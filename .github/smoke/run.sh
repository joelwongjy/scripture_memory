#!/bin/bash
# Pouch tour: open TMS 60 on card 30, open the pouch, turn cards, fold it.
source .github/smoke/lib.sh
boot_simulator
python3 .github/smoke/seed.py "$UDID" pouch
launch 8

# Centre "x y" of an element by label.
where() { axe describe-ui --udid "$UDID" 2>/dev/null | python3 .github/smoke/find.py "$1"; }

tour() {   # tour SUFFIX
  local s=$1
  tap_label "=Packs" "" 2; tap_label "TMS 60" "" 3; shot "$s-pack"
  record_start "$s-open-and-turn"
  tap_label "Open in pouch" "" 0.15; shot "$s-pouch-closed" 0
  sleep 0.25; shot "$s-pouch-opening" 0
  sleep 2; shot "$s-pouch-open" 0
  xy=$(where "Card 30 of 60") || xy=$(where "pouch")
  cx=${xy% *}; cy=${xy#* }
  if [ "$DEVICE" = ipad ]; then low=$((cy + 230)); reach=$((cy - 260)); hi=$((cy - 180)); else low=$((cy + 140)); reach=$((cy - 170)); hi=$((cy - 110)); fi
  axe swipe --start-x "$cx" --start-y "$low" --end-x "$cx" --end-y "$reach" --duration 1.2 --udid "$UDID" > /dev/null; sleep 1.5
  shot "$s-turned-forward" 0
  tap_xy "$cx" "$low" 1.5; shot "$s-turned-twice" 0
  tap_xy "$cx" "$hi" 1.5; shot "$s-turned-back" 0
  record_stop
  record_start "$s-fold"
  tap_label "Fold the pouch" "" 0.3; shot "$s-folding" 0
  sleep 1.5; shot "$s-folded" 0
  tap_label "Open the pouch" "" 2
  record_stop
  tap_label "=Close" "" 2; shot "$s-back-on-pack"
  tap_label "=Close" "" 2
}

tour light
xcrun simctl ui "$UDID" appearance dark; sleep 2
tour dark
