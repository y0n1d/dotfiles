#!/usr/bin/env bash

# 使用 niri msg 监听窗口焦点变化
# 注意：这需要 niri 运行中
niri msg --json focused-window | jq -r '.title // "Empty"' | zscroll \
    --length 25 \
    --delay 0.3 \
    --match-command "niri msg --json focused-window | jq -r '.title // \"Empty\"'" \
    --update-check true &

wait
