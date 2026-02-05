#!/bin/bash
# audit_system.sh
# Purpose: Read-only check of the Debian Labwc environment.
# Safety: Performs ZERO writes. No sudo required for checks.

# Colors
R='\033[0;31m'   # Red (Missing/Fail)
G='\033[0;32m'   # Green (OK)
Y='\033[0;33m'   # Yellow (Warning)
N='\033[0m'      # Reset

echo -e "${Y}Starting Non-Destructive System Audit...${N}"
echo "------------------------------------------------"

# 1. CHECK BINARIES
# We check if critical programs are reachable in the PATH.
# Detect which panel was installed
PANEL_CHOICE=$(cat /tmp/labwc_panel_choice 2>/dev/null || echo "waybar")

REQUIRED_BINS=(
    "labwc" "$PANEL_CHOICE" "foot" "fuzzel" "swaybg" "swaylock" 
    "seatd" "pipewire" "wireplumber" "grim" "slurp" 
    "swappy" "wlr-randr" "pavucontrol" "nm-applet"
    "xdg-desktop-portal-wlr"
)

echo -e "\n[ Checking Core Binaries ]"
MISSING_BINS=0
for bin in "${REQUIRED_BINS[@]}"; do
    if command -v "$bin" >/dev/null 2>&1; then
        echo -e "${G}[OK]${N} Found: $bin"
    else
        echo -e "${R}[MISSING]${N} $bin"
        ((MISSING_BINS++))
    fi
done

# 2. CHECK USER GROUPS
# Essential for Wayland hardware access.
CURRENT_USER=$(whoami)
REQUIRED_GROUPS=("video" "input")

echo -e "\n[ Checking User Groups for '$CURRENT_USER' ]"
for group in "${REQUIRED_GROUPS[@]}"; do
    if groups "$CURRENT_USER" | grep -q "\b$group\b"; then
        echo -e "${G}[OK]${N} User is in '$group'"
    else
        echo -e "${R}[FAIL]${N} User NOT in '$group' (Graphics/Input may fail)"
    fi
done

# 3. CHECK PORTALS
# Required for OBS and Screen Sharing.
echo -e "\n[ Checking XDG Portals ]"
PORTAL_FILE="/usr/share/xdg-desktop-portal/portals/wlr.portal"
if [ -f "$PORTAL_FILE" ]; then
    echo -e "${G}[OK]${N} wlr.portal definition found."
else
    echo -e "${R}[FAIL]${N} wlr.portal missing (Screen sharing will break)."
fi

# 4. CHECK CONFIGURATION LINKS
# Checks if your ~/.config files are actually symlinks (as intended by step 05).
echo -e "\n[ Checking Config Links ]"
CONFIGS=("labwc" "$PANEL_CHOICE" "foot")
for cfg in "${CONFIGS[@]}"; do
    TARGET="$HOME/.config/$cfg"
    if [ -L "$TARGET" ]; then
        echo -e "${G}[OK]${N} ~/.config/$cfg is a symlink."
    elif [ -d "$TARGET" ]; then
        echo -e "${Y}[WARN]${N} ~/.config/$cfg exists but is a standard directory (Not managed by script)."
    else
        echo -e "${R}[MISSING]${N} ~/.config/$cfg does not exist."
    fi
done

# 5. CHECK DOTFILES (.bashrc)
# Checks if our specific marker exists.
echo -e "\n[ Checking .bashrc injections ]"
if grep -q "DEBIAN-LABWC-SETUP-START" "$HOME/.bashrc"; then
    echo -e "${G}[OK]${N} .bashrc contains environment variables."
else
    echo -e "${Y}[WARN]${N} .bashrc does not contain the setup block."
fi

echo "------------------------------------------------"
if [ $MISSING_BINS -eq 0 ]; then
    echo -e "${G}Audit Complete. System appears ready for Labwc.${N}"
else
    echo -e "${R}Audit Complete. Found $MISSING_BINS missing components.${N}"
fi