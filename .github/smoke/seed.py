"""Seed the app's saved progress for a test scenario, and print facts about the
catalogue the assertions need. Usage: seed.py <udid> <scenario>"""
import json, subprocess, sys, time

udid, scenario = sys.argv[1], sys.argv[2]
BUNDLE = "joel.scripture-memory"
packs = json.load(open("scripture memory/Resources/verseData.json"))
ordered = [(p["name"], i, v) for p in packs for i, v in enumerate(p["verses"])]

def w(*args):
    subprocess.run(["xcrun", "simctl", "spawn", udid, "defaults", "write", BUNDLE, *args], check=True)

def data(key, obj):
    w(key, "-data", json.dumps(obj, separators=(",", ":")).encode().hex())

REF = 978307200  # seconds between 1970 and 2001 (Foundation's reference date)
now = time.time() - REF

def state(uid, phase, due_offset, interval=0, step=0):
    return {"key": uid, "phase": phase, "interval": interval, "ease": 2.5, "reps": 1 if phase == "review" else 0,
            "lapses": 0, "learningStep": step, "due": now + due_offset}

w("hasOnboardedLearning.v1", "-bool", "true")
w("identity.cardUidMigration.v1", "-bool", "true")
w("studyMode", "-string", "submit")
facts = {}

if scenario == "far":
    learnt = [v["cardUid"] for _, _, v in ordered[:119]]
    w("learning.learntKeys.v1", "-array", *learnt)
    cur_pack, cur_i, cur = ordered[119]
    _, _, last_known = ordered[118]
    new1, new2 = ordered[119][2], ordered[120][2]
    pack_len = len(next(p for p in packs if p["name"] == cur_pack)["verses"])
    facts = {"cursor_ref": f'{cur["book"]} {cur["reference"]}', "cursor_pack": cur_pack,
             "cursor_pos": f"{cur_i + 1} of {pack_len}", "first_review_ref": f'{last_known["book"]} {last_known["reference"]}',
             "tap_ref": f'{ordered[121][2]["book"]} {ordered[121][2]["reference"]}', "tap_pos": f"{ordered[121][1] + 1} of {pack_len}"}

elif scenario == "due":
    learnt = [v["cardUid"] for _, _, v in ordered[:10]]
    w("learning.learntKeys.v1", "-array", *learnt)
    states = {}
    for _, _, v in ordered[0:3]:  states[v["cardUid"]] = state(v["cardUid"], "learning", -60)
    for _, _, v in ordered[3:10]: states[v["cardUid"]] = state(v["cardUid"], "review", -3600, interval=3)
    for _, _, v in ordered[10:12]: states[v["cardUid"]] = state(v["cardUid"], "review", 5 * 86400, interval=6)
    data("srs.cardStates.v1", states)
    facts = {"expect_total": 3 + 5 + 2, "learning": 3, "review": 5, "new": 2}

print(json.dumps(facts))
