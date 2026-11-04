#!/usr/bin/env python3
import datetime
import json
import os
import sqlite3
import subprocess
import tempfile
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VECTORS = os.path.join(ROOT, "shared", "test-vectors")
FIXTURES = os.path.join(VECTORS, "anki")

CREATION = 1704052800
CREATION_MINUTES_WEST = -480
ROLLOVER = 4
TIME_ZONE_MINUTES_WEST = -480
FIXED_MTIME = (2024, 1, 1, 0, 0, 0)

DEFAULT_DECK = 1
VERSES_DECK = 1700000000001
ROMANS_DECK = 1700000000002
DECKS = {
    DEFAULT_DECK: ["Default"],
    VERSES_DECK: ["Verses"],
    ROMANS_DECK: ["Verses", "Romans"],
}

BASIC = 1600000000001
REVERSED = 1600000000002
VERSE = 1600000000003
NOTETYPES = {
    BASIC: ("Basic", ["Front", "Back"], ["Card 1"]),
    REVERSED: ("Basic (and reversed card)", ["Front", "Back"], ["Card 1", "Card 2"]),
    VERSE: ("Verse", ["Reference", "Verse", "Topic"], ["Recall"]),
}

NOTES = [
    {
        "id": 1710000000001,
        "mid": VERSE,
        "tags": " tms assurance ",
        "fields": [
            "Romans 8:28",
            "And we know that in all things God works for the good of those who love him,&nbsp;who<br>have been called according to his purpose.",
            "<b>Assurance</b>",
        ],
        "expected_fields": [
            "Romans 8:28",
            "And we know that in all things God works for the good of those who love him, who\nhave been called according to his purpose.",
            "Assurance",
        ],
        "cards": [
            {
                "id": 1720000000001, "did": ROMANS_DECK, "ord": 0, "type": 2, "queue": 2,
                "due": 700, "ivl": 37, "factor": 2350, "reps": 9, "lapses": 1,
                "revlog": [(1725000000000, 3, 1), (1726000000000, 3, 1), (1727000000123, 4, 1), (1728000000000, 0, 4)],
            },
        ],
    },
    {
        "id": 1710000000002,
        "mid": VERSE,
        "tags": "tms",
        "fields": [
            "John 3:16",
            "<div>For God so loved the world</div><div>that he gave his one and only Son,</div>",
            "Gospel",
        ],
        "expected_fields": [
            "John 3:16",
            "For God so loved the world\nthat he gave his one and only Son,",
            "Gospel",
        ],
        "cards": [
            {
                "id": 1720000000002, "did": VERSES_DECK, "ord": 0, "type": 1, "queue": 1,
                "due": 1730000000, "ivl": 0, "factor": 0, "reps": 1, "lapses": 0,
                "revlog": [(1729999400000, 3, 0)],
            },
        ],
    },
    {
        "id": 1710000000003,
        "mid": BASIC,
        "tags": "",
        "fields": [
            "Who wrote &quot;{{c1::Paul::apostle}}&quot; &amp; when? &#8212; &#x41;",
            "<p>To the   church</p><p>in Philippi</p>",
        ],
        "expected_fields": [
            "Who wrote \"Paul\" & when? — A",
            "To the church\nin Philippi",
        ],
        "cards": [
            {
                "id": 1720000000003, "did": VERSES_DECK, "ord": 0, "type": 0, "queue": 0,
                "due": 5, "ivl": 0, "factor": 0, "reps": 0, "lapses": 0, "revlog": [],
            },
        ],
    },
    {
        "id": 1710000000004,
        "mid": BASIC,
        "tags": "psalms",
        "fields": [
            "Psalm 119:11 [sound:ps119.mp3]",
            "I have hidden your word in my heart <img src=\"heart.png\"> that I might not sin against you.",
        ],
        "expected_fields": [
            "Psalm 119:11",
            "I have hidden your word in my heart that I might not sin against you.",
        ],
        "cards": [
            {
                "id": 1720000000004, "did": VERSES_DECK, "ord": 0, "type": 2, "queue": -1,
                "due": 650, "ivl": 12, "factor": 2500, "reps": 4, "lapses": 0,
                "revlog": [(1724000000000, 3, 1)],
            },
        ],
    },
    {
        "id": 1710000000005,
        "mid": REVERSED,
        "tags": "romans transformation",
        "fields": [
            "Romans 12:2",
            "Do not conform to the pattern of this world,<br><br><br><br>but be transformed",
        ],
        "expected_fields": [
            "Romans 12:2",
            "Do not conform to the pattern of this world,\n\nbut be transformed",
        ],
        "cards": [
            {
                "id": 1720000000006, "did": ROMANS_DECK, "ord": 1, "type": 3, "queue": 3,
                "due": 701, "ivl": 1, "factor": 2300, "reps": 6, "lapses": 2,
                "revlog": [(1727500000000, 1, 2)],
            },
            {
                "id": 1720000000005, "did": ROMANS_DECK, "ord": 0, "type": 2, "queue": 2,
                "due": 690, "ivl": 3, "factor": 2500, "reps": 3, "lapses": 0,
                "revlog": [(1727400000000, 3, 1)],
            },
        ],
    },
]

