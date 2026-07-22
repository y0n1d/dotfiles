SSH_AGENT_RUNTIME_DIR="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/ssh-agent"
SSH_AGENT_ENV_FILE="$SSH_AGENT_RUNTIME_DIR/agent-${UID}.env"

_ssh_agent_usable() {
  [[ -n ${SSH_AUTH_SOCK:-} ]] || return 1

  ssh-add -l >/dev/null 2>&1
  case $? in
    0|1) return 0 ;;
    *) return 1 ;;
  esac
}

_ssh_agent_load_env() {
  [[ -r "$SSH_AGENT_ENV_FILE" ]] || return 1
  # shellcheck disable=SC1090
  source "$SSH_AGENT_ENV_FILE" >/dev/null 2>&1
}

_ssh_agent_start() {
  umask 077

  mkdir -p -m 700 "$SSH_AGENT_RUNTIME_DIR" || return 1
  [[ -d "$SSH_AGENT_RUNTIME_DIR" && -O "$SSH_AGENT_RUNTIME_DIR" ]] || return 1
  chmod 700 "$SSH_AGENT_RUNTIME_DIR" || return 1

  local tmp_file
  tmp_file=$(mktemp "${SSH_AGENT_ENV_FILE}.XXXXXX") || return 1
  ssh-agent -s >| "$tmp_file" || {
    rm -f "$tmp_file"
    return 1
  }
  mv -f "$tmp_file" "$SSH_AGENT_ENV_FILE" || {
    rm -f "$tmp_file"
    return 1
  }
  # shellcheck disable=SC1090
  source "$SSH_AGENT_ENV_FILE" >/dev/null 2>&1
}

ssh1() {
  local key_file="$HOME/.ssh/key_list"
  local key key_path

  [[ -f "$key_file" ]] || {
    print -u2 "Error: $key_file not found"
    return 1
  }

  if ! _ssh_agent_usable; then
    _ssh_agent_load_env
  fi
  if ! _ssh_agent_usable; then
    _ssh_agent_start || {
      print -u2 "Error: unable to start SSH agent"
      return 1
    }
  fi

  while IFS= read -r key || [[ -n "$key" ]]; do
    key=${key%%$'\r'}
    [[ -z "$key" || "$key" == \#* ]] && continue

    key_path="$HOME/.ssh/$key"
    [[ -f "$key_path" ]] || {
      print -u2 "Skip missing key: $key_path"
      continue
    }

    ssh-add "$key_path" || \
      print -u2 "Skip already-loaded or unavailable key: $key"
  done < "$key_file"
}

ssh0() {
  if [[ -r "$SSH_AGENT_ENV_FILE" ]]; then
    local current_sock=${SSH_AUTH_SOCK:-} managed_sock
    managed_sock=$(
      source "$SSH_AGENT_ENV_FILE" >/dev/null 2>&1
      print -r -- "${SSH_AUTH_SOCK:-}"
    )

    (
      source "$SSH_AGENT_ENV_FILE" >/dev/null 2>&1
      ssh-agent -k >/dev/null 2>&1
    ) || true
    rm -f "$SSH_AGENT_ENV_FILE"

    if [[ -n "$managed_sock" && "$current_sock" == "$managed_sock" ]]; then
      unset SSH_AUTH_SOCK SSH_AGENT_PID
    fi
    return 0
  fi

  if _ssh_agent_usable; then
    ssh-add -D
    return
  fi

  print -u2 "Error: no usable SSH agent found in SSH_AUTH_SOCK"
  return 1
}

ssh-status() {
  if ! _ssh_agent_usable; then
    _ssh_agent_load_env
  fi
  if ! _ssh_agent_usable; then
    print -u2 "Error: no usable SSH agent found in SSH_AUTH_SOCK"
    return 1
  fi

  ssh-add -l
}
