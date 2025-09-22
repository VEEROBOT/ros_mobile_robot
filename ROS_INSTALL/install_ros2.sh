#!/bin/bash

# ROS 2 Jazzy Installation Script for Ubuntu 24.04
# Automatically detects architecture and installs appropriate ROS 2 packages
# Author: [Your Name]
# Version: 1.0.0

set -e  # Exit on any error

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

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Get the actual user (not root when using sudo)
ACTUAL_USER=${SUDO_USER:-$(whoami)}
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

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
    log_warning "This script is designed for Ubuntu 24.04 (noble). You're running $OS_CODENAME."
    log_warning "Proceeding anyway, but compatibility is not guaranteed."
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

# Step 4: Add ROS 2 Jazzy Repository
log_info "Adding ROS 2 Jazzy repository..."

# Get latest ros-apt-source version
log_info "Fetching latest ros-apt-source version..."
ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
    | grep -F "tag_name" | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')

if [[ -z "$ROS_APT_SOURCE_VERSION" ]]; then
    log_error "Failed to fetch ros-apt-source version"
    exit 1
fi

log_info "Using ros-apt-source version: $ROS_APT_SOURCE_VERSION"

# Download and install ros-apt-source
curl -L -o /tmp/ros2-apt-source.deb \
    "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${OS_CODENAME}_all.deb"

if [[ ! -f "/tmp/ros2-apt-source.deb" ]]; then
    log_error "Failed to download ros-apt-source package"
    exit 1
fi

dpkg -i /tmp/ros2-apt-source.deb
apt update -qq

log_success "ROS 2 repository added successfully"

# Step 5: System upgrade
log_info "Upgrading system packages..."
DEBIAN_FRONTEND=noninteractive apt upgrade -y

# Step 6: Install ROS 2 based on architecture
log_info "Installing ROS 2 packages based on architecture..."

case "$ARCH" in
    x86_64)
        log_info "Detected x86_64 architecture. Installing full desktop version..."
        PACKAGES="ros-jazzy-desktop ros-dev-tools python3-colcon-common-extensions python3-argcomplete"
        ;;
    aarch64|armv7l)
        log_info "Detected ARM architecture ($ARCH). Installing minimal ros-base version..."
        PACKAGES="ros-jazzy-ros-base python3-colcon-common-extensions python3-argcomplete"
        ;;
    *)
        log_warning "Unknown architecture: $ARCH. Defaulting to ros-base installation."
        PACKAGES="ros-jazzy-ros-base python3-colcon-common-extensions python3-argcomplete"
        ;;
esac

log_info "Installing packages: $PACKAGES"
DEBIAN_FRONTEND=noninteractive apt install -y $PACKAGES

log_success "ROS 2 packages installed successfully"

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
rm -f /tmp/ros2-apt-source.deb

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
echo "📚 Documentation: https://docs.ros.org/en/jazzy/"
echo ""

log_success "Installation script completed successfully!"