DUMMY_NOTE = {
    "id": 1, "mid": BASIC, "tags": "",
    "fields": ["This file requires a newer version of Anki.", ""],
    "cards": [{"id": 1, "did": DEFAULT_DECK, "ord": 0, "type": 0, "queue": 0, "due": 1,
               "ivl": 0, "factor": 0, "reps": 0, "lapses": 0, "revlog": []}],
}

SCHEMA11 = """
CREATE TABLE col (id integer PRIMARY KEY, crt integer NOT NULL, mod integer NOT NULL,
  scm integer NOT NULL, ver integer NOT NULL, dty integer NOT NULL, usn integer NOT NULL,
  ls integer NOT NULL, conf text NOT NULL, models text NOT NULL, decks text NOT NULL,
  dconf text NOT NULL, tags text NOT NULL);
CREATE TABLE notes (id integer PRIMARY KEY, guid text NOT NULL, mid integer NOT NULL,
  mod integer NOT NULL, usn integer NOT NULL, tags text NOT NULL, flds text NOT NULL,
  sfld integer NOT NULL, csum integer NOT NULL, flags integer NOT NULL, data text NOT NULL);
CREATE TABLE cards (id integer PRIMARY KEY, nid integer NOT NULL, did integer NOT NULL,
  ord integer NOT NULL, mod integer NOT NULL, usn integer NOT NULL, type integer NOT NULL,
  queue integer NOT NULL, due integer NOT NULL, ivl integer NOT NULL, factor integer NOT NULL,
  reps integer NOT NULL, lapses integer NOT NULL, left integer NOT NULL, odue integer NOT NULL,
  odid integer NOT NULL, flags integer NOT NULL, data text NOT NULL);
CREATE TABLE revlog (id integer PRIMARY KEY, cid integer NOT NULL, usn integer NOT NULL,
  ease integer NOT NULL, ivl integer NOT NULL, lastIvl integer NOT NULL, factor integer NOT NULL,
  time integer NOT NULL, type integer NOT NULL);
CREATE TABLE graves (usn integer NOT NULL, oid integer NOT NULL, type integer NOT NULL);
CREATE INDEX ix_cards_nid ON cards (nid);
CREATE INDEX ix_revlog_cid ON revlog (cid);
"""

