# ==========================================================
# 命令完成通知：长时间运行的命令结束后弹出桌面通知
# 依赖: notify-send、mako；Foot bell 只负责窗口紧急提示
# ==========================================================

# 可在 .env.local 中覆盖，例如：ZSH_NOTIFY_THRESHOLD=5
: ${ZSH_NOTIFY_THRESHOLD:=10}

# 记录命令开始时间
__cmd_start_time=0

autoload -Uz add-zsh-hook

__notify_preexec() {
    __cmd_start_time=$EPOCHREALTIME
    __cmd_line="$1"
}

__notify_precmd() {
    local exit_code=$?

    # 没有执行过命令（首次打开终端或刚显示过）时跳过
    (( __cmd_start_time == 0 )) && return

    local duration=$(( EPOCHREALTIME - __cmd_start_time ))
    local duration_text
    printf -v duration_text '%.1f' "$duration"

    # 重置，防止空回车重复触发
    __cmd_start_time=0

    # 很短的命令不刷屏；超过 1 秒才显示耗时。
    (( duration >= 1 )) && printf '\033[90m⏱ %ss\033[0m\n' "$duration_text"

    # 只为长任务发送桌面通知，阈值可按机器覆盖。
    (( duration < ZSH_NOTIFY_THRESHOLD )) && return

    # 构造通知内容
    local status_icon="✅"
    local status_text="完成"
    if (( exit_code != 0 )); then
        status_icon="❌"
        status_text="失败 (exit $exit_code)"
    fi

    # 截断过长的命令
    local short_cmd="${__cmd_line:0:80}"
    (( ${#__cmd_line} > 80 )) && short_cmd+="…"

    # 发送桌面通知
    local notification_body="${short_cmd}"$'\n'"耗时 ${duration_text}s"
    if (( $+commands[notify-send] )); then
        notify-send -u normal -a "终端" \
            "$status_icon 命令$status_text" \
            "$notification_body"
    fi

    # 同时触发终端 bell（让任务栏闪烁等）
    printf '\a'
}

add-zsh-hook -d preexec __notify_preexec 2>/dev/null
add-zsh-hook -d precmd __notify_precmd 2>/dev/null
add-zsh-hook preexec __notify_preexec
add-zsh-hook precmd __notify_precmd
# Capture the command status before prompt hooks such as Starship can overwrite $?.
precmd_functions=(__notify_precmd ${precmd_functions:#__notify_precmd})

# 显示 zsh 初始化耗时
if [[ -n $__zsh_init_start ]]; then
    init_duration=$(( EPOCHREALTIME - __zsh_init_start ))
    printf '\033[90m⏱ zsh 初始化耗时 %.2fs\033[0m\n' "$init_duration"
    unset __zsh_init_start
fi
