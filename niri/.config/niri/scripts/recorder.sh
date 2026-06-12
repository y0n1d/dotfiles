#!/usr/bin/env bash
# Screen recording script for niri (wf-recorder)
# Usage: recorder.sh [region|fullscreen]

set -euo pipefail

MODE="${1:-region}"
SAVE_DIR="$HOME/Videos/Recorder"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT="$SAVE_DIR/recording-${TIMESTAMP}.mp4"
PID_FILE="/tmp/wf-recorder.pid"

# 确保保存目录存在
mkdir -p "$SAVE_DIR"

# 清理函数
cleanup() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(<"$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi
}
trap cleanup EXIT INT TERM

# 检查是否已在录制
if [[ -f "$PID_FILE" ]]; then
    local_pid=$(<"$PID_FILE")
    if kill -0 "$local_pid" 2>/dev/null; then
        echo "⚠ 已有录制进程 (PID: $local_pid)"
        echo "如需重新录制，请先结束当前录制。"
        read -rp "按 Enter 退出..."
        exit 1
    fi
    rm -f "$PID_FILE"
fi

# 音频选择
echo "═══════════════════════════════════════"
echo "       🎬 屏幕录制 - ${MODE}"
echo "═══════════════════════════════════════"
echo ""
AUDIO_CHOICE=$(echo -e "无音频\n默认输入设备\n选择输入设备" | fzf --prompt="音频选项: " --height=40% --reverse)

AUDIO_ARGS=""
case "$AUDIO_CHOICE" in
    "默认输入设备")
        AUDIO_ARGS="--audio=default"
        ;;
    "选择输入设备")
        # 列出 PulseAudio 输入设备
        DEVICE=$(pactl list sources short | fzf --prompt="选择设备: " --height=40% --reverse | awk '{print $2}')
        if [[ -n "$DEVICE" ]]; then
            AUDIO_ARGS="--audio=$DEVICE"
        else
            echo "未选择设备，将不录音。"
        fi
        ;;
    *)
        echo "不录音。"
        ;;
esac

# 区域选择 (仅 region 模式)
GEOMETRY_ARGS=()
if [[ "$MODE" == "region" ]]; then
    echo ""
    echo "请用鼠标选择录屏区域..."
    GEOMETRY=$(slurp -d 2>/dev/null) || {
        echo "取消选择。"
        exit 0
    }
    GEOMETRY_ARGS=(-g "$GEOMETRY")
fi

# 录制前倒计时
echo ""
for i in 3 2 1; do
    echo "  ⏱ ${i} 秒后开始录制..."
    notify-send -t 1000 -a "recorder" "录屏" "${i} 秒后开始录制..." 2>/dev/null || true
    sleep 1
done

echo ""
echo "  🔴 录制中... 输出: $OUTPUT"
echo "  📁 保存位置: $SAVE_DIR"
echo ""
echo "  按 Enter 停止录制"
echo ""

# 启动 wf-recorder
# shellcheck disable=SC2086
wf-recorder -f "$OUTPUT" "${GEOMETRY_ARGS[@]}" $AUDIO_ARGS &
WF_PID=$!
echo "$WF_PID" > "$PID_FILE"

notify-send -t 3000 -a "recorder" "录屏" "🔴 录制已开始" 2>/dev/null || true

# 等待用户按 Enter 停止
read -rp ""

# 停止录制
echo ""
echo "  ⏹ 停止录制..."
kill -INT "$WF_PID" 2>/dev/null
wait "$WF_PID" 2>/dev/null || true
rm -f "$PID_FILE"

echo "  ✅ 录制完成: $OUTPUT"
echo ""

notify-send -t 5000 -a "recorder" "录屏完成" "✅ 已保存到:\n$OUTPUT" 2>/dev/null || true

read -rp "按 Enter 退出..."
