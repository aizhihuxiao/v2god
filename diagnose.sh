#!/bin/bash

echo "========================================="
echo "服务器网络诊断脚本"
echo "========================================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. 检查防火墙状态
echo "1️⃣ 【防火墙状态检查】"
echo "-------------------"

# UFW
if command -v ufw &> /dev/null; then
    ufw_status=$(ufw status 2>/dev/null | head -1)
    if echo "$ufw_status" | grep -q "inactive"; then
        echo -e "${GREEN}✅ UFW: 已禁用${NC}"
    else
        echo -e "${RED}❌ UFW: 正在运行！${NC}"
        ufw status numbered
        echo -e "${YELLOW}执行: ufw --force disable${NC}"
    fi
else
    echo "ℹ️  UFW 未安装"
fi

# Firewalld
if command -v firewall-cmd &> /dev/null; then
    if systemctl is-active --quiet firewalld; then
        echo -e "${RED}❌ Firewalld: 正在运行！${NC}"
        firewall-cmd --list-all
        echo -e "${YELLOW}执行: systemctl stop firewalld && systemctl disable firewalld${NC}"
    else
        echo -e "${GREEN}✅ Firewalld: 已禁用${NC}"
    fi
else
    echo "ℹ️  Firewalld 未安装"
fi

# iptables
echo ""
echo "iptables 规则:"
iptables -L INPUT -n -v --line-numbers | head -20
iptables -L OUTPUT -n -v --line-numbers | head -10

input_policy=$(iptables -L INPUT -n | grep "Chain INPUT" | awk '{print $4}')
if [ "$input_policy" = "ACCEPT)" ]; then
    echo -e "${GREEN}✅ iptables INPUT 默认策略: ACCEPT${NC}"
else
    echo -e "${RED}❌ iptables INPUT 默认策略: $input_policy${NC}"
    echo -e "${YELLOW}执行: iptables -P INPUT ACCEPT${NC}"
fi

echo ""
echo "2️⃣ 【端口监听检查】"
echo "-------------------"
echo "当前监听的端口:"
if command -v netstat &> /dev/null; then
    netstat -tlnp | grep -E '(:443|:80|:2019|:22|caddy)'
elif command -v ss &> /dev/null; then
    ss -tlnp | grep -E '(:443|:80|:2019|:22|caddy)'
fi

echo ""
echo "3️⃣ 【云服务商安全组检查】"
echo "-------------------"
echo "⚠️  请手动检查云服务商控制台的安全组规则："
echo "   - 入站规则必须允许: TCP 443, 80, 22"
echo "   - 出站规则必须允许: 全部流量"
echo ""

# 检测云服务商
if curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id &>/dev/null; then
    echo "检测到: AWS EC2"
elif curl -s -m 2 http://100.100.100.200/latest/meta-data/instance-id &>/dev/null; then
    echo "检测到: 阿里云 ECS"
elif curl -s -m 2 -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" &>/dev/null; then
    echo "检测到: Azure VM"
elif dmidecode -s system-product-name 2>/dev/null | grep -i "google"; then
    echo "检测到: Google Cloud"
else
    echo "未能自动检测云服务商"
fi

echo ""
echo "4️⃣ 【Docker 容器检查】"
echo "-------------------"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E '(NAMES|caddy)'

echo ""
echo "5️⃣ 【Caddy 配置检查】"
echo "-------------------"
if docker ps | grep -q caddy; then
    echo "实际生效的 Caddyfile:"
    docker exec caddy cat /etc/caddy/Caddyfile
    
    echo ""
    echo "Caddy 模块列表:"
    docker exec caddy caddy list-modules | grep -i forward || echo -e "${RED}❌ 未找到 forward_proxy 模块！${NC}"
else
    echo -e "${RED}❌ Caddy 容器未运行${NC}"
fi

echo ""
echo "6️⃣ 【网络连通性测试】"
echo "-------------------"
echo "测试本地 443 端口:"
timeout 3 bash -c "echo > /dev/tcp/127.0.0.1/443" 2>/dev/null && echo -e "${GREEN}✅ 本地 443 端口可访问${NC}" || echo -e "${RED}❌ 本地 443 端口无法访问${NC}"

echo ""
echo "测试本地 2019 端口 (Caddy Admin):"
timeout 3 bash -c "echo > /dev/tcp/127.0.0.1/2019" 2>/dev/null && echo -e "${GREEN}✅ 本地 2019 端口可访问${NC}" || echo -e "${RED}❌ 本地 2019 端口无法访问${NC}"

echo ""
echo "外网 IP 地址:"
curl -s ip.sb || curl -s ifconfig.me || curl -s icanhazip.com
echo ""

echo ""
echo "7️⃣ 【系统日志检查】"
echo "-------------------"
echo "最近的防火墙相关日志:"
journalctl -u firewalld -n 10 --no-pager 2>/dev/null || echo "无 firewalld 日志"
dmesg | grep -i "firewall\|iptables\|drop" | tail -10 || echo "无相关 dmesg 日志"

echo ""
echo "8️⃣ 【SELinux 检查】"
echo "-------------------"
if command -v getenforce &> /dev/null; then
    selinux_status=$(getenforce)
    if [ "$selinux_status" = "Enforcing" ]; then
        echo -e "${RED}❌ SELinux: $selinux_status (可能阻止连接)${NC}"
        echo -e "${YELLOW}建议执行: setenforce 0${NC}"
        echo -e "${YELLOW}永久禁用: sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config${NC}"
    else
        echo -e "${GREEN}✅ SELinux: $selinux_status${NC}"
    fi
else
    echo "ℹ️  SELinux 未安装"
fi

echo ""
echo "========================================="
echo "9️⃣ 【一键修复命令】"
echo "========================================="
echo ""
echo "如果发现问题，执行以下命令修复："
echo ""
echo -e "${YELLOW}# 禁用所有防火墙${NC}"
echo "ufw --force disable 2>/dev/null || true"
echo "systemctl stop firewalld 2>/dev/null || true"
echo "systemctl disable firewalld 2>/dev/null || true"
echo ""
echo -e "${YELLOW}# 清空 iptables 规则${NC}"
echo "iptables -F"
echo "iptables -X"
echo "iptables -P INPUT ACCEPT"
echo "iptables -P FORWARD ACCEPT"
echo "iptables -P OUTPUT ACCEPT"
echo ""
echo -e "${YELLOW}# 禁用 SELinux${NC}"
echo "setenforce 0 2>/dev/null || true"
echo ""
echo -e "${YELLOW}# 重启 Caddy 容器${NC}"
echo "cd /home/aizhihuxiao/v2god5 && docker-compose restart caddy"
echo ""
echo "========================================="
echo "检查完成！"
echo "========================================="
