#!/usr/bin/env bash

# Only one idle policy should run per user.  Using a lock avoids killing
# unrelated swayidle processes and lets a crashed process release the lock
# automatically.
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$UID}"
LOCK_FILE="$RUNTIME_DIR/niri-swayidle-$UID.lock"
export NIRI_AUTO_SUSPEND_STATE="$RUNTIME_DIR/niri-auto-suspend-inhibited"

if [[ ! -d "$RUNTIME_DIR" || ! -w "$RUNTIME_DIR" ]]; then
    printf 'Runtime directory is unavailable: %s\n' "$RUNTIME_DIR" >&2
    exit 1
fi

# 定义锁屏样式（保持你的自定义配色）
# 注意：添加了 -f (daemonize)，这对 swayidle 连续触发后续任务至关重要
LOCK_CMD="swaylock -f \
    --screenshots \
    --clock \
    --indicator \
    --indicator-radius 200 \
    --indicator-thickness 6 \
    --effect-blur 20x3 \
    --effect-vignette 0.1:0.4 \
    --ring-color b19cd9 \
    --key-hl-color a2d2ff \
    --text-color ffffff \
    --line-color 00000000 \
    --inside-color ffffff22 \
    --separator-color 00000000 \
    --fade-in 0.3 \
    --ring-clear-color e9edc9 \
    --inside-clear-color fff4e644 \
    --ring-ver-color a2d2ff \
    --inside-ver-color a2d2ff44 \
    --ring-wrong-color ffccd5 \
    --inside-wrong-color ffccd544"

# `swayidle -w` keeps the logind delay inhibitor until `swaylock -f` reports
# that the session is locked. This also protects explicit suspend/hibernate
# requests such as `systemctl hibernate`.
#
# Lock and power off the displays independently of the automatic-suspend toggle.
# The Waybar toggle creates NIRI_AUTO_SUSPEND_STATE, which only skips the
# 20-minute idle action and does not inhibit manual sleep or lid-close suspend.
exec flock --nonblock --close "$LOCK_FILE" \
    swayidle -w \
    timeout 300  "$LOCK_CMD" \
    timeout 500  'niri msg action power-off-monitors' \
    resume       'niri msg action power-on-monitors' \
    timeout 1200 '[ -e "$NIRI_AUTO_SUSPEND_STATE" ] || systemctl --check-inhibitors=yes suspend' \
    before-sleep "$LOCK_CMD" \
    after-resume 'niri msg action power-on-monitors' \
    lock         "$LOCK_CMD" \
    unlock 'paplay $HOME/.local/share/sounds/intro.mp3'
