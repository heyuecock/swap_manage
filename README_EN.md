# Swap Manager

English | [简体中文](README.md)

A powerful tool for managing swap space in Linux systems, providing a graphical menu interface with features for creating, deleting, monitoring, and performance testing of swap files.

## ✨ Features

- 🚀 Interactive menu interface, simple and intuitive operation
- 📊 Real-time monitoring of system memory and swap space usage
- 🛠 Support for creating/deleting swap files
- 📈 Memory stress testing functionality
- ⚙️ Swap tendency (swappiness) adjustment
- 🎨 Colorful output interface
- 🔒 Complete error handling and security checks

## 📥 Installation

### First-time installation:
```bash
wget -qO /usr/local/bin/swap https://raw.githubusercontent.com/heyuecock/swap_manage/refs/heads/main/swap_manager.sh && chmod +x /usr/local/bin/swap && swap
```

### Run again:
```bash
swap
```

## 🗑️ Uninstallation

### Method 1: Using the program (Recommended)
```bash
swap  # Enter the program and select "Uninstall Program" option
```

### Method 2: Manual uninstallation
```bash
sudo swapoff /swapfile  # Disable swap file
sudo rm -f /swapfile    # Delete swap file
sudo sed -i '/\/swapfile/d' /etc/fstab  # Remove configuration from fstab
sudo rm -f /usr/local/bin/swap  # Delete program
```

### Main Features

1. **Create Swap File**
   - Custom size support (100-5120MB)
   - Automatic disk space check
   - Automatic boot configuration
   - Secure permission settings

2. **Delete Swap File**
   - Safely disable and delete existing swap files
   - Automatic system configuration cleanup
   - Integrity check

3. **View System Information**
   - Detailed memory usage
   - Swap space status
   - Disk usage
   - CPU load information

4. **Adjust Swap Parameters**
   - Support for temporary/permanent swappiness modification
   - Optimization suggestions
   - Real-time effect

5. **Stress Testing**
   - Customizable test duration and intensity
   - Real-time system status monitoring
   - Automated test reports

## 💻 System Requirements

### Supported Operating Systems
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

## ⚠️ Notes
- Alpine Linux users may need to install additional basic tools
- Some minimal installations may require additional dependencies
- Root or sudo access required

1. **Security Warnings**
   - Backup important data before operations
   - Do not perform stress tests in production environment

2. **Usage Recommendations**
   - Recommended swap file size: 1-2 times physical memory
   - Recommended swappiness value: 10-60
   - Regular system status monitoring

3. **Troubleshooting**
   - If creation fails, check disk space
   - If deletion fails, ensure swap file is not in use
   - Stress testing may trigger OOM killer

## 🔧 FAQ

Q: Why do we need swap space?
A: Swap space serves as an extension of physical memory, preventing system crashes due to memory exhaustion.

Q: How to choose the appropriate swap file size?
A: Generally recommended to set it to 1-2 times the physical memory, but adjust according to actual usage.

Q: How to adjust the swappiness value?
A: Recommended setting for servers: 10-30, for desktop systems: 30-60. 
