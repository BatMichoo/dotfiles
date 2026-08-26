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

# 1. OS Detection
if [ -f /etc/arch-release ]; then
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
if [ "$RUN_BOOTSTRAP" = false ] && [ "$RUN_KDE" = false ] && [ "$RUN_SYS" = false ] && [ "$RUN_APPS" = false ]; then
    echo "==========================================="
    echo "    🌌 Unified Dotfiles Bootstrap Setup"
    echo "==========================================="
    echo "1) Full Setup (Bootstrap, KDE, System, Apps)"
    echo "2) KDE & Apps Setup (Skip System/Programming packages)"
    echo "3) Run Bootstrap Only (SSH Setup & Git Repo Setup)"
    echo "4) Configure KDE Desktop Only (kde-setup.sh)"
    echo "5) Install System Packages Only (sys-setup.sh)"
    echo "6) Install General Apps Only (apps-setup.sh)"
    echo "7) Exit"
    echo "==========================================="
    read -p "Select option [1-7]: " OPTION
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
        *)
            echo "Exiting..."
            exit 0
            ;;
    esac
fi

# Define target paths
SSH_SETUP_PATH="$HOME/.local/bin/github-ssh-setup.sh"
REPO_SETUP_PATH="$HOME/.local/bin/repo-setup.sh"
KDE_SETUP_PATH="$HOME/.local/bin/kde-setup.sh"
SYS_SETUP_PATH="$HOME/.local/bin/sys-setup.sh"
APPS_SETUP_PATH="$HOME/.local/bin/apps-setup.sh"
RELOAD_SERVICES_PATH="$HOME/.local/bin/reload-services.sh"

SSH_SETUP_URL="https://raw.githubusercontent.com/BatMichoo/dotfiles/main/.local/bin/github-ssh-setup.sh"
REPO_SETUP_URL="https://raw.githubusercontent.com/BatMichoo/dotfiles/main/.local/bin/repo-setup.sh"

run_bootstrap() {
    # 1. Run SSH setup
    if [ -f "$SSH_SETUP_PATH" ]; then
        chmod +x "$SSH_SETUP_PATH"
        "$SSH_SETUP_PATH"
    else
        log_info "Downloading github-ssh-setup.sh..."
        curl -fsSL "$SSH_SETUP_URL" -o /tmp/github-ssh-setup.sh
        chmod +x /tmp/github-ssh-setup.sh
        /tmp/github-ssh-setup.sh
    fi

    # 2. Run Repo Setup
    if [ -f "$REPO_SETUP_PATH" ]; then
        chmod +x "$REPO_SETUP_PATH"
        "$REPO_SETUP_PATH"
    else
        log_info "Downloading repo-setup.sh..."
        curl -fsSL "$REPO_SETUP_URL" -o /tmp/repo-setup.sh
        chmod +x /tmp/repo-setup.sh
        /tmp/repo-setup.sh
    fi
}

# Execute components in dependency order: Bootstrap -> KDE -> Sys -> Apps
if [ "$RUN_BOOTSTRAP" = true ]; then
    run_bootstrap
fi

if [ "$RUN_KDE" = true ]; then
    if [ -f "$KDE_SETUP_PATH" ]; then
        chmod +x "$KDE_SETUP_PATH"
        "$KDE_SETUP_PATH"
    else
        log_error "Error: kde-setup.sh not found on disk. Run bootstrap first."
        exit 1
    fi
fi

if [ "$RUN_SYS" = true ]; then
    if [ -f "$SYS_SETUP_PATH" ]; then
        chmod +x "$SYS_SETUP_PATH"
        "$SYS_SETUP_PATH" install
    else
        log_error "Error: sys-setup.sh not found on disk. Run bootstrap first."
        exit 1
    fi
fi

if [ "$RUN_APPS" = true ]; then
    if [ -f "$APPS_SETUP_PATH" ]; then
        chmod +x "$APPS_SETUP_PATH"
        "$APPS_SETUP_PATH" install
    else
        log_error "Error: apps-setup.sh not found on disk. Run bootstrap first."
        exit 1
    fi
fi

if [ -f "$RELOAD_SERVICES_PATH" ]; then
    chmod +x "$RELOAD_SERVICES_PATH"
    "$RELOAD_SERVICES_PATH"
fi

echo
echo "==========================================="
echo "    🎉 Setup Action(s) Complete!"
echo "==========================================="
