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

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
CACHE_FILE="$RUNTIME_DIR/network-speed-stacked-$UID.json"
LOCK_FILE="$RUNTIME_DIR/network-speed-stacked-$UID.lock"
PID_FILE="$RUNTIME_DIR/network-speed-stacked-$UID.pid"

# Format a per-second byte count with fixed width. Pure integer arithmetic —
# the old `bc` pipeline silently rendered 0.00 when bc was missing and forked
# twice per sample.
format_speed() {
    local bytes=$1 unit scale pad fmt frac frac_str
    if (( bytes >= 1073741824 )); then
        unit=1073741824 scale=100 pad="%02d" fmt="%7.2f GB/s"
    elif (( bytes >= 1048576 )); then
        unit=1048576 scale=100 pad="%02d" fmt="%7.2f MB/s"
    elif (( bytes >= 1024 )); then
        unit=1024 scale=10 pad="%01d" fmt="%7.1f KB/s"
    else
        printf "%7d  B/s" "$bytes"
        return
    fi
    frac=$(( ( (bytes % unit) * scale + unit / 2 ) / unit ))
    if (( frac >= scale )); then # rounded up across the unit boundary
        printf "$fmt" "$((bytes / unit + 1)).00"
        return
    fi
    printf -v frac_str "$pad" "$frac"
    printf "$fmt" "$((bytes / unit)).$frac_str"
}

# ── daemon: sample every 1s, write JSON to CACHE_FILE ──────────────
run_daemon() {
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        return 0
    fi
    # BASHPID, not $$: run_daemon executes in a background subshell where $$
    # still expands to the transient main script, which is already gone.
    echo "$BASHPID" > "$PID_FILE"

    local default_iface="" prev_rx=0 prev_tx=0 prev_us=0

    # Never unlink the lock file: flock() locks the inode, so removing it on
    # exit lets a replacement daemon lock a fresh file while this one is still
    # alive, running two samplers against one cache.
    trap 'rm -f "$PID_FILE"; exit 0' INT TERM

    while true; do
        local current_iface
        current_iface=$(ip route 2>/dev/null | awk '/^default/{print $5; exit}')
        [[ -z "$current_iface" ]] && current_iface="lo"
        if [[ "$current_iface" != "$default_iface" ]]; then
            default_iface="$current_iface"
            prev_rx=0
            prev_tx=0
        fi

        # ── read speed, normalized by the real elapsed time ──
        local rx_bytes tx_bytes rx_speed=0 tx_speed=0
        # The loop interval drifts past 1s (nmcli and other per-loop work), so
        # divide the counter delta by the measured microseconds instead of
        # assuming exactly one second.
        local stamp=${EPOCHREALTIME} frac now_us
        frac="${stamp#*.}000000"
        now_us=$(( ${stamp%%.*} * 1000000 + 10#${frac:0:6} ))
        rx_bytes=$(cat /sys/class/net/"$default_iface"/statistics/rx_bytes 2>/dev/null || echo 0)
        tx_bytes=$(cat /sys/class/net/"$default_iface"/statistics/tx_bytes 2>/dev/null || echo 0)

        if (( prev_rx > 0 && prev_us > 0 )); then
            local elapsed=$(( now_us - prev_us ))
            (( elapsed <= 0 )) && elapsed=1000000
            rx_speed=$(( (rx_bytes - prev_rx) * 1000000 / elapsed ))
            tx_speed=$(( (tx_bytes - prev_tx) * 1000000 / elapsed ))
            # A counter reset on the same interface (down/up) would otherwise
            # show a negative rate.
            (( rx_speed < 0 )) && rx_speed=0
            (( tx_speed < 0 )) && tx_speed=0
        fi
        prev_rx=$rx_bytes
        prev_tx=$tx_bytes
        prev_us=$now_us

        # detect connection type for tooltip
        local iface_type="ethernet" wifi_info="" ssid="" signal=""
        if [[ -d "/sys/class/net/$default_iface/wireless" ]] || \
           [[ -d "/sys/class/net/$default_iface/phy80211" ]]; then
            iface_type="wifi"
            local wifi_line
            while IFS= read -r wifi_line; do
                if [[ "$wifi_line" =~ ^yes:(.*):([0-9]+)$ ]]; then
                    ssid=${BASH_REMATCH[1]}
                    signal="${BASH_REMATCH[2]}%"
                    break
                fi
            done < <(
                # --rescan no: the default "auto" can trigger a Wi-Fi scan that
                # stalls this 1s loop for several seconds.
                nmcli -t --escape no -f ACTIVE,SSID,SIGNAL \
                    device wifi list --rescan no ifname "$default_iface" 2>/dev/null
            )
            if [[ -z "$signal" ]]; then
                signal=$(grep "$default_iface" /proc/net/wireless 2>/dev/null |
                    awk '{gsub(/\./, "", $3); print $3"%"}')
            fi
            [[ -n "$ssid" ]] && wifi_info="│ SSID: $ssid"$'\n'"│ Signal: ${signal:-N/A}"
        fi

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
            --arg ssid "$ssid" \
            --arg signal "$signal" \
            '{
                text: $text,
                tooltip: (
                    "Interface: \($iface)\n" +
                    "Download: \($dl)\nUpload: \($ul)" +
                    (if $wifi != "" then "\n\($wifi)" else "" end)
                ),
                class: $class,
                ssid: $ssid,
                signal: $signal,
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
