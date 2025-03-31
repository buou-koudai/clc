# Plugin Auto-Update Script
# Automatic update script for Cursor plugin, for Windows systems
# Usage: curl -s https://raw.githubusercontent.com/buou-koudai/clc/main/update-cursor-plugin.ps1 | powershell -

# Configuration parameters
$GithubRepo = "buou-koudai/clc" # GitHub username and repository
$PluginName = "cursor-lazy-cat"
$PluginDisplayName = "Cursor Lazy Cat"
$ReleaseTagUrl = "https://api.github.com/repos/$GithubRepo/releases/latest"
$VSCodeExtDir = "$env:USERPROFILE\.vscode\extensions"
$CursorExtDir = "$env:USERPROFILE\.cursor\extensions"

# Color definitions
function Write-ColorOutput($ForegroundColor) {
    # Save current color
    $fc = $host.UI.RawUI.ForegroundColor
    
    # Set new color
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    
    # If there are more than one parameter, treat the rest as objects to output
    if ($args.Count -gt 0) {
        Write-Output $args
    }
    
    # Restore color
    $host.UI.RawUI.ForegroundColor = $fc
}

# Output colored text
function Write-Info($message) { Write-ColorOutput Blue "[INFO] $message" }
function Write-Success($message) { Write-ColorOutput Green "[SUCCESS] $message" }
function Write-Warning($message) { Write-ColorOutput Yellow "[WARNING] $message" }
function Write-Error($message) { Write-ColorOutput Red "[ERROR] $message" }

# Show welcome message
Clear-Host
Write-Output ""
Write-Output "================================================="
Write-Success "$PluginDisplayName Auto Update Tool"
Write-Output "================================================="
Write-Output ""

# Check if plugin is installed
Write-Info "Checking local installation..."

$vsCodePluginDirs = Get-ChildItem -Path $VSCodeExtDir -Directory | Where-Object { $_.Name -like "buoukoudai.$PluginName*" }
$cursorPluginDirs = Get-ChildItem -Path $CursorExtDir -Directory | Where-Object { $_.Name -like "buoukoudai.$PluginName*" }

$vsCodePluginDir = $vsCodePluginDirs | Sort-Object { $_.Name } -Descending | Select-Object -First 1
$cursorPluginDir = $cursorPluginDirs | Sort-Object { $_.Name } -Descending | Select-Object -First 1

$localVersion = "0.0.0"
$vsCodeVersion = "0.0.0"
$cursorVersion = "0.0.0"
$installedLocation = ""

# Get VSCode plugin version
if ($vsCodePluginDir) {
    try {
        $packageJsonPath = Join-Path $vsCodePluginDir.FullName "package.json"
        if (Test-Path $packageJsonPath) {
            $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
            $vsCodeVersion = $packageJson.version
            Write-Info "VSCode plugin version: $vsCodeVersion"
        }
    } catch {
        Write-Warning "Unable to read VSCode plugin version: $_"
    }
} else {
    Write-Info "No VSCode plugin installation detected"
}

# Get Cursor plugin version
if ($cursorPluginDir) {
    try {
        $packageJsonPath = Join-Path $cursorPluginDir.FullName "package.json"
        if (Test-Path $packageJsonPath) {
            $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
            $cursorVersion = $packageJson.version
            Write-Info "Cursor plugin version: $cursorVersion"
        }
    } catch {
        Write-Warning "Unable to read Cursor plugin version: $_"
    }
} else {
    Write-Info "No Cursor plugin installation detected"
}

# Determine final version and installation location
if ([version]$vsCodeVersion -gt [version]$cursorVersion) {
    $localVersion = $vsCodeVersion
    $installedLocation = "VSCode"
} elseif ([version]$cursorVersion -gt [version]$vsCodeVersion) {
    $localVersion = $cursorVersion
    $installedLocation = "Cursor"
} elseif ([version]$vsCodeVersion -eq [version]$cursorVersion -and [version]$vsCodeVersion -ne [version]"0.0.0") {
    $localVersion = $vsCodeVersion
    $installedLocation = "Both"
} else {
    Write-Warning "No installed plugin detected"
    $installedLocation = "Not installed"
}

if ($installedLocation -ne "Not installed") {
    Write-Success "Installed plugin version: $localVersion (Location: $installedLocation)"
} else {
    Write-Warning "No installed plugin detected, will perform a new installation"
}

# Check the latest version on GitHub
Write-Info "Checking the latest version from GitHub..."

try {
    # Use GitHub API to check the latest version
    $headers = @{
        "Accept" = "application/vnd.github.v3+json"
    }
    $latestRelease = Invoke-RestMethod -Uri $ReleaseTagUrl -Headers $headers
    $latestVersion = $latestRelease.tag_name -replace "v", ""
    $downloadUrl = $latestRelease.assets | Where-Object { $_.name -like "*.vsix" } | Select-Object -First 1 -ExpandProperty browser_download_url

    Write-Success "GitHub latest version: $latestVersion"

    # Compare version numbers
    if ([version]$latestVersion -gt [version]$localVersion) {
        Write-Info "New version found! Local version: $localVersion, Latest version: $latestVersion"
        
        # Download the new version
        $tempDir = [System.IO.Path]::GetTempPath()
        $downloadPath = Join-Path $tempDir "buoukoudai.$PluginName-$latestVersion.vsix"
        
        Write-Info "Downloading new version..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
        
        if (Test-Path $downloadPath) {
            Write-Success "Download completed: $downloadPath"
            
            # Uninstall old version
            if ($installedLocation -eq "VSCode" -or $installedLocation -eq "Both") {
                Write-Info "Uninstalling old version from VSCode..."
                Start-Process -FilePath "code" -ArgumentList "--uninstall-extension", "buoukoudai.$PluginName" -NoNewWindow -Wait
            }
            
            if ($installedLocation -eq "Cursor" -or $installedLocation -eq "Both") {
                Write-Info "Uninstalling old version from Cursor..."
                Start-Process -FilePath "cursor" -ArgumentList "--uninstall-extension", "buoukoudai.$PluginName" -NoNewWindow -Wait
            }
            
            # Install new version
            Write-Info "Installing new version in VSCode..."
            Start-Process -FilePath "code" -ArgumentList "--install-extension", $downloadPath -NoNewWindow -Wait
            
            Write-Info "Installing new version in Cursor..."
            Start-Process -FilePath "cursor" -ArgumentList "--install-extension", $downloadPath -NoNewWindow -Wait
            
            Write-Success "Update complete! $PluginDisplayName has been updated to version $latestVersion"
            
            # Clean up download file
            Remove-Item $downloadPath -Force
        } else {
            Write-Error "Download failed!"
        }
    } else {
        Write-Success "Already on the latest version!"
    }
} catch {
    Write-Error "Error checking or downloading updates: $_"
}

Write-Output ""
Write-Output "================================================="
Write-Success "Operation completed"
Write-Output "================================================="

# Wait for user key press to exit
Write-Output "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 
