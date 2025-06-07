# Linux Swap Manager

A powerful Linux swap space management tool with a graphical menu interface, supporting swap file creation, deletion, monitoring, performance testing, and more.

## ✨ Features

- 🚀 Interactive menu interface with simple, intuitive operation
- 📊 Real-time monitoring of system memory and swap space usage
- 🛠 Create/delete swap files
- 📈 Memory stress testing
- ⚙️ Swappiness adjustment
- 🎨 Colorful output interface
- 🔒 Comprehensive error handling and safety checks

## 📥 Installation
Run as root user:
First-time installation:
```bash
wget -qO /usr/local/bin/swap https://raw.githubusercontent.com/heyuecock/swap_manage/refs/heads/main/swap_manager.sh && chmod +x /usr/local/bin/swap && swap
```

For subsequent runs, simply use:
```bash
swap
```

## 🗑️ Uninstallation

### Method 1: Using the program (recommended)
```bash
swap  # Select "Uninstall" option from the menu
```

### Method 2: Manual uninstallation
```bash
sudo swapoff /swapfile  # Deactivate swap file
sudo rm -f /swapfile    # Remove swap file
sudo sed -i '/\/swapfile/d' /etc/fstab  # Remove from fstab
sudo rm -f /usr/local/bin/swap  # Remove program
```

### Main Functions

1. **Create Swap File**
   - Custom size (100-5120MB)
   - Automatic disk space check
   - Automatic boot configuration
   - Secure permission settings

2. **Delete Swap File**
   - Safely deactivate and remove existing swap file
   - Automatic system configuration cleanup
   - Integrity checks

3. **View System Information**
   - Detailed memory usage
   - Swap space status
   - Disk usage
   - CPU load information

4. **Adjust Swap Parameters**
   - Temporary/permanent swappiness modification
   - Optimization suggestions
   - Immediate effect

5. **Stress Test**
   - Customizable duration and intensity
   - Real-time system monitoring
   - Automated test reports

## 💻 System Requirements

### Supported OS
- Ubuntu/Debian series
- CentOS/RHEL series
- Alpine Linux
- Arch Linux
- Other mainstream Linux distributions

### Dependencies
- Basic tools:
  - bc (basic calculator)
  - util-linux (system utilities)
- Optional tools:
  - stress/stress-ng (stress testing)

## ⚠️ Important Notes

- Alpine Linux users may need additional basic tools
- Some minimal installations may require extra dependencies
- Requires root or sudo privileges

1. **Security Warnings**
   - Backup important data before operations
   - Avoid stress testing in production environments

2. **Usage Recommendations**
   - Recommended swap size: 1-2x physical memory
   - Recommended swappiness: 10-60
   - Regular system monitoring

3. **Troubleshooting**
   - If creation fails, check disk space
   - If deletion fails, ensure swap file isn't in use
   - Stress testing may trigger OOM killer

## 🔧 FAQ

Q: Why is swap space needed?
A: Swap space extends physical memory, preventing system crashes from memory exhaustion.

Q: How to choose appropriate swap file size?
A: Typically 1-2x physical memory, but adjust based on actual usage.

Q: How to adjust swappiness?
A: Servers: 10-30, Desktop systems: 30-60.
