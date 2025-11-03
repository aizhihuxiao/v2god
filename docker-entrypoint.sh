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

# 验证 Caddyfile 格式
if ! caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile; then
    echo "❌ ERROR: Caddyfile validation failed!"
    exit 1
fi
echo "✅ Caddyfile validation passed"

# 先启动 Caddy（后台运行）
echo "🚀 Starting Caddy first to generate certificates..."
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
CADDY_PID=$!
echo "✅ Caddy started with PID: $CADDY_PID"

# 如果存在 sing-box 配置，等待证书生成后再启动
if [ -f "/etc/sing-box/config.json" ]; then
    echo "🔍 Detecting and waiting for SSL certificates..."
    
    # 提取域名
    DOMAIN=$(grep -o '"server_name"[[:space:]]*:[[:space:]]*"[^"]*"' /etc/sing-box/config.json | cut -d'"' -f4 | head -1)
    if [ -z "$DOMAIN" ]; then
        DOMAIN="99gtr.com"
    fi
    echo "📋 Domain: $DOMAIN"
    
    # 最多等待 180 秒
    WAIT_COUNT=0
    MAX_WAIT=180
    CERT_FOUND=false
    
    while [ "$CERT_FOUND" = "false" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        # 搜索任意 CA 颁发的证书（自动适配路径）
        ACTUAL_CERT=$(find /data/caddy/certificates -name "*.crt" -path "*/wildcard_*.${DOMAIN}/*" 2>/dev/null | head -1)
        
        if [ -n "$ACTUAL_CERT" ] && [ -f "$ACTUAL_CERT" ]; then
            ACTUAL_KEY="${ACTUAL_CERT%.crt}.key"
            
            if [ -f "$ACTUAL_KEY" ]; then
                echo "✅ Found certificate: $ACTUAL_CERT"
                echo "🔧 Auto-updating sing-box config with actual certificate paths..."
                
                # 备份原配置
                cp /etc/sing-box/config.json /etc/sing-box/config.json.original
                
                # 替换证书路径（使用实际检测到的路径）
                sed -i "s|\"certificate_path\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"certificate_path\": \"${ACTUAL_CERT}\"|g" /etc/sing-box/config.json
                sed -i "s|\"key_path\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"key_path\": \"${ACTUAL_KEY}\"|g" /etc/sing-box/config.json
                
                echo "✅ Certificate paths updated successfully"
                CERT_FOUND=true
            else
                echo "⚠️  Certificate found but key missing: $ACTUAL_KEY"
            fi
        fi
        
        if [ "$CERT_FOUND" = "false" ]; then
            sleep 2
            WAIT_COUNT=$((WAIT_COUNT + 2))
            if [ $((WAIT_COUNT % 10)) -eq 0 ]; then
                echo "⏳ Waiting for certificate... (${WAIT_COUNT}s/${MAX_WAIT}s)"
            fi
        fi
    done
    
    if [ "$CERT_FOUND" = "true" ]; then
        echo "🚀 Starting sing-box with auto-detected certificate..."
        
        # 确保日志目录存在
        mkdir -p /var/log/sing-box
        
        # 启动 sing-box
        sing-box run -c /etc/sing-box/config.json > /var/log/sing-box/sing-box.log 2>&1 &
        SINGBOX_PID=$!
        echo "✅ sing-box started with PID: $SINGBOX_PID"
        
        # 验证启动成功
        sleep 3
        if kill -0 $SINGBOX_PID 2>/dev/null; then
            echo "✅ sing-box is running successfully!"
        else
            echo "❌ sing-box failed to start! Logs:"
            cat /var/log/sing-box/sing-box.log 2>/dev/null || echo "No log file"
            echo "⚠️  Continuing with Caddy only..."
        fi
    else
        echo "⚠️  Timeout waiting for certificate after ${MAX_WAIT}s"
        echo "💡 sing-box will not start. Certificate may still be pending."
        echo "💡 Check: docker exec caddy ls -la /data/caddy/certificates/"
        echo "💡 Restart container later: docker restart caddy"
    fi
else
    echo "⚠️  sing-box config not found at /etc/sing-box/config.json, skipping..."
fi

echo "========================================="
echo "✅ Container initialization complete"
echo "📊 Caddy PID: $CADDY_PID"
echo "========================================="

# 保持容器运行
wait $CADDY_PID
