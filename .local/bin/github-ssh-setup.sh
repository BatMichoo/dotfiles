#!/usr/bin/env bash
set -euo pipefail

# 1. OS Detection & ksshaskpass installation (DOTFILES_TEST_OS overrides for testing)
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

# Ensure ksshaskpass is installed (Arch/CachyOS + KDE Plasma only)
if [ "$OS" = "arch" ]; then
    if ! command -v ksshaskpass >/dev/null 2>&1; then
        log_info "Installing ksshaskpass..."
        sudo pacman -S --noconfirm ksshaskpass
    else
        log_info "ksshaskpass is already installed."
    fi
else
    log_info "Skipping ksshaskpass (KDE Plasma-specific, Arch/CachyOS only)."
fi

# 2. Key Check & Generation
SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519"

if [ -f "$KEY_PATH" ]; then
    log_info "Existing SSH key found at $KEY_PATH. Skipping generation."
else
    # Prompts
    echo "=============================="
    echo "   GitHub SSH Key Generator"
    echo "=============================="
    echo

    read -p "Enter your GitHub email address: " EMAIL

    # Secure passphrase prompt
    read -s -p "Enter a passphrase for your new SSH key (leave empty for none): " PASS_1
    echo
    read -s -p "Confirm your passphrase: " PASS_2
    echo

    if [ "$PASS_1" != "$PASS_2" ]; then
        log_error "Passphrases do not match. Please run the script again."
        exit 1
    fi

    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"

    log_info "Generating new Ed25519 SSH key..."
    ssh-keygen -t ed25519 -C "$EMAIL" -N "$PASS_1" -f "$KEY_PATH"
fi

# 3. KDE Environment Configuration for ksshaskpass (Arch/CachyOS + KDE Plasma only)
if [ "$OS" = "arch" ]; then
    ENV_DIR="$HOME/.config/plasma-workspace/env"
    ASKPASS_CONFIG="$ENV_DIR/ssh-askpass.sh"
    if [ -f "$ASKPASS_CONFIG" ]; then
        log_info "KDE workspace SSH askpass environment already configured."
    else
        mkdir -p "$ENV_DIR"
        cat << 'EOF' > "$ASKPASS_CONFIG"
export SSH_ASKPASS="/usr/bin/ksshaskpass"
export SSH_ASKPASS_REQUIRE="prefer"
EOF
        chmod +x "$ASKPASS_CONFIG"
        log_info "Configured KDE workspace SSH askpass environment."
    fi
fi

# 4. Autostart Script Configuration
# Debian only: Arch/CachyOS gets SSH agent + key loading from keychain in
# .config/fish/config.fish instead. This autostart path exists to cover
# Debian, which doesn't get fish/keychain from any script here.
if [ "$OS" = "debian" ]; then
    BIN_DIR="$HOME/.local/bin"
    ADD_KEYS_SCRIPT="$BIN_DIR/ssh-add-keys.sh"
    if [ -f "$ADD_KEYS_SCRIPT" ]; then
        log_info "Key-adder script already exists at $ADD_KEYS_SCRIPT."
    else
        mkdir -p "$BIN_DIR"
        cat << 'EOF' > "$ADD_KEYS_SCRIPT"
#!/usr/bin/env bash
# Wait for KDE desktop environment and KWallet to settle
sleep 3
ssh-add -q "$HOME/.ssh/id_ed25519" </dev/null
EOF
        chmod +x "$ADD_KEYS_SCRIPT"
        log_info "Created key-adder script at $ADD_KEYS_SCRIPT"
    fi

    # 5. KDE Autostart Desktop Entry Configuration
    AUTOSTART_DIR="$HOME/.config/autostart"
    ADD_KEYS_DESKTOP="$AUTOSTART_DIR/ssh-add-keys.desktop"
    if [ -f "$ADD_KEYS_DESKTOP" ]; then
        log_info "Key-adder already registered in KDE autostart."
    else
        mkdir -p "$AUTOSTART_DIR"
        cat << EOF > "$ADD_KEYS_DESKTOP"
[Desktop Entry]
Exec=$ADD_KEYS_SCRIPT
Icon=dialog-password
Name=Add SSH Keys
Path=
Type=Application
X-KDE-AutostartScript=true
EOF
        log_info "Registered key-adder in KDE autostart."
    fi
else
    log_info "Skipping ssh-add-keys autostart (Arch/CachyOS uses keychain via fish instead)."
fi

# 6. Start ssh-agent and add key immediately
KEY_LOADED=false
if [ -f "$KEY_PATH" ]; then
    if ssh-add -l >/dev/null 2>&1 || [ $? -eq 1 ]; then
        KEY_FP=$(ssh-keygen -lf "$KEY_PATH" | awk '{print $2}')
        if ssh-add -l | grep -Fq "$KEY_FP"; then
            KEY_LOADED=true
        fi
    fi
fi

if [ "$KEY_LOADED" = true ]; then
    log_info "SSH key is already loaded in the active ssh-agent. Skipping agent start and key printing."
else
    # If agent is already running but key is not loaded, just add the key
    if ssh-add -l >/dev/null 2>&1 || [ $? -eq 1 ]; then
        log_info "Active ssh-agent detected. Adding key..."
        ssh-add "$KEY_PATH"
    else
        log_info "Starting ssh-agent and adding the key..."
        eval "$(ssh-agent -s)"
        ssh-add "$KEY_PATH"
    fi

    # 7. Instructions & Output
    echo
    echo "=================================================="
    echo "                  SUCCESS!"
    echo "=================================================="
    echo "SSH configuration verified."
    echo "Here is your public key. Copy the box below:"
    echo "--------------------------------------------------"
    cat "${KEY_PATH}.pub"
    echo "--------------------------------------------------"
    echo
    echo "Please add it to your GitHub account if you haven't already:"
    echo "👉 https://github.com/settings/keys"
    echo
    if [ "$OS" = "arch" ]; then
        echo "Note: The next time you log in, KDE will prompt you"
        echo "graphically for your passphrase. Make sure to check"
        echo "the 'Remember password' checkbox so KWallet saves it"
        echo "permanently."
    fi
    echo "=================================================="
fi
