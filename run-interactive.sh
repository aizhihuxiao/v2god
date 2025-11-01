#!/bin/sh
set -e  # 遇到错误立即退出

echo "========================================="
echo "  Caddy NaiveProxy 交互式部署脚本"
echo "========================================="
echo ""

# 交互式输入配置参数
read -p "请输入域名 (例如: xxx.com): " domain
while [ -z "$domain" ]; do
    echo "❌ 域名不能为空！"
    read -p "请输入域名: " domain
done

read -p "请输入代理路径 (例如: xxxx): " proxyPath
while [ -z "$proxyPath" ]; do
    echo "❌ 代理路径不能为空！"
    read -p "请输入代理路径: " proxyPath
done

read -p "请输入 Cloudflare API Token: " cloudflareApiToken
while [ -z "$cloudflareApiToken" ]; do
    echo "❌ API Token 不能为空！"
    read -p "请输入 Cloudflare API Token: " cloudflareApiToken
done

read -p "请输入 Naive 用户名: " naive_user
while [ -z "$naive_user" ]; do
    echo "❌ 用户名不能为空！"
    read -p "请输入 Naive 用户名: " naive_user
done

# 兼容 sh 的密码输入（不显示）
printf "请输入 Naive 密码: "
stty -echo
read naive_passwd
stty echo
echo ""
while [ -z "$naive_passwd" ]; do
    echo "❌ 密码不能为空！"
    printf "请输入 Naive 密码: "
    stty -echo
    read naive_passwd
    stty echo
    echo ""
done

echo ""
echo "========================================="
echo "配置确认："
echo "========================================="
echo "域名: ${domain}"
echo "代理路径: /${proxyPath}"
cloudflare_token_short=$(echo "$cloudflareApiToken" | cut -c1-20)
echo "Cloudflare Token: ${cloudflare_token_short}..."
echo "Naive 用户: ${naive_user}"
naive_passwd_short=$(echo "$naive_passwd" | cut -c1-8)
echo "Naive 密码: ${naive_passwd_short}..."
echo "========================================="
echo ""

read -p "确认配置无误？(y/n): " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "❌ 部署已取消"
    exit 0
fi

echo ""
echo "========================================="
echo "开始部署 Caddy NaiveProxy 服务"
echo "========================================="

# 设置时区
echo "⏰ 设置时区..."
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" > /etc/timezone

# 更新系统并安装依赖
echo "📦 安装系统依赖..."
apt update && apt upgrade -y
apt install -y curl ca-certificates gnupg

# 安装 Docker（如果未安装）
if ! command -v docker >/dev/null 2>&1; then
    echo "🐳 安装 Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
else
    echo "✅ Docker 已安装"
    # 确保 Docker 服务正在运行
    if ! systemctl is-active --quiet docker; then
        echo "⚠️  Docker 服务未运行，正在启动..."
        systemctl enable docker 2>/dev/null || true
        systemctl start docker
        sleep 3
    fi
fi

# 同步时间
echo "🕐 同步系统时间..."
apt install -y ntpdate
ntpdate -u pool.ntp.org

# 创建目录结构
echo "📁 创建目录..."
mkdir -p caddy/{data,config,logs}
# 设置目录权限，允许容器写入
chmod -R 777 caddy/data caddy/config caddy/logs

# 生成 Caddyfile - 修复变量名
if [ ! -f "./caddy/Caddyfile" ]; then
    echo "📝 生成 Caddyfile..."
    cp Caddyfile.example ./caddy/Caddyfile
    sed -i "s/domain/${domain}/g" ./caddy/Caddyfile
    sed -i "s/proxyPath/${proxyPath}/g" ./caddy/Caddyfile
    sed -i "s/cloudflareApiToken/${cloudflareApiToken}/g" ./caddy/Caddyfile
    sed -i "s/naive_user/${naive_user}/g" ./caddy/Caddyfile
    sed -i "s/naive_passwd/${naive_passwd}/g" ./caddy/Caddyfile
else
    echo "⚠️  Caddyfile 已存在"
    read -p "是否覆盖现有配置？(y/n): " overwrite
    if [ "$overwrite" = "y" ] || [ "$overwrite" = "Y" ]; then
        cp Caddyfile.example ./caddy/Caddyfile
        sed -i "s/domain/${domain}/g" ./caddy/Caddyfile
        sed -i "s/proxyPath/${proxyPath}/g" ./caddy/Caddyfile
        sed -i "s/cloudflareApiToken/${cloudflareApiToken}/g" ./caddy/Caddyfile
        sed -i "s/naive_user/${naive_user}/g" ./caddy/Caddyfile
        sed -i "s/naive_passwd/${naive_passwd}/g" ./caddy/Caddyfile
        echo "✅ Caddyfile 已更新"
    fi
