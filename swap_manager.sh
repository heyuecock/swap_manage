#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 重置颜色

# 语言设置
LANG_FILE="/tmp/swap_manager_lang"
if [ -f "$LANG_FILE" ]; then
    LANG=$(cat "$LANG_FILE")
else
    echo -e "${BLUE}Please select language / 请选择语言：${NC}"
    echo -e "1. English"
    echo -e "2. 中文"
    read -p "Enter your choice (1-2) / 请输入选项 (1-2): " lang_choice
    case $lang_choice in
        1) LANG="en" ;;
        2) LANG="zh" ;;
        *) LANG="en" ;;
    esac
    echo "$LANG" > "$LANG_FILE"
fi

# 语言文本定义
declare -A TEXT
if [ "$LANG" = "en" ]; then
    TEXT=(
        ["menu_title"]="========== Swap File Management Menu =========="
        ["create_swap"]="1. Create Swap File"
        ["delete_swap"]="2. Delete Swap File"
        ["view_swap"]="3. View Current Swap Information"
        ["adjust_swappiness"]="4. Adjust Memory Swappiness"
        ["stress_test"]="5. Memory Stress Test"
        ["uninstall"]="6. Uninstall Program"
        ["exit"]="7. Exit"
        ["menu_footer"]="====================================="
        ["invalid_option"]="Invalid option, please try again."
        ["swap_size_prompt"]="Enter swap file size (MB, range 100-5120, default 1024MB):"
        ["invalid_size"]="Invalid input, please enter an integer between 100 and 5120."
        ["disk_space"]="Current available disk space:"
        ["insufficient_space"]="Insufficient disk space, available:"
        ["needed_space"]="Required:"
        ["creating_swap"]="Creating"
        ["swap_file"]="swap file..."
        ["formatting"]="Formatting swap file..."
        ["enabling"]="Enabling swap file..."
        ["success"]="Virtual memory successfully created and enabled. Current memory and swap information:"
        ["deleting_swap"]="Deleting swap file"
        ["swap_not_found"]="Swap file not found"
        ["swap_deleted"]="Swap file deleted"
        ["current_swappiness"]="Current memory swappiness value:"
        ["swappiness_desc"]="Lower value means less swap usage; higher value means more swap usage."
        ["recommended_value"]="Recommended value: 10-60"
        ["enter_new_value"]="Enter new memory swappiness value (0-100, recommended 10-60):"
        ["invalid_swappiness"]="Invalid input, please enter an integer between 0 and 100."
        ["modify_method"]="Please select modification method:"
        ["temp_modify"]="1. Temporary modification (effective immediately, reset after reboot)"
        ["perm_modify"]="2. Permanent modification (effective immediately and persists after reboot)"
        ["enter_option"]="Enter option (1-2):"
        ["temp_modified"]="Memory swappiness value temporarily modified to"
        ["perm_modified"]="Memory swappiness value permanently modified to"
        ["invalid_method"]="Invalid option, no changes made."
        ["preparing_test"]="Preparing memory stress test..."
        ["installing_tools"]="Installing stress testing tools..."
        ["enter_test_time"]="Enter stress test duration (seconds, default 5):"
        ["invalid_time"]="Invalid input, please enter a positive integer (seconds)."
        ["enter_mem_percent"]="Enter memory usage percentage relative to system memory (10-1000, default 90):"
        ["invalid_percent"]="Invalid input, please enter an integer between 10 and 1000."
        ["test_starting"]="Starting memory stress test, using"
        ["system_memory"]="system memory, duration"
        ["seconds"]="seconds"
        ["monitoring"]="Monitoring memory and swap space usage:"
        ["note"]="Note: When using more than 100% system memory, OOM Killer may terminate the process."
        ["test_ended"]="Stress test completed"
        ["uninstall_preparing"]="Preparing to uninstall..."
        ["uninstall_options"]="Please select uninstall option:"
        ["delete_swap_only"]="1. Delete swap file only"
        ["delete_program_only"]="2. Delete program only"
        ["delete_all"]="3. Delete swap file and program"
        ["cancel"]="4. Cancel"
        ["enter_option_uninstall"]="Enter option (1-4):"
        ["confirm_delete_swap"]="Are you sure you want to delete the swap file? (y/n):"
        ["confirm_delete_program"]="Are you sure you want to delete the program? (y/n):"
        ["confirm_delete_all"]="Are you sure you want to delete the swap file and program? (y/n):"
        ["deleting"]="Deleting"
        ["program"]="program..."
        ["program_deleted"]="Program deleted"
        ["uninstall_cancelled"]="Uninstall cancelled"
        ["not_root"]="Not running as root user."
        ["sudo_not_found"]="sudo not detected."
        ["alpine_instructions"]="On Alpine Linux, please use the following command:"
        ["then_run"]="Then run with:"
        ["system_not_supported"]="This system may not support swap functionality."
        ["alpine_detected"]="Alpine Linux system detected"
        ["missing_packages"]="Missing required packages:"
        ["installing_packages"]="Installing required packages..."
        ["packages_installed"]="Required packages installed successfully"
        ["package_install_failed"]="Package installation failed, please run the following command manually:"
        ["loading_kernel_module"]="Loading swap kernel module..."
        ["fs_not_supported"]="Root filesystem does not support file creation, please check filesystem permissions."
        ["swapon_not_supported"]="System does not support swapon command, cannot create swap file."
    )
