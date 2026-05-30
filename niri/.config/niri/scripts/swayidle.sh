#!/usr/bin/env bash

# 1. 防止重复运行：杀掉之前已经存在的 swayidle 进程
# 使用 -u $USER 确保只杀死当前用户的进程，避免干扰其他用户
pkill -u $USER swayidle

# 给系统一小段缓冲时间确保进程已退出
sleep 1

# 2. 定义锁屏样式（保持你的自定义配色）
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
    --grace 2 \
    --fade-in 0.3 \
    --ring-clear-color e9edc9 \
    --inside-clear-color fff4e644 \
    --ring-ver-color a2d2ff \
    --inside-ver-color a2d2ff44 \
    --ring-wrong-color ffccd5 \
    --inside-wrong-color ffccd544"

# 3. 运行 swayidle
swayidle -w \
    timeout 300  "$LOCK_CMD" \
    timeout 500  'niri msg action power-off-monitors' \
    resume       'niri msg action power-on-monitors' \
    timeout 1200 'systemctl suspend' \
    before-sleep "$LOCK_CMD" \
    after-resume 'niri msg action power-on-monitors' \
    lock         "$LOCK_CMD" \
    unlock 'paplay $HOME/.local/share/sounds/intro.mp3'
