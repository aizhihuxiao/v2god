# 使用官方Caddy作为基础镜像
FROM caddy:2.8-alpine

# 元数据
LABEL maintainer="your-email@example.com" \
      description="Caddy Web Server" \
      version="1.0"

# 安装必要工具
RUN apk add --no-cache \
        ca-certificates \
        tzdata \
        wget

# 设置时区
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# 创建目录结构
RUN mkdir -p \
        /config/caddy \
        /data/caddy \
        /var/log/caddy \
        /etc/caddy && \
    chmod -R 777 /var/log/caddy

# 环境变量
ENV TZ=Asia/Shanghai

# 暴露端口
EXPOSE 80 443 2019

# 数据卷
VOLUME ["/config", "/data", "/var/log/caddy"]

# 工作目录
WORKDIR /srv

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:2019/ || exit 1

# 启动命令
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]