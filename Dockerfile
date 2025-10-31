# Enterprise Web Server - Production Build

# ==================== Build Stage ====================
FROM golang:1.23-alpine AS builder

# Build arguments
ARG CADDY_VERSION=latest
ARG NAIVE_VERSION=naive
ARG XCADDY_VERSION=v0.4.4

# Build environment
ENV GOTOOLCHAIN=auto \
    CGO_ENABLED=0 \
    GOOS=linux \
    GO111MODULE=on

# Install build dependencies
RUN apk add --no-cache git ca-certificates

# Install xcaddy
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@${XCADDY_VERSION}

# Build Caddy with required plugins
RUN xcaddy build ${CADDY_VERSION} \
    --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@${NAIVE_VERSION} \
    --with github.com/caddy-dns/cloudflare \
    --output /tmp/caddy

# ==================== 运行阶段 ====================
FROM alpine:3.19

# 元数据
LABEL maintainer="web-server-team" \
      description="Enterprise Web Application Platform" \
      version="1.0"

# 安装运行时依赖
RUN apk add --no-cache \
        ca-certificates \
        libcap \
        tzdata \
        wget && \
    # 设置时区
    cp /usr/share/zoneinfo/UTC /etc/localtime && \
    echo "UTC" > /etc/timezone && \
    # 创建用户
    addgroup -g 1000 caddy && \
    adduser -D -u 1000 -G caddy caddy && \
    # 创建目录结构
    mkdir -p \
        /config/caddy \
        /data/caddy \
        /var/log/caddy \
        /etc/caddy && \
    # 设置目录权限
    chown -R caddy:caddy /config /data /var/log/caddy /etc/caddy

# 复制构建的 caddy
COPY --from=builder /tmp/caddy /usr/bin/caddy

# 设置权限
RUN setcap cap_net_bind_service=+ep /usr/bin/caddy && \
    chmod +x /usr/bin/caddy && \
    # 验证构建
    caddy version

# 环境变量配置
ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data \
    TZ=UTC

# 暴露端口
EXPOSE 80 443 2019

# 数据卷
VOLUME ["/config", "/data", "/var/log/caddy"]

# 切换到非 root 用户
USER caddy

# 工作目录
WORKDIR /config/caddy

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:2019/config/ || exit 1

# 启动命令
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]