SCHEMA18 = """
CREATE TABLE col (id integer PRIMARY KEY, crt integer NOT NULL, mod integer NOT NULL,
  scm integer NOT NULL, ver integer NOT NULL, dty integer NOT NULL, usn integer NOT NULL,
  ls integer NOT NULL, conf text NOT NULL, models text NOT NULL, decks text NOT NULL,
  dconf text NOT NULL, tags text NOT NULL);
CREATE TABLE notes (id integer PRIMARY KEY, guid text NOT NULL, mid integer NOT NULL,
  mod integer NOT NULL, usn integer NOT NULL, tags text NOT NULL, flds text NOT NULL,
  sfld integer NOT NULL, csum integer NOT NULL, flags integer NOT NULL, data text NOT NULL);
CREATE TABLE cards (id integer PRIMARY KEY, nid integer NOT NULL, did integer NOT NULL,
  ord integer NOT NULL, mod integer NOT NULL, usn integer NOT NULL, type integer NOT NULL,
  queue integer NOT NULL, due integer NOT NULL, ivl integer NOT NULL, factor integer NOT NULL,
  reps integer NOT NULL, lapses integer NOT NULL, left integer NOT NULL, odue integer NOT NULL,
  odid integer NOT NULL, flags integer NOT NULL, data text NOT NULL);
CREATE TABLE revlog (id integer PRIMARY KEY, cid integer NOT NULL, usn integer NOT NULL,
  ease integer NOT NULL, ivl integer NOT NULL, lastIvl integer NOT NULL, factor integer NOT NULL,
  time integer NOT NULL, type integer NOT NULL);
CREATE TABLE graves (oid integer NOT NULL, type integer NOT NULL, usn integer NOT NULL,
  PRIMARY KEY (oid, type)) WITHOUT ROWID;
CREATE TABLE deck_config (id integer PRIMARY KEY NOT NULL, name text NOT NULL COLLATE unicase,
  mtime_secs integer NOT NULL, usn integer NOT NULL, config blob NOT NULL);
CREATE TABLE config (KEY text NOT NULL PRIMARY KEY, usn integer NOT NULL,
  mtime_secs integer NOT NULL, val blob NOT NULL) WITHOUT ROWID;
CREATE TABLE tags (tag text NOT NULL PRIMARY KEY COLLATE unicase, usn integer NOT NULL,
  collapsed boolean NOT NULL, config blob NULL) WITHOUT ROWID;
CREATE TABLE fields (ntid integer NOT NULL, ord integer NOT NULL, name text NOT NULL COLLATE unicase,
  config blob NOT NULL, PRIMARY KEY (ntid, ord)) WITHOUT ROWID;
CREATE UNIQUE INDEX idx_fields_name_ntid ON fields (name, ntid);
CREATE TABLE templates (ntid integer NOT NULL, ord integer NOT NULL, name text NOT NULL COLLATE unicase,
  mtime_secs integer NOT NULL, usn integer NOT NULL, config blob NOT NULL,
  PRIMARY KEY (ntid, ord)) WITHOUT ROWID;
CREATE TABLE notetypes (id integer NOT NULL PRIMARY KEY, name text NOT NULL COLLATE unicase,
  mtime_secs integer NOT NULL, usn integer NOT NULL, config blob NOT NULL);
CREATE UNIQUE INDEX idx_notetypes_name ON notetypes (name);
CREATE TABLE decks (id integer PRIMARY KEY NOT NULL, name text NOT NULL COLLATE unicase,
  mtime_secs integer NOT NULL, usn integer NOT NULL, common blob NOT NULL, kind blob NOT NULL);
CREATE UNIQUE INDEX idx_decks_name ON decks (name);
CREATE INDEX ix_cards_nid ON cards (nid);
CREATE INDEX ix_revlog_cid ON revlog (cid);
"""


def unicase(a, b):
    a, b = a.lower(), b.lower()
    return (a > b) - (a < b)


def connect(path):
    con = sqlite3.connect(path)
    con.create_collation("unicase", unicase)
    return con


def insert_notes(con, notes):
    for note in notes:
        con.execute(
            "INSERT INTO notes VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            (note["id"], "guid%d" % note["id"], note["mid"], 0, 0, note["tags"],
             "\x1f".join(note["fields"]), note["fields"][0], 0, 0, ""),
        )
        for card in note["cards"]:
            con.execute(
                "INSERT INTO cards VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (card["id"], note["id"], card["did"], card["ord"], 0, 0, card["type"], card["queue"],
                 card["due"], card["ivl"], card["factor"], card["reps"], card["lapses"], 0, 0, 0, 0, ""),
            )
            for revlog_id, ease, kind in card["revlog"]:
                con.execute(
                    "INSERT INTO revlog VALUES (?,?,?,?,?,?,?,?,?)",
                    (revlog_id, card["id"], 0, ease, card["ivl"], 0, card["factor"], 8000, kind),
                )


def legacy_collection(path, notes, conf):
    con = connect(path)
    con.executescript(SCHEMA11)
    models = {
        str(ntid): {
            "id": ntid,
            "name": name,
            "flds": [{"name": f, "ord": i} for i, f in reversed(list(enumerate(fields)))],
            "tmpls": [{"name": t, "ord": i} for i, t in enumerate(templates)],
        }
        for ntid, (name, fields, templates) in NOTETYPES.items()
    }
    decks = {str(did): {"id": did, "name": "::".join(parts)} for did, parts in DECKS.items()}
    con.execute(
        "INSERT INTO col VALUES (1,?,0,0,11,0,0,0,?,?,?,?,?)",
        (CREATION, json.dumps(conf), json.dumps(models), json.dumps(decks), "{}", "{}"),
    )
    insert_notes(con, notes)
    con.commit()
    con.close()


