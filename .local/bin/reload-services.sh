#!/usr/bin/env bash
# Restarts long-running, single-instance user services that cache their
# config in memory at startup, so dotfile edits actually take effect
# without a full logout/reboot.
#
# Restarting a service closes whatever windows/sessions it's currently
# serving (e.g. Ghostty's single-instance daemon), so this asks for
# confirmation before touching anything that's actually running.
set -euo pipefail

log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

# Format: "<systemd --user unit>:<friendly name>"
SERVICES=(
    "app-com.mitchellh.ghostty.service:Ghostty"
)

if ! command -v systemctl >/dev/null 2>&1; then
    log_info "systemctl not found. Skipping service reloads."
    exit 0
fi

# Find which of the known services are actually running.
to_restart=()
for entry in "${SERVICES[@]}"; do
    unit="${entry%%:*}"
    name="${entry#*:}"
    if systemctl --user is-active --quiet "$unit" 2>/dev/null; then
        to_restart+=("$entry")
    fi
done

if [ ${#to_restart[@]} -eq 0 ]; then
    log_info "No running services need a reload."
    exit 0
fi

echo "The following services are running and will be restarted to apply config changes:"
for entry in "${to_restart[@]}"; do
    echo "  - ${entry#*:} (closes any of its open windows)"
done

if [ ! -t 0 ]; then
    log_info "No interactive terminal detected. Skipping restart; run this script manually to apply changes."
    exit 0
fi

read -r -p "Proceed with restart? [y/N] " REPLY
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    log_info "Skipped. Run ~/.local/bin/reload-services.sh manually later to apply changes."
    exit 0
fi

for entry in "${to_restart[@]}"; do
    unit="${entry%%:*}"
    name="${entry#*:}"
    log_info "Restarting $name..."
    systemctl --user restart "$unit"
done

log_info "Service reload complete."
