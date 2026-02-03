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
LIB_PATH="lib/utils.sh"

if [[ ! -f "$LIB_PATH" ]]; then
    echo "CRITICAL ERROR: Cannot find library at $LIB_PATH"
    exit 1
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
    exit 1
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
    exit 1
fi

log_info "Found ${#SCRIPT_FILES[@]} steps to execute."

for script in "${SCRIPT_FILES[@]}"; do
    script_name=$(basename "$script")
    
    log_step "Executing Module: $script_name"
    
    # Ensure the step is executable
    chmod +x "$script"
    
    # Execute the script in the current shell environment
    # Using 'source' allows steps to share variables if needed, 
    # but running as executable (./) is safer for isolation. 
    # We choose execution for isolation.
    # Redirect stdin from /dev/tty if available to preserve interactivity
    if [ -t 0 ]; then
        ./"$script" < /dev/tty
    else
        ./"$script"
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