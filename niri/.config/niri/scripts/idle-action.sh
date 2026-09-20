#!/usr/bin/env bash
# Unified idle action dispatcher for swayidle callbacks.
# Reads the current idle mode from $XDG_RUNTIME_DIR/niri-idle-mode:
#   0 = enabled     — all actions active (default)
#   1 = inhibited   — suspend disabled, lock and DPMS active
#   2 = presentation — all idle actions disabled, screen stays on
#
# Usage: idle-action.sh <lock|dpms-off|dpms-on|suspend|unlock>

set -eu

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
MODE_FILE="$RUNTIME_DIR/niri-idle-mode"

read_mode() {
    local mode
    mode=$(cat "$MODE_FILE" 2>/dev/null || true)
    case "$mode" in
        0|1|2) printf '%s\n' "$mode" ;;
        *)     printf '0\n' ;;
    esac
}

MODE=$(read_mode)
ACTION="${1:-}"

case "$ACTION" in
    lock|dpms-off|dpms-on|suspend|unlock) ;;
    *)
        printf 'Usage: %s <lock|dpms-off|dpms-on|suspend|unlock>\n' "$0" >&2
        exit 2
        ;;
esac

LOCK_OPTS=(
    --screenshots
    --clock
    --indicator
    --indicator-radius 200
    --indicator-thickness 6
    --effect-blur 20x3
    --effect-vignette 0.1:0.4
    --ring-color b19cd9
    --key-hl-color a2d2ff
    --text-color ffffff
    --line-color 00000000
    --inside-color ffffff22
    --separator-color 00000000
    --fade-in 0.3
    --ring-clear-color e9edc9
    --inside-clear-color fff4e644
    --ring-ver-color a2d2ff
    --inside-ver-color a2d2ff44
    --ring-wrong-color ffccd5
    --inside-wrong-color ffccd544
)

case "$ACTION" in
    lock)
        [[ "$MODE" == 2 ]] && exit 0
        swaylock -f "${LOCK_OPTS[@]}"
        ;;
    dpms-off)
        [[ "$MODE" == 2 ]] && exit 0
        niri msg action power-off-monitors
        ;;
    dpms-on)
        # Waking a display is a recovery action, not an idle action.  Keep it
        # available in presentation mode as well, especially after resume.
        niri msg action power-on-monitors
        ;;
    suspend)
        # Only the normal mode permits swayidle's timeout-based suspend.
        # This does not install an inhibitor, so lid-close and explicit sleep
        # requests continue to be handled normally by logind in every mode.
        [[ "$MODE" != 0 ]] && exit 0
        systemctl --check-inhibitors=yes suspend
        ;;
    unlock)
        [[ "$MODE" == 2 ]] && exit 0
        paplay "$HOME/.local/share/sounds/intro.mp3"
        ;;
esac
