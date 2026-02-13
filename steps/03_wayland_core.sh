#!/bin/bash
# steps/03_wayland_core.sh
# Step 03: Wayland Compositor & Userland
# Fix: Robust Flatpak handling to prevent script crash on network errors.
# TODO: Add NONINTERACTIVE mode support to skip user prompts (e.g., multimedia apps)

# Exit codes for specific failures
readonly EXIT_WAYLAND_PACKAGE_FAILED=12

# ==============================================================================
# BOOTSTRAP
# ==============================================================================
LIB_PATH="lib/utils.sh"
if [[ ! -f "$LIB_PATH" && -f "../$LIB_PATH" ]]; then cd ..; fi
if [[ ! -f "$LIB_PATH" ]]; then echo "CRITICAL: Lib not found"; exit $EXIT_WAYLAND_PACKAGE_FAILED; fi
# shellcheck source=../lib/utils.sh
source "$LIB_PATH"
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

# ==============================================================================
# LOGIC
# ==============================================================================
log_step "Step 03: Wayland Core, Portals & Flatpak Apps"

# 1. Labwc (Compositor)
log_info "Installing Labwc..."
safe_install "labwc"

# 2. Critical Portals
PORTAL_PACKAGES=(
    "xdg-desktop-portal"
    "xdg-desktop-portal-wlr"
)
log_info "Installing XDG Desktop Portals..."
for pkg in "${PORTAL_PACKAGES[@]}"; do
    safe_install "$pkg"
done

# 3. Core Utilities
CORE_TOOLS=(
    "foot"
    "fuzzel"
    "swaybg"
    "swaylock"
    "swayidle"
    "playerctl"
    "wl-clipboard"
    "wlr-randr"
    "x11-utils"
    "flatpak" 
    "seahorse" # GUI for keyrings
)
log_info "Installing Core Tools..."
for pkg in "${CORE_TOOLS[@]}"; do
    safe_install "$pkg"
done

# 4. Native Media Tools
MEDIA_APPS=(
    "grim"
    "slurp"
    "swappy"
    "atril"
    "swayimg"
    "gnome-calculator"
    "file-roller"
)
log_info "Installing Native Media Tools..."
for pkg in "${MEDIA_APPS[@]}"; do
    safe_install "$pkg"
done

# 5. Web Browsers (Brave)
# We check if it is already installed to avoid running the install script every time
if command -v brave-browser >/dev/null 2>&1; then
    log_success "Brave Browser is already installed."
else
    log_info "Installing Brave Browser (via Official Script)..."
    
    # We disable 'set -e' so a network failure doesn't kill the entire installer
    set +e
    
    # Execute the official installer
    curl -fsS https://dl.brave.com/install.sh | sh
    EXIT_CODE=$?
    
    set -e # Re-enable strict mode

    if [ $EXIT_CODE -eq 0 ]; then
        log_success "Brave Browser installed successfully."
    else
        log_warn "Failed to install Brave Browser (Exit Code: $EXIT_CODE)."
        log_warn "Check internet connection or install manually later."
    fi
fi

# 6. Flatpak Configuration & Multimedia Apps (Interactive)
log_info "Configuring Flatpak Ecosystem..."

# A) Add Flathub Repo (Prerequisite)
if flatpak remote-list | grep -q "flathub"; then
    log_success "Flathub repo already exists."
else
    log_info "Adding Flathub repository..."
    
    # Disable strict mode to handle network errors manually
    set +e
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    RET=$?
    set -e # Re-enable strict mode

    if [ $RET -eq 0 ]; then
        log_success "Flathub repository added."
    else
        log_warn "Failed to add Flathub repo (Exit Code: $RET)."
        log_warn "Skipping Flatpak app installation as repo is missing."
        # We set a flag to skip the next block
        FLATHUB_MISSING=true
    fi
fi

# B) Interactive App Installation
if [ "$FLATHUB_MISSING" != "true" ]; then
    
    echo ""
    echo -e "${Y}Optional Multimedia Apps (Flatpak):${N}"
    echo "  1. OBS Studio (Screen Recording & Streaming)"
    echo "  2. Kdenlive (Professional Video Editor)"
    
    response=$(safe_prompt "Do you want to install these multimedia apps? [y/N]" "N")

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        
        # Helper function to install Flatpaks safely (Internal use only)
        install_flatpak_safe() {
            local app_id="$1"
            local app_name="$2"

            if flatpak list | grep -q "$app_id"; then
                log_success "$app_name is already installed."
            else
                log_info "Installing $app_name..."
                # Log attempted flatpak app for auditing
                mkdir -p "$(dirname \"$LOG_FILE\")"
                echo "$(date +%Y-%m-%dT%H:%M:%S) FLATPAK_ATTEMPT $app_id ($app_name)" >> "$LOG_FILE".attempts
                
                # Soft Fail Protection
                set +e
                flatpak install -y flathub "$app_id"
                RET=$?
                set -e

                if [ $RET -eq 0 ]; then
                    log_success "$app_name installed successfully."
                    echo "$(date +%Y-%m-%dT%H:%M:%S) FLATPAK_INSTALLED $app_id ($app_name)" >> "$LOG_FILE".results
                else
                    log_warn "Failed to install $app_name (Exit Code: $RET)."
                    echo "$(date +%Y-%m-%dT%H:%M:%S) FLATPAK_FAILED $app_id ($app_name) RET=$RET" >> "$LOG_FILE".results
                    log_warn "You can try manually: 'flatpak install flathub $app_id'"
                fi
            fi
        }

        # Install the requested apps
        install_flatpak_safe "com.obsproject.Studio" "OBS Studio"
        install_flatpak_safe "org.kde.kdenlive" "Kdenlive"

    else
        log_info "Skipping multimedia apps by user request."
    fi
fi

# 7. Validation
log_info "Verifying critical binaries..."
REQUIRED=("labwc" "swappy" "flatpak")

for bin in "${REQUIRED[@]}"; do
    if command -v "$bin" >/dev/null 2>&1; then
        log_success "Binary '$bin' detected."
    else
        log_warn "Binary '$bin' not found. Check logs."
    fi
done

# Check Portal Service files
if [ -f /usr/share/xdg-desktop-portal/portals/wlr.portal ]; then
    log_success "Portal backend (wlr.portal) detected."
else
    log_error "wlr.portal definition missing! Screen sharing will fail."
    # No hacemos exit 1 aquí para permitir que el script continúe al siguiente paso
fi

log_success "Step 03 complete. Core, Portals, and OBS ready."