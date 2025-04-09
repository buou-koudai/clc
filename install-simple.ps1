# Cursor Lazy Cat Plugin Installer
# Simple PowerShell script to install the plugin

Write-Host "Cursor Lazy Cat Plugin Installer" -ForegroundColor Cyan
Write-Host "============================" -ForegroundColor Cyan
Write-Host ""

$pluginPublisher = "buoukoudai"
$pluginName = "cursor-lazy-cat"
$fullPluginPrefix = "$pluginPublisher.$pluginName"
$githubRepo = "buou-koudai/clc"

Write-Host "Step 1: Checking for installed plugin..." -ForegroundColor White

$pluginDir = "$env:USERPROFILE\.cursor\extensions"
$installedVersion = "0.0.0"
$pluginInstalled = $false

Write-Host "  Checking directory: $pluginDir" -ForegroundColor Gray
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

Write-Host "`nStep 2: Checking latest version on GitHub..." -ForegroundColor White
try {
    $repoUrl = "https://api.github.com/repos/$githubRepo/releases/latest"
    $latestRelease = Invoke-RestMethod -Uri $repoUrl -ErrorAction Stop
    $latestVersion = $latestRelease.tag_name -replace "v", ""
    Write-Host "  Latest version on GitHub: v$latestVersion" -ForegroundColor Green

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
    if ($pluginInstalled) {
        $continuePrompt = Read-Host "  Continue with update anyway? (y/n)"
        if ($continuePrompt -ne "y" -and $continuePrompt -ne "Y") {
            Write-Host "`nExiting without update." -ForegroundColor Yellow
            exit
        }
    }
}

Write-Host "`nStep 3: Downloading latest plugin version..." -ForegroundColor White
try {
    $vsixFileName = "$pluginName-$latestVersion.vsix"
    $downloadUrl = "https://github.com/$githubRepo/releases/download/v$latestVersion/$vsixFileName"
    Write-Host "  Download URL: $downloadUrl" -ForegroundColor Gray
    Invoke-WebRequest -Uri $downloadUrl -OutFile "$pluginName.vsix" -ErrorAction Stop
    Write-Host "  Download completed successfully." -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Download failed! $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "`nInstallation failed. Please check your internet connection and try again." -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit
}

Write-Host "`nStep 4: Checking if Cursor is running..." -ForegroundColor White
$cursorProcess = Get-Process -Name "Cursor" -ErrorAction SilentlyContinue
if ($cursorProcess) {
    Write-Host "  INFO: Cursor is currently running. Installation will proceed without closing it." -ForegroundColor Cyan
    Write-Host "  NOTE: You will need to restart Cursor after installation to activate the plugin." -ForegroundColor Yellow
}

Write-Host "`nStep 5: Installing plugin..." -ForegroundColor White
$cursorExists = Get-Command -Name cursor -ErrorAction SilentlyContinue
if ($cursorExists) {
    Write-Host "  Installing using Cursor CLI..." -ForegroundColor Green
    if ($pluginInstalled) {
        Write-Host "  Uninstalling previous version first..." -ForegroundColor Yellow
        Start-Process -FilePath "cursor" -ArgumentList "--uninstall-extension", "$fullPluginPrefix" -NoNewWindow -Wait
    }
    Start-Process -FilePath "cursor" -ArgumentList "--install-extension", "$pluginName.vsix" -NoNewWindow -Wait
} else {
    Write-Host "  WARNING: Cursor command not found in PATH, attempting manual installation..." -ForegroundColor Yellow
    try {
        if (-not (Test-Path $pluginDir)) {
            New-Item -Path $pluginDir -ItemType Directory -Force | Out-Null
            Write-Host "  Created directory: $pluginDir" -ForegroundColor Green
        }

        $targetDir = Join-Path $pluginDir "$fullPluginPrefix-$latestVersion"
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

Write-Host "`nStep 6: Cleaning up..." -ForegroundColor White
Remove-Item -Path "$pluginName.vsix" -Force

if ($pluginInstalled) {
    Write-Host "`nUpdate successful! Plugin updated to v$latestVersion" -ForegroundColor Green
} else {
    Write-Host "`nInstallation successful! Plugin v$latestVersion has been installed." -ForegroundColor Green
}
Write-Host "Please restart Cursor to use the plugin." -ForegroundColor Green
Read-Host "Press Enter to exit"
