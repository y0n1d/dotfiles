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

PROFILE="${DOTFILES_PROFILE:-}"
PACKAGE_ARGUMENT="${DOTFILES_PACKAGES:-}"
TARGET_HOME="${DOTFILES_TARGET_HOME:-${HOME:-}}"
AUR_HELPER="${DOTFILES_AUR_HELPER:-}"
DRY_RUN=0
ASSUME_YES=0
INSTALL_DEPS=1
INSTALL_AUR=1
DEPLOY_STOW=1
BACKUP_CONFLICTS=0
PROFILE_FROM_CLI=0
PACKAGES_FROM_CLI=0

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
Usage:
  ./install.sh [OPTIONS]

Configuration selection:
  --profile desktop|terminal|all
                         desktop: primary niri desktop (default)
                         terminal: shell and terminal tools
                         all: include sway, river, wofi, and other fallbacks
  --packages LIST        Process only the listed Stow packages
                         (comma- or space-separated)

Installation behavior:
  --skip-deps            Do not install dependencies with pacman
  --skip-aur             Do not install optional AUR dependencies
  --skip-stow            Install dependencies without deploying dotfiles
  --backup-conflicts     Back up conflicting files before deployment
  --aur-helper COMMAND   Set the AUR helper (auto-detect yay or paru by default)
  --target DIR           Set the Stow target (default: DOTFILES_TARGET_HOME or $HOME)
  --dry-run              Show the plan and run Stow simulations without writes
  -y, --yes              Use defaults and disable package-manager prompts
  -h, --help             Show this help message

Environment variables:
  DOTFILES_TARGET_HOME   Default Stow target (falls back to $HOME)
  DOTFILES_PROFILE       Default profile
  DOTFILES_PACKAGES      Default comma- or space-separated package list
  DOTFILES_AUR_HELPER    Default AUR helper

Examples:
  ./install.sh
  ./install.sh --profile desktop --yes
  ./install.sh --packages "zsh,nvim,tmux" --skip-aur
  ./install.sh --profile desktop --dry-run
  DOTFILES_PROFILE=terminal ./install.sh --yes
  DOTFILES_TARGET_HOME=/home/alice ./install.sh --profile desktop

Existing configuration is never overwritten by default. Packages with
conflicts are skipped while the remaining packages continue. With
--backup-conflicts, conflicting items are moved to
~/.local/state/dotfiles-backups/<timestamp>/.

Uppercase names such as DIR, LIST, and COMMAND in this help are argument
labels, not placeholders that must be edited in the script.
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

set_cli_profile() {
    (( PACKAGES_FROM_CLI == 0 )) ||
        die "--profile and --packages cannot be used together"
    PROFILE="$1"
    PACKAGE_ARGUMENT=""
    PROFILE_FROM_CLI=1
}

set_cli_packages() {
    (( PROFILE_FROM_CLI == 0 )) ||
        die "--profile and --packages cannot be used together"
    PACKAGE_ARGUMENT="$1"
    PROFILE=""
    PACKAGES_FROM_CLI=1
}

parse_arguments() {
    while (($#)); do
        case "$1" in
            --profile)
                (($# >= 2)) || die "--profile requires an argument"
                set_cli_profile "$2"
                shift 2
                ;;
            --profile=*)
                set_cli_profile "${1#*=}"
                shift
                ;;
            --packages)
                (($# >= 2)) || die "--packages requires an argument"
                set_cli_packages "$2"
                shift 2
                ;;
            --packages=*)
                set_cli_packages "${1#*=}"
                shift
                ;;
            --target)
                (($# >= 2)) || die "--target requires an argument"
                TARGET_HOME="$2"
                shift 2
                ;;
            --target=*)
                TARGET_HOME="${1#*=}"
                shift
                ;;
            --aur-helper)
                (($# >= 2)) || die "--aur-helper requires an argument"
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
                (($# == 0)) || die "positional arguments are not supported: $*"
                ;;
            -*)
                die "unknown option: $1 (use --help for usage)"
                ;;
            *)
                die "positional argument '$1' is not supported; use --packages"
                ;;
        esac
    done
}

choose_profile_interactively() {
    local choice
    cat <<'EOF'
Select an installation profile:
  1) desktop   Primary niri desktop, terminal tools, and notifications (recommended)
  2) terminal  zsh, foot, Neovim, tmux, and Yazi
  3) all       Every configuration, including fallback compositors
  4) custom    Enter Stow package names manually
EOF
    read -r -p "Selection [1]: " choice
    case "${choice:-1}" in
        1|desktop) PROFILE="desktop" ;;
        2|terminal) PROFILE="terminal" ;;
        3|all) PROFILE="all" ;;
        4|custom)
            log "Available packages: ${AVAILABLE_PACKAGES[*]}"
            read -r -p "Packages (comma- or space-separated): " PACKAGE_ARGUMENT
            [[ -n "$PACKAGE_ARGUMENT" ]] || die "no configuration packages selected"
            ;;
        *) die "invalid selection: $choice" ;;
    esac
}

