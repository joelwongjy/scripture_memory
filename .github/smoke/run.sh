#!/bin/bash
# Design tour: screenshots of every main screen + recordings of the search bar.
source .github/smoke/lib.sh
boot_simulator
pref hasOnboardedLearning.v1 -bool true
pref identity.cardUidMigration.v1 -bool true
pref learning.learntKeys.v1 -array fb7aabf3e66b755f 01fc8d676ac96c6c c91123b93df2df7e b8e7f6a946673b5c
launch 8

search_clip() {   # $1 = screen name
  record_start "search-$1"
  tap_label "Search verses" "" 1.5
  axe type "love" --udid "$UDID" > /dev/null; sleep 1.5
  tap_label "=Cancel" "" 1.5 || tap_label "Close" "" 1.5
  record_stop
}

shot home
search_clip home
tap_label "=Packs" && shot packs
search_clip packs
tap_label "5 Assurances" "" 2 && shot pack-read-list
tap_label "=Review" "" 2 && shot pack-review-card
tap_label "Reveal next word" "" 1; tap_label "Reveal next word" "" 1; shot pack-review-hinted
tap_label "=Close" "" 2 || tap_label "Back to reading" "" 1; tap_label "=Close" "" 2
tap_label "=Quiz" && shot quiz
tap_label "Expand TMS 60" "" 1.5 && shot quiz-expanded
tap_label "=Settings" && shot settings
axe swipe --start-x 200 --start-y 700 --end-x 200 --end-y 200 --udid "$UDID" > /dev/null; sleep 1; shot settings-scrolled
tap_label "=Home" && tap_label "Reviewing all" "" 2 && shot packs-in-review
tap_label "=Home" "" 1 || true
openurl "scripturememory://review" 3; tap_label "=Open" "" 4 || tap_xy 275 474 4
shot review-session
record_start review-swipe
axe swipe --start-x 340 --start-y 420 --end-x 40 --end-y 420 --udid "$UDID" > /dev/null; sleep 1.5
record_stop
log done
