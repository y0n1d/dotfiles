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

# 如果是第一次运行,初始化文件
if [ ! -f "$RX_FILE" ] || [ ! -f "$TX_FILE" ]; then
    echo $(cat /sys/class/net/$INTERFACE/statistics/rx_bytes) > $RX_FILE
    echo $(cat /sys/class/net/$INTERFACE/statistics/tx_bytes) > $TX_FILE
    sleep 1
fi

# 读取当前字节数
RX_CURRENT=$(cat /sys/class/net/$INTERFACE/statistics/rx_bytes)
TX_CURRENT=$(cat /sys/class/net/$INTERFACE/statistics/tx_bytes)

# 读取上次字节数
RX_LAST=$(cat $RX_FILE)
TX_LAST=$(cat $TX_FILE)

# 计算时间差(秒)
TIME_DIFF=1

# 计算速度(B/s)
RX_SPEED=$((($RX_CURRENT - $RX_LAST) / $TIME_DIFF))
TX_SPEED=$((($TX_CURRENT - $TX_LAST) / $TIME_DIFF))

# 转换为更易读的格式
if [ $RX_SPEED -gt 1048576 ]; then
    RX_STR=$(echo "scale=1; $RX_SPEED / 1048576" | bc)M
elif [ $RX_SPEED -gt 1024 ]; then
    RX_STR=$(echo "scale=1; $RX_SPEED / 1024" | bc)K
else
    RX_STR=${RX_SPEED}B
fi

if [ $TX_SPEED -gt 1048576 ]; then
    TX_STR=$(echo "scale=1; $TX_SPEED / 1048576" | bc)M
elif [ $TX_SPEED -gt 1024 ]; then
    TX_STR=$(echo "scale=1; $TX_SPEED / 1024" | bc)K
else
    TX_STR=${TX_SPEED}B
fi

# 更新文件
echo $RX_CURRENT > $RX_FILE
echo $TX_CURRENT > $TX_FILE

# 获取IP地址
IP=$(ip addr show $INTERFACE | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)

# 获取SSID和信号强度(仅WiFi)
ESSID=""
SIGNAL=""
if [[ "$INTERFACE" == wlp* ]]; then
    ESSID=$(iwgetid -r 2>/dev/null || echo "")
    SIGNAL=$(iw dev "$INTERFACE" link 2>/dev/null | grep "signal:" | awk '{print $2}' | sed 's/ dBm//')
    if [ -n "$SIGNAL" ]; then
        # 将 dBm 转换为百分比 (假设 -30dBm = 100%, -100dBm = 0%)
        SIGNAL_DB=$((SIGNAL + 100))
        if [ $SIGNAL_DB -lt 0 ]; then
            SIGNAL_DB=0
        elif [ $SIGNAL_DB -gt 70 ]; then
            SIGNAL_DB=100
        else
            SIGNAL_DB=$((SIGNAL_DB * 100 / 70))
        fi
        SIGNAL="${SIGNAL_DB}%"
    fi
fi

# 输出格式
if [ -n "$ESSID" ]; then
    if [ -n "$SIGNAL" ]; then
        echo " $ESSID|$SIGNAL|$RX_STR/$TX_STR"
    else
        echo " $ESSID|$RX_STR/$TX_STR"
    fi
elif [ -n "$IP" ]; then
    echo " $IP $RX_STR/$TX_STR"
else
    echo "Disconnected ⚠"
fi
