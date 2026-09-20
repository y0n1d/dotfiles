#!/usr/bin/env bash
# Save backlight levels before system sleep and restore them after resume.

set -euo pipefail

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
STATE_DIR="$RUNTIME_DIR/niri-backlight-state"

if [[ ! -d "$RUNTIME_DIR" || ! -w "$RUNTIME_DIR" ]]; then
    printf 'Runtime directory is unavailable: %s\n' "$RUNTIME_DIR" >&2
    exit 1
fi

umask 077

log_message() {
    logger --tag niri-backlight -- "$*" 2>/dev/null || true
}

case "${1:-}" in
    save)
        mkdir -p -- "$STATE_DIR"
        chmod 700 -- "$STATE_DIR"

        saved=0
        for backlight in /sys/class/backlight/*; do
            [[ -e "$backlight" ]] || continue

            device="${backlight##*/}"
            if read -r value < "$backlight/brightness" &&
                [[ "$value" =~ ^[0-9]+$ ]]; then
                printf '%s\n' "$value" > "$STATE_DIR/$device"
                log_message "saved $device=$value"
                saved=$((saved + 1))
            fi
        done

        if (( saved == 0 )); then
            log_message "no backlight device found while saving"
            printf 'No backlight device found\n' >&2
            exit 1
        fi
        ;;

    restore)
        [[ -d "$STATE_DIR" ]] || {
            log_message "no saved backlight state found"
            exit 0
        }

        status=0
        for state_file in "$STATE_DIR"/*; do
            [[ -f "$state_file" ]] || continue

            device="${state_file##*/}"
            backlight="/sys/class/backlight/$device"
            [[ -e "$backlight" ]] || continue

            if ! read -r value < "$state_file" ||
                ! read -r max_value < "$backlight/max_brightness"; then
                continue
            fi

            [[ "$value" =~ ^[0-9]+$ ]] || continue
            [[ "$max_value" =~ ^[0-9]+$ ]] || continue
            (( value <= max_value )) || continue

            if brightnessctl --quiet --class=backlight \
                --device="$device" set "$value"; then
                log_message "restored $device=$value"
            else
                log_message "failed to restore $device=$value"
                printf 'Failed to restore backlight device: %s\n' "$device" >&2
                status=1
            fi
        done

        exit "$status"
        ;;

    *)
        printf 'Usage: %s <save|restore>\n' "$0" >&2
        exit 2
        ;;
esac
