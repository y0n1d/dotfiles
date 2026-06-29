#!/usr/bin/env bash
# Toggle swayidle for idle inhibition on niri.

STATE_FILE="/tmp/swayidle-inhibited"

case "${1:-status}" in
    toggle)
        if [ -f "$STATE_FILE" ]; then
            rm -f "$STATE_FILE"
            ~/.config/niri/scripts/swayidle.sh &>/dev/null &
        else
            pkill -u "$USER" swayidle
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
