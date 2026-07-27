#!/usr/bin/env bash

# Arch Linux bootstrapper for this dotfiles repository.
# The safe default is to preview each GNU Stow package and skip conflicts.

set -uo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly -a AVAILABLE_PACKAGES=(
    agent-notify fcitx5 foot gtk mako niri nvim river rofi sway tmux waybar
    wofi yazi zsh
)
readonly -a STOW_IGNORE_ARGS=(
    '--ignore=\.config/fcitx5/conf/cached_layouts'
    '--ignore=\.config/niri/dms'
    '--ignore=\.config/waybar/\.bak'
)
readonly -a DESKTOP_PACKAGES=(
    niri waybar foot zsh rofi fcitx5 gtk mako nvim tmux yazi agent-notify
)
readonly -a TERMINAL_PACKAGES=(zsh foot nvim tmux yazi)

PROFILE=""
PACKAGE_ARGUMENT=""
TARGET_HOME="${HOME:-}"
AUR_HELPER=""
DRY_RUN=0
ASSUME_YES=0
INSTALL_DEPS=1
INSTALL_AUR=1
DEPLOY_STOW=1
BACKUP_CONFLICTS=0

declare -a SELECTED_PACKAGES=()
declare -a REPO_PACKAGES=()
declare -a AUR_PACKAGES=()
declare -a INSTALLED_STOW=()
declare -a SKIPPED_STOW=()
declare -a WARNINGS=()
declare -a FAILURES=()

if [[ -t 1 ]]; then
    readonly RED=$'\033[31m'
    readonly GREEN=$'\033[32m'
    readonly YELLOW=$'\033[33m'
    readonly BLUE=$'\033[34m'
    readonly BOLD=$'\033[1m'
    readonly RESET=$'\033[0m'
else
    readonly RED="" GREEN="" YELLOW="" BLUE="" BOLD="" RESET=""
fi

log() {
    printf '%s\n' "$*"
}

info() {
    printf '%s==>%s %s\n' "$BLUE" "$RESET" "$*"
}

success() {
    printf '%s==>%s %s\n' "$GREEN" "$RESET" "$*"
}

warn() {
    printf '%swarning:%s %s\n' "$YELLOW" "$RESET" "$*" >&2
}

error() {
    printf '%serror:%s %s\n' "$RED" "$RESET" "$*" >&2
}

die() {
    error "$*"
    exit 2
}

usage() {
    cat <<'EOF'
用法：
  ./install.sh [选项]

配置选择：
  --profile desktop|terminal|all
                         desktop：niri 主桌面（默认）
                         terminal：终端与命令行配置
                         all：包括 sway、river、wofi 等备用配置
  --packages LIST        仅处理指定 Stow 包，逗号或空格分隔

安装行为：
  --skip-deps            不使用 pacman 安装依赖
  --skip-aur             不安装 AUR 中的可选依赖
  --skip-stow            只安装依赖，不部署配置
  --backup-conflicts     将冲突文件备份后再部署
  --aur-helper COMMAND   指定 AUR helper（默认自动查找 yay/paru）
  --target DIR           Stow 目标目录（默认：$HOME）
  --dry-run              只显示计划并执行 Stow 预演，不写入系统
  -y, --yes              使用默认选择，包管理器不再询问
  -h, --help             显示帮助

示例：
  ./install.sh
  ./install.sh --profile desktop --yes
  ./install.sh --packages "zsh,nvim,tmux" --skip-aur
  ./install.sh --profile desktop --dry-run

默认不会覆盖已有配置。冲突包会被跳过，其他包继续部署。只有显式使用
--backup-conflicts 时，冲突项才会移至
~/.local/state/dotfiles-backups/<时间戳>/。
EOF
}

shell_join() {
    local item
    printf '  '
    printf '%q ' "$@"
    printf '\n'
}

