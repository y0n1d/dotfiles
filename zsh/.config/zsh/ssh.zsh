ssh-on() {
 eval "$(ssh-agent -s)"

 # 添加私钥到SSH代理
 #ssh-add ~/.ssh/x1-nano_id_rsa
 ssh-add ~/.ssh/github
 ssh-add ~/.ssh/agri.pem
 ssh-add ~/.ssh/aliyun
}
