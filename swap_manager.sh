#!/bin/bash

# 定义颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 重置颜色

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
    echo -e "\n${BLUE}========== 交换文件管理菜单 ==========${NC}"
    echo -e "${GREEN}1. 创建交换文件${NC}"
    echo -e "${GREEN}2. 删除交换文件${NC}"
    echo -e "${GREEN}3. 查看当前交换空间信息${NC}"
    echo -e "${GREEN}4. 调整内存交换倾向性${NC}"
    echo -e "${GREEN}5. 内存压力测试${NC}"
    echo -e "${RED}6. 卸载程序${NC}"
    echo -e "${RED}7. 退出${NC}"
    echo -e "${BLUE}=====================================${NC}\n"
}

# 创建交换文件
create_swap() {
    while true; do
        read -p "请输入交换文件大小（单位：MB，范围100-5120，默认1024MB）：" SWAP_SIZE
        SWAP_SIZE=${SWAP_SIZE:-1024}  # 如果用户未输入，则默认1024MB
        
        # 验证输入是否合法
        if [[ $SWAP_SIZE =~ ^[0-9]+$ ]]; then
            if (( SWAP_SIZE >= 100 && SWAP_SIZE <= 5120 )); then
                break
            fi
        fi
        echo -e "${YELLOW}⚠️ 输入值无效，请输入100到5120之间的整数。${NC}"
    done

    # 检查磁盘空间是否足够(以MB为单位进行比较)
    DISK_SPACE=$(df -BM / | awk 'NR==2 {print $4}' | tr -d 'M')
    echo -e "${BLUE}当前可用磁盘空间: ${DISK_SPACE}MB${NC}"
    
    if [ -z "$DISK_SPACE" ] || ! [[ "$DISK_SPACE" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}✗ 无法获取磁盘空间信息${NC}"
        return
    fi
    
    if (( DISK_SPACE < SWAP_SIZE )); then
        echo -e "${YELLOW}⚠️ 磁盘空间不足，可用空间: ${DISK_SPACE}MB，需要: ${SWAP_SIZE}MB${NC}"
        return
    fi

    # 检查是否存在旧的交换文件
    if [ -f /swapfile ]; then
        echo -e "${BLUE}正在删除旧的交换文件 /swapfile...${NC}"
        sudo swapoff /swapfile 2>/dev/null
        sudo rm -f /swapfile
    fi

    # 创建交换文件
    echo -e "${BLUE}正在创建 ${SWAP_SIZE}MB 的交换文件...${NC}"
    sudo fallocate -l ${SWAP_SIZE}M /swapfile
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 交换文件创建失败，请检查磁盘空间。${NC}"
        return
    fi

    # 设置文件权限
    sudo chmod 600 /swapfile

    # 格式化交换文件
    echo -e "${BLUE}正在格式化交换文件...${NC}"
    sudo mkswap /swapfile
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 交换文件格式化失败。${NC}"
        sudo rm -f /swapfile
        return
    fi

    # 启用交换文件
    echo -e "${BLUE}正在启用交换文件...${NC}"
    sudo swapon /swapfile
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ 交换文件启用失败。${NC}"
        sudo rm -f /swapfile
        return
    fi

    # 永久生效
    if ! grep -q '/swapfile' /etc/fstab; then
        echo -e "${BLUE}将交换文件添加到 /etc/fstab，确保永久生效...${NC}"
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    fi

    # 输出结果
    echo -e "${GREEN}✓ ${SWAP_SIZE}MB 虚拟内存已成功创建并启用。当前内存和交换空间信息：${NC}"
    free -h
}

# 删除交换文件
delete_swap() {
    if [ -f /swapfile ]; then
        echo -e "${BLUE}[$(date +"%Y-%m-%d %H:%M:%S")] INFO: 正在删除交换文件 /swapfile...${NC}"
        sudo swapoff /swapfile 2>/dev/null
        sudo rm -f /swapfile
        # 从 /etc/fstab 中移除交换文件配置
        sudo sed -i '/\/swapfile/d' /etc/fstab
        echo -e "${GREEN}✓ : 交换文件已删除。${NC}"
    else
        echo -e "${BLUE}⚠️ 未找到交换文件 /swapfile。${NC}"
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
        echo -e "\n"
        echo -e "${GREEN}交换空间信息：${NC}"
        echo -e "总交换空间：${total_swap}MB"
        echo -e "已使用：${used_swap}MB (${swap_usage}%)"
        echo -e "可用交换空间：${free_swap}MB"
        echo -e "\n"
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
    echo -e "${YELLOW}当前内存交换倾向性值：${CURRENT_SWAPPINESS}${NC}"
    echo -e "${YELLOW}值越低，越少使用交换空间；值越高，越多使用交换空间。${NC}"
    echo -e "${YELLOW}推荐值：10-60${NC}"
    
    # 获取新值
    while true; do
        read -p "请输入新的内存交换倾向性值（0-100，推荐10-60）：" SWAPPINESS
        SWAPPINESS=${SWAPPINESS:-$CURRENT_SWAPPINESS}  # 如果用户未输入，保持当前值
        
        # 验证输入是否合法
        if [[ $SWAPPINESS =~ ^[0-9]+$ ]] && [ $SWAPPINESS -ge 0 ] && [ $SWAPPINESS -le 100 ]; then
            break
        else
            echo -e "${RED}⚠️ 输入值无效，请输入0到100之间的整数。${NC}"
        fi
    done

    # 让用户选择修改方式
    echo -e "\n${BLUE}请选择修改方式：${NC}"
    echo -e "${YELLOW}1. 临时修改（立即生效，重启后失效）${NC}"
    echo -e "${YELLOW}2. 永久修改（立即生效且重启后仍然有效）${NC}"
    read -p "请输入选项（1-2）：" MODE

    case $MODE in
        1)
            # 临时修改（立即生效）
            sudo sysctl vm.swappiness=$SWAPPINESS
            echo -e "${GREEN}✓ : 内存交换倾向性值已临时修改为 $SWAPPINESS（立即生效，重启后失效）。${NC}"
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
            echo -e "${GREEN}✓ : 内存交换倾向性值已永久修改为 $SWAPPINESS（立即生效且重启后仍然有效）。${NC}"
            ;;
        *)
            echo -e "${RED}⚠️ 无效选项，未进行任何修改。${NC}"
            ;;
    esac
}

