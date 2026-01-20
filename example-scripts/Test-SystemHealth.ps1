# Bepoz System Health Check Script
# Description: Performs comprehensive system health check and generates report
# Type: PowerShell
# Category: Diagnostics

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Bepoz System Health Check" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$healthReport = @{
    Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    ComputerName = $env:COMPUTERNAME
    Checks = @()
    OverallStatus = "PASS"
}

function Add-HealthCheck {
    param(
        [string]$Category,
        [string]$Check,
        [string]$Status,  # PASS, WARN, FAIL
        [string]$Message,
        [string]$Details = ""
    )

    $color = switch ($Status) {
        "PASS" { "Green" }
        "WARN" { "Yellow" }
        "FAIL" { "Red" }
    }

    $icon = switch ($Status) {
        "PASS" { "✓" }
        "WARN" { "⚠" }
        "FAIL" { "✗" }
    }

    Write-Host "  $icon $Check`: " -NoNewline -ForegroundColor $color
    Write-Host "$Message" -ForegroundColor White

    if ($Details) {
        Write-Host "    Details: $Details" -ForegroundColor Gray
    }

    $Script:healthReport.Checks += @{
        Category = $Category
        Check = $Check
        Status = $Status
        Message = $Message
        Details = $Details
    }

    if ($Status -eq "FAIL") {
        $Script:healthReport.OverallStatus = "FAIL"
    }
    elseif ($Status -eq "WARN" -and $Script:healthReport.OverallStatus -ne "FAIL") {
        $Script:healthReport.OverallStatus = "WARN"
    }
}

# ==========================================
# OPERATING SYSTEM CHECKS
# ==========================================
Write-Host "Category: Operating System" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow

# OS Version
$os = Get-WmiObject -Class Win32_OperatingSystem
$osVersion = $os.Caption
if ($os.Version -ge "6.1") {
    Add-HealthCheck -Category "OS" -Check "Windows Version" -Status "PASS" `
        -Message $osVersion -Details "Version $($os.Version)"
}
else {
    Add-HealthCheck -Category "OS" -Check "Windows Version" -Status "FAIL" `
        -Message $osVersion -Details "Bepoz requires Windows 7/Server 2008 R2 or higher"
}

# Disk Space
$systemDrive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeSpaceGB = [math]::Round($systemDrive.FreeSpace / 1GB, 2)
$totalSpaceGB = [math]::Round($systemDrive.Size / 1GB, 2)
$percentFree = [math]::Round(($systemDrive.FreeSpace / $systemDrive.Size) * 100, 2)

if ($percentFree -lt 10) {
    Add-HealthCheck -Category "OS" -Check "Disk Space" -Status "FAIL" `
        -Message "$freeSpaceGB GB free ($percentFree%)" `
        -Details "Critical: Less than 10% free space remaining"
}
elseif ($percentFree -lt 20) {
    Add-HealthCheck -Category "OS" -Check "Disk Space" -Status "WARN" `
        -Message "$freeSpaceGB GB free ($percentFree%)" `
        -Details "Warning: Less than 20% free space remaining"
}
else {
    Add-HealthCheck -Category "OS" -Check "Disk Space" -Status "PASS" `
        -Message "$freeSpaceGB GB free of $totalSpaceGB GB ($percentFree%)"
}

# Memory
$memory = Get-WmiObject Win32_ComputerSystem
$totalMemoryGB = [math]::Round($memory.TotalPhysicalMemory / 1GB, 2)

if ($totalMemoryGB -lt 4) {
    Add-HealthCheck -Category "OS" -Check "RAM" -Status "WARN" `
        -Message "$totalMemoryGB GB installed" `
        -Details "Recommended: 4GB or more for optimal performance"
}
else {
    Add-HealthCheck -Category "OS" -Check "RAM" -Status "PASS" `
        -Message "$totalMemoryGB GB installed"
}

Write-Host ""

# ==========================================
# .NET FRAMEWORK CHECKS
# ==========================================
Write-Host "Category: .NET Framework" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow

$dotNetVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Version

if ($dotNetVersion) {
    if ([version]$dotNetVersion -ge [version]"4.5") {
        Add-HealthCheck -Category ".NET" -Check ".NET Framework" -Status "PASS" `
            -Message "Version $dotNetVersion"
    }
    else {
        Add-HealthCheck -Category ".NET" -Check ".NET Framework" -Status "FAIL" `
            -Message "Version $dotNetVersion" `
            -Details "Bepoz requires .NET Framework 4.5 or higher"
    }
}
else {
    Add-HealthCheck -Category ".NET" -Check ".NET Framework" -Status "FAIL" `
        -Message "Not detected" `
        -Details ".NET Framework 4.5 or higher is required"
}

Write-Host ""

# ==========================================
# SQL SERVER CHECKS
# ==========================================
Write-Host "Category: SQL Server" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow

# Check if SQL Server service is running
$sqlServices = Get-Service -Name "MSSQL*" -ErrorAction SilentlyContinue

if ($sqlServices) {
    $runningSqlServices = $sqlServices | Where-Object { $_.Status -eq "Running" }

    if ($runningSqlServices) {
        $serviceNames = ($runningSqlServices | ForEach-Object { $_.DisplayName }) -join ", "
        Add-HealthCheck -Category "SQL" -Check "SQL Server Service" -Status "PASS" `
            -Message "Running" -Details $serviceNames
    }
    else {
        Add-HealthCheck -Category "SQL" -Check "SQL Server Service" -Status "FAIL" `
            -Message "Not running" -Details "SQL Server service is installed but not running"
    }
}
else {
    Add-HealthCheck -Category "SQL" -Check "SQL Server Service" -Status "WARN" `
        -Message "Not detected" -Details "No SQL Server instances found on this machine"
}

# Check for BepozPOS database
$sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue

if ($sqlcmd) {
    $dbCheck = sqlcmd -S "localhost" -Q "SELECT name FROM sys.databases WHERE name='BepozPOS'" -h -1 2>&1

    if ($dbCheck -match "BepozPOS") {
        Add-HealthCheck -Category "SQL" -Check "BepozPOS Database" -Status "PASS" `
            -Message "Database exists"
    }
    else {
        Add-HealthCheck -Category "SQL" -Check "BepozPOS Database" -Status "WARN" `
            -Message "Database not found" -Details "Database may need to be initialized"
    }
}
else {
    Add-HealthCheck -Category "SQL" -Check "SQL Command Tools" -Status "WARN" `
        -Message "sqlcmd not found" -Details "SQL Server Command Line Utilities not installed"
}

Write-Host ""

# ==========================================
# BEPOZ APPLICATION CHECKS
# ==========================================
Write-Host "Category: Bepoz Application" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow

# Check installation
$bepozPath = "C:\Program Files\Bepoz"
if (Test-Path $bepozPath) {
    Add-HealthCheck -Category "Bepoz" -Check "Installation" -Status "PASS" `
        -Message "Installed at $bepozPath"

    # Check config file
    $configFile = Join-Path $bepozPath "config.xml"
    if (Test-Path $configFile) {
        Add-HealthCheck -Category "Bepoz" -Check "Configuration File" -Status "PASS" `
            -Message "config.xml exists"

        # Parse configuration
        try {
            [xml]$config = Get-Content $configFile
            $companyName = $config.BepozConfiguration.Client.CompanyName

            if ($companyName) {
                Add-HealthCheck -Category "Bepoz" -Check "Client Configuration" -Status "PASS" `
                    -Message "Configured for $companyName"
            }
        }
        catch {
            Add-HealthCheck -Category "Bepoz" -Check "Configuration File" -Status "WARN" `
                -Message "Unable to parse config.xml"
        }
    }
    else {
        Add-HealthCheck -Category "Bepoz" -Check "Configuration File" -Status "WARN" `
            -Message "config.xml not found" -Details "Application may not be configured"
    }

    # Check license file
    $licenseFile = Join-Path $bepozPath "license.dat"
    if (Test-Path $licenseFile) {
        Add-HealthCheck -Category "Bepoz" -Check "License File" -Status "PASS" `
            -Message "license.dat exists"
    }
    else {
        Add-HealthCheck -Category "Bepoz" -Check "License File" -Status "WARN" `
            -Message "license.dat not found" -Details "License may need to be installed"
    }
}
else {
    Add-HealthCheck -Category "Bepoz" -Check "Installation" -Status "FAIL" `
        -Message "Not installed" -Details "Bepoz POS not found at $bepozPath"
}

Write-Host ""

# ==========================================
# NETWORK CHECKS
# ==========================================
Write-Host "Category: Network" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Yellow

# Internet connectivity
try {
    $ping = Test-Connection -ComputerName "8.8.8.8" -Count 1 -Quiet
    if ($ping) {
        Add-HealthCheck -Category "Network" -Check "Internet Connectivity" -Status "PASS" `
            -Message "Connected"
    }
    else {
        Add-HealthCheck -Category "Network" -Check "Internet Connectivity" -Status "WARN" `
            -Message "No response" -Details "Unable to reach external servers"
    }
}
catch {
    Add-HealthCheck -Category "Network" -Check "Internet Connectivity" -Status "WARN" `
        -Message "Check failed" -Details $_.Exception.Message
}

