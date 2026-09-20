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
├── fcitx5/        # 输入法
└── agent-notify/  # Codex / Claude 独立通知脚本
```

## 安装使用

推荐使用仓库自带的安装器。它仅支持 Arch Linux 自动安装依赖，并提供：

- `desktop`、`terminal`、`all` 三种 profile，也可精确选择 Stow 包；
- 自动跳过已安装的 pacman/AUR 依赖，可重复执行；
- 每个配置包单独进行 Stow 预演，单包失败不影响其他包；
- 默认不覆盖已有配置，可显式选择将冲突项备份后再部署；
- `--dry-run` 无副作用预演，适合先在新设备上检查。

### 1. 克隆仓库

```bash
git clone https://github.com/y0n1d/dotfiles.git ~/dotfiles
cd ~/dotfiles
```

### 2. 运行安装器

交互选择：

```bash
./install.sh
```

无需修改脚本中的用户名或家目录。安装器默认从当前普通用户的 `$HOME` 获取 Stow
目标；`--target DIR` 中的 `DIR` 只是参数说明，并不是需要编辑的占位符。脚本会在
安装系统包时自行调用 `sudo`，不应使用 `sudo ./install.sh`。

个人新设备一键安装 niri 主桌面：

```bash
./install.sh --profile desktop --yes
```

先检查将发生什么：

```bash
./install.sh --profile desktop --dry-run
```

只部署部分配置，或不让脚本安装系统依赖：

```bash
./install.sh --packages "zsh,nvim,tmux"
./install.sh --packages "zsh,nvim,tmux" --skip-deps
```

无人值守安装也可以通过环境变量设置默认值，显式命令行参数优先于环境变量：

```bash
DOTFILES_PROFILE=desktop ./install.sh --yes
DOTFILES_TARGET_HOME=/home/alice ./install.sh --profile desktop --yes
DOTFILES_PACKAGES="zsh,nvim,tmux" ./install.sh --yes
DOTFILES_AUR_HELPER=paru ./install.sh --profile desktop --yes
```

支持的环境变量为 `DOTFILES_TARGET_HOME`、`DOTFILES_PROFILE`、
`DOTFILES_PACKAGES` 和 `DOTFILES_AUR_HELPER`。普通单用户安装不需要设置它们。

默认遇到同名文件时跳过对应配置包，不会覆盖。确认希望保留旧文件并部署新配置时：

```bash
./install.sh --profile desktop --backup-conflicts
```

备份位于 `~/.local/state/dotfiles-backups/<时间戳>/`。安装器不会使用
`stow --adopt`，也不会删除已有文件。完整选项见 `./install.sh --help`。

`desktop` profile 不包含 `sway`、`river`、`wofi` 等备用配置；`all` 才会部署
全部包。AUR 依赖由 `yay` 或 `paru` 安装，未检测到 helper 时会给出提示并继续。
`terminal` profile 中的 `.zshrc` 仍保留 tty1 自动启动 niri 的个人行为；用于纯终端
设备时，应在首次登录前注释文件末尾对应的启动块。

安装器也会按所选配置补齐配置中实际调用的工具：例如 Waybar 的 MPD、Cava 和
PipeWire/WirePlumber 后端，niri 的录屏选择器、FSearch、Pot 翻译、朗读播放与
锁屏效果，以及 sway 的 `swww`、Blueman、SwayNC、`amixer` 和电源菜单。`fsearch`、
`pot-translation`、`swaylock-effects`、`rofi-power-menu`、`zen-browser-bin` 等来自
AUR；若使用 `--skip-aur` 或未配置 `yay`/`paru`，对应功能会不可用，安装总结会列出它们。

也可以继续直接使用 GNU Stow：

```bash
stow -nv niri waybar zsh  # 预演
stow niri waybar zsh      # 部署
stow -D niri              # 取消部署
```

Stow 会在 `$HOME` 下创建符号链接，例如
`niri/.config/niri/` → `~/.config/niri/`。

### 3. 首次启动前检查

`niri/.config/niri/output.kdl` 同时保留了两台现有笔记本的输出配置，并包含固定的
外接显示器模式和位置。新设备或他人设备应先运行 `niri msg outputs`，再按实际硬件
调整该文件。

`niri/.config/niri/startup.kdl` 还包含 `hda-verb`、`clash-verge`、Pot-App 服务和
本地提示音等个人化启动项。安装器会安装其中通用且可确认的软件；不适用于目标设备的
启动项需要手动注释。安装器不会修改机器相关配置，也不会自动更改默认 shell。

### 4. 启动

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
| `scripts/backlight-sleep.sh` | 睡眠前保存内屏亮度并在恢复后写回 |
| `dms/` | DMS 桌面管理系统集成配置 |

空闲策略分为三段：5 分钟自动锁屏、500 秒关闭显示器、20 分钟后请求系统休眠。Waybar
上的眼睛按钮依次循环三种模式：正常模式执行全部三段动作；休眠抑制模式仍锁屏和熄屏，
但不执行 20 分钟的空闲休眠；演示模式不锁屏、不熄屏、也不执行空闲休眠。模式状态保存
在 `$XDG_RUNTIME_DIR` 中，非法状态安全回退到正常模式，注销或重启后也会恢复正常模式。
三种模式都不安装系统休眠 inhibitor，因此合盖和手动执行 `systemctl suspend`/
`systemctl hibernate` 始终照常进入睡眠；正常及休眠抑制模式会先等待 swaylock 完成锁定，
演示模式则不锁屏。锁屏不设免密码宽限期。进入系统睡眠前会把内屏亮度保存到
`$XDG_RUNTIME_DIR`，恢复并点亮输出后再写回，避免固件将亮度重置为最大值；亮度运行时
状态会在注销或重启后自动清除。保存和恢复结果会以 `niri-backlight` 标签写入系统日志，
便于排查恢复失败。

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

#### 录屏

| 快捷键 | 功能 |
|--------|------|
| `Mod+Alt+Shift+S` | 选择区域并录屏 |
| `Mod+Alt+S` | 选择显示器并录制全屏 |

录屏文件保存到 `~/Videos/Recorder/`。开始录制前可以选择无音频、电脑内部
声音、麦克风，或电脑内部声音与麦克风混录；混录使用临时 PipeWire 音频节点，
录制结束后会自动清理。

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
- `scripts/network-speed.sh` — 网速显示脚本（单行：↓speed ↑speed）
- `scripts/network-speed-stacked.sh` — 网速显示脚本（上下堆叠：上传在上、下载在下，需配合 `"markup": "pango"` 使用）
- `scripts/network-info.sh` — 独立显示 SSID 与 Wi-Fi 信号强度；点击堆叠网速模块可切换显示或隐藏
- `scripts/player.sh` — 媒体播放器显示脚本

#### 字体要求

waybar 使用了大量 Nerd Font 图标，**必须安装以下字体才能正常显示**：

| 字体 | 用途 | 安装命令 |
|------|------|----------|
| **JetBrainsMono Nerd Font** | 网速模块图标 | `sudo pacman -S ttf-jetbrains-mono-nerd` |
| **FontAwesome** | 全局图标（CPU、内存、电池、音量等） | `sudo pacman -S otf-font-awesome` |

如果 waybar 中出现方块或乱码，说明字体没有正确安装。

#### waybar 脚本架构：Daemon + 文件共享

网速脚本采用 **后台守护 + 运行时文件** 的架构，避免每次刷新都等待采样；播放器和 cava 脚本分别直接监听 MPRIS 与 cava 输出。

1. **避免阻塞**：原始实现每次被 waybar 调用时都会 sleep 采样（如 network-speed.sh sleep 1s），导致 waybar 刷新周期被拉长、响应迟缓。
2. **多显示器同步**：多显示器下 waybar 为每个屏幕创建独立实例，如果每个实例各自采样，显示的数据会不同步。

**原理**：

```
┌─────────────────┐
│  后台守护进程     │  ← 自动 fork 到后台，持续运行
│  (每秒采样)      │
└────────┬────────┘
         │ 写入一份数据
         ▼
