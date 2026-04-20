#!/bin/bash

# 获取音量信息
get_audio() {
    local volume=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oP '\d+%' | head -1 | sed 's/%//')
    local muted=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -oP 'Mute: (yes|no)' | grep -oP 'yes')
    local mic_volume=$(pactl get-source-volume @DEFAULT_SOURCE@ | grep -oP '\d+%' | head -1 | sed 's/%//')
    local mic_muted=$(pactl get-source-mute @DEFAULT_SOURCE@ | grep -oP 'Mute: (yes|no)' | grep -oP 'yes')

    if [ "$muted" = "yes" ]; then
        echo "🔇"
    else
        echo "🔊 ${volume}%"
    fi

    if [ "$mic_muted" != "yes" ]; then
        echo "  ${mic_volume}%"
    fi
}

# 获取CPU信息
get_cpu() {
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
    echo "💻 ${cpu_usage}%"
}

# 获取内存信息
get_memory() {
    local mem_usage=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100)}')
    echo "🧠 ${mem_usage}%"
}

# 获取温度信息
get_temperature() {
    local temp=$(sensors | grep -m 1 "Tdie\|Package id 0\|Core 0" | awk '{print $3}' | sed 's/+//;s/°C//')
    if [ -z "$temp" ]; then
        temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000}')
    fi
    echo "🌡️ ${temp}°C"
}

# 获取背光信息
get_backlight() {
    local brightness=$(brightnessctl info 2>/dev/null | grep -oP '\d+%' | head -1 | sed 's/%//')
    if [ -z "$brightness" ]; then
        brightness=$(cat /sys/class/backlight/*/brightness 2>/dev/null | head -1)
        local max=$(cat /sys/class/backlight/*/max_brightness 2>/dev/null | head -1)
        if [ -n "$max" ] && [ "$max" -gt 0 ]; then
            brightness=$((brightness * 100 / max))
        fi
    fi
    echo "💡 ${brightness}%"
}

# 获取电池信息
get_battery() {
    local capacity=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)
    local status=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -1)

    if [ -z "$capacity" ]; then
        echo ""
        return
    fi

    local icon="🔋"
    if [ "$status" = "Charging" ]; then
        icon="🔌"
    elif [ "$capacity" -le 15 ]; then
        icon="🪫"
    elif [ "$capacity" -le 30 ]; then
        icon="🪫"
    fi

    echo "${icon} ${capacity}%"
}

# 获取键盘状态
get_keyboard() {
    local numlock=$(xset q 2>/dev/null | grep "Num Lock" | grep -oP "on|off" | head -1)
    local capslock=$(xset q 2>/dev/null | grep "Caps Lock" | grep -oP "on|off" | head -1)

    local status=""
    if [ "$numlock" = "on" ]; then
        status="${status}N"
    fi
    if [ "$capslock" = "on" ]; then
        status="${status}C"
    fi

    if [ -n "$status" ]; then
        echo "🔒 $status"
    fi
}

# 获取MPD状态
get_mpd() {
    if mpc status >/dev/null 2>&1; then
        local state=$(mpc status | grep -oP 'playing|paused' | head -1)
        local volume=$(mpc volume | grep -oP '\d+%' | head -1)
        
        if [ "$state" = "playing" ]; then
            echo "▶️"
        elif [ "$state" = "paused" ]; then
            echo "⏸️"
        fi
    fi
}

# 获取空闲抑制器状态
get_idle_inhibitor() {
    echo "👁️"
}

# 主输出
output=""

# 添加所有模块
output="${output}$(get_mpd) "
output="${output}$(get_idle_inhibitor) "
output="${output}$(get_audio) | "
output="${output}$(get_cpu) "
output="${output}$(get_memory) "
output="${output}$(get_temperature) "
output="${output}$(get_backlight) "
output="${output}$(get_keyboard) "
output="${output}$(get_battery)"

# 输出JSON格式
echo "{\"text\": \"$output\", \"tooltip\": \"系统信息\"}"