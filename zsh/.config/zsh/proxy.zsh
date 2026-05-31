### Proxy functions ###
# 修改这里的端口和协议，取决于你代理工具的监听配置
PROXY_HOST="127.0.0.1"
PROXY_PORT=7897

proxy-on() {
  export http_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
  export https_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
  export ftp_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
  export all_proxy="socks5://${PROXY_HOST}:${PROXY_PORT}"

  export HTTP_PROXY="$http_proxy"
  export HTTPS_PROXY="$https_proxy"
  export FTP_PROXY="$ftp_proxy"
  export ALL_PROXY="$all_proxy"

  export no_proxy="localhost,127.0.0.1,::1"
  export NO_PROXY="$no_proxy"

  if command -v lolcat &>/dev/null; then
    echo "✅ Proxy enabled on ${PROXY_HOST}:${PROXY_PORT}" | lolcat
  else
    echo "✅ Proxy enabled on ${PROXY_HOST}:${PROXY_PORT}"
  fi
}

proxy-off() {
  unset http_proxy https_proxy ftp_proxy all_proxy
  unset HTTP_PROXY HTTPS_PROXY FTP_PROXY ALL_PROXY
  unset no_proxy NO_PROXY

  echo "❎ Proxy disabled"
}

# 启动时自动检测端口并决定是否启用代理
#if nc -z ${PROXY_HOST} ${PROXY_PORT} >/dev/null 2>&1; then
#  proxy-on
#else
#  echo "ℹ️  No proxy detected on ${PROXY_HOST}:${PROXY_PORT}"
#fi