contains() {
    local needle="$1"
    shift
    local item
    for item in "$@"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

append_unique() {
    local array_name="$1"
    shift
    local -n target_array="$array_name"
    local item
    for item in "$@"; do
        contains "$item" "${target_array[@]}" || target_array+=("$item")
    done
}

confirm() {
    local prompt="$1"
    local default="${2:-no}"
    local reply

    if (( ASSUME_YES )); then
        [[ "$default" == "yes" ]]
        return
    fi
    if [[ ! -t 0 ]]; then
        [[ "$default" == "yes" ]]
        return
    fi

    if [[ "$default" == "yes" ]]; then
        read -r -p "$prompt [Y/n] " reply
        [[ -z "$reply" || "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
    else
        read -r -p "$prompt [y/N] " reply
        [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
    fi
}

parse_arguments() {
    while (($#)); do
        case "$1" in
            --profile)
                (($# >= 2)) || die "--profile 缺少参数"
                PROFILE="$2"
                shift 2
                ;;
            --profile=*)
                PROFILE="${1#*=}"
                shift
                ;;
            --packages)
                (($# >= 2)) || die "--packages 缺少参数"
                PACKAGE_ARGUMENT="$2"
                shift 2
                ;;
            --packages=*)
                PACKAGE_ARGUMENT="${1#*=}"
                shift
                ;;
            --target)
                (($# >= 2)) || die "--target 缺少参数"
                TARGET_HOME="$2"
                shift 2
                ;;
            --target=*)
                TARGET_HOME="${1#*=}"
                shift
                ;;
            --aur-helper)
                (($# >= 2)) || die "--aur-helper 缺少参数"
                AUR_HELPER="$2"
                shift 2
                ;;
            --aur-helper=*)
                AUR_HELPER="${1#*=}"
                shift
                ;;
            --skip-deps)
                INSTALL_DEPS=0
                shift
                ;;
            --skip-aur)
                INSTALL_AUR=0
                shift
                ;;
            --skip-stow)
                DEPLOY_STOW=0
                shift
                ;;
            --backup-conflicts)
                BACKUP_CONFLICTS=1
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            -y|--yes)
                ASSUME_YES=1
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            --)
                shift
                (($# == 0)) || die "不接受位置参数：$*"
                ;;
            -*)
                die "未知选项：$1（使用 --help 查看帮助）"
                ;;
            *)
                die "不接受位置参数：$1（使用 --packages 指定配置包）"
                ;;
        esac
    done
}

choose_profile_interactively() {
    local choice
    cat <<'EOF'
请选择安装范围：
  1) desktop   niri 主桌面、常用终端工具与通知（推荐）
  2) terminal  zsh、foot、Neovim、tmux、Yazi
  3) all       所有配置，包括备用 compositor
  4) custom    手动输入 Stow 包名
EOF
    read -r -p "选择 [1]: " choice
    case "${choice:-1}" in
        1|desktop) PROFILE="desktop" ;;
        2|terminal) PROFILE="terminal" ;;
        3|all) PROFILE="all" ;;
        4|custom)
            log "可选包：${AVAILABLE_PACKAGES[*]}"
            read -r -p "包名（逗号或空格分隔）: " PACKAGE_ARGUMENT
            [[ -n "$PACKAGE_ARGUMENT" ]] || die "没有选择任何配置包"
            ;;
        *) die "无效选择：$choice" ;;
    esac
}

