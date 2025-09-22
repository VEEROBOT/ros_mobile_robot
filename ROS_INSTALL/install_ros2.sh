#!/bin/bash

# ROS 2 Jazzy Installation Script for Ubuntu 24.04
# Automatically detects architecture and installs appropriate ROS 2 packages
# Author: [Your Name]
# Version: 1.1.0

set -e          # Exit on any error
set -o pipefail # Exit on pipe failures

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration options
STRICT_VERSION_CHECK=true  # Set to false to allow other Ubuntu versions
ENABLE_CACHING=true        # Set to false to always download fresh packages
MIN_FREE_SPACE_GB=2       # Minimum free space required (GB)
MIN_RAM_MB=1024           # Minimum RAM for full packages on ARM (MB)

# Parse command line arguments
FORCE_INSTALL=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE_INSTALL=true
            STRICT_VERSION_CHECK=false
            log_info "Force mode enabled - skipping strict checks"
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --force    Skip strict version checks and system requirements"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Get the actual user (not root when using sudo)
ACTUAL_USER=${SUDO_USER:-$(whoami)}
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

# Function to check system resources
check_system_resources() {
    local arch=$1
    
    # Check disk space
    local free_space_kb=$(df / | awk 'NR==2 {print $4}')
    local free_space_gb=$((free_space_kb / 1024 / 1024))
    
    log_info "Available disk space: ${free_space_gb}GB"
    
    if [[ $free_space_gb -lt $MIN_FREE_SPACE_GB ]] && [[ "$FORCE_INSTALL" != "true" ]]; then
        log_error "Insufficient disk space. Need at least ${MIN_FREE_SPACE_GB}GB, have ${free_space_gb}GB"
        log_error "Use --force to override this check"
        exit 1
    fi
    
    # Check RAM for ARM devices
    if [[ "$arch" == "aarch64" || "$arch" == "armv7l" || "$arch" == "armhf" ]]; then
        local total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local total_ram_mb=$((total_ram_kb / 1024))
        
        log_info "Available RAM: ${total_ram_mb}MB"
        
        # Suggest minimal installation for low-RAM ARM devices
        if [[ $total_ram_mb -lt $MIN_RAM_MB ]]; then
            log_warning "Low RAM detected (${total_ram_mb}MB < ${MIN_RAM_MB}MB)"
            log_warning "Recommending minimal installation for better performance"
            return 1  # Signal to use minimal packages
        fi
    fi
    
    return 0  # OK to proceed with standard packages
}

log_info "Starting ROS 2 Jazzy installation..."
log_info "Target user: $ACTUAL_USER"
log_info "User home: $ACTUAL_HOME"

# Step 1: Detect system information
log_info "Detecting system architecture..."
ARCH=$(uname -m)
OS_CODENAME=$(lsb_release -cs)
OS_VERSION=$(lsb_release -rs)

log_info "Architecture: $ARCH"
log_info "Ubuntu codename: $OS_CODENAME"
log_info "Ubuntu version: $OS_VERSION"

# Verify Ubuntu 24.04
if [[ "$OS_CODENAME" != "noble" ]]; then
    if [[ "$STRICT_VERSION_CHECK" == "true" ]]; then
        log_error "This script requires Ubuntu 24.04 (noble). You're running $OS_CODENAME."
        log_error "Set STRICT_VERSION_CHECK=false in the script to override this check."
        exit 1
    else
        log_warning "This script is designed for Ubuntu 24.04 (noble). You're running $OS_CODENAME."
        log_warning "Proceeding anyway, but compatibility is not guaranteed."
    fi
fi

# Step 2: Set Locale
log_info "Configuring system locale..."
apt update -qq
DEBIAN_FRONTEND=noninteractive apt install -y locales curl gnupg lsb-release software-properties-common

# Generate locales
locale-gen en_US en_US.UTF-8
update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

log_success "Locale configured successfully"

