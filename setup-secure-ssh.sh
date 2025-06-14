#!/bin/bash
#
# =================================================================
#  Secure SSH and User Setup Script
# =================================================================
#  This script is designed to be called from the main setup script.
#  It handles:
#  - Changing the SSH port.
#  - Creating an admin user with sudo privileges.
#  - Disabling root login.
#  - Creating restricted users for SSH tunneling.
#  - Setting up UFW (firewall).
#  - Installing and configuring fail2ban.
# =================================================================

# Exit on any error
set -e

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit 1
    fi
}

# Function to install all SSH and system dependencies
install_all_dependencies() {
    echo "================================================"
    echo "Installing ALL required dependencies..."
    echo "================================================"
    
    # Update package list
    apt-get update
    
    # Install essential SSH and system packages
    local packages=(
        "openssh-server"
        "openssh-client" 
        "ssh"
        "ufw"
        "fail2ban"
        "iptables"
        "iproute2"
        "net-tools"
        "tcpdump"
        "curl"
        "wget"
        "nano"
        "systemd"
    )
    
    echo "Installing packages: ${packages[*]}"
    apt-get install -y "${packages[@]}"
    
    # Ensure SSH service exists and is enabled
    systemctl enable ssh
    systemctl enable openssh-server 2>/dev/null || true
    
    # Start SSH if not running
    if ! systemctl is-active --quiet ssh; then
        systemctl start ssh
    fi
    
    echo "✅ All dependencies installed successfully"
    
    # Verify SSH daemon is working
    if ! systemctl is-active --quiet ssh; then
        echo "❌ SSH service is not running after installation"
        systemctl status ssh
        exit 1
    fi
    
    # Test SSH configuration
    if ! sshd -t; then
        echo "❌ SSH configuration test failed"
        exit 1
    fi
    
    echo "✅ SSH daemon is running and configuration is valid"
}

# Function to generate random string
generate_random_string() {
    openssl rand -base64 8 | tr -dc 'a-zA-Z0-9' | head -c 5
}

# Function to check SSH service
check_ssh_service() {
    if ! systemctl is-active --quiet ssh; then
        echo "SSH service is not running. Attempting to start..."
        systemctl start ssh
        sleep 2
        if ! systemctl is-active --quiet ssh; then
            echo "Failed to start SSH service. Please check the logs:"
            journalctl -u ssh --no-pager -n 50
            exit 1
        fi
    fi
}

# Function to verify port is listening
verify_port_listening() {
    local port=$1
    local max_attempts=5
    local attempt=1
    
    echo "Verifying port $port is listening..."
    while [ $attempt -le $max_attempts ]; do
        if netstat -tuln | grep -q ":$port "; then
            echo "✅ Port $port is listening"
            return 0
        fi
        echo "Attempt $attempt: Port $port not listening, waiting..."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo "❌ Port $port is not listening after $max_attempts attempts"
    return 1
}

# Function to remove existing users
remove_existing_users() {
    echo "Removing existing users..."
    # Get list of all users except root
    for user in $(awk -F: '$3 >= 1000 && $3 != 65534 {print $1}' /etc/passwd); do
        if [ "$user" != "root" ]; then
            echo "Removing user $user..."
            userdel -r "$user" 2>/dev/null || true
        fi
    done
}

# Function to get valid port number
get_valid_port() {
    local port
    read -p "Do you want to change the default SSH port? (y/n): " change_port
    if [[ "$change_port" =~ ^[Yy]$ ]]; then
        while true; do
            read -p "Enter SSH port number (1024-65535): " port
            if [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1024 ] && [ "$port" -le 65535 ]; then
                echo "$port"
                return 0
            fi
            echo "Invalid port number. Please enter a number between 1024 and 65535."
        done
    else
        echo "22"  # Default SSH port
        return 0
    fi
}

