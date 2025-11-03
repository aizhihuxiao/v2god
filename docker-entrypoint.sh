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

# 先启动 Caddy（后台运行）
echo "🚀 Starting Caddy first to generate certificates..."
caddy run --config /etc/caddy/Caddyfile --adapter caddyfile &
CADDY_PID=$!
echo "✅ Caddy started with PID: $CADDY_PID"

# 如果存在 sing-box 配置，等待证书生成后再启动
if [ -f "/etc/sing-box/config.json" ]; then
    echo "� Waiting for SSL certificates to be generated..."
    
    # 从 sing-box 配置中提取证书路径
    CERT_PATH=$(grep -o '"/data/caddy/certificates/[^"]*\.crt"' /etc/sing-box/config.json | tr -d '"' | head -1)
    
    if [ -n "$CERT_PATH" ]; then
        echo "📋 Certificate path: $CERT_PATH"
        
        # 最多等待 180 秒
        WAIT_COUNT=0
        MAX_WAIT=180
        
        while [ ! -f "$CERT_PATH" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
            sleep 2
            WAIT_COUNT=$((WAIT_COUNT + 2))
            if [ $((WAIT_COUNT % 10)) -eq 0 ]; then
                echo "⏳ Still waiting for certificate... (${WAIT_COUNT}s/${MAX_WAIT}s)"
            fi
            
            # 每30秒检查一次是否有其他CA的证书
            if [ $((WAIT_COUNT % 30)) -eq 0 ]; then
                ACTUAL_CERT=$(find /data/caddy/certificates -name "*.crt" -path "*/wildcard_*.99gtr.com/*" 2>/dev/null | head -1)
                if [ -n "$ACTUAL_CERT" ] && [ -f "$ACTUAL_CERT" ]; then
                    echo "📋 Found certificate at different path: $ACTUAL_CERT"
                    echo "🔧 Auto-fixing certificate path in config..."
                    
                    ACTUAL_KEY="${ACTUAL_CERT%.crt}.key"
                    
                    # 动态更新配置文件中的证书路径
                    cp /etc/sing-box/config.json /etc/sing-box/config.json.bak
                    sed -i "s|/data/caddy/certificates/.*/wildcard_[^/]*/wildcard_[^\"]*\.crt|${ACTUAL_CERT}|g" /etc/sing-box/config.json
                    sed -i "s|/data/caddy/certificates/.*/wildcard_[^/]*/wildcard_[^\"]*\.key|${ACTUAL_KEY}|g" /etc/sing-box/config.json
                    
                    CERT_PATH="$ACTUAL_CERT"
                    echo "✅ Certificate path updated to: $CERT_PATH"
                    break
                fi
            fi
        done
        
        if [ -f "$CERT_PATH" ]; then
            echo "✅ Certificate found! Starting sing-box..."
            
            # 确保日志目录存在
            mkdir -p /var/log/sing-box
            
            # 启动 sing-box
            sing-box run -c /etc/sing-box/config.json > /var/log/sing-box/sing-box.log 2>&1 &
            SINGBOX_PID=$!
            echo "✅ sing-box started with PID: $SINGBOX_PID"
            
            # 验证 sing-box 启动成功
            sleep 3
            if kill -0 $SINGBOX_PID 2>/dev/null; then
                echo "✅ sing-box is running successfully!"
            else
                echo "❌ sing-box failed to start! Logs:"
                cat /var/log/sing-box/sing-box.log
                echo "⚠️  Continuing with Caddy only..."
            fi
        else
            echo "⚠️  Timeout waiting for certificate after ${MAX_WAIT}s"
            echo "💡 sing-box will not start. You can manually restart the container after certificates are issued."
            echo "💡 Check certificate status: docker exec caddy ls -la /data/caddy/certificates/"
        fi
    else
        echo "⚠️  Could not extract certificate path from sing-box config"
        echo "🚀 Attempting to start sing-box anyway..."
        mkdir -p /var/log/sing-box
        sing-box run -c /etc/sing-box/config.json > /var/log/sing-box/sing-box.log 2>&1 &
        SINGBOX_PID=$!
        sleep 2
        if ! kill -0 $SINGBOX_PID 2>/dev/null; then
            echo "❌ sing-box failed to start! Logs:"
            cat /var/log/sing-box/sing-box.log
            echo "⚠️  Continuing with Caddy only..."
        fi
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
