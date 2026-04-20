#!/bin/bash
# 启动swayidle的脚本

# 先杀死可能存在的swayidle进程
pkill swayidle

# 等待片刻
sleep 0.5

# 启动swayidle（在后台运行）
swayidle -w \
    timeout 300 'swaylock -f -c 000000' \
    timeout 330 'swaymsg "output * dpms off"' \
    timeout 600 'systemctl suspend' \
    resume 'swaymsg "output * dpms on"' \
    before-sleep 'swaylock -f -c 000000' &