#!/usr/bin/env bash

# Only one idle policy should run per user.  Using a lock avoids killing
# unrelated swayidle processes and lets a crashed process release the lock
# automatically.
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
LOCK_FILE="$RUNTIME_DIR/niri-swayidle-$UID.lock"

if [[ ! -d "$RUNTIME_DIR" || ! -w "$RUNTIME_DIR" ]]; then
    printf 'Runtime directory is unavailable: %s\n' "$RUNTIME_DIR" >&2
    exit 1
fi

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
ACTION="$SCRIPT_DIR/idle-action.sh"
BACKLIGHT_ACTION="$SCRIPT_DIR/backlight-sleep.sh"

# `swayidle -w` keeps the logind delay inhibitor until `swaylock -f` reports
# that the session is locked.  This also protects explicit suspend/hibernate
# requests such as `systemctl hibernate`.
#
# All callbacks delegate to idle-action.sh which reads the idle mode from
# $XDG_RUNTIME_DIR/niri-idle-mode and decides whether to execute.
exec flock --nonblock --close "$LOCK_FILE" \
    swayidle -w \
    timeout 300  "$ACTION lock" \
    timeout 500  "$ACTION dpms-off" \
    resume       "$ACTION dpms-on" \
    timeout 1200 "$ACTION suspend" \
    before-sleep "\"$BACKLIGHT_ACTION\" save; \"$ACTION\" lock" \
    after-resume "\"$ACTION\" dpms-on; sleep 0.5; \"$BACKLIGHT_ACTION\" restore" \
    lock         "$ACTION lock" \
    unlock       "$ACTION unlock"