def modern_collection(path, notes):
    con = connect(path)
    con.executescript(SCHEMA18)
    con.execute("PRAGMA journal_mode = WAL")
    con.execute("INSERT INTO col VALUES (1,?,0,0,18,0,0,0,'','','','','')", (CREATION,))
    for key, value in [("schedVer", 2), ("creationOffset", CREATION_MINUTES_WEST),
                       ("sched2021", True), ("curDeck", 1)]:
        con.execute("INSERT INTO config VALUES (?,0,0,?)", (key, json.dumps(value).encode()))
    for ntid, (name, fields, templates) in NOTETYPES.items():
        con.execute("INSERT INTO notetypes VALUES (?,?,0,0,?)", (ntid, name, b""))
        for i, field in enumerate(fields):
            con.execute("INSERT INTO fields VALUES (?,?,?,?)", (ntid, i, field, b""))
        for i, template in enumerate(templates):
            con.execute("INSERT INTO templates VALUES (?,?,?,0,0,?)", (ntid, i, template, b""))
    for did, parts in DECKS.items():
        con.execute("INSERT INTO decks VALUES (?,?,0,0,?,?)", (did, "\x1f".join(parts), b"", b""))
    insert_notes(con, notes)
    con.commit()
    con.close()


def zstd(data):
    return subprocess.run(["zstd", "-q", "-c", "-19"], input=data, stdout=subprocess.PIPE, check=True).stdout


def write_zip(path, entries):
    with zipfile.ZipFile(path, "w") as archive:
        for name, data, method in entries:
            info = zipfile.ZipInfo(name, FIXED_MTIME)
            info.compress_type = method
            archive.writestr(info, data)


def read_bytes(path):
    with open(path, "rb") as handle:
        return handle.read()


def build_packages(work):
    legacy_path = os.path.join(work, "legacy.anki2")
    legacy_collection(legacy_path, NOTES, {
        "schedVer": 2, "rollover": ROLLOVER, "creationOffset": CREATION_MINUTES_WEST,
        "nextPos": 6, "curDeck": 1,
    })
    write_zip(os.path.join(FIXTURES, "legacy.apkg"), [
        ("collection.anki2", read_bytes(legacy_path), zipfile.ZIP_DEFLATED),
        ("media", b"{}", zipfile.ZIP_STORED),
    ])

    dummy_path = os.path.join(work, "dummy.anki2")
    legacy_collection(dummy_path, [DUMMY_NOTE], {"schedVer": 2})
    modern_path = os.path.join(work, "modern.anki21b")
    modern_collection(modern_path, NOTES)
    write_zip(os.path.join(FIXTURES, "modern.apkg"), [
        ("collection.anki2", read_bytes(dummy_path), zipfile.ZIP_DEFLATED),
        ("collection.anki21b", zstd(read_bytes(modern_path)), zipfile.ZIP_STORED),
        ("media", zstd(b""), zipfile.ZIP_STORED),
        ("meta", b"\x08\x03", zipfile.ZIP_STORED),
    ])


TEXT_EXPORT = (
    "#separator:tab\n"
    "#html:true\n"
    "#guid column:1\n"
    "#notetype column:2\n"
    "#deck column:3\n"
    "#tags column:7\n"
    "a1B2c3\tVerse\tVerses::Romans\tRomans 8:28\t\"And we know that in all things God works for the good<br>of those who love him\"\tAssurance\ttms assurance\n"
    "d4E5f6\tBasic\tVerses\t\"He said \"\"Come\"\"\nand follow\"\t{{c1::Peter::who}} &amp; Andrew\t\tdisciples\r\n"
    "\n"
    "g7H8i9\tBasic\tVerses\tPsalm 23:1\tThe <i>Lord</i> is my shepherd,&nbsp;I lack nothing.\t\t\n"
)

