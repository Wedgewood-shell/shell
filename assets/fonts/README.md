`BatteryDigits.ttf` is SN Pro (SIL OFL 1.1, see `OFL.txt`) instanced at weight 600,
subset to 0-9 with overlaps removed and renamed so it can't clash with an installed
copy. It is the closest free match to SF Pro Rounded's figures (footless 1, 8 with a
smaller top loop). Used for the percentage cut out of the bar's battery icon.

`build_battery_digits.py` rebuilds it and regenerates `components/BatteryHoles.js`,
the regions each percentage's halo encloses (filled in the outline colour). Rerun it
if the font, halo, size or tracking in `BatteryIndicator.qml` change.
