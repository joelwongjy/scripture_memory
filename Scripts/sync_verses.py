#!/usr/bin/env python3
"""Reconcile the bundled verse JSON against tms.navigators.tech.

The Navigators' own web app (a Next.js site) ships each pack's full contents in
the `__NEXT_DATA__` payload of `/pack/<id>/view`, and `?bibleVersion=<VER>`
re-renders the same pack in another translation. That makes it the authoritative
source for both the pack ordering and the verse text we bundle.

Commands
--------
    audit    Compare every bundled pack against the source and print a diff of
             the reference lists. Read-only.
    patch    Apply the reconciliation to Resources/verseData*.json: insert
             verses the source has and we don't, fix the known title typo, and
             pin the two verses whose printed card is KJV.
    dump     Emit a single canonical catalog JSON (all packs, all versions) on
             stdout — the seed input for the Supabase catalog.

Verse `id`s are load-bearing: quiz selections, submitted answers and
review-complete flags are all persisted by id. Inserted verses therefore get
fresh ids from a reserved high block rather than renumbering the pack, so a
user's existing progress keeps pointing at the verse it was recorded for.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RESOURCES = REPO / "scripture memory" / "Resources"
CACHE = Path(os.environ.get("TMS_CACHE", REPO / ".build" / "tms-cache"))

BUNDLES = {
    "NIV84": RESOURCES / "verseData.json",
    "NIV11": RESOURCES / "verseDataNIV11.json",
}

# The widget extension has its own bundle and can't read the app's resources, so
# it ships a byte-copy of the NIV84 file. Nothing keeps the two in step, so
# `patch` re-mirrors it — a drifted widget quietly shows the wrong verse text.
MIRRORS = {RESOURCES / "verseData.json": REPO / "ScriptureWidget" / "verseData.json"}

# Bundled pack name -> the source pack ids that concatenate into it. TMS 60 is
# published as five lettered booklets; we ship it as one 60-card pack.
PACK_MAP = {
    "5 Assurances": [1],
    "TMS 60": [2, 3, 4, 5, 6],
    "DEP 1: Assurance of Salvation": [51],
    "DEP 2: Quiet Time": [52],
    "DEP 3: The Word": [69],
    "DEP 4: Prayer": [84],
    "DEP 5: Fellowship": [103],
    "DEP 6: Witnessing": [104],
    "DEP 7: The Lordship of Christ": [105],
    "DEP 8: World Vision": [106],
    "TMS 180 · Getting to Know God": [56],
    "TMS 180 · Growing in Love": [59],
    "TMS 180 · Growing in Faith": [60],
    "TMS 180 · Walking in Victory": [61],
    "TMS 180 · Sharing Christ with Others": [62],
}

# First id handed out to a verse inserted by `patch`. Well clear of the existing
# ranges (max bundled id is 10176) so insertion never collides or renumbers.
INSERT_ID_BASE = 20001

# Verses whose printed card in the physical pack is KJV regardless of which NIV
# edition the rest of the pack uses. Keyed (pack, book, reference).
KJV_PINNED = [
    ("DEP 4: Prayer", "1 Thessalonians", "5:17"),
    ("DEP 2: Quiet Time", "Psalm", "27:8"),
]

# Cover colours, read off photographs of the printed packs.
#
# What shipped before came from tms.navigators.tech, where pack colour is picked
# by whoever uploaded it — pure `#00ff07`, `#14f7ff` and so on. Those bear no
# relation to the physical packs the covers are imitating.
#
# The photos were taken under warm shop lighting at an angle, so these are the
# sampled hues cleaned up to flat print colours rather than literal pixel values.
PACK_COLORS = {
    # DEP 242. Pack 1 is printed on white stock with red type; everything else is
    # a solid field with white type. The app picks the type colour from the
    # field's luminance, so the cream value is all it needs.
    # Sampled off the shop display card holding all eight, with only a light
    # exposure lift (~6%).
    #
    # I first white-balanced these hard against the board behind them, on the
    # reasoning that the board is painted white and reads #DFE0DF, so everything
    # was ~12% underexposed. Arithmetically fine, visibly wrong: it assumes the
    # board is pure white and pushes every pack to a brightness the printed cards
    # don't have. Trusting the measurement over the result is how you end up with
    # a set of neons that each individually "matches".
    #
    # The set runs as a spectrum: white, red, orange, yellow, green, sky, royal,
    # violet.
    "DEP 1: Assurance of Salvation": "#F4F2ED",
    "DEP 2: Quiet Time":             "#E14C30",
    "DEP 3: The Word":               "#EA8A2E",
    "DEP 4: Prayer":                 "#E7AF21",
    "DEP 5: Fellowship":             "#019A4E",
    "DEP 6: Witnessing":             "#0090D0",
    "DEP 7: The Lordship of Christ": "#01409E",
    "DEP 8: World Vision":           "#362B8A",

    # The olive green of "Lessons on Assurance", the book these five come from.
    "5 Assurances": "#7FA23C",

    "TMS 180 · Getting to Know God":        "#5E3A87",
    "TMS 180 · Growing in Love":            "#8E3339",
    "TMS 180 · Growing in Faith":           "#2E86B8",
    "TMS 180 · Walking in Victory":         "#8E9A3C",
    "TMS 180 · Sharing Christ with Others": "#D9925C",
}

# Straight text corrections in bundled titles/verses, applied to both editions.
TEXT_FIXES = [
    ("Moses - personal fellowship wtih the Lord",
     "Moses - personal fellowship with the Lord"),
]


# --------------------------------------------------------------------------- #
# Source fetching
# --------------------------------------------------------------------------- #

NEXT_DATA = re.compile(
    r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>', re.S
)


def fetch_pack(pack_id: int, version: str) -> dict:
    """The source pack payload, memoised on disk (the site is slow and static)."""
    CACHE.mkdir(parents=True, exist_ok=True)
    cached = CACHE / f"{pack_id}_{version}.json"
    if cached.exists():
        return json.loads(cached.read_text())

    url = f"https://tms.navigators.tech/pack/{pack_id}/view?bibleVersion={version}"
    req = urllib.request.Request(url, headers={"User-Agent": "scripture-memory-sync"})
    html = urllib.request.urlopen(req, timeout=30).read().decode()
    match = NEXT_DATA.search(html)
    if not match:
        raise RuntimeError(f"no __NEXT_DATA__ in {url}")
    pack = json.loads(match.group(1))["props"]["pageProps"]["initialPack"]
    cached.write_text(json.dumps(pack, ensure_ascii=False))
    return pack


def strip_control_chars(text: str) -> str:
    """Drop C0/C1 control characters.

    Jonah 4:10-11 ended with a literal U+001A (SUBSTITUTE) — invisible on the
    card, but `wordTokens` split it off as its own word, so the scorer counted a
    word nobody could type.
    """
    return "".join(c for c in text if c.isprintable() or c in " \n\t")


def normalize_text(text: str) -> str:
    """Bring source text in line with what the bundle already uses.

    The site renders poetic line breaks as runs of spaces, and its NIV84 edition
    types nested quotes as backticks. Neither convention appears anywhere in the
    bundled JSON, so an inserted verse that kept them would render visibly unlike
    the card above it — and the backtick would be a word token the user has to
    type. Applied only to text we're pulling in; bundled verses are left alone.
    """
    return re.sub(r"\s+", " ", text.replace("`", "'")).strip()


def flatten(pack: dict) -> list[dict]:
    """Source `contents` (interleaved TITLE / VERSE) -> flat verse records.

    A TITLE applies to every VERSE after it until the next TITLE — that heading
    is what our cards show as the verse title.
    """
    out: list[dict] = []
    title = ""
    for item in pack["contents"]:
        if item["type"] == "TITLE":
            title = item["name"].strip()
        else:
            out.append({
                "title": normalize_text(title),
                "book": item["book"].strip(),
                "reference": f"{item['chapter']}:{item['verses']}".strip(),
                "verse": normalize_text(item["text"]),
            })
    return out


def source_pack(name: str, version: str) -> list[dict]:
    verses: list[dict] = []
    for pack_id in PACK_MAP[name]:
        verses += flatten(fetch_pack(pack_id, version))
    return verses


# --------------------------------------------------------------------------- #
# Card identity
# --------------------------------------------------------------------------- #

def legacy_key(pack_name: str, verse: dict) -> str:
    """The identity the app used before `cardUid` — pack + book + reference.

    Mirrors `SRSKey.make` exactly (lowercased book, whitespace stripped from the
    reference). Reproduced here only so uids can be seeded from it, which is what
    makes the on-device migration a pure lookup.
    """
    book = verse["book"].lower().strip()
    reference = re.sub(r"\s", "", verse["reference"]).lower()
    return f"{pack_name}#{book}|{reference}"


def mint_uid(pack_name: str, verse: dict, occurrence: int = 1) -> str:
    """A card's permanent id.

    Derived from the legacy identity *once*, then stored and never recomputed —
    that seeding is what lets existing installs map their saved progress across
    without a server round trip. After assignment the value is authoritative on
    its own, so renaming a pack or restyling a reference no longer touches it.
    Both editions of a card derive the same uid because both agree on pack, book
    and reference.

    `occurrence` disambiguates packs that print the same passage on two cards
    under different titles (see `assign_uids`). It's part of the derivation only;
    once minted the uid stands alone and doesn't care about position.
    """
    seed = legacy_key(pack_name, verse)
    if occurrence > 1:
        seed += f"#{occurrence}"
    return hashlib.sha256(seed.encode()).hexdigest()[:16]


def assign_uids(bundle: list[dict]) -> int:
    """Fill in any missing `cardUid`. Idempotent — existing ones are never
    touched, which is the whole point: a uid that could be recomputed from
    content would inherit exactly the fragility it exists to remove.

    Three packs print the same passage on two different cards (Acts 17:11 twice
    in DEP 3, 1 Timothy 2:1-2 twice in DEP 4, Romans 10:9-10 twice in DEP 6).
    The old pack+book+reference key couldn't tell those apart, so the app treated
    each pair as one card — starring one starred both, and learning one skipped
    the other. Counting occurrences gives the second card its own id and its own
    progress.
    """
    added = 0
    for pack in bundle:
        counts: dict[str, int] = {}
        for verse in pack["verses"]:
            key = legacy_key(pack["name"], verse)
            counts[key] = counts.get(key, 0) + 1
            if not verse.get("cardUid"):
                verse["cardUid"] = mint_uid(pack["name"], verse, counts[key])
                added += 1
    return added


# --------------------------------------------------------------------------- #
# Comparison
# --------------------------------------------------------------------------- #

def ref_key(verse: dict) -> str:
    """Book + reference, normalised so `9:11` and `9, 11` compare equal.

    The source and the bundle disagree on whitespace inside multi-verse
    references, which is cosmetic — matching on it would report every one of
    them as a mismatch and bury the real gaps.
    """
    book = verse["book"].strip().rstrip(".")
    ref = re.sub(r"\s+", "", verse["reference"])
    return f"{book} {ref}"


def missing_from_bundle(local: list[dict], remote: list[dict]) -> list[tuple[int, dict]]:
    """Source verses absent from the bundle, as (insert index, verse).

    Walks both lists in order, so a verse is reported at the position it holds
    in the published pack rather than appended at the end.
    """
    local_keys = [ref_key(v) for v in local]
    gaps: list[tuple[int, dict]] = []
    i = 0
    for verse in remote:
        key = ref_key(verse)
        if i < len(local_keys) and local_keys[i] == key:
            i += 1
        elif key not in local_keys:
            gaps.append((i + len(gaps), verse))
    return gaps


def reorder_to_source(local: list[dict], remote: list[dict]) -> list[dict] | None:
    """`local` resequenced into the source's order, or None if it can't be.

    Card numbers come from position in the pack (`CardFooter`), so an edition
    that lists two verses in the wrong order gives them the wrong printed
    numbers — and disagrees with the other edition of the same card. Records
    move whole, ids included, so nothing keyed by id is disturbed.

    Only safe when the two lists hold exactly the same references; anything else
    is a gap for `missing_from_bundle` (or a human) to deal with first.
    """
    by_key: dict[str, list[dict]] = {}
    for verse in local:
        by_key.setdefault(ref_key(verse), []).append(verse)
    if sorted(by_key) != sorted({ref_key(v) for v in remote}):
        return None
    if any(len(group) > 1 for group in by_key.values()):
        return None       # duplicate reference — ambiguous, leave it alone
    ordered = [by_key[ref_key(v)][0] for v in remote]
    return ordered if ordered != local else None


def cmd_audit(_args) -> int:
    import difflib

    problems = 0
    for version, path in BUNDLES.items():
        bundle = json.loads(path.read_text())
        by_name = {p["name"]: p for p in bundle}
        print(f"\n===== {path.name} ({version}) =====")
        for name in PACK_MAP:
            if name not in by_name:
                print(f"  !! bundle is missing pack {name!r}")
                problems += 1
                continue
            local = by_name[name]["verses"]
            remote = source_pack(name, version)
            lk = [ref_key(v) for v in local]
            rk = [ref_key(v) for v in remote]
            if lk == rk:
                print(f"  ok  {name}  ({len(lk)} verses)")
                continue
            problems += 1
            print(f"  !!  {name}  bundle={len(lk)} source={len(rk)}")
            for line in difflib.unified_diff(lk, rk, "bundle", "source",
                                             lineterm="", n=1):
                print(f"        {line}")
    return 1 if problems else 0


# --------------------------------------------------------------------------- #
# Patching
# --------------------------------------------------------------------------- #

def cmd_patch(args) -> int:
    next_id = INSERT_ID_BASE
    # Both editions must give the same verse the same id — they are two
    # translations of one card, and ids are how a saved quiz finds it back.
    assigned: dict[tuple[str, str], int] = {}

    for version, path in BUNDLES.items():
        bundle = json.loads(path.read_text())
        changes: list[str] = []

        for pack in bundle:
            if pack["name"] not in PACK_MAP:
                continue
            remote = source_pack(pack["name"], version)
            by_key = {ref_key(v): v for v in remote}

            for index, verse in missing_from_bundle(pack["verses"], remote):
                slot = (pack["name"], ref_key(verse))
                if slot not in assigned:
                    assigned[slot] = next_id
                    next_id += 1
                record = {
                    "id": assigned[slot],
                    "title": verse["title"],
                    "verse": verse["verse"],
                    "book": verse["book"],
                    "reference": re.sub(r"\s+$", "", verse["reference"]),
                    "subpack": pack["verses"][min(index, len(pack["verses"]) - 1)]["subpack"],
                }
                pack["verses"].insert(index, record)
                changes.append(f"+ {pack['name']}: {ref_key(verse)} at #{index + 1}")

            resequenced = reorder_to_source(pack["verses"], remote)
            if resequenced is not None:
                moved = [ref_key(v) for a, v in zip(pack["verses"], resequenced)
                         if ref_key(a) != ref_key(v)]
                pack["verses"] = resequenced
                changes.append(f"> {pack['name']}: resequenced {', '.join(moved)}")

            # Pin the KJV-only cards to their KJV text.
            for pin_pack, book, reference in KJV_PINNED:
                if pack["name"] != pin_pack:
                    continue
                key = ref_key({"book": book, "reference": reference})
                kjv = {ref_key(v): v for v in source_pack(pack["name"], "KJV")}.get(key)
                if kjv is None:
                    print(f"  !! no KJV text for {key} in {pin_pack}", file=sys.stderr)
                    continue
                for verse in pack["verses"]:
                    if ref_key(verse) != key:
                        continue
                    if verse.get("verse") != kjv["verse"] or verse.get("version") != "KJV":
                        verse["verse"] = kjv["verse"]
                        verse["version"] = "KJV"
                        changes.append(f"~ {pack['name']}: {key} pinned to KJV")

            # Invisible characters that the tokenizer nonetheless sees.
            for verse in pack["verses"]:
                for field in ("title", "verse"):
                    cleaned = re.sub(r"\s+", " ", strip_control_chars(verse[field])).strip()
                    if cleaned != verse[field]:
                        verse[field] = cleaned
                        changes.append(f"~ {pack['name']}: stripped control chars from "
                                       f"{verse['book']} {verse['reference']}")

            # Straight text corrections.
            for verse in pack["verses"]:
                for wrong, right in TEXT_FIXES:
                    for field in ("title", "verse"):
                        if wrong in verse[field]:
                            verse[field] = verse[field].replace(wrong, right)
                            changes.append(f"~ {pack['name']}: fixed {wrong!r}")

        for pack in bundle:
            wanted = PACK_COLORS.get(pack["name"])
            if wanted and pack.get("color") != wanted:
                changes.append(f"~ {pack['name']}: colour {pack.get('color')} -> {wanted}")
                pack["color"] = wanted

        # Last, so verses inserted above are minted in the same pass.
        minted = assign_uids(bundle)
        if minted:
            changes.append(f"~ assigned {minted} card uid(s)")

        print(f"{path.name}: {len(changes)} change(s)")
        for line in changes:
            print(f"  {line}")
        if changes and not args.dry_run:
            path.write_text(json.dumps(bundle, ensure_ascii=False, indent=2) + "\n")

    if not args.dry_run:
        for source, mirror in MIRRORS.items():
            if not mirror.exists() or mirror.read_bytes() != source.read_bytes():
                mirror.write_bytes(source.read_bytes())
                print(f"mirrored {source.name} -> {mirror.relative_to(REPO)}")
    return 0


# --------------------------------------------------------------------------- #
# Catalog dump (Supabase seed input)
# --------------------------------------------------------------------------- #

def cmd_dump(args) -> int:
    """One document holding every pack in every bundled edition.

    Shape matches what the app's remote catalog expects, so the same file seeds
    Supabase and can be served verbatim as a static fallback.
    """
    editions = {}
    for version, path in BUNDLES.items():
        editions[version] = json.loads(path.read_text())
    catalog = {"catalogVersion": args.catalog_version, "editions": editions}
    json.dump(catalog, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("audit", help="compare bundled packs against the source")

    patch = sub.add_parser("patch", help="apply reconciliation to the bundled JSON")
    patch.add_argument("--dry-run", action="store_true",
                       help="report changes without writing")

    dump = sub.add_parser("dump", help="emit the canonical catalog JSON")
    dump.add_argument("--catalog-version", type=int, default=1)

    args = parser.parse_args()
    return {"audit": cmd_audit, "patch": cmd_patch, "dump": cmd_dump}[args.command](args)


if __name__ == "__main__":
    raise SystemExit(main())
