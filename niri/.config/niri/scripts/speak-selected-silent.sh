#!/bin/bash
# 使用 GLaDOS Piper 模型朗读当前选中的文本 (静默版)
# 用法:
#   speak-selected-silent.sh            # 朗读 Wayland 主选区内容
#   speak-selected-silent.sh -c         # 朗读剪贴板内容
#   speak-selected-silent.sh "文本"     # 朗读指定文本
#   echo "文本" | speak-selected-silent.sh -  # 从 stdin 读取

set -euo pipefail

MODEL_DIR="$HOME/Files/models"
MODEL="$MODEL_DIR/en_US-glados-medium.onnx"
PIPER="/opt/piper-tts/piper"

[[ ! -f "$MODEL" ]] && exit 1

text=""
if [[ "${1:-}" == "-c" ]]; then
    text=$(wl-paste 2>/dev/null || xclip -selection clipboard -o 2>/dev/null || true)
elif [[ "${1:-}" == "-" ]]; then
    text=$(cat)
elif [[ -n "${1:-}" ]]; then
    text="$1"
else
    text=$(wl-paste -p 2>/dev/null || xclip -selection primary -o 2>/dev/null || true)
fi

[[ -z "$text" ]] && exit 1

echo "$text" | "$PIPER" --model "$MODEL" -f - 2>/dev/null | mpv --no-terminal -
