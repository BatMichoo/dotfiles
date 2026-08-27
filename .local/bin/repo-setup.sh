#!/usr/bin/env bash
# Git Repository Setup Script
# Handles cloning the bare dotfiles repository, exclude configuration, and file checkout.
set -euo pipefail

# Configurations
DOTFILES_DIR="$HOME/.dotfiles"
TARGET_REMOTE="git@github.com:BatMichoo/dotfiles.git"
BACKUP_DIR_BASE="$HOME/.dotfiles-backup"

log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

dotfiles_git() {
    git --git-dir="$DOTFILES_DIR/" --work-tree="$HOME" "$@"
}

log_info "Setting up bare Git repository..."
if [ ! -d "$DOTFILES_DIR" ]; then
    log_info "Cloning bare repository from GitHub..."
    git clone --bare "$TARGET_REMOTE" "$DOTFILES_DIR"
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

# Extract configurations (checkout files to home directory)
log_info "Checking out dotfiles into active working tree..."
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

# Environment fallbacks & overrides
if [ -f "$HOME/.bashrc" ] && ! grep -q "export EDITOR=" "$HOME/.bashrc"; then
    log_info "Configuring default editor fallback in ~/.bashrc..."
    echo -e "\n# Set default editor to Neovim\nexport EDITOR=nvim\nexport VISUAL=nvim" >> "$HOME/.bashrc"
fi
