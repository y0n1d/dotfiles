#!/usr/bin/env bash
# Restore default application associations to zen-browser.
# Run this whenever another browser (Chrome, Edge, etc.) hijacks the defaults.

set -euo pipefail

browser="zen-browser.desktop"

declare -A defaults=(
    [x-scheme-handler/http]="$browser"
    [x-scheme-handler/https]="$browser"
    [x-scheme-handler/about]="$browser"
    [x-scheme-handler/unknown]="$browser"
    [text/html]="$browser"
    [application/xhtml+xml]="$browser"
    [application/pdf]="$browser"
    [image/png]="$browser"
    [image/jpeg]="$browser"
    [image/gif]="$browser"
    [image/webp]="$browser"
    [image/svg+xml]="$browser"
)

for mime in "${!defaults[@]}"; do
    xdg-mime default "${defaults[$mime]}" "$mime"
done

xdg-settings set default-web-browser "$browser"

echo "Defaults restored to $browser"
