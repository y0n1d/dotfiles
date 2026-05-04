ssh-on() {
 eval "$(ssh-agent -s)"

 # 添加私钥到SSH代理
 #ssh-add ~/.ssh/x1-nano_id_rsa
 ssh-add ~/.ssh/github
 ssh-add ~/.ssh/agri.pem
 ssh-add ~/.ssh/aliyun
}

ssh-on() {
  eval "$(ssh-agent -s)" >/dev/null 2>&1
  while IFS= read -r key || [ -n "$key" ]; do
    [[ -f "$HOME/.ssh/$key" ]] && ssh-add "$HOME/.ssh/$key" #>/dev/null 2>&1
  done < "$HOME/.ssh/key_list"
}
