#!/usr/bin/env bash

set -u

event=${1:-}
payload=$(cat)
[[ -n $payload ]] || payload='{}'

json_field() {
    jq -r "$1 // empty" <<<"$payload" 2>/dev/null
}

cwd=$(json_field '.cwd // .directory')
project=${cwd##*/}
[[ -n $project ]] || project="unknown directory"

play_notification() {
    local urgency=$1
    local expiry=$2
    local icon=$3
    local title=$4
    local body=$5
    local sound=$6

    notify-send \
        --app-name="OpenCode" \
        --urgency="$urgency" \
        --expire-time="$expiry" \
        --icon="$icon" \
        "$title" "$body" 2>/dev/null || true
    paplay "$sound" >/dev/null 2>&1 || true
}

case $event in
    permission)
        permission=$(json_field '.permission')
        command=$(json_field '.metadata.command // .metadata.cmd')
        body="Project: ${project}
An action is awaiting authorization."
        if [[ -n $permission ]]; then
            body="${body}
Action: ${permission}"
        fi
        if [[ -n $command ]]; then
            command=${command:0:80}
            body="${body}
Command: ${command}"
        fi
        play_notification \
            normal 10000 dialog-question \
            "OpenCode needs your confirmation" \
            "$body" \
            /usr/share/sounds/freedesktop/stereo/message-new-instant.oga
        ;;
    stop)
        play_notification \
            low 5000 dialog-information \
            "OpenCode awaits your input" \
            "Project: ${project}
Current turn has ended — you can plan the next step." \
            /usr/share/sounds/freedesktop/stereo/complete.oga
        ;;
    *)
        exit 0
        ;;
esac
