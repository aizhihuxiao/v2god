# Docker镜像构建和发布脚本 (PowerShell版本)
# 使用方法: .\build-and-push.ps1 [版本号]

param(
    [string]$Version = "latest",
    [string]$DockerUsername = "aizhihuxiao"
)

$ErrorActionPreference = "Stop"

# 配置
$ImageName = "v2god-caddy"
$FullImageName = "$DockerUsername/$ImageName"
$DateTag = Get-Date -Format "yyyyMMdd"

Write-Host "🚀 开始构建和发布Docker镜像..." -ForegroundColor Green
Write-Host "镜像名称: $FullImageName" -ForegroundColor Cyan
Write-Host "版本标签: $Version, $DateTag" -ForegroundColor Cyan
Write-Host ""

# 检查Docker是否运行
try {
    docker info | Out-Null
    Write-Host "✅ Docker运行正常" -ForegroundColor Green
} catch {
    Write-Host "❌ Docker未运行或未安装" -ForegroundColor Red
    Write-Host "请先启动Docker Desktop或安装Docker"
    exit 1
}

# 检查Docker Hub登录状态
Write-Host "🔐 检查Docker Hub登录状态..." -ForegroundColor Yellow
try {
    $dockerInfo = docker info 2>$null
    if (-not ($dockerInfo -match "Username")) {
        Write-Host "需要登录Docker Hub..." -ForegroundColor Yellow
        docker login
    } else {
        Write-Host "✅ 已登录Docker Hub" -ForegroundColor Green
    }
} catch {
    Write-Host "登录Docker Hub..." -ForegroundColor Yellow
    docker login
}

Write-Host ""
Write-Host "📦 开始构建镜像..." -ForegroundColor Yellow

# 构建镜像
docker build -f v2god.dockerfile -t "${FullImageName}:${Version}" -t "${FullImageName}:${DateTag}" -t "${FullImageName}:latest" .

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 镜像构建失败" -ForegroundColor Red
    exit 1
}

Write-Host "✅ 镜像构建成功" -ForegroundColor Green
Write-Host ""

# 验证镜像
Write-Host "🔍 验证镜像..." -ForegroundColor Yellow
docker images | Select-String $ImageName

Write-Host ""
Write-Host "📤 推送到Docker Hub..." -ForegroundColor Yellow

# 推送镜像
docker push "${FullImageName}:${Version}"
docker push "${FullImageName}:${DateTag}"
docker push "${FullImageName}:latest"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ 镜像推送失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "✅ 构建和发布完成!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "镜像地址:" -ForegroundColor Cyan
Write-Host "  - ${FullImageName}:${Version}" -ForegroundColor White
Write-Host "  - ${FullImageName}:${DateTag}" -ForegroundColor White  
Write-Host "  - ${FullImageName}:latest" -ForegroundColor White
Write-Host ""
Write-Host "拉取命令:" -ForegroundColor Cyan
Write-Host "  docker pull ${FullImageName}:${Version}" -ForegroundColor White
Write-Host ""
Write-Host "🐳 Docker Compose使用方法:" -ForegroundColor Cyan
Write-Host "修改docker-compose.yml中的image字段为: ${FullImageName}:${Version}" -ForegroundColor White
Write-Host ""
Write-Host "🌐 查看镜像页面:" -ForegroundColor Cyan
Write-Host "https://hub.docker.com/r/${DockerUsername}/${ImageName}" -ForegroundColor White
Write-Host "========================================"