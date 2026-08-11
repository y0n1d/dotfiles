#!/usr/bin/env bash
# Cycle idle modes for the niri session.
#   0 = enabled      — lock + DPMS + suspend
#   1 = inhibited    — lock + DPMS, no suspend
#   2 = presentation — no idle actions, screen stays on
#
# Manual suspend, hibernate and lid-close remain unaffected by the mode value;
# idle-action.sh handles the semantics of each mode.

set -eu

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
MODE_FILE="$RUNTIME_DIR/niri-idle-mode"
TOGGLE_LOCK="$RUNTIME_DIR/niri-idle-toggle-$UID.lock"

if [[ ! -d "$RUNTIME_DIR" || ! -w "$RUNTIME_DIR" ]]; then
    printf 'Runtime directory is unavailable: %s\n' "$RUNTIME_DIR" >&2
    exit 1
fi

read_mode() {
    local mode
    mode=$(cat "$MODE_FILE" 2>/dev/null || true)
    case "$mode" in
        0|1|2) printf '%s\n' "$mode" ;;
        *)     printf '0\n' ;;
    esac
}

write_mode() {
    local mode=$1
    local temporary="$MODE_FILE.tmp.$$"

    # Replace the state atomically so idle callbacks never observe a file
    # truncated between opening it and writing the new mode.
    umask 077
    printf '%s\n' "$mode" > "$temporary"
    mv -f -- "$temporary" "$MODE_FILE"
}

print_status() {
    local mode
    mode=$(read_mode)
    case "$mode" in
        0)
            printf '%s\n' '{"text":"󰒲 ","class":"enabled","tooltip":"Idle mode: enabled\\nLock 5min  |  DPMS 8min  |  Suspend 20min\\nClick to cycle"}'
            ;;
        1)
            printf '%s\n' '{"text":"󰒳 ","class":"inhibited","tooltip":"Idle mode: inhibited\\nLock 5min  |  DPMS 8min  |  Suspend disabled\\nClick to cycle"}'
            ;;
        2)
            printf '%s\n' '{"text":"󰛨 ","class":"presentation","tooltip":"Idle mode: presentation\\nNo idle actions  |  screen stays on\\nClick to cycle"}'
            ;;
    esac
}

cycle() {
    # Serialize rapid clicks so state changes cannot race.
    exec 9>"$TOGGLE_LOCK"
    flock 9

    local mode
    mode=$(read_mode)
    case "$mode" in
        0) write_mode 1 ;;
        1) write_mode 2 ;;
        2) write_mode 0 ;;
    esac

    # Ask only this user's Waybar process to refresh the module immediately.
    pkill -u "$UID" -RTMIN+8 -x waybar || true
}

case "${1:-status}" in
    status)
        print_status
        ;;
    cycle)
        cycle
        ;;
    *)
        printf 'Usage: %s [status|cycle]\n' "$0" >&2
        exit 2
        ;;
esac
