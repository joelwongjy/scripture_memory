#!/usr/bin/env python3
import re
import sys
from pathlib import Path

ICONS = {
    "arrow_clockwise": "regular/arrow-clockwise",
    "arrow_counter_clockwise": "regular/arrow-counter-clockwise",
    "arrow_elbow_down_right": "regular/arrow-elbow-down-right",
    "arrow_line_up": "regular/arrow-line-up",
    "arrow_u_up_left": "regular/arrow-u-up-left",
    "arrows_clockwise": "regular/arrows-clockwise",
    "bell": "regular/bell",
    "book_fill": "fill/book-fill",
    "book_open_fill": "fill/book-open-text-fill",
    "book": "regular/book",
    "bookmark_fill": "fill/bookmark-simple-fill",
    "calendar": "regular/calendar-dots",
    "caret_down": "bold/caret-down-bold",
    "caret_left": "bold/caret-left-bold",
    "caret_right": "bold/caret-right-bold",
    "caret_up_down": "bold/caret-up-down-bold",
    "cards": "regular/cards",
    "cards_fill": "fill/cards-fill",
    "cards_slash": "regular/selection-slash",
    "chart_bar": "regular/chart-bar",
    "check": "bold/check-bold",
    "check_circle": "regular/check-circle",
    "check_circle_fill": "fill/check-circle-fill",
    "circle": "regular/circle",
    "eye": "regular/eye",
    "eye_fill": "fill/eye-fill",
    "eye_slash": "regular/eye-slash",
    "fire_fill": "fill/fire-fill",
    "flag_fill": "fill/flag-fill",
    "gear": "regular/gear-six",
    "gear_fill": "fill/gear-six-fill",
    "house": "regular/house",
    "house_fill": "fill/house-fill",
    "keyboard": "regular/keyboard",
    "lightbulb": "regular/lightbulb",
    "list": "regular/list",
    "magnifying_glass": "regular/magnifying-glass",
    "magnifying_glass_bold": "bold/magnifying-glass-bold",
    "microphone": "regular/microphone",
    "microphone_fill": "fill/microphone-fill",
    "minus": "bold/minus-bold",
    "minus_circle_fill": "fill/minus-circle-fill",
    "moon_fill": "fill/moon-fill",
    "play_fill": "fill/play-fill",
    "plus": "bold/plus-bold",
    "push_pin": "regular/push-pin",
    "push_pin_fill": "fill/push-pin-fill",
    "push_pin_slash": "regular/push-pin-slash",
    "seal_check_fill": "fill/seal-check-fill",
    "star": "regular/star",
    "star_fill": "fill/star-fill",
    "sparkle": "regular/sparkle",
    "stack": "regular/stack",
    "stack_fill": "fill/stack-fill",
    "target": "regular/target",
    "target_fill": "fill/target-fill",
    "trash": "regular/trash",
    "x": "bold/x-bold",
}

source = Path(sys.argv[1])
out = Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
for name, rel in ICONS.items():
    svg = (source / f"{rel}.svg").read_text()
    paths = re.findall(r'<path[^>]*\sd="([^"]+)"', svg)
    body = "\n".join(
        f'    <path android:fillColor="#FF000000" android:pathData="{d}" />' for d in paths
    )
    (out / f"ic_{name}.xml").write_text(
        '<vector xmlns:android="http://schemas.android.com/apk/res/android"\n'
        '    android:width="24dp" android:height="24dp"\n'
        '    android:viewportWidth="256" android:viewportHeight="256">\n'
        f"{body}\n</vector>\n"
    )
print(f"{len(ICONS)} icons")
