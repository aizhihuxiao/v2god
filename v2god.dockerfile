# 直接使用已验证可工作的基础镜像
FROM teddysun/caddy:latest

# 元数据
LABEL maintainer="your-email@example.com" \
      description="Modern Web Server with Enhanced Network Features" \
      version="1.0"

# 确保必要的工具已安装
RUN apk add --no-cache ca-certificates tzdata wget

# 设置时区
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# 创建必要的目录
RUN mkdir -p /var/log/caddy && \
    chmod 777 /var/log/caddy

# 环境变量
ENV TZ=Asia/Shanghai

# 暴露端口
EXPOSE 80 443 2019

# 数据卷
VOLUME ["/data", "/config", "/var/log/caddy"]

# 工作目录
WORKDIR /srv

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:2019/ || exit 1

# 启动命令
CMD ["caddy", "run", "--config", "/etc/caddy/Caddyfile", "--adapter", "caddyfile"]