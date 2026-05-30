# Dotfiles

Arch Linux + Wayland 个人配置集合，以 [niri](https://github.com/YaLTeR/niri) 为主要窗口管理器。

使用 [GNU Stow](https://www.gnu.org/software/stow/) 管理，每个顶层目录是一个 stow 包。

## 目录结构

```
dotfiles/
├── niri/          # niri 窗口管理器配置
├── waybar/        # 状态栏
├── foot/          # 终端模拟器
├── zsh/           # zsh + starship prompt
├── sway/          # sway 窗口管理器（备用）
├── gtk/           # GTK3/4 主题设置
├── mako/          # 通知守护进程
├── rofi/          # 应用启动器
├── wofi/          # 备用启动器
├── river/         # river 窗口管理器（备用）
├── nvim/          # Neovim 编辑器
├── tmux/          # tmux 终端复用器
├── yazi/          # 文件管理器
└── fcitx5/        # 输入法
```

## 安装使用

### 1. 克隆仓库

```bash
git clone https://github.com/y0n1d/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. 安装依赖

#### 必装软件

```bash
# 窗口管理器 & 核心组件
sudo pacman -S niri waybar foot mako rofi swaylock swayidle

# 工具
sudo pacman -S grim slurp wl-clipboard cliphist playerctl brightnessctl polkit-gnome
sudo pacman -S xwayland-satellite nwg-displays

# Shell
sudo pacman -S zsh zsh-syntax-highlighting zsh-autosuggestions starship

# 输入法
sudo pacman -S fcitx5 fcitx5-rime rime-luna-pinyin

# 其他
sudo pacman -S yazi neovim tmux fsearch
```

#### AUR 软件

```bash
yay -S satty wlrctl bluetui wifitui musicfox awww-daemon-git dms-git
```

### 3. 安装字体

**必须安装**，否则 waybar 图标和终端符号无法正常显示：

```bash
# Nerd Font（waybar 图标、starship prompt、rofi 图标）
sudo pacman -S ttf-jetbrains-mono-nerd

# FontAwesome（waybar 全局图标）
sudo pacman -S otf-font-awesome

# 思源黑体（fcitx5 输入法界面）
sudo pacman -S adobe-source-han-sans-cn-fonts

# Adwaita 字体（GTK 应用）
sudo pacman -S cantarell-fonts
```

### 4. 安装光标主题

```bash
# Bocchi 光标主题
yay -S bibata-cursor-theme
# 或者从 AUR 安装其他包含 Bocchi 主题的包
```

### 5. 使用 Stow 部署配置

```bash
cd ~/dotfiles

# 部署单个包
stow niri
stow waybar
stow foot
stow zsh

# 或一次性部署所有
stow */

# 取消部署
stow -D niri
```

stow 会自动在 `$HOME` 下创建符号链接，例如：
- `niri/.config/niri/` → `~/.config/niri/`
- `zsh/.zshrc` → `~/.zshrc`

### 6. 启动

在 tty1 登录后会自动执行 `niri-session`（由 `.zshrc` 控制）。也可以手动：

```bash
exec niri-session
```

---

## 配置说明

### niri 窗口管理器

主要配置文件位于 `niri/.config/niri/`：

| 文件 | 说明 |
|------|------|
| `config.kdl` | 主配置入口，按顺序加载以下所有文件 |
| `monitor.kdl` | 显示器布局（由 nwg-displays 生成） |
| `environment.kdl` | 环境变量 |
| `input.kdl` | 键盘、触摸板、鼠标设置 |
| `output.kdl` | 输出设备定义（分辨率、刷新率、位置） |
| `layout.kdl` | 窗口间距、焦点环、边框、阴影、动画、光标主题 |
| `startup.kdl` | 开机自启动程序 |
| `window-rules.kdl` | 窗口匹配规则（浮动窗口等） |
| `keybinds.kdl` | 所有键盘快捷键 |
| `scripts/swayidle.sh` | 锁屏/休眠脚本 |
| `dms/` | DMS 桌面管理系统集成配置 |

#### 布局设置

- 窗口间距：1px
- 预设列宽：33% / 50% / 67%
- 默认列宽：50%
- 焦点环：宽度 2，活跃色 `#FAACAC`（粉色），非活跃色 `#505050`
- 光标主题：Bocchi，大小 48
- 截图保存路径：`~/Pictures/Screenshots/`

#### 自启动程序

- waybar — 状态栏
- mako — 通知守护进程
- fcitx5 — 输入法
- foot --server — 终端服务器模式
- clash-verge — 代理
- xwayland-satellite — X11 兼容层
- cliphist + wl-paste — 剪贴板历史
- polkit-gnome — 权限认证代理

---

### niri 快捷键一览

> Mod = Super (Win) 键

#### 系统

| 快捷键 | 功能 |
|--------|------|
| `Mod+F12` | 重启 waybar |
| `Mod+F1` | 切换 fcitx5 输入法 |
| `Mod+Shift+/` | 显示快捷键帮助 |
| `Mod+Escape` | 切换快捷键拦截 |

#### 启动应用

| 快捷键 | 功能 |
|--------|------|
| `Mod+Return` | 打开 foot 终端 |
| `Mod+T` | 打开 Terminator 终端 |
| `Mod+D` | Rofi 应用启动器 |
| `Mod+E` | Rofi 表情选择器 |
| `Mod+V` | 剪贴板管理器（cliphist） |
| `Ctrl+Alt+E` | 打开 FSearch 文件搜索 |
| `Super+Alt+L` | 锁屏 |
| `Super+Alt+S` | 切换 Orca 屏幕阅读器 |

#### 窗口管理

| 快捷键 | 功能 |
|--------|------|
| `Mod+Q` | 关闭窗口 |
| `Mod+F` | 最大化列 |
| `Mod+Shift+F` | 全屏窗口 |
| `Mod+Ctrl+F` | 展开列至可用宽度 |
| `Mod+C` | 居中列 |
| `Mod+W` | 切换标签页模式 |
| `Mod+R` | 切换预设列宽 |
| `Mod+Shift+R` | 切换预设窗口高度 |
| `Mod+Ctrl+R` | 重置窗口高度 |
| `Mod+Shift+Space` | 切换浮动/平铺 |
| `Mod+Space` | 在浮动和平铺间切换焦点 |
| `Mod+Minus` / `Mod+Equal` | 列宽 -1% / +1% |
| `Mod+Shift+Minus` / `Mod+Shift+Equal` | 窗口高 -3% / +3% |
| `Mod+Comma` / `Mod+Period` | 向左/右消费或排出窗口 |
| `Mod+BracketLeft` / `Mod+BracketRight` | 消费窗口入列 / 排出窗口出列 |
| `Mod+Shift+E` | 退出 niri |

#### 焦点导航（Vim 风格）

| 快捷键 | 功能 |
|--------|------|
| `Mod+H` / `Mod+Left` | 焦点移到左列 |
| `Mod+L` / `Mod+Right` | 焦点移到右列 |
| `Mod+J` / `Mod+Down` | 焦点移到下方窗口 |
| `Mod+K` / `Mod+Up` | 焦点移到上方窗口 |
| `Mod+Home` / `Mod+End` | 焦点移到第一/最后一列 |

#### 移动窗口

| 快捷键 | 功能 |
|--------|------|
| `Mod+Shift+H` / `Mod+Shift+Left` | 列左移 |
| `Mod+Shift+L` / `Mod+Shift+Right` | 列右移 |
| `Mod+Shift+J` / `Mod+Shift+Down` | 窗口下移 |
| `Mod+Shift+K` / `Mod+Shift+Up` | 窗口上移 |
| `Mod+Ctrl+Home` / `Mod+Ctrl+End` | 移到第一/最后位置 |

#### 显示器导航

| 快捷键 | 功能 |
|--------|------|
| `Mod+Ctrl+H/J/K/L` | 焦点移到左/下/上/右显示器 |
| `Mod+Shift+Ctrl+H/J/K/L` | 移动列到左/下/上/右显示器 |

#### 工作区

| 快捷键 | 功能 |
|--------|------|
| `Mod+U` / `Mod+Page_Down` | 切换到上一个工作区 |
| `Mod+I` / `Mod+Page_Up` | 切换到下一个工作区 |
| `Mod+1` ~ `Mod+0` | 切换到工作区 1-10 |
| `Mod+Shift+1` ~ `Mod+Shift+0` | 移动列到工作区 1-10 |
| `Mod+Shift+U/I` | 移动列到上/下一个工作区 |
| `Mod+Ctrl+U/I` | 上/下移动工作区顺序 |
| `Mod+滚轮` | 切换工作区（带 150ms 冷却） |

#### 概览

| 快捷键 | 功能 |
|--------|------|
| `Mod+O` | 切换概览模式 |
| `Mod+Tab` | 切换概览模式 |

#### 截图

| 快捷键 | 功能 |
|--------|------|
| `Mod+Shift+S` | 区域截图到剪贴板（grim + slurp） |
| `Mod+Ctrl+Shift+S` | 区域截图到 Satty 编辑器 |
| `Print` | 全屏截图保存 + 复制到剪贴板 |
| `Ctrl+Print` | 全屏截图到 Satty 编辑器 |
| `Alt+Print` | 窗口截图 |

#### 翻译（Pot-App 集成）

| 快捷键 | 功能 |
|--------|------|
| `Mod+A` | 输入翻译 |
| `Mod+Shift+A` | 划词翻译 |
| `Mod+Ctrl+A` | OCR 识别 |
| `Mod+Shift+Ctrl+A` | OCR 翻译 |

#### 音量控制

| 快捷键 | 功能 |
|--------|------|
| `XF86AudioRaiseVolume` / `XF86AudioLowerVolume` | 音量 +/-1% |
| `XF86AudioMute` | 静音 |
| `XF86AudioMicMute` | 麦克风静音 |
| `XF86AudioPlay/Prev/Next/Stop` | 媒体控制 |
| `Ctrl+Alt+P` | 播放/暂停 |
| `Ctrl+Alt+H/L` | 上/下一曲 |
| `Ctrl+Alt+J/K` | 音量 -/+1% |
| `Ctrl+Alt+M` | 静音 |

#### 亮度控制

| 快捷键 | 功能 |
|--------|------|
| `XF86MonBrightnessUp/Down` | 亮度 +/-5% |
| `Ctrl+Shift+Alt+H/L` | 外接显示器亮度 +/-10（ddcutil） |
| `Ctrl+Shift+Alt+J/K` | 外接显示器亮度 +/-3（ddcutil） |

#### 模拟鼠标滚轮

| 快捷键 | 功能 |
|--------|------|
| `Mod+N` / `Mod+M` | 向右/左滚动 |
| `Mod+Shift+N` / `Mod+Shift+M` | 向上/下滚动 |

---

### waybar 状态栏

配置文件：`waybar/.config/waybar/`

- `config.jsonc` — 模块配置
- `style.css` — 样式
- `scripts/network-speed.sh` — 网速显示脚本
- `scripts/player.sh` — 媒体播放器显示脚本

#### 字体要求

waybar 使用了大量 Nerd Font 图标，**必须安装以下字体才能正常显示**：

| 字体 | 用途 | 安装命令 |
|------|------|----------|
| **JetBrainsMono Nerd Font** | 网速模块图标 | `sudo pacman -S ttf-jetbrains-mono-nerd` |
| **FontAwesome** | 全局图标（CPU、内存、电池、音量等） | `sudo pacman -S otf-font-awesome` |

如果 waybar 中出现方块或乱码，说明字体没有正确安装。

---

### foot 终端

配置文件：`foot/.config/foot/foot.ini`

- 字体：JetBrainsMono Nerd Font，大小 16
- 光标：竖线样式，闪烁开启
- 背景：半透明（alpha=0.7），`#222222`
- 前景：`#eeeeee`
- 内边距：5x5
- 运行模式：支持服务器模式（`foot --server`），启动更快

---

### zsh 配置

配置文件：`zsh/.zshrc` + `zsh/.config/zsh/`

| 文件 | 说明 |
|------|------|
| `.zshrc` | 主配置，加载所有子模块 |
| `aliases.zsh` | 常用别名 |
| `env.zsh` | 环境变量（EDITOR=nvim 等） |
| `proxy.zsh` | 代理开关函数（proxy-on/proxy-off） |
| `ssh.zsh` | SSH agent 管理（从 ~/.ssh/key_list 读取密钥） |
| `history.zsh` | 历史记录配置 |
| `keybindings.zsh` | Emacs 风格键绑定 |
| `prompt.zsh` | 自定义 prompt（git 分支、SSH 感知） |
| `yaziShellWrapper.zsh` | yazi 退出后自动 cd |
| `starship.toml` | Starship prompt 配置 |

#### 常用别名

| 别名 | 命令 |
|------|------|
| `mf` | musicfox（终端音乐播放器） |
| `ll` | `ls -alh` |
| `la` | `ls -a` |
| `cls` | `clear` |
| `szsh` | `source ~/.zshrc` |
| `btui` | bluetui（蓝牙 TUI） |
| `wtui` | wifitui（WiFi TUI） |
| `Note` | `yazi ~/Note/` |
| `note` | `less ~/note` |
| `todo` | `nvim ~/todo` |

#### 代理设置

默认代理地址：`127.0.0.1:7897`（Clash Verge）

```bash
proxy-on   # 开启代理
proxy-off  # 关闭代理
```

#### Starship Prompt

使用 Amethyst 色彩方案，支持显示：
- 操作系统图标（Arch Linux）
- 当前目录（最多 3 层，带 Nerd Font 目录图标）
- Git 分支和状态
- 多语言版本（C, C++, Rust, Go, Node.js, Bun, PHP, Java, Kotlin, Haskell, Python）
- Docker 上下文
- 当前时间

---

### GTK 主题

配置文件：`gtk/.config/gtk-3.0/settings.ini` 和 `gtk/.config/gtk-4.0/settings.ini`

- 主题：Adwaita-dark
- 图标主题：Adwaita
- 字体：Adwaita Sans 11
- 光标主题：Bocchi，大小 24

---

### mako 通知

配置文件：`mako/.config/mako/config`

- 超时时间：5000ms
- 配色：Catppuccin Mocha 风格
- 背景：`#1e1e2e`
- 文字：`#cdd6f4`
- 边框：`#f5c2e7`（粉色）
- 高优先级边框：`#fab387`（橙色）

---

### rofi 启动器

配置文件：`rofi/.config/rofi/`

- 主题：grimm（深色风格，`#222222` 背景）
- 字体：JetBrainsMono Nerd Font Propo ExtraBold 14
- 包含电源菜单主题（`themes/powermenu.rasi`）

---

### fcitx5 输入法

配置文件：`fcitx5/.config/fcitx5/`

- 主题：Catppuccin Mocha Pink
- 字体：思源黑体 CN Medium 13
- 输入方案：rime + keyboard-us
- 切换快捷键：`Alt+Space`
- 候选词列表：垂直排列

---

### yazi 文件管理器

配置文件：`yazi/.config/yazi/keymap.toml`

- Vim 风格键绑定
- 通过 `y()` 函数包装，退出时自动切换目录

---

### sway（备用窗口管理器）

配置文件：`sway/.config/sway/`

结构与 niri 类似，Vim 风格快捷键（h/j/k/l）。包含触摸板手势支持：
- 三指滑动：切换工作区
- 四指滑动：全屏/浮动等

---

### river（备用窗口管理器）

配置文件：`river/.config/river/`

- Vim 风格键绑定
- rivertile 布局，1px 间距
- 使用 rofi 启动器

---

## 许可证

MIT