else
    TEXT=(
        ["menu_title"]="========== 交换文件管理菜单 =========="
        ["create_swap"]="1. 创建交换文件"
        ["delete_swap"]="2. 删除交换文件"
        ["view_swap"]="3. 查看当前交换空间信息"
        ["adjust_swappiness"]="4. 调整内存交换倾向性"
        ["stress_test"]="5. 内存压力测试"
        ["uninstall"]="6. 卸载程序"
        ["exit"]="7. 退出"
        ["menu_footer"]="====================================="
        ["invalid_option"]="无效选项，请重新输入。"
        ["swap_size_prompt"]="请输入交换文件大小（单位：MB，范围100-5120，默认1024MB）："
        ["invalid_size"]="输入值无效，请输入100到5120之间的整数。"
        ["disk_space"]="当前可用磁盘空间:"
        ["insufficient_space"]="磁盘空间不足，可用空间:"
        ["needed_space"]="需要:"
        ["creating_swap"]="正在创建"
        ["swap_file"]="的交换文件..."
        ["formatting"]="正在格式化交换文件..."
        ["enabling"]="正在启用交换文件..."
        ["success"]="虚拟内存已成功创建并启用。当前内存和交换空间信息："
        ["deleting_swap"]="正在删除交换文件"
        ["swap_not_found"]="未找到交换文件"
        ["swap_deleted"]="交换文件已删除"
        ["current_swappiness"]="当前内存交换倾向性值："
        ["swappiness_desc"]="值越低，越少使用交换空间；值越高，越多使用交换空间。"
        ["recommended_value"]="推荐值：10-60"
        ["enter_new_value"]="请输入新的内存交换倾向性值（0-100，推荐10-60）："
        ["invalid_swappiness"]="输入值无效，请输入0到100之间的整数。"
        ["modify_method"]="请选择修改方式："
        ["temp_modify"]="1. 临时修改（立即生效，重启后失效）"
        ["perm_modify"]="2. 永久修改（立即生效且重启后仍然有效）"
        ["enter_option"]="请输入选项（1-2）："
        ["temp_modified"]="内存交换倾向性值已临时修改为"
        ["perm_modified"]="内存交换倾向性值已永久修改为"
        ["invalid_method"]="无效选项，未进行任何修改。"
        ["preparing_test"]="正在准备内存压力测试..."
        ["installing_tools"]="正在安装压力测试工具..."
        ["enter_test_time"]="请输入压力测试时间（单位：秒，默认5秒）："
        ["invalid_time"]="输入值无效，请输入大于0的整数（单位：秒）。"
        ["enter_mem_percent"]="请输入压测内存使用量，相对于系统内存的百分比（10-1000，默认90）："
        ["invalid_percent"]="输入值无效，请输入10到1000之间的整数。"
        ["test_starting"]="即将开始内存压力测试，使用"
        ["system_memory"]="系统内存，持续"
        ["seconds"]="秒"
        ["monitoring"]="实时监控内存和交换空间使用情况："
        ["note"]="注意：当使用超过100%系统内存时，可能会触发OOM Killer终止进程。"
        ["test_ended"]="压力测试结束"
        ["uninstall_preparing"]="准备卸载..."
        ["uninstall_options"]="请选择卸载选项："
        ["delete_swap_only"]="1. 仅删除交换文件"
        ["delete_program_only"]="2. 仅删除程序"
        ["delete_all"]="3. 删除交换文件和程序"
        ["cancel"]="4. 取消"
        ["enter_option_uninstall"]="请输入选项（1-4）："
        ["confirm_delete_swap"]="确定要删除交换文件吗？(y/n):"
        ["confirm_delete_program"]="确定要删除程序吗？(y/n):"
        ["confirm_delete_all"]="确定要删除交换文件和程序吗？(y/n):"
        ["deleting"]="正在删除"
        ["program"]="程序..."
        ["program_deleted"]="程序已删除"
        ["uninstall_cancelled"]="取消卸载"
        ["not_root"]="未检测到sudo。"
        ["sudo_not_found"]="未检测到sudo。"
        ["alpine_instructions"]="在Alpine Linux中，请使用以下命令："
        ["then_run"]="然后使用以下命令运行："
        ["system_not_supported"]="此系统可能不支持交换空间功能。"
        ["alpine_detected"]="检测到Alpine Linux系统"
        ["missing_packages"]="检测到缺少必要的包:"
        ["installing_packages"]="正在自动安装必要的包..."
        ["packages_installed"]="必要的包安装成功"
        ["package_install_failed"]="包安装失败，请手动运行以下命令："
        ["loading_kernel_module"]="正在加载swap内核模块..."
        ["fs_not_supported"]="根文件系统不支持创建文件，请检查文件系统权限。"
        ["swapon_not_supported"]="系统不支持 swapon 命令，无法创建交换文件。"
    )
