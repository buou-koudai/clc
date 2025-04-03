# Cursor Lazy Cat Plugin Installer
# Simple PowerShell script to install the plugin

Write-Host "Cursor Lazy Cat Plugin Installer" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

# 插件名称和发布者前缀
$pluginPublisher = "buoukoudai"
$pluginName = "cursor-lazy-cat"
$fullPluginPrefix = "$pluginPublisher.$pluginName"
$githubRepo = "buou-koudai/clc"

# Step 1: 检查当前安装的插件版本
Write-Host "Step 1: Checking for installed plugin..." -ForegroundColor White

# 查找插件目录 - 只检查一个指定的目录
$pluginDir = "$env:USERPROFILE\.cursor\extensions"
$installedVersion = "0.0.0"
$pluginInstalled = $false

# 检查目录是否存在
Write-Host "  Checking directory: $pluginDir" -ForegroundColor Gray
if (Test-Path $pluginDir) {
    # 查找所有版本的插件目录
    $allPluginDirs = Get-ChildItem -Path $pluginDir -Directory | Where-Object { $_.Name -like "$fullPluginPrefix*" }

    # 解析版本号并按版本号排序（不是按字符串排序）
    $sortedPluginDirs = $allPluginDirs | ForEach-Object {
        # 尝试从目录名称提取版本
        $version = "0.0.0"
        $versionMatch = $_.Name -match "$fullPluginPrefix-(\d+\.\d+\.\d+)"
        if ($versionMatch) {
            $version = $Matches[1]
        } else {
            # 尝试从package.json读取版本
            $packageJsonPath = Join-Path $_.FullName "package.json"
            if (Test-Path $packageJsonPath) {
                try {
                    $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
                    if ($packageJson.version) {
                        $version = $packageJson.version
                    }
                } catch {
                    Write-Host "  WARNING: Could not parse package.json for $($_.Name)" -ForegroundColor Yellow
                }
            }
        }
        # 返回包含目录和版本信息的对象
        [PSCustomObject]@{
            Directory = $_
            Version = [version]$version
        }
    } | Sort-Object -Property Version -Descending

    # 检查是否存在多个版本
    if ($sortedPluginDirs.Count -gt 1) {
        Write-Host "  Found multiple versions of the plugin:" -ForegroundColor Yellow
        foreach ($item in $sortedPluginDirs) {
            Write-Host "    - $($item.Directory.Name) (v$($item.Version))" -ForegroundColor Yellow
        }
        Write-Host "  Will use the latest version and clean up old versions during installation." -ForegroundColor Yellow
    }

    # 获取最新版本
    $pluginInstallDir = if ($sortedPluginDirs.Count -gt 0) { $sortedPluginDirs[0].Directory } else { $null }
    
    if ($pluginInstallDir) {
        $pluginInstalled = $true
        
        # 尝试从目录名称提取版本
        $versionMatch = $pluginInstallDir.Name -match "$fullPluginPrefix-(\d+\.\d+\.\d+)"
        if ($versionMatch) {
            $installedVersion = $Matches[1]
        } else {
            # 尝试从package.json读取版本
            $packageJsonPath = Join-Path $pluginInstallDir.FullName "package.json"
            if (Test-Path $packageJsonPath) {
                try {
                    $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
                    if ($packageJson.version) {
                        $installedVersion = $packageJson.version
                    }
                } catch {
                    Write-Host "  WARNING: Could not parse package.json" -ForegroundColor Yellow
                }
            }
        }
        
        Write-Host "  Installed plugin found: $($pluginInstallDir.Name) (v$installedVersion)" -ForegroundColor Green
    } else {
        Write-Host "  No installed plugin found in $pluginDir" -ForegroundColor Yellow
    }
} else {
    Write-Host "  WARNING: Directory $pluginDir does not exist" -ForegroundColor Yellow
    
    # 创建目录
    try {
        New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null
        Write-Host "  Created directory: $pluginDir" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR: Failed to create directory: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if (-not $pluginInstalled) {
    Write-Host "  Will perform new installation." -ForegroundColor Yellow
}

# Step 2: 获取GitHub上的最新版本
Write-Host "`nStep 2: Checking latest version on GitHub..." -ForegroundColor White
try {
    $repoUrl = "https://api.github.com/repos/$githubRepo/releases/latest"
    $latestRelease = Invoke-RestMethod -Uri $repoUrl -ErrorAction Stop
    $latestVersion = $latestRelease.tag_name -replace "v", ""
    
    Write-Host "  Latest version on GitHub: v$latestVersion" -ForegroundColor Green
    
    # 比较版本
    if ($pluginInstalled) {
        $needsUpdate = [version]$latestVersion -gt [version]$installedVersion
        
        if (-not $needsUpdate) {
            Write-Host "`nYou already have the latest version installed. No update needed." -ForegroundColor Green
            Read-Host "Press Enter to exit"
            exit
        } else {
            Write-Host "`nA newer version is available. Will download and update." -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  ERROR: Failed to check latest version! $($_.Exception.Message)" -ForegroundColor Red
    
    # 如果已经安装了插件，但无法检查更新，询问是否继续
    if ($pluginInstalled) {
        $continuePrompt = Read-Host "  Continue with update anyway? (y/n)"
        if ($continuePrompt -ne "y" -and $continuePrompt -ne "Y") {
            Write-Host "`nExiting without update." -ForegroundColor Yellow
            exit
        }
    }
}

# Step 3: 下载最新版本
Write-Host "`nStep 3: Downloading latest plugin version..." -ForegroundColor White
try {
    # 构建正确的文件名（包含版本号）和下载URL
    $vsixFileName = "$pluginName-$latestVersion.vsix"
    $downloadUrl = "https://github.com/$githubRepo/releases/download/v$latestVersion/$vsixFileName"
    
    Write-Host "  Using GitHub direct download" -ForegroundColor Gray
    Write-Host "  Download URL: $downloadUrl" -ForegroundColor Gray
    
    Invoke-WebRequest -Uri $downloadUrl -OutFile "$pluginName.vsix" -ErrorAction Stop
    Write-Host "  Download completed successfully." -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Download failed! $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nInstallation failed. Please check your internet connection and try again." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

# Step 4: 检查Cursor是否运行
Write-Host "`nStep 4: Checking if Cursor is running..." -ForegroundColor White
$cursorProcess = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue
if ($cursorProcess) {
    Write-Host "  INFO: Cursor is currently running. Installation will proceed without closing it." -ForegroundColor Cyan
    Write-Host "  NOTE: You will need to restart Cursor after installation to activate the plugin." -ForegroundColor Yellow
}

# Step 5: 安装插件
Write-Host "`nStep 5: Installing plugin..." -ForegroundColor White

# 先尝试使用cursor命令
$cursorExists = Get-Command -Name cursor -ErrorAction SilentlyContinue
if ($cursorExists) {
    Write-Host "  Installing using Cursor CLI..." -ForegroundColor Green
    
    # 如果已安装则先卸载
    if ($pluginInstalled) {
        Write-Host "  Uninstalling previous version first..." -ForegroundColor Yellow
        Start-Process -FilePath "cursor" -ArgumentList "--uninstall-extension", "$fullPluginPrefix" -NoNewWindow -Wait
    }
    
    Start-Process -FilePath "cursor" -ArgumentList "--install-extension", "$pluginName.vsix" -NoNewWindow -Wait
} else {
    # 手动安装
    Write-Host "  WARNING: Cursor command not found in PATH, attempting manual installation..." -ForegroundColor Yellow
    
    # 确保插件目录存在
    if (-not (Test-Path $pluginDir)) {
        try {
            New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null
            Write-Host "  Created directory: $pluginDir" -ForegroundColor Green
        } catch {
            Write-Host "  ERROR: Could not create Cursor extensions directory! $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "`nInstallation failed. Please install manually using 'cursor --install-extension $pluginName.vsix'" -ForegroundColor Red
            Read-Host "Press Enter to exit"
            exit
        }
    }
    
    # 清理所有旧版本
    try {
        $allOldDirs = Get-ChildItem -Path $pluginDir -Directory | Where-Object { $_.Name -like "$fullPluginPrefix*" }
        if ($allOldDirs.Count -gt 0) {
            Write-Host "  Cleaning up all previous versions..." -ForegroundColor Yellow
            foreach ($oldDir in $allOldDirs) {
                Write-Host "    - Removing $($oldDir.Name)..." -ForegroundColor Gray
                Remove-Item -Path $oldDir.FullName -Recurse -Force -ErrorAction Stop
            }
            Write-Host "  All previous versions removed successfully." -ForegroundColor Green
        }
    } catch {
        Write-Host "  WARNING: Failed to remove some previous versions: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Will continue with installation anyway." -ForegroundColor Yellow
    }
    
    # 提取VSIX文件（实际上是ZIP文件）
    try {
        $targetDir = Join-Path $pluginDir "$fullPluginPrefix-$latestVersion"
        
        # 如果目录存在，删除它
        if (Test-Path $targetDir) {
            Remove-Item -Path $targetDir -Recurse -Force
        }
        
        Write-Host "  Extracting plugin to $targetDir..." -ForegroundColor Green
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory("$PWD\$pluginName.vsix", $targetDir)
    } catch {
        Write-Host "`n  ERROR: Manual installation failed! $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "`nInstallation failed. Please try again or install manually." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        exit
    }
}

# Step 6: 清理
Write-Host "`nStep 6: Cleaning up..." -ForegroundColor White
Remove-Item -Path "$pluginName.vsix" -Force

# 完成
if ($pluginInstalled) {
    Write-Host "`nUpdate successful! Plugin updated to v$latestVersion" -ForegroundColor Green
} else {
    Write-Host "`nInstallation successful! Plugin v$latestVersion has been installed." -ForegroundColor Green
}
Write-Host "Please restart Cursor to use the plugin." -ForegroundColor Green
Read-Host "Press Enter to exit" 