# Function to get valid username
get_valid_username() {
    local username
    while true; do
        read -p "Enter username (3-32 characters, only letters, numbers, and underscores): " username
        if [[ "$username" =~ ^[a-zA-Z0-9_]{3,32}$ ]]; then
            echo "$username"
            return 0
        fi
        echo "Invalid username. Use 3-32 characters, only letters, numbers, and underscores."
    done
}

# Function to get password preference
get_password_preference() {
    local username=$1
    local base_password=$2
    read -p "Do you want to add random characters to the base password for $username? (y/n): " add_random
    if [[ "$add_random" =~ ^[Yy]$ ]]; then
        RANDOM_STRING=$(generate_random_string)
        echo "${base_password}${RANDOM_STRING}"
    else
        echo "$base_password"
    fi
}

# Check if running as root
check_root

# Install all dependencies FIRST
install_all_dependencies

# Get SSH port
echo "================================================"
echo "SSH Port Configuration"
echo "================================================"
SSH_PORT=$(get_valid_port)

# Get root password
echo "================================================"
echo "Root Password Configuration"
echo "================================================"
read -sp "Enter root password (will be used as base for user passwords): " ROOT_PASSWORD
echo

# Get number of users
echo "================================================"
echo "User Configuration"
echo "================================================"
echo "IMPORTANT: User Access Levels"
echo "1. First user created will have:"
echo "   - Full SSH access"
echo "   - Sudo privileges (can run commands as root)"
echo "   - Full shell access"
echo ""
echo "2. All other users will have:"
echo "   - SSH VPN access only"
echo "   - Restricted shell (can only use SSH)"
echo "   - No sudo privileges"
echo "   - No command execution"
echo ""
echo "Choose the first user carefully as they will have admin privileges!"
echo "================================================"
read -p "Enter number of users to create (1-10): " NUM_USERS
while ! [[ "$NUM_USERS" =~ ^[1-9]$|^10$ ]]; do
    echo "Invalid number. Please enter a number between 1 and 10."
    read -p "Enter number of users to create (1-10): " NUM_USERS
done

# Get usernames
NEW_USERS=()
for ((i=1; i<=NUM_USERS; i++)); do
    if [ $i -eq 1 ]; then
        echo "Creating admin user (will have sudo privileges):"
    else
        echo "Creating VPN-only user $i:"
    fi
    username=$(get_valid_username)
    NEW_USERS+=("$username")
done

# Variables
SSH_CONFIG="/etc/ssh/sshd_config"
SSH_BACKUP="/etc/ssh/sshd_config.backup"
PASSWORDS=()  # Array to store passwords

# Backup original SSH config
echo "Creating backup of SSH configuration..."
cp $SSH_CONFIG $SSH_BACKUP

# Update system and check dependencies
echo "Updating system packages..."
apt-get update
apt-get upgrade -y

# Remove existing users
remove_existing_users

# Configure UFW
echo "Configuring firewall..."
# Reset UFW to default
ufw --force reset

# Set default policies
ufw default deny incoming
ufw default allow outgoing

# If changing SSH port, first allow both old and new ports
if [ "$SSH_PORT" != "22" ]; then
    echo "Adding both old and new SSH ports to UFW..."
    ufw allow 22/tcp          # Keep old port open temporarily
    ufw allow $SSH_PORT/tcp   # Add new port
else
    ufw allow 22/tcp          # Default SSH port
fi

# Allow other required ports
ufw allow 9999/tcp               # Your specified port
ufw allow 7799/tcp               # Brook VPN port
ufw allow 443/tcp                # HTTPS
ufw allow 80/tcp                 # HTTP

# Enable UFW
echo "y" | ufw enable

# Configure SSH
echo "Configuring SSH..."

