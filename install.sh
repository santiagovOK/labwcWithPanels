#!/bin/bash
# install.sh
# One-liner installer for LabWC Waybar Setup
# Usage: curl -sL <url> | bash

set -e

REPO_URL="https://github.com/santiagovOK/labwc_waybar_setup.git"
INSTALL_DIR="$HOME/labwc_installer"

# Colors
R='\033[0;31m'
# shellcheck disable=SC2034
G='\033[0;32m'
B='\033[0;34m'
N='\033[0m'

echo -e "${B}=== LabWC Installer ===${N}"

# 1. Enforce Non-Root Execution
if [ "$EUID" -eq 0 ]; then
    echo -e "${R}Error: Please run this script as a normal user (not root).${N}"
    echo "The script will ask for sudo privileges when necessary."
    exit 1
fi

# 2. Check/Install Git
if ! command -v git &> /dev/null; then
    echo -e "${B}Git not found. Installing...${N}"
    sudo apt-get update && sudo apt-get install -y git
fi

# 3. Clone or Update Repository
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${B}Updating existing repository at $INSTALL_DIR...${N}"
    cd "$INSTALL_DIR"
    git pull
else
    echo -e "${B}Cloning repository to $INSTALL_DIR...${N}"
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# 4. Handover to Main Script
echo -e "${B}Launching setup...${N}"
chmod +x main.sh

# Export environment variables for main.sh and preserve stdin for interactive prompts
export BRANCH

# Redirect stdin to TTY to preserve interactive prompts when running with sudo
if [ -t 0 ]; then
    # Interactive mode: preserve stdin by redirecting from /dev/tty
    sudo -E bash -c './main.sh < /dev/tty'
else
    # Non-interactive mode (e.g., curl | bash): run without TTY redirect
    sudo -E ./main.sh
fi
