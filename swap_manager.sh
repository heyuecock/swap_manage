#!/bin/bash

# Define colors / 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Reset color / 重置颜色

# Language settings / 语言设置
LANG_FILE="/etc/swap_manager_lang"
DEFAULT_LANG="en"

# 检查语言文件是否存在且可读
if [ -f "$LANG_FILE" ] && [ -r "$LANG_FILE" ]; then
    LANG=$(cat "$LANG_FILE")
    # 验证语言设置是否有效
    if [ "$LANG" != "en" ] && [ "$LANG" != "zh" ]; then
        LANG="$DEFAULT_LANG"
    fi
else
    # 显示语言选择菜单
    while true; do
        echo -e "${BLUE}Please select language / 请选择语言：${NC}"
        echo -e "1. English"
        echo -e "2. 中文"
        read -p "Enter your choice (1-2) / 请输入选项 (1-2): " lang_choice
        
        case $lang_choice in
            1) LANG="en"; break ;;
            2) LANG="zh"; break ;;
            *) 
                echo -e "${RED}Invalid choice, please try again. / 无效选项，请重试。${NC}"
                continue 
                ;;
        esac
    done

    # 尝试保存语言设置
    if ! echo "$LANG" | sudo tee "$LANG_FILE" > /dev/null 2>&1; then
        # 如果保存到/etc失败，尝试保存到用户主目录
        LANG_FILE="$HOME/.swap_manager_lang"
        if ! echo "$LANG" > "$LANG_FILE" 2>/dev/null; then
            echo -e "${YELLOW}Warning: Could not save language preference. / 警告：无法保存语言偏好设置。${NC}"
        fi
    fi
fi

