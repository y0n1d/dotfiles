#!/bin/bash
# network-speed-stacked.sh — Waybar network speed module (stacked layout)
#
# Upload on top, download on bottom:
#   ↑817 B/s
#   ↓1.2 KB/s
#
# Usage:
#   network-speed-stacked.sh            # read from daemon, output waybar JSON
#   network-speed-stacked.sh daemon     # run as background sampler (auto-started)

CACHE_FILE="/tmp/network-speed-stacked.json"
LOCK_FILE="/tmp/network-speed-stacked.lock"
PID_FILE="/tmp/network-speed-stacked.pid"

# ── daemon: sample every 1s, write JSON to CACHE_FILE ──────────────
run_daemon() {
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        return 0
    fi
    echo $$ > "$PID_FILE"

    local default_iface
    default_iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
    [[ -z "$default_iface" ]] && default_iface="lo"

    local prev_rx=0 prev_tx=0

    trap 'rm -f "$PID_FILE" "$LOCK_FILE"; exit 0' INT TERM

    while true; do
        local rx_bytes tx_bytes rx_speed=0 tx_speed=0
        rx_bytes=$(cat /sys/class/net/"$default_iface"/statistics/rx_bytes 2>/dev/null || echo 0)
        tx_bytes=$(cat /sys/class/net/"$default_iface"/statistics/tx_bytes 2>/dev/null || echo 0)

        if (( prev_rx > 0 )); then
            rx_speed=$(( rx_bytes - prev_rx ))
            tx_speed=$(( tx_bytes - prev_tx ))
        fi
        prev_rx=$rx_bytes
        prev_tx=$tx_bytes

        # detect connection type for tooltip
        local iface_type="ethernet" wifi_info=""
        if [[ -d "/sys/class/net/$default_iface/wireless" ]] || \
           [[ -d "/sys/class/net/$default_iface/phy80211" ]]; then
            iface_type="wifi"
            local ssid signal
            ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '/^yes/{print $2}')
            signal=$(grep "$default_iface" /proc/net/wireless 2>/dev/null | awk '{gsub(/\./, "", $3); print $3"%"}')
            [[ -n "$ssid" ]] && wifi_info="│ SSID: $ssid"$'\n'"│ Signal: ${signal:-N/A}"
        fi

        format_speed() {
            local bytes=$1
            if (( bytes >= 1073741824 )); then
                printf "%7.2f GB/s" "$(echo "$bytes / 1073741824" | bc -l)"
            elif (( bytes >= 1048576 )); then
                printf "%7.2f MB/s" "$(echo "$bytes / 1048576" | bc -l)"
            elif (( bytes >= 1024 )); then
                printf "%7.1f KB/s" "$(echo "$bytes / 1024" | bc -l)"
            else
                printf "%7.0f  B/s" "$bytes"
            fi
        }

        local dl ul
        dl=$(format_speed "$rx_speed")
        ul=$(format_speed "$tx_speed")

        local class="disconnected"
        if [[ "$default_iface" != "lo" ]] && \
           [[ "$(cat /sys/class/net/"$default_iface"/operstate 2>/dev/null)" == "up" ]]; then
            class=$iface_type
        fi

        local NL=$'\n'
        local text="↑${ul}${NL}↓${dl}"

        local tmp="${CACHE_FILE}.tmp.$$"
        jq -c -n \
            --arg text "$text" \
            --arg dl "$dl" \
            --arg ul "$ul" \
            --arg iface "$default_iface" \
            --arg class "$class" \
            --arg wifi "$wifi_info" \
            '{
                text: $text,
                tooltip: (
                    "Interface: \($iface)\n" +
                    "Download: \($dl)\nUpload: \($ul)" +
                    (if $wifi != "" then "\n\($wifi)" else "" end)
                ),
                class: $class,
                percentage: 0
            }' > "$tmp" && mv -f "$tmp" "$CACHE_FILE"

        sleep 1
    done
}

main() {
    if ! flock -n "$LOCK_FILE" true 2>/dev/null; then
        :
    else
        run_daemon >/dev/null 2>&1 &
        disown
        local i=0
        while [[ ! -f "$CACHE_FILE" ]] && [ "$i" -lt 5 ]; do
            sleep 0.2
            i=$((i + 1))
        done
    fi

    local out
    out=$(jq -c . "$CACHE_FILE" 2>/dev/null)
    if [ -n "$out" ]; then
        printf '%s' "$out"
    else
        echo '{"text":"Loading…","class":"disconnected","tooltip":"Waiting for daemon"}'
    fi
}

case "${1:-}" in
    daemon) run_daemon ;;
    *)      main ;;
esac
