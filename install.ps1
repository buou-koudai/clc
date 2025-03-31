# Cursor Lazy Cat Installation Script
# Usage: iwr -useb https://raw.githubusercontent.com/buou-koudai/clc/main/install.ps1 | iex

Write-Host "Installing Cursor Lazy Cat plugin..." -ForegroundColor Cyan

$GithubRepo = "buou-koudai/clc" # GitHub username and repository
$PluginName = "cursor-lazy-cat"
$ReleaseUrl = "https://api.github.com/repos/$GithubRepo/releases/latest"

Write-Host "API URL: $ReleaseUrl" -ForegroundColor Gray

try {
    # Check latest version using GitHub API
    $headers = @{
        "Accept" = "application/vnd.github.v3+json"
    }
    
    Write-Host "Fetching release information..." -ForegroundColor Gray
    $latestRelease = Invoke-RestMethod -Uri $ReleaseUrl -Headers $headers
    
    Write-Host "Release info retrieved. Tag: $($latestRelease.tag_name)" -ForegroundColor Gray
    $latestVersion = $latestRelease.tag_name -replace "v", ""
    
    Write-Host "Checking assets..." -ForegroundColor Gray
    $assets = $latestRelease.assets
    Write-Host "Found $($assets.Count) assets" -ForegroundColor Gray
    
    foreach ($asset in $assets) {
        Write-Host " - Asset: $($asset.name)" -ForegroundColor Gray
    }
    
    $downloadUrl = $latestRelease.assets | Where-Object { $_.name -like "*.vsix" } | Select-Object -First 1 -ExpandProperty browser_download_url
    
    if ($downloadUrl) {
        Write-Host "Download URL found: $downloadUrl" -ForegroundColor Gray
    } else {
        Write-Host "No .vsix file found in release assets!" -ForegroundColor Red
        Write-Host "Please upload a .vsix file to the GitHub release" -ForegroundColor Red
        exit
    }

    Write-Host "Latest version detected: $latestVersion" -ForegroundColor Green
    
    # Download plugin
    $tempDir = [System.IO.Path]::GetTempPath()
    $downloadPath = Join-Path $tempDir "buoukoudai.$PluginName-$latestVersion.vsix"
    
    Write-Host "Downloading plugin..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $downloadUrl -OutFile $downloadPath
    
    # Check if download successful
    if (Test-Path $downloadPath) {
        Write-Host "Download completed!" -ForegroundColor Green
        
        # Try to uninstall old version
        Write-Host "Uninstalling old version..." -ForegroundColor Cyan
        
        try {
            Start-Process -FilePath "cursor" -ArgumentList "--uninstall-extension", "buoukoudai.$PluginName" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        } catch {
            # Ignore uninstall errors
        }
        
        # Install new version
        Write-Host "Installing new version..." -ForegroundColor Cyan
        Start-Process -FilePath "cursor" -ArgumentList "--install-extension", $downloadPath -NoNewWindow -Wait
        
        Write-Host "Installation completed!" -ForegroundColor Green
        
        # Clean up download file
        Remove-Item $downloadPath -Force
        
        Write-Host "Cursor Lazy Cat plugin installed successfully!" -ForegroundColor Green
        Write-Host "Version: $latestVersion" -ForegroundColor Green
    } else {
        Write-Host "Download failed, please check your network connection and try again" -ForegroundColor Red
    }
} catch {
    Write-Host "Error during installation: $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception)" -ForegroundColor Red
}

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 