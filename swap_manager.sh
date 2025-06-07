#!/bin/bash

# Define colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No color

# Check if the user is root; if not, try using sudo or prompt to use root
if [ "$EUID" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo "$0" "$@"
    else
        echo -e "${YELLOW}Sudo not detected.${NC}"
        echo -e "${BLUE}On Alpine Linux, please use the following command:${NC}"
        echo -e "${GREEN}su -c 'wget -qO /usr/local/bin/swap https://raw.githubusercontent.com/heyuecock/swap_manage/refs/heads/main/swap_manager.sh && chmod +x /usr/local/bin/swap'${NC}"
        echo -e "${BLUE}Then run with the following command:${NC}"
        echo -e "${GREEN}su -c swap${NC}"
        exit 1
    fi
fi

# Check and install necessary dependencies
check_dependencies() {
    # Check package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        INSTALL_CMD="apt-get install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        INSTALL_CMD="yum install -y"
    elif command -v apk &> /dev/null; then
        PKG_MANAGER="apk"
        INSTALL_CMD="apk add"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
        INSTALL_CMD="pacman -S --noconfirm"
    else
        echo -e "${RED}✗ Unable to identify system's package manager.${NC}"
        exit 1
    fi

    # Check and install basic tools
    MISSING_TOOLS=()
    
    # Check basic tools
    for tool in bc swapon mkswap free df; do
        if ! command -v $tool &> /dev/null; then
            case $PKG_MANAGER in
                "apt-get"|"yum") 
                    if [[ "$tool" == "bc" ]]; then
                        MISSING_TOOLS+=("bc")
                    else
                        MISSING_TOOLS+=("util-linux")
                    fi
                    ;;
                "apk") 
                    if [[ "$tool" == "bc" ]]; then
                        MISSING_TOOLS+=("bc")
                    else
                        MISSING_TOOLS+=("util-linux-misc")
                    fi
                    ;;
                "pacman")
                    if [[ "$tool" == "bc" ]]; then
                        MISSING_TOOLS+=("bc")
                    else
                        MISSING_TOOLS+=("util-linux")
                    fi
                    ;;
            esac
        fi
    done

    # Install missing basic tools
    if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
        echo -e "${YELLOW}Installing necessary tools: ${MISSING_TOOLS[*]}${NC}"
        if [ "$PKG_MANAGER" = "apk" ]; then
            if ! $INSTALL_CMD "${MISSING_TOOLS[@]}"; then
                echo -e "${RED}✗ Tool installation failed. Please manually install the following packages: ${MISSING_TOOLS[*]}${NC}"
                exit 1
            fi
        else
            if ! sudo $INSTALL_CMD "${MISSING_TOOLS[@]}"; then
                echo -e "${RED}✗ Tool installation failed. Please manually install the following packages: ${MISSING_TOOLS[*]}${NC}"
                exit 1
            fi
        fi
    fi
}

# System compatibility check
check_system_compatibility() {
    # Check if swap is supported
    if ! grep -q "SwapTotal" /proc/meminfo; then
        echo -e "${RED}✗ This system may not support swap functionality.${NC}"
        exit 1
    fi

    # Special handling for Alpine Linux
    if [ -f /etc/alpine-release ]; then
        echo -e "${YELLOW}Detected Alpine Linux system.${NC}"
        
        # Check necessary packages
        MISSING_PKGS=()
        for pkg in sudo wget bash util-linux-misc bc; do
            if ! command -v $pkg >/dev/null 2>&1; then
                MISSING_PKGS+=($pkg)
            fi
        done
        
        if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
            echo -e "${YELLOW}Missing necessary packages: ${MISSING_PKGS[*]}${NC}"
            echo -e "${BLUE}Attempting to install necessary packages automatically...${NC}"
            
            # Try installing directly with apk
            if apk add ${MISSING_PKGS[*]}; then
                echo -e "${GREEN}✓ Necessary packages installed successfully${NC}"
            else
                echo -e "${RED}✗ Package installation failed. Please manually run the following command:${NC}"
                echo -e "apk add ${MISSING_PKGS[*]}"
                exit 1
            fi
        fi

        # Check necessary kernel modules
        if ! grep -q "swap" /proc/modules; then
            echo -e "${YELLOW}Loading swap kernel module...${NC}"
            modprobe swap
        fi
    fi

    # Check filesystem support
    if ! touch /.swap_test_file 2>/dev/null; then
        echo -e "${RED}✗ Root filesystem does not support file creation. Please check filesystem permissions.${NC}"
        exit 1
    fi
    rm -f /.swap_test_file
}

