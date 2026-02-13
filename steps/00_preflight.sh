#!/bin/bash
# steps/00_preflight.sh
# Step 00: System Preparation & Base Updates
# Update: Adds interactive error handling (Retry/Skip/Abort)
# TODO: Add NONINTERACTIVE mode support to skip user prompts (e.g., retry/skip/abort)

# ==============================================================================
# BOOTSTRAP
# ==============================================================================
LIB_PATH="lib/utils.sh"
if [[ ! -f "$LIB_PATH" && -f "../$LIB_PATH" ]]; then cd ..; fi
if [[ ! -f "$LIB_PATH" ]]; then echo "CRITICAL: Lib not found"; exit 1; fi
# shellcheck source=../lib/utils.sh
source "$LIB_PATH"
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

# Exit codes for specific failures
readonly EXIT_NOT_ROOT=60
readonly EXIT_WRONG_DISTRO=61
readonly EXIT_NO_INTERNET=80
readonly EXIT_USER_ABORTED=62

# ==============================================================================
# FUNCIONES AUXILIARES
# ==============================================================================

# Función robusta para instalar paquetes con opción de continuar
safe_install() {
    local pkg="$1"
    
    # Bucle infinito hasta éxito o decisión del usuario
    while true; do
        if is_installed "$pkg"; then
            log_success "$pkg is already installed."
            return 0
        fi

        log_info "Attempting to install: $pkg..."
        
        # Desactivamos temporalmente el cierre automático por error (set +e)
        # para capturar el fallo nosotros mismos.
        set +e
        apt-get install -y -q "$pkg"
        local exit_code=$?
        set -e  # Reactivamos modo estricto

        if [ $exit_code -eq 0 ]; then
            log_success "$pkg installed successfully."
            return 0
        else
            echo ""
            log_warn "Failed to install '$pkg' (Exit Code: $exit_code)."
            log_warn "This might be due to network issues or missing repositories."
            
            # Preguntar al usuario qué hacer
            echo -e "${Y}How do you want to proceed?${N}"
            echo "  [r] Retry (Try installing again)"
            echo "  [s] Skip  (Ignore this package and continue)"
            echo "  [a] Abort (Stop the entire script)"
            
            choice=$(safe_prompt "Select option [r/s/a]:" "a")
            case "$choice" in
                r|R)
                    log_info "Retrying..."
                    apt-get update -q # Intentamos refrescar antes de reintentar
                    continue
                    ;;
                s|S)
                    log_warn "Skipping $pkg by user request. System may be incomplete."
                    return 0
                    ;;
                a|A)
                    log_error "Aborting installation via user request."
                    export SCRIPT_SELF_REPORTED_ERROR=1
                    exit $EXIT_USER_ABORTED
                    ;;
                *)
                    log_warn "Invalid option. Retrying..."
                    continue
                    ;;
            esac
        fi
    done
}

# ==============================================================================
# LOGIC
# ==============================================================================
log_step "Step 00: Preflight Checks & Base Updates"

export DEBIAN_FRONTEND=noninteractive

# 1. Soft-Fix: CD-ROM Source
# Solo comentamos la línea para que no de error si no está el USB puesto.
# No borramos nada, ni añadimos repositorios externos.
if grep -q "^deb cdrom:" /etc/apt/sources.list; then
    log_info "Commented out CD-ROM in sources.list to prevent lock-ups."
    sed -i '/^deb cdrom:/ s/^/#/' /etc/apt/sources.list
fi

# 2. Wait for Apt Lock
wait_for_apt_lock() {
    while fuser /var/lib/dpkg/lock >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do
        log_warn "Waiting for another apt process to finish..."
        sleep 2
    done
}
wait_for_apt_lock

# 3. Update Repository Cache
log_info "Updating package lists..."
set +e
apt-get update -q
if [ $? -ne 0 ]; then
    log_warn "apt-get update returned an error. You may want to check your internet or sources."
    log_warn "Proceeding anyway..."
fi
set -e

# 4. Upgrade Existing System
updates_count=$(apt-get -s upgrade | grep -P '^\d+ upgraded' | cut -d" " -f1)
if [[ "$updates_count" -gt 0 ]]; then
    log_info "Upgrading system..."
    # Usamos la misma lógica safe_install genérica o un try directo
    apt-get upgrade -y -q || log_warn "Upgrade returned errors, but proceeding."
else
    log_success "System is already up to date."
fi

# 5. Install Essential Core Utilities
CORE_PACKAGES=(
    "build-essential"
    "curl"
    "wget"
    "git"
    "unzip"
)

log_info "Verifying core dependencies..."

for pkg in "${CORE_PACKAGES[@]}"; do
    safe_install "$pkg"
done

# 6. Clean up
apt-get autoremove -y -q
apt-get clean

log_success "Step 00 complete."