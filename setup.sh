#!/bin/bash
#
# =================================================================
#  All-in-One Server Setup - Main Orchestrator
# =================================================================
#  This script guides the user through the setup process,
#  allowing them to choose which components to install.
# =================================================================

# Exit on any error
set -e

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "❌ This script must be run as root. Please use 'sudo'."
        exit 1
    fi
}

# Function to display a clear section header
print_header() {
    echo ""
    echo "================================================"
    echo "  $1"
    echo "================================================"
    echo ""
}

# Function to print the welcome message
print_welcome_message() {
    print_header "Welcome to the All-in-One Server Setup"
    echo "This script will help you configure your server by running a series of specialized scripts."
    echo "You will be asked if you want to run each setup step."
    echo ""
    echo "The available setup modules are:"
    echo "  1. 🔒 Secure SSH: Harden SSH, create users, set up firewall."
    echo "  2. 📜 SSL Certificate: Get a free Let's Encrypt SSL certificate for a domain."
    echo "  3. 🚀 Brook VPN: Install a multi-protocol VPN server using Docker."
}

# Check for root privileges at the start
check_root

# --- Welcome Message ---
print_welcome_message

# --- Helper to Ask User to Start ---
# Pause and wait for the user to press Enter to start the process.
wait_for_user_to_start() {
    print_header "Ready to Begin"
    echo "The setup is ready to start."
    read -p "Press Enter to begin the setup..." < /dev/tty
}

# --- Reusable Prompt ---
# A reusable function to ask the user if they want to run a setup module.
prompt_to_run() {
    local question=$1
    local choice_var=$2
    while true; do
        read -p "$question (y/n): " choice < /dev/tty
        case "$choice" in
            [Yy]* ) eval "$choice_var='y'"; break;;
            [Nn]* ) eval "$choice_var='n'"; break;;
            * ) echo "Invalid input. Please answer y (yes) or n (no).";;
        esac
    done
}

# --- Main Logic ---
# Clear the screen for a clean start
clear
print_welcome_message

wait_for_user_to_start

# --- 1. Secure SSH ---
print_header "Module 1: Secure SSH Setup"
echo "This module will secure your server's SSH access."
echo "It is highly recommended for any new server."
echo ""
prompt_to_run "Do you want to run the Secure SSH setup now?" RUN_SSH_SETUP
if [[ "$RUN_SSH_SETUP" == "y" ]]; then
    ./setup-secure-ssh.sh
fi

# --- 2. SSL Certificate ---
print_header "Module 2: SSL Certificate Setup"
echo "This module gets a free SSL certificate from Let's Encrypt."
echo "This is required for the WSS (stealth) VPN service."
echo ""
prompt_to_run "Do you want to run the SSL Certificate setup now?" RUN_SSL_SETUP
if [[ "$RUN_SSL_SETUP" == "y" ]]; then
    ./setup-ssl.sh
fi

# --- 3. Brook VPN ---
print_header "Module 3: Brook VPN Setup"
echo "This module installs Brook VPN services using Docker."
echo "You can choose which services (VPN, SOCKS5, WSS) to enable."
echo ""
prompt_to_run "Do you want to run the Brook VPN setup now?" RUN_BROOK_SETUP
if [[ "$RUN_BROOK_SETUP" == "y" ]]; then
    ./setup-brook.sh
fi

print_header "🎉 All Done!"

# --- Final Message ---
print_header "Setup Process Finished"
echo "All selected setup modules have been executed."
echo "Please review the output from each script for important information, such as usernames, passwords, and ports."
echo ""
echo "✅ Your server setup is complete!"
echo "" 