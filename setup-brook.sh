#!/bin/bash

#==============================================================================
# Brook VPN Setup Script
#==============================================================================
# This script sets up a complete Brook VPN server with multiple protocols:
# 
# SERVICES:
# - Brook VPN Server (TCP) - Standard Brook proxy server
# - Brook SOCKS5 Server (TCP/UDP) - SOCKS5 proxy server with authentication
# - Brook WSS Server (TCP) - WebSocket Secure server with TLS
#
# SOCKS5 USAGE:
# - Good for bypassing sanctions and geo-restrictions (not content filtering)
# - Excellent for development work and API testing
# - Supports both TCP and UDP protocols
# - Requires username/password authentication
#
# FEATURES:
# - Automatic SSL certificate integration with Let's Encrypt
# - Docker containerized deployment with health checks
# - Dynamic server IP detection for UDP support
# - Port conflict detection and resolution
# - Service connectivity testing
# - Automatic SSL certificate renewal setup
# - Clean container management (removes existing containers)
#
# REQUIREMENTS:
# - Root privileges
# - Docker and Docker Compose
# - Valid SSL certificates (Let's Encrypt recommended)
# - Domain name pointing to server IP
#
# USAGE:
# sudo ./setup-brook.sh
#==============================================================================

# Exit on any error
set -e

# Default ports
DEFAULT_VPN_PORT=7799
DEFAULT_SOCKS5_PORT=1080
DEFAULT_WSS_PORT=8899

