# 🚀 Docker构建和发布指南

## 快速开始

### 使用预构建镜像 (推荐)

```bash
# 拉取最新镜像
docker pull aizhihuxiao/web-server:latest

# 使用docker-compose启动
docker-compose up -d
```

### 本地构建

如果您需要自定义构建或使用最新代码：

#### Windows PowerShell
```powershell
# 给脚本执行权限
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 构建并推送到Docker Hub
.\build-and-push.ps1

# 或指定版本
.\build-and-push.ps1 -Version "v1.0.1" -DockerUsername "yourusername"
```

#### Linux/macOS
```bash
# 给脚本执行权限
chmod +x build-and-push.sh

# 构建并推送
./build-and-push.sh

# 或指定版本
./build-and-push.sh v1.0.1
```

## 自动化构建

### GitHub Actions自动构建

每次推送到main分支时，GitHub Actions会自动：
1. 构建多架构镜像 (amd64, arm64)
2. 推送到Docker Hub
3. 更新Docker Hub描述

需要在GitHub仓库中设置以下Secrets：
- `DOCKERHUB_USERNAME`: Docker Hub用户名
- `DOCKERHUB_TOKEN`: Docker Hub访问令牌

### 手动触发构建

在GitHub仓库的Actions页面，可以手动触发构建并指定：
- 服务器版本
- 插件版本  
- 是否强制重新构建

## 镜像说明

### 镜像标签
- `latest`: 最新构建版本
- `YYYYMMDD`: 按日期的版本标签
- `YYYYMMDD-<commit>`: 包含提交哈希的版本

### 镜像特性
- ✅ 基于Alpine Linux，体积小巧
- ✅ 支持多架构 (amd64, arm64)
- ✅ 集成高级网络功能
- ✅ 支持DNS解析优化
- ✅ 非root用户运行，安全性高
- ✅ 内置健康检查
- ✅ 亚洲/上海时区

## 配置要求

### 环境变量
```bash
CLOUDFLARE_API_TOKEN=your_cloudflare_token
WEB_USER=webuser
WEB_PASSWORD=your_secure_password
```

### 端口映射
- `80`: HTTP
- `443`: HTTPS  
- `2019`: Caddy管理API

### 卷映射
- `./Caddyfile:/etc/caddy/Caddyfile:ro`: 配置文件
- `caddy_data:/data`: 数据持久化
- `caddy_config:/config`: 配置持久化
- `./logs:/var/log/caddy`: 日志目录

## 故障排除

### Docker未安装
```powershell
# Windows - 安装Docker Desktop
# 从 https://www.docker.com/products/docker-desktop/ 下载

# 或使用Chocolatey
choco install docker-desktop
```

### 权限问题
```bash
# Linux - 将用户添加到docker组
sudo usermod -aG docker $USER
# 注销并重新登录
```

### 网络问题
如果构建时遇到网络问题，可以使用国内镜像：
```bash
# 在Dockerfile中添加
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories
```

## 更多信息

- 🐳 [Docker Hub页面](https://hub.docker.com/r/aizhihuxiao/web-server)
- 📚 [项目文档](./README.md)
- 🔧 [配置示例](./Caddyfile.example)