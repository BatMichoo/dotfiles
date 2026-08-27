#!/usr/bin/env bash
# Restarts long-running, single-instance user services that cache their
# config in memory at startup, so dotfile edits actually take effect
# without a full logout/reboot.
#
# Restarting a service closes whatever windows/sessions it's currently
# serving (e.g. Ghostty's single-instance daemon). This is usually run
# as part of a setup script from a different console, so rather than
# blocking on a prompt it gives a short countdown (Ctrl+C to abort)
# before restarting, and relaunches Ghostty afterwards if it was one
# of the services restarted.
set -euo pipefail

log_info() {
    echo -e "\033[1;34m[INFO]\033[0m $1"
}

# Format: "<systemd --user unit>:<friendly name>:<relaunch command, or empty>"
SERVICES=(
    "app-com.mitchellh.ghostty.service:Ghostty:ghostty"
)

if ! command -v systemctl >/dev/null 2>&1; then
    log_info "systemctl not found. Skipping service reloads."
    exit 0
fi

# Find which of the known services are actually running.
to_restart=()
for entry in "${SERVICES[@]}"; do
    unit="${entry%%:*}"
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
    IFS=':' read -r _ name _ <<< "$entry"
    echo "  - $name (closes any of its open windows)"
done

echo "Restarting in 3 (Ctrl+C to abort)..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1

for entry in "${to_restart[@]}"; do
    IFS=':' read -r unit name relaunch <<< "$entry"
    log_info "Restarting $name..."
    systemctl --user restart "$unit"
    if [ -n "$relaunch" ]; then
        log_info "Launching $name..."
        nohup "$relaunch" >/dev/null 2>&1 & disown
    fi
done

log_info "Service reload complete."
