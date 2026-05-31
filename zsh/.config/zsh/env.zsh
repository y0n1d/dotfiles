export EDITOR="nvim"
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

if [ -f "$HOME/.config/.env.local" ]; then
    source "$HOME/.config/.env.local"
fi