# Call at main program start
check_system_compatibility
check_dependencies

# Check if system supports swap files
if ! swapon --version &>/dev/null; then
    echo -e "${RED}✗ The system does not support swapon command, cannot create swap file.${NC}"
    exit 1
fi

# Menu function (with colors)
show_menu() {
    echo -e "\n${BLUE}========== Swap File Management Menu ==========${NC}"
    echo -e "${GREEN}1. Create swap file${NC}"
    echo -e "${GREEN}2. Delete swap file${NC}"
    echo -e "${GREEN}3. View current swap space info${NC}"
    echo -e "${GREEN}4. Adjust swappiness${NC}"
    echo -e "${GREEN}5. Memory stress test${NC}"
    echo -e "${RED}6. Uninstall program${NC}"
    echo -e "${RED}7. Exit${NC}"
    echo -e "${BLUE}===============================================${NC}\n"
}

# Create swap file
create_swap() {
    while true; do
        read -p "Please enter swap file size (unit: MB, range: 100-5120, default 1024MB):" SWAP_SIZE
        SWAP_SIZE=${SWAP_SIZE:-1024}  # Default to 1024MB if no input
        
        # Validate input
        if [[ $SWAP_SIZE =~ ^[0-9]+$ ]]; then
            if (( SWAP_SIZE >= 100 && SWAP_SIZE <= 5120 )); then
                break
            fi
        fi
        echo -e "${YELLOW}⚠️ Invalid input, please enter an integer between 100 and 5120.${NC}"
    done

    # Check disk space availability (in MB)
    DISK_SPACE=$(df -BM / | awk 'NR==2 {print $4}' | tr -d 'M')
    echo -e "${BLUE}Current available disk space: ${DISK_SPACE}MB${NC}"
    
    if [ -z "$DISK_SPACE" ] || ! [[ "$DISK_SPACE" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}✗ Unable to retrieve disk space information.${NC}"
        return
    fi
    
    if (( DISK_SPACE < SWAP_SIZE )); then
        echo -e "${YELLOW}⚠️ Insufficient disk space, available: ${DISK_SPACE}MB, needed: ${SWAP_SIZE}MB${NC}"
        return
    fi

    # Check for existing swap file
    if [ -f /swapfile ]; then
        echo -e "${BLUE}Removing old swap file /swapfile...${NC}"
        sudo swapoff /swapfile 2>/dev/null
        sudo rm -f /swapfile
    fi

    # Create swap file
    echo -e "${BLUE}Creating swap file of ${SWAP_SIZE}MB...${NC}"
    sudo fallocate -l ${SWAP_SIZE}M /swapfile
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to create swap file, please check disk space.${NC}"
        return
    fi

    # Set file permissions
    sudo chmod 600 /swapfile

    # Format swap file
    echo -e "${BLUE}Formatting swap file...${NC}"
    sudo mkswap /swapfile
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Swap file formatting failed.${NC}"
        sudo rm -f /swapfile
        return
    fi

    # Enable swap file
    echo -e "${BLUE}Enabling swap file...${NC}"
    sudo swapon /swapfile
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ Failed to enable swap file.${NC}"
        sudo rm -f /swapfile
        return
    fi

    # Make it persistent
    if ! grep -q '/swapfile' /etc/fstab; then
        echo -e "${BLUE}Adding swap file to /etc/fstab for persistence...${NC}"
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi

    # Output result
    echo -e "${GREEN}✓ ${SWAP_SIZE}MB virtual memory successfully created and enabled. Current memory and swap info:${NC}"
    free -h
}

# Delete swap file
delete_swap() {
    if [ -f /swapfile ]; then
        echo -e "${BLUE}[$(date +"%Y-%m-%d %H:%M:%S")] INFO: Removing swap file /swapfile...${NC}"
        sudo swapoff /swapfile 2>/dev/null
        sudo rm -f /swapfile
        # Remove entry from /etc/fstab
        sudo sed -i '/\/swapfile/d' /etc/fstab
        echo -e "${GREEN}✓ Swap file deleted.${NC}"
    else
        echo -e "${BLUE}⚠️ Swap file /swapfile not found.${NC}"
    fi
}

# View current swap space info
view_swap() {
    if swapon --show | grep -q '/'; then
        # Get detailed memory info
        mem_info=$(free -m | awk 'NR==2')
        total_mem=$(echo $mem_info | awk '{print $2}')
        used_mem=$(echo $mem_info | awk '{print $3}')
        free_mem=$(echo $mem_info | awk '{print $4}')
        shared_mem=$(echo $mem_info | awk '{print $5}')
        buff_cache=$(echo $mem_info | awk '{print $6}')
        available_mem=$(free -m | awk 'NR==2 {print $7}')
        
        # Get swap info
        swap_info=$(free -m | awk 'NR==3')
        total_swap=$(echo $swap_info | awk '{print $2}')
        used_swap=$(echo $swap_info | awk '{print $3}')
        free_swap=$(echo $swap_info | awk '{print $4}')
        
        # Calculate swap usage percentage
        if [ "$total_swap" -gt 0 ]; then
            swap_usage=$((used_swap * 100 / total_swap))
        else
            swap_usage=0
        fi
        
        # Calculate memory usage percentage
        mem_usage=$((used_mem * 100 / total_mem))
        available_percent=$((available_mem * 100 / total_mem))
        
        # Get disk info
        disk_info=$(df -h / | awk 'NR==2')
        disk_total=$(echo $disk_info | awk '{print $2}')
        disk_used=$(echo $disk_info | awk '{print $3}')
        disk_avail=$(echo $disk_info | awk '{print $4}')
        disk_usage=$(echo $disk_info | awk '{print $5}')
        
        echo -e "${BLUE}========== System Resource Info =========${NC}"
        echo -e "${GREEN}Memory Info:${NC}"
        echo -e "Total Memory: ${total_mem}MB"
        echo -e "Used: ${used_mem}MB (${mem_usage}%)"
        echo -e "Free Memory: ${free_mem}MB"
        echo -e "Shared Memory: ${shared_mem}MB"
        echo -e "Buffer/Cached: ${buff_cache}MB"
        echo -e "Available Memory: ${available_mem}MB (${available_percent}%)"
        echo -e "${GREEN}Swap Space Info:${NC}"
        echo -e "Total Swap: ${total_swap}MB"
        echo -e "Used: ${used_swap}MB (${swap_usage}%)"
        echo -e "Free Swap: ${free_swap}MB"
        echo -e "${GREEN}Disk Info:${NC}"
        echo -e "Total: ${disk_total}"
        echo -e "Used: ${disk_used} (${disk_usage})"
        echo -e "Available: ${disk_avail}"
        echo -e "${BLUE}=========================================${NC}"
    else
        echo -e "${BLUE}Swap space not enabled.${NC}"
    fi
}

# Adjust swappiness value
adjust_swappiness() {
    CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness)
    # Show brief explanation
    echo -e "${YELLOW}Current swappiness value: ${CURRENT_SWAPPINESS}${NC}"
    echo -e "${YELLOW}Lower values mean less use of swap; higher values mean more swap usage.${NC}"
    echo -e "${YELLOW}Recommended range: 10-60${NC}"
    
    # Get new value
    while true; do
        read -p "Enter new swappiness value (0-100, recommended 10-60):" SWAPPINESS
        SWAPPINESS=${SWAPPINESS:-$CURRENT_SWAPPINESS}  # Keep current if no input
        
        # Validate input
        if [[ $SWAPPINESS =~ ^[0-9]+$ ]] && [ $SWAPPINESS -ge 0 ] && [ $SWAPPINESS -le 100 ]; then
            break
        else
            echo -e "${RED}⚠️ Invalid input, please enter an integer between 0 and 100.${NC}"
        fi
    done

    # Ask user to choose modification mode
    echo -e "\n${BLUE}Select modification mode:${NC}"
    echo -e "${YELLOW}1. Temporary change (effective immediately, will revert after reboot)${NC}"
    echo -e "${YELLOW}2. Permanent change (effective immediately and persists after reboot)${NC}"
    read -p "Enter option (1-2):" MODE

    case $MODE in
        1)
            # Temporary change
            sudo sysctl vm.swappiness=$SWAPPINESS
            echo -e "${GREEN}✓ Swappiness temporarily set to $SWAPPINESS (effective immediately, will revert after reboot).${NC}"
            ;;
        2)
            # Permanent change
            CONFIG_FILE="/etc/sysctl.conf"
            if grep -q '^vm.swappiness=' $CONFIG_FILE; then
                sudo sed -i "s/^vm.swappiness=.*/vm.swappiness=$SWAPPINESS/" $CONFIG_FILE
            else
                echo "vm.swappiness=$SWAPPINESS" | sudo tee -a $CONFIG_FILE > /dev/null
            fi
            # Apply immediately
            sudo sysctl -p
            echo -e "${GREEN}✓ Swappiness permanently set to $SWAPPINESS (effective immediately and after reboot).${NC}"
            ;;
        *)
            echo -e "${RED}⚠️ Invalid option, no changes made.${NC}"
            ;;
    esac
}

