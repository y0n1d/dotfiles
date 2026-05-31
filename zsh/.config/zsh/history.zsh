# 设置历史记录文件的路径
HISTFILE="$HOME/.zsh_history"

# 设置在会话（内存）中和历史文件中保存的条数
HISTSIZE=100000
SAVEHIST=100000

# 忽略所有重复的命令（不只是连续的）
setopt HIST_IGNORE_ALL_DUPS

# 忽略以空格开头的命令（用于临时执行一些你不想保存的敏感命令）
setopt HIST_IGNORE_SPACE

# 去掉命令中的多余空格
setopt HIST_REDUCE_BLANKS

# 在多个终端之间实时共享历史记录
# 这是实现多终端同步最关键的选项
setopt SHARE_HISTORY

# 让新的历史记录追加到文件，而不是覆盖
setopt APPEND_HISTORY
# 在历史记录中记录命令的执行开始时间和持续时间
setopt EXTENDED_HISTORY
# 带时间戳立即写入文件，崩溃不丢历史，且配合 SHARE_HISTORY 不会产生重复
setopt INC_APPEND_HISTORY_TIME