resolve_selection() {
    local normalized item

    [[ -z "$PROFILE" || -z "$PACKAGE_ARGUMENT" ]] ||
        die "--profile 与 --packages 不能同时使用"

    if [[ -z "$PROFILE" && -z "$PACKAGE_ARGUMENT" ]]; then
        if (( ASSUME_YES )) || [[ ! -t 0 ]]; then
            PROFILE="desktop"
        else
            choose_profile_interactively
        fi
    fi

    if [[ -n "$PACKAGE_ARGUMENT" ]]; then
        normalized="${PACKAGE_ARGUMENT//,/ }"
        read -r -a SELECTED_PACKAGES <<<"$normalized"
    else
        case "$PROFILE" in
            desktop) SELECTED_PACKAGES=("${DESKTOP_PACKAGES[@]}") ;;
            terminal) SELECTED_PACKAGES=("${TERMINAL_PACKAGES[@]}") ;;
            all) SELECTED_PACKAGES=("${AVAILABLE_PACKAGES[@]}") ;;
            *) die "未知 profile：$PROFILE" ;;
        esac
    fi

    ((${#SELECTED_PACKAGES[@]} > 0)) || die "没有选择任何配置包"

    local -a unique=()
    for item in "${SELECTED_PACKAGES[@]}"; do
        contains "$item" "${AVAILABLE_PACKAGES[@]}" ||
            die "不存在 Stow 包 '$item'；可选值：${AVAILABLE_PACKAGES[*]}"
        [[ -d "$SCRIPT_DIR/$item" ]] ||
            die "配置包目录不存在：$SCRIPT_DIR/$item"
        append_unique unique "$item"
    done
    SELECTED_PACKAGES=("${unique[@]}")
}

add_dependencies_for() {
    local package="$1"

    case "$package" in
        agent-notify)
            append_unique REPO_PACKAGES jq libnotify
            ;;
        fcitx5)
            append_unique REPO_PACKAGES fcitx5 fcitx5-rime \
                adobe-source-han-sans-cn-fonts
            append_unique AUR_PACKAGES rime-ice-git
            ;;
        foot)
            append_unique REPO_PACKAGES foot ttf-jetbrains-mono-nerd
            ;;
        gtk)
            append_unique REPO_PACKAGES cantarell-fonts
            ;;
        mako)
            append_unique REPO_PACKAGES mako libnotify
            ;;
        niri)
            append_unique REPO_PACKAGES niri waybar foot mako rofi swaylock \
                swayidle grim slurp wl-clipboard cliphist playerctl \
                brightnessctl polkit-gnome xwayland-satellite jq bc \
                util-linux iproute2 networkmanager curl wf-recorder \
                pipewire-pulse libnotify ddcutil satty awww wiremix \
                terminator alsa-tools otf-font-awesome
            append_unique AUR_PACKAGES wlrctl wifitui clash-verge-rev
            ;;
        nvim)
            append_unique REPO_PACKAGES neovim
            ;;
        river)
            append_unique REPO_PACKAGES river foot rofi pamixer playerctl \
                brightnessctl
            ;;
        rofi)
            append_unique REPO_PACKAGES rofi
            ;;
        sway)
            append_unique REPO_PACKAGES sway waybar swaylock swayidle grim \
                slurp wl-clipboard cliphist playerctl brightnessctl libpulse \
                swappy bemenu bluetui fcitx5 rofi
            ;;
        tmux)
            append_unique REPO_PACKAGES tmux
            ;;
        waybar)
            append_unique REPO_PACKAGES waybar jq bc util-linux iproute2 \
                networkmanager playerctl foot wiremix otf-font-awesome
            append_unique AUR_PACKAGES wifitui
            ;;
        wofi)
            append_unique REPO_PACKAGES wofi
            ;;
        yazi)
            append_unique REPO_PACKAGES yazi
            ;;
        zsh)
            append_unique REPO_PACKAGES zsh zsh-syntax-highlighting \
                zsh-autosuggestions starship fzf
            ;;
    esac
}

build_dependency_plan() {
    local package
    REPO_PACKAGES=(git stow)
    AUR_PACKAGES=()
    for package in "${SELECTED_PACKAGES[@]}"; do
        add_dependencies_for "$package"
    done
}

