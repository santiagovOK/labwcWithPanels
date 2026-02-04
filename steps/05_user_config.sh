#!/bin/bash
# steps/05_user_config.sh
# Step 05: User Configuration & Dotfiles Linking
# Update: Interactive prompts for Dotfiles and .bashrc separately.
# TODO: Add NONINTERACTIVE mode support to skip user prompts (e.g., deploy configs, .bashrc)

# ==============================================================================
# BOOTSTRAP
# ==============================================================================
LIB_PATH="lib/utils.sh"
if [[ ! -f "$LIB_PATH" && -f "../$LIB_PATH" ]]; then cd ..; fi
if [[ ! -f "$LIB_PATH" ]]; then echo "CRITICAL: Lib not found"; exit 1; fi
# shellcheck source=../lib/utils.sh
source "$LIB_PATH"
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

# ==============================================================================
# SETUP
# ==============================================================================
log_step "Step 05: Applying User Configurations"

# Detect actual user
CURRENT_USER=$(logname 2>/dev/null || echo "$SUDO_USER")
if [[ -z "$CURRENT_USER" || "$CURRENT_USER" == "root" ]]; then
    log_error "Cannot determine target non-root user. Do not run as pure root."
    exit 1
fi

USER_HOME=$(eval echo "~$CURRENT_USER")
PROJECT_CONFIG_DIR="$(pwd)/config"

log_info "Target User: $CURRENT_USER"
log_info "User Home: $USER_HOME"

# Helper function to link configs safely
install_config() {
    local src_name="$1"
    local dest_path="$2"
    local full_src_path="$PROJECT_CONFIG_DIR/$src_name"
    local full_dest_path="$USER_HOME/.config/$dest_path"

    # 1. Check if Source Exists
    if [[ ! -e "$full_src_path" ]]; then
        log_warn "Source '$src_name' not found in project ($full_src_path). Skipping."
        return 0
    fi

    log_info "Linking $src_name -> .config/$dest_path"

    # 2. Ensure parent dir exists
    mkdir -p "$(dirname "$full_dest_path")"

    # 3. Backup existing config
    if [[ -e "$full_dest_path" && ! -L "$full_dest_path" ]]; then
        log_info "Backing up existing $dest_path..."
        mv "$full_dest_path" "${full_dest_path}.bak_$(date +%s)"
    fi

    # 4. Create Link (with permissions fix)
    # We turn off strict mode briefly for the link command
    set +e
    ln -sf "$full_src_path" "$full_dest_path"
    local ret=$?
    set -e
    
    if [ $ret -eq 0 ]; then
        chown -h "$CURRENT_USER":"$CURRENT_USER" "$full_dest_path"
        
        # Special handling for labwc autostart: replace panel placeholder
        if [[ "$dest_path" == "labwc/autostart" ]]; then
            PANEL_CHOICE=$(cat /tmp/labwc_panel_choice 2>/dev/null || echo "waybar")
            log_info "Configuring autostart for panel: $PANEL_CHOICE"
            
            # Replace placeholder with actual panel command
            sed -i "s|##PANEL_AUTOSTART##|${PANEL_CHOICE} \&|g" "$full_dest_path"
        fi
        
        log_success "Linked: $dest_path"
    else
        log_error "Failed to link $dest_path (Permission denied?)"
    fi
}

# ==============================================================================
# PHASE A: DOTFILES LINKING (Interactive)
# ==============================================================================
log_info "Phase A: Deploying Dotfiles..."

# Determine selected panel
PANEL_CHOICE=$(cat /tmp/labwc_panel_choice 2>/dev/null || echo "waybar")
log_info "Detected panel choice: $PANEL_CHOICE"

echo -e "${Y}Do you want to overwrite ~/.config with project dotfiles (labwc, $PANEL_CHOICE, foot)?${N}"
response=$(safe_prompt "Deploy Configs? [y/N]" "N")

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    
    # Check if we even have a config folder to deploy
    if [[ ! -d "$PROJECT_CONFIG_DIR" ]]; then
        log_warn "No 'config' directory found in project root."
        log_info "Creating empty structure for future use..."
        mkdir -p config/{labwc,waybar,sfwbar,foot}
        # We don't exit, just warn
    fi

    # Attempt to link modules
    install_config "labwc" "labwc"
    install_config "$PANEL_CHOICE" "$PANEL_CHOICE"
    install_config "foot" "foot"

    # Fix permissions recursively on .config
    chown -R "$CURRENT_USER":"$CURRENT_USER" "$USER_HOME/.config"
    log_success "Dotfiles deployment finished."

else
    log_info "Skipping Dotfiles deployment by user request."
fi

# ==============================================================================
# PHASE B: BASHRC INJECTION (Interactive)
# ==============================================================================
log_info "Phase B: Shell Configuration"

echo -e "${Y}Do you want to inject environment variables & aliases into .bashrc?${N}"
response=$(safe_prompt "Update .bashrc? [y/N]" "N")

if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    
    BASHRC="$USER_HOME/.bashrc"
    MARKER="# === DEBIAN-LABWC-SETUP-START ==="
    
    if grep -Fq "$MARKER" "$BASHRC"; then
        log_success ".bashrc already contains the configuration. Skipping."
    else
        log_info "Backing up .bashrc..."
        cp "$BASHRC" "${BASHRC}.bak"

        log_info "Injecting configuration..."
        
        # Safe read to prevent EOF crash
        read -r -d '' BASH_BLOCK << EOM || true
$MARKER
# Added by main.sh on $(date +%Y-%m-%d)

# 1. Environment Variables
export MOZ_ENABLE_WAYLAND=1
export COLORTERM=truecolor

# Fix for terminals not reporting truecolor correctly
case "\$TERM" in
    *-truecolor) ;;
    *-256color)  ;;
    *)           export TERM=xterm-256color ;;
esac

# 2. Aliases
alias code='code --ozone-platform-hint=wayland --enable-features=WaylandWindowDecorations'
alias shot='grim -g "\$(slurp)" - | swappy -f -'

# Display Management (Examples)
alias onedisplay='wlr-randr --output DP-1 --on --mode 1920x1080@144Hz --output HDMI-A-1 --off'

# === DEBIAN-LABWC-SETUP-END ===
EOM
        
        echo "$BASH_BLOCK" >> "$BASHRC"
        log_success "Configuration appended to .bashrc"
    fi

else
    log_info "Skipping .bashrc update by user request."
fi

# ==============================================================================
# COMPLETION
# ==============================================================================
log_step "Installation Finished"
log_success "Step 05 complete."
log_info "Please REBOOT your system to apply all changes."