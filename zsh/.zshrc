# 语法检查和高亮
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh

# 开启tab上下左右选择补全
zstyle ':completion:*' menu select
autoload -Uz compinit
compinit

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

export PATH="$HOME/.local/bin:$PATH"

# 只在 tty1 上自动启动 niri-session
if [[ "$(tty)" == "/dev/tty1" ]]; then
    proxy-off

    eval $(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh) #初始化 gnome-keyring 并导出环境变量
    export SSH_AUTH_SOCK

    exec niri-session
fi


# 配置 nvm 和 nvm 补全
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
