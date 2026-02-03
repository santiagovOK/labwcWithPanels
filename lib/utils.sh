#!/bin/bash
# lib/utils.sh
# Core library: Logging, Error Handling, Validation & Interactive Recovery

# ==============================================================================
# 1. CONSTANTS & COLORS
# ==============================================================================
LOG_FILE="logs/install_$(date +%Y-%m-%d).log"
readonly LOG_FILE
readonly R='\033[0;31m'   # Red (Error)
readonly G='\033[0;32m'   # Green (Success)
readonly Y='\033[0;33m'   # Yellow (Warning)
readonly B='\033[0;34m'   # Blue (Info)
readonly C='\033[0;36m'   # Cyan (Step Title)
readonly N='\033[0m'      # Reset

mkdir -p logs

# ==============================================================================
# 2. LOGGING FUNCTIONS
# ==============================================================================
_log() {
    local type="$1"
    local color="$2"
    local message="$3"
    local timestamp
    timestamp=$(date +"%H:%M:%S")
    echo -e "${color}[${timestamp}] [${type}] ${message}${N}" >&2
    echo "[${timestamp}] [${type}] ${message}" >> "$LOG_FILE"
}

log_info() { _log "INFO" "$B" "$1"; }
log_success() { _log "OK" "$G" "$1"; }
log_warn() { _log "WARN" "$Y" "$1"; }
log_error() { _log "ERROR" "$R" "$1"; }
log_step() {
    echo ""
    _log "STEP" "$C" "------------------------------------------------"
    _log "STEP" "$C" "$1"
    _log "STEP" "$C" "------------------------------------------------"
}

# ==============================================================================
# 3. ERROR HANDLING (Global Trap)
# ==============================================================================
error_handler() {
    local line_no=$1
    local exit_code=$2
    local last_command=$3
    
    # Evitamos que el trap se dispare si el código de salida es 0 (éxito)
    # o si ya estamos gestionando el error manualmente en safe_install
    if [ $exit_code -eq 0 ]; then return; fi

    log_error "Critical failure detected!"
    log_error "Failed command: $last_command"
    log_error "Line: $line_no | Exit Code: $exit_code"
    log_error "See $LOG_FILE for full details."
    exit "$exit_code"
}

# ==============================================================================
# 4. INTERACTIVE RECOVERY (Global Safe Install)
# ==============================================================================
safe_install() {
    local pkg="$1"
    
    while true; do
        # Verificar si ya está instalado (idempotencia)
        if dpkg -l "$pkg" &> /dev/null; then
            log_success "$pkg is already installed."
            return 0
        fi

        log_info "Attempting to install: $pkg..."
        # Log attempted package for auditing
        mkdir -p "$(dirname "$LOG_FILE")"
        echo "$(date +%Y-%m-%dT%H:%M:%S) ATTEMPT $pkg" >> "$LOG_FILE".attempts
        # Desactivar modo estricto temporalmente para capturar el error
        set +e
        apt-get install -y -q "$pkg"
        local exit_code=$?
        set -e

        if [ $exit_code -eq 0 ]; then
            log_success "$pkg installed successfully."
            echo "$(date +%Y-%m-%dT%H:%M:%S) INSTALLED $pkg" >> "$LOG_FILE".results
            return 0
        else
            echo ""
            log_warn "Failed to install '$pkg' (Exit Code: $exit_code)."
            log_warn "Repo issue or missing package."
            
            # Menú Interactivo
            echo -e "${Y}Action required:${N}"
            echo "  [r] Retry (Try installing again)"
            echo "  [s] Skip  (Ignore and continue - SYSTEM MAY BE UNSTABLE)"
            echo "  [a] Abort (Stop script)"
            
            read -p "Select [r/s/a]: " choice
            case "$choice" in
                r|R)
                    log_info "Retrying..."
                    set +e
                    apt-get update -q
                    set -e
                    continue
                    ;;
                s|S)
                    log_warn "SKIPPING $pkg. Note this for troubleshooting."
                    echo "$(date +%Y-%m-%dT%H:%M:%S) SKIPPED $pkg" >> "$LOG_FILE".results
                    return 0
                    ;;
                a|A)
                    log_error "Installation aborted by user."
                    exit 1
                    ;;
                *)
                    continue
                    ;;
            esac
        fi
    done
}

# ==============================================================================
# 5. VALIDATION FUNCTIONS
# ==============================================================================
assert_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Must run as root (sudo)."
        exit 1
    fi
    log_success "Root privileges confirmed."
}

assert_debian_trixie() {
    log_info "Verifying OS version..."
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" == "debian" ]]; then
            log_success "Detected Debian System."
            if [[ "$VERSION_CODENAME" != "trixie" ]]; then
                log_warn "Detected $VERSION_CODENAME (Expected: trixie)."
            else
                log_success "Detected Debian Trixie."
            fi
        else
            log_error "Not Debian. Detected: $ID"
            exit 1
        fi
    else
        log_error "Cannot determine OS."
        exit 1
    fi
}

check_internet() {
    log_info "Checking internet connectivity..."
    if ping -c 1 8.8.8.8 &> /dev/null; then
        log_success "Internet connection active."
    else
        log_error "No internet connection."
        exit 1
    fi
}

# Only returns 0 if the package status is exactly "installed"
is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# Safe interactive prompt that handles non-interactive mode (e.g., curl | bash)
# Usage: safe_prompt "Question?" "default_value"
# Returns: user input or default if stdin unavailable
safe_prompt() {
    local prompt_text="$1"
    local default_value="${2:-N}"
    local response=""
    
    # Check if /dev/tty is available (interactive terminal)
    if [ -e /dev/tty ]; then
        # Read directly from terminal to avoid subshell stdin issues
        read -r -p "$prompt_text " response < /dev/tty
        echo "$response"
    else
        # Non-interactive mode: use default and log it
        log_warn "Non-interactive mode detected. Using default: $default_value"
        echo "$default_value"
    fi
}