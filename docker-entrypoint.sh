#!/bin/sh
set -e

echo "========================================="
echo "Starting Caddy + sing-box container v1.1"
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
    
    # 提取域名（从 server_name 字段获取，用于定位证书目录）
    DOMAIN=$(grep -o '"server_name"[[:space:]]*:[[:space:]]*"[^"]*"' /etc/sing-box/config.json | cut -d'"' -f4 | head -1)
    # 提取根域名（例如从 "naicha.99gtr.com" 提取 "99gtr.com"）
    ROOT_DOMAIN=$(echo "$DOMAIN" | awk -F. '{if(NF>=2) print $(NF-1)"."$NF; else print $0}')
    if [ -z "$ROOT_DOMAIN" ]; then
        ROOT_DOMAIN="99gtr.com"  # 默认值
    fi
    echo "📋 Domain: $DOMAIN (root: $ROOT_DOMAIN)"
    
    # 先复制配置到可写位置（解决只读挂载问题）
    cp /etc/sing-box/config.json /tmp/sing-box-config.json
    
    # 证书查找函数 - 支持多种路径格式
    find_certificate() {
        local cert=""
        
        # 策略1: 通配符证书 wildcard_*.domain.com (最常见)
        cert=$(find /data/caddy/certificates -name "*.crt" -path "*/wildcard_*.${ROOT_DOMAIN}/*" 2>/dev/null | head -1)
        if [ -n "$cert" ] && [ -f "$cert" ]; then echo "$cert"; return 0; fi
        
        # 策略2: 完整域名证书 subdomain.domain.com
        if [ -n "$DOMAIN" ]; then
            cert=$(find /data/caddy/certificates -name "*.crt" -path "*/${DOMAIN}/*" 2>/dev/null | head -1)
            if [ -n "$cert" ] && [ -f "$cert" ]; then echo "$cert"; return 0; fi
        fi
        
        # 策略3: 根域名证书 domain.com
        cert=$(find /data/caddy/certificates -name "*.crt" -path "*/${ROOT_DOMAIN}/*" 2>/dev/null | head -1)
        if [ -n "$cert" ] && [ -f "$cert" ]; then echo "$cert"; return 0; fi
        
        # 策略4: 任意包含根域名的证书
        cert=$(find /data/caddy/certificates -name "*.crt" 2>/dev/null | grep -i "${ROOT_DOMAIN}" | head -1)
        if [ -n "$cert" ] && [ -f "$cert" ]; then echo "$cert"; return 0; fi
        
        # 策略5: 任意有效证书（最后备选）
        cert=$(find /data/caddy/certificates -name "*.crt" -type f 2>/dev/null | head -1)
        if [ -n "$cert" ] && [ -f "$cert" ]; then echo "$cert"; return 0; fi
        
        return 1
    }
    
    # 最多等待 180 秒
    WAIT_COUNT=0
    MAX_WAIT=180
    CERT_FOUND=false
    
    # 首次等待10秒，让Caddy有时间开始申请证书
    echo "⏳ Waiting 10s for Caddy to initialize certificate request..."
    sleep 10
    WAIT_COUNT=10
    
    while [ "$CERT_FOUND" = "false" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        # 使用多策略查找证书
        ACTUAL_CERT=$(find_certificate)
        
        if [ -n "$ACTUAL_CERT" ] && [ -f "$ACTUAL_CERT" ]; then
            ACTUAL_KEY="${ACTUAL_CERT%.crt}.key"
            
            if [ -f "$ACTUAL_KEY" ]; then
                echo "✅ Found certificate: $ACTUAL_CERT"
                echo "✅ Found key: $ACTUAL_KEY"
                echo "🔧 Auto-updating sing-box config with actual certificate paths..."
                
                # 替换证书路径（使用 | 作为分隔符避免路径中的 / 冲突）
                sed -i "s|\"certificate_path\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"certificate_path\": \"${ACTUAL_CERT}\"|g" /tmp/sing-box-config.json
                sed -i "s|\"key_path\"[[:space:]]*:[[:space:]]*\"[^\"]*\"|\"key_path\": \"${ACTUAL_KEY}\"|g" /tmp/sing-box-config.json
                
                echo "✅ Certificate paths updated successfully"
                CERT_FOUND=true
            else
                echo "⚠️  Certificate found but key missing: $ACTUAL_KEY"
            fi
        fi
        
        if [ "$CERT_FOUND" = "false" ]; then
            sleep 3
            WAIT_COUNT=$((WAIT_COUNT + 3))
            if [ $((WAIT_COUNT % 15)) -eq 0 ]; then
                echo "⏳ Waiting for certificate... (${WAIT_COUNT}s/${MAX_WAIT}s)"
                # 每15秒显示一次证书目录状态
                echo "📂 Certificate directory status:"
                ls -la /data/caddy/certificates/ 2>/dev/null || echo "   Directory not ready"
                find /data/caddy/certificates -name "*.crt" -o -name "*.key" 2>/dev/null | head -5 || true
            fi
        fi
    done
    
    if [ "$CERT_FOUND" = "true" ]; then
        echo "🚀 Starting sing-box with auto-detected certificate..."
        
        # 确保日志目录存在
        mkdir -p /var/log/sing-box
        
        # 启动 sing-box
        sing-box run -c /tmp/sing-box-config.json > /var/log/sing-box/sing-box.log 2>&1 &
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
