#!/bin/bash
# Smoke test for the cleanup branch. Screenshots + UI dumps land in results/.
source .github/smoke/lib.sh
boot_simulator

# --- Seed: onboarded, first 4 verses of 5 Assurances learnt (cursor on #5,
# the last card of the pack), Home opens the learning verse in Review.
pref hasOnboardedLearning.v1 -bool true
pref identity.cardUidMigration.v1 -bool true
pref learning.learntKeys.v1 -array fb7aabf3e66b755f 01fc8d676ac96c6c c91123b93df2df7e b8e7f6a946673b5c
pref homeVerseStartMode.v1 -string review
pref studyMode -string submit

launch 8
shot home

# --- Tabs render
for tab in Packs Quiz Settings; do tap_label "=$tab" && shot "tab-$tab"; done
tap_label "=Home"

answer_card() {   # Entire Verse: type an (imperfect) answer and submit it
  axe type "for god so loved" --udid "$UDID" > /dev/null; sleep 1
  tap_label "=Submit" "" 2
}

open_link() {     # iOS asks before opening a custom-scheme link
  openurl "$1" 3
  tap_label "=Open" "" 4 || tap_xy 275 474 4
}

# --- Fix 3: swipe past the last card of a pack crosses into the next pack
tap_label "Practice" "" 3 && shot "learning-review-last-card"
swipe 340 380 40 380 2.5
shot "after-swipe-forward"
grep -i "TMS 60\|5 Assurances" "results/$(ls results | grep after-swipe-forward.labels.txt)" | head -5 | tee -a results/log.txt
tap_label "=Close" || tap_label "Back to reading"
shot "home-after-learning"

# --- Fix 2 part 1: start a quiz, answer one card, leave it
tap_label "=Quiz"
tap_label "Up to current verse" && shot "quiz-selected"
tap_label "=Start" "" 4 && shot "quiz-session-start"
answer_card
shot "quiz-one-card-done"
tap_label "Close session" "" 2
shot "quiz-tab-after-leaving"

# --- Fix 1: daily review, rating labels on a learnt-but-unscheduled verse
open_link "scripturememory://review"
shot "review-start"
answer_card
shot "review-rating-buttons"
tap_label "Close session" "" 2

# --- Fix 2 part 2: the quiz is still there with its progress
tap_label "=Quiz"
shot "quiz-tab-after-review"
tap_label "Session in Progress" "" 3 && shot "quiz-resumed"
tap_label "Close session" "" 2

log "done"
