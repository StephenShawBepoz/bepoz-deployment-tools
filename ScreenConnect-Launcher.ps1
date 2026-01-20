# Bepoz Deployment Toolbox - ScreenConnect Bootstrap Launcher
# This is the script you paste into ScreenConnect to launch the deployment toolbox
# Version: 1.0

# Configuration - Update these before deploying
$GitHubRepo = "StephenShawBepoz/bepoz-deployment-tools"  # e.g., "johndoe/bepoz-tools"
$GitHubToken = "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"  # Your GitHub Personal Access Token
$MainScriptPath = "BepozDeploymentToolbox.ps1"  # Path to main script in repo

# Working directory
$WorkingDir = "C:\Temp\BepozDeployment"

# Create working directory if it doesn't exist
if (-not (Test-Path $WorkingDir)) {
    New-Item -Path $WorkingDir -ItemType Directory -Force | Out-Null
}

# Set location
Set-Location $WorkingDir

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Bepoz Deployment Toolbox Launcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to download file from GitHub
function Get-GitHubFile {
    param(
        [string]$FilePath,
        [string]$DestinationPath
    )

    $apiUrl = "https://api.github.com/repos/$GitHubRepo/contents/$FilePath"

    try {
        Write-Host "Downloading: $FilePath..." -ForegroundColor Yellow

        $headers = @{
            "Authorization" = "token $GitHubToken"
            "Accept" = "application/vnd.github.v3.raw"
        }

        Invoke-RestMethod -Uri $apiUrl -Headers $headers -OutFile $DestinationPath -ErrorAction Stop
        Write-Host "Downloaded successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to download: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Download the main script
$mainScriptLocal = Join-Path $WorkingDir "BepozDeploymentToolbox.ps1"

if (Get-GitHubFile -FilePath $MainScriptPath -DestinationPath $mainScriptLocal) {
    Write-Host ""
    Write-Host "Launching Bepoz Deployment Toolbox..." -ForegroundColor Green
    Write-Host ""

    # Update the script with GitHub credentials
    $scriptContent = Get-Content $mainScriptLocal -Raw
    $scriptContent = $scriptContent -replace 'GitHubRepo = "YOUR_GITHUB_USERNAME/bepoz-deployment-tools"', "GitHubRepo = `"$GitHubRepo`""
    $scriptContent = $scriptContent -replace 'GitHubToken = "YOUR_GITHUB_PAT_HERE"', "GitHubToken = `"$GitHubToken`""
    Set-Content -Path $mainScriptLocal -Value $scriptContent

    # Execute the main script
    & $mainScriptLocal
}
else {
    Write-Host ""
    Write-Host "Failed to download the main script. Please check:" -ForegroundColor Red
    Write-Host "  1. GitHub repository name is correct: $GitHubRepo" -ForegroundColor Yellow
    Write-Host "  2. GitHub Personal Access Token is valid" -ForegroundColor Yellow
    Write-Host "  3. Script path is correct: $MainScriptPath" -ForegroundColor Yellow
    Write-Host "  4. Internet connectivity is working" -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
}
