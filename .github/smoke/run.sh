#!/bin/bash
# QA run: scenario checks with assertions (iPhone) and the wide-window tour (iPad).
source .github/smoke/lib.sh
: > results/assertions.txt

expect() {   # expect "what" "regex"
  local text; text=$(axe describe-ui --udid "$UDID" 2>/dev/null | python3 .github/smoke/alltext.py)
  if echo "$text" | grep -Eq -- "$2"; then echo "PASS | $1" | tee -a results/assertions.txt
  else echo "FAIL | $1 | wanted /$2/ | saw: $(echo "$text" | head -40 | tr '\n' '~' | cut -c1-500)" | tee -a results/assertions.txt; fi
}
expect_not() {   # expect_not "what" "regex"
  local text; text=$(axe describe-ui --udid "$UDID" 2>/dev/null | python3 .github/smoke/alltext.py)
  if echo "$text" | grep -Eq -- "$2"; then echo "FAIL | $1 | found /$2/" | tee -a results/assertions.txt
  else echo "PASS | $1" | tee -a results/assertions.txt; fi
}
due_is() { echo "^$1\$|(^|[^0-9])$1,? cards? due"; }
fact() { python3 -c "import json,sys; print(json.load(open('results/facts-$1.json'))['$2'])"; }
fresh_install() { xcrun simctl uninstall "$UDID" "$BUNDLE" 2>/dev/null; xcrun simctl install "$UDID" "$APP"; }
open_review() { openurl "scripturememory://review" 3; tap_label "=Open" "" 4 || true; }
answer() { axe type "for god so loved" --udid "$UDID" > /dev/null; sleep 1; tap_label "=Submit" "" 2; }

boot_simulator

if [ "$DEVICE" = iphone ]; then
  # ── Scenario 1: 119 verses learnt, cursor on verse 120 ─────────────────────
  python3 .github/smoke/seed.py "$UDID" far > results/facts-far.json; cat results/facts-far.json
  launch 8
  shot far-home
  expect "Home shows the current verse (#120), not verse 1" "$(fact far cursor_ref)"
  expect "Home's position reads like the pack position" "$(fact far cursor_pos)"
  expect "Daily review: 7 due (5 already-known + 2 new)" "$(due_is 7)"
  expect "Breakdown: 5 Review" "5 Review"
  expect "Breakdown: 2 New" "2 New"
  open_review; shot far-review-first-card
  expect "Review starts with the most recent known verse (#119)" "$(fact far first_review_ref)"
  expect_not "Review doesn't start from verse 1" "1 John 5:11-12"
  tap_label "Close session" "" 2
  # Pack opens at the current verse, keeps place across open/back and reopen
  tap_label "=Packs"; tap_label "$(fact far cursor_pack)" "" 3; shot far-pack-opens
  expect "Pack opens on the current verse" "$(fact far cursor_pos)"
  tap_label "$(fact far tap_ref)" "" 3; shot far-tapped-card
  expect "Tapping a card opens that card" "$(fact far tap_pos)"
  tap_label "Back to reading" "" 3; shot far-back-to-list
  expect "Back returns to the same place in the list" "$(fact far tap_pos)"
  tap_label "=Close" "" 2
  tap_label "$(fact far cursor_pack)" "" 3; shot far-pack-reopened
  expect "Reopening the pack lands where you left it" "$(fact far tap_pos)"
  tap_label "=Close" "" 2

  # ── Scenario 2: exact due counts, rating, undo, streak ─────────────────────
  fresh_install
  python3 .github/smoke/seed.py "$UDID" due > results/facts-due.json; cat results/facts-due.json
  launch 8
  tap_label "=Home" "" 1 || true
  shot due-home
  expect "Daily review: 10 due (3 learning + 5 review cap + 2 new)" "$(due_is 10)"
  expect "Breakdown: 3 Learning" "3 Learning"
  expect "Breakdown: 5 Review (capped from 7)" "5 Review"
  expect "Streak not yet earned today (opening the app doesn't count)" "0 day streak"
  open_review; shot due-review-start
  expect "Review session has 10 cards" "1 of 10"
  answer; shot due-answered
  tap_label "=Good" "" 1; tap_label "=Confirm" "" 3; shot due-after-confirm
  expect "Confirm moves to the next card" "2 of 10"
  tap_label "Undo last rating" "" 3; shot due-after-undo
  expect "Undo goes back to the rated card" "1 of 10"
  tap_label "=Good" "" 1; tap_label "=Confirm" "" 3
  tap_label "Close session" "" 3; shot due-celebration
  expect "Streak celebration appears after leaving the session" "day streak!"
  tap_label "=Continue" "" 2; shot due-home-after
  expect "Home count drops by the one card rated (10 -> 9)" "$(due_is 9)"
  expect "Streak is now 1 day" "1 day streak"
  tap_label "1 day streak" "" 3; shot streak-screen
  expect "Streak screen shows best streak" "Best streak"
  expect "Streak screen shows today as done" "practised today"
else
  # ── Wide window (stand-in for iPhone Duo's inner display) ──────────────────
  python3 .github/smoke/seed.py "$UDID" far > results/facts-far.json
  launch 8
  tour() {
    tap_label "=Home" "" 1 || true; shot "home$1"
    tap_label "day streak" "" 3 && shot "streak$1"; tap_label "=Home" "" 2 || tap_label "Back" "" 2
    tap_label "=Packs" && shot "packs$1"
    tap_label "$(fact far cursor_pack)" "" 3 && shot "pack-read$1"
    tap_label "=Review" "" 2 && shot "pack-review$1"
    tap_label "=Close" "" 2 || tap_label "Back to reading" "" 1; tap_label "=Close" "" 2
    tap_label "=Quiz" && shot "quiz$1"
    tap_label "=Settings" && shot "settings$1"
    tap_label "=Home"; open_review; shot "review$1"; tap_label "Close session" "" 2
  }
  tour "-portrait"
  rotate
  tour "-landscape"
fi
log done
echo "== $(grep -c '^PASS' results/assertions.txt) passed, $(grep -c '^FAIL' results/assertions.txt) failed"
