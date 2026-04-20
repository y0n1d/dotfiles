#!/bin/bash

# 获取默认网络接口
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

if [ -z "$INTERFACE" ]; then
    echo "Disconnected ⚠"
    exit 0
fi

# 获取上次的字节数
RX_FILE="/tmp/waybar_rx_$INTERFACE"
TX_FILE="/tmp/waybar_tx_$INTERFACE"

# 如果是第一次运行, 初始化文件
if [ ! -f "$RX_FILE" ] || [ ! -f "$TX_FILE" ]; then
    cat /sys/class/net/"$INTERFACE"/statistics/rx_bytes > "$RX_FILE"
    cat /sys/class/net/"$INTERFACE"/statistics/tx_bytes > "$TX_FILE"
    sleep 1
fi

# 读取当前字节数
RX_CURRENT=$(cat /sys/class/net/"$INTERFACE"/statistics/rx_bytes)
TX_CURRENT=$(cat /sys/class/net/"$INTERFACE"/statistics/tx_bytes)
RX_LAST=$(cat "$RX_FILE")
TX_LAST=$(cat "$TX_FILE")

# 更新记录文件
echo "$RX_CURRENT" > "$RX_FILE"
echo "$TX_CURRENT" > "$TX_FILE"

# 计算速度 (Bytes per second)
RX_SPEED=$((RX_CURRENT - RX_LAST))
TX_SPEED=$((TX_CURRENT - TX_LAST))

# --- 函数：格式化速度为固定宽度 ---
# 格式为 " 1.2M" 或 " 120K" 或 " 500B"，总宽 6 位
format_speed() {
    local speed=$1
    if [ "$speed" -ge 1048576 ]; then
        # MB/s: 保持 4位有效数字 + M，例如 1.2M, 12.5M
        echo "$speed" | awk '{printf "%4.1fM", $1/1048576}'
    elif [ "$speed" -ge 1024 ]; then
        # KB/s
        echo "$speed" | awk '{printf "%4.1fK", $1/1024}'
    else
        # B/s
        echo "$speed" | awk '{printf "%4dB", $1}'
    fi
}

RX_STR=$(format_speed "$RX_SPEED")
TX_STR=$(format_speed "$TX_SPEED")

# 获取IP地址
IP=$(ip addr show "$INTERFACE" | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)

# 获取SSID和信号强度
ESSID=""
SIGNAL_STR="    " # 默认4个空格占位
if [[ "$INTERFACE" == w* ]]; then
    ESSID=$(iwgetid -r 2>/dev/null || echo "WiFi")
    SIGNAL=$(iw dev "$INTERFACE" link 2>/dev/null | grep "signal:" | awk '{print $2}')
    
    if [ -n "$SIGNAL" ]; then
        # 将 dBm 转换为百分比
        SIGNAL_DB=$((SIGNAL + 100))
        if [ $SIGNAL_DB -lt 0 ]; then SIGNAL_DB=0; fi
        if [ $SIGNAL_DB -gt 70 ]; then SIGNAL_DB=100; fi
        if [ $SIGNAL_DB -le 70 ] && [ $SIGNAL_DB -ge 0 ]; then
            SIGNAL_DB=$((SIGNAL_DB * 100 / 70))
        fi
        # 固定信号强度为 4 位宽度 (例如 "100%" 或 " 95%")
        SIGNAL_STR=$(printf "%3d%%" "$SIGNAL_DB")
    fi
fi

# --- 输出格式控制 ---
# 使用箭头符号: ⬇ ⬆ 或 ↓ ↑
DOWN_ICON="▼"
UP_ICON="▲"

if [ -n "$ESSID" ]; then
    # 格式：图标 SSID | 信号 | ⬇ 速度 ⬆ 速度
    # 用 printf 保证整体框架更稳
    printf "  %s |%s | %5s %s/%s %5s\n" "$ESSID" "$SIGNAL_STR" "$RX_STR" "$DOWN_ICON" "$UP_ICON" "$TX_STR"
elif [ -n "$IP" ]; then
    printf "  %s | %s %5s %s %5s\n" "$IP" "$DOWN_ICON" "$RX_STR" "$UP_ICON" "$TX_STR"
else
    echo "Disconnected ⚠"
fi
