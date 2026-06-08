#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/.dotfiles"
TARGET_REMOTE="git@github.com:BatMichoo/dotfiles.git"
FISH_FUNCTIONS_DIR="$HOME/.config/fish/functions"
BACKUP_DIR_BASE="$HOME/.dotfiles-backup"

dotfiles_git() {
    git --git-dir="$DOTFILES_DIR/" --work-tree="$HOME" "$@"
}

echo "=== Initializing Bare Repository ==="
if [ ! -d "$DOTFILES_DIR" ]; then
    git init --bare "$DOTFILES_DIR"
    echo "Bare repository initialized at $DOTFILES_DIR"
else
    echo "Bare repository directory $DOTFILES_DIR already exists."
fi

echo "=== Configuring Remote ==="
if dotfiles_git remote | grep -q "^origin$"; then
    dotfiles_git remote set-url origin "$TARGET_REMOTE"
else
    dotfiles_git remote add origin "$TARGET_REMOTE"
fi

echo "=== Setting Local Configs ==="
dotfiles_git config --local status.showUntrackedFiles no
dotfiles_git symbolic-ref HEAD refs/heads/main 2>/dev/null || true

echo "=== Configuring Fish Alias ==="
mkdir -p "$FISH_FUNCTIONS_DIR"
cat << 'EOF' > "$FISH_FUNCTIONS_DIR/dotfiles.fish"
function dotfiles --wraps=git --description 'alias dotfiles git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
  git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME $argv
end
EOF
echo "Fish alias written to $FISH_FUNCTIONS_DIR/dotfiles.fish"

echo "=== Setting KDE Terminal Settings ==="
if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kdeglobals --group General --key TerminalApplication "ghostty"
    kwriteconfig6 --file kdeglobals --group General --key TerminalService "com.mitchellh.ghostty.desktop"
    echo "KDE default terminal set to Ghostty."
else
    echo "kwriteconfig6 not found. Skipping KDE settings change."
fi

echo "=== Setting KDE KWin Scripts and Shortcuts ==="
if command -v kwriteconfig6 >/dev/null 2>&1; then
    # Enable the custom KWin script
    kwriteconfig6 --file kwinrc --group Plugins --key toggle-maximize-tileEnabled true
    echo "Enabled toggle-maximize-tile KWin script."

    # Configure global shortcuts to map Meta+Up to the script and disable default Quick Tile Top
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Top" "none,none,Quick Tile Window to the Top"
    kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "toggle-maximize-tile:Toggle Maximize or Tile Top" "Meta+Up,none,Toggle Maximize or Tile Top"
    echo "Configured Meta+Up shortcuts."

    # Reload KWin configuration
    if command -v gdbus >/dev/null 2>&1; then
        gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.reconfigure >/dev/null 2>&1 || true
        (systemctl --user restart plasma-kglobalaccel.service >/dev/null 2>&1 || true)
        gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.reconfigure >/dev/null 2>&1 || true
        echo "Reloaded KWin and kglobalaccel configuration."
    fi
else
    echo "kwriteconfig6 not found. Skipping KWin script setup."
fi


echo "=== Fetching and Checking out main branch ==="
if dotfiles_git fetch origin main 2>/dev/null; then
    checkout_output=$(dotfiles_git checkout main 2>&1) || true
    
    if echo "$checkout_output" | grep -q "already on 'main'"; then
        echo "Already on main branch."
    elif echo "$checkout_output" | grep -q "Switched to branch 'main'"; then
        echo "Successfully checked out main branch."
    elif echo "$checkout_output" | grep -q "The following untracked working tree files would be overwritten by checkout"; then
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        CURRENT_BACKUP_DIR="$BACKUP_DIR_BASE/$TIMESTAMP"
        mkdir -p "$CURRENT_BACKUP_DIR"
        echo "Collision detected. Backing up colliding files to $CURRENT_BACKUP_DIR..."
        
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
            
        echo "Retrying checkout..."
        dotfiles_git checkout main
    else
        echo "Warning: Checkout failed or had unexpected output:"
        echo "$checkout_output"
    fi
else
    echo "Note: Remote main branch does not exist or fetch failed. If the repo is empty, this is expected."
fi

echo "=== Updating Submodules ==="
dotfiles_git submodule update --init --recursive

echo "=== Setup Completed Successfully ==="
