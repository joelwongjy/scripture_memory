# Managing verses outside the app

The bundled JSON in `scripture memory/Resources/` is still the floor: it ships
with the app, it's complete, and a fresh install reads it with no network at
all. Supabase sits on top so a typo or a missing verse can be corrected without
shipping a build through App Store review.

Nothing here is active until you fill in the two Info.plist keys. Until then the
app behaves exactly as it did before and never makes a request.

## One-time setup

1. Create a project at [supabase.com](https://supabase.com). (You'll need to do
   this yourself — it's an account signup.)
2. **SQL Editor → New query**, paste `schema.sql`, run it.
3. **Project Settings → API Keys**, copy the *Project URL* and the
   **publishable** key (`sb_publishable_…`) into `AppInfo.plist`:

   ```xml
   <key>SupabaseURL</key>
   <string>https://yourproject.supabase.co</string>
   <key>SupabaseAnonKey</key>
   <string>sb_publishable_...</string>
   ```

   The publishable key is meant to ship in clients — it's what replaced the old
   `anon` key. Row-level security (bottom of `schema.sql`) makes the catalog
   world-readable and writable by nobody. The **secret** key (`sb_secret_…`,
   formerly `service_role`) bypasses RLS and must never go in the app or in git.

4. Seed it from the bundled JSON — run this yourself, so the secret key stays on
   your machine:

   ```bash
   SUPABASE_URL=https://yourproject.supabase.co \
   SUPABASE_SERVICE_KEY=<secret key> \
   python3 Scripts/seed_supabase.py
   ```

## Editing a verse

Supabase's **Table Editor** is the admin UI — no separate tool to build or host.

Edit the row. That's it: a trigger publishes the change for you by bumping the
catalog version, so there's no second step to forget.

To release a set of related corrections **together** rather than one at a time,
wrap them in a transaction — the version moves once, at commit:

```sql
begin;
  update verses set verse = '...' where id = 1;
  update verses set verse = '...' where id = 2;
commit;
```

`select bump_catalog_version();` still exists as a manual override, for forcing
clients to re-download when nothing in the tables actually changed.

Sanity check, if you ever suspect an edit didn't go out:

```sql
select * from catalog_status;
```

`unpublished_edits` should always read 0. Anything else means the triggers
aren't installed — re-run `schema.sql`.

### When the change appears

On the next launch, not immediately. The refresh runs at startup, writes a
cache file, and stops — the running session keeps the catalog it started with.
Printed card numbers, the search index, an in-flight quiz's verse list and the
learning cursor's position are all computed once from the catalog and held for
the life of the process; swapping it underneath them would renumber cards
mid-quiz for a payoff nobody is waiting on. So: open the app, close it, open it
again.

## Adding and removing

### The thing to understand first

**Every card is two rows** — one per edition (`NIV84`, `NIV11`) — and the two
must share a `card_uid`. That id is what user progress is filed under, so if the
editions disagree about it, a user switching translation loses their history for
that card. Nothing in the Table Editor shows you this.

So don't add cards by hand. Use:

```sql
select add_card('DEP 2: Quiet Time', 7, 'Seek him early',
                'Psalm', '63:1', 'O God, you are my God…');
```

It inserts into every edition of that pack with one shared id. Different text per
translation:

```sql
select add_card('DEP 2: Quiet Time', 7, 'Seek him early', 'Psalm', '63:1',
                p_verse_by_edition => '{"NIV84":"…","NIV11":"…"}'::jsonb);
```

Editing existing text *is* fine in the Table Editor — just remember a typo fix
usually needs doing in both editions.

**A pack.** Insert into `packs` **once per edition**, then its verses via
`add_card`. A pack added to only one edition won't exist for users on the other
translation.

### Check yourself

```sql
select * from catalog_problems;
```

Empty means coherent. It reports packs present in only one edition, cards whose
editions disagree on `card_uid`, and two verses claiming the same `sort_index`.
Worth running after any structural change.

New packs get the generic cover. The DEP, TMS 60, TMS 180 and 5 Assurances
designs are matched by name in `PackCover`, and the series footers
(`A-12 · Live the New Life`) come from a list in `CardFooter` — a new pack falls
back to plain styling rather than breaking.

**Removing** a verse or a pack works as you'd expect (packs cascade to their
verses). Users who had progress on a deleted verse keep a harmless orphan entry.

## Two things to be careful with

**`verse_id` is not a database key.** It's the id the *app* persists progress
against — quiz selections, submitted answers, review-complete flags all live on
device keyed by it. Changing an existing verse's `verse_id` silently repoints a
user's saved progress at a different verse. Adding a verse? Give it an unused
id (the `Scripts/sync_verses.py` insertions start at 20001) rather than
renumbering the pack around it.

**Learning and SRS progress are keyed by pack name + book + reference**, not by
`verse_id`. Renaming a pack or rewriting a reference orphans every user's
progress for the verses in it. Fixing the verse *text* is free; changing what
identifies the verse is not.

## Keeping the two in sync

The bundled JSON is the offline fallback, so it shouldn't drift far from what's
hosted. `Scripts/seed_supabase.py --check` compares them and exits non-zero if
they differ — worth running in CI.

To go the other way (source of truth → JSON), `Scripts/sync_verses.py`
reconciles the bundled files against the Navigators' published packs at
tms.navigators.tech:

```bash
python3 Scripts/sync_verses.py audit    # report differences
python3 Scripts/sync_verses.py patch    # apply them
```

Then re-run the seed to push the result up.

## Widget note

The widget extension has its own bundle and can't read the app's resources, so
it ships a byte-copy of `verseData.json` and does **not** read the remote
catalog. `sync_verses.py patch` re-mirrors that copy. A verse corrected remotely
will show the old text in the widget until the next app release.
