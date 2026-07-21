#!/usr/bin/env bash
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
PID_FILE="$RUNTIME_DIR/waybar-playerctl-$UID.pid"
INFO_FILE="$RUNTIME_DIR/waybar-playerctl-$UID.info"
exec 2>"$RUNTIME_DIR/waybar-playerctl-$UID.log"
IFS=$'\n\t'

cleanup(){
	[[ -r "$PID_FILE" ]] || return 0
	read -r pid <"$PID_FILE"
	[[ -d "/proc/$pid" ]] || return
	read -rd '' cmd < "/proc/$pid/cmdline"
	: "$cmd"
	case $cmd in
		-playerctl|playerctl|*/playerctl)
			echo >&2 "Killing playerctl [$pid]"
			kill "$pid"
	esac
}

# in case waybar didn't die cleanly
cleanup

trap cleanup EXIT INT

while true; do

	while read -r playing position length name artist title arturl hpos hlen; do
		# remove leaders
		playing=${playing:1} position=${position:1} length=${length:1} name=${name:1}
		artist=${artist:1} title=${title:1} arturl=${arturl:1} hpos=${hpos:1} hlen=${hlen:1}

		# build line
		line="${artist:+$artist ${title:+- }}${title:+$title }${hpos:+$hpos${hlen:+|}}$hlen"

		((percentage = length ? (100 * (position % length)) / length : 0))
		case $playing in
		⏸️ | Paused) text='<span foreground=\"#FFB7B2\" size=\"smaller\">'"$line"'</span>' ;;
		▶️ | Playing) text="<small>$line</small>" ;;
		*) text='<span foreground=\"#073642\">⏹</span>' ;;
		esac

		# integrations for other services (nwg-wrapper)
		if [[ $title != "$ptitle" || $artist != "$partist" || $parturl != "$arturl" ]]; then
			typeset -p playing length name artist title arturl >"$INFO_FILE"
			pkill -8 nwg-wrapper
			ptitle=$title partist=$artist parturl=$arturl
		fi

		# jq handles quotes, backslashes and newlines in MPRIS metadata safely.
		jq -cn \
			--arg text "$text" \
			--arg tooltip "$playing $name | $line" \
			--arg class "$playing" \
			--argjson percentage "$percentage" \
			'{text: $text, tooltip: $tooltip, class: $class, percentage: $percentage}' || break 2

	done < <(
		# requires playerctl>=2.0
		# Add non-space character ":" before each parameter to prevent 'read' from skipping over them
		playerctl --follow metadata --player playerctld --format \
			$':{{emoji(status)}}\t:{{position}}\t:{{mpris:length}}\t:{{playerName}}\t:{{markup_escape(artist)}}\t:{{markup_escape(title)}}\t:{{mpris:artUrl}}\t:{{duration(position)}}\t:{{duration(mpris:length)}}' &
			echo $! >"$PID_FILE"
	)

	# no current players
	cleanup
	# exit if print fails
	echo '{"text":"⏹","class":"stopped","percentage":0}' || break
	sleep 15

done
