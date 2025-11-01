# 🚀 Caddy NaiveProxy + sing-box Reality 双协议部署指南

## 📋 项目简介

本项目在 Caddy + NaiveProxy 的基础上集成了 **sing-box Reality 协议**，实现：

- ✅ **NaiveProxy** (Caddy Forward Proxy) - 443端口
- ✅ **Reality** (VLESS + XTLS Reality) - 8443端口
- ✅ 两个协议独立工作，互不干扰
- ✅ 使用同一个域名，简化配置
- ✅ 多CA 智能切换，解决证书限制问题

## 🏗️ 架构说明

```
                     Internet
                        ↓
                  Your Domain (99gtr.com)
                        ↓
          ┌─────────────┴──────────────┐
          │                            │
      Port 443                      Port 8443
          │                            │
          ↓                            ↓
  ┌─────────────────┐        ┌─────────────────┐
  │     Caddy       │        │    sing-box     │
  │  (NaiveProxy)   │        │    (Reality)    │
  │  HTTPS + Proxy  │        │  VLESS+Reality  │
  └─────────────────┘        └─────────────────┘
```

### 工作原理

1. **Caddy 监听 443 端口** - 处理 NaiveProxy 流量（主要用途）
2. **sing-box 监听 8443 端口** - 处理 Reality 协议流量
3. **两个服务独立运行，互不干扰**
4. **使用同一个域名，不同端口**

### 端口分配

| 服务 | 外部端口 | 协议 | 用途 |
|------|---------|------|------|
| Caddy HTTPS | 443 | HTTPS | NaiveProxy 服务 |
| sing-box | 8443 | VLESS+Reality | Reality 协议 |
| Caddy HTTP | 80 | HTTP | 自动重定向 |

## 🚀 快速开始

### 1. 部署服务

#### 方式A: 使用默认配置（推荐）

```bash
chmod +x run.sh
./run.sh
```

#### 方式B: 交互式部署

```bash
chmod +x run-interactive.sh
./run-interactive.sh
```

#### 方式C: Naicha 配置

```bash
chmod +x run-naicha.sh
./run-naicha.sh
```

### 2. 查看 Reality 配置

部署完成后，Reality 配置会保存在：

```bash
cat ./singbox/reality-info.txt
```

输出示例：

```
Reality 配置信息
生成时间: 2025-11-01 10:30:00
========================================

服务器信息:
域名: 99gtr.com
端口: 8443
Reality SNI: 99gtr.com
握手伪装域名: www.catalog.update.microsoft.com

密钥信息:
UUID: 12345678-1234-1234-1234-123456789012
Private Key: YJnovvjJxsWQ6JKdDPqBjUs00dDs_6b3k1R5VEssAEw
Public Key: eSyY2BcdvGOJxglH4zJJGM4iCPPJPQf7MFu1ItHkxAg
Short ID: abc12345

========================================
架构说明:
1. Caddy 监听 443 端口 (NaiveProxy)
2. sing-box 监听 8443 端口 (Reality)
3. 两个协议独立工作，互不干扰
4. UUID 与 NaiveProxy 密码统一管理

客户端配置:
- 地址: 99gtr.com
- 端口: 8443
- UUID: 12345678-1234-1234-1234-123456789012
- Public Key: eSyY2BcdvGOJxglH4zJJGM4iCPPJPQf7MFu1ItHkxAg
- Short ID: abc12345
- SNI: 99gtr.com
- Server Name: www.catalog.update.microsoft.com
- Flow: xtls-rprx-vision
========================================
```

### 3. 配置防火墙

在云服务商控制台开放以下端口：

```bash
22/tcp    # SSH
80/tcp    # HTTP (自动跳转)
443/tcp   # HTTPS (NaiveProxy)
8443/tcp  # Reality
```

## 📱 客户端配置

### NaiveProxy 客户端

#### v2rayN / Nekobox / sing-box

使用 Naive 配置：

```json
{
  "type": "http",
  "tag": "naive-proxy",
  "server": "99gtr.com",
  "server_port": 443,
  "username": "your_username",
  "password": "your_password",
  "tls": {
    "enabled": true,
    "server_name": "99gtr.com"
  }
}
```

#### NaiveProxy 官方客户端

`config.json`:

```json
{
  "listen": "socks://127.0.0.1:1080",
  "proxy": "https://username:password@99gtr.com"
}
```

### Reality 客户端

#### v2rayN

1. 添加服务器 → 自定义配置服务器 → VLESS
2. 填写配置：

