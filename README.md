# V2God - 企业级 Web 应用平台

现代化的 Web 应用服务器，基于 Caddy 构建，专为企业内部应用和 API 网关设计。

## 核心功能

- 🌐 **自动 SSL** - 自动证书管理，支持通配符证书
- ⚡ **负载均衡** - 内置负载均衡和健康检查
- 🔐 **身份验证** - 企业级用户认证和授权
- 📡 **API 网关** - 微服务 API 路由和管理
- 📊 **访问统计** - 详细的访问日志和性能指标
- 🔄 **服务发现** - 动态服务注册和发现
- 🌍 **CDN 加速** - 集成主流 CDN 提供商
- 🐳 **容器化** - Docker 部署，支持 K8s

## 快速部署

### 1. 克隆项目
```bash
git clone https://github.com/aizhihuxiao/v2god.git
cd v2god
```

### 2. 配置服务
编辑配置文件设置你的域名和服务参数：
```bash
# 基础配置
DOMAIN="your-company.com"
API_PATH="api/v1" 
AUTH_TOKEN="your-auth-token"
ADMIN_USER="administrator"
ADMIN_PASS="secure-password-123"
```

### 3. 启动服务
```bash
# 自动部署
chmod +x deploy.sh
sudo ./deploy.sh

# 或手动配置
docker-compose up -d
```

### 4. 验证部署
```bash
# 检查服务状态
curl -k https://your-company.com/api/health

# 查看服务日志  
docker logs web-server
```

## 系统要求

| 组件 | 最低要求 | 推荐配置 |
|------|----------|----------|
| CPU | 1 核心 | 2+ 核心 |
| 内存 | 512MB | 1GB+ |
| 存储 | 5GB | 20GB+ |
| 网络 | 1Mbps | 100Mbps+ |

## 部署文件

| 文件 | 用途 |
|------|------|
| `deploy.sh` | 主部署脚本 |
| `setup-interactive.sh` | 交互式安装向导 |
| `setup-production.sh` | 生产环境部署 |
| `Dockerfile` | 容器镜像构建 |
| `server.conf` | 服务器配置模板 |
| `build-image.sh` | 镜像构建脚本 |

## 配置说明

### 基础配置
```yaml
# 服务配置
server:
  domain: "example.com"
  port: 443
  ssl: auto
  
# 认证配置  
auth:
  method: basic
  users:
    admin: "hashed-password"
    
# 上游服务
upstream:
  - name: "backend"
    url: "http://internal-service:8080"
    health_check: "/health"
```

### 高级配置
```yaml
# 负载均衡
load_balancer:
  algorithm: "round_robin"
  health_check:
    interval: 30s
    timeout: 5s
    
# 缓存策略
cache:
  static_files: 7d
  api_responses: 1h
  
# 日志配置
logging:
  level: "INFO"
  format: "json"
  retention: "30d"
```

## 服务管理

### 常用命令
```bash
# 查看服务状态
./status.sh

# 重启服务
./restart.sh

# 更新配置
./reload-config.sh

# 查看实时日志
./view-logs.sh

# 备份数据
./backup.sh
```

### 监控检查
```bash
# 服务健康检查
curl -f http://localhost/health || echo "Service Down"

# 性能指标
curl -s http://localhost/metrics | grep response_time

# 连接统计
netstat -an | grep :443 | wc -l
```

## 安全配置

### SSL 证书
- 自动申请 Let's Encrypt 证书
- 支持通配符域名证书
- 证书自动续期

### 访问控制
- 基于 IP 的访问限制
- 用户认证和授权
- API 密钥管理

### 安全加固
```bash
# 防火墙配置
ufw allow 22/tcp
ufw allow 80/tcp  
ufw allow 443/tcp
ufw enable

# 系统安全
fail2ban-client status
systemctl status sshd
```

## 故障排查

### 常见问题

#### 1. 服务无法启动
```bash
# 检查端口占用
netstat -tlnp | grep :443

# 检查配置文件
./validate-config.sh

# 查看错误日志
docker logs web-server --tail 50
```

#### 2. SSL 证书问题
```bash
# 检查证书状态
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# 手动续期证书
./renew-cert.sh

# 检查 DNS 配置
dig your-domain.com
```

#### 3. 性能问题
```bash
# 查看资源使用
docker stats web-server

# 网络连接统计
ss -tuln | grep :443

# 系统负载
top -p $(pgrep -f "web-server")
```

## 监控集成

### Prometheus 指标
```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'web-server'
    static_configs:
      - targets: ['localhost:9090']
```

### Grafana 仪表板
- 请求响应时间
- 错误率统计
- 连接数监控
- 系统资源使用

## 开发指南

### 本地开发
```bash
# 开发环境
docker-compose -f docker-compose.dev.yml up

# 代码检查
make lint

# 单元测试
make test

# 集成测试
make integration-test
```

### 构建发布
```bash
# 构建镜像
./build-image.sh

# 推送到仓库
./push-image.sh

# 部署到生产
./deploy-production.sh
```

## 许可协议

本项目基于 Apache 2.0 许可协议开源。详见 [LICENSE](LICENSE) 文件。

## 技术支持

- 📧 邮件：support@v2god.com
- 💬 社区：https://github.com/aizhihuxiao/v2god/discussions
- 📖 文档：https://docs.v2god.com
- 🐛 报告问题：https://github.com/aizhihuxiao/v2god/issues

---

> **注意**: 本项目适用于企业内部应用部署，请确保在合规的网络环境中使用。