#!/bin/bash
# 启动swayidle的脚本

# 先杀死可能存在的swayidle进程
pkill swayidle

# 等待片刻
sleep 0.5

# 定义复杂的swaylock命令变量
# 注意：删除了末尾多余的重复字符和数字23
LOCK_CMD="swaylock \
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

# 启动swayidle（在后台运行）
swayidle -w \
    timeout 300 "$LOCK_CMD" \
    timeout 330 'swaymsg "output * dpms off"' \
    timeout 600 'systemctl suspend' \
    resume 'swaymsg "output * dpms on"' \
    before-sleep "$LOCK_CMD" &
