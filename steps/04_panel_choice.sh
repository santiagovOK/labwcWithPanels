#!/bin/bash
# Step 04: Panel Selection
# Allows user to choose between Waybar and sfwbar

set -euo pipefail

# Exit codes for specific failures
readonly EXIT_INVALID_PANEL_CHOICE=62

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# shellcheck source=lib/utils.sh
source "$PROJECT_ROOT/lib/utils.sh"
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

log_step "Step 04: Panel Selection"

echo ""
echo -e "${Y}═══════════════════════════════════════════════════${N}"
echo -e "${Y}          Choose Your Panel for Labwc              ${N}"
echo -e "${Y}═══════════════════════════════════════════════════${N}"
echo ""
echo -e "${G}[1] Waybar${N} - Highly customizable Wayland bar (recommended)"
echo "    • JSON/CSS configuration"
echo "    • Modular widgets (workspaces, clock, tray, etc.)"
echo "    • Active development, large community"
echo "    • Available in Debian repos (quick install)"
echo ""
echo -e "${G}[2] sfwbar${N} - Simple Wayland bar with taskbar support"
echo "    • GTK3-based configuration"
echo "    • Built-in taskbar with window grouping"
echo "    • Workspace switcher (pager)"
echo "    • Requires compilation from source (~3-5 min build)"
echo ""
echo -e "${Y}═══════════════════════════════════════════════════${N}"
echo ""

response=$(safe_prompt "Select panel [1/2] (default: 1):" "1")

case "$response" in
    1)
        PANEL_CHOICE="waybar"
        log_success "Selected: Waybar (highly customizable)"
        ;;
    2)
        PANEL_CHOICE="sfwbar"
        log_success "Selected: sfwbar (simple with taskbar)"
        log_warn "Note: sfwbar will be compiled from source (~3-5 minutes)"
        ;;
    *)
        log_warn "Invalid choice. Defaulting to Waybar."
        PANEL_CHOICE="waybar"
        ;;
esac

# Store choice for subsequent steps
echo "$PANEL_CHOICE" > /tmp/labwc_panel_choice
log_info "Panel choice saved: $PANEL_CHOICE"

echo ""
log_success "Panel selection completed."
