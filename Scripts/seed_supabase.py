#!/usr/bin/env python3
"""Push the bundled verse JSON into Supabase.

Run once to populate an empty project, and again whenever you've changed the
bundled JSON and want the hosted catalog to match. After seeding, edits are
normally made in the Supabase Table Editor rather than here.

    SUPABASE_URL=https://<project>.supabase.co \
    SUPABASE_SERVICE_KEY=<secret key> \
    python3 Scripts/seed_supabase.py

The secret key (`sb_secret_…`, formerly `service_role`) bypasses row-level
security, so it must never be committed or shipped in the app — pass it through
the environment. The app ships the publishable key (`sb_publishable_…`, formerly
`anon`) instead, which the policies make read-only.

`--check` verifies what's hosted matches what's bundled and writes nothing;
useful as a CI guard against the two drifting apart.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RESOURCES = REPO / "scripture memory" / "Resources"

EDITIONS = {
    "NIV84": RESOURCES / "verseData.json",
    "NIV11": RESOURCES / "verseDataNIV11.json",
}


class Supabase:
    def __init__(self, url: str, key: str):
        self.url = url.rstrip("/")
        self.key = key

    def _request(self, method: str, path: str, body=None, prefer: str | None = None):
        headers = {
            "apikey": self.key,
            "Authorization": f"Bearer {self.key}",
            "Content-Type": "application/json",
        }
        if prefer:
            headers["Prefer"] = prefer
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(f"{self.url}/rest/v1/{path}", data=data,
                                     headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=60) as response:
                raw = response.read()
                return json.loads(raw) if raw else None
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")
            # PGRST205 is "no such table". Every first run hits it, because the
            # tables are DDL and this script only moves rows — so say the actual
            # next step instead of forwarding a schema-cache error.
            if "PGRST205" in detail:
                raise SystemExit(
                    "The catalog tables don't exist yet.\n"
                    "Create them first: Supabase dashboard -> SQL Editor -> New query,\n"
                    "paste supabase/schema.sql, Run. Then re-run this script."
                ) from None
            if error.code in (401, 403):
                raise SystemExit(
                    f"{method} {path} was rejected ({error.code}).\n"
                    "SUPABASE_SERVICE_KEY must be the *secret* key (sb_secret_...), "
                    "not the publishable one — writing needs to bypass RLS."
                ) from None
            raise SystemExit(f"{method} {path} failed ({error.code}): {detail}") from None

    def select(self, path: str):
        return self._request("GET", path)

    def insert(self, table: str, rows: list[dict]):
        # Chunked: a single request carrying every verse in the catalogue is
        # large enough to hit request-size limits on some plans.
        out = []
        for start in range(0, len(rows), 500):
            got = self._request("POST", table, rows[start:start + 500],
                                prefer="return=representation")
            out += got or []
        return out

    def delete_all(self, table: str):
        # PostgREST refuses an unfiltered DELETE; `id=gte.0` is the "yes, all of
        # it" spelling.
        self._request("DELETE", f"{table}?id=gte.0")

    def rpc(self, function: str, args: dict | None = None):
        return self._request("POST", f"rpc/{function}", args or {})


def bundled_catalog() -> list[tuple[str, dict, int]]:
    """(edition, pack, sort_index) for every bundled pack."""
    out = []
    for edition, path in EDITIONS.items():
        packs = json.loads(path.read_text())
        for index, pack in enumerate(packs):
            out.append((edition, pack, index))
    return out


def cmd_check(client: Supabase) -> int:
    hosted = client.select("packs?select=edition,name,verses(verse_id)")
    hosted_counts = {(row["edition"], row["name"]): len(row["verses"]) for row in hosted}
    bundled_counts = {(edition, pack["name"]): len(pack["verses"])
                      for edition, pack, _ in bundled_catalog()}

    if hosted_counts == bundled_counts:
        print(f"in sync: {len(bundled_counts)} packs, "
              f"{sum(bundled_counts.values())} verses")
        return 0

    for key in sorted(set(hosted_counts) | set(bundled_counts)):
        hosted_n = hosted_counts.get(key)
        bundled_n = bundled_counts.get(key)
        if hosted_n != bundled_n:
            print(f"  {key[0]} {key[1]}: hosted={hosted_n} bundled={bundled_n}")
    return 1


def cmd_seed(client: Supabase) -> int:
    # Replace rather than merge: the bundled JSON is the whole truth here, and a
    # verse deleted from it has to disappear from the catalog too. `verses`
    # cascades from `packs`, so one delete clears both.
    print("clearing existing catalog…")
    client.delete_all("packs")

    verse_rows: list[dict] = []
    pack_rows = []
    for edition, pack, index in bundled_catalog():
        pack_rows.append({
            "edition": edition,
            "name": pack["name"],
            "color": pack["color"],
            "accent_text": pack.get("accentText", ""),
            "sort_index": index,
        })

    print(f"inserting {len(pack_rows)} packs…")
    inserted = client.insert("packs", pack_rows)
    pack_ids = {(row["edition"], row["name"]): row["id"] for row in inserted}

    for edition, pack, _ in bundled_catalog():
        pack_id = pack_ids[(edition, pack["name"])]
        for index, verse in enumerate(pack["verses"]):
            if not verse.get("cardUid"):
                raise SystemExit(
                    f"{edition} / {pack['name']} / {verse['book']} {verse['reference']} "
                    "has no cardUid.\nRun `python3 Scripts/sync_verses.py patch` first — "
                    "it assigns them."
                )
            verse_rows.append({
                "pack_id":    pack_id,
                "verse_id":   verse["id"],
                "card_uid":   verse["cardUid"],
                "sort_index": index,
                "title":      verse["title"],
                "verse":      verse["verse"],
                "book":       verse["book"],
                "reference":  verse["reference"],
                "subpack":    verse.get("subpack", ""),
                "version":    verse.get("version"),
            })

    print(f"inserting {len(verse_rows)} verses…")
    client.insert("verses", verse_rows)

    # Belt and braces. The auto-publish triggers have already bumped the version
    # several times during this run — once per write statement, so a seed moves
    # it by about six — but this guarantees a final publish even against a
    # database where the triggers aren't installed.
    version = client.rpc("bump_catalog_version")
    print(f"done — catalog version is now {version}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true",
                        help="compare hosted against bundled, write nothing")
    args = parser.parse_args()

    url = os.environ.get("SUPABASE_URL", "").strip()
    key = os.environ.get("SUPABASE_SERVICE_KEY", "").strip()
    if not url or not key:
        print("set SUPABASE_URL and SUPABASE_SERVICE_KEY", file=sys.stderr)
        return 2

    client = Supabase(url, key)
    return cmd_check(client) if args.check else cmd_seed(client)


if __name__ == "__main__":
    raise SystemExit(main())
