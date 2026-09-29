#!/usr/bin/env bash
# 摄像头占用检测 → waybar custom/camera 模块 (return-type: json)
#
# waybar 的 privacy 模块只监听 Stream/Input/Video (屏幕共享流),
# 摄像头设备节点 (Video/Source) 和直接 V4L2 打开都不会触发它,
# 所以用 fuser 轮询 /dev/video* 与 /dev/media* 的持有者来补齐监控。
# 空闲时输出空 text, 由 "hide-empty-text": true 隐藏整个模块。

set -u

devs=()
for d in /dev/video* /dev/media*; do
    [[ -e "$d" ]] && devs+=("$d")
done

if ((${#devs[@]} == 0)); then
    printf '{"text": "", "tooltip": "无摄像头设备"}\n'
    exit 0
fi

if fuser -s "${devs[@]}" 2>/dev/null; then
    procs=$(fuser -v "${devs[@]}" 2>&1 \
        | awk 'NR > 1 && NF >= 2 { print $NF }' \
        | sort -u | paste -sd' ' -)
    jq -nc --arg p "${procs:-unknown}" \
        '{text: " 󰄀 ", class: "active", tooltip: ("摄像头占用中: " + $p)}'
else
    printf '{"text": "", "tooltip": "摄像头空闲"}\n'
fi