validate_environment() {
    [[ $EUID -ne 0 ]] ||
        die "请以普通用户运行；脚本只会在安装系统包时调用 sudo"
    [[ -n "$TARGET_HOME" ]] || die "无法确定目标 HOME，请使用 --target"
    [[ "$TARGET_HOME" == /* ]] || die "--target 必须是绝对路径：$TARGET_HOME"
    [[ "$TARGET_HOME" != "/" ]] || die "拒绝将根目录作为 Stow 目标"
    [[ -d "$TARGET_HOME" ]] || die "Stow 目标目录不存在：$TARGET_HOME"

    if (( INSTALL_DEPS )); then
        [[ -r /etc/arch-release ]] ||
            die "自动安装依赖仅支持 Arch Linux；其他系统请使用 --skip-deps"
        command -v pacman >/dev/null ||
            die "未找到 pacman"
    fi
}

print_plan() {
    log
    printf '%s安装计划%s\n' "$BOLD" "$RESET"
    log "  仓库：$SCRIPT_DIR"
    log "  目标：$TARGET_HOME"
    log "  配置：${SELECTED_PACKAGES[*]}"
    if (( INSTALL_DEPS )); then
        log "  官方仓库依赖：${REPO_PACKAGES[*]}"
        if (( INSTALL_AUR )) && ((${#AUR_PACKAGES[@]})); then
            log "  AUR 可选依赖：${AUR_PACKAGES[*]}"
        else
            log "  AUR 可选依赖：跳过"
        fi
    else
        log "  系统依赖：跳过"
    fi
    (( DEPLOY_STOW )) && log "  Stow：部署（冲突时$(
        (( BACKUP_CONFLICTS )) && printf '备份' || printf '跳过'
    )）" || log "  Stow：跳过"
    (( DRY_RUN )) && log "  模式：dry-run，不写入系统"
    log
}

missing_packages() {
    local package
    for package in "$@"; do
        pacman -Q "$package" >/dev/null 2>&1 || printf '%s\n' "$package"
    done
}

install_repo_dependencies() {
    local -a missing=()
    mapfile -t missing < <(missing_packages "${REPO_PACKAGES[@]}")
    if ((${#missing[@]} == 0)); then
        success "官方仓库依赖已满足"
        return
    fi

    info "需要安装 ${#missing[@]} 个官方仓库包：${missing[*]}"
    local -a command=(pacman -S --needed)
    (( ASSUME_YES )) && command+=(--noconfirm)
    command+=("${missing[@]}")
    (( EUID == 0 )) || command=(sudo "${command[@]}")

    if (( DRY_RUN )); then
        shell_join "${command[@]}"
        return
    fi

    if ! command -v sudo >/dev/null; then
        FAILURES+=("缺少 sudo，无法安装官方仓库依赖")
        error "${FAILURES[-1]}"
        return
    fi
    if "${command[@]}"; then
        success "官方仓库依赖安装完成"
    else
        FAILURES+=("pacman 依赖安装失败")
        error "${FAILURES[-1]}；继续进行可执行的后续步骤"
    fi
}

detect_aur_helper() {
    if [[ -n "$AUR_HELPER" ]]; then
        command -v "$AUR_HELPER" >/dev/null || return 1
        return
    fi
    if command -v yay >/dev/null; then
        AUR_HELPER="yay"
    elif command -v paru >/dev/null; then
        AUR_HELPER="paru"
    else
        return 1
    fi
}

install_aur_dependencies() {
    (( INSTALL_AUR )) || return
    ((${#AUR_PACKAGES[@]})) || return

    local -a missing=()
    mapfile -t missing < <(missing_packages "${AUR_PACKAGES[@]}")
    if ((${#missing[@]} == 0)); then
        success "AUR 可选依赖已满足"
        return
    fi

    if ! detect_aur_helper; then
        WARNINGS+=("未找到 yay/paru，已跳过 AUR 包：${missing[*]}")
        warn "${WARNINGS[-1]}"
        return
    fi

    info "需要安装 ${#missing[@]} 个 AUR 包：${missing[*]}"
    local -a command=("$AUR_HELPER" -S --needed)
    (( ASSUME_YES )) && command+=(--noconfirm)
    command+=("${missing[@]}")

    if (( DRY_RUN )); then
        shell_join "${command[@]}"
        return
    fi

    if "${command[@]}"; then
        success "AUR 可选依赖安装完成"
    else
        WARNINGS+=("AUR 可选依赖安装失败：${missing[*]}")
        warn "${WARNINGS[-1]}；配置部署将继续"
    fi
}

stow_preflight() {
    local package="$1"
    local output
    if output=$(stow --no-folding --simulate --verbose=0 \
        "${STOW_IGNORE_ARGS[@]}" \
        --dir="$SCRIPT_DIR" --target="$TARGET_HOME" "$package" 2>&1); then
        return 0
    fi
    [[ -z "$output" ]] || printf '%s\n' "$output" >&2
    return 1
}

backup_conflicts_for_package() {
    local package="$1"
    local backup_root="$2"
    local tracked source relative target parent partial component
    local moved=0
    local -a components=()

    # Only back up targets corresponding to version-controlled package files.
    # This prevents local caches or other untracked data from expanding the
    # scope of an explicitly requested backup.
    while IFS= read -r -d '' tracked; do
        source="$SCRIPT_DIR/$tracked"
        [[ -e "$source" || -L "$source" ]] || continue
        relative="${tracked#"$package/"}"
        target="$TARGET_HOME/$relative"

        IFS='/' read -r -a components <<<"$relative"
        partial="$TARGET_HOME"
        for component in "${components[@]:0:${#components[@]}-1}"; do
            partial="$partial/$component"
            if [[ (-e "$partial" || -L "$partial") && ! -d "$partial" ]]; then
                if (( DRY_RUN )); then
                    log "  [backup] $partial -> $backup_root/${partial#"$TARGET_HOME/"}"
                else
                    parent="$backup_root/${partial#"$TARGET_HOME/"}"
                    mkdir -p -- "$(dirname -- "$parent")"
                    mv -- "$partial" "$parent"
                fi
                ((moved += 1))
                break
            fi
        done

        if [[ -e "$target" || -L "$target" ]]; then
            if [[ "$target" -ef "$source" ]]; then
                continue
            fi
            if (( DRY_RUN )); then
                log "  [backup] $target -> $backup_root/$relative"
            else
                parent="$backup_root/$relative"
                mkdir -p -- "$(dirname -- "$parent")"
                mv -- "$target" "$parent"
            fi
            ((moved += 1))
        fi
    done < <(git -C "$SCRIPT_DIR" ls-files -z -- "$package")

    (( moved > 0 )) || return 1
    return 0
}

deploy_package() {
    local package="$1"
    local backup_root="$2"

    info "预演 Stow 包：$package"
    if stow_preflight "$package"; then
        if (( DRY_RUN )); then
            INSTALLED_STOW+=("$package")
            return
        fi
        if stow --no-folding "${STOW_IGNORE_ARGS[@]}" \
            --dir="$SCRIPT_DIR" --target="$TARGET_HOME" "$package"; then
            INSTALLED_STOW+=("$package")
            success "已部署：$package"
        else
            FAILURES+=("Stow 部署失败：$package")
            error "${FAILURES[-1]}"
        fi
        return
    fi

    if (( BACKUP_CONFLICTS )); then
        warn "$package 存在冲突，准备备份冲突项"
        if ! backup_conflicts_for_package "$package" "$backup_root"; then
            FAILURES+=("$package 预演失败，但没有识别出可安全备份的冲突项")
            error "${FAILURES[-1]}"
            SKIPPED_STOW+=("$package")
            return
        fi
        if (( DRY_RUN )); then
            INSTALLED_STOW+=("$package")
            return
        fi
        if stow_preflight "$package" &&
            stow --no-folding "${STOW_IGNORE_ARGS[@]}" \
                --dir="$SCRIPT_DIR" --target="$TARGET_HOME" "$package"; then
            INSTALLED_STOW+=("$package")
            success "已备份冲突并部署：$package"
        else
            FAILURES+=("备份冲突后仍无法部署：$package")
            error "${FAILURES[-1]}"
            SKIPPED_STOW+=("$package")
        fi
    else
        WARNINGS+=("$package 存在冲突，已跳过；可检查上方 Stow 输出或使用 --backup-conflicts")
        warn "${WARNINGS[-1]}"
        SKIPPED_STOW+=("$package")
    fi
}

deploy_dotfiles() {
    (( DEPLOY_STOW )) || return

    if ! command -v stow >/dev/null; then
        FAILURES+=("未找到 stow，无法部署配置")
        error "${FAILURES[-1]}"
        return
    fi

    local timestamp backup_root package
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_root="$TARGET_HOME/.local/state/dotfiles-backups/$timestamp"

    for package in "${SELECTED_PACKAGES[@]}"; do
        deploy_package "$package" "$backup_root"
    done

    if contains niri "${INSTALLED_STOW[@]}"; then
        if (( DRY_RUN )); then
            log "  mkdir -p $(printf '%q' "$TARGET_HOME/Pictures/Screenshots")"
        else
            mkdir -p -- "$TARGET_HOME/Pictures/Screenshots"
        fi
    fi

    if (( BACKUP_CONFLICTS )) && [[ -d "$backup_root" ]]; then
        WARNINGS+=("冲突文件备份在：$backup_root")
    fi
}

print_summary() {
    log
    printf '%s执行摘要%s\n' "$BOLD" "$RESET"
    if (( DEPLOY_STOW )); then
        if ((${#INSTALLED_STOW[@]})); then
            if (( DRY_RUN )); then
                log "  Stow 预演通过：${INSTALLED_STOW[*]}"
            else
                log "  已部署：${INSTALLED_STOW[*]}"
            fi
        fi
        ((${#SKIPPED_STOW[@]} == 0)) ||
            log "  已跳过：${SKIPPED_STOW[*]}"
    fi

    local item
    for item in "${WARNINGS[@]}"; do
        warn "$item"
    done
    for item in "${FAILURES[@]}"; do
        error "$item"
    done

    if contains niri "${SELECTED_PACKAGES[@]}"; then
        log
        warn "niri/output.kdl 含特定显示器布局；首次登录前请按本机输出调整"
        warn "startup.kdl 含 hda-verb、clash-verge、Pot-App 和提示音等个人项；请按需禁用"
    fi
    if contains zsh "${SELECTED_PACKAGES[@]}" &&
        ! contains niri "${SELECTED_PACKAGES[@]}"; then
        log
        warn "zsh/.zshrc 会在 tty1 尝试启动 niri；纯终端设备请先注释该启动块"
    fi

    log
    if ((${#FAILURES[@]})); then
        error "安装未完全成功（${#FAILURES[@]} 项失败）；其余可执行步骤已完成"
        return 1
    fi
    if ((${#SKIPPED_STOW[@]})); then
        warn "安装完成，但有 ${#SKIPPED_STOW[@]} 个冲突包未部署"
        return 1
    fi
    (( DRY_RUN )) && success "预演完成，未修改系统" || success "安装完成"
}

main() {
    parse_arguments "$@"
    resolve_selection
    validate_environment
    build_dependency_plan
    print_plan

    if ! (( ASSUME_YES )) && ! (( DRY_RUN )); then
        confirm "继续执行？" yes || {
            log "已取消"
            exit 0
        }
    fi

    if (( INSTALL_DEPS )); then
        install_repo_dependencies
        install_aur_dependencies
    fi
    deploy_dotfiles
    print_summary
}

main "$@"
