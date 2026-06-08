#!/usr/bin/env bash
set -euo pipefail

# Config Versions
NET_SDK_V="9.0"
NET_RUN_V="10.0"
NVM_V="0.40.4"

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

# --- BUILD ESSENTIALS ---
build_ess_i() {
    log_info "Installing build essentials..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm base-devel git curl ripgrep unzip xclip
    else
        sudo apt-get install -y build-essential git curl ripgrep unzip xclip
    fi
}

build_ess_c() {
    log_info "Cleaning build essentials..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm base-devel git curl ripgrep unzip xclip || true
    else
        sudo apt-get purge -y build-essential git curl ripgrep unzip xclip || true
        sudo apt-get autoremove -y || true
    fi
}

# --- DOTNET ---
dotnet_i() {
    log_info "Installing .NET SDK & Runtime..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm dotnet-runtime-${NET_RUN_V} dotnet-sdk-${NET_SDK_V} aspnet-runtime-${NET_RUN_V}
    else
        sudo add-apt-repository ppa:dotnet/backports -y
        sudo apt-get update
        sudo apt-get install -y dotnet-runtime-${NET_RUN_V} dotnet-sdk-${NET_SDK_V} aspnet-runtime-${NET_RUN_V}
    fi
}

dotnet_c() {
    log_info "Cleaning .NET SDK & Runtime..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm dotnet-runtime-${NET_RUN_V} dotnet-sdk-${NET_SDK_V} aspnet-runtime-${NET_RUN_V} || true
    else
        sudo apt-get purge -y "dotnet*-${NET_SDK_V}*" "aspnetcore*-${NET_RUN_V}*" "dotnet*-${NET_RUN_V}*" || true
        sudo apt-get autoremove -y || true
        sudo add-apt-repository --remove ppa:dotnet/backports -y || true
        sudo apt-get update || true
    fi
}

# --- GO ---
go_i() {
    log_info "Installing Go..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm go
    else
        sudo add-apt-repository ppa:longsleep/golang-backports -y
        sudo apt-get update
        sudo apt-get install -y golang-go
    fi
}

go_c() {
    log_info "Cleaning Go..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm go || true
    else
        sudo apt-get purge -y golang-go || true
        sudo add-apt-repository --remove ppa:longsleep/golang-backports -y || true
        sudo apt-get autoremove -y || true
    fi
}

# --- NODEJS ---
node_i() {
    log_info "Installing Node.js..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm fnm
        if ! grep -q 'fnm env' "$HOME/.bashrc"; then
            echo 'eval "$(fnm env --use-on-cd)"' >> "$HOME/.bashrc"
        fi
        eval "$(fnm env --use-on-cd)"
        fnm install --lts
    else
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_V}/install.sh" | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        nvm install --lts
        nvm use --lts
        nvm alias default "lts/*"
    fi
}

node_c() {
    log_info "Cleaning Node.js..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm fnm || true
        rm -rf "$HOME/.local/share/fnm" "$HOME/.fnm" || true
        sed -i '/fnm env/d' "$HOME/.bashrc" || true
    else
        export NVM_DIR="$HOME/.nvm"
        if [ -s "$NVM_DIR/nvm.sh" ]; then
            \. "$NVM_DIR/nvm.sh"
            nvm deactivate || true
            nvm uninstall lts || true
            nvm uninstall node || true
        fi
        rm -rf "$NVM_DIR" || true
        sed -i '/NVM_DIR/d' "$HOME/.bashrc" || true
        sed -i '/nvm.sh/d' "$HOME/.bashrc" || true
        sed -i '/bash_completion/d' "$HOME/.bashrc" || true
    fi
}

# --- NEOVIM ---
nvim_i() {
    log_info "Installing Neovim..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm neovim
    else
        sudo add-apt-repository ppa:neovim-ppa/unstable -y
        sudo apt-get update
        sudo apt-get install -y neovim
    fi
}

nvim_c() {
    log_info "Cleaning Neovim..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm neovim || true
    else
        sudo apt-get autoremove --purge -y neovim || true
        sudo add-apt-repository --remove ppa:neovim-ppa/unstable -y || true
        sudo apt-get update || true
    fi
}

