#!/bin/bash
# main.sh
# Main Orchestrator for Debian Labwc Setup
# Author: Santiago Varela
# License: MIT

# ==============================================================================
# 1. STRICT MODE & ENVIRONMENT
# ==============================================================================
# -e: Exit immediately if a command exits with a non-zero status.
# -u: Treat unset variables as an error.
# -o pipefail: Return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# Set working directory to the script's location to allow execution from anywhere
cd "$(dirname "$0")"

# ==============================================================================
# 2. LOAD LIBRARY
# ==============================================================================
# Exit codes for main orchestrator
readonly EXIT_MISSING_LIBRARY=70
readonly EXIT_MISSING_STEPS_DIR=71
readonly EXIT_NO_SCRIPTS_FOUND=72

LIB_PATH="lib/utils.sh"

if [[ ! -f "$LIB_PATH" ]]; then
    echo "CRITICAL ERROR: Cannot find library at $LIB_PATH"
    exit $EXIT_MISSING_LIBRARY
fi

# shellcheck source=lib/utils.sh
source "$LIB_PATH"

# ==============================================================================
# 3. TRAP HANDLER INITIALIZATION
# ==============================================================================
# Trap errors (ERR), interruptions (INT), and termination signals (TERM)
# Passes: Line Number, Exit Code, and the Command that failed
trap 'error_handler ${LINENO} $? "$BASH_COMMAND"' ERR INT TERM

# ==============================================================================
# 3a. STEP SCRIPT EXECUTION FUNCTION
# ==============================================================================
# Safely execute a step script with proper exit code capture
# Uses set +e pattern to avoid triggering trap during exit code assignment
run_step_script() {
    local script="$1"
    
    # Execute with stdin redirection if available
    # Note: Caller is responsible for managing set -e state
    if [ -t 0 ]; then
        ./"$script" < /dev/tty
    else
        ./"$script"
    fi
}

# ==============================================================================
# 4. PRE-EXECUTION CHECKS (Phase I)
# ==============================================================================
log_step "Phase I: Initialization & Validation"

assert_root
assert_debian_trixie
check_internet

# ==============================================================================
# 5. MAIN EXECUTION LOOP (Phase II)
# ==============================================================================
STEPS_DIR="steps"

# Verify steps directory exists
if [[ ! -d "$STEPS_DIR" ]]; then
    log_error "Steps directory '$STEPS_DIR' not found!"
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_MISSING_STEPS_DIR
fi

# Get list of scripts sorted naturally (00, 01, ... 10)
# We use 'find' to safely handle filenames, but a simple glob works for strict naming.
# Storing in array to handle potential whitespace safely (though filenames should be strict).
failglob_state=$(shopt -p failglob || true)
shopt -s failglob nullglob

SCRIPT_FILES=("$STEPS_DIR"/*.sh)

# Restore shell option
eval "$failglob_state"

if [ ${#SCRIPT_FILES[@]} -eq 0 ]; then
    log_error "No .sh scripts found in $STEPS_DIR/"
    export SCRIPT_SELF_REPORTED_ERROR=1
    exit $EXIT_NO_SCRIPTS_FOUND
fi

log_info "Found ${#SCRIPT_FILES[@]} steps to execute."

for script in "${SCRIPT_FILES[@]}"; do
    script_name=$(basename "$script")
    
    log_step "Executing Module: $script_name"
    
    # Ensure the step is executable
    chmod +x "$script"
    
    # Temporarily disable ERR trap and errexit
    trap - ERR
    
    # Execute the script using safe function wrapper
    # This function handles exit code capture without triggering the trap
    set +e  # Disable trap BEFORE executing
    run_step_script "$script"
    exit_code=$?
    
    # Re-enable errexit after capturing exit code from function
    # (function disables it globally with set +e)
    set -e
    
    if [ $exit_code -ne 0 ]; then
        log_error "Script $script_name exited with code: $exit_code"
        
        # Provide context for specific exit codes
        case $exit_code in
            # Dependencies (10-19)
            10) log_error "Reason: Missing dependency or base package failed" ;;
            11) log_error "Reason: Video package or user detection failed" ;;
            12) log_error "Reason: Wayland package or git clone failed" ;;
            13) log_error "Reason: Meson configuration or Waybar package failed" ;;
            14) log_error "Reason: Ninja build/compilation failed" ;;
            15) log_error "Reason: Ninja installation failed" ;;
            16) log_error "Reason: Binary verification failed" ;;
            
            # Configuration (20-29)
            
            # Build/Compile (30-39)
            
            # Installation (40-49)
            41) log_error "Reason: Brave browser installation failed" ;;
            
            # Verification (50-59)
            
            # User Interaction (60-69)
            60) log_error "Reason: Script must be run as root" ;;
            61) log_error "Reason: Wrong distribution (not Debian Trixie)" ;;
            62) log_error "Reason: Invalid panel choice or user aborted" ;;
            
            # File System (70-79)
            71) log_error "Reason: Failed to create config directory" ;;
            72) log_error "Reason: Failed to create config symlink" ;;
            
            # Network (80-89)
            80) log_error "Reason: No internet connectivity" ;;
            
            *) log_error "Reason: General error" ;;
        esac
        
        export SCRIPT_SELF_REPORTED_ERROR=1
        exit "$exit_code"
    fi
    
    log_success "Module $script_name completed successfully."
done

# ==============================================================================
# 6. COMPLETION
# ==============================================================================
log_step "Installation Complete"
log_success "The system has been successfully set up."
log_info "You may need to reboot for all changes to take effect."
log_info "Log saved to: $LOG_FILE"

exit 0