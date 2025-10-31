# 高性能代理转发优化版 Dockerfile

# ==================== 构建阶段 ====================
FROM golang:1.23-alpine AS builder

# 构建参数
ARG CADDY_VERSION=latest
ARG NAIVE_VERSION=naive
ARG XCADDY_VERSION=v0.4.4
ARG TARGETOS=linux
ARG TARGETARCH=amd64

# 优化Go构建环境 - 专注网络性能
ENV GOTOOLCHAIN=auto \
    CGO_ENABLED=0 \
    GOOS=${TARGETOS} \
    GOARCH=${TARGETARCH} \
    GO111MODULE=on

# 安装构建依赖
RUN apk add --no-cache git ca-certificates upx

# 安装 xcaddy
RUN go install github.com/caddyserver/xcaddy/cmd/xcaddy@${XCADDY_VERSION}

# 构建优化的 Caddy - 启用所有网络性能特性
RUN xcaddy build ${CADDY_VERSION} \
    --with github.com/caddyserver/forwardproxy@caddy2=github.com/klzgrad/forwardproxy@${NAIVE_VERSION} \
    --with github.com/caddy-dns/cloudflare \
    --output /tmp/caddy && \
    # 压缩二进制以减少内存占用
    upx --best /tmp/caddy

# ==================== 运行阶段 ====================
FROM alpine:3.19

# 元数据
LABEL maintainer="caddy-naiveproxy" \
      description="High-performance Caddy with NaiveProxy" \
      version="2.0"

# 安装运行时依赖 + 网络性能工具
RUN apk add --no-cache \
        ca-certificates \
        libcap \
        tzdata \
        wget \
        iperf3 \
        htop \
        ss \
        tcpdump && \
    # 设置时区
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    # 创建用户
    addgroup -g 1000 caddy && \
    adduser -D -u 1000 -G caddy caddy && \
    # 创建优化的目录结构
    mkdir -p \
        /config/caddy \
        /data/caddy \
        /var/log/caddy \
        /etc/caddy \
        /tmp/caddy && \
    # 设置目录权限
    chown -R caddy:caddy /config /data /var/log/caddy /etc/caddy /tmp/caddy

# 复制优化的 caddy
COPY --from=builder /tmp/caddy /usr/bin/caddy

# 设置权限和系统级网络优化
RUN setcap cap_net_bind_service=+ep /usr/bin/caddy && \
    chmod +x /usr/bin/caddy && \
    # 验证构建
    caddy version && \
    caddy list-modules | grep forward_proxy && \
    # 系统级网络优化配置
    echo '# 网络性能优化配置' > /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.core.netdev_max_backlog = 5000' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.ipv4.tcp_rmem = 4096 87380 134217728' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.ipv4.tcp_wmem = 4096 65536 134217728' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.ipv4.tcp_fastopen = 3' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.ipv4.tcp_slow_start_after_idle = 0' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.ipv4.tcp_no_metrics_save = 1' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.ipv4.tcp_moderate_rcvbuf = 1' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.ipv4.tcp_window_scaling = 1' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.ipv4.tcp_timestamps = 1' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.ipv4.tcp_sack = 1' >> /etc/sysctl.d/99-caddy-performance.conf && \
    echo 'net.ipv4.tcp_fack = 1' >> /etc/sysctl.d/99-caddy-performance.conf

# 创建网络性能监控脚本
RUN echo '#!/bin/sh' > /usr/local/bin/network-monitor.sh && \
    echo 'while true; do' >> /usr/local/bin/network-monitor.sh && \
    echo '  echo "=== $(date) ===" >> /var/log/caddy/network-stats.log' >> /usr/local/bin/network-monitor.sh && \
    echo '  ss -tuln >> /var/log/caddy/network-stats.log' >> /usr/local/bin/network-monitor.sh && \
    echo '  echo "Active connections: $(ss -t state established | wc -l)" >> /var/log/caddy/network-stats.log' >> /usr/local/bin/network-monitor.sh && \
    echo '  sleep 60' >> /usr/local/bin/network-monitor.sh && \
    echo 'done' >> /usr/local/bin/network-monitor.sh && \
    chmod +x /usr/local/bin/network-monitor.sh

# 高性能环境变量配置
ENV XDG_CONFIG_HOME=/config \
    XDG_DATA_HOME=/data \
    TZ=Asia/Shanghai \
    # Go运行时性能优化
    GOGC=100 \
    GOMEMLIMIT=1GiB \
    GOMAXPROCS=0 \
    # 网络性能关键优化
    GODEBUG=netdns=go,http2client=0,http2server=0 \
    # 连接池优化
    CADDY_MAXIDLECONNSPERHOST=100 \
    CADDY_MAXCONNSPERHOST=0 \
    CADDY_IDLECONNTIMEOUT=90s \
    CADDY_RESPONSEHEADERTIMEOUT=30s \
    CADDY_EXPECTCONTINUETIMEOUT=1s \
    # 缓冲区优化
    CADDY_READBUFFERSIZE=8192 \
    CADDY_WRITEBUFFERSIZE=8192

# 暴露端口
EXPOSE 80 443 2019

# 数据卷
VOLUME ["/config", "/data", "/var/log/caddy"]

# 切换到非 root 用户
USER caddy

# 工作目录
WORKDIR /config/caddy

# 增强的健康检查 - 检查代理性能
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD wget --no-verbose --tries=1 --timeout=5 --spider http://localhost:2019/config/ && \
        [ $(ss -t state established | wc -l) -lt 1000 ] || exit 1

# 启动命令 - 启用性能监控
CMD sh -c '/usr/local/bin/network-monitor.sh & exec caddy run --config /etc/caddy/Caddyfile --adapter caddyfile'
