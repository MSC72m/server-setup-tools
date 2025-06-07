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

# Check for root privileges at the start
check_root

# --- Welcome Message ---
print_header "Welcome to the All-in-One Server Setup"
echo "This script will help you configure your server by running a series of specialized scripts."
echo "You will be asked if you want to run each setup step."
echo ""
echo "The available setup modules are:"
echo "  1. 🔒 Secure SSH: Harden SSH, create users, set up firewall."
echo "  2. 📜 SSL Certificate: Get a free Let's Encrypt SSL certificate for a domain."
echo "  3. 🚀 Brook VPN: Install a multi-protocol VPN server using Docker."
echo ""
read -p "Press Enter to begin the setup..."

# --- Module 1: Secure SSH ---
print_header "Module 1: Secure SSH Setup"
echo "This module will secure your server's SSH access."
echo "It is highly recommended for any new server."
echo ""
while true; do
    read -p "Do you want to run the Secure SSH setup now? (y/n): " choice
    case $choice in
        [Yy]*)
            echo "🚀 Starting Secure SSH setup..."
            if [ -f ./setup-secure-ssh.sh ]; then
                bash ./setup-secure-ssh.sh
                echo "✅ Secure SSH setup finished."
            else
                echo "❌ Error: setup-secure-ssh.sh not found!"
            fi
            break
            ;;
        [Nn]*)
            echo "Skipping Secure SSH setup."
            break
            ;;
        *)
            echo "Invalid input. Please answer y (yes) or n (no)."
            ;;
    esac
done

# --- Module 2: SSL Certificate ---
print_header "Module 2: SSL Certificate Setup"
echo "This module will obtain a free SSL certificate from Let's Encrypt."
echo "This is required if you plan to use the Brook WSS (WebSocket Secure) VPN service."
echo ""
while true; do
    read -p "Do you want to run the SSL Certificate setup now? (y/n): " choice
    case $choice in
        [Yy]*)
            echo "🚀 Starting SSL Certificate setup..."
            if [ -f ./setup-ssl.sh ]; then
                bash ./setup-ssl.sh
                echo "✅ SSL Certificate setup finished."
            else
                echo "❌ Error: setup-ssl.sh not found!"
            fi
            break
            ;;
        [Nn]*)
            echo "Skipping SSL Certificate setup."
            break
            ;;
        *)
            echo "Invalid input. Please answer y (yes) or n (no)."
            ;;
    esac
done

# --- Module 3: Brook VPN ---
print_header "Module 3: Brook VPN Setup"
echo "This module will install and configure the Brook VPN services using Docker."
echo "You can choose which VPN protocols (VPN, SOCKS5, WSS) to enable."
echo ""
while true; do
    read -p "Do you want to run the Brook VPN setup now? (y/n): " choice
    case $choice in
        [Yy]*)
            echo "🚀 Starting Brook VPN setup..."
            if [ -f ./setup-brook.sh ] && [ -f ./docker-compose.yml ]; then
                bash ./setup-brook.sh
                echo "✅ Brook VPN setup finished."
            else
                echo "❌ Error: setup-brook.sh or docker-compose.yml not found!"
            fi
            break
            ;;
        [Nn]*)
            echo "Skipping Brook VPN setup."
            break
            ;;
        *)
            echo "Invalid input. Please answer y (yes) or n (no)."
            ;;
    esac
done

# --- Final Message ---
print_header "Setup Process Finished"
echo "All selected setup modules have been executed."
echo "Please review the output from each script for important information, such as usernames, passwords, and ports."
echo ""
echo "✅ Your server setup is complete!"
echo "" 