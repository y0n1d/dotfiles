#!/bin/bash
# network-speed.sh — Waybar network speed module (daemon mode)
#
# Usage:
#   network-speed.sh            # read from daemon, output waybar JSON
#   network-speed.sh daemon     # run as background sampler (auto-started)
#   network-speed.sh --toggle   # toggle compact / detailed mode

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
CACHE_FILE="$RUNTIME_DIR/network-speed-$UID.json"
LOCK_FILE="$RUNTIME_DIR/network-speed-$UID.lock"
PID_FILE="$RUNTIME_DIR/network-speed-$UID.pid"
MODE_FILE="$RUNTIME_DIR/network-display-mode-$UID"

# ── daemon: sample every 1s, write JSON to CACHE_FILE ──────────────
run_daemon() {
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        return 0
    fi
    echo $$ > "$PID_FILE"

    local default_iface="" prev_rx=0 prev_tx=0

    trap 'rm -f "$PID_FILE" "$LOCK_FILE"; exit 0' INT TERM

    while true; do
        local current_iface
        current_iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
        [[ -z "$current_iface" ]] && current_iface="lo"
        if [[ "$current_iface" != "$default_iface" ]]; then
            default_iface="$current_iface"
            prev_rx=0
            prev_tx=0
        fi

        # ── read speed ──
        local rx_bytes tx_bytes rx_speed=0 tx_speed=0
        rx_bytes=$(cat /sys/class/net/"$default_iface"/statistics/rx_bytes 2>/dev/null || echo 0)
        tx_bytes=$(cat /sys/class/net/"$default_iface"/statistics/tx_bytes 2>/dev/null || echo 0)

        if (( prev_rx > 0 )); then
            rx_speed=$(( rx_bytes - prev_rx ))
            tx_speed=$(( tx_bytes - prev_tx ))
        fi
        prev_rx=$rx_bytes
        prev_tx=$tx_bytes

        # ── detect connection type ──
        local iface_type="ethernet" net_icon="󰈀" net_label=""
        local ssid="" signal="" wifi_info=""

        if [[ -d "/sys/class/net/$default_iface/wireless" ]] || \
           [[ -d "/sys/class/net/$default_iface/phy80211" ]]; then
            iface_type="wifi"
            net_icon="󰤨"
            ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | awk -F: '/^yes/{print $2}')
            signal=$(grep "$default_iface" /proc/net/wireless 2>/dev/null | awk '{gsub(/\./, "", $3); print $3"%"}')
            [[ -n "$ssid" ]] && {
                net_label="$ssid"
                wifi_info="│ SSID: $ssid"$'\n'"│ Signal: ${signal:-N/A}"
            }
        else
            # ethernet — show interface name or connection name
            net_label=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null | awk -F: '$2=="'"$default_iface"'"{print $1; exit}')
            [[ -z "$net_label" ]] && net_label="$default_iface"
        fi

        # ── format speed (fixed-width: number always 7 chars, unit 4 chars) ──
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

        # ── class ──
        local class="disconnected"
        if [[ "$default_iface" != "lo" ]] && \
           [[ "$(cat /sys/class/net/"$default_iface"/operstate 2>/dev/null)" == "up" ]]; then
            class=$iface_type
        fi

        # ── build text based on display mode ──
        local mode="compact"
        [[ -f "$MODE_FILE" ]] && mode=$(cat "$MODE_FILE")

        local text alt
        if [[ "$mode" == "detailed" ]]; then
            # detailed: "  SSID  ↓speed ↑speed"
            text="$net_icon $net_label  ↓${dl} ↑${ul}"
            alt="detailed"
        else
            # compact: "↓speed ↑speed"
            text="↓${dl} ↑${ul}"
            alt="compact"
        fi

        # ── write JSON atomically ──
        local tmp="${CACHE_FILE}.tmp.$$"
        jq -c -n \
            --arg text "$text" \
            --arg alt "$alt" \
            --arg dl "$dl" \
            --arg ul "$ul" \
            --arg iface "$default_iface" \
            --arg class "$class" \
            --arg icon "$net_icon" \
            --arg label "$net_label" \
            --arg wifi "$wifi_info" \
            '{
                text: $text,
                alt: $alt,
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

# ── toggle compact / detailed mode ─────────────────────────────────
toggle_mode() {
    if [[ -f "$MODE_FILE" ]] && [[ "$(cat "$MODE_FILE")" == "detailed" ]]; then
        echo "compact" > "$MODE_FILE"
    else
        echo "detailed" > "$MODE_FILE"
    fi
    # force daemon to pick up the change immediately by touching cache
    # (daemon reads MODE_FILE each iteration, no restart needed)
}

# ── main: read CACHE_FILE and output waybar JSON ───────────────────
main() {
    # auto-start daemon if not running
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
    daemon)   run_daemon ;;
    --toggle) toggle_mode ;;
    *)        main ;;
esac