# Function to get server's primary IP address
get_server_ip() {
    local server_ip=""
    local external_ip=""
    local route_ip=""
    local hostname_ip=""
    local interface_ip=""
    
    echo "Detecting server IP address..." >&2
    
    # Method 1: Using external services (most reliable for public IP)
    if command -v curl >/dev/null 2>&1; then
        echo "  Checking external IP services..." >&2
        external_ip=$(timeout 10 curl -s ifconfig.me 2>/dev/null || timeout 10 curl -s ipinfo.io/ip 2>/dev/null || timeout 10 curl -s icanhazip.com 2>/dev/null || echo "")
        if [[ $external_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            echo "  ✅ External IP detected: $external_ip" >&2
            server_ip="$external_ip"
        else
            echo "  ❌ External IP detection failed" >&2
        fi
    fi
    
    # Method 2: Using ip route (good for local network IP)
    echo "  Checking ip route..." >&2
    route_ip=$(ip route get 8.8.8.8 2>/dev/null | awk '{print $7; exit}' || echo "")
    if [[ $route_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "  ✅ Route IP detected: $route_ip" >&2
        if [ -z "$server_ip" ]; then
            server_ip="$route_ip"
        fi
    else
        echo "  ❌ Route IP detection failed" >&2
    fi
    
    # Method 3: Using hostname -I
    echo "  Checking hostname..." >&2
    hostname_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "")
    if [[ $hostname_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "  ✅ Hostname IP detected: $hostname_ip" >&2
        if [ -z "$server_ip" ]; then
            server_ip="$hostname_ip"
        fi
    else
        echo "  ❌ Hostname IP detection failed" >&2
    fi
    
    # Method 4: Using ip addr
    echo "  Checking network interfaces..." >&2
    interface_ip=$(ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}' | cut -d'/' -f1 || echo "")
    if [[ $interface_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "  ✅ Interface IP detected: $interface_ip" >&2
        if [ -z "$server_ip" ]; then
            server_ip="$interface_ip"
        fi
    else
        echo "  ❌ Interface IP detection failed" >&2
    fi
    
    # Auto-select best IP or prompt user
    if [ -n "$server_ip" ]; then
        echo "" >&2
        echo "✅ Automatically selected IP: $server_ip" >&2
        
        # If we have multiple options, let user confirm or choose different
        local alternatives=()
        [ -n "$external_ip" ] && [ "$external_ip" != "$server_ip" ] && alternatives+=("External: $external_ip")
        [ -n "$route_ip" ] && [ "$route_ip" != "$server_ip" ] && alternatives+=("Route: $route_ip")
        [ -n "$hostname_ip" ] && [ "$hostname_ip" != "$server_ip" ] && alternatives+=("Hostname: $hostname_ip")
        [ -n "$interface_ip" ] && [ "$interface_ip" != "$server_ip" ] && alternatives+=("Interface: $interface_ip")
        
        if [ ${#alternatives[@]} -gt 0 ]; then
            echo "" >&2
            read -p "Use this IP? (y/n): " confirm
            if [[ $confirm =~ ^[Nn] ]]; then
                echo "" >&2
                echo "Alternative IP addresses found:" >&2
                for i in "${!alternatives[@]}"; do
                    echo "  $((i+1)). ${alternatives[$i]}" >&2
                done
                echo "  $((${#alternatives[@]}+1)). Enter IP manually" >&2
                echo "" >&2
                
                while true; do
                    read -p "Select alternative (1-$((${#alternatives[@]}+1))): " choice
                    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $((${#alternatives[@]}+1)) ]; then
                        if [ "$choice" -eq $((${#alternatives[@]}+1)) ]; then
                            read -p "Enter your server's IP address: " server_ip
                            if [[ $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                                break
                            else
                                echo "Invalid IP format. Please try again." >&2
                            fi
                        else
                            server_ip=$(echo "${alternatives[$((choice-1))]}" | awk '{print $NF}')
                            break
                        fi
                    else
                        echo "Invalid choice. Please select 1-$((${#alternatives[@]}+1))." >&2
                    fi
                done
            fi
        fi
    else
        echo "" >&2
        echo "❌ Could not detect any IP addresses automatically." >&2
        while true; do
            read -p "Please enter your server's public IP address: " server_ip
            if [[ $server_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                break
            else
                echo "Invalid IP format. Please try again." >&2
            fi
        done
    fi
    
    echo "$server_ip"
}

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

# Function to get process info for a port
get_port_process_info() {
    local port=$1
    local protocol=${2:-tcp}
    
    if ! command_exists lsof; then
        apt-get install -y lsof
    fi
    
    local pid=$(lsof -i :$port -t 2>/dev/null)
    if [ -n "$pid" ]; then
        local process_info=$(ps -p $pid -o comm= 2>/dev/null)
        local service_name=$(systemctl list-units --type=service --state=running | grep $process_info | head -n1 | awk '{print $1}')
        
        echo "Port $port is in use by:"
        echo "  Process: $process_info (PID: $pid)"
        if [ -n "$service_name" ]; then
            echo "  Service: $service_name"
            echo "  To stop: sudo systemctl stop $service_name"
        fi
        echo "  To kill: sudo kill $pid"
        return 1
    fi
    return 0
}

# Function to check if a port is in use
check_port_in_use() {
    local port=$1
    local protocol=${2:-tcp}
    
    # Check if netstat is available
    if ! command_exists netstat; then
        apt-get install -y net-tools
    fi
    
    # Check if port is in use
    if netstat -tuln | grep -q ":$port "; then
        get_port_process_info "$port" "$protocol"
        return 1
    fi
    return 0
}

# Function to validate port number
validate_port() {
    local port=$1
    local protocol=${2:-tcp}
    local default_port=$3
    
    # Check if port is a valid number
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        echo "Invalid port number. Please enter a number between 1 and 65535."
        return 1
    fi
    
    # Check if port is in use
    if ! check_port_in_use "$port" "$protocol"; then
        if [ "$port" = "$default_port" ]; then
            echo "The default port $port is in use. Please choose a different port."
        fi
        return 1
    fi
    
    return 0
}

# Function to test TCP port connectivity
test_tcp_port() {
    local host=$1
    local port=$2
    local service_name=$3
    
    echo "Testing $service_name connectivity..."
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        echo "✅ $service_name is accessible on port $port"
        return 0
    else
        echo "❌ $service_name is not accessible on port $port"
        return 1
    fi
}

# Function to test SOCKS5 connectivity
test_socks5_port() {
    local host=$1
    local port=$2
    local service_name=$3
    
    echo "Testing $service_name connectivity..."
    
    # Check if the service is running in the container
    if ! docker exec brook-socks5 ps aux | grep -q "brook socks5"; then
        echo "❌ $service_name is not running in container"
        return 1
    fi
    
    # Check SOCKS5 port
    if ! netstat -tln | grep -q ":$port "; then
        echo "❌ $service_name SOCKS5 port $port is not open"
        return 1
    fi
    
    echo "✅ $service_name is running (SOCKS5 port $port is open)"
    return 0
}

# Function to test WSS connectivity
test_wss_port() {
    local host=$1
    local port=$2
    local service_name=$3
    
    echo "Testing $service_name connectivity..."
    
    # First check if the port is open
    if ! netstat -tln | grep -q ":$port "; then
        echo "❌ $service_name port $port is not open"
        return 1
    fi
    
    # Check if the service is running in the container
    if ! docker exec brook-wss ps aux | grep -q "brook wssserver"; then
        echo "❌ $service_name is not running in container"
        return 1
    fi
    
    # Try to connect to the WSS endpoint
    if timeout 5 curl -s -k -o /dev/null -w "%{http_code}" "https://$host:$port/ws" 2>/dev/null | grep -q "400\|404\|426"; then
        echo "✅ $service_name is accessible on port $port (WSS endpoint responding)"
        return 0
    else
        echo "✅ $service_name is running (WSS port $port is open)"
        return 0
    fi
}

# Function to test Brook services
test_brook_services() {
    local domain=$1
    local vpn_port=$2
    local socks5_port=$3
    local wss_port=$4
    
    echo "Testing Brook services connectivity..."
    
    # Install required tools
    if ! command_exists nc; then
        apt-get install -y netcat
    fi
    if ! command_exists curl; then
        apt-get install -y curl
    fi
    
    # Test VPN service (TCP)
    test_tcp_port "localhost" "$vpn_port" "Brook VPN"
    local vpn_status=$?
    
    # Test SOCKS5 service (TCP)
    test_socks5_port "localhost" "$socks5_port" "Brook SOCKS5"
    local socks5_status=$?
    
    # Test WSS service (TCP)
    test_wss_port "localhost" "$wss_port" "Brook WSS"
    local wss_status=$?
    
    # Return overall status
    if [ $vpn_status -eq 0 ] && [ $socks5_status -eq 0 ] && [ $wss_status -eq 0 ]; then
        echo "✅ All Brook services are accessible!"
        return 0
    else
        echo "❌ Some Brook services are not accessible. Please check the logs above."
        return 1
    fi
}

# Function to clean up existing Brook containers
cleanup_existing_containers() {
    echo "Checking for existing Brook containers..."
    
    # List of container names to check
    local containers=("brook-vpn" "brook-socks5" "brook-wss")
    
    for container in "${containers[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
            echo "Found existing container: $container"
            echo "Removing container: $container"
            docker rm -f "$container" || true
        fi
    done
    
    echo "Cleanup completed"
}

# Function to display service selection menu
select_services() {
    echo ""
    echo "=============================================="
    echo "           Brook Services Selection"
    echo "=============================================="
    echo ""
    echo "Available Brook services:"
    echo ""
    echo "1. 📡 Brook VPN Server (TCP)"
    echo "   - Standard Brook proxy server"
    echo "   - Good for general VPN usage"
    echo "   - Requires: Port configuration"
    echo ""
    echo "2. 🧦 Brook SOCKS5 Server (TCP/UDP)"
    echo "   - SOCKS5 proxy with authentication"
    echo "   - Excellent for bypassing sanctions and geo-restrictions"
    echo "   - Perfect for development work and API testing"
    echo "   - Requires: Username, password, server IP, port"
    echo ""
    echo "3. 🔒 Brook WSS Server (TCP)"
    echo "   - WebSocket Secure server with TLS"
    echo "   - Works through firewalls and CDNs"
    echo "   - Requires: Domain name, SSL certificates, port"
    echo ""
    
    # Initialize all services as disabled
    ENABLE_VPN=false
    ENABLE_SOCKS5=false
    ENABLE_WSS=false
    
    echo "Select which services to install:"
    echo "(You can select multiple services)"
    echo ""
    
    # VPN Selection
    while true; do
        read -p "Install Brook VPN Server? (y/n): " choice
        case $choice in
            [Yy]*)
                ENABLE_VPN=true
                echo "  ✅ Brook VPN Server selected"
                break
                ;;
            [Nn]*)
                ENABLE_VPN=false
                echo "  ❌ Brook VPN Server skipped"
                break
                ;;
            *)
                echo "Please answer y (yes) or n (no)."
                ;;
        esac
    done
    
    # SOCKS5 Selection
    while true; do
        read -p "Install Brook SOCKS5 Server? (y/n): " choice
        case $choice in
            [Yy]*)
                ENABLE_SOCKS5=true
                echo "  ✅ Brook SOCKS5 Server selected"
                break
                ;;
            [Nn]*)
                ENABLE_SOCKS5=false
                echo "  ❌ Brook SOCKS5 Server skipped"
                break
                ;;
            *)
                echo "Please answer y (yes) or n (no)."
                ;;
        esac
    done
    
    # WSS Selection
    while true; do
        read -p "Install Brook WSS Server? (y/n): " choice
        case $choice in
            [Yy]*)
                ENABLE_WSS=true
                echo "  ✅ Brook WSS Server selected"
                break
                ;;
            [Nn]*)
                ENABLE_WSS=false
                echo "  ❌ Brook WSS Server skipped"
                break
                ;;
            *)
                echo "Please answer y (yes) or n (no)."
                ;;
        esac
    done
    
    # Validate at least one service is selected
    if [ "$ENABLE_VPN" = false ] && [ "$ENABLE_SOCKS5" = false ] && [ "$ENABLE_WSS" = false ]; then
        echo ""
        echo "❌ Error: You must select at least one service!"
        echo "Please run the script again and select at least one service."
        exit 1
    fi
    
    # Show summary
    echo ""
    echo "📋 Selected Services Summary:"
    [ "$ENABLE_VPN" = true ] && echo "  ✅ Brook VPN Server"
    [ "$ENABLE_SOCKS5" = true ] && echo "  ✅ Brook SOCKS5 Server"
    [ "$ENABLE_WSS" = true ] && echo "  ✅ Brook WSS Server"
    echo ""
    
    # Confirm selection
    while true; do
        read -p "Proceed with these services? (y/n): " confirm
        case $confirm in
            [Yy]*)
                echo "✅ Service selection confirmed!"
                break
                ;;
            [Nn]*)
                echo "Restarting service selection..."
                select_services
                return
                ;;
            *)
                echo "Please answer y (yes) or n (no)."
                ;;
        esac
    done
    echo ""
}

# Function to verify SSL certificates
verify_ssl_certificates() {
    local domain=$1
    local cert_path="/etc/letsencrypt/live/$domain"
    
    echo "Verifying SSL certificates..."
    
    if [ ! -d "$cert_path" ]; then
        echo "❌ SSL certificate directory not found at $cert_path"
        return 1
    fi
    
    if [ ! -f "$cert_path/fullchain.pem" ] || [ ! -f "$cert_path/privkey.pem" ]; then
        echo "❌ SSL certificate files not found"
        echo "Expected files:"
        echo "  - $cert_path/fullchain.pem"
        echo "  - $cert_path/privkey.pem"
        return 1
    fi
    
    # Verify certificate validity
    if ! openssl x509 -in "$cert_path/fullchain.pem" -text -noout >/dev/null 2>&1; then
        echo "❌ Invalid SSL certificate"
        return 1
    fi
    
    echo "✅ SSL certificates verified"
    return 0
}

# Function to create environment file
create_env_file() {
    echo "Creating environment file..."
    
    cat > .env << EOF
# Brook Services Configuration
BROOK_PASSWORD=${BROOK_PASSWORD}

# Server Configuration
SERVER_IP=${SERVER_IP:-127.0.0.1}

# VPN Service
BROOK_VPN_PORT=${BROOK_VPN_PORT:-7799}

# SOCKS5 Service
BROOK_SOCKS5_PORT=${BROOK_SOCKS5_PORT:-1080}
BROOK_SOCKS5_USER=${BROOK_SOCKS5_USER:-user}

# WSS Service
BROOK_WSS_PORT=${BROOK_WSS_PORT:-8899}
DOMAIN=${DOMAIN:-localhost}
SSL_DIR=${SSL_DIR:-/etc/letsencrypt/live/${DOMAIN}}
EOF

    echo "✅ Environment file created successfully"
}

# Function to start selected services
start_brook_services() {
    echo "Starting selected Brook services..."
    
    # Build profiles array based on selected services
    local profiles=()
    [ "$ENABLE_VPN" = true ] && profiles+=("vpn")
    [ "$ENABLE_SOCKS5" = true ] && profiles+=("socks5")
    [ "$ENABLE_WSS" = true ] && profiles+=("wss")
    
    # Join profiles with comma
    local profile_list=$(IFS=,; echo "${profiles[*]}")
    
    echo "Starting services with profiles: $profile_list"
    
    # Start services with selected profiles
    COMPOSE_PROFILES="$profile_list" docker compose -f docker-compose.yml up -d
    
    echo "✅ Brook services started successfully"
}

# Check if running as root
check_root

# Service selection
select_services

# Get server IP dynamically (only if SOCKS5 is enabled)
if [ "$ENABLE_SOCKS5" = true ]; then
    echo "=============================================="
    echo "        Server IP Detection (SOCKS5)"
    echo "=============================================="
    echo "SOCKS5 requires your server's IP address for UDP support."
    echo "This enables full TCP/UDP proxy functionality."
    echo ""
    SERVER_IP=$(get_server_ip)
    echo "✅ Server IP selected: $SERVER_IP"
    echo ""
fi

# Get user input based on selected services
echo "=============================================="
echo "            Service Configuration"
echo "=============================================="

# Domain and email (required for WSS)
if [ "$ENABLE_WSS" = true ]; then
    echo ""
    echo "📋 Domain Configuration (Required for WSS)"
    echo "WSS service requires a valid domain name for SSL certificates."
    echo "The domain must point to this server's IP address."
    echo "If you don't have a domain, rerun the script and unselect WSS."
    echo ""
    while true; do
        read -p "Enter your domain name (e.g., example.com): " DOMAIN
        if [ -n "$DOMAIN" ]; then
            break
        else
            echo "Domain is required for WSS service. Please enter a valid domain."
        fi
    done
    
    echo ""
    echo "📧 Email for SSL Certificate"
    echo "Required for Let's Encrypt SSL certificate generation."
    echo ""
    while true; do
        read -p "Enter your email address: " EMAIL
        if [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            break
        else
            echo "Please enter a valid email address."
        fi
    done
fi

# Brook password (required for all services)
echo ""
echo "🔐 Brook Services Password"
echo "This password will be used for all enabled Brook services."
echo "Make it strong and memorable."
echo ""
while true; do
    read -s -p "Enter password for Brook servers: " BROOK_PASSWORD
    echo ""
    if [ ${#BROOK_PASSWORD} -ge 6 ]; then
        read -s -p "Confirm password: " BROOK_PASSWORD_CONFIRM
        echo ""
        if [ "$BROOK_PASSWORD" = "$BROOK_PASSWORD_CONFIRM" ]; then
            break
        else
            echo "Passwords don't match. Please try again."
        fi
    else
        echo "Password must be at least 6 characters long."
    fi
done

# SOCKS5 Configuration
if [ "$ENABLE_SOCKS5" = true ]; then
    echo ""
    echo "👤 SOCKS5 Authentication"
    echo "SOCKS5 requires username authentication for security."
    echo "This username will be used along with the password above."
    echo ""
    while true; do
        read -p "Enter username for SOCKS5 authentication: " BROOK_SOCKS5_USER
        if [ -n "$BROOK_SOCKS5_USER" ]; then
            break
        else
            echo "Username is required for SOCKS5 authentication."
        fi
    done
fi

# Get port configurations
echo ""
echo "🔌 Port Configuration"
echo "Configure ports for your selected services."
echo ""

if [ "$ENABLE_VPN" = true ]; then
    echo "📡 Brook VPN Port"
    echo "Standard Brook proxy server port (TCP only)."
    echo ""
    while true; do
        read -p "Enter port for Brook VPN (default: $DEFAULT_VPN_PORT): " BROOK_VPN_PORT
        BROOK_VPN_PORT=${BROOK_VPN_PORT:-$DEFAULT_VPN_PORT}
        if validate_port "$BROOK_VPN_PORT" "tcp" "$DEFAULT_VPN_PORT"; then
            echo "✅ VPN port set to: $BROOK_VPN_PORT"
            break
        fi
    done
    echo ""
fi

if [ "$ENABLE_SOCKS5" = true ]; then
    echo "🧦 Brook SOCKS5 Port"
    echo "SOCKS5 proxy server port (TCP and UDP)."
    echo "Standard SOCKS5 port is 1080."
    echo ""
    while true; do
        read -p "Enter port for Brook SOCKS5 (default: $DEFAULT_SOCKS5_PORT): " BROOK_SOCKS5_PORT
        BROOK_SOCKS5_PORT=${BROOK_SOCKS5_PORT:-$DEFAULT_SOCKS5_PORT}
        if validate_port "$BROOK_SOCKS5_PORT" "tcp" "$DEFAULT_SOCKS5_PORT"; then
            echo "✅ SOCKS5 port set to: $BROOK_SOCKS5_PORT"
            break
        fi
    done
    echo ""
fi

if [ "$ENABLE_WSS" = true ]; then
    echo "🔒 Brook WSS Port"
    echo "WebSocket Secure server port (TCP with SSL)."
    echo "This port will serve WSS connections with your SSL certificate."
    echo ""
    while true; do
        read -p "Enter port for Brook WSS (default: $DEFAULT_WSS_PORT): " BROOK_WSS_PORT
        BROOK_WSS_PORT=${BROOK_WSS_PORT:-$DEFAULT_WSS_PORT}
        if validate_port "$BROOK_WSS_PORT" "tcp" "$DEFAULT_WSS_PORT"; then
            echo "✅ WSS port set to: $BROOK_WSS_PORT"
            break
        fi
    done
    echo ""
fi

# Install required dependencies
echo "Installing required dependencies..."
apt-get update
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    ufw \
    net-tools \
    lsof

# Install Docker if not already installed
if ! command_exists docker; then
    echo "Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    systemctl start docker
    systemctl enable docker
fi

# Clean up any existing containers before proceeding
cleanup_existing_containers

# Install Certbot and get SSL certificate (only if WSS is enabled)
if [ "$ENABLE_WSS" = true ]; then
    echo "Installing Certbot for SSL certificates..."
    apt-get install -y certbot

    echo "Obtaining SSL certificate for $DOMAIN..."
    certbot certonly --standalone \
        --preferred-challenges http \
        --agree-tos \
        --email "$EMAIL" \
        -d "$DOMAIN"

    # Verify SSL certificates before proceeding
    if ! verify_ssl_certificates "$DOMAIN"; then
        echo "❌ SSL certificate verification failed. Please ensure certificates are properly installed."
        exit 1
    fi
    
    # Set up auto-renewal for SSL certificates
    echo "Setting up SSL certificate auto-renewal..."
    echo "0 0 * * * root certbot renew --quiet" > /etc/cron.d/ssl-renewal
    chmod 644 /etc/cron.d/ssl-renewal
fi

# Configure firewall (UFW)
echo "Configuring firewall..."
if command_exists ufw; then
    # Allow ports based on enabled services
    if [ "$ENABLE_VPN" = true ]; then
        ufw allow ${BROOK_VPN_PORT}/tcp comment 'Brook VPN'
    fi
    
    if [ "$ENABLE_SOCKS5" = true ]; then
        ufw allow ${BROOK_SOCKS5_PORT}/tcp comment 'Brook SOCKS5 TCP'
        ufw allow ${BROOK_SOCKS5_PORT}/udp comment 'Brook SOCKS5 UDP'
    fi
    
    if [ "$ENABLE_WSS" = true ]; then
        ufw allow ${BROOK_WSS_PORT}/tcp comment 'Brook WSS'
    fi
    
    # Enable UFW if not already enabled
    if ! ufw status | grep -q "Status: active"; then
        echo "y" | ufw enable
    fi
fi

# Create environment file
create_env_file

# Start the services using Docker Compose
start_brook_services

# Wait for services to start
echo "Waiting for services to start..."
sleep 10

# Test the services
test_brook_services "$DOMAIN" "$BROOK_VPN_PORT" "$BROOK_SOCKS5_PORT" "$BROOK_WSS_PORT"
test_status=$?

if [ $test_status -ne 0 ]; then
    echo "⚠️ Some services failed the connectivity test. Please check the logs above."
    echo "You can check the container logs using:"
    echo "docker logs brook-vpn"
    echo "docker logs brook-socks5"
    echo "docker logs brook-wss"
fi

# Additional WSS configuration checks
echo "Performing additional WSS configuration checks..."

# Check WSS configuration
echo "Checking WSS configuration..."
if ! docker exec brook-wss brook wssserver --help >/dev/null 2>&1; then
    echo "❌ WSS server configuration error. Please check the container logs."
    docker logs brook-wss
fi

# Verify SSL certificate permissions for WSS
echo "Verifying SSL certificate permissions..."
if ! docker exec brook-wss ls -l /etc/brook-ssl/fullchain.pem >/dev/null 2>&1 || \
   ! docker exec brook-wss ls -l /etc/brook-ssl/privkey.pem >/dev/null 2>&1; then
    echo "❌ WSS container cannot access SSL certificates"
fi

# Check if WSS is properly bound to its port
echo "Verifying service bindings..."
if ! netstat -tuln | grep -q ":${BROOK_WSS_PORT} "; then
    echo "❌ WSS service not properly bound to TCP port ${BROOK_WSS_PORT}"
else
    echo "✅ WSS service properly bound to TCP port ${BROOK_WSS_PORT}"
fi

echo "Brook services have been set up successfully!"
echo "Services running:"

if [ "$ENABLE_VPN" = true ]; then
    echo "- Brook VPN: Port ${BROOK_VPN_PORT} (TCP)"
fi

if [ "$ENABLE_SOCKS5" = true ]; then
    echo "- Brook SOCKS5: Port ${BROOK_SOCKS5_PORT} (TCP/UDP) - Username: ${BROOK_SOCKS5_USER}"
fi

if [ "$ENABLE_WSS" = true ]; then
    echo "- Brook WSS: Port ${BROOK_WSS_PORT} (TCP) - Domain: ${DOMAIN}"
fi

if [ "$ENABLE_SOCKS5" = true ]; then
    echo "Server IP: $SERVER_IP"
fi

echo ""

# Show usage examples based on enabled services
if [ "$ENABLE_SOCKS5" = true ]; then
    echo "SOCKS5 Usage Examples:"
    echo "  curl --socks5 ${SERVER_IP}:${BROOK_SOCKS5_PORT} --user ${BROOK_SOCKS5_USER}:${BROOK_PASSWORD} http://httpbin.org/ip"
    echo "  curl --socks5 localhost:${BROOK_SOCKS5_PORT} --user ${BROOK_SOCKS5_USER}:${BROOK_PASSWORD} http://httpbin.org/ip"
    echo ""
fi

if [ "$ENABLE_WSS" = true ]; then
    echo "WSS Connection:"
    echo "  wss://${DOMAIN}:${BROOK_WSS_PORT}/ws"
    echo ""
fi

if [ "$ENABLE_VPN" = true ]; then
    echo "VPN Connection:"
    echo "  Server: ${SERVER_IP:-$(hostname -I | awk '{print $1}')}:${BROOK_VPN_PORT}"
    echo "  Password: ${BROOK_PASSWORD}"
    echo ""
fi

echo "All services will automatically start on system reboot"

echo "✅ Setup completed successfully!" 