resolve_selection() {
    local normalized item

    [[ -z "$PROFILE" || -z "$PACKAGE_ARGUMENT" ]] ||
        die "--profile and --packages cannot be used together"

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
            *) die "unknown profile: $PROFILE" ;;
        esac
    fi

    ((${#SELECTED_PACKAGES[@]} > 0)) || die "no configuration packages selected"

    local -a unique=()
    for item in "${SELECTED_PACKAGES[@]}"; do
        contains "$item" "${AVAILABLE_PACKAGES[@]}" ||
            die "unknown Stow package '$item'; available: ${AVAILABLE_PACKAGES[*]}"
        [[ -d "$SCRIPT_DIR/$item" ]] ||
            die "package directory does not exist: $SCRIPT_DIR/$item"
        append_unique unique "$item"
    done
    SELECTED_PACKAGES=("${unique[@]}")
}

add_dependencies_for() {
    local package="$1"

    case "$package" in
        agent-notify)
            # The hooks parse JSON, display desktop notifications, and play
            # the Freedesktop notification sounds with paplay.
            append_unique REPO_PACKAGES jq libnotify libpulse
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
            append_unique REPO_PACKAGES niri waybar foot mako rofi rofi-emoji \
                swaylock swayidle grim slurp wl-clipboard cliphist playerctl \
                brightnessctl polkit-gnome xwayland-satellite jq bc \
                util-linux iproute2 networkmanager curl wf-recorder \
                pipewire-pulse wireplumber libpulse libnotify ddcutil satty \
                awww wiremix terminator alsa-tools otf-font-awesome fzf mpv \
                procps-ng xdg-desktop-portal-gnome xdg-desktop-portal-gtk
            # fsearch, Pot, wlrctl and swaylock-effects are invoked directly
            # from key bindings; their packages are not in Arch's official repos.
            append_unique AUR_PACKAGES wlrctl wifitui clash-verge-rev \
                fsearch pot-translation swaylock-effects
            ;;
        nvim)
            append_unique REPO_PACKAGES neovim
            ;;
        river)
            append_unique REPO_PACKAGES river foot rofi pamixer playerctl \
                brightnessctl
            ;;
        rofi)
            # The niri configuration invokes Rofi's separately packaged
            # emoji mode, and the checked-in theme selects this Nerd Font.
            append_unique REPO_PACKAGES rofi rofi-emoji ttf-jetbrains-mono-nerd
            ;;
        sway)
            append_unique REPO_PACKAGES sway waybar swaylock swayidle grim \
                slurp wl-clipboard cliphist playerctl brightnessctl libpulse \
                swappy bemenu bluetui fcitx5 rofi swww blueman swaync \
                alsa-utils pipewire-pulse wireplumber procps-ng
            append_unique AUR_PACKAGES clash-verge-rev rofi-power-menu \
                swaylock-effects
            ;;
        tmux)
            append_unique REPO_PACKAGES tmux
            ;;
        waybar)
            append_unique REPO_PACKAGES waybar jq bc util-linux iproute2 \
                networkmanager playerctl foot wiremix otf-font-awesome cava \
                mpd pipewire-pulse wireplumber libpulse procps-ng \
                ttf-jetbrains-mono-nerd
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
                zsh-autosuggestions starship fzf openssh xdg-utils python \
                python-requests glow
            # zen-browser is the configured BROWSER and default-browser helper.
            append_unique AUR_PACKAGES zen-browser-bin
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
        die "run this script as a regular user; sudo is used only for system packages"
    [[ -n "$TARGET_HOME" ]] || die "cannot determine the target HOME; use --target"
    [[ "$TARGET_HOME" == /* ]] || die "--target must be an absolute path: $TARGET_HOME"
    [[ "$TARGET_HOME" != "/" ]] || die "refusing to use the filesystem root as the Stow target"
    [[ -d "$TARGET_HOME" ]] || die "Stow target directory does not exist: $TARGET_HOME"

    if (( INSTALL_DEPS )); then
        [[ -r /etc/arch-release ]] ||
            die "automatic dependency installation supports Arch Linux only; use --skip-deps elsewhere"
        command -v pacman >/dev/null ||
            die "pacman was not found"
    fi
}

print_plan() {
    log
    printf '%sInstallation plan%s\n' "$BOLD" "$RESET"
    log "  Repository: $SCRIPT_DIR"
    log "  Target: $TARGET_HOME"
    log "  Configuration: ${SELECTED_PACKAGES[*]}"
    if (( INSTALL_DEPS )); then
        log "  Official repository dependencies: ${REPO_PACKAGES[*]}"
        if (( INSTALL_AUR )) && ((${#AUR_PACKAGES[@]})); then
            log "  Optional AUR dependencies: ${AUR_PACKAGES[*]}"
        else
            log "  Optional AUR dependencies: skipped"
        fi
    else
        log "  System dependencies: skipped"
    fi
    (( DEPLOY_STOW )) && log "  Stow: deploy ($(
        (( BACKUP_CONFLICTS )) && printf 'back up' || printf 'skip'
    ) conflicts)" || log "  Stow: skipped"
    (( DRY_RUN )) && log "  Mode: dry-run; no system changes"
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
        success "Official repository dependencies are satisfied"
        return
    fi

    info "${#missing[@]} official repository package(s) need installation: ${missing[*]}"
    local -a command=(pacman -S --needed)
    (( ASSUME_YES )) && command+=(--noconfirm)
    command+=("${missing[@]}")
    (( EUID == 0 )) || command=(sudo "${command[@]}")

    if (( DRY_RUN )); then
        shell_join "${command[@]}"
        return
    fi

    if ! command -v sudo >/dev/null; then
        FAILURES+=("sudo is unavailable; cannot install official repository dependencies")
        error "${FAILURES[-1]}"
        return
    fi
    if "${command[@]}"; then
        success "Official repository dependencies installed"
    else
        FAILURES+=("pacman dependency installation failed")
        error "${FAILURES[-1]}; continuing with the remaining available steps"
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
        success "Optional AUR dependencies are satisfied"
        return
    fi

    if ! detect_aur_helper; then
        WARNINGS+=("yay/paru was not found; skipped AUR packages: ${missing[*]}")
        warn "${WARNINGS[-1]}"
        return
    fi

    info "${#missing[@]} AUR package(s) need installation: ${missing[*]}"
    local -a command=("$AUR_HELPER" -S --needed)
    (( ASSUME_YES )) && command+=(--noconfirm)
    command+=("${missing[@]}")

    if (( DRY_RUN )); then
        shell_join "${command[@]}"
        return
    fi

    if "${command[@]}"; then
        success "Optional AUR dependencies installed"
    else
        WARNINGS+=("optional AUR dependency installation failed: ${missing[*]}")
        warn "${WARNINGS[-1]}; dotfile deployment will continue"
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

    info "Simulating Stow package: $package"
    if stow_preflight "$package"; then
        if (( DRY_RUN )); then
            INSTALLED_STOW+=("$package")
            return
        fi
        if stow --no-folding "${STOW_IGNORE_ARGS[@]}" \
            --dir="$SCRIPT_DIR" --target="$TARGET_HOME" "$package"; then
            INSTALLED_STOW+=("$package")
            success "Deployed: $package"
        else
            FAILURES+=("Stow deployment failed: $package")
            error "${FAILURES[-1]}"
        fi
        return
    fi

    if (( BACKUP_CONFLICTS )); then
        warn "$package has conflicts; preparing to back up conflicting items"
        if ! backup_conflicts_for_package "$package" "$backup_root"; then
            FAILURES+=("$package simulation failed, but no safely backupable conflicts were identified")
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
            success "Backed up conflicts and deployed: $package"
        else
            FAILURES+=("deployment still failed after backing up conflicts: $package")
            error "${FAILURES[-1]}"
            SKIPPED_STOW+=("$package")
        fi
    else
        WARNINGS+=("$package has conflicts and was skipped; inspect the Stow output or use --backup-conflicts")
        warn "${WARNINGS[-1]}"
        SKIPPED_STOW+=("$package")
    fi
}

deploy_dotfiles() {
    (( DEPLOY_STOW )) || return

    if ! command -v stow >/dev/null; then
        FAILURES+=("stow was not found; cannot deploy configuration")
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
        WARNINGS+=("conflicting files were backed up to: $backup_root")
    fi
}

print_summary() {
    log
    printf '%sExecution summary%s\n' "$BOLD" "$RESET"
    if (( DEPLOY_STOW )); then
        if ((${#INSTALLED_STOW[@]})); then
            if (( DRY_RUN )); then
                log "  Stow simulation passed: ${INSTALLED_STOW[*]}"
            else
                log "  Deployed: ${INSTALLED_STOW[*]}"
            fi
        fi
        ((${#SKIPPED_STOW[@]} == 0)) ||
            log "  Skipped: ${SKIPPED_STOW[*]}"
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
        warn "niri/output.kdl contains machine-specific layouts; adjust it before the first login"
        warn "startup.kdl contains personal hda-verb, clash-verge, Pot-App, and sound entries; disable them as needed"
    fi
    if contains zsh "${SELECTED_PACKAGES[@]}" &&
        ! contains niri "${SELECTED_PACKAGES[@]}"; then
        log
        warn "zsh/.zshrc starts niri on tty1; comment out that block on terminal-only systems"
    fi

    log
    if ((${#FAILURES[@]})); then
        error "installation was incomplete (${#FAILURES[@]} failure(s)); all other available steps completed"
        return 1
    fi
    if ((${#SKIPPED_STOW[@]})); then
        warn "installation completed with ${#SKIPPED_STOW[@]} conflicting package(s) not deployed"
        return 1
    fi
    (( DRY_RUN )) && success "Dry run completed; no system changes made" || success "Installation completed"
}

main() {
    parse_arguments "$@"
    resolve_selection
    validate_environment
    build_dependency_plan
    print_plan

    if ! (( ASSUME_YES )) && ! (( DRY_RUN )); then
        confirm "Continue?" yes || {
            log "Cancelled"
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