# Firewall status
$firewallProfiles = Get-NetFirewallProfile -ErrorAction SilentlyContinue

if ($firewallProfiles) {
    $enabledProfiles = $firewallProfiles | Where-Object { $_.Enabled -eq $true }
    if ($enabledProfiles) {
        $profileNames = ($enabledProfiles | ForEach-Object { $_.Name }) -join ", "
        Add-HealthCheck -Category "Network" -Check "Windows Firewall" -Status "PASS" `
            -Message "Enabled" -Details "Active profiles: $profileNames"
    }
    else {
        Add-HealthCheck -Category "Network" -Check "Windows Firewall" -Status "WARN" `
            -Message "Disabled" -Details "No firewall profiles are enabled"
    }
}

Write-Host ""

# ==========================================
# GENERATE SUMMARY
# ==========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Health Check Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$passCount = ($healthReport.Checks | Where-Object { $_.Status -eq "PASS" }).Count
$warnCount = ($healthReport.Checks | Where-Object { $_.Status -eq "WARN" }).Count
$failCount = ($healthReport.Checks | Where-Object { $_.Status -eq "FAIL" }).Count
$totalCount = $healthReport.Checks.Count

Write-Host "Total Checks: $totalCount" -ForegroundColor White
Write-Host "  PASS: $passCount" -ForegroundColor Green
Write-Host "  WARN: $warnCount" -ForegroundColor Yellow
Write-Host "  FAIL: $failCount" -ForegroundColor Red
Write-Host ""

$overallColor = switch ($healthReport.OverallStatus) {
    "PASS" { "Green" }
    "WARN" { "Yellow" }
    "FAIL" { "Red" }
}

Write-Host "Overall Status: " -NoNewline
Write-Host $healthReport.OverallStatus -ForegroundColor $overallColor
Write-Host ""

# Save report to file
$reportPath = "C:\Temp\BepozDeployment\Logs\HealthCheck_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
$healthReport | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath

Write-Host "Detailed report saved to: $reportPath" -ForegroundColor Gray
Write-Host ""

# Exit with appropriate code
if ($healthReport.OverallStatus -eq "FAIL") {
    Write-Host "CRITICAL ISSUES FOUND - System may not function properly" -ForegroundColor Red
    exit 1
}
elseif ($healthReport.OverallStatus -eq "WARN") {
    Write-Host "WARNINGS FOUND - Review and address issues" -ForegroundColor Yellow
    exit 0
}
else {
    Write-Host "System health check passed successfully" -ForegroundColor Green
    exit 0
}
