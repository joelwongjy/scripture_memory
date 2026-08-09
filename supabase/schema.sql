-- Verse catalog schema for Scripture Memory.
--
-- Run once in the Supabase SQL editor (Dashboard → SQL Editor → New query).
-- After it succeeds, seed the data with:
--
--     SUPABASE_URL=https://<project>.supabase.co \
--     SUPABASE_SERVICE_KEY=<service_role key> \
--     python3 Scripts/seed_supabase.py
--
-- Editing afterwards: the Table Editor is the admin UI. Change a verse row,
-- then bump the version so clients notice:
--
--     select bump_catalog_version();
--
-- Clients read this with the *anon* key, which is publishable. The policies at
-- the bottom are what make that safe: anyone may read, nobody may write. All
-- writes go through the service_role key, which lives on your machine and in
-- CI — never in the app.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table if not exists packs (
    id          bigint generated always as identity primary key,
    -- Which bundled edition this pack belongs to: 'NIV84' or 'NIV11'. The two
    -- are separate rows, not translations of one row, because they differ in
    -- more than text — a card can be present in one and absent from the other.
    edition     text    not null,
    name        text    not null,
    color       text    not null,
    accent_text text    not null default '',
    -- Display order within the edition. The app applies the user's own pack
    -- ordering on top of this; this is the shipped default.
    sort_index  integer not null,
    unique (edition, name)
);

create table if not exists verses (
    id         bigint generated always as identity primary key,
    pack_id    bigint  not null references packs(id) on delete cascade,
    -- The card's permanent identity, and what all user progress on device is
    -- filed under. Identical in both editions. NEVER edit this: changing it
    -- detaches every user's learnt/starred/scheduled state for that card. It is
    -- deliberately meaningless so that nothing you *can* sensibly edit — the
    -- pack's name, the book's spelling, the reference's punctuation — is load
    -- bearing. Those are all now safe to change.
    --
    -- Nullable only so this file stays re-runnable against a database seeded
    -- before the column existed; the seed script always populates it, and the
    -- app ignores a catalog with any uid missing.
    card_uid   text,
    -- The id the *app* knows this verse by. Quiz selections, submitted answers
    -- and review-complete flags are all persisted against it on device, so it
    -- is authored data, not a generated key: changing it silently repoints a
    -- user's saved progress at a different verse. Only unique within an
    -- edition — the same card has different ids in NIV84 and NIV11.
    verse_id   bigint  not null,
    sort_index integer not null,
    title      text    not null,
    verse      text    not null,
    book       text    not null,
    reference  text    not null,
    -- Lettered section, e.g. TMS 60's 'A'..'E'. Empty for packs that are one
    -- straight run.
    subpack    text    not null default '',
    -- Translation override for a card printed in something other than its
    -- pack's edition (a few DEP cards are KJV). NULL means "the pack's own".
    version    text,
    unique (pack_id, verse_id)
);

-- ---------------------------------------------------------------------------
-- Columns added after the first release
-- ---------------------------------------------------------------------------
--
-- `create table if not exists` does nothing at all to a table that already
-- exists — including adding columns declared above. Anything introduced after
-- the first run has to be stated separately, and it has to come before the
-- indexes and views that reference it. All of these are safe to re-run.

alter table verses add column if not exists card_uid   text;
alter table packs  add column if not exists updated_at timestamptz not null default now();
alter table verses add column if not exists updated_at timestamptz not null default now();

-- Defaults for the two columns you'd otherwise have to invent by hand.
--
-- Adding a verse in the Table Editor means filling a row without leaving these
-- blank, and a blank card_uid is the single worst mistake available: the app
-- refuses a catalog in which any verse lacks one, so one empty cell stops every
-- device updating and says nothing about why. Generating both here means a new
-- row only needs its text.
create sequence if not exists verse_id_seq start with 30001;

alter table verses alter column verse_id set default nextval('verse_id_seq');
alter table verses alter column card_uid set default encode(gen_random_bytes(8), 'hex');

-- Backfill anything inserted before the default existed, then make it a rule
-- rather than a convention.
update verses set card_uid = encode(gen_random_bytes(8), 'hex') where card_uid is null;
alter table verses alter column card_uid set not null;

create index if not exists verses_pack_sort_idx on verses (pack_id, sort_index);
create index if not exists packs_edition_idx     on packs  (edition, sort_index);
create index if not exists verses_card_uid_idx   on verses (card_uid);

-- ---------------------------------------------------------------------------
-- Change tracking
-- ---------------------------------------------------------------------------
--
-- Clients only re-download when `catalog_meta.version` goes up, and that only
-- happens when you call bump_catalog_version(). Which means a forgotten bump
-- looks exactly like a successful edit: the row shows your new text, and no
-- device ever sees it. These stamps make that visible instead of silent.

