#!/bin/bash
# steps/04a_waybar_install.sh
# Waybar installation (only runs if selected)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck source=lib/utils.sh
source "$PROJECT_ROOT/lib/utils.sh"
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

# Check if waybar was selected
PANEL_CHOICE=$(cat /tmp/labwc_panel_choice 2>/dev/null || echo "waybar")
if [[ "$PANEL_CHOICE" != "waybar" ]]; then
    log_info "Skipping Waybar installation (selected: $PANEL_CHOICE)"
    exit 0
fi

log_step "Step 04a: Waybar Installation & UI Assets"

PACKAGES=(
    "waybar"
    "pcmanfm-qt"
    "fonts-font-awesome"
    "fonts-noto-color-emoji"
    "fonts-dejavu"
    "pavucontrol"
    "blueman"
    "network-manager-gnome"
    "jq"
    "gparted"
)

log_info "Installing Waybar components..."
for pkg in "${PACKAGES[@]}"; do
    safe_install "$pkg"
done

# Creación de directorios previa (para asegurar permisos antes del paso 05)
CURRENT_USER=$(logname 2>/dev/null || echo $SUDO_USER)
if [[ -n "$CURRENT_USER" ]]; then
    USER_HOME=$(eval echo "~$CURRENT_USER")
    mkdir -p "$USER_HOME/.config/waybar"
    chown -R "$CURRENT_USER":"$CURRENT_USER" "$USER_HOME/.config"
fi

log_success "Step 04 complete."