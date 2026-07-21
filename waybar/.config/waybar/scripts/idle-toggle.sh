#!/usr/bin/env bash
# Toggle swayidle for idle inhibition on niri.

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
STATE_FILE="$RUNTIME_DIR/swayidle-inhibited-$UID"

case "${1:-status}" in
    toggle)
        if [ -f "$STATE_FILE" ]; then
            rm -f "$STATE_FILE"
            "$HOME/.config/niri/scripts/swayidle.sh" &>/dev/null &
        else
            pkill -u "${USER:?USER is required}" -x swayidle || true
            touch "$STATE_FILE"
        fi
        sleep 0.2
        pkill -RTMIN+8 waybar
        ;;
    status)
        if [ -f "$STATE_FILE" ]; then
            echo ""
        else
            echo ""
        fi
        ;;
esac