create or replace function touch_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists packs_touch_updated_at on packs;
create trigger packs_touch_updated_at
    before update on packs
    for each row execute function touch_updated_at();

drop trigger if exists verses_touch_updated_at on verses;
create trigger verses_touch_updated_at
    before update on verses
    for each row execute function touch_updated_at();

-- Single-row table the client polls on launch. Fetching one integer to learn
-- there is nothing to do is much cheaper than downloading ~490 verses to
-- discover the same.
create table if not exists catalog_meta (
    id         integer     primary key default 1,
    version    bigint      not null default 1,
    updated_at timestamptz not null default now(),
    constraint catalog_meta_singleton check (id = 1)
);

insert into catalog_meta (id, version) values (1, 1)
on conflict (id) do nothing;

-- Publish whatever is currently in the tables. Edits publish themselves (see
-- Auto-publish below), so this is now a manual override — useful to force
-- clients to re-download when nothing in the tables actually changed.
create or replace function bump_catalog_version()
returns bigint
language sql
as $$
    update catalog_meta
       set version = version + 1, updated_at = now()
     where id = 1
 returning version;
$$;

-- ---------------------------------------------------------------------------
-- Auto-publish
-- ---------------------------------------------------------------------------
--
-- Any edit to packs or verses publishes itself. Without this, editing a row in
-- the Table Editor looked exactly like a successful change while reaching
-- precisely nobody — the version never moved, so no client ever re-downloaded.
--
-- FOR EACH STATEMENT, not FOR EACH ROW: seeding inserts ~1,000 verses, and a
-- per-row trigger would bump the version a thousand times to say one thing.
--
-- The cost of this convenience is that edits go out as you make them. To
-- release a set of related changes together, wrap them in a transaction — one
-- statement each, but a single visible version at the end:
--
--     begin;
--       update verses set verse = '...' where id = 1;
--       update verses set verse = '...' where id = 2;
--     commit;

-- `security definer` so the bump can't be blocked by row-level security on
-- catalog_meta, which has no write policy by design. Today only the service
-- role can write packs/verses and it bypasses RLS anyway; this keeps the
-- trigger working if a narrower writer role is ever added, instead of failing
-- the edit with a confusing permission error. `search_path` is pinned, which is
-- the required companion to `security definer` — without it a caller could
-- shadow `catalog_meta` with their own table and run this as the owner.
create or replace function bump_catalog_version_from_edit()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
    update catalog_meta
       set version = version + 1, updated_at = now()
     where id = 1;
    return null;
end;
$$;

drop trigger if exists packs_bump_catalog_version on packs;
create trigger packs_bump_catalog_version
    after insert or update or delete or truncate on packs
    for each statement execute function bump_catalog_version_from_edit();

drop trigger if exists verses_bump_catalog_version on verses;
create trigger verses_bump_catalog_version
    after insert or update or delete or truncate on verses
    for each statement execute function bump_catalog_version_from_edit();

-- Sanity check: `select * from catalog_status;`
--
-- With auto-publish above, `unpublished_edits` should always read 0. If it ever
-- doesn't, the triggers aren't installed — re-run this file — and the fallback
-- is to publish by hand with `select bump_catalog_version();`.
--
-- Defined here, after catalog_meta, because a view can't reference a table that
-- doesn't exist yet.
create or replace view catalog_status as
select
    m.version                                            as published_version,
    m.updated_at                                         as published_at,
    greatest(
        coalesce((select max(updated_at) from verses), m.updated_at),
        coalesce((select max(updated_at) from packs),  m.updated_at)
    )                                                    as last_edit_at,
    (select count(*) from verses where updated_at > m.updated_at)
  + (select count(*) from packs  where updated_at > m.updated_at)
                                                         as unpublished_edits
from catalog_meta m
where m.id = 1;

-- Run this view as whoever queries it, not as its owner.
--
-- Postgres 15+ creates views as SECURITY DEFINER by default, which Supabase's
-- linter flags: the view would read packs/verses/catalog_meta with the owner's
-- rights and skip the caller's row-level security. It changes nothing today —
-- all three tables are publicly readable, so the view can't reveal a row anyone
-- couldn't already select — but the day rows on verses or packs are restricted,
-- this would silently keep counting all of them.
alter view catalog_status set (security_invoker = on);

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------
--
-- Read-only to the world; writes only via service_role, which bypasses RLS.

alter table packs        enable row level security;
alter table verses       enable row level security;
alter table catalog_meta enable row level security;

