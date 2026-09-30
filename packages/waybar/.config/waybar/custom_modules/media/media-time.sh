#!/usr/bin/env bash
# 歌曲进度（waybar: custom/media-time, return-type: json）
# 每秒一次轮询：
#   无播放器/元数据 → {"text":""} → 配合 hide-empty-text 直接隐藏模块，不残留旧文本
#   有播放器 → {"text":"0:32/3:14","class":"playing"|"paused"}
#   非 Playing（暂停/停止）→ class=paused → CSS 变暗，与歌名模块同节奏(≈1s)换色，
#   一眼区分"暂停中"
#
# --player musicfox,playerctld：钉住音乐播放器。不指定时 playerctl 选"最近活跃"的,
# 浏览器放个视频就会显示成视频进度(如 0:15/23:40), musicfox 不在时回退 playerctld。
# PLAYERS 环境变量可覆盖（测试用）。
PLAYERS=${PLAYERS:-musicfox,playerctld}

line=$(playerctl --player "$PLAYERS" metadata \
    --format '{{status}}|{{duration(position)}}/{{duration(mpris:length)}}' 2>/dev/null)

# 无输出，或输出里没有状态分隔符（异常/老格式）→ 空文本，模块隐藏
if [ -z "$line" ] || [ "${line#*|}" = "$line" ]; then
    printf '{"text":""}\n'
    exit 0
fi

status=${line%%|*}
text=${line#*|}

if [ "$status" = "Playing" ]; then
    printf '{"text":"%s","class":"playing"}\n' "$text"
else
    printf '{"text":"%s","class":"paused"}\n' "$text"
fi
