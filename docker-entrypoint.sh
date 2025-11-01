#!/bin/sh
set -e

echo "========================================="
echo "Starting Caddy + sing-box container"
echo "========================================="

# 检查 Caddyfile 是否存在
if [ ! -f "/etc/caddy/Caddyfile" ]; then
    echo "❌ ERROR: /etc/caddy/Caddyfile not found!"
    echo "Please mount your Caddyfile to /etc/caddy/Caddyfile"
    exit 1
fi

echo "📝 Caddyfile found, checking format..."
cat /etc/caddy/Caddyfile
echo "========================================="

# 验证 Caddyfile 格式
if ! caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; then
    echo "❌ ERROR: Caddyfile validation failed!"
    exit 1
fi
echo "✅ Caddyfile validation passed"

# 启动 sing-box（如果配置文件存在）
if [ -f "/etc/sing-box/config.json" ]; then
    echo "🚀 Starting sing-box..."
    echo "sing-box config:"
    cat /etc/sing-box/config.json | jq '.' 2>/dev/null || cat /etc/sing-box/config.json
    echo "========================================="
    
    # 确保日志目录存在
    mkdir -p /etc/sing-box/logs
    
    sing-box run -c /etc/sing-box/config.json > /etc/sing-box/logs/sing-box.log 2>&1 &
    SINGBOX_PID=$!
    echo "✅ sing-box started with PID: $SINGBOX_PID"
    
    # 等待 sing-box 启动
    sleep 2
    if ! kill -0 $SINGBOX_PID 2>/dev/null; then
        echo "❌ ERROR: sing-box failed to start!"
        cat /etc/sing-box/logs/sing-box.log
        exit 1
    fi
else
    echo "⚠️  sing-box config not found at /etc/sing-box/config.json, skipping..."
fi

# 启动 Caddy
echo "🚀 Starting Caddy..."
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
