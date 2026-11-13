#!/bin/sh
# Stream raw touchpad swipe events from libinput (read-only; the compositor
# keeps handling them). Only gesture-capable devices are opened, so keyboards
# are never read. Requires membership of the `input` group.
#
#   B <fingers>        swipe began
#   U <dx> <dy>        unaccelerated delta, as niri sees it (before natural scroll)
#   E <0|1>            swipe ended (1 = cancelled)

devices=$(libinput list-devices 2>/dev/null | awk '
    /^Kernel:/ { kernel = $2 }
    /^Capabilities:/ && /gesture/ { print kernel }')
[ -n "$devices" ] || exit 2

set --
for device in $devices; do
    set -- "$@" --device "$device"
done

exec stdbuf -oL libinput debug-events "$@" | awk '
    /GESTURE_SWIPE_BEGIN/ { print "B", $NF; fflush(); next }
    /GESTURE_SWIPE_END/   { print "E", ($0 ~ /cancelled/ ? 1 : 0); fflush(); next }
    /GESTURE_SWIPE_UPDATE/ {
        gsub(/[()\/]/, " ")
        print "U", $(NF - 2), $(NF - 1)
        fflush()
    }'