# Step 3: Enable Universe Repository
log_info "Enabling universe repository..."
add-apt-repository -y universe

# Function to get installed package version from .deb file
get_deb_version() {
    local deb_file=$1
    if [[ -f "$deb_file" ]]; then
        dpkg-deb -f "$deb_file" Version 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Step 4: Add ROS 2 Jazzy Repository
log_info "Adding ROS 2 Jazzy repository..."

# Check if we can use cached version
ROS_DEB_PATH="/tmp/ros2-apt-source.deb"
NEED_DOWNLOAD=true

if [[ "$ENABLE_CACHING" == "true" && -f "$ROS_DEB_PATH" ]]; then
    log_info "Found cached ros-apt-source package, verifying version..."
    
    # Get latest version from GitHub
    LATEST_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
        | grep -F "tag_name" | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    
    # Get version from cached .deb file
    CACHED_VERSION=$(get_deb_version "$ROS_DEB_PATH")
    
    if [[ -n "$LATEST_VERSION" && -n "$CACHED_VERSION" && "$CACHED_VERSION" == "$LATEST_VERSION" ]]; then
        log_info "Using cached version: $CACHED_VERSION (matches latest)"
        NEED_DOWNLOAD=false
    else
        log_info "Cached version ($CACHED_VERSION) != latest ($LATEST_VERSION), will download"
    fi
fi

if [[ "$NEED_DOWNLOAD" == "true" ]]; then
    # Get latest ros-apt-source version
    log_info "Fetching latest ros-apt-source version..."
    ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
        | grep -F "tag_name" | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

    if [[ -z "$ROS_APT_SOURCE_VERSION" ]]; then
        log_error "Failed to fetch ros-apt-source version"
        exit 1
    fi

    log_info "Downloading ros-apt-source version: $ROS_APT_SOURCE_VERSION"

    # Download ros-apt-source
    curl -L -o "$ROS_DEB_PATH" \
        "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${OS_CODENAME}_all.deb"

    if [[ ! -f "$ROS_DEB_PATH" ]]; then
        log_error "Failed to download ros-apt-source package"
        exit 1
    fi
fi

# Install ros-apt-source
log_info "Installing ros-apt-source package..."
if ! dpkg -i "$ROS_DEB_PATH"; then
    log_error "Failed to install ros-apt-source package"
    exit 1
fi

# Single comprehensive apt update after adding repository
log_info "Updating package lists..."
apt update -qq

log_success "ROS 2 repository added successfully"

# Step 5: System upgrade
log_info "Upgrading system packages..."
DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Step 6: Check system resources and install ROS 2 based on architecture
log_info "Checking system resources..."
SYSTEM_OK=true
if ! check_system_resources "$ARCH"; then
    SYSTEM_OK=false
fi

log_info "Installing ROS 2 packages based on architecture and system capabilities..."

case "$ARCH" in
    x86_64)
        log_info "Detected x86_64 architecture. Installing full desktop version..."
        PACKAGES="ros-jazzy-desktop ros-dev-tools python3-colcon-common-extensions python3-argcomplete"
        ;;
    aarch64)
        if [[ "$SYSTEM_OK" == "true" ]]; then
            log_info "Detected ARM64 architecture with sufficient resources. Installing base + dev tools..."
            PACKAGES="ros-jazzy-ros-base python3-colcon-common-extensions python3-argcomplete python3-rosdep"
        else
            log_info "Detected ARM64 architecture with limited resources. Installing minimal version..."
            PACKAGES="ros-jazzy-ros-base python3-colcon-common-extensions python3-argcomplete"
        fi
        ;;
    armv7l|armhf)
        log_info "Detected ARM 32-bit architecture ($ARCH). Installing minimal ros-base version..."
        # Always use minimal packages on 32-bit ARM
        PACKAGES="ros-jazzy-ros-base python3-colcon-common-extensions python3-argcomplete"
        ;;
    *)
        log_warning "Unknown architecture: $ARCH. Defaulting to minimal ros-base installation."
        PACKAGES="ros-jazzy-ros-base python3-colcon-common-extensions python3-argcomplete"
        ;;
