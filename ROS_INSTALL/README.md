# ROS 2 Jazzy Installation Script

This script automatically installs **ROS 2 Jazzy Jalisco** on Ubuntu 24.04 (Noble) with intelligent architecture detection. It supports both desktop/laptop installations and Raspberry Pi deployments.

## 🚀 Features

- **Automatic Architecture Detection**: Installs appropriate ROS 2 packages based on system architecture
- **Non-Interactive Installation**: Fully automated with no user prompts
- **Locale Configuration**: Sets up UTF-8 locale for proper ROS functionality
- **Repository Management**: Adds universe repository and official ROS 2 sources
- **Environment Setup**: Automatically configures shell environment
- **Cross-Platform**: Supports x86_64 (desktop) and ARM (Raspberry Pi) architectures

## 📋 Requirements

- **Operating System**: Ubuntu 24.04 (Noble Numbat)
- **Architecture**: x86_64 (amd64), ARM64, or ARM 32-bit (armv7l/armhf)
- **Permissions**: `sudo` privileges required
- **Network**: Active internet connection
- **Storage**: At least 2GB free space
- **Memory**: 1GB+ RAM recommended for ARM devices (minimal packages used if less)

## 🛠 Installation Packages

The script intelligently selects packages based on architecture and available system resources:

| Architecture | RAM | Package Selection | Description |
|--------------|-----|------------------|-------------|
| x86_64 (Desktop/Laptop) | Any | `ros-jazzy-desktop` + `ros-dev-tools` | Full ROS 2 desktop with GUI tools and development tools |
| ARM64 (Raspberry Pi) | >1GB | `ros-jazzy-ros-base` + dev tools | Base ROS 2 with essential development packages |
| ARM64 (Raspberry Pi) | <1GB | `ros-jazzy-ros-base` (minimal) | Minimal ROS 2 base installation |
| ARM 32-bit (armv7l/armhf) | Any | `ros-jazzy-ros-base` (minimal) | Minimal ROS 2 base installation |

**Additional packages installed on all systems:**
- `python3-colcon-common-extensions`
- `python3-argcomplete`
- `python3-rosdep` (ARM64 with sufficient RAM only)

## 📖 Usage

### 1. Download and Make Executable

```bash
# Download the script
wget https://raw.githubusercontent.com/yourusername/ros2-install-script/main/install_ros2.sh

# Make it executable
chmod +x install_ros2.sh
```

### 2. Run the Installation

```bash
# Standard installation with all system checks
sudo ./install_ros2.sh

# Force installation (skip version and resource checks)
sudo ./install_ros2.sh --force

# Show help and available options
./install_ros2.sh --help
```

### 3. Command Line Options

| Option | Description |
|--------|-------------|
| `--force` | Skip Ubuntu version check and system resource requirements |
| `--help` | Display usage information and available options |

### 4. Activate Environment

The script automatically adds ROS 2 to your shell configuration. Either:

**Option A: Open a new terminal**
```bash
# New terminal will automatically source ROS 2
```

**Option B: Source manually in current terminal**
```bash
source ~/.bashrc
# or for zsh users:
source ~/.zshrc
```

## ✅ Verification

Test your installation with these commands:

```bash
# Check ROS 2 installation
ros2 --help

# Test with demo nodes (if desktop version installed)
ros2 run demo_nodes_cpp talker

# In another terminal:
ros2 run demo_nodes_cpp listener
```

## 🗑 Uninstallation

To completely remove ROS 2 Jazzy:

```bash
# Remove ROS 2 packages
sudo apt remove ~nros-jazzy-* && sudo apt autoremove

# Remove repository source
sudo apt remove ros2-apt-source

# Clean up system
sudo apt update && sudo apt autoremove && sudo apt upgrade

# Manually remove the source line from ~/.bashrc or ~/.zshrc
sed -i '/source \/opt\/ros\/jazzy\/setup.bash/d' ~/.bashrc
```

## 🔧 Script Details

The script performs these steps:

1. **Command Line Parsing**: Processes `--force` and `--help` options
2. **System Detection**: Identifies architecture and Ubuntu codename
3. **Resource Checking**: Validates disk space (2GB+) and RAM (1GB+ for ARM)
4. **Locale Setup**: Configures UTF-8 locale for international support
5. **Repository Addition**: Enables universe repository and adds ROS 2 sources with caching
6. **Smart Package Selection**: Chooses appropriate packages based on system capabilities
7. **Environment Configuration**: Adds ROS 2 sourcing to shell configuration

## 🐛 Troubleshooting

### Common Issues

**Issue**: `This script requires Ubuntu 24.04 (noble)`
```bash
# Solution: Use force flag to override version check
sudo ./install_ros2.sh --force
```

**Issue**: `Insufficient disk space. Need at least 2GB`
```bash
# Solution: Free up space or use force flag
sudo ./install_ros2.sh --force
```

**Issue**: `locale: Cannot set LC_ALL to default locale`
```bash
# Solution: Run locale configuration manually
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
```

**Issue**: `ros2: command not found`
```bash
# Solution: Source the setup file or restart terminal
source /opt/ros/jazzy/setup.bash
# Or restart your terminal
```

**Issue**: Permission denied
```bash
# Solution: Ensure script has execute permissions
chmod +x install_ros2.sh
```

### Low Resource Systems

For Raspberry Pi or systems with limited resources:
- Script automatically detects low RAM and installs minimal packages
- Use `--force` to override resource checks if needed
- Consider using external storage for ROS workspaces

## 📝 Notes

- The script includes strict error handling with `set -e` and `set -o pipefail`
- System packages are updated (`apt update && apt upgrade`) before ROS 2 installation
- All repository additions and package installations use non-interactive flags
- Compatible with both Bash and Zsh shells
- Download caching reduces bandwidth usage on repeated runs
- Resource checking prevents installation failures on constrained systems
- Designed for fresh Ubuntu 24.04 installations but works on existing systems
- Internet connection required throughout installation

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Commit your changes (`git commit -am 'Add some improvement'`)
4. Push to the branch (`git push origin feature/improvement`)
5. Create a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏷 Version

- **Script Version**: 1.1.0
- **ROS 2 Version**: Jazzy Jalisco
- **Target OS**: Ubuntu 24.04 (Noble)
- **Last Updated**: September 2025

## 🔄 Changelog

### v1.1.0
- Added `--force` and `--help` command line options
- Implemented system resource checking (disk space and RAM)
- Added intelligent package selection based on available resources
- Improved .deb version validation with proper control file parsing
- Enhanced download caching system
- Added `set -o pipefail` for stricter error handling
- Expanded ARM architecture support (armhf)

### v1.0.0
- Initial release with basic architecture detection
- Support for x86_64 and ARM64 architectures
- Automatic environment configuration
