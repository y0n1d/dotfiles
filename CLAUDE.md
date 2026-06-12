# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

Arch Linux + Wayland personal dotfiles, managed by GNU Stow. Each top-level directory is a stow package that symlinks into `$HOME` when deployed. Primary compositor is niri (Wayland); sway and river are backup options.

## How to Deploy

```bash
# Deploy all packages
cd ~/dotfiles && stow */

# Deploy a single package
stow niri

# Remove a package
stow -D niri
```

No build system, Makefile, or install scripts exist. Dependencies are installed via `pacman` / `yay` (see README.md for full lists).

## Architecture

### Config Modularity

Configs that support it are split into modules via include directives:

- **niri** (`niri/.config/niri/`): `config.kdl` includes 7 `.kdl` modules (environment, input, output, layout, startup, window-rules, keybinds). Scripts live in `scripts/`.
- **zsh** (`zsh/.zshrc` → `zsh/.config/zsh/*.zsh`): 8 module files sourced from `.zshrc` (history, prompt, proxy, ssh, aliases, env, keybindings, yaziShellWrapper).
- **sway** (`sway/.config/sway/config`): includes `.conf` modules similarly to niri.

When editing niri or sway configs, check `config.kdl` / `config` for the include order. When editing zsh behavior, the entry point is `.zshrc` which sources modules from `~/.config/zsh/`.

### Key Components

| Package | Config format | Notes |
|---------|--------------|-------|
| niri | KDL | Main compositor. `keybinds.kdl` is ~340 lines. Startup runs `hda-verb` audio hack + `paplay` intro sound. |
| waybar | JSONC + CSS + shell scripts | 3 custom scripts in `scripts/`: `network-speed.sh`, `player.sh` (MPRIS), `cava.sh` (audio visualizer). |
| zsh | Zsh scripts | SSH sessions use custom `prompt.zsh`; local sessions use Starship. TTY1 auto-starts niri via `exec niri-session`. NVM is lazy-loaded. |
| rofi | RASI | Themes in `themes/` (grimm, powermenu). |
| fcitx5 | INI/conf | Rime + keyboard-us input. Catppuccin Mocha Pink theme. |
| nvim | VimL | Minimal: `init.vim` has only `set number`. |
| tmux | — | Only vendors the Catppuccin plugin; no `tmux.conf` in repo. |

### Color Scheme

Pink/peach accent palette used consistently: niri focus ring `#FAACAC`, waybar `#FF9AA2`, mako `#f5c2e7`, rofi grimm theme. fcitx5 uses Catppuccin Mocha Pink.

### Shell Scripts

Custom scripts live inside their respective stow packages (not a top-level `scripts/` dir):

- `niri/.config/niri/scripts/swayidle.sh` — idle lock/DPMS/suspend (300s/500s/1200s)
- `waybar/.config/waybar/scripts/network-speed.sh` — reads `/sys/class/net/` for RX/TX speed, WiFi SSID + signal
- `waybar/.config/waybar/scripts/player.sh` — MPRIS metadata streaming via `playerctl --follow`
- `waybar/.config/waybar/scripts/cava.sh` — cava visualizer to Unicode blocks
- `zsh/.config/zsh/scripts/pee.sh` — kaoyan exam countdown

## Conventions

- Mod key is Super (Win) throughout all compositors.
- Vim-style navigation (h/j/k/l) for window focus and movement in niri and sway.
- Proxy is managed via `proxy-on`/`proxy-off` shell functions (Clash Verge at `127.0.0.1:7897`).
- Screenshot workflow: `grim` + `slurp` → clipboard or `satty` editor. Save path: `~/Pictures/Screenshots/`.
- Translation integration hits Pot-App server at `127.0.0.1:60828` via curl.
- `.stow-local-ignore` excludes `.git`, `README.*`, `LICENSE`, swap files from symlinking.
- `.gitignore` excludes `*.log`, `.env.local`, `.claude/`.
