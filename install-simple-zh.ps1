# Cursor Lazy Cat Plugin Installer - With GitHub Proxy
# PowerShell 脚本，用于安装/更新 Cursor Lazy Cat 插件，支持加速下载

Write-Host "Cursor Lazy Cat 插件安装器" -ForegroundColor Cyan
Write-Host "==============================" -ForegroundColor Cyan
Write-Host ""

$pluginPublisher = "buoukoudai"
$pluginName = "cursor-lazy-cat"
$fullPluginPrefix = "$pluginPublisher.$pluginName"
$githubRepo = "buou-koudai/clc"

Write-Host "步骤 1：检查已安装插件..." -ForegroundColor White

$pluginDir = "$env:USERPROFILE\.cursor\extensions"
$installedVersion = "0.0.0"
$pluginInstalled = $false

Write-Host "  检查目录：$pluginDir" -ForegroundColor Gray
if (Test-Path $pluginDir) {
    $pluginInstallDir = Get-ChildItem -Path $pluginDir -Directory | Where-Object { $_.Name -like "$fullPluginPrefix*" } | Sort-Object { $_.Name } -Descending | Select-Object -First 1

    if ($pluginInstallDir) {
        $pluginInstalled = $true
        if ($pluginInstallDir.Name -match "$fullPluginPrefix-(\d+\.\d+\.\d+)") {
            $installedVersion = $Matches[1]
        } else {
            $packageJsonPath = Join-Path $pluginInstallDir.FullName "package.json"
            if (Test-Path $packageJsonPath) {
                try {
                    $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
                    if ($packageJson.version) {
                        $installedVersion = $packageJson.version
                    }
                } catch {
                    Write-Host "  警告：无法解析 package.json" -ForegroundColor Yellow
                }
            }
        }
        Write-Host "  已安装插件：$($pluginInstallDir.Name) (v$installedVersion)" -ForegroundColor Green
    } else {
        Write-Host "  未在 $pluginDir 中找到插件" -ForegroundColor Yellow
    }
} else {
    Write-Host "  警告：目录 $pluginDir 不存在，正在创建..." -ForegroundColor Yellow
    try {
        New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null
        Write-Host "  已创建目录：$pluginDir" -ForegroundColor Green
    } catch {
        Write-Host "  错误：创建目录失败：$($_.Exception.Message)" -ForegroundColor Red
    }
}

if (-not $pluginInstalled) {
    Write-Host "  将执行新安装。" -ForegroundColor Yellow
}

Write-Host "`n步骤 2：检查 GitHub 上的最新版本..." -ForegroundColor White
try {
    $repoUrl = "https://api.github.com/repos/$githubRepo/releases/latest"
    $latestRelease = Invoke-RestMethod -Uri $repoUrl -ErrorAction Stop
    $latestVersion = $latestRelease.tag_name -replace "v", ""
    Write-Host "  GitHub 上的最新版本：v$latestVersion" -ForegroundColor Green

    if ($pluginInstalled) {
        $needsUpdate = [version]$latestVersion -gt [version]$installedVersion
        if (-not $needsUpdate) {
            Write-Host "`n你已安装最新版，无需更新。" -ForegroundColor Green
            Read-Host "按回车退出"
            exit
        } else {
            Write-Host "`n发现新版本，将下载并更新。" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  错误：无法检查最新版本！$($_.Exception.Message)" -ForegroundColor Red
    if ($pluginInstalled) {
        $continuePrompt = Read-Host "  是否继续安装？(y/n)"
        if ($continuePrompt -ne "y" -and $continuePrompt -ne "Y") {
            Write-Host "`n已退出安装。" -ForegroundColor Yellow
            exit
        }
    }
}

Write-Host "`n步骤 3：下载插件（使用加速）..." -ForegroundColor White
try {
    $vsixFileName = "$pluginName-$latestVersion.vsix"
    $rawDownloadUrl = "https://github.com/$githubRepo/releases/download/v$latestVersion/$vsixFileName"
    $downloadUrl = "https://gh-proxy.com/$rawDownloadUrl"  # 使用加速

    Write-Host "  下载链接：$downloadUrl" -ForegroundColor Gray
    Invoke-WebRequest -Uri $downloadUrl -OutFile "$pluginName.vsix" -ErrorAction Stop
    Write-Host "  下载成功。" -ForegroundColor Green
} catch {
    Write-Host "  错误：下载失败！$($_.Exception.Message)" -ForegroundColor Red
    Read-Host "按回车退出"
    exit
}

Write-Host "`n步骤 4：检测 Cursor 是否运行..." -ForegroundColor White
$cursorProcess = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue
if ($cursorProcess) {
    Write-Host "  提示：Cursor 当前正在运行，请稍后重启以生效插件。" -ForegroundColor Yellow
}

Write-Host "`n步骤 5：开始安装插件..." -ForegroundColor White
$cursorExists = Get-Command -Name cursor -ErrorAction SilentlyContinue
if ($cursorExists) {
    Write-Host "  使用 Cursor CLI 进行安装..." -ForegroundColor Green
    if ($pluginInstalled) {
        Write-Host "  正在卸载旧版本..." -ForegroundColor Yellow
        Start-Process -FilePath "cursor" -ArgumentList "--uninstall-extension", "$fullPluginPrefix" -NoNewWindow -Wait
    }
    Start-Process -FilePath "cursor" -ArgumentList "--install-extension", "$pluginName.vsix" -NoNewWindow -Wait
} else {
    Write-Host "  警告：未找到 cursor 命令，使用手动安装..." -ForegroundColor Yellow
    try {
        if (-not (Test-Path $pluginDir)) {
            New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null
            Write-Host "  创建目录：$pluginDir" -ForegroundColor Green
        }

        $targetDir = Join-Path $pluginDir "$fullPluginPrefix-$latestVersion"
        if (Test-Path $targetDir) {
            Remove-Item -Path $targetDir -Recurse -Force
        }

        Write-Host "  解压插件到：$targetDir..." -ForegroundColor Green
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$pluginName.vsix", $targetDir)
    } catch {
        Write-Host "`n  错误：手动安装失败！$($_.Exception.Message)" -ForegroundColor Red
        Read-Host "按回车退出"
        exit
    }
}

Write-Host "`n步骤 6：清理临时文件..." -ForegroundColor White
Remove-Item -Path "$pluginName.vsix" -Force

if ($pluginInstalled) {
    Write-Host "`n插件已成功更新到 v$latestVersion" -ForegroundColor Green
} else {
    Write-Host "`n插件 v$latestVersion 安装成功！" -ForegroundColor Green
}
Write-Host "请重启 Cursor 以激活插件。" -ForegroundColor Green
Read-Host "按回车退出"