fi

# 检查是否为root用户，如果不是则尝试使用sudo或提示使用root
if [ "$EUID" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        exec sudo "$0" "$@"
    else
        echo -e "${YELLOW}未检测到sudo。${NC}"
        echo -e "${BLUE}在Alpine Linux中，请使用以下命令：${NC}"
        echo -e "${GREEN}su -c 'wget -qO /usr/local/bin/swap https://raw.githubusercontent.com/heyuecock/swap_manage/refs/heads/main/swap_manager.sh && chmod +x /usr/local/bin/swap'${NC}"
        echo -e "${BLUE}然后使用以下命令运行：${NC}"
        echo -e "${GREEN}su -c swap${NC}"
        exit 1
    fi
fi

# 检查并安装必要依赖
check_dependencies() {
    # 检查包管理器
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
        echo -e "${RED}✗ 未能识别系统的包管理器。${NC}"
        exit 1
    fi

    # 检查并安装基本工具
    MISSING_TOOLS=()
    
    # 检查基本工具
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

    # 安装缺失的基本工具
    if [ ${#MISSING_TOOLS[@]} -ne 0 ]; then
        echo -e "${YELLOW}正在安装必要工具: ${MISSING_TOOLS[*]}${NC}"
        if [ "$PKG_MANAGER" = "apk" ]; then
            if ! $INSTALL_CMD "${MISSING_TOOLS[@]}"; then
                echo -e "${RED}✗ 工具安装失败。请手动安装以下包: ${MISSING_TOOLS[*]}${NC}"
                exit 1
            fi
        else
            if ! sudo $INSTALL_CMD "${MISSING_TOOLS[@]}"; then
                echo -e "${RED}✗ 工具安装失败。请手动安装以下包: ${MISSING_TOOLS[*]}${NC}"
                exit 1
            fi
        fi
    fi
}

# 系统兼容性检查
check_system_compatibility() {
    # 检查是否支持swap
    if ! grep -q "SwapTotal" /proc/meminfo; then
        echo -e "${RED}✗ 此系统可能不支持交换空间功能。${NC}"
        exit 1
    fi

    # Alpine特殊处理
    if [ -f /etc/alpine-release ]; then
        echo -e "${YELLOW}检测到Alpine Linux系统${NC}"
        
        # 检查必要的包
        MISSING_PKGS=()
        for pkg in sudo wget bash util-linux-misc bc; do
            if ! command -v $pkg >/dev/null 2>&1; then
                MISSING_PKGS+=($pkg)
            fi
        done
        
        if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
            echo -e "${YELLOW}检测到缺少必要的包: ${MISSING_PKGS[*]}${NC}"
            echo -e "${BLUE}正在自动安装必要的包...${NC}"
            
            # 尝试直接使用apk安装
            if apk add ${MISSING_PKGS[*]}; then
                echo -e "${GREEN}✓ 必要的包安装成功${NC}"
            else
                echo -e "${RED}✗ 包安装失败，请手动运行以下命令：${NC}"
                echo -e "apk add ${MISSING_PKGS[*]}"
                exit 1
            fi
        fi

        # 检查必要的内核模块
        if ! grep -q "swap" /proc/modules; then
            echo -e "${YELLOW}正在加载swap内核模块...${NC}"
            modprobe swap
        fi
    fi

    # 检查文件系统支持
    if ! touch /.swap_test_file 2>/dev/null; then
        echo -e "${RED}✗ 根文件系统不支持创建文件，请检查文件系统权限。${NC}"
        exit 1
    fi
    rm -f /.swap_test_file
}

# 在主程序开始时调用
check_system_compatibility
check_dependencies

# 检查系统是否支持交换文件
if ! swapon --version &>/dev/null; then
    echo -e "${RED}✗ 系统不支持 swapon 命令，无法创建交换文件。${NC}"
    exit 1
fi

# 菜单函数（带颜色）
show_menu() {
    echo -e "\n${BLUE}${TEXT["menu_title"]}${NC}"
    echo -e "${GREEN}${TEXT["create_swap"]}${NC}"
    echo -e "${GREEN}${TEXT["delete_swap"]}${NC}"
    echo -e "${GREEN}${TEXT["view_swap"]}${NC}"
    echo -e "${GREEN}${TEXT["adjust_swappiness"]}${NC}"
    echo -e "${GREEN}${TEXT["stress_test"]}${NC}"
    echo -e "${RED}${TEXT["uninstall"]}${NC}"
    echo -e "${RED}${TEXT["exit"]}${NC}"
    echo -e "${BLUE}${TEXT["menu_footer"]}${NC}\n"
}

# 创建交换文件
create_swap() {
    while true; do
        read -p "${TEXT["swap_size_prompt"]}" SWAP_SIZE
        SWAP_SIZE=${SWAP_SIZE:-1024}  # 如果用户未输入，则默认1024MB
        
        # 验证输入是否合法
        if [[ $SWAP_SIZE =~ ^[0-9]+$ ]]; then
            if (( SWAP_SIZE >= 100 && SWAP_SIZE <= 5120 )); then
                break
            fi
        fi
        echo -e "${YELLOW}${TEXT["invalid_size"]}${NC}"
    done

    # 检查磁盘空间是否足够(以MB为单位进行比较)
    DISK_SPACE=$(df -BM / | awk 'NR==2 {print $4}' | tr -d 'M')
    echo -e "${BLUE}${TEXT["disk_space"]} ${DISK_SPACE}MB${NC}"
    
    if [ -z "$DISK_SPACE" ] || ! [[ "$DISK_SPACE" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}✗ ${TEXT["disk_space"]}${NC}"
        return
    fi
    
    if (( DISK_SPACE < SWAP_SIZE )); then
        echo -e "${YELLOW}⚠️ ${TEXT["insufficient_space"]} ${DISK_SPACE}MB，${TEXT["needed_space"]} ${SWAP_SIZE}MB${NC}"
        return
    fi

    # 检查是否存在旧的交换文件
    if [ -f /swapfile ]; then
        echo -e "${BLUE}${TEXT["deleting_swap"]} /swapfile...${NC}"
        sudo swapoff /swapfile 2>/dev/null
        sudo rm -f /swapfile
    fi

    # 创建交换文件
    echo -e "${BLUE}${TEXT["creating_swap"]} ${SWAP_SIZE}MB ${TEXT["swap_file"]}${NC}"
    sudo fallocate -l ${SWAP_SIZE}M /swapfile
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ ${TEXT["creating_swap"]}${NC}"
        return
    fi

    # 设置文件权限
    sudo chmod 600 /swapfile

    # 格式化交换文件
    echo -e "${BLUE}${TEXT["formatting"]}${NC}"
    sudo mkswap /swapfile
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ ${TEXT["formatting"]}${NC}"
        sudo rm -f /swapfile
        return
    fi

    # 启用交换文件
    echo -e "${BLUE}${TEXT["enabling"]}${NC}"
    sudo swapon /swapfile
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ ${TEXT["enabling"]}${NC}"
        sudo rm -f /swapfile
        return
    fi

    # 永久生效
    if ! grep -q '/swapfile' /etc/fstab; then
        echo -e "${BLUE}${TEXT["enabling"]}${NC}"
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi

    # 输出结果
    echo -e "${GREEN}✓ ${TEXT["success"]}${NC}"
    free -h
}

# 删除交换文件
delete_swap() {
    if [ -f /swapfile ]; then
        echo -e "${BLUE}[$(date +"%Y-%m-%d %H:%M:%S")] INFO: ${TEXT["deleting_swap"]} /swapfile...${NC}"
        sudo swapoff /swapfile 2>/dev/null
        sudo rm -f /swapfile
        # 从 /etc/fstab 中移除交换文件配置
        sudo sed -i '/\/swapfile/d' /etc/fstab
        echo -e "${GREEN}✓ ${TEXT["swap_deleted"]}${NC}"
    else
        echo -e "${BLUE}⚠️ ${TEXT["swap_not_found"]} /swapfile${NC}"
    fi
}

# 查看当前交换空间信息
view_swap() {
    if swapon --show | grep -q '/'; then
        # 获取详细内存信息
        mem_info=$(free -m | awk 'NR==2')
        total_mem=$(echo $mem_info | awk '{print $2}')
        used_mem=$(echo $mem_info | awk '{print $3}')
        free_mem=$(echo $mem_info | awk '{print $4}')
        shared_mem=$(echo $mem_info | awk '{print $5}')
        buff_cache=$(echo $mem_info | awk '{print $6}')
        available_mem=$(free -m | awk 'NR==2 {print $7}')
        
        # 获取交换空间信息
        swap_info=$(free -m | awk 'NR==3')
        total_swap=$(echo $swap_info | awk '{print $2}')
        used_swap=$(echo $swap_info | awk '{print $3}')
        free_swap=$(echo $swap_info | awk '{print $4}')
        
        # 计算交换空间使用率
        if [ "$total_swap" -gt 0 ]; then
            swap_usage=$((used_swap * 100 / total_swap))
        else
            swap_usage=0
        fi
        
        # 计算使用率
        mem_usage=$((used_mem * 100 / total_mem))
        available_percent=$((available_mem * 100 / total_mem))
        
        # 获取磁盘信息
        disk_info=$(df -h / | awk 'NR==2')
        disk_total=$(echo $disk_info | awk '{print $2}')
        disk_used=$(echo $disk_info | awk '{print $3}')
        disk_avail=$(echo $disk_info | awk '{print $4}')
        disk_usage=$(echo $disk_info | awk '{print $5}')
        

        
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
    else
        echo -e "${BLUE}未启用交换空间。${NC}"
    fi
}

# 调整内存交换倾向性
adjust_swappiness() {
    CURRENT_SWAPPINESS=$(cat /proc/sys/vm/swappiness)
    # 显示简要说明
    echo -e "${YELLOW}${TEXT["current_swappiness"]}${CURRENT_SWAPPINESS}${NC}"
    echo -e "${YELLOW}${TEXT["swappiness_desc"]}${NC}"
    echo -e "${YELLOW}${TEXT["recommended_value"]}${NC}"
    
    # 获取新值
    while true; do
        read -p "${TEXT["enter_new_value"]}" SWAPPINESS
        SWAPPINESS=${SWAPPINESS:-$CURRENT_SWAPPINESS}  # 如果用户未输入，保持当前值
        
        # 验证输入是否合法
        if [[ $SWAPPINESS =~ ^[0-9]+$ ]] && [ $SWAPPINESS -ge 0 ] && [ $SWAPPINESS -le 100 ]; then
            break
        else
            echo -e "${RED}⚠️ ${TEXT["invalid_swappiness"]}${NC}"
        fi
    done

    # 让用户选择修改方式
    echo -e "\n${BLUE}${TEXT["modify_method"]}${NC}"
    echo -e "${YELLOW}${TEXT["temp_modify"]}${NC}"
    echo -e "${YELLOW}${TEXT["perm_modify"]}${NC}"
    read -p "${TEXT["enter_option"]}" MODE

    case $MODE in
        1)
            # 临时修改（立即生效）
            sudo sysctl vm.swappiness=$SWAPPINESS
            echo -e "${GREEN}✓ ${TEXT["temp_modified"]} $SWAPPINESS${NC}"
            ;;
        2)
            # 永久修改并立即生效
            CONFIG_FILE="/etc/sysctl.conf"
            if grep -q '^vm.swappiness=' $CONFIG_FILE; then
                sudo sed -i "s/^vm.swappiness=.*/vm.swappiness=$SWAPPINESS/" $CONFIG_FILE
            else
                echo "vm.swappiness=$SWAPPINESS" | sudo tee -a $CONFIG_FILE > /dev/null
            fi
            # 立即生效
            sudo sysctl -p
            echo -e "${GREEN}✓ ${TEXT["perm_modified"]} $SWAPPINESS${NC}"
            ;;
        *)
            echo -e "${RED}⚠️ ${TEXT["invalid_method"]}${NC}"
            ;;
    esac
}

# 内存压力测试
stress_test() {
    echo -e "${BLUE}${TEXT["preparing_test"]}${NC}"
    
    # 检查是否安装stress/stress-ng
    if ! command -v stress &> /dev/null && ! command -v stress-ng &> /dev/null; then
        echo -e "${YELLOW}${TEXT["installing_tools"]}${NC}"
        
        case $PKG_MANAGER in
            "apk")
                if ! apk add stress-ng; then
                    echo -e "${RED}✗ stress-ng ${TEXT["package_install_failed"]}${NC}"
                    return 1
                fi
                STRESS_CMD="stress-ng"
                ;;
            "apt-get")
                if ! sudo apt-get install -y stress; then
                    echo -e "${RED}✗ stress ${TEXT["package_install_failed"]}${NC}"
                    return 1
                fi
                STRESS_CMD="stress"
                ;;
            "yum")
                if ! sudo yum install -y stress; then
                    echo -e "${RED}✗ stress ${TEXT["package_install_failed"]}${NC}"
                    return 1
                fi
                STRESS_CMD="stress"
                ;;
            "pacman")
                if ! sudo pacman -S --noconfirm stress; then
                    echo -e "${RED}✗ stress ${TEXT["package_install_failed"]}${NC}"
                    return 1
                fi
                STRESS_CMD="stress"
                ;;
        esac
    else
        STRESS_CMD=$(command -v stress-ng || command -v stress)
    fi

    # 获取测试时间
    while true; do
        read -p "${TEXT["enter_test_time"]}" TEST_TIME
        TEST_TIME=${TEST_TIME:-5}  # 如果用户未输入，则默认5秒
        
        # 验证输入是否合法
        if [[ $TEST_TIME =~ ^[0-9]+$ ]] && [ $TEST_TIME -gt 0 ]; then
            break
        else
            echo -e "${RED}✗ ${TEXT["invalid_time"]}${NC}"
        fi
    done

    # 获取可用内存
    total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    
    # 让用户输入内存使用百分比
    while true; do
        read -p "${TEXT["enter_mem_percent"]}" MEM_PERCENT
        MEM_PERCENT=${MEM_PERCENT:-90}  # 如果用户未输入，则默认90%
        
        # 验证输入是否合法
        if [[ $MEM_PERCENT =~ ^[0-9]+$ ]] && [ $MEM_PERCENT -ge 10 ] && [ $MEM_PERCENT -le 1000 ]; then
            break
        else
            echo -e "${RED}✗ ${TEXT["invalid_percent"]}${NC}"
        fi
    done

    # 计算测试内存大小
    MEM_RATIO=$(echo "scale=2; $MEM_PERCENT / 100" | bc)
    MEM_SIZE=$(echo "$total_mem * 1024 * $MEM_RATIO" | bc | awk '{printf "%d\n", $0}')
    MEM_SIZE_GB=$(echo "scale=2; $MEM_SIZE / 1024 / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
    
    echo -e "${YELLOW}${TEXT["test_starting"]} ${MEM_SIZE_GB} GB ${TEXT["system_memory"]} ${TEST_TIME} ${TEXT["seconds"]}${NC}"
    
    # 运行压力测试
    timeout ${TEST_TIME}s $STRESS_CMD --vm-bytes ${MEM_SIZE} --vm-keep -m 1 &
    STRESS_PID=$!
    
    # 获取初始CPU时间
    get_cpu_stats() {
        read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
        total=$((user + nice + system + idle + iowait + irq + softirq + steal))
        idle_total=$((idle + iowait))
        echo "$total $idle_total"
    }

    prev_stats=$(get_cpu_stats)
    prev_total=$(echo $prev_stats | awk '{print $1}')
    prev_idle=$(echo $prev_stats | awk '{print $2}')

    # 实时监控内存和交换空间使用情况
    echo -e "${BLUE}${TEXT["monitoring"]}${NC}"
    echo -e "${YELLOW}${TEXT["note"]}${NC}"
    while kill -0 $STRESS_PID 2>/dev/null; do
        # 获取内存信息
        total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        avail_mem=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        used_mem=$((total_mem - avail_mem))
        mem_usage=$((used_mem * 100 / total_mem))
        # 转换内存使用量为GB，确保有前导零
        used_mem_gb=$(echo "scale=2; $used_mem / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # 获取交换空间信息
        total_swap=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
        free_swap=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
        used_swap=$((total_swap - free_swap))
        swap_usage=$((total_swap > 0 ? used_swap * 100 / total_swap : 0))
        # 转换交换空间使用量为GB，确保有前导零
        used_swap_gb=$(echo "scale=2; $used_swap / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # 计算CPU使用率
        current_stats=$(get_cpu_stats)
        current_total=$(echo $current_stats | awk '{print $1}')
        current_idle=$(echo $current_stats | awk '{print $2}')
        
        total_diff=$((current_total - prev_total))
        idle_diff=$((current_idle - prev_idle))
        cpu_usage=$((100 * (total_diff - idle_diff) / total_diff))
        
        # 更新前一次统计
        prev_total=$current_total
        prev_idle=$current_idle
        
        echo -e "CPU使用: ${cpu_usage}%  内存使用: ${mem_usage}% (${used_mem_gb}GB)  交换空间: ${swap_usage}% (${used_swap_gb}GB)"
        sleep 1  # 每秒更新一次
    done
    
    echo -e "${GREEN}✓ ${TEXT["test_ended"]}${NC}"
    # 显示测试后状态
    for i in {1..1}; do
        # 获取内存信息
        total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        avail_mem=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
        used_mem=$((total_mem - avail_mem))
        mem_usage=$((used_mem * 100 / total_mem))
        used_mem_gb=$(echo "scale=2; $used_mem / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # 获取交换空间信息
        total_swap=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
        free_swap=$(awk '/SwapFree/ {print $2}' /proc/meminfo)
        used_swap=$((total_swap - free_swap))
        swap_usage=$((total_swap > 0 ? used_swap * 100 / total_swap : 0))
        used_swap_gb=$(echo "scale=2; $used_swap / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
        
        # 计算CPU使用率
        current_stats=$(get_cpu_stats)
        current_total=$(echo $current_stats | awk '{print $1}')
        current_idle=$(echo $current_stats | awk '{print $2}')
        
        total_diff=$((current_total - prev_total))
        idle_diff=$((current_idle - prev_idle))
        cpu_usage=$((100 * (total_diff - idle_diff) / total_diff))
        
        # 更新前一次统计
        prev_total=$current_total
        prev_idle=$current_idle
        
        echo -e "CPU使用: ${cpu_usage}%  内存使用: ${mem_usage}% (${used_mem_gb}GB)  交换空间: ${swap_usage}% (${used_swap_gb}GB)"
        sleep 1  # 每秒更新一次
    done
}

# 添加卸载函数
uninstall_program() {
    echo -e "${YELLOW}${TEXT["uninstall_preparing"]}${NC}"
    
    echo -e "\n${BLUE}${TEXT["uninstall_options"]}${NC}"
    echo -e "${GREEN}${TEXT["delete_swap_only"]}${NC}"
    echo -e "${GREEN}${TEXT["delete_program_only"]}${NC}"
    echo -e "${RED}${TEXT["delete_all"]}${NC}"
    echo -e "${BLUE}${TEXT["cancel"]}${NC}"
    
    read -p "${TEXT["enter_option_uninstall"]}" uninstall_choice
    
    case $uninstall_choice in
        1)  # 仅删除交换文件
            read -p "${TEXT["confirm_delete_swap"]}" confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                if [ -f /swapfile ]; then
                    echo -e "${BLUE}${TEXT["deleting"]} ${TEXT["swap_file"]}${NC}"
                    sudo swapoff /swapfile 2>/dev/null
                    sudo rm -f /swapfile
                    sudo sed -i '/\/swapfile/d' /etc/fstab
                    echo -e "${GREEN}✓ ${TEXT["swap_deleted"]}${NC}"
                else
                    echo -e "${YELLOW}${TEXT["swap_not_found"]}${NC}"
                fi
            else
                echo -e "${BLUE}${TEXT["uninstall_cancelled"]}${NC}"
            fi
            ;;
            
        2)  # 仅删除程序
            read -p "${TEXT["confirm_delete_program"]}" confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                echo -e "${BLUE}${TEXT["deleting"]} ${TEXT["program"]}${NC}"
                sudo rm -f /usr/local/bin/swap
                echo -e "${GREEN}✓ ${TEXT["program_deleted"]}${NC}"
                exit 0
            else
                echo -e "${BLUE}${TEXT["uninstall_cancelled"]}${NC}"
            fi
            ;;
            
        3)  # 删除全部
            read -p "${TEXT["confirm_delete_all"]}" confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                # 删除交换文件
                if [ -f /swapfile ]; then
                    echo -e "${BLUE}${TEXT["deleting"]} ${TEXT["swap_file"]}${NC}"
                    sudo swapoff /swapfile 2>/dev/null
                    sudo rm -f /swapfile
                    sudo sed -i '/\/swapfile/d' /etc/fstab
                    echo -e "${GREEN}✓ ${TEXT["swap_deleted"]}${NC}"
                fi
                
                # 删除程序
                echo -e "${BLUE}${TEXT["deleting"]} ${TEXT["program"]}${NC}"
                sudo rm -f /usr/local/bin/swap
                echo -e "${GREEN}✓ ${TEXT["program_deleted"]}${NC}"
                exit 0
            else
                echo -e "${BLUE}${TEXT["uninstall_cancelled"]}${NC}"
            fi
            ;;
            
        4)  # 取消
            echo -e "${BLUE}${TEXT["uninstall_cancelled"]}${NC}"
            ;;
            
        *)
            echo -e "${RED}✗ ${TEXT["invalid_option"]}${NC}"
            ;;
    esac
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项（1-7）：" choice

    case $choice in
        1) create_swap ;;
        2) delete_swap ;;
        3) view_swap ;;
        4) adjust_swappiness ;;
        5) stress_test ;;
        6) uninstall_program ;;
        7) break ;;
        *) echo -e "${RED}✗ 无效选项，请重新输入。${NC}" ;;
    esac
done
