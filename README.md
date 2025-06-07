# Manual VPN & Secure SSH Server Setup

Welcome! This project provides a collection of scripts to turn a fresh Debian-based server (like Ubuntu) into a secure, multi-protocol VPN and SSH server. It's designed to be run interactively, guiding you through each step of the process.

This setup will help you:
- Secure your SSH access.
- Install and configure Brook VPN services.
- Set up SSL certificates with Let's Encrypt.

## ✨ Features

- **Secure SSH:**
  - Changes the default SSH port.
  - Disables root login.
  - Creates a new admin user with `sudo` rights.
  - Can create additional, restricted users for SSH tunneling (VPN).
  - Sets up `fail2ban` to protect against brute-force attacks.
  - Configures a firewall (UFW) to allow only necessary ports.

- **Brook VPN Services:**
  - **Brook VPN Server:** A standard, fast VPN server.
  - **SOCKS5 Proxy:** A versatile proxy server with username/password authentication.
  - **WSS (WebSocket Secure) Server:** A stealthy VPN that masks traffic as regular HTTPS.

- **Automatic SSL:**
  - Automatically obtains and installs free SSL certificates from Let's Encrypt for your domain.
  - Sets up automatic renewal.

- **Dockerized Services:**
  - All Brook VPN services run in isolated Docker containers for better security and easy management.

## 📋 Requirements

1.  **A Server:** A fresh server running a Debian-based Linux distribution (e.g., Ubuntu 20.04 or newer).
2.  **Root Access:** You'll need to be able to run commands as the `root` user (using `sudo`).
3.  **Domain Name (Optional):** If you want to use the WSS (WebSocket Secure) service, you'll need a domain name that points to your server's IP address.
4.  **Git:** The `git` command-line tool must be installed to download the scripts. You can install it with `sudo apt-get update && sudo apt-get install -y git`.

## 🚀 How to Run the Setup

The setup is run from a main script that lets you choose which components to install.

### 1. Download the Scripts
First, connect to your server and clone this repository:
```bash
git clone https://github.com/MSC72m/vpn-setup-tools.git
```

### 2. Start the Interactive Setup
Navigate into the new directory, make the scripts executable, and run the main setup file:
```bash
cd vpn-setup-tools
chmod +x *.sh
sudo ./setup.sh
```
This will start an interactive guide that will ask you which setup modules you want to run.

## 📁 The Scripts

The setup process is divided into several scripts. The main `setup.sh` script will orchestrate running them, but you can also run them individually if you are an advanced user. They should be run in the order listed below.

### 1. `setup-secure-ssh.sh`
**What it does:** This is the most critical script for securing your server. It hardens your SSH configuration, creates a new administrative user (with `sudo`), disables direct `root` login, and can create additional restricted users intended only for VPN/tunneling access. It also configures the UFW firewall and installs `fail2ban` to prevent brute-force attacks.
**How to run it:**
```bash
sudo ./setup-secure-ssh.sh
```
> **Note:** This script is run first by the main `setup.sh` orchestrator.

### 2. `setup-ssl.sh`
**What it does:** This script obtains a free SSL certificate from Let's Encrypt. You will need a domain name that correctly points to your server's IP address. This certificate is required if you want to use the stealthy WSS (WebSocket Secure) VPN service. It also configures a cron job to handle automatic renewal.
**How to run it:**
```bash
sudo ./setup-ssl.sh
```
> **Note:** This should be run after securing your server but before setting up the Brook VPN services if you need WSS.

### 3. `setup-brook.sh`
**What it does:** This script configures and deploys the Brook VPN services (standard VPN, SOCKS5 proxy, and WSS). It uses Docker and Docker Compose to run the services in isolated containers, based on the `docker-compose.yml` file and the configuration you provide.
**How to run it:**
```bash
sudo ./setup-brook.sh
```
> **Note:** This is the final step and should be run after the server is secured and you have an SSL certificate (if needed).

### `setup.sh` (Main Orchestrator)
This is the main script that provides an interactive menu to run the other scripts in the correct order. It's the recommended way to use this project.

## ⚠️ Disclaimer

These scripts are provided as-is. While they are designed to improve security, always be careful when running scripts with root privileges on your server. It's recommended to understand what the scripts do before running them.

---
Happy tunneling! 