TEXT_EXPECTED = {
    "deckNames": ["Verses::Romans", "Verses"],
    "notes": [
        {
            "deck": "Verses::Romans", "noteType": "Verse",
            "fieldNames": ["Field 1", "Field 2", "Field 3"],
            "fields": ["Romans 8:28",
                       "And we know that in all things God works for the good\nof those who love him",
                       "Assurance"],
            "tags": ["tms", "assurance"], "cards": [],
        },
        {
            "deck": "Verses", "noteType": "Basic",
            "fieldNames": ["Field 1", "Field 2"],
            "fields": ["He said \"Come\"\nand follow", "Peter & Andrew"],
            "tags": ["disciples"], "cards": [],
        },
        {
            "deck": "Verses", "noteType": "Basic",
            "fieldNames": ["Field 1", "Field 2"],
            "fields": ["Psalm 23:1", "The Lord is my shepherd, I lack nothing."],
            "tags": [], "cards": [],
        },
    ],
}

TEXT_CASES = [
    {
        "name": "sniffs comma without a header and decodes nothing",
        "input": "Romans 8:28,\"And we know, in all things\"\nJohn 3:16,For God so loved\n",
        "expected": {
            "deckNames": [],
            "notes": [
                {"deck": "", "noteType": "", "fieldNames": ["Field 1", "Field 2"],
                 "fields": ["Romans 8:28", "And we know, in all things"], "tags": [], "cards": []},
                {"deck": "", "noteType": "", "fieldNames": ["Field 1", "Field 2"],
                 "fields": ["John 3:16", "For God so loved"], "tags": [], "cards": []},
            ],
        },
    },
    {
        "name": "sniffs semicolon even when commas appear inside the text",
        "input": "﻿Romans 8:28;And we know, in all things;tms\nJohn 3:16;For God, so loved;gospel\n",
        "expected": {
            "deckNames": [],
            "notes": [
                {"deck": "", "noteType": "", "fieldNames": ["Field 1", "Field 2", "Field 3"],
                 "fields": ["Romans 8:28", "And we know, in all things", "tms"], "tags": [], "cards": []},
                {"deck": "", "noteType": "", "fieldNames": ["Field 1", "Field 2", "Field 3"],
                 "fields": ["John 3:16", "For God, so loved", "gospel"], "tags": [], "cards": []},
            ],
        },
    },
    {
        "name": "plain text keeps markup-looking characters and uses global deck, notetype, tags and column names",
        "input": "#separator:Pipe\n#html:false\n#deck:Memory::OYO\n#notetype:Verse\n#tags:oyo  imported\n#columns:Reference|Verse\nIsaiah 40:31|they will soar on wings like eagles &amp; <run>\n",
        "expected": {
            "deckNames": ["Memory::OYO"],
            "notes": [
                {"deck": "Memory::OYO", "noteType": "Verse", "fieldNames": ["Reference", "Verse"],
                 "fields": ["Isaiah 40:31", "they will soar on wings like eagles &amp; <run>"],
                 "tags": ["oyo", "imported"], "cards": []},
            ],
        },
    },
    {
        "name": "html is detected without a header, a literal separator char works",
        "input": "#separator:^\nJohn 1:1^In the beginning<br>was the Word\n",
        "expected": {
            "deckNames": [],
            "notes": [
                {"deck": "", "noteType": "", "fieldNames": ["Field 1", "Field 2"],
                 "fields": ["John 1:1", "In the beginning\nwas the Word"], "tags": [], "cards": []},
            ],
        },
    },
]

TEXT_ERRORS = [
    {"name": "only headers", "input": "#separator:tab\n#html:true\n", "error": "empty"},
    {"name": "only blank rows", "input": "\n\t\t\n", "error": "empty"},
]

