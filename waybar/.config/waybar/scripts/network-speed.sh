#!/bin/bash

command -v ip &>/dev/null || { echo "No ip"; exit 1; }
# 切换显示模式
toggle_mode() {
    local mode_file="/tmp/waybar_network_mode"
    if [ "$(cat "$mode_file" 2>/dev/null)" = "full" ]; then
        echo "compact" > "$mode_file"
    else
        echo "full" > "$mode_file"
    fi
}

# 支持传入 --toggle 参数
[ "$1" = "--toggle" ] && { toggle_mode; exit 0; }


INTERFACE=$(ip route show default 2>/dev/null | awk '{print $5; exit}')

if [ -z "$INTERFACE" ] || [ ! -d "/sys/class/net/$INTERFACE" ]; then
    echo "Disconnected ⚠"
    exit 0
fi

STAT_DIR="/sys/class/net/$INTERFACE/statistics"
RX_FILE="/tmp/waybar_rx_$INTERFACE"
TX_FILE="/tmp/waybar_tx_$INTERFACE"

# read 替代 cat，省一次 fork
read -r RX_CURRENT < "$STAT_DIR/rx_bytes" 2>/dev/null || { echo "⚠"; exit 0; }
read -r TX_CURRENT < "$STAT_DIR/tx_bytes" 2>/dev/null || { echo "⚠"; exit 0; }

if [ -f "$RX_FILE" ] && [ -f "$TX_FILE" ]; then
    read -r RX_LAST < "$RX_FILE"
    read -r TX_LAST < "$TX_FILE"
    RX_SPEED=$(( RX_CURRENT - RX_LAST ))
    TX_SPEED=$(( TX_CURRENT - TX_LAST ))
    (( RX_SPEED < 0 )) && RX_SPEED=0
    (( TX_SPEED < 0 )) && TX_SPEED=0
else
    RX_SPEED=0
    TX_SPEED=0
fi

echo "$RX_CURRENT" > "$RX_FILE"
echo "$TX_CURRENT" > "$TX_FILE"

# 单次 awk 格式化两个值，减少一次 fork
read -r RX_STR TX_STR <<< "$(awk -v rx="$RX_SPEED" -v tx="$TX_SPEED" 'BEGIN {
    if (rx>=1048576) r=sprintf("%4.1fM",rx/1048576); else if (rx>=1024) r=sprintf("%4.1fK",rx/1024); else r=sprintf("%4dB",rx)
    if (tx>=1048576) t=sprintf("%4.1fM",tx/1048576); else if (tx>=1024) t=sprintf("%4.1fK",tx/1024); else t=sprintf("%4dB",tx)
    print r, t
}')"

# 网络信息
ESSID=""
SIGNAL_STR=""
if [[ "$INTERFACE" == w* ]]; then
    IP=$(ip addr show "$INTERFACE" 2>/dev/null | awk '/inet / {split($2,a,"/"); print a[1]; exit}')
    ESSID=$(iwgetid -r 2>/dev/null || echo "WiFi")
    SIGNAL=$(iw dev "$INTERFACE" link 2>/dev/null | awk '/signal:/ {print $2}')
    [ -n "$SIGNAL" ] && SIGNAL_STR="${SIGNAL}dBm"
else
    IP=$(ip addr show "$INTERFACE" 2>/dev/null | awk '/inet / {split($2,a,"/"); print a[1]; exit}')
fi

DOWN_ICON="▼"
UP_ICON="▲"

# 读取显示模式（默认 compact）
MODE_FILE="/tmp/waybar_network_mode"
[ -f "$MODE_FILE" ] && MODE=$(cat "$MODE_FILE") || MODE="compact"

if [ -n "$ESSID" ]; then
    if [ "$MODE" = "full" ]; then
        printf "  %s | %s | %5s %s/%s %5s\n" "$ESSID" "$SIGNAL_STR" "$RX_STR" "$DOWN_ICON" "$UP_ICON" "$TX_STR"
    else
        printf "  %5s %s/%s %5s\n" "$RX_STR" "$DOWN_ICON" "$UP_ICON" "$TX_STR"
    fi
elif [ -n "$IP" ]; then
    if [ "$MODE" = "full" ]; then
        printf "  %s | %s %5s %s %5s\n" "$IP" "$DOWN_ICON" "$RX_STR" "$UP_ICON" "$TX_STR"
    else
        printf "  %5s %s/%s %5s\n" "$RX_STR" "$DOWN_ICON" "$UP_ICON" "$TX_STR"
    fi
else
    echo "Disconnected ⚠"
fi