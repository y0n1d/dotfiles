# ZSH 快捷键绑定配置

# 确保在所有终端环境下都有正确的按键绑定
bindkey -e

# Emacs 风格的快捷键（默认）
bindkey '^A' beginning-of-line     # Ctrl+A 跳转到行首
bindkey '^E' end-of-line           # Ctrl+E 跳转到行尾
bindkey '^F' forward-char          # Ctrl+F 前进一个字符
bindkey '^B' backward-char         # Ctrl+B 后退一个字符
bindkey '^D' delete-char           # Ctrl+D 删除当前字符
bindkey '^K' kill-line             # Ctrl+K 删除从光标到行尾的所有内容
bindkey '^U' backward-kill-line    # Ctrl+U 删除从光标到行首的所有内容
bindkey '^W' backward-kill-word    # Ctrl+W 删除前一个单词
bindkey '^Y' yank                  # Ctrl+Y 粘贴已删除的内容

# Alt 组合键
bindkey '^[b' backward-word        # Alt+B 跳转到前一个单词
bindkey '^[f' forward-word         # Alt+F 跳转到后一个单词
bindkey '^[d' kill-word            # Alt+D 删除下一个单词
bindkey '^[^H' backward-kill-word  # Alt+Backspace 删除前一个单词
bindkey '^[^W' backward-kill-word  # Alt+W 删除前一个单词
bindkey '^[w' backward-kill-word   # Alt+W 删除前一个单词

# 历史记录导航
bindkey '^P' up-history            # Ctrl+P 上一条历史记录
bindkey '^N' down-history          # Ctrl+N 下一条历史记录
bindkey '^R' history-incremental-search-backward  # Ctrl+R 反向搜索历史记录

# 方向键导航历史记录
bindkey '^[[A' up-history          # 上方向键 上一条历史记录
bindkey '^[[B' down-history        # 下方向键 下一条历史记录

# Alt+J/K 导航历史记录 (使用小写字母)
bindkey '^[j' down-history         # Alt+J 下一条历史记录
bindkey '^[k' up-history           # Alt+K 上一条历史记录

# 其他有用的快捷键
bindkey '^?' backward-delete-char  # Backspace 删除前一个字符
bindkey '^H' backward-delete-char  # Ctrl+H 删除前一个字符

# 确保在所有终端类型下都能正常工作
bindkey '^[[1~' beginning-of-line   # Home 键
bindkey '^[[4~' end-of-line         # End 键
bindkey '^[[3~' delete-char         # Delete 键