#!/usr/bin/env bash
# Screen recording script for niri (wf-recorder)
# Usage: recorder.sh [region|fullscreen]

set -euo pipefail

MODE="${1:-region}"
SAVE_DIR="$HOME/Videos/Recorder"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT="$SAVE_DIR/recording-${TIMESTAMP}.mp4"
PID_FILE="/tmp/wf-recorder.pid"
AUDIO_MODULE_IDS=()
MIX_SINK_NAME=""

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

    # 混录模式创建的 PipeWire 临时模块必须在退出时释放。
    for ((i = ${#AUDIO_MODULE_IDS[@]} - 1; i >= 0; i--)); do
        pactl unload-module "${AUDIO_MODULE_IDS[i]}" >/dev/null 2>&1 || true
    done
    AUDIO_MODULE_IDS=()
}
trap cleanup EXIT INT TERM

# 检查是否已在录制
if [[ -f "$PID_FILE" ]]; then
    local_pid=$(<"$PID_FILE")
    if kill -0 "$local_pid" 2>/dev/null; then
        echo "⚠ Recording already in progress (PID: $local_pid)"
        echo "Stop the current recording before starting a new one."
        read -rp "Press Enter to exit..."
        exit 1
    fi
    rm -f "$PID_FILE"
fi

# 音频选择
echo "═══════════════════════════════════════"
echo "       🎬 Screen Recording - ${MODE}"
echo "═══════════════════════════════════════"
echo ""
AUDIO_CHOICE=$(printf '%s\n' \
    "No Audio" \
    "System Audio" \
    "Microphone" \
    "System Audio + Microphone" | \
    fzf --prompt="Audio option: " --height=40% --reverse) || {
    echo "Audio selection cancelled."
    exit 0
}

AUDIO_ARGS=()
case "$AUDIO_CHOICE" in
    "System Audio")
        SYSTEM_SOURCE="$(pactl get-default-sink).monitor"
        AUDIO_ARGS=(--audio="$SYSTEM_SOURCE")
        ;;
    "Microphone")
        MIC_SOURCE="$(pactl get-default-source)"
        AUDIO_ARGS=(--audio="$MIC_SOURCE")
        ;;
    "System Audio + Microphone")
        MIX_SINK_NAME="wf_recorder_mix_${UID}_${BASHPID}"
        SYSTEM_SOURCE="$(pactl get-default-sink).monitor"
        MIC_SOURCE="$(pactl get-default-source)"

        MIX_ID=$(pactl load-module module-null-sink \
            "sink_name=$MIX_SINK_NAME" \
            "sink_properties=device.description=$MIX_SINK_NAME")
        AUDIO_MODULE_IDS+=("$MIX_ID")

        SYSTEM_LOOP_ID=$(pactl load-module module-loopback \
            "source=$SYSTEM_SOURCE" "sink=$MIX_SINK_NAME" latency_msec=20)
        AUDIO_MODULE_IDS+=("$SYSTEM_LOOP_ID")

        MIC_LOOP_ID=$(pactl load-module module-loopback \
            "source=$MIC_SOURCE" "sink=$MIX_SINK_NAME" latency_msec=20)
        AUDIO_MODULE_IDS+=("$MIC_LOOP_ID")

        AUDIO_ARGS=(--audio="${MIX_SINK_NAME}.monitor")
        ;;
    *)
        echo "No audio."
        ;;
esac

# 全屏录制必须明确指定输出。若让 wf-recorder 在后台自行询问编号，
# 会和本脚本后续的 Enter 停止操作争抢同一个终端输入流。
OUTPUT_ARGS=()
if [[ "$MODE" == "fullscreen" ]]; then
    echo ""
    echo "Select a display to record..."
    OUTPUT_NAME=$(wf-recorder -L 2>/dev/null | \
        awk '/Name:/ { sub(/^.*Name: /, ""); print $1 }' | \
        sort -u | \
        fzf --prompt="Record display: " --height=40% --reverse) || {
        echo "Display selection cancelled."
        exit 0
    }
    if [[ -z "$OUTPUT_NAME" ]]; then
        echo "No display selected."
        exit 0
    fi
    OUTPUT_ARGS=(-o "$OUTPUT_NAME")
fi

# 区域选择 (仅 region 模式)
GEOMETRY_ARGS=()
if [[ "$MODE" == "region" ]]; then
    echo ""
    echo "Select a region to record with your mouse..."
    GEOMETRY=$(slurp -d 2>/dev/null) || {
        echo "Selection cancelled."
        exit 0
    }
    GEOMETRY_ARGS=(-g "$GEOMETRY")
fi

# 录制前倒计时
echo ""
for i in 3 2 1; do
    echo "  ⏱ Recording starts in ${i}s..."
    notify-send -t 1000 -a "recorder" "Recording" "Starting in ${i}s..." 2>/dev/null || true
    sleep 1
done

echo ""
echo "  🔴 Recording... Output: $OUTPUT"
echo "  📁 Save location: $SAVE_DIR"
echo ""
echo "  Press Enter to stop recording"
echo ""

# 启动 wf-recorder
wf-recorder -f "$OUTPUT" "${OUTPUT_ARGS[@]}" \
    "${GEOMETRY_ARGS[@]}" "${AUDIO_ARGS[@]}" &
WF_PID=$!
echo "$WF_PID" > "$PID_FILE"

# 启动失败时不要继续等待 Enter，也不要误报“录制完成”。
sleep 0.2
if ! kill -0 "$WF_PID" 2>/dev/null; then
    wait "$WF_PID" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "❌ wf-recorder failed to start, no recording file was created." >&2
    exit 1
fi

notify-send -t 3000 -a "recorder" "Recording" "🔴 Recording started" 2>/dev/null || true

# 等待用户按 Enter 停止
read -rp ""

# 停止录制
echo ""
echo "  ⏹ Stopping recording..."
kill -INT "$WF_PID" 2>/dev/null
wait "$WF_PID" 2>/dev/null || true
rm -f "$PID_FILE"

if [[ ! -s "$OUTPUT" ]]; then
    echo "❌ Recording failed: no valid video file was created." >&2
    exit 1
fi

# 录制已经结束，立即释放临时混音模块。
cleanup

echo "  ✅ Recording complete: $OUTPUT"
echo ""

notify-send -t 5000 -a "recorder" "Recording Complete" "✅ Saved to:\n$OUTPUT" 2>/dev/null || true

read -rp "Press Enter to exit..."
