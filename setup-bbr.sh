#!/bin/bash
#
# =================================================================
#  BBR Network Optimization Setup
# =================================================================
#  This script enables and optimizes BBR congestion control
#  for better network performance, especially for VPN and SSH.
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

# Function to check if BBR is already enabled
check_bbr_enabled() {
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
        return 0
    else
        return 1
    fi
}

# Function to enable BBR
enable_bbr() {
    echo "Enabling BBR congestion control..."
    
    # Add BBR module to kernel modules
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    
    # Set BBR as default congestion control
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    
    # Apply changes
    sysctl -p
    
    # Verify BBR is enabled
    if check_bbr_enabled; then
        echo "✅ BBR successfully enabled"
    else
        echo "❌ Failed to enable BBR"
        exit 1
    fi
}

# Function to optimize network parameters
optimize_network() {
    echo "Optimizing network parameters..."
    
    # Add network optimizations to sysctl.conf
    cat >> /etc/sysctl.conf << EOL

# Network optimizations for better performance
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_rmem=4096 87380 16777216
net.ipv4.tcp_wmem=4096 65536 16777216
net.ipv4.tcp_mtu_probing=1
net.ipv4.tcp_fastopen=3
net.core.netdev_max_backlog=2500
net.ipv4.tcp_max_syn_backlog=8192
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30
net.ipv4.tcp_keepalive_time=1200
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=5
EOL

    # Apply changes
    sysctl -p
    
    echo "✅ Network parameters optimized"
}

# Function to verify Docker can use BBR
verify_docker_bbr() {
    echo "Verifying Docker can use BBR..."
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo "⚠️ Docker not found. Skipping Docker verification."
        return
    }
    
    # Create a test container to verify BBR
    echo "Testing BBR with Docker..."
    docker run --rm alpine sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"
    
    if [ $? -eq 0 ]; then
        echo "✅ Docker containers can use BBR"
    else
        echo "⚠️ Docker containers might not be able to use BBR"
        echo "This is normal if the container doesn't have the required kernel modules"
    fi
}

# Main execution
check_root

echo "================================================"
echo "🔧 BBR Network Optimization Setup"
echo "================================================"

# Check if BBR is already enabled
if check_bbr_enabled; then
    echo "✅ BBR is already enabled"
else
    enable_bbr
fi

# Optimize network parameters
optimize_network

# Verify Docker can use BBR
verify_docker_bbr

echo "================================================"
echo "🎉 BBR Setup Complete!"
echo "================================================"
echo "Your system is now optimized for better network performance."
echo "These optimizations will benefit:"
echo "  - SSH tunneling"
echo "  - Brook VPN services"
echo "  - General network performance"
echo ""
echo "Note: A system reboot is recommended for all changes to take full effect."
echo "================================================" 