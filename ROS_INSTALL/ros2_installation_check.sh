#!/bin/bash

# Optimized ROS 2 Jazzy Installation Check Script
echo "🚀 ROS 2 Jazzy Installation Check"
echo "=================================="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

check_pass() { echo -e "✅ ${GREEN}$1${NC}"; }
check_fail() { echo -e "❌ ${RED}$1${NC}"; }
check_warn() { echo -e "⚠️  ${YELLOW}$1${NC}"; }
check_info() { echo -e "ℹ️  ${BLUE}$1${NC}"; }

# Cache installed ROS packages once to speed up checks
INSTALLED_ROS_PACKAGES=$(dpkg -l | grep "ros-jazzy" | awk '{print $2}')

pkg_installed() {
    local pkg="$1"
    echo "$INSTALLED_ROS_PACKAGES" | grep -qx "$pkg"
}

# 1. BASIC ROS 2 CHECK
echo -e "\n${BLUE}1. Basic ROS 2 Status${NC}"
echo "====================="
if command -v ros2 &> /dev/null; then
    check_pass "ROS 2 command available"
    if [[ -n "$ROS_DISTRO" ]]; then
        check_pass "ROS_DISTRO: $ROS_DISTRO"
    else
        check_fail "ROS_DISTRO not set - run: source /opt/ros/jazzy/setup.bash"
    fi
else
    check_fail "ROS 2 command not found"
fi

# Auto-sourcing check
if grep -q "ros/jazzy" ~/.bashrc ~/.zshrc 2>/dev/null; then
    check_pass "Auto-sourcing configured"
else
    check_fail "Auto-sourcing not set - add to ~/.bashrc: source /opt/ros/jazzy/setup.bash"
fi

# 2. CORE PACKAGES CHECK
echo -e "\n${BLUE}2. Core Packages${NC}"
echo "=================="
CORE_PACKAGES=(
    "ros-jazzy-ros-base:ROS Base"
    "ros-jazzy-desktop:ROS Desktop"
    "ros-dev-tools:Development Tools"
    "python3-colcon-common-extensions:Colcon Build Tool"
    "python3-argcomplete:Tab Completion"
)

for pkg_info in "${CORE_PACKAGES[@]}"; do
    IFS=':' read -r pkg desc <<< "$pkg_info"
    # Use cached data for ROS packages, dpkg for system packages
    if [[ "$pkg" == ros-jazzy-* ]]; then
        if pkg_installed "$pkg"; then
            check_pass "$desc ($pkg)"
        else
            check_warn "$desc ($pkg) - not installed"
        fi
    else
        if dpkg -l | grep -q "^ii.*$pkg "; then
            check_pass "$desc ($pkg)"
        else
            check_warn "$desc ($pkg) - not installed"
        fi
    fi
done

# 3. DEVELOPMENT TOOLS
echo -e "\n${BLUE}3. Development Tools${NC}"
echo "===================="
DEV_PACKAGES=(
    "python3-rosdep:Dependency Manager"
    "python3-vcstool:Version Control Tool"
    "python3-vcstools:VCS Tools"
)

for pkg_info in "${DEV_PACKAGES[@]}"; do
    IFS=':' read -r pkg desc <<< "$pkg_info"
    if dpkg -l | grep -q "^ii.*$pkg "; then
        check_pass "$desc ($pkg)"
    else
        check_fail "$desc ($pkg) - MISSING"
        echo "   Install: sudo apt install $pkg"
    fi
done

# rosdep check
if command -v rosdep &> /dev/null; then
    if rosdep update &> /dev/null; then
        check_pass "rosdep functional"
    else
        check_warn "rosdep update failed - run: sudo rosdep init && rosdep update"
    fi
fi

# 4. DEMO AND TEST PACKAGES
echo -e "\n${BLUE}4. Demo & Test Packages${NC}"
echo "======================="
DEMO_PACKAGES=(
    "ros-jazzy-demo-nodes-cpp:C++ Demo Nodes"
    "ros-jazzy-demo-nodes-py:Python Demo Nodes"
    "ros-jazzy-turtlesim:Turtle Simulator"
    "ros-jazzy-example-interfaces:Example Messages"
)

for pkg_info in "${DEMO_PACKAGES[@]}"; do
    IFS=':' read -r pkg desc <<< "$pkg_info"
    if pkg_installed "$pkg"; then
        check_pass "$desc ($pkg)"
    else
        check_warn "$desc ($pkg) - not installed"
        echo "   Install: sudo apt install $pkg"
    fi
done

# 5. VISUALIZATION TOOLS
echo -e "\n${BLUE}5. Visualization Tools${NC}"
echo "======================"
ARCH=$(uname -m)

# Check if we have GUI environment
if [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]] || [[ "$ARCH" == "x86_64" ]]; then
    GUI_AVAILABLE=true
    check_info "GUI environment detected - checking visualization tools"
else
    GUI_AVAILABLE=false
    check_info "Headless/Lite system detected - visualization tools optional"
fi

VIZ_PACKAGES=(
    "ros-jazzy-rviz2:3D Visualization"
    "ros-jazzy-rqt:Qt-based Tools"
    "ros-jazzy-rqt-common-plugins:RQT Plugins"
    "ros-jazzy-rqt-graph:Node Graph Viewer"
    "ros-jazzy-rqt-console:Log Viewer"
)