CLEANING = [
    {"input": "a<br>b<br/>c<BR >d", "html": True, "output": "a\nb\nc\nd"},
    {"input": "line1<div>line2</div><div>line3</div>", "html": True, "output": "line1\nline2\nline3"},
    {"input": "<p>One</p><p>Two</p>", "html": True, "output": "One\nTwo"},
    {"input": "<ul><li>a</li><li>b</li></ul>", "html": True, "output": "a\nb"},
    {"input": "x &lt; y &gt; z &amp;&amp; &quot;q&quot; &#39;s&#x27; &apos;", "html": True, "output": "x < y > z && \"q\" 's' '"},
    {"input": "&nbsp;&nbsp;lead&nbsp;&nbsp;trail&#160;", "html": True, "output": "lead trail"},
    {"input": "&mdash;&ndash;&hellip;&lsquo;&rsquo;&ldquo;&rdquo;&unknown; &amp", "html": True, "output": "—–…‘’“”&unknown; &amp"},
    {"input": "&#128512; &#x1F600; &#0; &#xZZ;", "html": True, "output": "\U0001F600 \U0001F600 &#0; &#xZZ;"},
    {"input": "{{c1::Romans 8:28}} and {{c2::grace::hint}} and {{c10::x}}", "html": True, "output": "Romans 8:28 and grace and x"},
    {"input": "{{c1::outer {{c2::inner::h}} end::hint}}", "html": True, "output": "outer inner end"},
    {"input": "{{c1::unterminated and {{notcloze}}", "html": True, "output": "{{c1::unterminated and {{notcloze}}"},
    {"input": "Play [sound:verse.mp3] now [sound:broken", "html": True, "output": "Play now [sound:broken"},
    {"input": "pic <img src=\"a.png\"> here <IMG SRC='b.jpg'/>", "html": True, "output": "pic here"},
    {"input": "<style>.x{color:red}</style>Text<script>alert(1)</script><!-- note -->!", "html": True, "output": "Text!"},
    {"input": "1 < 2 and 3 > 2", "html": True, "output": "1 < 2 and 3 > 2"},
    {"input": "open <b unterminated", "html": True, "output": "open <b unterminated"},
    {"input": "  many    spaces\tand\ttabs  ", "html": True, "output": "many spaces and tabs"},
    {"input": "a\r\nb\rc\n\n\n\n\nd \n e", "html": True, "output": "a\nb\nc\n\nd\ne"},
    {"input": "<div><br></div><div>after blank</div>", "html": True, "output": "after blank"},
    {"input": "<b>bold</b>&amp;<i>it</i>", "html": False, "output": "<b>bold</b>&amp;<i>it</i>"},
    {"input": "{{c1::Plain}} [sound:x.mp3]  text", "html": False, "output": "Plain text"},
]

HTML_DETECTION = [
    {"input": "plain text", "html": False},
    {"input": "1 < 2 > 0", "html": False},
    {"input": "a<br>b", "html": True},
    {"input": "</div>", "html": True},
    {"input": "<!-- c -->", "html": True},
    {"input": "&amp; alone", "html": False},
]


def epoch_day(year, month, day):
    return (datetime.date(year, month, day) - datetime.date(1970, 1, 1)).days


def creation_local_date(minutes_west):
    return (datetime.datetime.utcfromtimestamp(CREATION) - datetime.timedelta(minutes=minutes_west)).date()


def v2_new_day_start(day, creation_minutes_west, current_minutes_west, rollover):
    date = creation_local_date(creation_minutes_west) + datetime.timedelta(days=day)
    days = (date - datetime.date(1970, 1, 1)).days
    return days * 86400 + rollover * 3600 + current_minutes_west * 60


def v2_legacy_day_start(day, current_minutes_west, rollover):
    date = creation_local_date(current_minutes_west)
    days = (date - datetime.date(1970, 1, 1)).days
    return days * 86400 + rollover * 3600 + current_minutes_west * 60 + day * 86400


def v1_day_start(day):
    return CREATION + day * 86400


def last_review_seconds(card):
    reviews = [rid for rid, ease, _ in card["revlog"] if ease > 0]
    return max(reviews) / 1000 if reviews else None


KINDS = ["new", "learning", "review", "relearning"]


def expected_card(card):
    kind = KINDS[card["type"]]
    if kind == "new":
        due = None
    elif card["queue"] in (2, 3) or card["type"] == 2:
        due = v2_new_day_start(card["due"], CREATION_MINUTES_WEST, TIME_ZONE_MINUTES_WEST, ROLLOVER)
    else:
        due = card["due"]
    ivl = card["ivl"]
    return {
        "kind": kind,
        "isSuspended": card["queue"] == -1,
        "intervalDays": float(ivl) if ivl > 0 else (-ivl / 86400 if ivl < 0 else 0.0),
        "ease": card["factor"] / 1000,
        "due": due,
        "reps": card["reps"],
        "lapses": card["lapses"],
        "lastReviewed": last_review_seconds(card),
    }


def deck_of(note):
    first = min(note["cards"], key=lambda c: c["ord"])
    return "::".join(DECKS[first["did"]])