# Memory stress test
stress_test() {
    echo -e "${BLUE}Preparing for memory stress test...${NC}"
    
    # Check if stress/stress-ng is installed
    if ! command -v stress &> /dev/null && ! command -v stress-ng &> /dev/null; then
        echo -e "${YELLOW}Stress testing tools not installed, installing now...${NC}"
        
        case $PKG_MANAGER in
            "apk")
                if ! apk add stress-ng; then
                    echo -e "${RED}✗ stress-ng installation failed${NC}"
                    return 1
                fi
                STRESS_CMD="stress-ng"
                ;;
            "apt-get")
                if ! sudo apt-get install -y stress; then
                    echo -e "${RED}✗ stress installation failed${NC}"
                    return 1
                fi
                STRESS_CMD="stress"
                ;;
            "yum")
                if ! sudo yum install -y stress; then
                    echo -e "${RED}✗ stress installation failed${NC}"
                    return 1
                fi
                STRESS_CMD="stress"
                ;;
            "pacman")
                if ! sudo pacman -S --noconfirm stress; then
                    echo -e "${RED}✗ stress installation failed${NC}"
                    return 1
                fi
                STRESS_CMD="stress"
                ;;
        esac
    else
        STRESS_CMD=$(command -v stress-ng || command -v stress)
    fi

    # Get test duration
    while true; do
        read -p "Please enter stress test duration (unit: seconds, default 5):" TEST_TIME
        TEST_TIME=${TEST_TIME:-5}  # Default to 5 seconds
        
        # Validate input
        if [[ $TEST_TIME =~ ^[0-9]+$ ]] && [ $TEST_TIME -gt 0 ]; then
            break
        else
            echo -e "${RED}✗ Invalid input, please enter an integer greater than 0 (seconds).${NC}"
        fi
    done

    # Get available memory
    total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    
    # Ask user for memory usage percentage
    while true; do
        read -p "Please enter memory usage percentage for stress test (10-1000, default 90):" MEM_PERCENT
        MEM_PERCENT=${MEM_PERCENT:-90}  # Default to 90%
        
        # Validate input
        if [[ $MEM_PERCENT =~ ^[0-9]+$ ]] && [ $MEM_PERCENT -ge 10 ] && [ $MEM_PERCENT -le 1000 ]; then
            break
        else
            echo -e "${RED}✗ Invalid input, please enter an integer between 10 and 1000.${NC}"
        fi
    done

    # Calculate memory size for testing
    MEM_RATIO=$(echo "scale=2; $MEM_PERCENT / 100" | bc)
    MEM_SIZE=$(echo "$total_mem * 1024 * $MEM_RATIO" | bc | awk '{printf "%d\n", $0}')
    MEM_SIZE_GB=$(echo "scale=2; $MEM_SIZE / 1024 / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
    
    echo -e "${YELLOW}Starting memory stress test with ${MEM_SIZE_GB} GB (${MEM_PERCENT}% of system memory), duration: ${TEST_TIME} seconds.${NC}"
    
    # Run stress test
    timeout ${TEST_TIME}s $STRESS_CMD --vm-bytes ${MEM_SIZE} --vm-keep -m 1 &
    STRESS_PID=$!
    
    # Function to get CPU stats
    get_cpu_stats() {
        read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
        total=$((user + nice + system + idle + iowait + irq + softirq + steal))
        idle_total=$((idle + iowait))
        echo "$total $idle_total"
    }

    prev_stats=$(get_cpu_stats)
    prev_total=$(echo $prev_stats | awk '{print $1}')
    prev_idle=$(echo $prev_stats | awk '{print $2}')

    # Monitor memory and swap usage in real-time
    echo -e "${BLUE}Real-time monitoring of memory and swap usage:${NC}"
    echo -e "${YELLOW}Note: Using more than 100% of system memory may trigger OOM Killer to terminate the process.${NC}"
    while kill -0 $STRESS_PID 2>/dev/null; do
        # Get memory info
        total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        avail_mem=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        used_mem=$((total_mem - avail_mem))
        mem_usage=$((used_mem * 100 / total_mem))
        used_mem_gb=$(echo "scale=2; $used_mem / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # Get swap info
        total_swap=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
        free_swap=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
        used_swap=$((total_swap - free_swap))
        swap_usage=$((total_swap > 0 ? used_swap * 100 / total_swap : 0))
        used_swap_gb=$(echo "scale=2; $used_swap / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # Calculate CPU usage
        current_stats=$(get_cpu_stats)
        current_total=$(echo $current_stats | awk '{print $1}')
        current_idle=$(echo $current_stats | awk '{print $2}')
        
        total_diff=$((current_total - prev_total))
        idle_diff=$((current_idle - prev_idle))
        cpu_usage=$((100 * (total_diff - idle_diff) / total_diff))
        
        # Update previous stats
        prev_total=$current_total
        prev_idle=$current_idle
        
        echo -e "CPU Usage: ${cpu_usage}%  Memory Usage: ${mem_usage}% (${used_mem_gb}GB)  Swap: ${swap_usage}% (${used_swap_gb}GB)"
        sleep 1  # Update every second
    done
    
    echo -e "${GREEN}✓ Stress test completed.${NC}"
    # Show status after test
    for i in {1..1}; do
        # Get memory info
        total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        avail_mem=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        used_mem=$((total_mem - avail_mem))
        mem_usage=$((used_mem * 100 / total_mem))
        used_mem_gb=$(echo "scale=2; $used_mem / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # Get swap info
        total_swap=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
        free_swap=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
        used_swap=$((total_swap - free_swap))
        swap_usage=$((total_swap > 0 ? used_swap * 100 / total_swap : 0))
        used_swap_gb=$(echo "scale=2; $used_swap / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # Calculate CPU usage
        current_stats=$(get_cpu_stats)
        current_total=$(echo $current_stats | awk '{print $1}')
        current_idle=$(echo $current_stats | awk '{print $2}')
        
        total_diff=$((current_total - prev_total))
        idle_diff=$((current_idle - prev_idle))
        cpu_usage=$((100 * (total_diff - idle_diff) / total_diff))
        
        # Update previous stats
        prev_total=$current_total
        prev_idle=$current_idle
        
        echo -e "CPU Usage: ${cpu_usage}%  Memory Usage: ${mem_usage}% (${used_mem_gb}GB)  Swap: ${swap_usage}% (${used_swap_gb}GB)"
        sleep 1  # Update every second
    done
}

# Add uninstall functions
uninstall_program() {
    echo -e "${YELLOW}Preparing to uninstall...${NC}"
    
    echo -e "\n${BLUE}Choose uninstall option:${NC}"
    echo -e "${GREEN}1. Remove only swap file${NC}"
    echo -e "${GREEN}2. Remove only program${NC}"
    echo -e "${RED}3. Remove both swap file and program${NC}"
    echo -e "${BLUE}4. Cancel${NC}"
    
    read -p "Enter option (1-4):" uninstall_choice
    
    case $uninstall_choice in
        1)  # Remove only swap file
            read -p "Are you sure to delete swap file? (y/n): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                if [ -f /swapfile ]; then
                    echo -e "${BLUE}Removing swap file...${NC}"
                    sudo swapoff /swapfile 2>/dev/null
                    sudo rm -f /swapfile
                    sudo sed -i '/\/swapfile/d' /etc/fstab
                    echo -e "${GREEN}✓ Swap file removed.${NC}"
                else
                    echo -e "${YELLOW}Swap file not found.${NC}"
                fi
            else
                echo -e "${BLUE}Cancelled swap file removal.${NC}"
            fi
            ;;
        2)  # Remove only program
            read -p "Are you sure to delete program? (y/n): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                echo -e "${BLUE}Removing program...${NC}"
                sudo rm -f /usr/local/bin/swap
                echo -e "${GREEN}✓ Program removed.${NC}"
                exit 0
            else
                echo -e "${BLUE}Cancelled program removal.${NC}"
            fi
            ;;
        3)  # Remove all
            read -p "Are you sure to delete swap file and program? (y/n): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                # Remove swap file
                if [ -f /swapfile ]; then
                    echo -e "${BLUE}Removing swap file...${NC}"
                    sudo swapoff /swapfile 2>/dev/null
                    sudo rm -f /swapfile
                    sudo sed -i '/\/swapfile/d' /etc/fstab
                    echo -e "${GREEN}✓ Swap file removed.${NC}"
                fi
                # Remove program
                echo -e "${BLUE}Removing program...${NC}"
                sudo rm -f /usr/local/bin/swap
                echo -e "${GREEN}✓ Program removed.${NC}"
                exit 0
            else
                echo -e "${BLUE}Uninstall cancelled.${NC}"
            fi
            ;;
        4)  # Cancel
            echo -e "${BLUE}Uninstall cancelled.${NC}"
            ;;
        *)
            echo -e "${RED}✗ Invalid option.${NC}"
            ;;
    esac
}

# Main loop
while true; do
    show_menu
    read -p "Please enter option (1-7):" choice

    case $choice in
        1) create_swap ;;
        2) delete_swap ;;
        3) view_swap ;;
        4) adjust_swappiness ;;
        5) stress_test ;;
        6) uninstall_program ;;
        7) break ;;
        *) echo -e "${RED}✗ Invalid option, please try again.${NC}" ;;
    esac
done