┌─────────────────┐
│ XDG_RUNTIME_DIR 文件 │  ← 当前用户的唯一数据源
└────────┬────────┘
         │ 读取
    ┌────┴────┐
    ▼         ▼
┌────────┐ ┌────────┐
│waybar 1│ │waybar 2│   ← 多显示器实例，读同一文件
└────────┘ └────────┘
```

- **network-speed.sh** 与 **network-speed-stacked.sh**：后台守护每秒读 `/sys/class/net/` 计算网速，写入 `$XDG_RUNTIME_DIR`（不可用时才使用 `/tmp`）的按用户隔离文件。切换默认网卡时会自动重新采样。Waybar 调用时直接读取 JSON；配置必须设置 `"return-type": "json"`。
- **network-info.sh**：复用 `network-speed-stacked.sh` 的缓存显示 SSID 与 Wi-Fi 信号强度，不重复采样网速。显示状态保存在 `$XDG_RUNTIME_DIR` 的按用户隔离文件中；点击堆叠网速模块切换状态并立即刷新所有 Waybar 实例。
- **player.sh**：直接监听 `playerctl --follow` 的 MPRIS 事件，并用 `jq` 生成安全的 JSON。
- **cava.sh**：直接读取 cava 的实时输出。

**为什么 network-speed 用文件而不用 FIFO**：FIFO 是单读者模型；网速数据需要供多个 Waybar 实例读取，因此使用普通文件并通过临时文件原子替换。

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
| `env.zsh` | 环境变量及不入库的 `.env.local` 机器配置 |
| `proxy.zsh` | 代理开关函数（`proxy1`/`proxy0`） |
| `ssh.zsh` | SSH agent 辅助函数（`ssh1`/`ssh0`，复用当前 agent） |
| `history.zsh` | 历史记录配置 |
| `keybindings.zsh` | Emacs 风格键绑定 |
| `prompt.zsh` | 自定义 prompt（git 分支、SSH 感知） |
| `notify.zsh` | 每条命令显示原始精度耗时，桌面通知默认阈值 1 秒 |
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
proxy1   # 开启代理
proxy0   # 关闭代理
```