```
地址(address): 99gtr.com
端口(port): 8443
用户ID(id): [从 reality-info.txt 复制 UUID]
流控(flow): xtls-rprx-vision
加密(encryption): none
传输协议(network): tcp
传输层安全(security): reality

Reality 设置:
  Public Key: [从 reality-info.txt 复制]
  Short ID: [从 reality-info.txt 复制]
  SNI: 99gtr.com
  Server Name: www.catalog.update.microsoft.com
  Fingerprint: chrome
```

#### sing-box 配置

`config.json`:

```json
{
  "outbounds": [
    {
      "type": "vless",
      "tag": "reality-out",
      "server": "99gtr.com",
      "server_port": 8443,
      "uuid": "YOUR_UUID",
      "flow": "xtls-rprx-vision",
      "tls": {
        "enabled": true,
        "server_name": "99gtr.com",
        "reality": {
          "enabled": true,
          "public_key": "YOUR_PUBLIC_KEY",
          "short_id": "YOUR_SHORT_ID"
        }
      }
    }
  ]
}
```

#### Clash Meta 配置

`config.yaml`:

```yaml
proxies:
  - name: "Reality"
    type: vless
    server: 99gtr.com
    port: 8443
    uuid: YOUR_UUID
    network: tcp
    udp: true
    flow: xtls-rprx-vision
    tls: true
    servername: 99gtr.com
    reality-opts:
      public-key: YOUR_PUBLIC_KEY
      short-id: YOUR_SHORT_ID
    client-fingerprint: chrome
```

## 🔧 管理命令

### 查看日志

```bash
# Caddy 日志
docker logs -f caddy

# sing-box 日志
docker exec caddy cat /var/log/sing-box/sing-box.log

# 实时日志
docker exec caddy tail -f /var/log/sing-box/sing-box.log
```

### 服务管理

```bash
# 重启服务
docker restart caddy

# 停止服务
docker stop caddy

# 启动服务
docker start caddy

# 查看状态
docker ps | grep caddy
```

### 证书管理

```bash
# 查看证书列表
docker exec caddy caddy list-certificates

# 手动申请证书（如果自动失败）
chmod +x cert-manager.sh
./cert-manager.sh
```

### Reality 配置管理

```bash
# 重新生成 Reality 密钥
chmod +x generate-reality-keys.sh
./generate-reality-keys.sh

# 单独配置 Reality
chmod +x setup-reality.sh
./setup-reality.sh reality_path www.apple.com your-domain.com
```

## 🔍 故障排查

### Reality 连接失败

1. **检查 sing-box 是否监听 8443**
   ```bash
   # 在服务器上测试
   netstat -tlnp | grep :8443
   # 应该看到 sing-box 监听 8443
   ```

2. **检查 sing-box 运行状态**
   ```bash
   docker exec caddy ps aux | grep sing-box
   docker exec caddy cat /var/log/sing-box/sing-box.log
   ```

3. **检查防火墙**
   ```bash
   # 确保 8443 端口已在云控制台开放
   ```

4. **测试 Reality 连接**
   ```bash
   # 使用 v2ray 客户端测试连接
   # 或查看客户端日志
   ```

5. **查看 sing-box 配置**
   ```bash
   docker exec caddy cat /etc/sing-box/config.json
   # 确认端口为 8443
   ```

### NaiveProxy 连接失败

1. **检查 Caddy 日志**
   ```bash
   docker logs caddy --tail 50
   ```

2. **验证证书**
   ```bash
   docker exec caddy caddy list-certificates
   ```

3. **测试端口**
   ```bash
   curl -I https://your-domain.com
   ```

### 证书申请失败

使用多CA 智能切换：

```bash
chmod +x cert-manager.sh
./cert-manager.sh
```

查看尝试状态：

```bash
cat caddy/acme-state.txt
```

## 📊 性能优化

### 系统优化已自动应用

部署脚本已自动配置：

- ✅ BBR 拥塞控制
- ✅ TCP Fast Open
- ✅ 大缓冲区设置
- ✅ TIME_WAIT 快速回收

### 验证优化

```bash
# 检查 BBR
sysctl net.ipv4.tcp_congestion_control

# 检查 TCP Fast Open
sysctl net.ipv4.tcp_fastopen
```

## 🔒 安全建议

1. **定期更换密钥和 UUID**
   ```bash
   # 生成新的 UUID
   cat /proc/sys/kernel/random/uuid
   ```

2. **启用 UFW 防火墙**（可选）
   ```bash
   ufw allow 22/tcp
   ufw allow 80/tcp
   ufw allow 443/tcp
   ufw allow 8443/tcp
   ufw enable
   ```

