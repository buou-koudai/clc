# Cursor Plugin Auto Update Script
# For Windows systems
# Usage: iwr -useb https://raw.githubusercontent.com/buou-koudai/clc/main/update-cursor-plugin.ps1 | iex

# Force ASCII encoding
$PSDefaultParameterValues['*:Encoding'] = 'ASCII'

# Set TLS to 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Configuration
$GithubRepo = "buou-koudai/clc"
$PluginName = "cursor-lazy-cat"
$PluginDisplayName = "Cursor Lazy Cat"
$ReleaseTagUrl = "https://api.github.com/repos/$GithubRepo/releases/latest"
$VSCodeExtDir = "$env:USERPROFILE\.vscode\extensions"
$CursorExtDir = "$env:USERPROFILE\.cursor\extensions"

# Color definitions
function Write-ColorText($Color, $Text) {
    $CurrentColor = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $Color
    Write-Output $Text
    $host.UI.RawUI.ForegroundColor = $CurrentColor
}

function Write-Info($message) { Write-ColorText Blue "[INFO] $message" }
function Write-Success($message) { Write-ColorText Green "[SUCCESS] $message" }
function Write-Warning($message) { Write-ColorText Yellow "[WARNING] $message" }
function Write-Error($message) { Write-ColorText Red "[ERROR] $message" }

# Main function
function Update-CursorPlugin {
    try {
        # Display welcome
        Clear-Host
        Write-Output ""
        Write-Output "================================================="
        Write-Success "$PluginDisplayName Auto Update Tool"
        Write-Output "================================================="
        Write-Output ""

        # Check installation
        Write-Info "Checking local installation..."

        $vsCodePluginDirs = Get-ChildItem -Path $VSCodeExtDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "buoukoudai.$PluginName*" }
        $cursorPluginDirs = Get-ChildItem -Path $CursorExtDir -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "buoukoudai.$PluginName*" }

        $vsCodePluginDir = $vsCodePluginDirs | Sort-Object { $_.Name } -Descending | Select-Object -First 1
        $cursorPluginDir = $cursorPluginDirs | Sort-Object { $_.Name } -Descending | Select-Object -First 1

        $localVersion = "0.0.0"
        $vsCodeVersion = "0.0.0"
        $cursorVersion = "0.0.0"
        $installedLocation = ""

        # Get VSCode version
        if ($vsCodePluginDir) {
            try {
                $packageJsonPath = Join-Path $vsCodePluginDir.FullName "package.json"
                if (Test-Path $packageJsonPath) {
                    $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
                    $vsCodeVersion = $packageJson.version
                    Write-Info "VSCode plugin version: $vsCodeVersion"
                }
            } catch {
                Write-Warning "Cannot read VSCode version"
            }
        } else {
            Write-Info "VSCode plugin not found"
        }

        # Get Cursor version
        if ($cursorPluginDir) {
            try {
                $packageJsonPath = Join-Path $cursorPluginDir.FullName "package.json"
                if (Test-Path $packageJsonPath) {
                    $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
                    $cursorVersion = $packageJson.version
                    Write-Info "Cursor plugin version: $cursorVersion"
                }
            } catch {
                Write-Warning "Cannot read Cursor version"
            }
        } else {
            Write-Info "Cursor plugin not found"
        }

        # Find final version
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
            Write-Warning "No plugin installed"
            $installedLocation = "None"
        }

        if ($installedLocation -ne "None") {
            Write-Success "Installed version: $localVersion (Location: $installedLocation)"
        } else {
            Write-Warning "No plugin installed, will perform fresh install"
        }

        # Check GitHub version
        Write-Info "Checking GitHub version..."

        try {
            $headers = @{
                "Accept" = "application/vnd.github.v3+json"
            }
            $latestRelease = Invoke-RestMethod -Uri $ReleaseTagUrl -Headers $headers
            $latestVersion = $latestRelease.tag_name -replace "v", ""
            $downloadUrl = $latestRelease.assets | Where-Object { $_.name -like "*.vsix" } | Select-Object -First 1 -ExpandProperty browser_download_url

            Write-Success "GitHub version: $latestVersion"

            # Compare versions
            if ([version]$latestVersion -gt [version]$localVersion) {
                Write-Info "New version found! Local: $localVersion, Latest: $latestVersion"
                
                # Download new version
                $tempDir = [System.IO.Path]::GetTempPath()
                $downloadPath = Join-Path $tempDir "buoukoudai.$PluginName-$latestVersion.vsix"
                
                Write-Info "Downloading..."
                Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
                
                if (Test-Path $downloadPath) {
                    Write-Success "Download completed"
                    
                    # Uninstall old
                    if ($installedLocation -eq "VSCode" -or $installedLocation -eq "Both") {
                        Write-Info "Uninstalling from VSCode..."
                        Start-Process -FilePath "code" -ArgumentList "--uninstall-extension", "buoukoudai.$PluginName" -NoNewWindow -Wait
                    }
                    
                    if ($installedLocation -eq "Cursor" -or $installedLocation -eq "Both") {
                        Write-Info "Uninstalling from Cursor..."
                        Start-Process -FilePath "cursor" -ArgumentList "--uninstall-extension", "buoukoudai.$PluginName" -NoNewWindow -Wait
                    }
                    
                    # Install new
                    Write-Info "Installing to VSCode..."
                    Start-Process -FilePath "code" -ArgumentList "--install-extension", $downloadPath -NoNewWindow -Wait
                    
                    Write-Info "Installing to Cursor..."
                    Start-Process -FilePath "cursor" -ArgumentList "--install-extension", $downloadPath -NoNewWindow -Wait
                    
                    Write-Success "Update complete! Version: $latestVersion"
                    
                    # Cleanup
                    Remove-Item $downloadPath -Force
                } else {
                    Write-Error "Download failed!"
                }
            } else {
                Write-Success "Already on latest version!"
            }
        } catch {
            Write-Error "Error checking GitHub: $_"
        }
    } catch {
        Write-Error "Update error: $_"
    } finally {
        Write-Output ""
        Write-Output "================================================="
        Write-Success "Operation completed"
        Write-Output "================================================="

        Write-Output "Press any key to exit..."
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    }
}

# Execute
Update-CursorPlugin 