# Check if running as root, if not try sudo or prompt for root / 检查是否为root用户，如果不是则尝试使用sudo或提示使用root
if [ "$EUID" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo "$0" "$@"
    else
        echo -e "${YELLOW}${TEXT["not_root"]}${NC}"
        echo -e "${BLUE}${TEXT["alpine_instructions"]}${NC}"
        echo -e "${GREEN}su -c 'wget -qO /usr/local/bin/swap https://raw.githubusercontent.com/heyuecock/swap_manage/refs/heads/main/swap_manager.sh && chmod +x /usr/local/bin/swap'${NC}"
        echo -e "${BLUE}${TEXT["then_run"]}${NC}"
        echo -e "${GREEN}su -c swap${NC}"
        exit 1
    fi
fi

# Check and install required dependencies / 检查并安装必要依赖
check_dependencies() {
    # Check package manager / 检查包管理器
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
        echo -e "${RED}✗ ${TEXT["package_manager_not_found"]}${NC}"
        exit 1
    fi

    # Check and install basic tools / 检查并安装基本工具
    MISSING_TOOLS=()
    
    # Check basic tools / 检查基本工具
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

    # Install missing basic tools / 安装缺失的基本工具
    if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
        echo -e "${YELLOW}${TEXT["installing_tools"]}: ${MISSING_TOOLS[*]}${NC}"
        if [ "$PKG_MANAGER" = "apk" ]; then
            if ! $INSTALL_CMD "${MISSING_TOOLS[@]}"; then
                echo -e "${RED}✗ ${TEXT["package_install_failed"]}: ${MISSING_TOOLS[*]}${NC}"
                exit 1
            fi
        else
            if ! sudo $INSTALL_CMD "${MISSING_TOOLS[@]}"; then
                echo -e "${RED}✗ ${TEXT["package_install_failed"]}: ${MISSING_TOOLS[*]}${NC}"
                exit 1
            fi
        fi
    fi
}

# System compatibility check / 系统兼容性检查
check_system_compatibility() {
    # Check if swap is supported / 检查是否支持swap
    if ! grep -q "SwapTotal" /proc/meminfo; then
        echo -e "${RED}✗ ${TEXT["system_not_supported"]}${NC}"
        exit 1
    fi

    # Alpine special handling / Alpine特殊处理
    if [ -f /etc/alpine-release ]; then
        echo -e "${YELLOW}${TEXT["alpine_detected"]}${NC}"
        
        # Check required packages / 检查必要的包
        MISSING_PKGS=()
        for pkg in sudo wget bash util-linux-misc bc; do
            if ! command -v $pkg >/dev/null 2>&1; then
                MISSING_PKGS+=($pkg)
            fi
        done
        
        if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
            echo -e "${YELLOW}${TEXT["missing_packages"]} ${MISSING_PKGS[*]}${NC}"
            echo -e "${BLUE}${TEXT["installing_packages"]}${NC}"
            
            # Try direct apk installation / 尝试直接使用apk安装
            if apk add ${MISSING_PKGS[*]}; then
                echo -e "${GREEN}✓ ${TEXT["packages_installed"]}${NC}"
            else
                echo -e "${RED}✗ ${TEXT["package_install_failed"]}${NC}"
                echo -e "apk add ${MISSING_PKGS[*]}"
                exit 1
            fi
        fi

        # Check required kernel modules / 检查必要的内核模块
        if ! grep -q "swap" /proc/modules; then
            echo -e "${YELLOW}${TEXT["loading_kernel_module"]}${NC}"
            modprobe swap
        fi
    fi

    # Check filesystem support / 检查文件系统支持
    if ! touch /.swap_test_file 2>/dev/null; then
        echo -e "${RED}✗ ${TEXT["fs_not_supported"]}${NC}"
        exit 1
    fi
    rm -f /.swap_test_file
}

# Call at program start / 在主程序开始时调用
check_system_compatibility
check_dependencies

# Check if system supports swap files / 检查系统是否支持交换文件
if ! swapon --version &>/dev/null; then
    echo -e "${RED}✗ ${TEXT["swapon_not_supported"]}${NC}"
    exit 1
fi

# Menu function (with colors) / 菜单函数（带颜色）
show_menu() {
    if [ "$LANG" = "en" ]; then
        echo -e "\n${BLUE}========== Swap File Management Menu ==========${NC}"
        echo -e "${GREEN}1. Create Swap File${NC}"
        echo -e "${GREEN}2. Delete Swap File${NC}"
        echo -e "${GREEN}3. View Current Swap Information${NC}"
        echo -e "${GREEN}4. Adjust Memory Swappiness${NC}"
        echo -e "${GREEN}5. Memory Stress Test${NC}"
        echo -e "${RED}6. Uninstall Program${NC}"
        echo -e "${RED}7. Exit${NC}"
        echo -e "${BLUE}=====================================${NC}\n"
    else
        echo -e "\n${BLUE}========== 交换文件管理菜单 ==========${NC}"
        echo -e "${GREEN}1. 创建交换文件${NC}"
        echo -e "${GREEN}2. 删除交换文件${NC}"
        echo -e "${GREEN}3. 查看当前交换空间信息${NC}"
        echo -e "${GREEN}4. 调整内存交换倾向性${NC}"
        echo -e "${GREEN}5. 内存压力测试${NC}"
        echo -e "${RED}6. 卸载程序${NC}"
        echo -e "${RED}7. 退出${NC}"
        echo -e "${BLUE}=====================================${NC}\n"
    fi
}

# Create swap file / 创建交换文件
create_swap() {
    if [ "$LANG" = "en" ]; then
        echo -e "${BLUE}Creating swap file...${NC}"
        echo -e "${YELLOW}Please enter the size of swap file in MB (default: 1024)${NC}"
        echo -e "${YELLOW}Recommended: 100-5120 MB${NC}"
        read -p "Enter swap file size (MB): " SWAP_SIZE
    else
        echo -e "${BLUE}正在创建交换文件...${NC}"
        echo -e "${YELLOW}请输入交换文件大小（MB）（默认：1024）${NC}"
        echo -e "${YELLOW}推荐：100-5120 MB${NC}"
        read -p "请输入交换文件大小（MB）：" SWAP_SIZE
    fi
    
    SWAP_SIZE=${SWAP_SIZE:-1024}  # If user didn't input, default to 1024MB
    
    # Validate input is legal / 验证输入是否合法
    if ! [[ $SWAP_SIZE =~ ^[0-9]+$ ]] || [ $SWAP_SIZE -lt 100 ] || [ $SWAP_SIZE -gt 5120 ]; then
        if [ "$LANG" = "en" ]; then
            echo -e "${RED}✗ Invalid size, using default 1024MB${NC}"
        else
            echo -e "${RED}✗ 无效的大小，使用默认值1024MB${NC}"
        fi
        SWAP_SIZE=1024
    fi

    # Check disk space is enough / 检查磁盘空间是否足够
    DISK_SPACE=$(df -BM / | awk 'NR==2 {print $4}' | tr -d 'M')
    if [ "$LANG" = "en" ]; then
        echo -e "${BLUE}Available disk space: ${DISK_SPACE}MB${NC}"
    else
        echo -e "${BLUE}可用磁盘空间：${DISK_SPACE}MB${NC}"
    fi
    
    if [ -z "$DISK_SPACE" ] || ! [[ "$DISK_SPACE" =~ ^[0-9]+$ ]]; then
        if [ "$LANG" = "en" ]; then
            echo -e "${RED}✗ Failed to get disk space information${NC}"
        else
            echo -e "${RED}✗ 获取磁盘空间信息失败${NC}"
        fi
        return
    fi
    
    if (( DISK_SPACE < SWAP_SIZE )); then
        if [ "$LANG" = "en" ]; then
            echo -e "${YELLOW}⚠️ Insufficient disk space: ${DISK_SPACE}MB available, ${SWAP_SIZE}MB needed${NC}"
        else
            echo -e "${YELLOW}⚠️ 磁盘空间不足：可用${DISK_SPACE}MB，需要${SWAP_SIZE}MB${NC}"
        fi
        return
    fi

    # Check if old swap file exists / 检查是否存在旧的交换文件
    if [ -f /swapfile ]; then
        if [ "$LANG" = "en" ]; then
            echo -e "${BLUE}Deleting existing swap file...${NC}"
        else
            echo -e "${BLUE}正在删除现有交换文件...${NC}"
        fi
        sudo swapoff /swapfile 2>/dev/null
        sudo rm -f /swapfile
    fi

    # Create swap file / 创建交换文件
    if [ "$LANG" = "en" ]; then
        echo -e "${BLUE}Creating ${SWAP_SIZE}MB swap file...${NC}"
    else
        echo -e "${BLUE}正在创建${SWAP_SIZE}MB交换文件...${NC}"
    fi
    sudo fallocate -l ${SWAP_SIZE}M /swapfile
    if [ $? -ne 0 ]; then
        if [ "$LANG" = "en" ]; then
            echo -e "${RED}✗ Failed to create swap file${NC}"
        else
            echo -e "${RED}✗ 创建交换文件失败${NC}"
        fi
        return
    fi

    # Set file permissions / 设置文件权限
    sudo chmod 600 /swapfile

    # Format swap file / 格式化交换文件
    if [ "$LANG" = "en" ]; then
        echo -e "${BLUE}Formatting swap file...${NC}"
    else
        echo -e "${BLUE}正在格式化交换文件...${NC}"
    fi
    sudo mkswap /swapfile
    if [ $? -ne 0 ]; then
        if [ "$LANG" = "en" ]; then
            echo -e "${RED}✗ Failed to format swap file${NC}"
        else
            echo -e "${RED}✗ 格式化交换文件失败${NC}"
        fi
        sudo rm -f /swapfile
        return
    fi

    # Enable swap file / 启用交换文件
    if [ "$LANG" = "en" ]; then
        echo -e "${BLUE}Enabling swap file...${NC}"
    else
        echo -e "${BLUE}正在启用交换文件...${NC}"
    fi
    sudo swapon /swapfile
    if [ $? -ne 0 ]; then
        if [ "$LANG" = "en" ]; then
            echo -e "${RED}✗ Failed to enable swap file${NC}"
        else
            echo -e "${RED}✗ 启用交换文件失败${NC}"
        fi
        sudo rm -f /swapfile
        return
    fi

    # Permanent effect / 永久生效
    if ! grep -q '/swapfile' /etc/fstab; then
        if [ "$LANG" = "en" ]; then
            echo -e "${BLUE}Making swap file permanent...${NC}"
        else
            echo -e "${BLUE}正在使交换文件永久生效...${NC}"
        fi
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi

    # Output result / 输出结果
    if [ "$LANG" = "en" ]; then
        echo -e "${GREEN}✓ Swap file created successfully${NC}"
        echo -e "${BLUE}Current memory status:${NC}"
    else
        echo -e "${GREEN}✓ 交换文件创建成功${NC}"
        echo -e "${BLUE}当前内存状态：${NC}"
    fi
    free -h
}

# Delete swap file / 删除交换文件
delete_swap() {
    if [ -f /swapfile ]; then
        if [ "$LANG" = "en" ]; then
            echo -e "${BLUE}Deleting swap file...${NC}"
            echo -e "${YELLOW}This will remove the swap file and disable swap space.${NC}"
            read -p "Are you sure you want to continue? (y/N): " confirm
        else
            echo -e "${BLUE}正在删除交换文件...${NC}"
            echo -e "${YELLOW}这将删除交换文件并禁用交换空间。${NC}"
            read -p "确定要继续吗？(y/N)：" confirm
        fi
        
        if [[ $confirm =~ ^[Yy]$ ]]; then
            if [ "$LANG" = "en" ]; then
                echo -e "${BLUE}Disabling swap file...${NC}"
            else
                echo -e "${BLUE}正在禁用交换文件...${NC}"
            fi
            sudo swapoff /swapfile 2>/dev/null
            
            if [ "$LANG" = "en" ]; then
                echo -e "${BLUE}Removing swap file...${NC}"
            else
                echo -e "${BLUE}正在删除交换文件...${NC}"
            fi
            sudo rm -f /swapfile
            
            if [ "$LANG" = "en" ]; then
                echo -e "${BLUE}Removing swap configuration...${NC}"
            else
                echo -e "${BLUE}正在删除交换配置...${NC}"
            fi
            sudo sed -i '/\/swapfile/d' /etc/fstab
            
            if [ "$LANG" = "en" ]; then
                echo -e "${GREEN}✓ Swap file deleted successfully${NC}"
                echo -e "${BLUE}Current memory status:${NC}"
            else
                echo -e "${GREEN}✓ 交换文件删除成功${NC}"
                echo -e "${BLUE}当前内存状态：${NC}"
            fi
            free -h
        else
            if [ "$LANG" = "en" ]; then
                echo -e "${BLUE}Operation cancelled${NC}"
            else
                echo -e "${BLUE}操作已取消${NC}"
            fi
        fi
    else
        if [ "$LANG" = "en" ]; then
            echo -e "${BLUE}No swap file found at /swapfile${NC}"
        else
            echo -e "${BLUE}未找到交换文件 /swapfile${NC}"
        fi
    fi
}

# View current swap space information / 查看当前交换空间信息
view_swap() {
    if swapon --show | grep -q '/'; then
        # Get detailed memory information
        mem_info=$(free -m | awk 'NR==2')
        total_mem=$(echo $mem_info | awk '{print $2}')
        used_mem=$(echo $mem_info | awk '{print $3}')
        free_mem=$(echo $mem_info | awk '{print $4}')
        shared_mem=$(echo $mem_info | awk '{print $5}')
        buff_cache=$(echo $mem_info | awk '{print $6}')
        available_mem=$(free -m | awk 'NR==2 {print $7}')
        
        # Get swap space information
        swap_info=$(free -m | awk 'NR==3')
        total_swap=$(echo $swap_info | awk '{print $2}')
        used_swap=$(echo $swap_info | awk '{print $3}')
        free_swap=$(echo $swap_info | awk '{print $4}')
        
        # Calculate swap space usage
        if [ "$total_swap" -gt 0 ]; then
            swap_usage=$((used_swap * 100 / total_swap))
        else
            swap_usage=0
        fi
        
        # Calculate usage
        mem_usage=$((used_mem * 100 / total_mem))
        available_percent=$((available_mem * 100 / total_mem))
        
        # Get disk information
        disk_info=$(df -h / | awk 'NR==2')
        disk_total=$(echo $disk_info | awk '{print $2}')
        disk_used=$(echo $disk_info | awk '{print $3}')
        disk_avail=$(echo $disk_info | awk '{print $4}')
        disk_usage=$(echo $disk_info | awk '{print $5}')
        
        if [ "$LANG" = "en" ]; then
            echo -e "${BLUE}========== System Resource Information =========${NC}"
            echo -e "${GREEN}Memory Information:${NC}"
            echo -e "Total Memory: ${total_mem}MB"
            echo -e "Used: ${used_mem}MB (${mem_usage}%)"
            echo -e "Free Memory: ${free_mem}MB"
            echo -e "Shared Memory: ${shared_mem}MB"
            echo -e "Buffer/Cache: ${buff_cache}MB"
            echo -e "Available Memory: ${available_mem}MB (${available_percent}%)"
            echo -e "${GREEN}Swap Space Information:${NC}"
            echo -e "Total Swap Space: ${total_swap}MB"
            echo -e "Used: ${used_swap}MB (${swap_usage}%)"
            echo -e "Available Swap Space: ${free_swap}MB"
            echo -e "${GREEN}Disk Information:${NC}"
            echo -e "Total Space: ${disk_total}"
            echo -e "Used: ${disk_used} (${disk_usage})"
            echo -e "Available Space: ${disk_avail}"
            echo -e "${BLUE}===============================${NC}"
        else
            echo -e "${BLUE}========== 系统资源信息 =========${NC}"
            echo -e "${GREEN}内存信息：${NC}"
            echo -e "总内存：${total_mem}MB"
            echo -e "已使用：${used_mem}MB (${mem_usage}%)"
            echo -e "空闲内存：${free_mem}MB"
            echo -e "共享内存：${shared_mem}MB"
            echo -e "缓存/缓冲区：${buff_cache}MB"
            echo -e "实际可用内存：${available_mem}MB (${available_percent}%)"
            echo -e "${GREEN}交换空间信息：${NC}"
            echo -e "总交换空间：${total_swap}MB"
            echo -e "已使用：${used_swap}MB (${swap_usage}%)"
            echo -e "可用交换空间：${free_swap}MB"
            echo -e "${GREEN}磁盘信息：${NC}"
            echo -e "总空间：${disk_total}"
            echo -e "已使用：${disk_used} (${disk_usage})"
            echo -e "可用空间：${disk_avail}"
            echo -e "${BLUE}===============================${NC}"
        fi
    else
        if [ "$LANG" = "en" ]; then
            echo -e "${BLUE}No swap space enabled.${NC}"
        else
            echo -e "${BLUE}未启用交换空间。${NC}"
        fi
    fi
}

# Adjust memory swappiness / 调整内存交换倾向性
adjust_swappiness() {
    CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness)
    # Display brief description / 显示简要说明
    if [ "$LANG" = "en" ]; then
        echo -e "${YELLOW}Current memory swappiness value: ${CURRENT_SWAPPINESS}${NC}"
        echo -e "${YELLOW}Lower value means less swap usage; higher value means more swap usage.${NC}"
        echo -e "${YELLOW}Recommended value: 10-60${NC}"
        read -p "Enter new memory swappiness value (0-100, recommended 10-60): " SWAPPINESS
    else
        echo -e "${YELLOW}当前内存交换倾向性值：${CURRENT_SWAPPINESS}${NC}"
        echo -e "${YELLOW}值越低，越少使用交换空间；值越高，越多使用交换空间。${NC}"
        echo -e "${YELLOW}推荐值：10-60${NC}"
        read -p "请输入新的内存交换倾向性值（0-100，推荐10-60）：" SWAPPINESS
    fi
    
    SWAPPINESS=${SWAPPINESS:-$CURRENT_SWAPPINESS}  # If user didn't input, keep current value
    
    # Validate input is legal / 验证输入是否合法
    if [[ $SWAPPINESS =~ ^[0-9]+$ ]] && [ $SWAPPINESS -ge 0 ] && [ $SWAPPINESS -le 100 ]; then
        # Let user choose modification method / 让用户选择修改方式
        if [ "$LANG" = "en" ]; then
            echo -e "\n${BLUE}Please select modification method:${NC}"
            echo -e "${YELLOW}1. Temporary modification (effective immediately, reset after reboot)${NC}"
            echo -e "${YELLOW}2. Permanent modification (effective immediately and persists after reboot)${NC}"
            read -p "Enter option (1-2): " MODE
        else
            echo -e "\n${BLUE}请选择修改方式：${NC}"
            echo -e "${YELLOW}1. 临时修改（立即生效，重启后失效）${NC}"
            echo -e "${YELLOW}2. 永久修改（立即生效且重启后仍然有效）${NC}"
            read -p "请输入选项（1-2）：" MODE
        fi

        case $MODE in
            1)
                # Temporary modification (effective immediately) / 临时修改（立即生效）
                sudo sysctl vm.swappiness=$SWAPPINESS
                if [ "$LANG" = "en" ]; then
                    echo -e "${GREEN}✓ Memory swappiness value temporarily modified to $SWAPPINESS${NC}"
                else
                    echo -e "${GREEN}✓ 内存交换倾向性值已临时修改为 $SWAPPINESS${NC}"
                fi
                ;;
            2)
                # Permanent modification and effective immediately / 永久修改并立即生效
                CONFIG_FILE="/etc/sysctl.conf"
                if grep -q '^vm.swappiness=' $CONFIG_FILE; then
                    sudo sed -i "s/^vm.swappiness=.*/vm.swappiness=$SWAPPINESS/" $CONFIG_FILE
                else
                    echo "vm.swappiness=$SWAPPINESS" | sudo tee -a $CONFIG_FILE > /dev/null
                fi
                # Effective immediately / 立即生效
                sudo sysctl -p
                if [ "$LANG" = "en" ]; then
                    echo -e "${GREEN}✓ Memory swappiness value permanently modified to $SWAPPINESS${NC}"
                else
                    echo -e "${GREEN}✓ 内存交换倾向性值已永久修改为 $SWAPPINESS${NC}"
                fi
                ;;
            *)
                if [ "$LANG" = "en" ]; then
                    echo -e "${RED}✗ Invalid option, no changes made.${NC}"
                else
                    echo -e "${RED}✗ 无效选项，未进行任何修改。${NC}"
                fi
                ;;
        esac
    else
        if [ "$LANG" = "en" ]; then
            echo -e "${RED}✗ Invalid input, please enter an integer between 0 and 100.${NC}"
        else
            echo -e "${RED}✗ 输入值无效，请输入0到100之间的整数。${NC}"
        fi
    fi
}

