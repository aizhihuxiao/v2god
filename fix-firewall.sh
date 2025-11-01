#!/bin/bash

echo "========================================="
echo "一键修复防火墙和网络问题"
echo "========================================="
echo ""

# 1. 禁用 UFW
if command -v ufw &> /dev/null; then
    echo "🔥 禁用 UFW..."
    ufw --force disable
    systemctl disable ufw 2>/dev/null || true
    systemctl stop ufw 2>/dev/null || true
    echo "✅ UFW 已禁用"
fi

# 2. 禁用 Firewalld
if command -v firewall-cmd &> /dev/null; then
    echo "🔥 禁用 Firewalld..."
    systemctl stop firewalld 2>/dev/null || true
    systemctl disable firewalld 2>/dev/null || true
    echo "✅ Firewalld 已禁用"
fi

# 3. 清空 iptables 规则
echo "🔥 清空 iptables 规则..."
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "✅ iptables 规则已清空"

# 4. 禁用 SELinux (如果存在)
if command -v getenforce &> /dev/null; then
    echo "🔥 禁用 SELinux..."
    setenforce 0 2>/dev/null || true
    if [ -f /etc/selinux/config ]; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
        sed -i 's/SELINUX=permissive/SELINUX=disabled/' /etc/selinux/config
    fi
    echo "✅ SELinux 已禁用"
fi

# 5. 检查 Docker
echo "🐳 检查 Docker 服务..."
if ! systemctl is-active --quiet docker; then
    systemctl start docker
    sleep 2
fi
echo "✅ Docker 服务正常"

# 6. 重启 Caddy 容器
echo "🔄 重启 Caddy 容器..."
if [ -d "/home/aizhihuxiao/v2god5" ]; then
    cd /home/aizhihuxiao/v2god5
    docker-compose restart caddy
    echo "✅ Caddy 容器已重启"
else
    echo "⚠️  未找到项目目录，请手动重启"
fi

echo ""
echo "========================================="
echo "7️⃣ 【验证修复结果】"
echo "========================================="
echo ""

# 等待容器启动
sleep 3

# 检查端口
echo "检查端口监听:"
if command -v netstat &> /dev/null; then
    netstat -tlnp | grep -E '(:443|:80|:2019)' || echo "⚠️  未检测到端口监听"
elif command -v ss &> /dev/null; then
    ss -tlnp | grep -E '(:443|:80|:2019)' || echo "⚠️  未检测到端口监听"
fi

echo ""
echo "检查容器状态:"
docker ps --filter name=caddy --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "测试本地连接:"
timeout 3 bash -c "echo > /dev/tcp/127.0.0.1/443" 2>/dev/null && echo "✅ 443 端口可访问" || echo "❌ 443 端口无法访问"
timeout 3 bash -c "echo > /dev/tcp/127.0.0.1/2019" 2>/dev/null && echo "✅ 2019 端口可访问" || echo "❌ 2019 端口无法访问"

echo ""
echo "========================================="
echo "修复完成！"
echo "========================================="
echo ""
echo "⚠️  重要提示："
echo "1. 如果还是无法连接，请检查云服务商的安全组设置"
echo "2. 确保安全组入站规则允许: TCP 443, 80, 22"
echo "3. 从客户端测试: telnet <服务器IP> 443"
echo "4. 查看 Caddy 日志: docker logs -f caddy"
echo ""
