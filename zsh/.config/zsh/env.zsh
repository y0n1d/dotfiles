export EDITOR="nvim"
export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"

# Machine-local secrets and overrides stay untracked. Prefer the package-local
# path on new machines while retaining the legacy path for existing installs.
if [[ -r "$HOME/.config/zsh/.env.local" ]]; then
    source "$HOME/.config/zsh/.env.local"
elif [[ -r "$HOME/.config/.env.local" ]]; then
    source "$HOME/.config/.env.local"
fi