# Memory stress test / 内存压力测试
stress_test() {
    if [ "$LANG" = "en" ]; then
        echo -e "${BLUE}Preparing memory stress test...${NC}"
        echo -e "${YELLOW}This test will simulate high memory usage to test your system's performance.${NC}"
        echo -e "${YELLOW}Please make sure you have saved all your work before proceeding.${NC}"
    else
        echo -e "${BLUE}正在准备内存压力测试...${NC}"
        echo -e "${YELLOW}此测试将模拟高内存使用情况来测试系统性能。${NC}"
        echo -e "${YELLOW}请确保在继续之前已保存所有工作。${NC}"
    fi
    
    # Check if stress/stress-ng is installed / 检查是否安装了stress/stress-ng
    if ! command -v stress &> /dev/null && ! command -v stress-ng &> /dev/null; then
        if [ "$LANG" = "en" ]; then
            echo -e "${YELLOW}Installing stress testing tool...${NC}"
        else
            echo -e "${YELLOW}正在安装压力测试工具...${NC}"
        fi
        
        case $PKG_MANAGER in
            "apk")
                if ! apk add stress-ng; then
                    if [ "$LANG" = "en" ]; then
                        echo -e "${RED}✗ Failed to install stress-ng${NC}"
                    else
                        echo -e "${RED}✗ 安装stress-ng失败${NC}"
                    fi
                    return 1
                fi
                STRESS_CMD="stress-ng"
                ;;
            "apt-get")
                if ! sudo apt-get install -y stress; then
                    if [ "$LANG" = "en" ]; then
                        echo -e "${RED}✗ Failed to install stress${NC}"
                    else
                        echo -e "${RED}✗ 安装stress失败${NC}"
                    fi
                    return 1
                fi
                STRESS_CMD="stress"
                ;;
            "yum")
                if ! sudo yum install -y stress; then
                    if [ "$LANG" = "en" ]; then
                        echo -e "${RED}✗ Failed to install stress${NC}"
                    else
                        echo -e "${RED}✗ 安装stress失败${NC}"
                    fi
                    return 1
                fi
                STRESS_CMD="stress"
                ;;
            "pacman")
                if ! sudo pacman -S --noconfirm stress; then
                    if [ "$LANG" = "en" ]; then
                        echo -e "${RED}✗ Failed to install stress${NC}"
                    else
                        echo -e "${RED}✗ 安装stress失败${NC}"
                    fi
                    return 1
                fi
                STRESS_CMD="stress"
                ;;
        esac
    else
        STRESS_CMD=$(command -v stress-ng || command -v stress)
    fi

    # Get test time / 获取测试时间
    if [ "$LANG" = "en" ]; then
        echo -e "\n${BLUE}Test Duration:${NC}"
        echo -e "${YELLOW}Please enter the test duration in seconds (default: 5)${NC}"
        echo -e "${YELLOW}Recommended: 5-30 seconds${NC}"
        read -p "Enter test duration (seconds): " TEST_TIME
    else
        echo -e "\n${BLUE}测试时长：${NC}"
        echo -e "${YELLOW}请输入测试时长（秒）（默认：5）${NC}"
        echo -e "${YELLOW}推荐：5-30秒${NC}"
        read -p "请输入测试时长（秒）：" TEST_TIME
    fi
    
    TEST_TIME=${TEST_TIME:-5}  # If user didn't input, default to 5 seconds
    
    # Validate input is legal / 验证输入是否合法
    if ! [[ $TEST_TIME =~ ^[0-9]+$ ]] || [ $TEST_TIME -le 0 ]; then
        if [ "$LANG" = "en" ]; then
            echo -e "${RED}✗ Invalid time value, using default 5 seconds${NC}"
        else
            echo -e "${RED}✗ 无效的时间值，使用默认值5秒${NC}"
        fi
        TEST_TIME=5
    fi

    # Get available memory / 获取可用内存
    total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    
    # Let user input memory usage percentage / 让用户输入内存使用百分比
    if [ "$LANG" = "en" ]; then
        echo -e "\n${BLUE}Memory Usage:${NC}"
        echo -e "${YELLOW}Please enter the percentage of memory to use (default: 90%)${NC}"
        echo -e "${YELLOW}Recommended: 70-90%${NC}"
        read -p "Enter memory usage percentage (10-100): " MEM_PERCENT
    else
        echo -e "\n${BLUE}内存使用率：${NC}"
        echo -e "${YELLOW}请输入要使用的内存百分比（默认：90%）${NC}"
        echo -e "${YELLOW}推荐：70-90%${NC}"
        read -p "请输入内存使用百分比（10-100）：" MEM_PERCENT
    fi
    
    MEM_PERCENT=${MEM_PERCENT:-90}  # If user didn't input, default to 90%
    
    # Validate input is legal / 验证输入是否合法
    if ! [[ $MEM_PERCENT =~ ^[0-9]+$ ]] || [ $MEM_PERCENT -lt 10 ] || [ $MEM_PERCENT -gt 100 ]; then
        if [ "$LANG" = "en" ]; then
            echo -e "${RED}✗ Invalid percentage, using default 90%${NC}"
        else
            echo -e "${RED}✗ 无效的百分比，使用默认值90%${NC}"
        fi
        MEM_PERCENT=90
    fi

    # Calculate test memory size / 计算测试内存大小
    MEM_RATIO=$(echo "scale=2; $MEM_PERCENT / 100" | bc)
    MEM_SIZE=$(echo "$total_mem * 1024 * $MEM_RATIO" | bc | awk '{printf "%d\n", $0}')
    MEM_SIZE_GB=$(echo "scale=2; $MEM_SIZE / 1024 / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
    
    if [ "$LANG" = "en" ]; then
        echo -e "\n${BLUE}Test Configuration:${NC}"
        echo -e "${YELLOW}Duration: ${TEST_TIME} seconds${NC}"
        echo -e "${YELLOW}Memory Usage: ${MEM_PERCENT}% (${MEM_SIZE_GB} GB)${NC}"
        echo -e "${YELLOW}Starting test in 3 seconds...${NC}"
    else
        echo -e "\n${BLUE}测试配置：${NC}"
        echo -e "${YELLOW}时长：${TEST_TIME} 秒${NC}"
        echo -e "${YELLOW}内存使用率：${MEM_PERCENT}% (${MEM_SIZE_GB} GB)${NC}"
        echo -e "${YELLOW}测试将在3秒后开始...${NC}"
    fi
    
    sleep 3
    
    # Run stress test / 运行压力测试
    timeout ${TEST_TIME}s $STRESS_CMD --vm-bytes ${MEM_SIZE} --vm-keep -m 1 &
    STRESS_PID=$!
    
    # Get initial CPU time / 获取初始CPU时间
    get_cpu_stats() {
        read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
        total=$((user + nice + system + idle + iowait + irq + softirq + steal))
        idle_total=$((idle + iowait))
        echo "$total $idle_total"
    }

    prev_stats=$(get_cpu_stats)
    prev_total=$(echo $prev_stats | awk '{print $1}')
    prev_idle=$(echo $prev_stats | awk '{print $2}')

    # Monitor memory and swap space usage / 监控内存和交换空间使用情况
    if [ "$LANG" = "en" ]; then
        echo -e "\n${BLUE}Monitoring system resources...${NC}"
        echo -e "${YELLOW}Press Ctrl+C to stop the test early${NC}"
    else
        echo -e "\n${BLUE}正在监控系统资源...${NC}"
        echo -e "${YELLOW}按Ctrl+C可以提前停止测试${NC}"
    fi
    
    while kill -0 $STRESS_PID 2>/dev/null; do
        # Get memory information / 获取内存信息
        total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        avail_mem=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        used_mem=$((total_mem - avail_mem))
        mem_usage=$((used_mem * 100 / total_mem))
        used_mem_gb=$(echo "scale=2; $used_mem / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # Get swap space information / 获取交换空间信息
        total_swap=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
        free_swap=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
        used_swap=$((total_swap - free_swap))
        swap_usage=$((total_swap > 0 ? used_swap * 100 / total_swap : 0))
        used_swap_gb=$(echo "scale=2; $used_swap / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # Calculate CPU usage / 计算CPU使用率
        current_stats=$(get_cpu_stats)
        current_total=$(echo $current_stats | awk '{print $1}')
        current_idle=$(echo $current_stats | awk '{print $2}')
        
        total_diff=$((current_total - prev_total))
        idle_diff=$((current_idle - prev_idle))
        cpu_usage=$((100 * (total_diff - idle_diff) / total_diff))
        
        # Update previous stats / 更新之前的统计信息
        prev_total=$current_total
        prev_idle=$current_idle
        
        if [ "$LANG" = "en" ]; then
            echo -e "CPU Usage: ${cpu_usage}%  Memory Usage: ${mem_usage}% (${used_mem_gb}GB)  Swap Space: ${swap_usage}% (${used_swap_gb}GB)"
        else
            echo -e "CPU使用: ${cpu_usage}%  内存使用: ${mem_usage}% (${used_mem_gb}GB)  交换空间: ${swap_usage}% (${used_swap_gb}GB)"
        fi
        sleep 1  # Update every second / 每秒更新一次
    done
    
    if [ "$LANG" = "en" ]; then
        echo -e "\n${GREEN}✓ Test completed${NC}"
        echo -e "${BLUE}Final system status:${NC}"
    else
        echo -e "\n${GREEN}✓ 测试完成${NC}"
        echo -e "${BLUE}最终系统状态：${NC}"
    fi
    
    # Display post-test status / 显示测试后状态
    for i in {1..1}; do
        # Get memory information / 获取内存信息
        total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        avail_mem=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        used_mem=$((total_mem - avail_mem))
        mem_usage=$((used_mem * 100 / total_mem))
        used_mem_gb=$(echo "scale=2; $used_mem / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # Get swap space information / 获取交换空间信息
        total_swap=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
        free_swap=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
        used_swap=$((total_swap - free_swap))
        swap_usage=$((total_swap > 0 ? used_swap * 100 / total_swap : 0))
        used_swap_gb=$(echo "scale=2; $used_swap / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # Calculate CPU usage / 计算CPU使用率
        current_stats=$(get_cpu_stats)
        current_total=$(echo $current_stats | awk '{print $1}')
        current_idle=$(echo $current_stats | awk '{print $2}')
        
        total_diff=$((current_total - prev_total))
        idle_diff=$((current_idle - prev_idle))
        cpu_usage=$((100 * (total_diff - idle_diff) / total_diff))
        
        # Update previous stats / 更新之前的统计信息
        prev_total=$current_total
        prev_idle=$current_idle
        
        if [ "$LANG" = "en" ]; then
            echo -e "CPU Usage: ${cpu_usage}%  Memory Usage: ${mem_usage}% (${used_mem_gb}GB)  Swap Space: ${swap_usage}% (${used_swap_gb}GB)"
        else
            echo -e "CPU使用: ${cpu_usage}%  内存使用: ${mem_usage}% (${used_mem_gb}GB)  交换空间: ${swap_usage}% (${used_swap_gb}GB)"
        fi
        sleep 1  # Update every second / 每秒更新一次
    done
}

# Add uninstall function / 添加卸载函数
uninstall_program() {
    if [ "$LANG" = "en" ]; then
        echo -e "${BLUE}Preparing to uninstall...${NC}"
        echo -e "${YELLOW}Please select an uninstall option:${NC}"
        echo -e "${GREEN}1. Delete swap file only${NC}"
        echo -e "${GREEN}2. Delete program only${NC}"
        echo -e "${RED}3. Delete all (swap file and program)${NC}"
        echo -e "${BLUE}4. Cancel${NC}"
        read -p "Enter your choice (1-4): " uninstall_choice
    else
        echo -e "${BLUE}准备卸载...${NC}"
        echo -e "${YELLOW}请选择卸载选项：${NC}"
        echo -e "${GREEN}1. 仅删除交换文件${NC}"
        echo -e "${GREEN}2. 仅删除程序${NC}"
        echo -e "${RED}3. 删除所有（交换文件和程序）${NC}"
        echo -e "${BLUE}4. 取消${NC}"
        read -p "请输入选项（1-4）：" uninstall_choice
    fi
    
    case $uninstall_choice in
        1)  # Delete swap file only / 仅删除交换文件
            if [ "$LANG" = "en" ]; then
                echo -e "${YELLOW}This will only delete the swap file. The program will remain installed.${NC}"
                read -p "Are you sure you want to continue? (y/N): " confirm
            else
                echo -e "${YELLOW}这将仅删除交换文件。程序将保持安装状态。${NC}"
                read -p "确定要继续吗？(y/N)：" confirm
            fi
            
            if [[ $confirm =~ ^[Yy]$ ]]; then
                if [ -f /swapfile ]; then
                    if [ "$LANG" = "en" ]; then
                        echo -e "${BLUE}Deleting swap file...${NC}"
                    else
                        echo -e "${BLUE}正在删除交换文件...${NC}"
                    fi
                    sudo swapoff /swapfile 2>/dev/null
                    sudo rm -f /swapfile
                    sudo sed -i '/\/swapfile/d' /etc/fstab
                    if [ "$LANG" = "en" ]; then
                        echo -e "${GREEN}✓ Swap file deleted successfully${NC}"
                    else
                        echo -e "${GREEN}✓ 交换文件删除成功${NC}"
                    fi
                else
                    if [ "$LANG" = "en" ]; then
                        echo -e "${YELLOW}No swap file found${NC}"
                    else
                        echo -e "${YELLOW}未找到交换文件${NC}"
                    fi
                fi
            else
                if [ "$LANG" = "en" ]; then
                    echo -e "${BLUE}Operation cancelled${NC}"
                else
                    echo -e "${BLUE}操作已取消${NC}"
                fi
            fi
            ;;
            
        2)  # Delete program only / 仅删除程序
            if [ "$LANG" = "en" ]; then
                echo -e "${YELLOW}This will only delete the program. The swap file will remain.${NC}"
                read -p "Are you sure you want to continue? (y/N): " confirm
            else
                echo -e "${YELLOW}这将仅删除程序。交换文件将保留。${NC}"
                read -p "确定要继续吗？(y/N)：" confirm
            fi
            
            if [[ $confirm =~ ^[Yy]$ ]]; then
                if [ "$LANG" = "en" ]; then
                    echo -e "${BLUE}Deleting program...${NC}"
                else
                    echo -e "${BLUE}正在删除程序...${NC}"
                fi
                sudo rm -f /usr/local/bin/swap
                if [ "$LANG" = "en" ]; then
                    echo -e "${GREEN}✓ Program deleted successfully${NC}"
                else
                    echo -e "${GREEN}✓ 程序删除成功${NC}"
                fi
                exit 0
            else
                if [ "$LANG" = "en" ]; then
                    echo -e "${BLUE}Operation cancelled${NC}"
                else
                    echo -e "${BLUE}操作已取消${NC}"
                fi
            fi
            ;;
            
        3)  # Delete all / 删除所有
            if [ "$LANG" = "en" ]; then
                echo -e "${RED}This will delete both the swap file and the program.${NC}"
                echo -e "${RED}This action cannot be undone.${NC}"
                read -p "Are you sure you want to continue? (y/N): " confirm
            else
                echo -e "${RED}这将删除交换文件和程序。${NC}"
                echo -e "${RED}此操作无法撤销。${NC}"
                read -p "确定要继续吗？(y/N)：" confirm
            fi
            
            if [[ $confirm =~ ^[Yy]$ ]]; then
                # Delete swap file / 删除交换文件
                if [ -f /swapfile ]; then
                    if [ "$LANG" = "en" ]; then
                        echo -e "${BLUE}Deleting swap file...${NC}"
                    else
                        echo -e "${BLUE}正在删除交换文件...${NC}"
                    fi
                    sudo swapoff /swapfile 2>/dev/null
                    sudo rm -f /swapfile
                    sudo sed -i '/\/swapfile/d' /etc/fstab
                    if [ "$LANG" = "en" ]; then
                        echo -e "${GREEN}✓ Swap file deleted successfully${NC}"
                    else
                        echo -e "${GREEN}✓ 交换文件删除成功${NC}"
                    fi
                fi
                
                # Delete program / 删除程序
                if [ "$LANG" = "en" ]; then
                    echo -e "${BLUE}Deleting program...${NC}"
                else
                    echo -e "${BLUE}正在删除程序...${NC}"
                fi
                sudo rm -f /usr/local/bin/swap
                if [ "$LANG" = "en" ]; then
                    echo -e "${GREEN}✓ Program deleted successfully${NC}"
                else
                    echo -e "${GREEN}✓ 程序删除成功${NC}"
                fi
                exit 0
            else
                if [ "$LANG" = "en" ]; then
                    echo -e "${BLUE}Operation cancelled${NC}"
                else
                    echo -e "${BLUE}操作已取消${NC}"
                fi
            fi
            ;;
            
        4)  # Cancel / 取消
            if [ "$LANG" = "en" ]; then
                echo -e "${BLUE}Uninstall cancelled${NC}"
            else
                echo -e "${BLUE}卸载已取消${NC}"
            fi
            ;;
            
        *)
            if [ "$LANG" = "en" ]; then
                echo -e "${RED}✗ Invalid option, please enter a number between 1 and 4${NC}"
            else
                echo -e "${RED}✗ 无效选项，请输入1到4之间的数字${NC}"
            fi
            ;;
    esac
}

