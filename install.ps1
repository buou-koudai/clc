# Cursor Lazy Cat 安装脚本
# 使用方法: iwr -useb https://raw.githubusercontent.com/buou-koudai/clc/main/install.ps1 | iex

# 设置输出编码为UTF-8，解决中文显示问题
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "正在安装 Cursor Lazy Cat 插件..." -ForegroundColor Cyan

$GithubRepo = "buou-koudai/clc" # GitHub用户名和仓库名
$PluginName = "cursor-lazy-cat"
$ReleaseUrl = "https://api.github.com/repos/$GithubRepo/releases/latest"

try {
    # 使用GitHub API检查最新版本
    $headers = @{
        "Accept" = "application/vnd.github.v3+json"
    }
    $latestRelease = Invoke-RestMethod -Uri $ReleaseUrl -Headers $headers
    $latestVersion = $latestRelease.tag_name -replace "v", ""
    $downloadUrl = $latestRelease.assets | Where-Object { $_.name -like "*.vsix" } | Select-Object -First 1 -ExpandProperty browser_download_url

    Write-Host "检测到最新版本: $latestVersion" -ForegroundColor Green
    
    # 下载插件
    $tempDir = [System.IO.Path]::GetTempPath()
    $downloadPath = Join-Path $tempDir "buoukoudai.$PluginName-$latestVersion.vsix"
    
    Write-Host "正在下载插件..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
    
    # 检查是否下载成功
    if (Test-Path $downloadPath) {
        Write-Host "下载完成!" -ForegroundColor Green
        
        # 尝试卸载旧版本
        Write-Host "正在卸载旧版本..." -ForegroundColor Cyan
        
        try {
            Start-Process -FilePath "cursor" -ArgumentList "--uninstall-extension", "buoukoudai.$PluginName" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        } catch {
            # 忽略卸载错误
        }
        
        # 安装新版本
        Write-Host "正在安装新版本..." -ForegroundColor Cyan
        Start-Process -FilePath "cursor" -ArgumentList "--install-extension", $downloadPath -NoNewWindow -Wait
        
        Write-Host "安装完成!" -ForegroundColor Green
        
        # 清理下载文件
        Remove-Item $downloadPath -Force
        
        Write-Host "Cursor Lazy Cat 插件安装成功!" -ForegroundColor Green
        Write-Host "版本: $latestVersion" -ForegroundColor Green
    } else {
        Write-Host "下载失败，请检查网络连接后重试" -ForegroundColor Red
    }
} catch {
    Write-Host "安装过程中出错: $_" -ForegroundColor Red
    
    # 检查是否是因为下载URL为空导致的问题
    if ($null -eq $downloadUrl -or $downloadUrl -eq "") {
        Write-Host "未能获取下载链接，请确保在GitHub上创建了Release并上传了.vsix文件" -ForegroundColor Yellow
    }
}

Write-Host "`n按任意键退出..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 