#!/usr/bin/env bash
set -euo pipefail

# 1. OS Detection & ksshaskpass installation
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

# Ensure ksshaskpass is installed
if ! command -v ksshaskpass >/dev/null 2>&1; then
    log_info "Installing ksshaskpass..."
    if [ "$OS" = "arch" ]; then
        sudo pacman -S --noconfirm ksshaskpass
    else
        sudo apt-get update && sudo apt-get install -y ksshaskpass
    fi
else
    log_info "ksshaskpass is already installed."
fi

# 2. Prompts
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

# 3. Key Generation
SSH_DIR="$HOME/.ssh"
KEY_PATH="$SSH_DIR/id_ed25519"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

if [ -f "$KEY_PATH" ]; then
    BACKUP_PATH="${KEY_PATH}_backup_$(date +%Y%m%d_%H%M%S)"
    log_info "Existing SSH key found. Backing up to $BACKUP_PATH..."
    mv "$KEY_PATH" "$BACKUP_PATH"
    if [ -f "${KEY_PATH}.pub" ]; then
        mv "${KEY_PATH}.pub" "${BACKUP_PATH}.pub"
    fi
fi

log_info "Generating new Ed25519 SSH key..."
ssh-keygen -t ed25519 -C "$EMAIL" -N "$PASS_1" -f "$KEY_PATH"

# 4. KDE Environment Configuration for ksshaskpass
ENV_DIR="$HOME/.config/plasma-workspace/env"
mkdir -p "$ENV_DIR"
cat << 'EOF' > "$ENV_DIR/ssh-askpass.sh"
export SSH_ASKPASS="/usr/bin/ksshaskpass"
export SSH_ASKPASS_REQUIRE="prefer"
EOF
chmod +x "$ENV_DIR/ssh-askpass.sh"
log_info "Configured KDE workspace SSH askpass environment."

# 5. Autostart Script Configuration
BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"
cat << 'EOF' > "$BIN_DIR/ssh-add-keys.sh"
#!/usr/bin/env bash
# Wait for KDE desktop environment and KWallet to settle
sleep 3
ssh-add -q "$HOME/.ssh/id_ed25519" </dev/null
EOF
chmod +x "$BIN_DIR/ssh-add-keys.sh"
log_info "Created key-adder script at ~/.local/bin/ssh-add-keys.sh"

# 6. KDE Autostart Desktop Entry Configuration
AUTOSTART_DIR="$HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"
cat << 'EOF' > "$AUTOSTART_DIR/ssh-add-keys.desktop"
[Desktop Entry]
Exec=/home/batmicho/.local/bin/ssh-add-keys.sh
Icon=dialog-password
Name=Add SSH Keys
Path=
Type=Application
X-KDE-AutostartScript=true
EOF
log_info "Registered key-adder in KDE autostart."

# 7. Instructions & Output
echo
echo "=================================================="
echo "                  SUCCESS!"
echo "=================================================="
echo "Your new SSH key has been generated."
echo "Here is your public key. Copy the box below:"
echo "--------------------------------------------------"
cat "${KEY_PATH}.pub"
echo "--------------------------------------------------"
echo
echo "Please add it to your GitHub account:"
echo "👉 https://github.com/settings/keys"
echo
echo "Note: The next time you log in, KDE will prompt you"
echo "graphically for your passphrase. Make sure to check"
echo "the 'Remember password' checkbox so KWallet saves it"
echo "permanently."
echo "=================================================="
