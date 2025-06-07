# One-Command Secure VPN & SSH Server Setup

Welcome! This project provides a collection of scripts to turn a fresh Debian-based server (like Ubuntu) into a secure, multi-protocol VPN and SSH server. It's designed to be as simple as possible, even for users with little to no command-line experience.

With a single command, you can launch an interactive setup that will:
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
  - **SOCKS5 Proxy:** A versatile proxy server with username/password authentication, great for development or bypassing geo-restrictions.
  - **WSS (WebSocket Secure) Server:** A stealthy VPN that masks traffic as regular HTTPS, making it effective against firewalls.

- **Automatic SSL:**
  - Automatically obtains and installs free SSL certificates from Let's Encrypt for your domain.
  - Sets up automatic renewal, so you don't have to worry about expiration.

- **Dockerized Services:**
  - All Brook VPN services run in isolated Docker containers for better security and easy management.

## 📋 Requirements

1.  **A Server:** A fresh server running a Debian-based Linux distribution (e.g., Ubuntu 20.04 or newer).
2.  **Root Access:** You'll need to be able to run commands as the `root` user (using `sudo`).
3.  **Domain Name (Optional):** If you want to use the WSS (WebSocket Secure) service, you'll need a domain name that points to your server's IP address.

## 🚀 Quick Start

Connect to your server via SSH. Then, run the following command. It will download the setup files and start the interactive installation guide.

```bash
curl -sL https://raw.githubusercontent.com/MSC72m/vpn-setup-tools/main/bootstrap.sh | sudo bash
```

This command downloads a bootstrap script and executes it. The script will:
1.  Check if `git` is installed (and ask to install it if it's not).
2.  Clone this repository into `/opt/vpn-setup-script`.
3.  Start the main interactive setup script (`setup.sh`).

The setup script will then ask you which components you'd like to install and guide you through each configuration step.

## 🤔 What Happens During Setup?

The setup is divided into three main parts. You can choose to run any or all of them.

### Part 1: Securing Your Server (SSH)

This is the first and most crucial step. It hardens your server's security.
- **It asks for a new SSH port:** Changing from the default port 22 makes it harder for bots to find and attack your server.
- **It creates new users:** You'll create an admin user for managing the server and can add more users who can only use the server for VPN access (no shell access).
- **It disables root login:** Logging in directly as `root` is risky. This script ensures you log in with your admin user and use `sudo` for administrative tasks.
- **It sets up a firewall:** A firewall is configured to block all incoming connections except for the services you explicitly approve (like your new SSH port and VPN ports).

### Part 2: Getting a Security Certificate (SSL)

This step is required if you want to use the WSS (WebSocket Secure) VPN.
- **It asks for your domain and email:** This information is needed to register a free SSL certificate with Let's Encrypt.
- **It verifies your domain:** It checks that your domain name correctly points to your server's IP address.
- **It installs the certificate:** It fetches the certificate and places it where the WSS service can use it.
- **It sets up auto-renewal:** Certificates expire, but the script sets up a cron job to renew them automatically.

### Part 3: Setting Up Your VPN (Brook)

This is where you configure and launch your VPN services.
- **It lets you choose services:** You can enable any combination of the Brook VPN, SOCKS5, and WSS services.
- **It asks for configuration details:** You'll set ports and passwords for your services.
- **It uses Docker:** It pulls the Brook Docker image and starts the services in containers based on your selections and the `docker-compose.yml` file. This keeps them isolated and easy to manage.

## 📁 The Scripts

- `bootstrap.sh`: The entry point script for the one-liner command. It clones the repo and starts the setup.
- `setup.sh`: The main interactive orchestrator that guides you through the setup choices.
- `setup-secure-ssh.sh`: The script that handles all SSH hardening and user setup.
- `setup-ssl.sh`: The script for obtaining Let's Encrypt SSL certificates.
- `setup-brook.sh`: The script for configuring and deploying the Brook VPN services via Docker Compose.
- `docker-compose.yml`: The Docker Compose file that defines the Brook VPN services.
- `README.md`: This file.

## ⚠️ Disclaimer

These scripts are provided as-is. While they are designed to improve security, always be careful when running scripts with root privileges on your server. It's recommended to understand what the scripts do before running them.

---
Happy tunneling! 