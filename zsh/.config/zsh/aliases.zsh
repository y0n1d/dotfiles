alias w-tja='curl wttr.in/Huainan'
alias btrfs-assistant='xhost +local:root && sudo QT_QPA_PLATFORM=xcb btrfs-assistant'
alias wificon='nmcli -a device wifi con'
alias sshy='ssh -Y'
alias ls='ls --color=auto'
alias la='ls -a'
alias ll='ls -alh'
alias cls='clear'
alias cd..='cd ..'
alias szsh='source ~/.zshrc'
alias dpsk='~/code/note/deepseek_chat.py'
alias note='less ~/note'
alias note.='nvim ~/note'
alias Note='yazi ~/Note/'
alias btui='bluetui'
alias wtui='wifitui'
alias cd_wifi='cd /usr/share/hashcatch/handshakes'
alias swaylock='swaylock \
	--screenshots \
	--clock \
	--indicator \
	--indicator-radius 200 \
	--indicator-thickness 6 \
	--effect-blur 20x3 \
	--effect-vignette 0.1:0.4 \
	--ring-color b19cd9 \
	--key-hl-color a2d2ff \
	--text-color ffffff \
	--line-color 00000000 \
	--inside-color ffffff22 \
	--separator-color 00000000 \
	--grace 2 \
	--fade-in 0.3 \
	--ring-clear-color e9edc9 \
	--inside-clear-color fff4e644 \
	--ring-ver-color a2d2ff \
	--inside-ver-color a2d2ff44 \
	--ring-wrong-color ffccd5 \
	--inside-wrong-color ffccd544'

# 显示器设置 (sway 中)
alias dis-on='wlr-randr --output eDP-2 --on'
alias dis-off='wlr-randr --output eDP-2 --off'

# 显示器亮度设置
dis_set() {
  brightnessctl set "$1"%
}

# 注释掉 x 别名，避免与 x-cmd 冲突
# alias x='x-cmd'
