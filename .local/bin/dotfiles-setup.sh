#!/usr/bin/env bash
set -euo pipefail

# Configurations
DOTFILES_DIR="$HOME/.dotfiles"
TARGET_REMOTE="git@github.com:BatMichoo/dotfiles.git"
FISH_FUNCTIONS_DIR="$HOME/.config/fish/functions"
BACKUP_DIR_BASE="$HOME/.dotfiles-backup"

dotfiles_git() {
    git --git-dir="$DOTFILES_DIR/" --work-tree="$HOME" "$@"
}

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

echo "==========================================="
echo "   🌌 Unified Dotfiles Bootstrap Setup"
echo "==========================================="
echo

# 2. Run SSH & passphrase configuration via downloaded script
SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519"

if [ ! -f "$KEY_PATH" ]; then
    log_info "No SSH key found. Downloading and running github-ssh-setup.sh..."
    SSH_SETUP_URL="https://raw.githubusercontent.com/BatMichoo/dotfiles/main/.local/bin/github-ssh-setup.sh"
    curl -fsSL "$SSH_SETUP_URL" -o /tmp/github-ssh-setup.sh
    chmod +x /tmp/github-ssh-setup.sh
    /tmp/github-ssh-setup.sh
else
    log_info "Existing SSH key found at $KEY_PATH. Proceeding..."
fi

# Start ssh-agent in the current session so git checkout works immediately
eval "$(ssh-agent -s)"
ssh-add "$KEY_PATH" || true

# 3. Bare Repository Initialization
echo
log_info "Initializing bare Git repository..."
if [ ! -d "$DOTFILES_DIR" ]; then
    git init --bare "$DOTFILES_DIR"
    log_info "Bare repository initialized at $DOTFILES_DIR"
else
    log_info "Bare repository directory $DOTFILES_DIR already exists."
fi

log_info "Configuring remote origin..."
if dotfiles_git remote | grep -q "^origin$"; then
    dotfiles_git remote set-url origin "$TARGET_REMOTE"
else
    dotfiles_git remote add origin "$TARGET_REMOTE"
fi

log_info "Configuring local repository options..."
dotfiles_git config --local status.showUntrackedFiles no
dotfiles_git symbolic-ref HEAD refs/heads/main 2>/dev/null || true

log_info "Configuring exclude rules for the bare repository..."
mkdir -p "$DOTFILES_DIR/info"
cat << 'EOF' > "$DOTFILES_DIR/info/exclude"
# Ignore system/caching folders
.cache/
.dbus/
.local/share/Trash/
.cargo/
.npm/

# Ignore sensitive keys and private data
.ssh/id_*
.ssh/known_hosts*
.gnupg/

# Ignore temp files and histories
.node_repl_history
.bash_history
.lesshst
EOF


# 4. Fish Alias Configuration
log_info "Configuring Fish alias..."
mkdir -p "$FISH_FUNCTIONS_DIR"
cat << 'EOF' > "$FISH_FUNCTIONS_DIR/dotfiles.fish"
function dotfiles --wraps=git --description 'alias dotfiles git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
  git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME $argv
end
EOF

# 5. KDE settings configuration
log_info "Running KDE desktop setup script..."
KDE_SETUP_PATH="$HOME/.local/bin/kde-setup.sh"
if [ -f "$KDE_SETUP_PATH" ]; then
    chmod +x "$KDE_SETUP_PATH"
    "$KDE_SETUP_PATH"
else
    log_error "Warning: kde-setup.sh not found. Skipping KDE DE config."
fi

# 6. Fetch and Checkout configurations
log_info "Fetching and checking out dotfiles..."
if dotfiles_git fetch origin main; then
    checkout_output=$(dotfiles_git checkout main 2>&1) || true
    
    if echo "$checkout_output" | grep -q "already on 'main'"; then
        log_info "Already on main branch."
    elif echo "$checkout_output" | grep -q "Switched to branch 'main'"; then
        log_info "Successfully checked out main branch."
    elif echo "$checkout_output" | grep -q "The following untracked working tree files would be overwritten by checkout"; then
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        CURRENT_BACKUP_DIR="$BACKUP_DIR_BASE/$TIMESTAMP"
        mkdir -p "$CURRENT_BACKUP_DIR"
        log_info "Collision detected. Backing up colliding files to $CURRENT_BACKUP_DIR..."
        
        echo "$checkout_output" | \
            awk '/The following untracked working tree files would be overwritten by checkout:/,/Please move or remove them before you switch branches./' | \
            grep -E '^(\t|[ ]{4})' | \
            sed -E 's/^[ \t]+//' | \
            while read -r file; do
                if [ -n "$file" ] && [ -e "$HOME/$file" ]; then
                    mkdir -p "$CURRENT_BACKUP_DIR/$(dirname "$file")"
                    mv "$HOME/$file" "$CURRENT_BACKUP_DIR/$file"
                    echo "  Moved: $file -> $CURRENT_BACKUP_DIR/$file"
                fi
            done
            
        log_info "Retrying checkout..."
        dotfiles_git checkout main
    else
        log_error "Warning: Checkout failed or had unexpected output:"
        echo "$checkout_output"
    fi
else
    log_error "Error: Fetching from origin failed. Check your internet connection and GitHub key registry."
    exit 1
fi

log_info "Updating submodules recursively..."
dotfiles_git submodule update --init --recursive

# 7. Run System Setup Script
SYS_SETUP_PATH="$HOME/.local/bin/sys-setup.sh"
if [ -f "$SYS_SETUP_PATH" ]; then
    log_info "Running system packages installation..."
    chmod +x "$SYS_SETUP_PATH"
    "$SYS_SETUP_PATH" install
else
    log_error "Error: sys-setup.sh not found after checkout. Setup incomplete."
    exit 1
fi

echo
echo "==========================================="
echo "   🎉 Environment Setup Complete!"
echo "   Please restart your session/logout to"
echo "   apply KDE KWallet settings."
echo "==========================================="
