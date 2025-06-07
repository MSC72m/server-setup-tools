#!/bin/bash
#
# =================================================================
#  Bootstrap Script for Server Setup
# =================================================================
#  This script should be run via curl with sudo:
#  sudo bash <(curl -sL https://raw.githubusercontent.com/MSC72m/vpn-setup-tools/main/bootstrap.sh)
#
#  It performs the following actions:
#  1. Checks for root access.
#  2. Checks for git and prompts to install if missing.
#  3. Clones or updates the setup repository.
#  4. Executes the main setup script.
# =================================================================

set -e

# --- Configuration ---
# This is the repository containing all the setup scripts.
REPO_URL="https://github.com/MSC72m/vpn-setup-tools.git"
INSTALL_DIR="/opt/vpn-setup-script"

# --- Helper Functions ---
print_header() {
    echo ""
    echo "=============================================="
    echo "  $1"
    echo "=============================================="
    echo ""
}

# --- Main Logic ---
print_header "Starting Server Setup Bootstrap"

# 1. Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run with root privileges."
    echo "Please run it again using 'sudo':"
    echo "   sudo bash <(curl -sL https://raw.githubusercontent.com/MSC72m/vpn-setup-tools/main/bootstrap.sh)"
    exit 1
fi

# 2. Check for Git
if ! command -v git &> /dev/null; then
    print_header "Installing Git"
    echo "Git is required to download the setup files, but it's not installed."
    read -p "Do you want to install Git now? (y/n): " install_git
    if [[ "$install_git" =~ ^[Yy]$ ]]; then
        echo "Updating package lists..."
        apt-get update -y
        echo "Installing git..."
        apt-get install -y git
        echo "✅ Git installed successfully."
    else
        echo "❌ Git is required to continue. Aborting setup."
        exit 1
    fi
fi

# 3. Clone or update the repository
if [ -d "$INSTALL_DIR" ]; then
    print_header "Updating Existing Setup Files"
    echo "An existing installation was found in $INSTALL_DIR."
    cd "$INSTALL_DIR"
    echo "Pulling latest changes from the repository..."
    # Stash local changes to prevent pull conflicts
    git stash >/dev/null
    git pull
else
    print_header "Downloading Setup Files"
    echo "Cloning repository from $REPO_URL into $INSTALL_DIR..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# 4. Check for main setup script
if [ ! -f "setup.sh" ]; then
    echo "❌ Critical Error: The main setup script 'setup.sh' was not found in the repository."
    echo "Please check the repository URL ($REPO_URL) and its contents."
    exit 1
fi

# 5. Make all scripts executable and run the main one
print_header "Starting Interactive Setup"
echo "Handing over to the main setup script..."
chmod +x ./*.sh
bash ./setup.sh

print_header "Bootstrap Finished"
echo "If you ran into any issues, please check the output above or report an issue on the GitHub repository." 