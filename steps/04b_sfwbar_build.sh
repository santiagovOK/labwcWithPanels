#!/bin/bash
# steps/04b_sfwbar_build.sh
# sfwbar compilation and installation from source

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"

# Exit codes for specific failures
readonly EXIT_DEPENDENCY_MISSING=10
readonly EXIT_USER_DETECTION_FAILED=11
readonly EXIT_GIT_CLONE_FAILED=12
readonly EXIT_MESON_CONFIG_FAILED=13
readonly EXIT_NINJA_BUILD_FAILED=14
readonly EXIT_NINJA_INSTALL_FAILED=15
readonly EXIT_BINARY_VERIFICATION_FAILED=16

# shellcheck source=lib/utils.sh
source "$PROJECT_ROOT/lib/utils.sh"
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

# Function to display build diagnostics
show_build_diagnostics() {
    local build_dir="$1"
    local meson_log="$build_dir/build/meson-logs/meson-log.txt"
    
    log_error "Build failed. Checking diagnostics..."
    
    if [[ -f "$meson_log" ]]; then
        log_info "Meson build log (last 30 lines):"
        tail -n 30 "$meson_log" | while IFS= read -r line; do
            echo "  $line" >&2
        done
    else
        log_warn "Meson log not found at: $meson_log"
    fi
    
    # Check for common missing dependencies
    if [[ -f "$meson_log" ]] && grep -q "pkg-config" "$meson_log"; then
        log_info "Hint: Missing pkg-config dependencies detected. Check above for specific packages."
    fi
}

# Check if sfwbar was selected
PANEL_CHOICE=$(cat /tmp/labwc_panel_choice 2>/dev/null || echo "waybar")
if [[ "$PANEL_CHOICE" != "sfwbar" ]]; then
    log_info "Skipping sfwbar installation (selected: $PANEL_CHOICE)"
    exit 0
fi

log_step "Step 04b: sfwbar Build & Installation"

# Build dependencies
BUILD_DEPS=(
    "git"
    "meson"
    "ninja-build"
    "pkg-config"
    "libwayland-dev"
    "libgtk-3-dev"
    "libgtk-layer-shell-dev"
    "libjson-c-dev"
    "libpulse-dev"
    "libmpdclient-dev"
    "libcairo2-dev"
    "libgdk-pixbuf-2.0-dev"
    "libxkbcommon-dev"
)

