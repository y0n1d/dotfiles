# ==========================================================
# 命令完成通知：长时间运行的命令结束后弹出桌面通知
# 依赖: foot (bell → notify-send), mako
# ==========================================================

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

    # 重置，防止空回车重复触发
    __cmd_start_time=0

    # 终端内始终显示运行耗时
    printf "\033[90m⏱ ${duration}s\033[0m\n"

    # 短于 1 秒的命令不弹桌面通知
    (( duration < 1 )) && return

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
    local notification_body="${short_cmd}"$'\n'"耗时 ${duration}s"
    notify-send -u normal -a "终端" \
        "$status_icon 命令$status_text" \
        "$notification_body"

    # 同时触发终端 bell（让任务栏闪烁等）
    printf '\a'
}

add-zsh-hook preexec __notify_preexec
add-zsh-hook precmd __notify_precmd
# Capture the command status before prompt hooks such as Starship can overwrite $?.
precmd_functions=(__notify_precmd ${precmd_functions:#__notify_precmd})

# 显示 zsh 初始化耗时
if [[ -n $__zsh_init_start ]]; then
    init_duration=$(( EPOCHREALTIME - __zsh_init_start ))
    printf "\033[90m⏱ zsh 初始化耗时 ${init_duration}s\033[0m\n"
    unset __zsh_init_start
fi