def expected_package():
    notes = []
    deck_names = []
    for note in sorted(NOTES, key=lambda n: n["id"]):
        name, field_names, _ = NOTETYPES[note["mid"]]
        deck = deck_of(note)
        if deck not in deck_names:
            deck_names.append(deck)
        notes.append({
            "deck": deck,
            "noteType": name,
            "fieldNames": field_names,
            "fields": note["expected_fields"],
            "tags": note["tags"].split(),
            "cards": [expected_card(c) for c in sorted(note["cards"], key=lambda c: c["ord"])],
        })
    return {"deckNames": deck_names, "notes": notes}


def schedule_row(type_, queue, due, ivl=0, factor=0, reps=0, lapses=0, odue=0, odid=0, last=None):
    return {"type": type_, "queue": queue, "due": due, "interval": ivl, "factor": factor,
            "reps": reps, "lapses": lapses, "originalDue": odue, "originalDeckID": odid,
            "lastReviewMilliseconds": last}


def timing(creation_minutes_west, current_minutes_west, rollover):
    return {"creation": CREATION, "creationMinutesWest": creation_minutes_west,
            "currentMinutesWest": current_minutes_west, "rolloverHour": rollover}


def schedule_cases():
    sgt = timing(-480, -480, 4)
    moved = timing(-480, 300, 4)
    late_rollover = timing(-480, -480, 23)
    legacy_v2 = timing(None, 300, 4)
    v1 = timing(None, 0, None)
    cases = [
        ("review in creation zone", schedule_row(2, 2, 700, 37, 2350, 9, 1, last=1727000000123), sgt,
         {"kind": "review", "isSuspended": False, "intervalDays": 37.0, "ease": 2.35,
          "due": v2_new_day_start(700, -480, -480, 4), "reps": 9, "lapses": 1, "lastReviewed": 1727000000.123}),
        ("review after moving to UTC-5", schedule_row(2, 2, 700, 37, 2350), moved,
         {"kind": "review", "isSuspended": False, "intervalDays": 37.0, "ease": 2.35,
          "due": v2_new_day_start(700, -480, 300, 4), "reps": 0, "lapses": 0, "lastReviewed": None}),
        ("rollover hour 23", schedule_row(2, 2, 1, 1, 2500), late_rollover,
         {"kind": "review", "isSuspended": False, "intervalDays": 1.0, "ease": 2.5,
          "due": v2_new_day_start(1, -480, -480, 23), "reps": 0, "lapses": 0, "lastReviewed": None}),
        ("v2 without creation offset", schedule_row(2, 2, 10, 5, 2500), legacy_v2,
         {"kind": "review", "isSuspended": False, "intervalDays": 5.0, "ease": 2.5,
          "due": v2_legacy_day_start(10, 300, 4), "reps": 0, "lapses": 0, "lastReviewed": None}),
        ("v1 scheduler", schedule_row(2, 2, 10, 5, 2500), v1,
         {"kind": "review", "isSuspended": False, "intervalDays": 5.0, "ease": 2.5,
          "due": v1_day_start(10), "reps": 0, "lapses": 0, "lastReviewed": None}),
        ("intraday learning", schedule_row(1, 1, 1730000000, 0, 0, 1), sgt,
         {"kind": "learning", "isSuspended": False, "intervalDays": 0.0, "ease": 0.0,
          "due": 1730000000, "reps": 1, "lapses": 0, "lastReviewed": None}),
        ("interday learning", schedule_row(1, 3, 702), sgt,
         {"kind": "learning", "isSuspended": False, "intervalDays": 0.0, "ease": 0.0,
          "due": v2_new_day_start(702, -480, -480, 4), "reps": 0, "lapses": 0, "lastReviewed": None}),
        ("relearning with a seconds interval", schedule_row(3, 1, 1730000600, -600, 2100, 7, 3), sgt,
         {"kind": "relearning", "isSuspended": False, "intervalDays": 600 / 86400, "ease": 2.1,
          "due": 1730000600, "reps": 7, "lapses": 3, "lastReviewed": None}),
        ("suspended learning keeps its timestamp", schedule_row(1, -1, 1730000000), sgt,
         {"kind": "learning", "isSuspended": True, "intervalDays": 0.0, "ease": 0.0,
          "due": 1730000000, "reps": 0, "lapses": 0, "lastReviewed": None}),
        ("buried review is not suspended", schedule_row(2, -2, 700, 37, 2350), sgt,
         {"kind": "review", "isSuspended": False, "intervalDays": 37.0, "ease": 2.35,
          "due": v2_new_day_start(700, -480, -480, 4), "reps": 0, "lapses": 0, "lastReviewed": None}),
        ("new card has no due date", schedule_row(0, 0, 42), sgt,
         {"kind": "new", "isSuspended": False, "intervalDays": 0.0, "ease": 0.0,
          "due": None, "reps": 0, "lapses": 0, "lastReviewed": None}),
        ("filtered deck uses the original due", schedule_row(2, 2, 900, 20, 2500, odue=710, odid=VERSES_DECK), sgt,
         {"kind": "review", "isSuspended": False, "intervalDays": 20.0, "ease": 2.5,
          "due": v2_new_day_start(710, -480, -480, 4), "reps": 0, "lapses": 0, "lastReviewed": None}),
        ("unknown type is treated as new", schedule_row(9, 0, 3), sgt,
         {"kind": "new", "isSuspended": False, "intervalDays": 0.0, "ease": 0.0,
          "due": None, "reps": 0, "lapses": 0, "lastReviewed": None}),
    ]
    return [{"name": n, "row": r, "timing": t, "expected": e} for n, r, t, e in cases]


