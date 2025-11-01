# V2God - Caddy + NaiveProxy + sing-box AnyTLS

一键部署 Caddy NaiveProxy 和 sing-box AnyTLS 双协议代理服务。

## 功能特性

- ✅ **Caddy NaiveProxy** - 端口 443，支持 HTTP/2 伪装
- ✅ **sing-box AnyTLS** - 端口 8443，支持 uTLS 指纹模拟
- ✅ **自动证书** - 支持 ZeroSSL/Let's Encrypt 多 CA 自动切换
- ✅ **性能优化** - 预配置 BBR 加速和 TCP 优化
- ✅ **Docker 部署** - 一键启动，自动更新

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/aizhihuxiao/v2god.git
cd v2god
```

### 2. 配置参数

编辑 `run-naicha.sh`（或复制为自己的配置文件）：

```bash
domain="yourdomain.com"              # 你的域名
proxyPath="yourpath"                 # NaiveProxy 路径
cloudflareApiToken="your_token"      # Cloudflare API Token
naive_user="username"                # NaiveProxy 用户名
naive_passwd="password"              # NaiveProxy 密码

# sing-box AnyTLS 配置
enable_anytls="true"                 # 启用 AnyTLS
anytls_port="8443"                   # AnyTLS 端口
anytls_user="username"               # AnyTLS 用户名
anytls_password="password"           # AnyTLS 密码
anytls_sni="yourdomain.com"          # AnyTLS SNI
```

### 3. 运行部署脚本

```bash
chmod +x run-naicha.sh
./run-naicha.sh
```

### 4. 配置安全组

在云服务商控制台开放以下端口：

- `22/tcp` - SSH
- `80/tcp` - HTTP（证书验证）
- `443/tcp` - HTTPS（NaiveProxy）
- `8443/tcp` - sing-box AnyTLS

## 客户端配置

### NaiveProxy 配置

```json
{
  "protocol": "naive",
  "server": "yourdomain.com:443",
  "username": "username",
  "password": "password"
}
```

### sing-box AnyTLS 配置

```json
{
  "type": "anytls",
  "tag": "anytls-out",
  "server": "yourdomain.com",
  "server_port": 8443,
  "username": "username",
  "password": "password",
  "tls": {
    "enabled": true,
    "server_name": "yourdomain.com"
  }
}
```

**NekoBox 配置：**
- 协议：AnyTLS
- 服务器：yourdomain.com
- 端口：8443
- 用户名：username
- 密码：password

## 常用命令

```bash
# 查看容器状态
docker ps

# 查看日志
docker logs -f caddy

# 重启服务
docker restart caddy

# 停止服务
docker stop caddy

# 查看 sing-box 进程
docker exec caddy pgrep -f sing-box

# 查看端口监听
docker exec caddy ss -tlnp | grep 8443
```

## 配置文件说明

### singbox-config.json.example

sing-box AnyTLS 配置模板，部署脚本会自动生成实际配置。

占位符：
- `REALITY_UUID` - 用户名/密码
- `REALITY_SNI` - 服务器域名
- `wildcard_.domain` - 通配符证书路径
- `8443` - 监听端口

### Caddyfile.reality.example

Caddy 配置模板，支持：
- NaiveProxy forward_proxy
- DNS-01 证书验证
- 多 CA 自动切换（ZeroSSL/Let's Encrypt）

## 故障排查

### sing-box 未启动

```bash
# 检查配置文件
docker exec caddy cat /etc/sing-box/config.json

# 检查进程
docker exec caddy pgrep -f sing-box

# 查看启动日志
docker logs caddy | grep sing-box
```

### 客户端无法连接

1. **检查端口监听**
   ```bash
   docker exec caddy ss -tlnp | grep 8443
   ```

2. **检查证书路径**
   ```bash
   docker exec caddy ls -la /data/caddy/certificates/
   ```

3. **查看 sing-box 日志**
   ```bash
   docker exec caddy cat /etc/sing-box/logs/sing-box.log
   ```

4. **验证安全组规则**
   - 确保 8443/tcp 已开放

### 证书申请失败

脚本支持多 CA 自动切换：
1. 优先使用 ZeroSSL
2. 失败时自动切换到 Let's Encrypt
3. 手动重试：`./cert-manager.sh`

## 更新日志

### 2025-11-01
- ✅ 添加 sing-box AnyTLS 支持
- ✅ 修复 VLESS 协议错误（改用 AnyTLS 类型）
- ✅ 更新部署脚本自动生成配置
- ✅ 修复 docker-entrypoint.sh 日志路径

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request！