# --- LAZYGIT ---
lazygit_i() {
    log_info "Installing Lazygit..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm lazygit
    else
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit /usr/local/bin/lazygit
        rm -f lazygit lazygit.tar.gz
    fi
}

lazygit_c() {
    log_info "Cleaning Lazygit..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm lazygit || true
    else
        sudo rm -f /usr/local/bin/lazygit || true
        sudo apt-get autoremove --purge -y lazygit || true
        sudo add-apt-repository --remove ppa:lazygit-team/release -y || true
        sudo apt-get update || true
    fi
}

# --- TREESITTER ---
treesitter_i() {
    log_info "Installing Tree-sitter CLI..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm tree-sitter-cli
    else
        sudo apt-get install -y tree-sitter-cli
    fi
}

treesitter_c() {
    log_info "Cleaning Tree-sitter CLI..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm tree-sitter-cli || true
    else
        sudo apt-get purge -y tree-sitter-cli || true
        sudo apt-get autoremove -y || true
    fi
}

# --- RUST ---
rust_i() {
    log_info "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
}

rust_c() {
    log_info "Cleaning Rust..."
    if command -v rustup >/dev/null 2>&1; then
        rustup self uninstall -y
    fi
}

# --- ANTIGRAVITY ---
antigravity_i() {
    log_info "Installing Antigravity CLI..."
    curl -fsSL https://antigravity.google/cli/install.sh | bash
}

antigravity_c() {
    log_info "Cleaning Antigravity CLI..."
    rm -f "$HOME/.local/bin/agy" "/usr/local/bin/agy" || true
    rm -rf "$HOME/.config/Antigravity" "$HOME/.gemini/antigravity-cli" || true
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

# --- BULK COMMANDS ---
install_all() {
    log_info "Starting full installation..."
    sys_update
    build_ess_i
    dotnet_i
    node_i
    go_i
    rust_i
    nvim_i
    lazygit_i
    antigravity_i
    treesitter_i
    discord_i
    steam_i
    log_info "Full installation completed!"
}

clean_all() {
    log_info "Starting full cleanup..."
    steam_c
    discord_c
    treesitter_c
    antigravity_c
    lazygit_c
    nvim_c
    rust_c
    go_c
    node_c
    dotnet_c
    build_ess_c
    log_info "Full cleanup completed!"
}

show_help() {
    echo "Usage: $0 <action> [component]"
    echo ""
    echo "Actions:"
    echo "  install [component]  Install everything or a specific component"
    echo "  clean [component]    Uninstall everything or a specific component"
    echo "  update               Run system update"
    echo ""
    echo "Components:"
    echo "  build-ess, dotnet, go, node, nvim, lazygit, treesitter, rust, antigravity, discord, steam"
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

# Map compatibility targets (e.g. node-i to install node, node-c to clean node)
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

# Run logic
case "$COMPONENT" in
    all)
        if [ "$ACTION" = "install" ]; then
            install_all
        else
            clean_all
        fi
        ;;
    build-ess)
        if [ "$ACTION" = "install" ]; then build_ess_i; else build_ess_c; fi
        ;;
    dotnet)
        if [ "$ACTION" = "install" ]; then dotnet_i; else dotnet_c; fi
        ;;
    go)
        if [ "$ACTION" = "install" ]; then go_i; else go_c; fi
        ;;
    node)
        if [ "$ACTION" = "install" ]; then node_i; else node_c; fi
        ;;
    nvim)
        if [ "$ACTION" = "install" ]; then nvim_i; else nvim_c; fi
        ;;
    lazygit)
        if [ "$ACTION" = "install" ]; then lazygit_i; else lazygit_c; fi
        ;;
    treesitter)
        if [ "$ACTION" = "install" ]; then treesitter_i; else treesitter_c; fi
        ;;
    rust)
        if [ "$ACTION" = "install" ]; then rust_i; else rust_c; fi
        ;;
    antigravity)
        if [ "$ACTION" = "install" ]; then antigravity_i; else antigravity_c; fi
        ;;
    discord)
        if [ "$ACTION" = "install" ]; then discord_i; else discord_c; fi
        ;;
    steam)
        if [ "$ACTION" = "install" ]; then steam_i; else steam_c; fi
        ;;
    *)
        log_error "Unknown component: $COMPONENT"
        show_help
        exit 1
        ;;
esac
