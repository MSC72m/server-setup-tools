#!/bin/bash
#
# =================================================================
#  SSL Certificate Setup Script (Let's Encrypt)
# =================================================================
#  This script is called from the main setup script.
#  It handles:
#  - Installing certbot.
#  - Verifying domain ownership.
#  - Obtaining an SSL certificate from Let's Encrypt.
#  - Setting up automatic renewal.
# =================================================================

# Exit on any error
set -e

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi
}

# Function to check if port 80 is available
check_port_80() {
    if netstat -tuln | grep -q ":80 "; then
        local pid=$(lsof -i :80 -t 2>/dev/null)
        if [ -n "$pid" ]; then
            local process_info=$(ps -p $pid -o comm= 2>/dev/null)
            echo "Port 80 is in use by process: $process_info (PID: $pid)"
            echo "To fix this, you can:"
            echo "1. Stop the process: sudo systemctl stop $process_info (if it's a service)"
            echo "   or"
            echo "2. Kill the process: sudo kill $pid"
            echo "   or"
            echo "3. Temporarily stop the process and run this script again"
            return 1
        fi
    fi
    return 0
}

# Function to get server's IPv4 address
get_server_ipv4() {
    # Try multiple methods to get the IPv4 address
    local ipv4=""
    
    # Method 1: Using curl and ipify
    ipv4=$(curl -s https://api.ipify.org)
    
    # Method 2: Using curl and ifconfig.me
    if [ -z "$ipv4" ]; then
        ipv4=$(curl -s https://ifconfig.me/ip)
    fi
    
    # Method 3: Using hostname
    if [ -z "$ipv4" ]; then
        ipv4=$(hostname -I | awk '{print $1}')
    fi
    
    echo "$ipv4"
}

# Function to check DNS propagation
check_dns_propagation() {
    local domain=$1
    local expected_ip=$2
    local max_attempts=30
    local attempt=1
    local wait_time=10
    
    echo "Checking DNS propagation..."
    echo "This may take a few minutes..."
    
    while [ $attempt -le $max_attempts ]; do
        local current_ip=$(dig +short A $domain)
        
        if [ -n "$current_ip" ]; then
            if [ "$current_ip" = "$expected_ip" ]; then
                echo "✅ DNS propagation successful!"
                return 0
            else
                echo "Attempt $attempt/$max_attempts: Domain points to $current_ip, expected $expected_ip"
            fi
        else
            echo "Attempt $attempt/$max_attempts: DNS record not found yet"
        fi
        
        if [ $attempt -lt $max_attempts ]; then
            echo "Waiting ${wait_time}s for DNS propagation..."
            sleep $wait_time
        fi
        
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Function to verify domain DNS
verify_dns() {
    local domain=$1
    local server_ipv4=$(get_server_ipv4)
    
    echo "Verifying DNS configuration..."
    echo "Your server's public IPv4 address is: $server_ipv4"
    echo "Checking if $domain points to this IP..."
    
    # Get domain's IP
    local domain_ip=$(dig +short A $domain)
    
    if [ -z "$domain_ip" ]; then
        echo "Error: Could not resolve $domain"
        echo "Please add an A record in your domain's DNS settings:"
        echo "Type: A"
        echo "Name: @ (or leave blank)"
        echo "Value: $server_ipv4"
        echo "TTL: 3600 (or default)"
        echo ""
        echo "After adding the DNS record, wait a few minutes for propagation and run this script again."
        return 1
    fi
    
    if [ "$domain_ip" != "$server_ipv4" ]; then
        echo "Current DNS configuration for $domain:"
        echo "A record points to: $domain_ip"
        echo "Expected IP: $server_ipv4"
        echo ""
        echo "Please update your domain's A record to point to: $server_ipv4"
        echo "After updating the DNS record, wait a few minutes for propagation and run this script again."
        return 1
    fi
    
    # Check DNS propagation
    if ! check_dns_propagation "$domain" "$server_ipv4"; then
        echo "❌ DNS propagation check failed"
        echo "Please ensure your DNS changes have propagated and run this script again."
        return 1
    fi
    
    echo "✅ DNS verification successful"
    return 0
}

# Check if running as root
check_root

# Install required dependencies
echo "Installing required dependencies..."
apt-get update
apt-get install -y \
    certbot \
    net-tools \
    dnsutils \
    curl

# Get user input
read -p "Enter your domain name (e.g., example.com): " DOMAIN
read -p "Enter your email address: " EMAIL

# Verify DNS configuration
if ! verify_dns "$DOMAIN"; then
    echo "Please fix your DNS configuration and run this script again."
    exit 1
fi

# Check if port 80 is available
if ! check_port_80; then
    echo "Please free up port 80 and run this script again."
    exit 1
fi

# Configure firewall to allow port 80 temporarily
echo "Configuring firewall..."
if command_exists ufw; then
    # Allow port 80 for ACME challenge
    ufw allow 80/tcp
fi

# Get SSL certificate
echo "Obtaining SSL certificate for $DOMAIN..."
certbot certonly --standalone \
    --preferred-challenges http \
    --agree-tos \
    --email "$EMAIL" \
    -d "$DOMAIN" \
    --non-interactive

# Check if certificate was obtained successfully
if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "Failed to obtain SSL certificate. Please check the error messages above."
    exit 1
fi

echo "SSL certificates have been set up successfully!"
echo "Domain: $DOMAIN"
echo "Certificates are stored in: /etc/letsencrypt/live/$DOMAIN/"

# Set up auto-renewal
echo "Setting up auto-renewal..."
echo "0 0 * * * root certbot renew --quiet" > /etc/cron.d/ssl-renewal
chmod 644 /etc/cron.d/ssl-renewal

echo "Auto-renewal has been set up. Certificates will be renewed automatically when needed."

# Remove temporary port 80 access if it was added
if command_exists ufw; then
    ufw delete allow 80/tcp
fi

echo "✅ Setup completed successfully!" 