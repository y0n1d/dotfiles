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

# 只在 tty1 上自动启动 niri-session
if [[ "$(tty)" == "/dev/tty1" ]]; then
    proxy-off

    eval "$(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh)" #初始化 gnome-keyring 并导出环境变量
    export SSH_AUTH_SOCK

    exec niri-session
fi


# NVM 懒加载：第一次调用 nvm/node/npm/npx 时才真正加载 NVM
export NVM_DIR="$HOME/.nvm"
nvm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm "$@"
}
node() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    node "$@"
}
npm() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    npm "$@"
}
npx() {
    unset -f nvm node npm npx
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    npx "$@"
}
