#!/usr/bin/env bash

set -u

event=${1:-}
payload=$(cat)
[[ -n $payload ]] || payload='{}'

json_field() {
    jq -r "$1 // empty" <<<"$payload" 2>/dev/null
}

cwd=$(json_field '.cwd')
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
        --app-name="Codex" \
        --urgency="$urgency" \
        --expire-time="$expiry" \
        --icon="$icon" \
        "$title" "$body" 2>/dev/null || true
    paplay "$sound" >/dev/null 2>&1 || true
}

case $event in
    stop)
        [[ $(json_field '.stop_hook_active // .stopHookActive') != true ]] || exit 0

        session_id=$(json_field '.session_id // .sessionId')
        turn_id=$(json_field '.turn_id // .turnId')
        event_id=${turn_id:-$session_id}

        if [[ -n $event_id ]]; then
            if [[ -n ${XDG_RUNTIME_DIR:-} ]]; then
                runtime_base="${XDG_RUNTIME_DIR}/agent-notify"
            else
                runtime_base="/tmp/agent-notify-${UID}"
            fi
            state_dir="${runtime_base}/codex"
            state_key=$(printf '%s' "$event_id" | sha256sum | cut -d ' ' -f 1)
            umask 077
            mkdir -p -- "$state_dir" 2>/dev/null || exit 0
            mkdir -- "${state_dir}/${state_key}" 2>/dev/null || exit 0
        fi

        play_notification \
            low 5000 dialog-information \
            "Codex awaits your input" \
            "Project: ${project}
Current turn has ended — you can plan the next step." \
            /usr/share/sounds/freedesktop/stereo/complete.oga
        ;;
    *)
        exit 0
        ;;
esac
