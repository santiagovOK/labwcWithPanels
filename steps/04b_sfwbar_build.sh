#!/bin/bash
# steps/04b_sfwbar_build.sh
# sfwbar compilation and installation from source

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck source=lib/utils.sh
source "$PROJECT_ROOT/lib/utils.sh"

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
    exit 1
fi

USER_HOME=$(eval echo "~$CURRENT_USER")
BUILD_DIR="$USER_HOME/.cache/sfwbar-build"

log_info "Cloning sfwbar repository..."
if [[ -d "$BUILD_DIR" ]]; then
    log_warn "Build directory exists, removing: $BUILD_DIR"
    rm -rf "$BUILD_DIR"
fi

# Clone as user, not root
sudo -u "$CURRENT_USER" git clone https://github.com/LBCrion/sfwbar "$BUILD_DIR"

log_info "Configuring build with meson..."
cd "$BUILD_DIR"

# Run meson as user
sudo -u "$CURRENT_USER" meson setup build \
    --prefix=/usr/local \
    -Dnetwork=enabled \
    -Dbluez=disabled

log_info "Compiling sfwbar (this may take 3-5 minutes)..."
sudo -u "$CURRENT_USER" ninja -C build

log_info "Installing sfwbar to /usr/local..."
ninja -C build install

# Verify installation
if command -v sfwbar >/dev/null 2>&1; then
    SFWBAR_VERSION=$(sfwbar -v 2>&1 | head -n1 || echo "unknown")
    log_success "sfwbar installed successfully: $SFWBAR_VERSION"
else
    log_error "sfwbar installation failed - binary not found in PATH"
    exit 1
fi

# Update linker cache for /usr/local/lib
ldconfig

# Create config directory
log_info "Creating sfwbar config directory..."
mkdir -p "$USER_HOME/.config/sfwbar"
chown -R "$CURRENT_USER":"$CURRENT_USER" "$USER_HOME/.config/sfwbar"

log_success "sfwbar build and installation completed."
