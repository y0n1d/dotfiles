export EDITOR="nvim"
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

if [ -f "$HOME/.config/zsh/.env.local" ]; then
    source "$HOME/.config/zsh/.env.local"
fi
