#!/usr/bin/env bash
set -euo pipefail

# Config Versions
NET_SDK_V="9.0"
NET_RUN_V="10.0"
NVM_V="0.40.4"

# 1. OS Detection (DOTFILES_TEST_OS overrides for testing)
if [ -n "${DOTFILES_TEST_OS:-}" ]; then
    OS="$DOTFILES_TEST_OS"
elif [ -f /etc/arch-release ]; then
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

# --- POSTGRESQL CLIENT (psql) ---
psql_i() {
    log_info "Installing PostgreSQL client (psql)..."
    if [ "$OS" = "arch" ]; then
        # No client-only split in official Arch repos; this pulls the
        # server binaries too, but nothing is enabled/started.
        sudo pacman -S --noconfirm postgresql
    else
        sudo apt-get install -y postgresql-client
    fi
}

psql_c() {
    log_info "Cleaning PostgreSQL client..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm postgresql || true
    else
        sudo apt-get purge -y postgresql-client || true
        sudo apt-get autoremove -y || true
    fi
}

# --- MICROSOFT SQL SERVER CLI (sqlcmd) ---
mssql_i() {
    log_info "Installing sqlcmd (mssql-tools18)..."
    if [ "$OS" = "arch" ]; then
        # AUR; pulls the msodbcsql18 dependency automatically.
        paru -S --noconfirm mssql-tools
    else
        curl https://packages.microsoft.com/keys/microsoft.asc | sudo tee /etc/apt/trusted.gpg.d/microsoft.asc >/dev/null
        curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list >/dev/null
        sudo apt-get update
        sudo ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev
        if ! grep -q "mssql-tools18/bin" "$HOME/.bashrc" 2>/dev/null; then
            echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> "$HOME/.bashrc"
        fi
    fi
}

mssql_c() {
    log_info "Cleaning sqlcmd..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm mssql-tools msodbcsql || true
    else
        sudo apt-get purge -y mssql-tools18 unixodbc-dev || true
        sudo apt-get autoremove -y || true
        sudo rm -f /etc/apt/sources.list.d/mssql-release.list /etc/apt/trusted.gpg.d/microsoft.asc || true
        sed -i '/mssql-tools18\/bin/d' "$HOME/.bashrc" 2>/dev/null || true
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

# --- DOCKER ---
docker_i() {
    log_info "Installing Docker (CLI + Compose plugin, no Docker Desktop)..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm docker docker-compose
    else
        sudo apt-get install -y docker.io docker-compose-v2
    fi

    log_info "Enabling and starting the docker service..."
    sudo systemctl enable --now docker.service

    if ! id -nG "$USER" | grep -qw docker; then
        log_info "Adding $USER to the docker group (log out/in, or run 'newgrp docker', for this to take effect)..."
        sudo usermod -aG docker "$USER"
    fi
}

docker_c() {
    log_info "Cleaning Docker..."
    sudo systemctl disable --now docker.service || true
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm docker docker-compose || true
    else
        sudo apt-get purge -y docker.io docker-compose-v2 || true
        sudo apt-get autoremove -y || true
    fi
    sudo gpasswd -d "$USER" docker || true
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

# --- GEMINI CLI ---
# Note: skill/plugin installs run through `agy` (Antigravity CLI), which is
# how Gemini CLI's plugin system is invoked now. Requires the 'antigravity'
# component installed first.
gemini_i() {
    log_info "Installing Gemini CLI..."
    if ! command -v npm >/dev/null 2>&1; then
        log_error "npm not found. Install the 'node' component first."
        return 1
    fi
    npm install -g @google/gemini-cli

    if ! command -v agy >/dev/null 2>&1; then
        log_error "agy not found. Install the 'antigravity' component first to get Gemini CLI's plugin/skill installs."
        return 0
    fi

    log_info "Installing caveman plugin for Gemini CLI (agy)..."
    agy plugin install https://github.com/JuliusBrussee/caveman || \
        log_error "Failed to install caveman plugin for Gemini CLI."

    log_info "Installing superpowers plugin for Gemini CLI (agy)..."
    agy plugin install https://github.com/obra/superpowers || \
        log_error "Failed to install superpowers plugin for Gemini CLI."
}

gemini_c() {
    log_info "Cleaning Gemini CLI..."
    if command -v agy >/dev/null 2>&1; then
        agy plugin uninstall caveman || true
        agy plugin uninstall superpowers || true
    fi
    if command -v npm >/dev/null 2>&1; then
        npm uninstall -g @google/gemini-cli || true
    fi
}

# --- CLAUDE CODE CLI ---
claude_i() {
    log_info "Installing Claude Code CLI..."
    curl -fsSL https://claude.ai/install.sh | bash

    log_info "Installing caveman plugin for Claude Code..."
    claude plugin marketplace add JuliusBrussee/caveman
    claude plugin install caveman@caveman

    log_info "Installing superpowers plugin for Claude Code..."
    claude plugin install superpowers@claude-plugins-official
}

claude_c() {
    log_info "Cleaning Claude Code CLI..."
    if command -v claude >/dev/null 2>&1; then
        claude plugin uninstall superpowers@claude-plugins-official || true
        claude plugin uninstall caveman@caveman || true
        claude plugin marketplace remove JuliusBrussee/caveman || true
    fi
    rm -f "$HOME/.local/bin/claude" || true
    rm -rf "$HOME/.local/share/claude" || true
}

# Prompts to pick which AI CLI(s) to install as part of a full run,
# rather than installing both unconditionally.
ai_cli_select() {
    if [ ! -t 0 ]; then
        log_info "No interactive terminal detected. Skipping AI CLI selection (run 'sys-setup.sh install gemini' or 'install claude' manually)."
        return 0
    fi

    echo "AI CLI tools:"
    echo "  1) Gemini CLI"
    echo "  2) Claude Code CLI"
    echo "  3) Both"
    echo "  4) Skip"
    read -r -p "Select option [1-4]: " AI_CHOICE
    case "$AI_CHOICE" in
        1) gemini_i ;;
        2) claude_i ;;
        3) gemini_i; claude_i ;;
        4|*) log_info "Skipping AI CLI installation." ;;
    esac
}

