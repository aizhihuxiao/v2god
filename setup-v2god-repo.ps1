# GitHub 仓库创建 PowerShell 脚本
# 仓库名称: v2god

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  创建 GitHub 仓库: v2god" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 配置信息
$repoName = "v2god"
$githubUsername = "aizhihuxiao"
$repoUrl = "https://github.com/$githubUsername/$repoName.git"

Write-Host "仓库名称: $repoName" -ForegroundColor Green
Write-Host "GitHub 用户: $githubUsername" -ForegroundColor Green
Write-Host "仓库地址: $repoUrl" -ForegroundColor Green
Write-Host ""

# 检查 Git 配置
Write-Host "⚙️  检查 Git 配置..." -ForegroundColor Yellow
$currentUser = git config user.name
$currentEmail = git config user.email

if (-not $currentUser) {
    Write-Host "设置 Git 用户名..." -ForegroundColor Yellow
    git config --global user.name $githubUsername
}

if (-not $currentEmail) {
    Write-Host "设置 Git 邮箱..." -ForegroundColor Yellow
    git config --global user.email "$githubUsername@users.noreply.github.com"
}

Write-Host "当前 Git 用户: $(git config user.name)" -ForegroundColor Green
Write-Host "当前 Git 邮箱: $(git config user.email)" -ForegroundColor Green
Write-Host ""

# 添加所有文件
Write-Host "📦 添加文件到 Git..." -ForegroundColor Yellow
git add .

# 提交更改
Write-Host "💾 提交更改..." -ForegroundColor Yellow
$commitMessage = @"
feat: V2God 高性能 NaiveProxy 代理服务

✨ 新特性:
- 反检测流量伪装优化
- BBR 网络性能调优
- 自动 SSL 证书申请
- Docker 容器化部署
- 多种部署脚本支持

🔧 文件:
- run.sh: 主部署脚本
- run-naicha.sh: naicha 专用版本
- run-interactive.sh: 交互式部署
- Dockerfile: 优化的镜像构建
- Caddyfile.example: 反检测配置模板
- build-and-push.sh: 镜像构建推送

🛡️ 安全优化:
- 微软更新服务器伪装
- IIS 服务器身份模拟
- 抗探测配置增强
- 标准 TLS 指纹避免检测
"@

git commit -m $commitMessage

Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "🎯 GitHub 仓库创建步骤" -ForegroundColor Cyan  
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. 📋 在 GitHub 上创建新仓库:" -ForegroundColor Yellow
Write-Host "   - 访问: https://github.com/new" -ForegroundColor White
Write-Host "   - 仓库名称: $repoName" -ForegroundColor White
Write-Host "   - 描述: 高性能 NaiveProxy 代理服务，专门优化反检测和网络性能" -ForegroundColor White
Write-Host "   - 设置为公开仓库" -ForegroundColor White
Write-Host "   - 不要初始化 README（我们已经有了）" -ForegroundColor White
Write-Host ""

Write-Host "2. 🔗 添加远程仓库并推送:" -ForegroundColor Yellow
Write-Host "   git remote remove origin" -ForegroundColor Green
Write-Host "   git remote add origin $repoUrl" -ForegroundColor Green
Write-Host "   git branch -M main" -ForegroundColor Green  
Write-Host "   git push -u origin main" -ForegroundColor Green
Write-Host ""

Write-Host "3. 🔑 如果需要身份验证:" -ForegroundColor Yellow
Write-Host "   - 使用 GitHub Personal Access Token" -ForegroundColor White
Write-Host "   - 或者配置 SSH 密钥" -ForegroundColor White
Write-Host ""

Write-Host "4. 🚀 推送完成后的后续操作:" -ForegroundColor Yellow
Write-Host "   - 更新 Docker Hub 镜像仓库名为 v2god" -ForegroundColor White
Write-Host "   - 运行 ./build-and-push.sh 构建新镜像" -ForegroundColor White
Write-Host "   - 更新 run.sh 中的镜像名称" -ForegroundColor White
Write-Host ""

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "✅ Git 仓库准备完成！" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Cyan

# 显示当前状态
Write-Host ""
Write-Host "📊 当前 Git 状态:" -ForegroundColor Yellow
git status --short

Write-Host ""
Write-Host "📂 仓库文件:" -ForegroundColor Yellow
Get-ChildItem -Force | Where-Object { $_.Name -notlike ".git" } | Format-Table Name, Length, LastWriteTime -AutoSize

Write-Host ""
Write-Host "🤖 自动执行命令提示:" -ForegroundColor Cyan
Write-Host "复制并执行以下命令来完成仓库切换:" -ForegroundColor Yellow
Write-Host ""
Write-Host "git remote remove origin" -ForegroundColor Green
Write-Host "git remote add origin $repoUrl" -ForegroundColor Green  
Write-Host "git branch -M main" -ForegroundColor Green
Write-Host "git push -u origin main" -ForegroundColor Green
Write-Host ""

# 询问是否自动执行
$autoExec = Read-Host "是否现在就执行远程仓库切换？(需要先在 GitHub 创建仓库) [y/N]"

if ($autoExec -eq 'y' -or $autoExec -eq 'Y') {
    Write-Host ""
    Write-Host "🔗 执行远程仓库切换..." -ForegroundColor Yellow
    
    try {
        git remote remove origin 2>$null
        git remote add origin $repoUrl
        git branch -M main
        
        Write-Host "⏳ 推送到新仓库..." -ForegroundColor Yellow
        git push -u origin main
        
        Write-Host ""
        Write-Host "🎉 成功！新仓库已创建并推送完成！" -ForegroundColor Green
        Write-Host "🔗 访问地址: https://github.com/$githubUsername/$repoName" -ForegroundColor Cyan
        
    } catch {
        Write-Host ""
        Write-Host "❌ 推送失败，可能原因：" -ForegroundColor Red
        Write-Host "   - GitHub 仓库尚未创建" -ForegroundColor Yellow
        Write-Host "   - 需要身份验证" -ForegroundColor Yellow
        Write-Host "   - 网络连接问题" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "请先在 GitHub 上创建仓库，然后手动执行上述命令。" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "📋 记住要先在 GitHub 上创建仓库，然后执行上述命令！" -ForegroundColor Yellow
}