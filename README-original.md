# V2God - 现代化 Web 服务器

🚀 基于 Caddy 的高性能 Web 服务器解决方案，适用于企业级应用部署

## ✨ 特性

- 🌐 **自动 HTTPS** - 自动申请和更新 SSL 证书
- ⚡ **高性能** - 现代化架构，支持 HTTP/2 和最新网络协议
- 🔒 **安全可靠** - 内置安全防护和访问控制
- 🔧 **易于部署** - Docker 容器化，一键部署
- 📊 **监控日志** - 完整的访问日志和性能监控
- 🔄 **自动更新** - 支持容器自动更新机制
- 🌍 **CDN 集成** - 支持主流 CDN 服务商
- � **多平台** - 支持 Linux x64/ARM64 架构

## 快速开始

### 1. 准备 Caddyfile

创建 `Caddyfile` 配置文件：

```caddyfile
:443, *.yourdomain.com {
    tls {
        dns cloudflare {env.CF_API_TOKEN}
        protocols tls1.2 tls1.3
    }

    route {
        forward_proxy {
            basic_auth {env.NAIVE_USER} {env.NAIVE_PASSWD}
            hide_ip
            hide_via
            probe_resistance
        }
        
        reverse_proxy https://www.cloudflare.com {
            header_up Host {upstream_hostport}
        }
    }
}

:80 {
    redir https://{host}{uri} permanent
}
```

### 2. 启动容器

```bash
docker run -d --name caddy \
    --restart=always \
    --net=host \
    -e CF_API_TOKEN=your_cloudflare_api_token \
    -v ./Caddyfile:/etc/caddy/Caddyfile:ro \
    -v caddy_data:/data/caddy \
    -v caddy_config:/config \
    -v caddy_logs:/var/log/caddy \
    aizhihuxiao/caddy-nv:latest
```

### 3. 使用部署脚本（推荐）

下载并运行自动化部署脚本：

```bash
chmod +x run.sh
./run.sh
```

或使用交互式配置：

```bash
chmod +x run-interactive.sh
./run-interactive.sh
```

## 环境变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `CF_API_TOKEN` | Cloudflare API Token | `abc123...` |

## 目录说明

- `/etc/caddy/Caddyfile` - Caddy 配置文件
- `/data/caddy` - 证书和数据存储
- `/config` - 配置存储
- `/var/log/caddy` - 日志文件

## 管理命令

```bash
# 查看日志
docker logs -f caddy

# 重启服务
docker restart caddy

# 查看证书
docker exec caddy caddy list-certificates

# 重新加载配置（优雅重启）
docker exec caddy caddy reload --config /etc/caddy/Caddyfile
```

## 性能优化

服务器端建议启用 BBR 和优化 TCP 参数：

```bash
# 启用 BBR
modprobe tcp_bbr
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
```

完整优化请参考 `run.sh` 脚本。

## 客户端配置

NaiveProxy 客户端配置示例：

```json
{
  "listen": "socks://127.0.0.1:1080",
  "proxy": "https://username:password@yourdomain.com"
}
```

## 更新镜像

```bash
# 拉取最新版本
docker pull aizhihuxiao/caddy-nv:latest

# 重启容器
docker restart caddy
```

使用 Watchtower 自动更新：

```bash
docker run -d --name watchtower \
    --restart=unless-stopped \
    -v /var/run/docker.sock:/var/run/docker.sock \
    containrrr/watchtower --cleanup --interval 21600
```

## 构建镜像

本地构建：

```bash
docker build --no-cache -t caddy-naiveproxy:latest .
```

## 安全建议

- ✅ 使用强密码
- ✅ 定期更换认证信息
- ✅ 在云服务商配置安全组，只开放必要端口
- ✅ 启用 Cloudflare CDN（可选）
- ✅ 定期查看日志，检测异常访问

## 故障排查

### 证书申请失败

```bash
# 检查 Cloudflare API Token 权限
# 需要 Zone:DNS:Edit 权限

# 查看详细日志
docker logs caddy
```

### 无法连接

```bash
# 检查端口是否开放
netstat -tlnp | grep 443

# 检查防火墙
ufw status

# 检查容器状态
docker ps
docker logs caddy
```

## 许可证

本项目基于开源组件构建：
- [Caddy](https://github.com/caddyserver/caddy) - Apache 2.0
- [NaiveProxy](https://github.com/klzgrad/forwardproxy) - BSD 3-Clause
- [Cloudflare DNS Plugin](https://github.com/caddy-dns/cloudflare) - Apache 2.0

## 相关链接

- [Caddy 文档](https://caddyserver.com/docs/)
- [Cloudflare API](https://developers.cloudflare.com/api/)
