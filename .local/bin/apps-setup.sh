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

# --- FIREFOX ---
firefox_i() {
    log_info "Installing Firefox..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm firefox
    else
        sudo apt-get install -y firefox
    fi
}

firefox_c() {
    log_info "Cleaning Firefox..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm firefox || true
    else
        sudo apt-get purge -y firefox || true
        sudo apt-get autoremove -y || true
    fi
}

# --- BRAVE ---
brave_i() {
    log_info "Installing Brave..."
    if [ "$OS" = "arch" ]; then
        paru -S --noconfirm brave-bin
    else
        curl -fsS https://dl.brave.com/install.sh | sh
    fi
}

brave_c() {
    log_info "Cleaning Brave..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm brave-bin || true
    else
        sudo apt-get purge -y brave-browser || true
        sudo apt-get autoremove -y || true
        sudo rm -f /etc/apt/sources.list.d/brave-browser-release.list || true
    fi
}

# Prompts to pick which browser(s) to install as part of a full run,
# rather than installing Chrome unconditionally.
browser_select() {
    if [ ! -t 0 ]; then
        log_info "No interactive terminal detected. Skipping browser selection (run 'apps-setup.sh install chrome|firefox|brave' manually)."
        return 0
    fi

    echo "Browsers:"
    echo "  1) Google Chrome"
    echo "  2) Firefox"
    echo "  3) Brave"
    echo "  4) All of the above"
    echo "  5) Skip"
    read -r -p "Select option [1-5]: " BROWSER_CHOICE
    case "$BROWSER_CHOICE" in
        1) chrome_i ;;
        2) firefox_i ;;
        3) brave_i ;;
        4) chrome_i; firefox_i; brave_i ;;
        5|*) log_info "Skipping browser installation." ;;
    esac
}

# --- BULK COMMANDS ---
install_all() {
    log_info "Starting apps installation..."
    sys_update
    discord_i
    steam_i
    browser_select
    log_info "Apps installation completed!"
}

clean_all() {
    log_info "Starting apps cleanup..."
    brave_c
    firefox_c
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
    echo "  discord, steam, chrome, firefox, brave"
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
    firefox)
        if [ "$ACTION" = "install" ]; then firefox_i; else firefox_c; fi
        ;;
    brave)
        if [ "$ACTION" = "install" ]; then brave_i; else brave_c; fi
        ;;
    *)
        log_error "Unknown component: $COMPONENT"
        show_help
        exit 1
        ;;
esac