drop policy if exists "catalog is publicly readable" on packs;
create policy "catalog is publicly readable"
    on packs for select to anon, authenticated using (true);

drop policy if exists "catalog is publicly readable" on verses;
create policy "catalog is publicly readable"
    on verses for select to anon, authenticated using (true);

drop policy if exists "catalog is publicly readable" on catalog_meta;
create policy "catalog is publicly readable"
    on catalog_meta for select to anon, authenticated using (true);

-- The status view is for you, not for clients; it reads tables the anon role
-- can already select from, so nothing is exposed that wasn't.
grant select on catalog_status to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Consistency check
-- ---------------------------------------------------------------------------
--
-- `select * from catalog_problems;` — empty means the catalog is coherent.
--
-- Every card is two rows, one per edition, and they have to agree about which
-- card they are. That's invisible in the Table Editor, and getting it wrong is
-- silent: a card whose two editions carry different `card_uid`s loses the
-- user's progress the moment they switch translation. This makes each of those
-- mistakes a row you can see.

-- Add one card to every edition of a pack in a single call.
--
--   select add_card('DEP 2: Quiet Time', 7, 'Seek him early',
--                   'Psalm', '63:1', 'O God, you are my God...');
--
-- Doing this by hand means two inserts that must agree on `card_uid` — and the
-- column's default generates a *different* random id per row, so the natural
-- way to add a card is also the way to break it. One uid is minted here and
-- shared, which is the whole point of the function.
--
-- Pass `p_verse_by_edition` to give each translation its own text:
--   '{"NIV84": "...", "NIV11": "..."}'::jsonb
create or replace function add_card(
    p_pack_name text,
    p_sort_index integer,
    p_title text,
    p_book text,
    p_reference text,
    p_verse text default null,
    p_verse_by_edition jsonb default null,
    p_subpack text default '',
    p_version text default null
) returns text
language plpgsql
as $$
declare
    new_uid text := encode(gen_random_bytes(8), 'hex');
    pack record;
    body text;
begin
    if p_verse is null and p_verse_by_edition is null then
        raise exception 'give either p_verse or p_verse_by_edition';
    end if;

    for pack in select id, edition from packs where name = p_pack_name loop
        body := coalesce(p_verse_by_edition ->> pack.edition, p_verse);
        if body is null then
            raise exception 'no verse text for edition %', pack.edition;
        end if;
        insert into verses (pack_id, card_uid, sort_index, title, verse,
                            book, reference, subpack, version)
        values (pack.id, new_uid, p_sort_index, p_title, body,
                p_book, p_reference, p_subpack, p_version);
    end loop;

    if not found then
        raise exception 'no pack named %', p_pack_name;
    end if;
    return new_uid;
end;
$$;

create or replace view catalog_problems as
    -- A pack added to one edition only. Users on the other never see it.
    select 'pack missing from an edition'::text as problem,
           (p.edition || ' / ' || p.name)::text as detail
      from packs p
     where not exists (select 1 from packs q
                        where q.name = p.name and q.edition <> p.edition)

    union all

    -- The same passage carrying different ids in the two editions. This is the
    -- one that costs users their progress.
    --
    -- Compares the *set* of ids per edition rather than counting distinct ids
    -- across both, because three packs legitimately print the same passage on
    -- two different cards (Acts 17:11 is DEP 3 cards 23 and 32) and those
    -- rightly hold two ids. Whitespace is stripped from the reference first:
    -- the editions disagree on `27:17, 19` versus `27:17,19`, which is only a
    -- spelling of the same reference — and is exactly how the ids were minted.
    select 'card_uid differs between editions'::text,
           (t.name || ' / ' || t.book || ' ' || t.reference)::text
      from (
            select p.name,
                   v.book,
                   regexp_replace(v.reference, '\s', '', 'g') as reference,
                   p.edition,
                   array_agg(v.card_uid order by v.card_uid) as uids
              from verses v
              join packs p on p.id = v.pack_id
             group by p.name, v.book, regexp_replace(v.reference, '\s', '', 'g'), p.edition
           ) t
     group by t.name, t.book, t.reference
    having count(distinct t.uids) > 1

    union all

    -- Two verses claiming the same position in a pack: the card order becomes
    -- whatever Postgres feels like, and the printed numbers drift.
    select 'duplicate sort_index'::text,
           (p.edition || ' / ' || p.name || ' #' || v.sort_index::text)::text
      from verses v
      join packs p on p.id = v.pack_id
     group by p.edition, p.name, v.sort_index
    having count(*) > 1;

alter view catalog_problems set (security_invoker = on);
grant select on catalog_problems to anon, authenticated;
