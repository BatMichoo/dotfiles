#!/usr/bin/env bash
set -euo pipefail

# 1. OS Detection
if [ -f /etc/arch-release ]; then
    OS="arch"
elif [ -f /etc/debian_version ]; then
    OS="debian"
else
    echo "Error: Unsupported OS. Could not detect Arch or Debian." >&2
    exit 1
fi

log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

# --- SYSTEM UPDATE ---
sys_update() {
    log_info "Updating system packages..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Syu --noconfirm
    else
        sudo apt-get update && sudo apt-get upgrade -y
    fi
}

# --- DISCORD ---
discord_i() {
    log_info "Installing Discord..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm discord
    else
        curl -Lo /tmp/discord.deb "https://discord.com/api/download?platform=linux&format=deb"
        sudo apt-get install -y /tmp/discord.deb
        rm -f /tmp/discord.deb
    fi
}

discord_c() {
    log_info "Cleaning Discord..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm discord || true
    else
        sudo apt-get purge -y discord || true
        sudo apt-get autoremove -y || true
    fi
}

# --- STEAM ---
steam_i() {
    log_info "Installing Steam..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm steam
    else
        sudo dpkg --add-architecture i386 || true
        sudo apt-get update
        sudo apt-get install -y steam-installer || sudo apt-get install -y steam
    fi
}

steam_c() {
    log_info "Cleaning Steam..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm steam || true
    else
        sudo apt-get purge -y steam-installer steam || true
        sudo apt-get autoremove -y || true
    fi
}

# --- GOOGLE CHROME ---
chrome_i() {
    log_info "Installing Google Chrome..."
    if [ "$OS" = "arch" ]; then
        paru -S --noconfirm google-chrome
    else
        curl -Lo /tmp/google-chrome.deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
        sudo apt-get install -y /tmp/google-chrome.deb
        rm -f /tmp/google-chrome.deb
    fi
}

chrome_c() {
    log_info "Cleaning Google Chrome..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm google-chrome || true
    else
        sudo apt-get purge -y google-chrome-stable || true
        sudo apt-get autoremove -y || true
    fi
}

# --- BULK COMMANDS ---
install_all() {
    log_info "Starting apps installation..."
    sys_update
    discord_i
    steam_i
    chrome_i
    log_info "Apps installation completed!"
}

clean_all() {
    log_info "Starting apps cleanup..."
    chrome_c
    steam_c
    discord_c
    log_info "Apps cleanup completed!"
}

show_help() {
    echo "Usage: $0 <action> [component]"
    echo ""
    echo "Actions:"
    echo "  install [component]  Install all apps or a specific app"
    echo "  clean [component]    Uninstall all apps or a specific app"
    echo "  update               Run system update"
    echo ""
    echo "Components:"
    echo "  discord, steam, chrome"
    echo ""
    echo "Legacy Target Support:"
    echo "  <component>-i        Same as 'install <component>'"
    echo "  <component>-c        Same as 'clean <component>'"
}

# --- ARGUMENT ROUTING ---
if [ $# -lt 1 ]; then
    show_help
    exit 1
fi

ACTION="$1"
COMPONENT="${2:-all}"

if [[ "$ACTION" =~ ^(.*)-(i|c)$ ]]; then
    COMP="${BASH_REMATCH[1]}"
    OP="${BASH_REMATCH[2]}"
    if [ "$OP" = "i" ]; then
        ACTION="install"
    else
        ACTION="clean"
    fi
    COMPONENT="$COMP"
fi

if [ "$ACTION" = "update" ]; then
    sys_update
    exit 0
fi

if [ "$ACTION" != "install" ] && [ "$ACTION" != "clean" ]; then
    show_help
    exit 1
fi

case "$COMPONENT" in
    all)
        if [ "$ACTION" = "install" ]; then
            install_all
        else
            clean_all
        fi
        ;;
    discord)
        if [ "$ACTION" = "install" ]; then discord_i; else discord_c; fi
        ;;
    steam)
        if [ "$ACTION" = "install" ]; then steam_i; else steam_c; fi
        ;;
    chrome)
        if [ "$ACTION" = "install" ]; then chrome_i; else chrome_c; fi
        ;;
    *)
        log_error "Unknown component: $COMPONENT"
        show_help
        exit 1
        ;;
esac
