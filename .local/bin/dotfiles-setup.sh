#!/usr/bin/env bash
# Main Dotfiles Setup & Orchestration Entry Script
set -euo pipefail

# Helper Logging
log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

# 1. OS Detection (DOTFILES_TEST_OS overrides for testing)
if [ -n "${DOTFILES_TEST_OS:-}" ]; then
    OS="$DOTFILES_TEST_OS"
elif [ -f /etc/arch-release ]; then
    OS="arch"
elif [ -f /etc/debian_version ]; then
    OS="debian"
else
    log_error "Unsupported OS. Could not detect Arch or Debian."
    exit 1
fi

# Flags initialized to false
RUN_BOOTSTRAP=false
RUN_KDE=false
RUN_SYS=false
RUN_APPS=false
RUN_UPDATE=false

show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -b, --bootstrap    Run SSH setup and repository bootstrap setup"
    echo "  -k, --kde          Run KDE settings setup"
    echo "  -s, --sys          Run system programming packages installation"
    echo "  -a, --apps         Run general applications installation"
    echo "  --all              Run all setup steps in order"
    echo "  --skip-sys         Run Bootstrap, KDE, and Apps setups (skip system packages)"
    echo "  -u, --update       Re-download the helper scripts already in ~/.local/bin"
    echo "  -h, --help         Show this help message"
}

# Parse options
while [ $# -gt 0 ]; do
    case "$1" in
        -b|--bootstrap)
            RUN_BOOTSTRAP=true
            shift
            ;;
        -k|--kde)
            RUN_KDE=true
            shift
            ;;
        -s|--sys)
            RUN_SYS=true
            shift
            ;;
        -a|--apps)
            RUN_APPS=true
            shift
            ;;
        -u|--update)
            RUN_UPDATE=true
            shift
            ;;
        --all)
            RUN_BOOTSTRAP=true
            RUN_KDE=true
            RUN_SYS=true
            RUN_APPS=true
            shift
            ;;
        --skip-sys)
            RUN_BOOTSTRAP=true
            RUN_KDE=true
            RUN_APPS=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            show_help
            exit 1
            ;;
    esac
done

# If no flags are set, run the interactive menu
if [ "$RUN_BOOTSTRAP" = false ] && [ "$RUN_KDE" = false ] && [ "$RUN_SYS" = false ] && [ "$RUN_APPS" = false ] && [ "$RUN_UPDATE" = false ]; then
    echo "==========================================="
    echo "    🌌 Unified Dotfiles Bootstrap Setup"
    echo "==========================================="
    echo "1) Full Setup (Bootstrap, KDE, System, Apps)"
    echo "2) KDE & Apps Setup (Skip System/Programming packages)"
    echo "3) Run Bootstrap Only (SSH Setup & Git Repo Setup)"
    echo "4) Configure KDE Desktop Only (kde-setup.sh)"
    echo "5) Install System Packages Only (sys-setup.sh)"
    echo "6) Install General Apps Only (apps-setup.sh)"
    echo "7) Update Helper Scripts (fetch latest from GitHub)"
    echo "8) Exit"
    echo "==========================================="
    read -p "Select option [1-8]: " OPTION
    case "$OPTION" in
        1)
            RUN_BOOTSTRAP=true
            RUN_KDE=true
            RUN_SYS=true
            RUN_APPS=true
            ;;
        2)
            RUN_BOOTSTRAP=true
            RUN_KDE=true
            RUN_APPS=true
            ;;
        3)
            RUN_BOOTSTRAP=true
            ;;
        4)
            RUN_KDE=true
            ;;
        5)
            RUN_SYS=true
            ;;
        6)
            RUN_APPS=true
            ;;
        7)
            RUN_UPDATE=true
            ;;
        *)
            echo "Exiting..."
            exit 0
            ;;
    esac
fi

# Define target paths
SCRIPTS_DIR="$HOME/.local/bin"
SCRIPTS_URL="https://raw.githubusercontent.com/BatMichoo/dotfiles/main/.local/bin"
RELOAD_SERVICES_PATH="$SCRIPTS_DIR/reload-services.sh"

HELPER_SCRIPTS=(dotfiles-setup.sh github-ssh-setup.sh repo-setup.sh kde-setup.sh sys-setup.sh apps-setup.sh reload-services.sh)

# Downloads a helper script into ~/.local/bin. Writes to a temp file and moves
# it into place, so replacing the copy of this script bash is executing is safe.
download_script() {
    local name="$1"
    local path="$SCRIPTS_DIR/$name"
    local tmp="$path.download"

    log_info "Downloading $name..."
    mkdir -p "$SCRIPTS_DIR"
    curl -fsSL "$SCRIPTS_URL/$name" -o "$tmp"
    chmod +x "$tmp"
    mv "$tmp" "$path"
}

# Runs a helper script from ~/.local/bin, downloading it first only when it
# isn't on disk yet (e.g. a single step picked before bootstrap).
run_setup_script() {
    local name="$1"
    shift
    local path="$SCRIPTS_DIR/$name"

    if [ ! -f "$path" ]; then
        download_script "$name"
    fi

    chmod +x "$path"
    "$path" "$@"
}

# Refresh only the helper scripts already on disk; missing ones are still
# fetched on demand when their step runs
if [ "$RUN_UPDATE" = true ]; then
    for name in "${HELPER_SCRIPTS[@]}"; do
        if [ -f "$SCRIPTS_DIR/$name" ]; then
            download_script "$name"
        fi
    done
fi

# Execute components in dependency order: Bootstrap -> KDE -> Sys -> Apps
if [ "$RUN_BOOTSTRAP" = true ]; then
    run_setup_script github-ssh-setup.sh
    run_setup_script repo-setup.sh
fi

if [ "$RUN_KDE" = true ]; then
    run_setup_script kde-setup.sh
fi

if [ "$RUN_SYS" = true ]; then
    run_setup_script sys-setup.sh install
fi

if [ "$RUN_APPS" = true ]; then
    run_setup_script apps-setup.sh install
fi

# Skip the service reload for an update-only run: no config changed
if [ -f "$RELOAD_SERVICES_PATH" ] && { [ "$RUN_BOOTSTRAP" = true ] || [ "$RUN_KDE" = true ] || [ "$RUN_SYS" = true ] || [ "$RUN_APPS" = true ]; }; then
    chmod +x "$RELOAD_SERVICES_PATH"
    "$RELOAD_SERVICES_PATH"
fi

echo
echo "==========================================="
echo "    🎉 Setup Action(s) Complete!"
echo "==========================================="