机器专属变量或密钥放在不会被 Git 跟踪的
`~/.config/zsh/.env.local`；为兼容现有机器，也会回退读取
`~/.config/.env.local`。可在其中设置 `ZSH_NOTIFY_THRESHOLD` 调整长任务通知
阈值（秒）。

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

### Codex / Claude 通知

`agent-notify` 提供两套独立 Hook 通知入口：

- `codex-notify.sh`：Codex 回合结束通知；权限请求使用 Codex 桌面端原生通知，
  以免“替我审批”启用时 `PermissionRequest` Hook 抢先误报
- `claude-notify.sh`：Claude 权限请求和回合结束通知

两者使用不同的应用名、音效和运行时去重目录。回合结束通知不会再表述为
“任务已完成”，并会显示触发通知的项目目录。依赖 `jq`、`libnotify` 和
`paplay`（PipeWire Pulse 兼容层）。

---

### rofi 启动器

配置文件：`rofi/.config/rofi/`

- 主题：grimm（深色风格，`#222222` 背景）
- 字体：JetBrainsMono Nerd Font Propo ExtraBold 14
- 包含电源菜单主题（`themes/powermenu.rasi`）

---

### fcitx5 输入法

配置文件：`fcitx5/.config/fcitx5/`。

Rime 雾凇预设位于
`fcitx5/.local/share/fcitx5/rime/default.custom.yaml`；部署 `fcitx5`
包时，Stow 会自动创建目标目录并链接该文件。

`fcitx5/.config/environment.d/ime.conf` 设置 `XMODIFIERS=@im=fcitx`，
使 XWayland 应用能够使用 Fcitx5 输入法。

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
