#!/bin/sh
set -e

echo "========================================="
echo "Starting Caddy + sing-box container"
echo "========================================="

# 启动 sing-box（如果配置文件存在）
if [ -f "/etc/sing-box/config.json" ]; then
    echo "🚀 Starting sing-box..."
    sing-box run -c /etc/sing-box/config.json > /var/log/sing-box/sing-box.log 2>&1 &
    SINGBOX_PID=$!
    echo "✅ sing-box started with PID: $SINGBOX_PID"
else
    echo "⚠️  sing-box config not found, skipping..."
fi

# 启动 Caddy
echo "🚀 Starting Caddy..."
exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile
