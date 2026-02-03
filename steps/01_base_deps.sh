#!/bin/bash
# steps/01_base_deps.sh
# Step 01: Base Session, Hardware, Audio & Connectivity
# Updated to use global safe_install

LIB_PATH="lib/utils.sh"
if [[ ! -f "$LIB_PATH" && -f "../$LIB_PATH" ]]; then cd ..; fi
if [[ ! -f "$LIB_PATH" ]]; then echo "CRITICAL: Lib not found"; exit 1; fi
# shellcheck source=../lib/utils.sh
source "$LIB_PATH"
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

log_step "Step 01: Base Session, Audio & Hardware"

# 1. Definición de Paquetes
PACKAGES=(
    "dbus-user-session"
    "libpam-systemd"
    "seatd"
    "libseat1"
    "firmware-realtek"
    "pipewire-audio"
    "pipewire-pulse"
    "wireplumber"
    "libspa-0.2-bluetooth"
    "xdg-user-dirs"
    "bash-completion"
    "htop"
    "locales"
    "libfuse2t64"
    "mate-polkit"
)

log_info "Installing Base Dependencies..."

# 2. Instalación Interactiva
for pkg in "${PACKAGES[@]}"; do
    safe_install "$pkg"
done

# 3. Configuración de Grupos
log_info "Configuring user groups..."
CURRENT_USER=$(logname 2>/dev/null || echo $SUDO_USER)

if [[ -n "$CURRENT_USER" ]]; then
    for group in video input bluetooth; do
        # Verificar si el grupo existe antes de intentar añadir
        if getent group "$group" >/dev/null; then
            if ! groups "$CURRENT_USER" | grep -q "\b$group\b"; then
                usermod -aG "$group" "$CURRENT_USER"
                log_success "Added $CURRENT_USER to '$group'."
            fi
        fi
    done
    sudo -u "$CURRENT_USER" xdg-user-dirs-update
else
    log_warn "No sudo user detected. Skipping groups."
fi

# 4. Swap (Interactivo)
if grep -q "swap" /proc/swaps; then
    log_warn "Active Swap detected."
    response=$(safe_prompt "Disable Swap permanently? [y/N]" "N")
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        swapoff -a
        sed -i '/swap/s/^/#/' /etc/fstab
        log_success "Swap disabled."
    fi
fi

# 5. Servicios
if systemctl list-unit-files | grep -q seatd.service; then
    systemctl enable --now seatd
fi
if systemctl list-unit-files | grep -q wireplumber.service; then
    systemctl --global enable wireplumber.service
fi

log_success "Step 01 complete."