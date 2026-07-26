#!/usr/bin/env bash
# Toggle only the automatic suspend triggered by swayidle after 20 minutes.
# Manual suspend/hibernate and logind lid handling must remain unaffected.

set -eu

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
AUTO_SUSPEND_STATE="$RUNTIME_DIR/niri-auto-suspend-inhibited"
TOGGLE_LOCK="$RUNTIME_DIR/niri-suspend-toggle-$UID.lock"

if [[ ! -d "$RUNTIME_DIR" || ! -w "$RUNTIME_DIR" ]]; then
    printf 'Runtime directory is unavailable: %s\n' "$RUNTIME_DIR" >&2
    exit 1
fi

is_inhibited() {
    [[ -e "$AUTO_SUSPEND_STATE" ]]
}

print_status() {
    if is_inhibited; then
        printf '%s\n' '{"text":"","class":"inhibited","tooltip":"20-minute auto suspend: inhibited\\nManual suspend, hibernate and lid close remain active"}'
    else
        printf '%s\n' '{"text":"","class":"enabled","tooltip":"20-minute auto suspend: enabled\\nClick to keep remote connections alive"}'
    fi
}

toggle() {
    # Serialize rapid clicks so state changes cannot race.
    exec 9>"$TOGGLE_LOCK"
    flock 9

    if is_inhibited; then
        rm -f -- "$AUTO_SUSPEND_STATE"
    else
        umask 077
        : > "$AUTO_SUSPEND_STATE"
    fi

    # Ask only this user's Waybar process to refresh the module immediately.
    pkill -u "$UID" -RTMIN+8 -x waybar || true
}

case "${1:-status}" in
    status)
        print_status
        ;;
    toggle)
        toggle
        ;;
    *)
        printf 'Usage: %s [status|toggle]\n' "$0" >&2
        exit 2
        ;;
esac
