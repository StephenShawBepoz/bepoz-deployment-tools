# Bepoz Client Configuration Script
# Description: Configures client-specific settings for Bepoz POS
# Type: PowerShell
# Category: Configuration

param(
    [Parameter(Mandatory=$true)]
    [string]$CompanyName,

    [Parameter(Mandatory=$true)]
    [string]$LicenseKey,

    [Parameter(Mandatory=$false)]
    [string]$Region = "US"
)

# Configuration paths
$installPath = "C:\Program Files\Bepoz"
$configFile = Join-Path $installPath "config.xml"
$licenseFile = Join-Path $installPath "license.dat"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Bepoz Client Configuration" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Company Name: $CompanyName" -ForegroundColor White
Write-Host "License Key: $($LicenseKey.Substring(0, [Math]::Min(10, $LicenseKey.Length)))..." -ForegroundColor White
Write-Host "Region: $Region" -ForegroundColor White
Write-Host ""

# Verify installation path exists
if (-not (Test-Path $installPath)) {
    Write-Host "ERROR: Bepoz installation not found at $installPath" -ForegroundColor Red
    Write-Host "Please install Bepoz POS before running configuration" -ForegroundColor Yellow
    exit 1
}

Write-Host "Step 1: Updating configuration file..." -ForegroundColor Yellow

# Create or update configuration XML
$configXml = @"
<?xml version="1.0" encoding="utf-8"?>
<BepozConfiguration>
  <Client>
    <CompanyName>$CompanyName</CompanyName>
    <Region>$Region</Region>
    <ConfiguredDate>$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</ConfiguredDate>
  </Client>
  <Database>
    <Server>localhost</Server>
    <Database>BepozPOS</Database>
    <IntegratedSecurity>true</IntegratedSecurity>
  </Database>
  <Licensing>
    <LicenseFile>$licenseFile</LicenseFile>
  </Licensing>
  <Regional>
    <CurrencySymbol>$(if($Region -eq 'US'){'$'}elseif($Region -eq 'UK'){'£'}elseif($Region -eq 'EU'){'€'}else{'$'})</CurrencySymbol>
    <DateFormat>$(if($Region -eq 'US'){'MM/dd/yyyy'}else{'dd/MM/yyyy'})</DateFormat>
    <TimeFormat>12h</TimeFormat>
  </Regional>
</BepozConfiguration>
"@

try {
    Set-Content -Path $configFile -Value $configXml -Force
    Write-Host "  ✓ Configuration file updated successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed to update configuration file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Installing license key..." -ForegroundColor Yellow

try {
    # Create license file (in production, this would validate and encrypt the license)
    $licenseData = @{
        CompanyName = $CompanyName
        LicenseKey = $LicenseKey
        IssuedDate = (Get-Date).ToString('yyyy-MM-dd')
        ExpiryDate = (Get-Date).AddYears(1).ToString('yyyy-MM-dd')
    }

    $licenseJson = $licenseData | ConvertTo-Json
    Set-Content -Path $licenseFile -Value $licenseJson -Force

    Write-Host "  ✓ License key installed successfully" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed to install license key: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 3: Configuring registry settings..." -ForegroundColor Yellow

try {
    # Create registry keys for Bepoz
    $regPath = "HKLM:\SOFTWARE\Bepoz\POS"

    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    Set-ItemProperty -Path $regPath -Name "CompanyName" -Value $CompanyName
    Set-ItemProperty -Path $regPath -Name "Region" -Value $Region
    Set-ItemProperty -Path $regPath -Name "InstallPath" -Value $installPath
    Set-ItemProperty -Path $regPath -Name "ConfiguredDate" -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

    Write-Host "  ✓ Registry settings configured" -ForegroundColor Green
}
catch {
    Write-Host "  ✗ Failed to configure registry: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Configuration completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration Summary:" -ForegroundColor White
Write-Host "  Company: $CompanyName" -ForegroundColor White
Write-Host "  Region: $Region" -ForegroundColor White
Write-Host "  Config File: $configFile" -ForegroundColor White
Write-Host "  License File: $licenseFile" -ForegroundColor White
Write-Host ""

exit 0