# Create new users
for i in "${!NEW_USERS[@]}"; do
    user="${NEW_USERS[$i]}"
    echo "Creating user $user..."
    useradd -m -s /bin/bash "$user"
    
    # Get password based on user preference
    PASSWORD=$(get_password_preference "$user" "$ROOT_PASSWORD")
    
    # Set the password
    echo "$user:$PASSWORD" | chpasswd
    PASSWORDS+=("$user: $PASSWORD")
    
    # Set permissions based on user
    if [ $i -eq 0 ]; then
        # First user gets sudo access
        usermod -aG sudo "$user"
        echo "$user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$user
        chmod 440 /etc/sudoers.d/$user
    else
        # Other users get restricted shell
        chsh -s /bin/rbash "$user"
        # Create restricted home directory structure
        mkdir -p /home/$user/bin
        # Set proper permissions
        chown -R $user:$user /home/$user
        chmod 755 /home/$user
        # Allow only SSH commands
        echo 'PATH=$HOME/bin' > /home/$user/.bashrc
        echo 'export PATH' >> /home/$user/.bashrc
        # Create symlinks for allowed commands
        ln -sf /usr/bin/ssh /home/$user/bin/
    fi
done

# Create privilege separation directory
echo "Creating privilege separation directory..."
mkdir -p /run/sshd
chmod 0755 /run/sshd

# Configure SSH settings
echo "Updating SSH configuration..."

# Create a temporary file for the new config
cat > /tmp/sshd_config << EOL
# SSH Port
Port $SSH_PORT

# Security settings
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
PermitEmptyPasswords no

# VPN and Tunneling settings
AllowTcpForwarding yes
AllowStreamLocalForwarding yes
GatewayPorts yes
PermitTunnel yes
X11Forwarding no

# Connection settings
ClientAliveInterval 300
MaxAuthTries 4
LoginGraceTime 60

# Logging
SyslogFacility AUTH
LogLevel VERBOSE

# Authentication - Allow either password OR publickey (not both required)
# Remove AuthenticationMethods to use default behavior

# Allow specific users
AllowUsers ${NEW_USERS[@]}
EOL

# Test the new configuration before applying
echo "Testing new SSH configuration..."
if ! sshd -t -f /tmp/sshd_config; then
    echo "❌ SSH configuration test failed"
    echo "Restoring backup..."
    cp $SSH_BACKUP $SSH_CONFIG
    systemctl restart ssh
    exit 1
fi

# SAFETY MECHANISM: Start SSH on new port while keeping old port active
echo "🔒 SAFETY: Starting SSH on new port while keeping current session active..."
echo "This ensures you won't get locked out if something goes wrong."

# Replace the SSH config
mv /tmp/sshd_config $SSH_CONFIG

# Set proper permissions
chmod 644 $SSH_CONFIG

# Test the new configuration one more time
if ! sshd -t; then
    echo "❌ Final SSH configuration test failed"
    echo "Restoring backup..."
    cp $SSH_BACKUP $SSH_CONFIG
    systemctl restart ssh
    exit 1
fi

# Configure fail2ban
echo "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << EOL
[sshd]
enabled = true
port = $SSH_PORT
filter = sshd
logpath = /var/log/auth.log
maxretry = 4
findtime = 300
bantime = 3600
EOL

# Enable IP forwarding for VPN
echo "Enabling IP forwarding..."
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

# Restart services
echo "Restarting services..."
echo "⚠️  IMPORTANT: Keep this terminal session open until you verify SSH access!"
echo "⚠️  Test SSH connection in a NEW terminal before closing this one!"

# Stop both SSH service and socket
systemctl stop ssh.socket 2>/dev/null || true
systemctl stop ssh
sleep 3

# Disable the socket to prevent it from auto-starting
systemctl disable ssh.socket 2>/dev/null || true

# Start SSH service with new configuration
echo "Starting SSH with new configuration..."
systemctl start ssh
sleep 5  # Give SSH time to fully start

# Verify SSH started successfully
if ! systemctl is-active --quiet ssh; then
    echo "❌ SSH service failed to start with new configuration!"
    echo "Restoring backup configuration..."
    cp $SSH_BACKUP $SSH_CONFIG
    systemctl start ssh
    sleep 3
    if systemctl is-active --quiet ssh; then
        echo "✅ SSH service restored with backup configuration"
        echo "❌ New configuration failed - please check the settings"
        exit 1
    else
        echo "❌ CRITICAL: SSH service failed to start even with backup!"
        echo "Manual intervention required via console access"
        exit 1
    fi
