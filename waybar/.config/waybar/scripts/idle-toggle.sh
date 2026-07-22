#!/usr/bin/env bash
# Toggle only system sleep. swayidle keeps handling lock and display power.

set -eu

UNIT="niri-suspend-inhibitor.service"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
TOGGLE_LOCK="$RUNTIME_DIR/niri-suspend-toggle-$UID.lock"

is_inhibited() {
    systemctl --user --quiet is-active "$UNIT" 2>/dev/null
}

print_status() {
    if is_inhibited; then
        printf '%s\n' '{"text":"","class":"inhibited","tooltip":"系统休眠：已抑制\\n自动锁屏与熄屏保持启用"}'
    else
        printf '%s\n' '{"text":"","class":"enabled","tooltip":"系统休眠：正常\\n点击后可在离开时保持远程连接"}'
    fi
}

toggle() {
    # Serialize rapid clicks so transient-unit start/stop operations cannot race.
    exec 9>"$TOGGLE_LOCK"
    flock 9

    if is_inhibited; then
        systemctl --user --quiet stop "$UNIT"
    else
        systemd-run --user --quiet --collect --unit="$UNIT" \
            --property="Description=Prevent system sleep for remote access" \
            /usr/bin/systemd-inhibit \
                --what=sleep:handle-lid-switch \
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
