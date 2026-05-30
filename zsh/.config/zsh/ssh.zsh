ssh-on() {
  eval "$(ssh-agent -s)" >/dev/null 2>&1
  while IFS= read -r key || [ -n "$key" ]; do
    [[ -f "$HOME/.ssh/$key" ]] && ssh-add "$HOME/.ssh/$key" #>/dev/null 2>&1
  done < "$HOME/.ssh/key_list"
}