fi

# 停止并删除旧容器（如果存在）
if docker ps -a --format '{{.Names}}' | grep -q "^caddy$"; then
    echo "🗑️  删除旧的 Caddy 容器..."
    docker stop caddy 2>/dev/null || true
    docker rm caddy
fi

# 启动 Caddy 容器
echo "🚀 启动 Caddy 容器..."
docker run -d --name caddy \
    --restart=always \
    --net=host \
    --log-opt max-size=10m \
    --log-opt max-file=3 \
    -v $PWD/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
    -v $PWD/caddy/data:/data/caddy \
    -v $PWD/caddy/config:/config \
    -v $PWD/caddy/logs:/var/log/caddy \
    aizhihuxiao/v2god:latest

# 检查 Caddy 启动状态
echo "⏳ 等待 Caddy 启动..."
sleep 5
if docker ps | grep -q caddy; then
    echo "✅ Caddy 容器启动成功"
    docker logs caddy --tail 20
else
    echo "❌ Caddy 容器启动失败，查看日志:"
    docker logs caddy
    exit 1
fi

# 启动 Watchtower 自动更新
if ! docker ps -a --format '{{.Names}}' | grep -q "^watchtower$"; then
    echo "🔄 启动 Watchtower 自动更新..."
    docker run -d --name watchtower \
        --restart=unless-stopped \
        -v /var/run/docker.sock:/var/run/docker.sock \
        containrrr/watchtower --cleanup --interval 86400
else
    echo "✅ Watchtower 已在运行"
fi

# 平衡的网络优化配置 - 交互式版
echo "🚄 配置网络性能优化（平衡模式）..."
modprobe tcp_bbr 2>/dev/null || echo "⚠️  BBR 模块加载失败"

# 检查 sysctl.conf 是否已包含配置，避免重复添加
if ! grep -q "# 平衡性能优化" /etc/sysctl.conf; then
cat >> /etc/sysctl.conf << EOF

# 平衡性能优化 - 避免过于激进
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr

# 适度的 TCP 优化
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
net.ipv4.tcp_mtu_probing=1

# 适中的连接队列
net.core.somaxconn=32768
net.ipv4.tcp_max_syn_backlog=4096
net.core.netdev_max_backlog=8192

# 适中的缓冲区设置
net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 65536 33554432
net.ipv4.tcp_wmem=4096 65536 33554432

# 温和的 TIME_WAIT 设置
net.ipv4.tcp_tw_reuse=1
net.ipv4.tcp_fin_timeout=30

# 正常的保活设置
net.ipv4.tcp_keepalive_time=1200
net.ipv4.tcp_keepalive_intvl=30
net.ipv4.tcp_keepalive_probes=3

# IP 转发
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF
else
    echo "⚠️  网络优化配置已存在，跳过添加"
fi

sysctl -p > /dev/null

# 验证优化
echo "✅ 网络优化已应用"
sysctl net.ipv4.tcp_congestion_control
sysctl net.ipv4.tcp_fastopen

# 禁用系统防火墙
echo "🔥 禁用系统防火墙..."
if command -v ufw &> /dev/null; then
    ufw --force disable
    systemctl disable ufw 2>/dev/null || true
    echo "✅ UFW 防火墙已禁用"
fi

if command -v firewalld &> /dev/null; then
    systemctl stop firewalld 2>/dev/null || true
    systemctl disable firewalld 2>/dev/null || true
    echo "✅ Firewalld 已禁用"
fi

# 清理 iptables 规则
iptables -F
iptables -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
echo "✅ iptables 规则已清空"

# 保存配置到文件（方便后续查看）
cat > ./caddy/config.txt << EOF
部署时间: $(date)
域名: ${domain}
代理路径: /${proxyPath}
Naive 用户: ${naive_user}
Naive 密码: ${naive_passwd}
Cloudflare Token: ${cloudflareApiToken}
EOF
chmod 600 ./caddy/config.txt

echo ""
echo "========================================="
echo "✅ 部署完成！"
echo "========================================="
echo "域名: ${domain}"
echo "代理路径: /${proxyPath}"
echo "Naive 用户: ${naive_user}"
echo "Naive 密码: ${naive_passwd}"
echo ""
echo "⚠️  配置已保存到: ./caddy/config.txt"
echo ""
echo "⚠️  请在云服务商控制台配置安全组："
echo "   - 开放 22/tcp  (SSH)"
echo "   - 开放 80/tcp  (HTTP)"
echo "   - 开放 443/tcp (HTTPS)"
echo ""
echo "📊 查看日志: docker logs -f caddy"
echo "🔍 检查状态: docker ps"
echo "🛑 停止服务: docker stop caddy"
echo "🔄 重启服务: docker restart caddy"
echo "========================================="