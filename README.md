# Swap Manager

[English](README_EN.md) | 简体中文

一个功能强大的Linux交换空间管理工具，提供图形化菜单界面，支持交换文件的创建、删除、监控和性能测试等功能。

## ✨ 功能特性

- 🚀 交互式菜单界面，操作简单直观
- 📊 实时监控系统内存和交换空间使用情况
- 🛠 支持创建/删除交换文件
- 📈 内存压力测试功能
- ⚙️ 交换倾向性(swappiness)调整
- 🎨 彩色输出界面
- 🔒 完整的错误处理和安全检查

## 📥 安装

### 首次安装：
```bash
wget -qO /usr/local/bin/swap https://raw.githubusercontent.com/heyuecock/swap_manage/refs/heads/main/swap_manager.sh && chmod +x /usr/local/bin/swap && swap
```

### 再次运行：
```bash
swap
```

## 🗑️ 卸载

### 方法一：使用程序卸载（推荐）
```bash
swap  # 进入程序后选择"卸载程序"选项
```

### 方法二：手动卸载
```bash
sudo swapoff /swapfile  # 关闭交换文件
sudo rm -f /swapfile    # 删除交换文件
sudo sed -i '/\/swapfile/d' /etc/fstab  # 从fstab中删除配置
sudo rm -f /usr/local/bin/swap  # 删除程序
```

### 主要功能

1. **创建交换文件**
   - 支持自定义大小(100-5120MB)
   - 自动检查磁盘空间
   - 自动配置开机启动
   - 安全权限设置

2. **删除交换文件**
   - 安全关闭并删除现有交换文件
   - 自动清理系统配置
   - 完整性检查

3. **查看系统信息**
   - 内存使用详情
   - 交换空间状态
   - 磁盘使用情况
   - CPU负载信息

4. **调整交换参数**
   - 支持临时/永久修改swappiness
   - 提供优化建议
   - 实时生效

5. **压力测试**
   - 自定义测试时长和强度
   - 实时监控系统状态
   - 自动化测试报告

## 💻 系统要求

### 支持的操作系统
- Ubuntu/Debian 系列
- CentOS/RHEL 系列
- Alpine Linux
- Arch Linux
- 其他主流 Linux 发行版

### 依赖项
- 基础工具：
  - bc (基础计算)
  - util-linux (系统工具)
- 可选工具：
  - stress/stress-ng (压力测试)

## ⚠️ 注意事项
- Alpine Linux 用户可能需要额外安装一些基础工具
- 某些最小化安装的系统可能需要安装额外依赖
- 需要root权限或sudo访问权限

1. **安全警告**
   - 建议在操作前备份重要数据
   - 不要在生产环境进行压力测试

2. **使用建议**
   - 建议交换文件大小为物理内存的1-2倍
   - swappiness推荐值: 10-60
   - 定期监控系统状态

3. **故障排除**
   - 如创建失败，检查磁盘空间
   - 如无法删除，确保交换文件未被使用
   - 压力测试可能触发OOM killer

## 🔧 常见问题

Q: 为什么需要交换空间？
A: 交换空间作为物理内存的扩展，可以防止内存耗尽导致的系统崩溃。

Q: 如何选择合适的交换文件大小？
A: 通常建议设置为物理内存的1-2倍，但要根据实际使用情况调整。

Q: swappiness值如何调整？
A: 服务器建议设置为10-30，桌面系统可以设置为30-60。
