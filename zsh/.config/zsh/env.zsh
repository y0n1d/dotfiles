# 终端 deepseek 设置
export EDITOR="nvim"
export PATH=~/.npm-global/bin:$PATH

if [ -f "$HOME/.config/zsh/.env.local" ]; then
    source "$HOME/.config/zsh/.env.local"
fi
