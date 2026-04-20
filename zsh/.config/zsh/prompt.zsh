# 1. 启用 vcs_info (显示 Git 分支信息所需)
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{yellow}%b%f' # 定义分支显示格式：空格+黄色分支名
precmd() { vcs_info } # 在每个提示符打印前更新信息

# 2. 启用变量替换 (用于显示 vcs_info_msg_0_)
setopt prompt_subst

# 3. 定义提示符 (使用 %F{color} 替代变量，代码更短)
# %n: 用户名, %m: 主机名, %~: 当前目录
if [[ "$TERM" == "linux" ]]; then
    PROMPT='[%F{cyan}%n%f@%F{green}%m%f%F{blue}%~%f${vcs_info_msg_0_}]
> '
else
PROMPT='%F{146}%n%f@%F{244}%m%f %F{110}%~%f${vcs_info_msg_0_}
%F{244}>%f '
fi

~/.config/zsh/scripts/pee.sh
