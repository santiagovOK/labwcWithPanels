#!/bin/bash
# steps/02_video_input.sh
# Updated to use global safe_install

LIB_PATH="lib/utils.sh"
if [[ ! -f "$LIB_PATH" && -f "../$LIB_PATH" ]]; then cd ..; fi
if [[ ! -f "$LIB_PATH" ]]; then echo "CRITICAL: Lib not found"; exit 1; fi
# shellcheck source=../lib/utils.sh
source "$LIB_PATH"
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

log_step "Step 02: Video & Input Subsystems"

# 1. Definir Paquetes
PACKAGES=(
    "libinput-bin"
    "libinput-tools"
    "xwayland"
    "libgl1-mesa-dri"
    "libglx-mesa0"
    "mesa-vulkan-drivers"
    "mesa-utils"
    "vulkan-tools"
    "drm-info"
    "mesa-va-drivers"
    "libva-drm2"
)

# Check Intel
if lspci | grep -i "Intel" | grep -i "VGA" > /dev/null; then
    PACKAGES+=("intel-media-va-driver")
fi

# 2. Instalación
log_info "Installing Graphics & Input stack..."
for pkg in "${PACKAGES[@]}"; do
    safe_install "$pkg"
done

# 3. Validación
if [ -d "/dev/dri" ]; then
    log_success "Graphics card detected."
else
    log_warn "Directory /dev/dri not found. Check drivers."
fi

log_success "Step 02 complete."