# Shared UI dependencies (also used by waybar)
UI_DEPS=(
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

log_info "Verifying dependency availability..."
# Check critical dependency package name
if ! apt-cache show libgtk-layer-shell-dev >/dev/null 2>&1; then
    log_warn "libgtk-layer-shell-dev not found, checking alternatives..."
    if apt-cache show gtk-layer-shell >/dev/null 2>&1; then
        log_info "Using gtk-layer-shell instead"
        BUILD_DEPS[6]="gtk-layer-shell"
    else
        log_error "gtk-layer-shell library not available in repositories"
        log_error "This is required for Wayland layer shell support"
        export SCRIPT_SELF_REPORTED_ERROR=1
        exit $EXIT_DEPENDENCY_MISSING
    fi
fi

log_info "Installing build dependencies for sfwbar..."
for pkg in "${BUILD_DEPS[@]}"; do
    safe_install "$pkg"
done

log_info "Installing shared UI components..."
for pkg in "${UI_DEPS[@]}"; do
    safe_install "$pkg"
done

# Determine user for build directory
CURRENT_USER=$(logname 2>/dev/null || echo "$SUDO_USER")
if [[ -z "$CURRENT_USER" ]]; then
    log_error "Cannot determine non-root user for build"
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_USER_DETECTION_FAILED
fi

USER_HOME=$(eval echo "~$CURRENT_USER")
BUILD_DIR="$USER_HOME/.cache/sfwbar-build"

log_info "Cloning sfwbar repository..."
if [[ -d "$BUILD_DIR" ]]; then
    log_warn "Build directory exists, removing: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi

# Clone with retry logic (max 3 attempts)
SFWBAR_REPO="https://github.com/LBCrion/sfwbar"
CLONE_SUCCESS=false
for attempt in {1..3}; do
    log_info "Cloning sfwbar (attempt $attempt/3)..."
    log_info "Executing: git clone --depth 1 $SFWBAR_REPO"
    
    # Disable ERR trap and errexit to allow retry logic
    trap - ERR
    set +e
    sudo -u "$CURRENT_USER" git clone --depth 1 "$SFWBAR_REPO" "$BUILD_DIR"
    clone_exit_code=$?
    set -e
    trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM
    
    if [[ $clone_exit_code -eq 0 ]]; then
        CLONE_SUCCESS=true
        break
    else
        log_warn "Clone attempt $attempt failed"
        sleep 2
    fi
done

if [[ "$CLONE_SUCCESS" != "true" ]]; then
    log_error "Failed to clone sfwbar repository after 3 attempts"
    log_error "Check internet connection and GitHub availability"
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_GIT_CLONE_FAILED
fi

# Display cloned version info
cd "$BUILD_DIR"
GIT_COMMIT=$(sudo -u "$CURRENT_USER" git rev-parse --short HEAD)
log_info "Cloned sfwbar at commit: $GIT_COMMIT"

log_info "Configuring build with meson..."
cd "$BUILD_DIR"

# Run meson as user with output capture
log_info "Running meson setup (output logged to $LOG_FILE)..."
log_info "Executing: meson setup build --prefix=/usr/local -Dnetwork=enabled -Dbluez=disabled"

# Disable ERR trap and errexit to capture exit code before diagnostics
trap - ERR
set +e
sudo -u "$CURRENT_USER" meson setup build \
    --prefix=/usr/local \
    -Dnetwork=enabled \
    -Dbluez=disabled 2>&1 | tee -a "$LOG_FILE"
meson_exit_code=$?
set -e
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

if [[ $meson_exit_code -ne 0 ]]; then
    show_build_diagnostics "$BUILD_DIR"
    log_error "Meson configuration failed"
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_MESON_CONFIG_FAILED
fi

log_info "Compiling sfwbar (this may take 3-5 minutes)..."
log_info "Compilation output logged to $LOG_FILE"
log_info "Executing: ninja -C build"

# Disable ERR trap and errexit to capture exit code before diagnostics
trap - ERR
set +e
sudo -u "$CURRENT_USER" ninja -C build 2>&1 | tee -a "$LOG_FILE"
ninja_exit_code=$?
set -e
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

if [[ $ninja_exit_code -ne 0 ]]; then
    show_build_diagnostics "$BUILD_DIR"
    log_error "Compilation failed"
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_NINJA_BUILD_FAILED
fi

log_info "Installing sfwbar to /usr/local..."
log_info "Executing: ninja -C build install"

# Disable ERR trap and errexit to capture exit code before error handling
trap - ERR
set +e
ninja -C build install 2>&1 | tee -a "$LOG_FILE"
install_exit_code=$?
set -e
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

if [[ $install_exit_code -ne 0 ]]; then
    log_error "Installation failed"
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_NINJA_INSTALL_FAILED
fi

# Update linker cache for /usr/local/lib first
if ! ldconfig 2>&1 | tee -a "$LOG_FILE"; then
    log_warn "ldconfig reported warnings (non-critical)"
fi

# Verify installation with explicit PATH
export PATH="/usr/local/bin:$PATH"
log_info "Verifying sfwbar installation..."

if command -v sfwbar >/dev/null 2>&1; then
    SFWBAR_VERSION=$(sfwbar -v 2>&1 | head -n1 || echo "unknown")
    SFWBAR_PATH=$(command -v sfwbar)
    log_success "sfwbar installed successfully: $SFWBAR_VERSION"
    log_info "Binary location: $SFWBAR_PATH"
else
    log_error "sfwbar installation failed - binary not found in PATH"
    log_error "Checked PATH: $PATH"
    log_error "Expected location: /usr/local/bin/sfwbar"
    if [[ -f "/usr/local/bin/sfwbar" ]]; then
        log_error "Binary exists but is not executable or PATH issue detected"
    fi
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_BINARY_VERIFICATION_FAILED
fi

# Create config directory
log_info "Creating sfwbar config directory..."
mkdir -p "$USER_HOME/.config/sfwbar"
chown -R "$CURRENT_USER":"$CURRENT_USER" "$USER_HOME/.config/sfwbar"

log_success "sfwbar build and installation completed."
