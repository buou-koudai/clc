# 插件自动更新脚本
# 适用于Cursor插件的自动更新脚本，适用于Windows系统
# 使用方法: curl -s https://raw.githubusercontent.com/buou-koudai/cle/main/update-cursor-plugin.ps1 | powershell -

# 配置参数
$GithubRepo = "buou-koudai/cle" # GitHub用户名和仓库名
$PluginName = "cursor-lazy-cat"
$PluginDisplayName = "Cursor Lazy Cat"
$ReleaseTagUrl = "https://api.github.com/repos/$GithubRepo/releases/latest"
$VSCodeExtDir = "$env:USERPROFILE\.vscode\extensions"
$CursorExtDir = "$env:USERPROFILE\.cursor\extensions"

# 颜色定义
function Write-ColorOutput($ForegroundColor) {
    # 保存当前的颜色
    $fc = $host.UI.RawUI.ForegroundColor
    
    # 设置新的颜色
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    
    # 如果参数数量大于1，那么剩余的参数都被当作要输出的对象
    if ($args.Count -gt 0) {
        Write-Output $args
    }
    
    # 恢复颜色
    $host.UI.RawUI.ForegroundColor = $fc
}

# 输出带颜色的文本
function Write-Info($message) { Write-ColorOutput Blue "[信息] $message" }
function Write-Success($message) { Write-ColorOutput Green "[成功] $message" }
function Write-Warning($message) { Write-ColorOutput Yellow "[警告] $message" }
function Write-Error($message) { Write-ColorOutput Red "[错误] $message" }

# 显示欢迎信息
Clear-Host
Write-Output ""
Write-Output "================================================="
Write-Success "$PluginDisplayName 自动更新工具"
Write-Output "================================================="
Write-Output ""

# 检查是否已安装插件
Write-Info "正在检查本地安装情况..."

$vsCodePluginDirs = Get-ChildItem -Path $VSCodeExtDir -Directory | Where-Object { $_.Name -like "buoukoudai.$PluginName*" }
$cursorPluginDirs = Get-ChildItem -Path $CursorExtDir -Directory | Where-Object { $_.Name -like "buoukoudai.$PluginName*" }

$vsCodePluginDir = $vsCodePluginDirs | Sort-Object { $_.Name } -Descending | Select-Object -First 1
$cursorPluginDir = $cursorPluginDirs | Sort-Object { $_.Name } -Descending | Select-Object -First 1

$localVersion = "0.0.0"
$vsCodeVersion = "0.0.0"
$cursorVersion = "0.0.0"
$installedLocation = ""

# 获取VSCode插件版本
if ($vsCodePluginDir) {
    try {
        $packageJsonPath = Join-Path $vsCodePluginDir.FullName "package.json"
        if (Test-Path $packageJsonPath) {
            $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
            $vsCodeVersion = $packageJson.version
            Write-Info "VSCode插件版本: $vsCodeVersion"
        }
    } catch {
        Write-Warning "无法读取VSCode插件版本: $_"
    }
} else {
    Write-Info "未检测到VSCode插件安装"
}

# 获取Cursor插件版本
if ($cursorPluginDir) {
    try {
        $packageJsonPath = Join-Path $cursorPluginDir.FullName "package.json"
        if (Test-Path $packageJsonPath) {
            $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
            $cursorVersion = $packageJson.version
            Write-Info "Cursor插件版本: $cursorVersion"
        }
    } catch {
        Write-Warning "无法读取Cursor插件版本: $_"
    }
} else {
    Write-Info "未检测到Cursor插件安装"
}

# 确定最终版本和安装位置
if ([version]$vsCodeVersion -gt [version]$cursorVersion) {
    $localVersion = $vsCodeVersion
    $installedLocation = "VSCode"
} elseif ([version]$cursorVersion -gt [version]$vsCodeVersion) {
    $localVersion = $cursorVersion
    $installedLocation = "Cursor"
} elseif ([version]$vsCodeVersion -eq [version]$cursorVersion -and [version]$vsCodeVersion -ne [version]"0.0.0") {
    $localVersion = $vsCodeVersion
    $installedLocation = "两者"
} else {
    Write-Warning "未检测到已安装的插件"
    $installedLocation = "未安装"
}

if ($installedLocation -ne "未安装") {
    Write-Success "已安装的插件版本: $localVersion (安装位置: $installedLocation)"
} else {
    Write-Warning "未检测到已安装的插件，将执行全新安装"
}

# 检查GitHub上的最新版本
Write-Info "正在从GitHub检查最新版本..."

try {
    # 使用GitHub API检查最新版本
    $headers = @{
        "Accept" = "application/vnd.github.v3+json"
    }
    $latestRelease = Invoke-RestMethod -Uri $ReleaseTagUrl -Headers $headers
    $latestVersion = $latestRelease.tag_name -replace "v", ""
    $downloadUrl = $latestRelease.assets | Where-Object { $_.name -like "*.vsix" } | Select-Object -First 1 -ExpandProperty browser_download_url

    Write-Success "GitHub最新版本: $latestVersion"

    # 比较版本号
    if ([version]$latestVersion -gt [version]$localVersion) {
        Write-Info "发现新版本! 本地版本: $localVersion, 最新版本: $latestVersion"
        
        # 下载新版本
        $tempDir = [System.IO.Path]::GetTempPath()
        $downloadPath = Join-Path $tempDir "buoukoudai.$PluginName-$latestVersion.vsix"
        
        Write-Info "正在下载新版本..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
        
        if (Test-Path $downloadPath) {
            Write-Success "下载完成: $downloadPath"
            
            # 卸载旧版本
            if ($installedLocation -eq "VSCode" -or $installedLocation -eq "两者") {
                Write-Info "正在卸载VSCode中的旧版本..."
                Start-Process -FilePath "code" -ArgumentList "--uninstall-extension", "buoukoudai.$PluginName" -NoNewWindow -Wait
            }
            
            if ($installedLocation -eq "Cursor" -or $installedLocation -eq "两者") {
                Write-Info "正在卸载Cursor中的旧版本..."
                Start-Process -FilePath "cursor" -ArgumentList "--uninstall-extension", "buoukoudai.$PluginName" -NoNewWindow -Wait
            }
            
            # 安装新版本
            Write-Info "正在安装新版本到VSCode中..."
            Start-Process -FilePath "code" -ArgumentList "--install-extension", $downloadPath -NoNewWindow -Wait
            
            Write-Info "正在安装新版本到Cursor中..."
            Start-Process -FilePath "cursor" -ArgumentList "--install-extension", $downloadPath -NoNewWindow -Wait
            
            Write-Success "更新完成! $PluginDisplayName 已更新到版本 $latestVersion"
            
            # 清理下载文件
            Remove-Item $downloadPath -Force
        } else {
            Write-Error "下载失败！"
        }
    } else {
        Write-Success "已经是最新版本！"
    }
} catch {
    Write-Error "检查或下载更新时出错: $_"
}

Write-Output ""
Write-Output "================================================="
Write-Success "操作完成"
Write-Output "================================================="

# 等待用户按键退出
Write-Output "按任意键退出..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 