# 内存压力测试
stress_test() {
    echo -e "${BLUE}正在准备内存压力测试...${NC}"
    
    # 检查是否安装stress/stress-ng
    if ! command -v stress &> /dev/null && ! command -v stress-ng &> /dev/null; then
        echo -e "${YELLOW}未安装压力测试工具，正在安装...${NC}"
        
        case $PKG_MANAGER in
            "apk")
                if ! apk add stress-ng; then
                    echo -e "${RED}✗ stress-ng 安装失败${NC}"
                    return 1
                fi
                STRESS_CMD="stress-ng"
                ;;
            "apt-get")
                if ! sudo apt-get install -y stress; then
                    echo -e "${RED}✗ stress 安装失败${NC}"
                    return 1
                fi
                STRESS_CMD="stress"
                ;;
            "yum")
                if ! sudo yum install -y stress; then
                    echo -e "${RED}✗ stress 安装失败${NC}"
                    return 1
                fi
                STRESS_CMD="stress"
                ;;
            "pacman")
                if ! sudo pacman -S --noconfirm stress; then
                    echo -e "${RED}✗ stress 安装失败${NC}"
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
        read -p "请输入压力测试时间（单位：秒，默认5秒）：" TEST_TIME
        TEST_TIME=${TEST_TIME:-5}  # 如果用户未输入，则默认5秒
        
        # 验证输入是否合法
        if [[ $TEST_TIME =~ ^[0-9]+$ ]] && [ $TEST_TIME -gt 0 ]; then
            break
        else
            echo -e "${RED}✗ 输入值无效，请输入大于0的整数（单位：秒）。${NC}"
        fi
    done

    # 获取可用内存
    total_mem=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
    
    # 让用户输入内存使用百分比
    while true; do
        read -p "请输入压测内存使用量，相对于系统内存的百分比（10-1000，默认90）：" MEM_PERCENT
        MEM_PERCENT=${MEM_PERCENT:-90}  # 如果用户未输入，则默认90%
        
        # 验证输入是否合法
        if [[ $MEM_PERCENT =~ ^[0-9]+$ ]] && [ $MEM_PERCENT -ge 10 ] && [ $MEM_PERCENT -le 1000 ]; then
            break
        else
            echo -e "${RED}✗ 输入值无效，请输入10到1000之间的整数。${NC}"
        fi
    done

    # 计算测试内存大小
    MEM_RATIO=$(echo "scale=2; $MEM_PERCENT / 100" | bc)
    MEM_SIZE=$(echo "$total_mem * 1024 * $MEM_RATIO" | bc | awk '{printf "%d\n", $0}')
    MEM_SIZE_GB=$(echo "scale=2; $MEM_SIZE / 1024 / 1024 / 1024" | bc | awk '{printf "%.2f\n", $0}')
    
    echo -e "${YELLOW}即将开始内存压力测试，使用 ${MEM_SIZE_GB} GB 内存（${MEM_PERCENT}%系统内存），持续${TEST_TIME}秒${NC}"
    
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
    echo -e "${BLUE}实时监控内存和交换空间使用情况：${NC}"
    echo -e "${YELLOW}注意：当使用超过100%系统内存时，可能会触发OOM Killer终止进程。${NC}"
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
    
    echo -e "${GREEN}✓ 压力测试结束${NC}"
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
    echo -e "${YELLOW}准备卸载 Swap Manager...${NC}"
    
    # 确认卸载
    read -p "确定要卸载吗？这将删除交换文件和程序(y/n): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}取消卸载。${NC}"
        return
    fi

    # 删除交换文件（如果存在）
    if [ -f /swapfile ]; then
        echo -e "${BLUE}正在删除交换文件...${NC}"
        sudo swapoff /swapfile 2>/dev/null
        sudo rm -f /swapfile
        sudo sed -i '/\/swapfile/d' /etc/fstab
    fi

    # 删除程序本体
    echo -e "${BLUE}正在删除程序...${NC}"
    sudo rm -f /usr/local/bin/swap

    echo -e "${GREEN}✓ Swap Manager 已完全卸载。${NC}"
    exit 0
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
