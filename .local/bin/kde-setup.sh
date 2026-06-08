#!/usr/bin/env bash
set -euo pipefail

log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

log_error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

log_info "Configuring KDE settings..."

if ! command -v kwriteconfig6 >/dev/null 2>&1; then
    log_error "kwriteconfig6 not found. Skipping KDE settings."
    exit 0
fi

# A. Terminal Defaults & MIME associations
kwriteconfig6 --file kdeglobals --group General --key TerminalApplication "ghostty"
kwriteconfig6 --file kdeglobals --group General --key TerminalService "com.mitchellh.ghostty.desktop"

if command -v xdg-mime >/dev/null 2>&1; then
    log_info "Setting Neovim as default plain text handler..."
    xdg-mime default nvim.desktop text/plain
fi

# B. Keyboard Layouts (US + Bulgarian Traditional Phonetic, Alt+Shift to switch)
kwriteconfig6 --file kxkbrc --group Layout --key Use true
kwriteconfig6 --file kxkbrc --group Layout --key LayoutList "us,bg"
kwriteconfig6 --file kxkbrc --group Layout --key VariantList ",phonetic"
kwriteconfig6 --file kxkbrc --group Layout --key DisplayNames ","
kwriteconfig6 --file kxkbrc --group Layout --key Options "grp:alt_shift_toggle"

# C. KWin Tiling
kwriteconfig6 --file kwinrc --group Plugins --key toggle-maximize-tileEnabled true
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Top" "none,none,Quick Tile Window to the Top"
kwriteconfig6 --file kglobalshortcutsrc --group kwin --key "toggle-maximize-tile:Toggle Maximize or Tile Top" "Meta+Up,none,Toggle Maximize or Tile Top"

# D. PowerDevil settings (30m screen off, 1h 30m sleep, never dim display on AC)
kwriteconfig6 --file powerdevilrc --group AC --group Display --key DimDisplayWhenIdle false
kwriteconfig6 --file powerdevilrc --group AC --group Display --key TurnOffDisplayIdleTimeoutSec 1800
kwriteconfig6 --file powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendIdleTimeoutSec 5400
kwriteconfig6 --file powerdevilrc --group Battery --group Display --key TurnOffDisplayIdleTimeoutSec 1800
kwriteconfig6 --file powerdevilrc --group Battery --group SuspendAndShutdown --key AutoSuspendIdleTimeoutSec 5400

# E. Live Configuration Reloads
if command -v gdbus >/dev/null 2>&1; then
    gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.reconfigure >/dev/null 2>&1 || true
    (systemctl --user restart plasma-kglobalaccel.service >/dev/null 2>&1 || true)
    gdbus call --session --dest org.kde.KWin --object-path /KWin --method org.kde.KWin.reconfigure >/dev/null 2>&1 || true
    gdbus call --session --dest org.freedesktop.PowerManagement --object-path /org/kde/Solid/PowerManagement --method org.kde.Solid.PowerManagement.reparseConfiguration >/dev/null 2>&1 || true
    # Reload keyboard configuration daemon
    gdbus call --session --dest org.kde.keyboard --object-path /Layouts --method org.kde.KeyboardLayouts.reconfigure >/dev/null 2>&1 || true
fi

log_info "KDE configuration applied successfully."
