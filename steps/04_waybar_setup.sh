#!/bin/bash
# steps/04_waybar_setup.sh
# Updated to use global safe_install

LIB_PATH="lib/utils.sh"
if [[ ! -f "$LIB_PATH" && -f "../$LIB_PATH" ]]; then cd ..; fi
if [[ ! -f "$LIB_PATH" ]]; then echo "CRITICAL: Lib not found"; exit 1; fi
# shellcheck source=../lib/utils.sh
source "$LIB_PATH"
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

log_step "Step 04: Waybar & UI Assets"

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