# Main loop / 主循环
while true; do
    show_menu
    if [ "$LANG" = "en" ]; then
        read -p "Please enter your choice (1-7): " choice
    else
        read -p "请输入选项（1-7）：" choice
    fi

    # Validate input is a number / 验证输入是否为数字
    if ! [[ "$choice" =~ ^[1-7]$ ]]; then
        if [ "$LANG" = "en" ]; then
            echo -e "${RED}✗ Invalid option, please enter a number between 1 and 7.${NC}"
        else
            echo -e "${RED}✗ 无效选项，请输入1到7之间的数字。${NC}"
        fi
        continue
    fi

    case $choice in
        1) 
            # Create swap file / 创建交换文件
            if [ "$LANG" = "en" ]; then
                echo -e "${BLUE}Creating swap file...${NC}"
            else
                echo -e "${BLUE}正在创建交换文件...${NC}"
            fi
            create_swap 
            ;;
        2) 
            # Delete swap file / 删除交换文件
            if [ "$LANG" = "en" ]; then
                echo -e "${BLUE}Deleting swap file...${NC}"
            else
                echo -e "${BLUE}正在删除交换文件...${NC}"
            fi
            delete_swap 
            ;;
        3) 
            # View swap information / 查看交换空间信息
            view_swap 
            ;;
        4) 
            # Adjust memory swappiness / 调整内存交换倾向性
            if [ "$LANG" = "en" ]; then
                echo -e "${BLUE}Adjusting memory swappiness...${NC}"
            else
                echo -e "${BLUE}正在调整内存交换倾向性...${NC}"
            fi
            adjust_swappiness 
            ;;
        5) 
            # Start memory stress test / 启动内存压力测试
            if [ "$LANG" = "en" ]; then
                echo -e "${BLUE}Starting memory stress test...${NC}"
            else
                echo -e "${BLUE}正在启动内存压力测试...${NC}"
            fi
            stress_test 
            ;;
        6) 
            # Uninstall program / 卸载程序
            if [ "$LANG" = "en" ]; then
                echo -e "${BLUE}Preparing to uninstall...${NC}"
            else
                echo -e "${BLUE}准备卸载...${NC}"
            fi
            uninstall_program 
            ;;
        7) 
            # Exit program / 退出程序
            if [ "$LANG" = "en" ]; then
                echo -e "${GREEN}Thank you for using Swap Manager. Goodbye!${NC}"
            else
                echo -e "${GREEN}感谢使用交换空间管理器。再见！${NC}"
            fi
            break 
            ;;
    esac
done