3. **使用强密码**
   - Naive 用户名密码应使用复杂字符
   - Reality UUID 使用随机生成

4. **定期查看日志**
   ```bash
   docker logs caddy --tail 100
   ```

## ⚖️ 协议对比

| 特性 | NaiveProxy | Reality |
|------|------------|---------|
| 伪装性 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 速度 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 客户端支持 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 配置难度 | 简单 | 简单 |
| 资源占用 | 低 | 极低 |
| 抗封锁能力 | 强 | 极强 |

### 使用建议

- **NaiveProxy**: 适合浏览器扩展、桌面客户端
- **Reality**: 适合移动设备、高性能需求

## 📚 相关链接

- [Caddy 官方文档](https://caddyserver.com/docs/)
- [sing-box 文档](https://sing-box.sagernet.org/)
- [NaiveProxy 项目](https://github.com/klzgrad/naiveproxy)
- [Reality 协议说明](https://github.com/XTLS/REALITY)

## 🛠️ 高级配置

### 自定义 Reality 伪装域名

编辑 `run.sh` 或 `run-naicha.sh`:

```bash
reality_server_name="www.apple.com"  # 修改为你想要的域名
```

常用伪装域名推荐：
- `www.microsoft.com`
- `www.apple.com`
- `www.cloudflare.com`
- `www.amazon.com`
- `www.catalog.update.microsoft.com`

### 修改 Reality 端口

编辑 `singbox-config.json.example`:

```json
"listen_port": 4443  // 修改为其他端口
```

然后重新部署。

### 禁用 Reality

编辑部署脚本，设置：

```bash
enable_reality="false"
```

### 仅部署 Reality

1. 修改 `singbox-config.json.example` 中的端口为 443
2. 移除 Caddy 容器启动命令
3. 单独启动 sing-box

## 🔄 更新说明

### 更新 Docker 镜像

```bash
# 停止容器
docker stop caddy watchtower

# 删除旧容器
docker rm caddy watchtower

# 拉取最新镜像
docker pull aizhihuxiao/v2god:latest

# 重新部署
./run.sh
```

### 自动更新

Watchtower 已自动启动，每 24 小时检查一次更新。

## ❓ 常见问题

**Q: 为什么 Reality 使用 8443 端口而不是 443？**  
A: 为了确保两个协议都能正常工作。NaiveProxy 需要真实的 TLS 证书和 443 端口，Reality 使用独立端口避免冲突。

**Q: 需要配置 DNS 解析吗？**  
A: 是的，需要将你的域名解析到服务器 IP。只需一条 A 记录即可，两个协议共享同一个域名。

**Q: 可以修改 Reality 端口吗？**  
A: 可以。编辑 `run.sh` 中的 `reality_port="8443"` 改成你想要的端口，比如 `4443`。

**Q: NaiveProxy 和 Reality 真的独立工作吗？**  
A: 是的。Caddy 在 443 处理 NaiveProxy，sing-box 在 8443 处理 Reality，两者完全独立，互不干扰。

**Q: 为什么不用 fallback 机制共享 443 端口？**  
A: fallback 机制会在 sing-box 进行 TLS 终止，导致 Caddy 无法获得真实的 TLS 握手，NaiveProxy 需要完整的 TLS 连接才能正常工作。

**Q: 客户端连接时要注意什么？**  
A: **最重要的是端口：**
- NaiveProxy: 端口 443
- Reality: 端口 8443

**Q: 可以只用 Reality 不用 NaiveProxy 吗？**  
A: 可以。设置 `enable_reality="true"` 并修改 Reality 端口为 443，然后不启动 Caddy 即可。

## 📝 更新日志

### 2025-01-XX - 架构优化
- ✅ 调整架构：Caddy 443 + sing-box 8443
- ✅ 移除 fallback 机制，改为独立端口
- ✅ 确保 NaiveProxy 和 Reality 都能正常工作
- ✅ 简化配置，提高稳定性
- ✅ 添加 reality_port 变量支持自定义端口

### 2025-11-01 - 初始版本
- ✅ 集成 sing-box Reality 协议
- ✅ 实现双协议支持（NaiveProxy + Reality）
- ✅ 自动生成 Reality 密钥
- ✅ 添加完整客户端配置示例
- ✅ 保持 NaiveProxy 功能不变
- ✅ 多CA 智能切换支持

---

**部署完成后别忘记：**
1. ✅ 检查 `./singbox/reality-info.txt` 获取 Reality 配置
2. ✅ 在云控制台开放 80、443 和 8443 端口
3. ✅ 客户端配置时注意端口区分
4. ✅ 测试两个协议是否都能正常连接