esac

log_info "Installing packages: $PACKAGES"
DEBIAN_FRONTEND=noninteractive apt install -y $PACKAGES

log_success "ROS 2 packages installed successfully"

# Step 6.5: Initialize rosdep
log_info "Checking rosdep..."
if ! command -v rosdep &> /dev/null; then
    log_info "Installing python3-rosdep..."
    DEBIAN_FRONTEND=noninteractive apt install -y python3-rosdep
fi

# Initialize rosdep if needed
if ! rosdep update &> /dev/null; then
    log_info "Initializing rosdep..."
    rosdep init
    rosdep update
fi
log_success "rosdep ready"

# Step 7: Configure environment for the actual user
log_info "Configuring ROS 2 environment..."

# Determine shell configuration file
if [[ -f "$ACTUAL_HOME/.zshrc" ]] && [[ -n "$ZSH_VERSION" ]]; then
    SHELLRC="$ACTUAL_HOME/.zshrc"
    SHELL_NAME="zsh"
else
    SHELLRC="$ACTUAL_HOME/.bashrc"
    SHELL_NAME="bash"
fi

log_info "Configuring $SHELL_NAME environment in: $SHELLRC"

# Add ROS 2 sourcing to shell configuration if not already present
ROS_SOURCE_LINE="source /opt/ros/jazzy/setup.bash"
if ! grep -qxF "$ROS_SOURCE_LINE" "$SHELLRC"; then
    echo "" >> "$SHELLRC"
    echo "# ROS 2 Jazzy setup" >> "$SHELLRC"
    echo "$ROS_SOURCE_LINE" >> "$SHELLRC"
    log_success "Added ROS 2 sourcing to $SHELLRC"
else
    log_info "ROS 2 sourcing already present in $SHELLRC"
fi

# Ensure correct ownership of configuration files
chown $ACTUAL_USER:$ACTUAL_USER "$SHELLRC"

# Source ROS 2 in current environment
source /opt/ros/jazzy/setup.bash

# Step 8: Cleanup
log_info "Cleaning up temporary files..."
if [[ "$ENABLE_CACHING" != "true" ]]; then
    rm -f "$ROS_DEB_PATH"
    log_info "Removed temporary download file"
else
    log_info "Keeping cached file for future use: $ROS_DEB_PATH"
fi

# Step 9: Verify installation
log_info "Verifying installation..."
if command -v ros2 &> /dev/null; then
    ROS2_VERSION=$(ros2 --version 2>/dev/null || echo "Version check failed")
    log_success "ROS 2 command available: $ROS2_VERSION"
else
    log_warning "ROS 2 command not immediately available (may require new shell session)"
fi

# Final success message
echo ""
echo "🎉 ROS 2 Jazzy installation completed successfully!"
echo ""
echo "📋 Installation Summary:"
echo "   • Architecture: $ARCH"
echo "   • Packages: $PACKAGES"
echo "   • Shell config: $SHELLRC"
echo ""
echo "🚀 Next steps:"
echo "   1. Open a new terminal session, or run:"
echo "      source $SHELLRC"
echo ""
echo "   2. Test your installation:"
echo "      ros2 --help"
if [[ "$ARCH" == "x86_64" ]]; then
echo ""
echo "   3. Try demo nodes (desktop version only):"
echo "      ros2 run demo_nodes_cpp talker"
fi
echo ""
echo "💡 Usage tips:"
echo "   • Run with --force to skip system checks"
echo "   • Run with --help to see all options"
echo ""
echo "📚 Documentation: https://docs.ros.org/en/jazzy/"
echo ""

log_success "Installation script completed successfully!"