# --- GHOSTTY ---
ghostty_i() {
    log_info "Installing Ghostty Terminal..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm ghostty
    else
        if ! sudo apt-get install -y ghostty 2>/dev/null; then
            if command -v add-apt-repository >/dev/null 2>&1; then
                log_info "Ghostty not found in standard apt repository. Adding PPA..."
                sudo add-apt-repository ppa:mkasberg/ghostty-ubuntu -y
                sudo apt-get update
                sudo apt-get install -y ghostty
            else
                log_error "Ghostty could not be installed automatically via apt."
            fi
        fi
    fi
}

ghostty_c() {
    log_info "Cleaning Ghostty Terminal..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -Rns --noconfirm ghostty || true
    else
        sudo apt-get purge -y ghostty || true
        sudo apt-get autoremove -y || true
        if [ -f /etc/apt/sources.list.d/mkasberg-ubuntu-ghostty-ubuntu-*.list ]; then
            sudo add-apt-repository --remove ppa:mkasberg/ghostty-ubuntu -y || true
            sudo apt-get update || true
        fi
    fi
}

# --- BULK COMMANDS ---
install_all() {
    log_info "Starting full installation..."
    sys_update
    build_ess_i
    ghostty_i
    dotnet_i
    node_i
    go_i
    rust_i
    nvim_i
    lazygit_i
    docker_i
    psql_i
    mssql_i
    antigravity_i
    ai_cli_select
    treesitter_i
    log_info "Full installation completed!"
}

clean_all() {
    log_info "Starting full cleanup..."
    treesitter_c
    claude_c
    gemini_c
    antigravity_c
    mssql_c
    psql_c
    docker_c
    lazygit_c
    nvim_c
    rust_c
    go_c
    node_c
    dotnet_c
    build_ess_c
    ghostty_c
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
    echo "  build-ess, ghostty, dotnet, go, node, nvim, lazygit, docker, psql, mssql, treesitter, rust, antigravity, gemini, claude"
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
    ghostty)
        if [ "$ACTION" = "install" ]; then ghostty_i; else ghostty_c; fi
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
    docker)
        if [ "$ACTION" = "install" ]; then docker_i; else docker_c; fi
        ;;
    psql)
        if [ "$ACTION" = "install" ]; then psql_i; else psql_c; fi
        ;;
    mssql)
        if [ "$ACTION" = "install" ]; then mssql_i; else mssql_c; fi
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
    gemini)
        if [ "$ACTION" = "install" ]; then gemini_i; else gemini_c; fi
        ;;
    claude)
        if [ "$ACTION" = "install" ]; then claude_i; else claude_c; fi
        ;;
    *)
        log_error "Unknown component: $COMPONENT"
        show_help
        exit 1
        ;;
esac
