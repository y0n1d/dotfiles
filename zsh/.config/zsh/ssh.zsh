ssh-on() {
  local key_file="$HOME/.ssh/key_list"
  [[ -f "$key_file" ]] || { echo "Error: $key_file not found" >&2; return 1; }
  eval "$(ssh-agent -s)" >/dev/null
  while IFS= read -r key || [ -n "$key" ]; do
    [[ -f "$HOME/.ssh/$key" ]] && ssh-add "$HOME/.ssh/$key"
  done < "$key_file"
}
