#!/usr/bin/env bash
set -euo pipefail

# Configurations
DOTFILES_DIR="$HOME/.dotfiles"
TARGET_REMOTE="git@github.com:BatMichoo/dotfiles.git"
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
echo "    🌌 Unified Dotfiles Bootstrap Setup"
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

# Start ssh-agent in the current session so git clone works immediately
eval "$(ssh-agent -s)"
ssh-add "$KEY_PATH" || true


# 3. Clean Bare Repository Cloning
echo
log_info "Setting up bare Git repository..."
if [ ! -d "$DOTFILES_DIR" ]; then
    log_info "Cloning bare repository from GitHub..."
    dotfiles_git clone --bare "$TARGET_REMOTE" "$DOTFILES_DIR"
else
    log_info "Bare repository directory $DOTFILES_DIR already exists."
fi

# Apply visibility and rule constraints immediately to the cloned engine
log_info "Configuring repository parameters..."
dotfiles_git config --local status.showUntrackedFiles no

# Configure exclude rules for the bare repository
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


# 4. Extract Configurations (Checkout Files to Disk)
log_info "Checking out dotfiles into active working tree..."

# Natively attempt checkout now that the bare clone tracked structural state perfectly
if ! dotfiles_git checkout main 2>/dev/null; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    CURRENT_BACKUP_DIR="$BACKUP_DIR_BASE/$TIMESTAMP"
    log_info "Collision detected. Safely backing up conflicting local files to $CURRENT_BACKUP_DIR..."

    # Query Git directly via diff for paths conflicting with the remote state
    dotfiles_git diff --name-only origin/main | while read -r file; do
        if [ -n "$file" ] && [ -e "$HOME/$file" ]; then
            mkdir -p "$CURRENT_BACKUP_DIR/$(dirname "$file")"
            mv "$HOME/$file" "$CURRENT_BACKUP_DIR/$file"
            echo "  Moved: $file -> $CURRENT_BACKUP_DIR/$file"
        fi
    done

    log_info "Retrying final configuration checkout..."
    dotfiles_git checkout main
else
    log_info "Successfully completed dotfiles repository checkout."
fi

log_info "Updating submodules recursively..."
dotfiles_git submodule update --init --recursive


# 5. Environment Fallbacks & Overrides
# Note: Your Fish alias file (dotfiles.fish) is now cleanly dropped in place by the checkout.
if [ -f "$HOME/.bashrc" ] && ! grep -q "export EDITOR=" "$HOME/.bashrc"; then
    log_info "Configuring default editor fallback in ~/.bashrc..."
    echo -e "\n# Set default editor to Neovim\nexport EDITOR=nvim\nexport VISUAL=nvim" >> "$HOME/.bashrc"
fi


# 6. Run Desktop Configuration Scripts (Now safely present on disk)
log_info "Running KDE desktop setup script..."
KDE_SETUP_PATH="$HOME/.local/bin/kde-setup.sh"
if [ -f "$KDE_SETUP_PATH" ]; then
    chmod +x "$KDE_SETUP_PATH"
    "$KDE_SETUP_PATH" || log_error "Warning: kde-setup.sh exited with an error status."
else
    log_error "Warning: kde-setup.sh not found on disk. Skipping KDE setup configuration."
fi


# 7. Run System Setup Script (Programming Tools)
SYS_SETUP_PATH="$HOME/.local/bin/sys-setup.sh"
if [ -f "$SYS_SETUP_PATH" ]; then
    log_info "Running system packages installation..."
    chmod +x "$SYS_SETUP_PATH"
    "$SYS_SETUP_PATH" install
else
    log_error "Error: sys-setup.sh not found after checkout. Setup incomplete."
    exit 1
fi


# 8. Run General Applications Script (Discord, Steam, Chrome)
APPS_SETUP_PATH="$HOME/.local/bin/apps-setup.sh"
if [ -f "$APPS_SETUP_PATH" ]; then
    log_info "Running general apps installation (Discord, Steam, Chrome)..."
    chmod +x "$APPS_SETUP_PATH"
    "$APPS_SETUP_PATH" install
else
    log_error "Error: apps-setup.sh not found after checkout. Setup incomplete."
    exit 1
fi

echo
echo "==========================================="
echo "    🎉 Environment Setup Complete!"
echo "    Please restart your session/logout to"
echo "    apply KDE settings completely."
echo "==========================================="