TIMING_CASES = [
    {"name": "v2 with rollover and offset", "creation": CREATION, "schedulerVersion": 2, "rollover": 5,
     "creationOffset": -480, "deviceMinutesWest": 300,
     "expected": {"creation": CREATION, "creationMinutesWest": -480, "currentMinutesWest": 300, "rolloverHour": 5}},
    {"name": "v2 defaults rollover to 4", "creation": CREATION, "schedulerVersion": 2, "rollover": None,
     "creationOffset": -480, "deviceMinutesWest": -480,
     "expected": {"creation": CREATION, "creationMinutesWest": -480, "currentMinutesWest": -480, "rolloverHour": 4}},
    {"name": "rollover is capped at 23", "creation": CREATION, "schedulerVersion": 3, "rollover": 30,
     "creationOffset": None, "deviceMinutesWest": 0,
     "expected": {"creation": CREATION, "creationMinutesWest": None, "currentMinutesWest": 0, "rolloverHour": 23}},
    {"name": "missing scheduler version is v1", "creation": CREATION, "schedulerVersion": None, "rollover": 4,
     "creationOffset": -480, "deviceMinutesWest": -480,
     "expected": {"creation": CREATION, "creationMinutesWest": None, "currentMinutesWest": -480, "rolloverHour": None}},
]


def dump_section(items):
    return "[\n" + ",\n".join(json.dumps(item, ensure_ascii=False, sort_keys=True) for item in items) + "\n]"


def main():
    os.makedirs(FIXTURES, exist_ok=True)
    with tempfile.TemporaryDirectory() as work:
        build_packages(work)
    with open(os.path.join(FIXTURES, "notes.txt"), "w", encoding="utf-8", newline="") as handle:
        handle.write(TEXT_EXPORT)

    sections = [
        ("description", json.dumps(
            "Anki import reader. Packages and textExport name files in anki/, built by "
            "Scripts/make_anki_fixtures.py. Dates are Unix seconds. timeZoneMinutesWest is the "
            "device zone to read packages with.")),
        ("timeZoneMinutesWest", json.dumps(TIME_ZONE_MINUTES_WEST)),
        ("packages", json.dumps(["anki/legacy.apkg", "anki/modern.apkg"])),
        ("package", json.dumps(expected_package(), ensure_ascii=False, sort_keys=True)),
        ("textExport", json.dumps({"file": "anki/notes.txt", "expected": TEXT_EXPECTED}, ensure_ascii=False, sort_keys=True)),
        ("textCases", dump_section(TEXT_CASES)),
        ("textErrors", dump_section(TEXT_ERRORS)),
        ("cleaning", dump_section(CLEANING)),
        ("htmlDetection", dump_section(HTML_DETECTION)),
        ("schedules", dump_section(schedule_cases())),
        ("timings", dump_section(TIMING_CASES)),
    ]
    body = ",\n".join('"%s": %s' % (key, value) for key, value in sections)
    with open(os.path.join(VECTORS, "anki_import.json"), "w", encoding="utf-8") as handle:
        handle.write("{\n" + body + "\n}\n")


if __name__ == "__main__":
    main()
