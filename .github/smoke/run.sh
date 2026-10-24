#!/bin/bash
# Design tour after the design pass. DEVICE=iphone or ipad (stand-in for Duo inner).
source .github/smoke/lib.sh
boot_simulator
pref hasOnboardedLearning.v1 -bool true
pref identity.cardUidMigration.v1 -bool true
pref learning.learntKeys.v1 -array fb7aabf3e66b755f 01fc8d676ac96c6c c91123b93df2df7e b8e7f6a946673b5c
launch 8

search_clip() {
  record_start "search-$1"
  tap_label "Search verses" "" 1.5
  axe type "love" --udid "$UDID" > /dev/null; sleep 1.5
  tap_label "=Cancel" "" 1.5 || tap_label "=Close" "" 1.5
  record_stop
}

tour() {   # $1 = suffix
  tap_label "=Home" "" 1 || true
  shot "home$1"
  tap_label "=Packs" && shot "packs$1"
  tap_label "5 Assurances" "" 2 && shot "pack-read-list$1"
  tap_label "=Review" "" 2 && shot "pack-review-card$1"
  tap_label "=Close" "" 2 || tap_label "Back to reading" "" 1; tap_label "=Close" "" 2
  tap_label "=Quiz" && shot "quiz$1"
  tap_label "=Settings" && shot "settings$1"
  tap_label "=Home"
  openurl "scripturememory://review" 3; tap_label "=Open" "" 4 || true
  shot "review-session$1"
  tap_label "Close session" "" 2
}

shot home
if [ "$DEVICE" = iphone ]; then
  search_clip home
  tap_label "=Packs" && search_clip packs
  tour ""
  # Search-bar experiment: same clip without the mount-delay workaround.
  xcrun simctl terminate "$UDID" "$BUNDLE"; xcrun simctl launch "$UDID" "$BUNDLE" -SMNoMountDelay > /dev/null; sleep 8
  shot home-nodelay
  search_clip home-nodelay
  tap_label "=Packs" && search_clip packs-nodelay
else
  tour "-portrait"
  rotate
  tour "-landscape"
fi
log done
