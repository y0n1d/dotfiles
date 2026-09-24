#!/bin/bash
# network-info.sh — Waybar SSID and Wi-Fi signal module
#
# Usage:
#   network-info.sh            # read metadata from the stacked speed cache
#   network-info.sh --toggle   # toggle this module, then refresh Waybar

RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
CACHE_FILE="$RUNTIME_DIR/network-speed-stacked-$UID.json"
STATE_FILE="$RUNTIME_DIR/network-info-visible-$UID"

toggle_visibility() {
    local current="visible" next="hidden"
    if [[ -r "$STATE_FILE" ]]; then
        read -r current < "$STATE_FILE"
    fi
    [[ "$current" == "hidden" ]] && next="visible"

    local tmp="${STATE_FILE}.tmp.$$"
    printf '%s\n' "$next" > "$tmp" && mv -f "$tmp" "$STATE_FILE"

    # Refresh every Waybar instance immediately. Only modules using signal 8
    # react to this real-time signal.
    pkill -RTMIN+8 -x waybar 2>/dev/null || true
}

wifi_icon() {
    local signal_value=$1
    if (( signal_value >= 80 )); then
        printf '󰤨'
    elif (( signal_value >= 60 )); then
        printf '󰤥'
    elif (( signal_value >= 40 )); then
        printf '󰤢'
    elif (( signal_value >= 20 )); then
        printf '󰤟'
    else
        printf '󰤯'
    fi
}

main() {
    local visibility="visible"
    if [[ -r "$STATE_FILE" ]]; then
        read -r visibility < "$STATE_FILE"
    fi
    if [[ "$visibility" == "hidden" ]]; then
        printf '%s\n' '{"text":"","class":"hidden"}'
        return
    fi

    local cache
    cache=$(jq -c . "$CACHE_FILE" 2>/dev/null)
    if [[ -z "$cache" ]]; then
        printf '%s\n' '{"text":"󰤭 Network unavailable","class":"disconnected","tooltip":"Waiting for network data"}'
        return
    fi

    local class iface ssid signal tooltip
    class=$(jq -r '.class // "disconnected"' <<< "$cache")
    iface=$(jq -r '.tooltip | split("\n")[0] | sub("^Interface: "; "")' <<< "$cache")
    ssid=$(jq -r '.ssid // empty' <<< "$cache")
    signal=$(jq -r '.signal // empty' <<< "$cache")

    # Compatibility with cache files written by an already-running older
    # sampler. A future sampler cycle/session supplies the dedicated fields.
    if [[ -z "$ssid" ]]; then
        ssid=$(jq -r '
            .tooltip
            | split("\n")[]
            | select(startswith("│ SSID: "))
            | sub("^│ SSID: "; "")
        ' <<< "$cache" | head -n 1)
    fi
    if [[ -z "$signal" ]]; then
        signal=$(jq -r '
            .tooltip
            | split("\n")[]
            | select(startswith("│ Signal: "))
            | sub("^│ Signal: "; "")
        ' <<< "$cache" | head -n 1)
    fi

    local text icon signal_value
    case "$class" in
        wifi)
            signal_value=${signal%\%}
            [[ "$signal_value" =~ ^[0-9]+$ ]] || signal_value=0
            icon=$(wifi_icon "$signal_value")
            text="${ssid:-Unknown SSID}"$'\n'"$icon ${signal:-N/A}"
            tooltip="SSID: ${ssid:-Unknown}"$'\n'"Signal: ${signal:-N/A}"$'\n'"Interface: ${iface:-Unknown}"
            ;;
        ethernet)
            text="󰈀 ${iface:-Wired}"
            tooltip="Wired network"$'\n'"Interface: ${iface:-Unknown}"$'\n'"SSID and signal do not apply"
            ;;
        *)
            class="disconnected"
            text="󰤭 Disconnected"
            tooltip="No active network connection"
            ;;
    esac

    jq -c -n \
        --arg text "$text" \
        --arg class "$class" \
        --arg tooltip "$tooltip" \
        '{text: $text, class: $class, tooltip: $tooltip}'
}

case "${1:-}" in
    --toggle) toggle_visibility ;;
    *)        main ;;
esac