for pkg_info in "${VIZ_PACKAGES[@]}"; do
    IFS=':' read -r pkg desc <<< "$pkg_info"
    if dpkg -l | grep -q "^ii.*$pkg "; then
        check_pass "$desc ($pkg)"
    else
        if [[ "$GUI_AVAILABLE" == "true" ]]; then
            check_warn "$desc ($pkg) - not installed"
            echo "   Install: sudo apt install $pkg"
        else
            check_info "$desc ($pkg) - not needed on headless system"
        fi
    fi
done

# 6. FUNCTIONAL TESTS
echo -e "\n${BLUE}6. Functional Tests${NC}"
echo "==================="

# Test basic ROS 2 functionality
if command -v ros2 &> /dev/null && [[ -n "$ROS_DISTRO" ]]; then
    if ros2 pkg list &> /dev/null; then
        PKG_COUNT=$(ros2 pkg list | wc -l)
        check_pass "Package discovery working ($PKG_COUNT packages)"
    else
        check_fail "Package discovery not working"
    fi
    
    if ros2 topic list &> /dev/null; then
        check_pass "Topic listing working"
    else
        check_fail "Topic listing not working"
    fi
else
    check_fail "Cannot run functional tests - ROS 2 not properly sourced"
fi

# 7. INSTALLATION SUMMARY
echo -e "\n${BLUE}7. Installation Summary${NC}"
echo "======================="
TOTAL_ROS_PACKAGES=$(dpkg -l | grep "ros-jazzy" | wc -l)
check_info "Total ROS 2 packages installed: $TOTAL_ROS_PACKAGES"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)
        if dpkg -l | grep -q "ros-jazzy-desktop"; then
            check_pass "Desktop installation detected (x86_64) - Full featured"
        elif dpkg -l | grep -q "ros-jazzy-ros-base"; then
            check_warn "Base installation only (consider ros-jazzy-desktop for GUI tools)"
        fi
        ;;
    aarch64)
        if dpkg -l | grep -q "ros-jazzy-desktop"; then
            check_pass "Desktop installation on ARM64 - Full featured"
        else
            check_pass "Base installation on ARM64 - Optimized for resources"
        fi
        ;;
    armv7l|armhf)
        check_pass "ARM 32-bit installation - Minimal packages recommended"
        if dpkg -l | grep -q "ros-jazzy-desktop"; then
            check_warn "Desktop packages on 32-bit ARM may impact performance"
        fi
        ;;
    *)
        check_info "Architecture: $ARCH"
        ;;
esac

# System type detection
if [[ -z "$DISPLAY" ]] && [[ -z "$WAYLAND_DISPLAY" ]] && [[ "$ARCH" != "x86_64" ]]; then
    check_info "Headless system detected - command-line ROS development setup"
else
    check_info "GUI system detected - full ROS development environment"
fi

# 8. QUICK TESTS TO RUN
echo -e "\n${BLUE}8. Quick Test Commands${NC}"
echo "======================"
echo "Copy and run these tests:"
echo ""

if dpkg -l | grep -q "ros-jazzy-demo-nodes-cpp"; then
    echo "# Test demo nodes:"
    echo "ros2 run demo_nodes_cpp talker"
    echo "# (In another terminal) ros2 run demo_nodes_cpp listener"
    echo ""
fi

if dpkg -l | grep -q "ros-jazzy-turtlesim"; then
    echo "# Test turtlesim:"
    echo "ros2 run turtlesim turtlesim_node"
    echo "# (In another terminal) ros2 run turtlesim turtle_teleop_key"
    echo ""
fi

if dpkg -l | grep -q "ros-jazzy-rviz2" && [[ "$GUI_AVAILABLE" == "true" ]]; then
    echo "# Test visualization:"
    echo "rviz2"
    echo ""
fi

if dpkg -l | grep -q "ros-jazzy-rqt" && [[ "$GUI_AVAILABLE" == "true" ]]; then
    echo "# Test RQT tools:"
    echo "rqt"
    echo "rqt_graph"
    echo "rqt_console"
    echo ""
fi

echo "# Basic ROS 2 commands:"
echo "ros2 topic list"
echo "ros2 node list"
echo "ros2 pkg list"

# 9. TROUBLESHOOTING TIPS
echo -e "\n${BLUE}9. Common Issues & Fixes${NC}"
echo "========================"
echo "❓ ROS 2 command not found:"
echo "   → source /opt/ros/jazzy/setup.bash"
echo ""
echo "❓ Commands work in current terminal but not new ones:"
echo "   → Add to ~/.bashrc: source /opt/ros/jazzy/setup.bash"
echo ""
echo "❓ Package not found errors:"
echo "   → sudo apt update && sudo apt install <package-name>"
echo ""
echo "❓ Permission errors:"
echo "   → Check sudo privileges, run rosdep with proper permissions"

echo -e "\n🎉 ${GREEN}Check completed!${NC}"
echo "📚 ROS 2 Documentation: https://docs.ros.org/en/jazzy/"