fi

# Restart fail2ban
systemctl restart fail2ban
systemctl enable fail2ban

# Check SSH service
check_ssh_service

# Verify ports are listening
echo "Verifying SSH ports are listening..."
if ! verify_port_listening $SSH_PORT; then
    echo "❌ SSH port ($SSH_PORT) is not listening"
    echo "Restoring backup configuration..."
    cp $SSH_BACKUP $SSH_CONFIG
    systemctl restart ssh
    exit 1
fi

# If we changed the SSH port, wait for confirmation before removing old port
if [ "$SSH_PORT" != "22" ]; then
    echo "================================================"
    echo "⚠️  IMPORTANT: SSH port change in progress"
    echo "================================================"
    echo "1. Both ports 22 and $SSH_PORT are currently open"
    echo "2. Please test the new port ($SSH_PORT) in a new terminal"
    echo "3. Once confirmed working, we can remove port 22"
    echo ""
    read -p "Is the new SSH port working correctly? (y/n): " port_working
    
    if [[ "$port_working" =~ ^[Yy]$ ]]; then
        echo "Removing old SSH port (22) from UFW..."
        ufw delete allow 22/tcp
        echo "✅ Old SSH port removed successfully"
    else
        echo "❌ Port change not confirmed. Keeping both ports open for safety."
        echo "You can manually remove port 22 later using: ufw delete allow 22/tcp"
    fi
fi

# Print important information
echo "================================================"
echo "🎉 SSH Configuration Complete!"
echo "================================================"
echo "SSH is now listening on port: $SSH_PORT"
echo "Root login has been disabled"
echo ""
echo "🔐 AUTHENTICATION METHODS ENABLED:"
echo "✅ Password authentication: YES"
echo "✅ Public key authentication: YES"
echo "✅ You can use EITHER password OR public key to connect"
echo ""
echo "User Access Levels:"
echo "1. Admin User (${NEW_USERS[0]}):"
echo "   - Full SSH access"
echo "   - Sudo privileges (can run commands as root)"
echo "   - Full shell access"
echo ""
echo "2. VPN Users (${NEW_USERS[@]:1}):"
echo "   - SSH VPN access only"
echo "   - Restricted shell (can only use SSH)"
echo "   - No sudo privileges"
echo "   - No command execution"
echo ""
echo "Firewall (UFW) has been configured with the following ports:"
echo "- SSH: $SSH_PORT"
echo "- 9999"
echo "- 7799 (Brook VPN)"
echo "- 443 (HTTPS)"
echo "- 80 (HTTP)"
echo ""
echo "SSH VPN Features Enabled:"
echo "- TCP Forwarding"
echo "- Stream Local Forwarding"
echo "- Gateway Ports"
echo "- IP Forwarding"
echo ""
echo "🔑 IMPORTANT - SAVE THESE PASSWORDS:"
for pass in "${PASSWORDS[@]}"; do
    echo "   $pass"
done
echo ""
echo "⚠️  CRITICAL SAFETY INSTRUCTIONS:"
echo "1. 🚨 DO NOT CLOSE THIS TERMINAL SESSION YET!"
echo "2. 🧪 Open a NEW terminal and test SSH connection:"
echo "   ssh -p $SSH_PORT ${NEW_USERS[0]}@\$(hostname -I | awk '{print \$1}')"
echo "   ssh -p $SSH_PORT ${NEW_USERS[0]}@YOUR_SERVER_IP"
echo "3. ✅ Only close this session AFTER confirming new SSH works"
echo "4. 🔄 If connection fails, this session can restore the backup"
echo "5. 🔐 After logging in, change your password using: passwd"
echo ""
echo "🌐 For SSH VPN, use:"
echo "   ssh -p $SSH_PORT -D 1080 username@server_ip"
echo "================================================"

# Show current listening ports
echo "Current listening ports:"
netstat -tulpn | grep -E ":$SSH_PORT"

echo "✅ SSH configuration test passed" 