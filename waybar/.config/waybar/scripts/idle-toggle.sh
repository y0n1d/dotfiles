#!/usr/bin/env bash
# Toggle only automatic system sleep (the swayidle timeout).
# Keep this as a high-level "sleep" inhibitor: adding "handle-lid-switch"
# would take lid handling away from logind and prevent lid-close suspend.

set -eu

UNIT="niri-suspend-inhibitor.service"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
TOGGLE_LOCK="$RUNTIME_DIR/niri-suspend-toggle-$UID.lock"

is_inhibited() {
    systemctl --user --quiet is-active "$UNIT" 2>/dev/null
}

print_status() {
    if is_inhibited; then
        printf '%s\n' '{"text":"","class":"inhibited","tooltip":"Auto sleep: inhibited\\nLid-close suspend, lock and screen-off remain active"}'
    else
        printf '%s\n' '{"text":"","class":"enabled","tooltip":"Auto sleep: normal\\nClick to keep remote connections alive; lid close still suspends"}'
    fi
}

toggle() {
    # Serialize rapid clicks so transient-unit start/stop operations cannot race.
    exec 9>"$TOGGLE_LOCK"
    flock 9

    if is_inhibited; then
        systemctl --user --quiet stop "$UNIT"
    else
        # A low-level handle-lid-switch lock must never be added here.
        systemd-run --user --quiet --collect --unit="$UNIT" \
            --property="Description=Prevent automatic suspend for remote access" \
            /usr/bin/systemd-inhibit \
                --what=sleep \
                --who="Waybar suspend toggle" \
                --why="Keep the machine reachable for remote access" \
                --mode=block \
                /usr/bin/sleep infinity
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
