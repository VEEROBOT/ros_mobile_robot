#!/bin/bash
set -e

echo "Detecting system architecture..."
ARCH=$(uname -m)
OS_CODENAME=$(lsb_release -cs)
echo "Architecture: $ARCH, Ubuntu codename: $OS_CODENAME"

# 1️⃣ Set Locale
echo "Setting locale..."
sudo apt update && sudo apt install -y locales curl gnupg lsb-release software-properties-common
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

# 2️⃣ Enable Universe Repository
sudo add-apt-repository -y universe

# 3️⃣ Add ROS 2 Jazzy Repository
echo "Adding ROS 2 Jazzy repository..."
ROS_APT_SOURCE_VERSION=$(curl -s https://api.github.com/repos/ros-infrastructure/ros-apt-source/releases/latest \
    | grep -F "tag_name" | awk -F\" '{print $4}')
curl -L -o /tmp/ros2-apt-source.deb "https://github.com/ros-infrastructure/ros-apt-source/releases/download/${ROS_APT_SOURCE_VERSION}/ros2-apt-source_${ROS_APT_SOURCE_VERSION}.${OS_CODENAME}_all.deb"
sudo dpkg -i /tmp/ros2-apt-source.deb
sudo apt update

# 4️⃣ Install ROS 2
echo "Installing ROS 2..."
sudo apt upgrade -y

if [[ "$ARCH" == "x86_64" ]]; then
    echo "Detected laptop/desktop (amd64). Installing full desktop version..."
    sudo apt install -y ros-jazzy-desktop ros-dev-tools python3-colcon-common-extensions python3-argcomplete
elif [[ "$ARCH" == "aarch64" || "$ARCH" == "armv7l" ]]; then
    echo "Detected Raspberry Pi (ARM). Installing minimal ros-base version..."
    sudo apt install -y ros-jazzy-ros-base python3-colcon-common-extensions python3-argcomplete
else
    echo "Unknown architecture $ARCH. Defaulting to ros-base."
    sudo apt install -y ros-jazzy-ros-base python3-colcon-common-extensions python3-argcomplete
fi

# 5️⃣ Source ROS 2 Environment
echo "Configuring environment..."
SHELLRC="$HOME/.bashrc"
if [[ -n "$ZSH_VERSION" ]]; then
    SHELLRC="$HOME/.zshrc"
fi
grep -qxF "source /opt/ros/jazzy/setup.bash" "$SHELLRC" || echo "source /opt/ros/jazzy/setup.bash" >> "$SHELLRC"
source /opt/ros/jazzy/setup.bash

echo "✅ ROS 2 Jazzy installation complete!"
echo "Please open a new terminal or run 'source $SHELLRC' to start using ROS 2."
