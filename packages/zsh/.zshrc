# 记录 zsh 初始化起始时间
zmodload zsh/datetime
__zsh_init_start=$EPOCHREALTIME

# 补全系统初始化（带缓存，24小时刷新一次）
autoload -Uz compinit
if [[ -n ${ZSH_COMPDUMP}(#qN.mh+24) ]]; then
    compinit -C -d "${ZSH_COMPDUMP}"
else
    compinit -d "${ZSH_COMPDUMP}"
fi

# 开启tab上下左右选择补全
zstyle ':completion:*' menu select

# 语法检查和高亮（存在性检查，缺包时不影响启动）
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && \
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# zsh-vi-mode 插件
source /usr/share/zsh/plugins/zsh-vi-mode/zsh-vi-mode.plugin.zsh

# Source 子配置文件
source ~/.config/zsh/history.zsh

if [[ -n $SSH_CONNECTION ]]; then
    source ~/.config/zsh/prompt.zsh
else
    eval "$(starship init zsh)"
fi
#source ~/.config/zsh/prompt.zsh
#eval "$(starship init zsh)"

source ~/.config/zsh/proxy.zsh
source ~/.config/zsh/ssh.zsh
source ~/.config/zsh/aliases.zsh
source ~/.config/zsh/env.zsh
source ~/.config/zsh/keybindings.zsh
source ~/.config/zsh/yaziShellWrapper.zsh
source ~/.config/zsh/notify.zsh

# 只在 tty1 上自动启动 niri-session
if [[ "$(tty 2>/dev/null)" == "/dev/tty1" ]]; then
    proxy0
    # pam_gnome_keyring 已在登录阶段接管 keyring，不要在这里再起第二个 daemon。
    exec niri-session
fi


# NVM 懒加载：第一次调用 nvm/node/npm/npx 时才真正加载 NVM。
# 优先使用用户目录；Arch 的 nvm 包则从 /usr/share/nvm/nvm.sh 加载。
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
__load_nvm() {
    local nvm_script="$NVM_DIR/nvm.sh"
    [[ -s "$nvm_script" ]] || nvm_script=/usr/share/nvm/nvm.sh

    if [[ ! -s "$nvm_script" ]]; then
        print -u2 "nvm is not installed (looked for $NVM_DIR/nvm.sh and /usr/share/nvm/nvm.sh)"
        return 1
    fi

    unset -f nvm node npm npx
    source "$nvm_script"
}
nvm() {
    __load_nvm && nvm "$@"
}
node() {
    __load_nvm && node "$@"
}
npm() {
    __load_nvm && npm "$@"
}
npx() {
    __load_nvm && npx "$@"
}
