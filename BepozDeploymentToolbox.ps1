# Bepoz Deployment Toolbox
# Main PowerShell application with Windows Forms UI
# Version: 1.0

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Configuration
$Script:Config = @{
    GitHubRepo = "StephenShawBepoz/bepoz-deployment-tools"  # Update this
    GitHubToken = "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"  # Update this with your Personal Access Token
    WorkingDirectory = "C:\Temp\BepozDeployment"
    LogDirectory = "C:\Temp\BepozDeployment\Logs"
    ManifestFile = "deployment-manifest.json"
    Version = "1.0.0"
}

# Initialize directories
function Initialize-Directories {
    if (-not (Test-Path $Script:Config.WorkingDirectory)) {
        New-Item -Path $Script:Config.WorkingDirectory -ItemType Directory -Force | Out-Null
    }
    if (-not (Test-Path $Script:Config.LogDirectory)) {
        New-Item -Path $Script:Config.LogDirectory -ItemType Directory -Force | Out-Null
    }
}

# Logging function
function Write-DeploymentLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"

    # Write to console
    Write-Host $logMessage -ForegroundColor $(
        switch ($Level) {
            "ERROR" { "Red" }
            "WARNING" { "Yellow" }
            "SUCCESS" { "Green" }
            default { "White" }
        }
    )

    # Write to log file
    $logFile = Join-Path $Script:Config.LogDirectory "deployment_$(Get-Date -Format 'yyyyMMdd').log"
    Add-Content -Path $logFile -Value $logMessage

    # Update UI log if available
    if ($Script:LogTextBox) {
        $Script:LogTextBox.AppendText("$logMessage`r`n")
        $Script:LogTextBox.SelectionStart = $Script:LogTextBox.Text.Length
        $Script:LogTextBox.ScrollToCaret()
    }
}

# Check prerequisites
function Test-Prerequisites {
    Write-DeploymentLog "Checking prerequisites..." "INFO"

    $issues = @()

    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        $issues += "PowerShell 5.0 or higher required (Current: $($PSVersionTable.PSVersion))"
    }

    # Check if running as administrator (for some operations)
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $Script:IsAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $Script:IsAdmin) {
        Write-DeploymentLog "Note: Not running as administrator. Some operations may require elevation." "WARNING"
    }

    # Check .NET version
    $dotNetVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full" -ErrorAction SilentlyContinue).Version
    if ($dotNetVersion -lt "4.5") {
        $issues += ".NET Framework 4.5 or higher required"
    }

    # Check internet connectivity
    try {
        $null = Test-Connection -ComputerName "github.com" -Count 1 -ErrorAction Stop
    } catch {
        $issues += "Cannot reach GitHub. Check internet connectivity."
    }

    if ($issues.Count -gt 0) {
        Write-DeploymentLog "Prerequisites check failed:" "ERROR"
        foreach ($issue in $issues) {
            Write-DeploymentLog "  - $issue" "ERROR"
        }
        return $false
    }

    Write-DeploymentLog "Prerequisites check passed" "SUCCESS"
    return $true
}

# Download file from GitHub
function Get-GitHubFile {
    param(
        [string]$FilePath,
        [string]$DestinationPath
    )

    $apiUrl = "https://api.github.com/repos/$($Script:Config.GitHubRepo)/contents/$FilePath"

    try {
        Write-DeploymentLog "Downloading: $FilePath" "INFO"

        $headers = @{
            "Authorization" = "token $($Script:Config.GitHubToken)"
            "Accept" = "application/vnd.github.v3.raw"
        }

        Invoke-RestMethod -Uri $apiUrl -Headers $headers -OutFile $DestinationPath
        Write-DeploymentLog "Downloaded to: $DestinationPath" "SUCCESS"
        return $true
    }
    catch {
        Write-DeploymentLog "Failed to download $FilePath : $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Download and parse manifest
function Get-DeploymentManifest {
    $manifestPath = Join-Path $Script:Config.WorkingDirectory $Script:Config.ManifestFile

    if (Get-GitHubFile -FilePath $Script:Config.ManifestFile -DestinationPath $manifestPath) {
        try {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
            Write-DeploymentLog "Manifest loaded successfully" "SUCCESS"
            return $manifest
        }
        catch {
            Write-DeploymentLog "Failed to parse manifest: $($_.Exception.Message)" "ERROR"
            return $null
        }
    }
    return $null
}

# Prompt for parameters
function Get-DeploymentParameters {
    param(
        [array]$Parameters
    )

    if ($Parameters.Count -eq 0) {
        return @{}
    }

    $paramForm = New-Object System.Windows.Forms.Form
    $paramForm.Text = "Deployment Parameters"
    $paramForm.Size = New-Object System.Drawing.Size(500, (150 + ($Parameters.Count * 60)))
    $paramForm.StartPosition = "CenterScreen"
    $paramForm.FormBorderStyle = "FixedDialog"
    $paramForm.MaximizeBox = $false
    $paramForm.MinimizeBox = $false

    $yPos = 20
    $paramValues = @{}
    $textBoxes = @{}

    foreach ($param in $Parameters) {
        $label = New-Object System.Windows.Forms.Label
        $label.Location = New-Object System.Drawing.Point(20, $yPos)
        $label.Size = New-Object System.Drawing.Size(460, 20)
        $label.Text = "$($param.Name):"
        if ($param.Description) {
            $label.Text += " ($($param.Description))"
        }
        $paramForm.Controls.Add($label)

        $textBox = New-Object System.Windows.Forms.TextBox
        $textBox.Location = New-Object System.Drawing.Point(20, ($yPos + 25))
        $textBox.Size = New-Object System.Drawing.Size(440, 20)
        if ($param.DefaultValue) {
            $textBox.Text = $param.DefaultValue
        }
        $paramForm.Controls.Add($textBox)
        $textBoxes[$param.Name] = $textBox

        $yPos += 60
    }

    $okButton = New-Object System.Windows.Forms.Button
    $okButton.Location = New-Object System.Drawing.Point(280, ($yPos + 10))
    $okButton.Size = New-Object System.Drawing.Size(80, 30)
    $okButton.Text = "OK"
    $okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $paramForm.AcceptButton = $okButton
    $paramForm.Controls.Add($okButton)

    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Location = New-Object System.Drawing.Point(380, ($yPos + 10))
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.Text = "Cancel"
    $cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $paramForm.Controls.Add($cancelButton)

    $result = $paramForm.ShowDialog()

    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($param in $Parameters) {
            $paramValues[$param.Name] = $textBoxes[$param.Name].Text
        }
        return $paramValues
    }

    return $null
}

# Execute deployment item
function Invoke-DeploymentItem {
    param(
        [object]$Item
    )

    Write-DeploymentLog "========================================" "INFO"
    Write-DeploymentLog "Starting deployment: $($Item.Name)" "INFO"
    Write-DeploymentLog "Description: $($Item.Description)" "INFO"

    # Get parameters if needed
    $parameters = @{}
    if ($Item.Parameters -and $Item.Parameters.Count -gt 0) {
        Write-DeploymentLog "Parameters required for this deployment" "INFO"
        $parameters = Get-DeploymentParameters -Parameters $Item.Parameters

        if ($null -eq $parameters) {
            Write-DeploymentLog "Deployment cancelled by user" "WARNING"
            return $false
        }

        Write-DeploymentLog "Parameters collected:" "INFO"
        foreach ($key in $parameters.Keys) {
            Write-DeploymentLog "  $key = $($parameters[$key])" "INFO"
        }
    }

    # Download files
    $downloadedFiles = @()
    foreach ($file in $Item.Files) {
        $localPath = Join-Path $Script:Config.WorkingDirectory $file.Split('/')[-1]
        if (Get-GitHubFile -FilePath $file -DestinationPath $localPath) {
            $downloadedFiles += $localPath
        } else {
            Write-DeploymentLog "Failed to download required file: $file" "ERROR"
            return $false
        }
    }

    # Execute based on type
    $success = $false
    switch ($Item.Type) {
        "PowerShell" {
            $success = Invoke-PowerShellScript -ScriptPath $downloadedFiles[0] -Parameters $parameters
        }
        "Executable" {
            $success = Invoke-Executable -ExePath $downloadedFiles[0] -Arguments $Item.Arguments -Parameters $parameters
        }
        "SQL" {
            $success = Invoke-SQLScript -ScriptPath $downloadedFiles[0] -Parameters $parameters
        }
        "Batch" {
            $success = Invoke-BatchScript -ScriptPath $downloadedFiles[0] -Parameters $parameters
        }
        default {
            Write-DeploymentLog "Unknown deployment type: $($Item.Type)" "ERROR"
            $success = $false
        }
    }

    if ($success) {
        Write-DeploymentLog "Deployment completed successfully: $($Item.Name)" "SUCCESS"
    } else {
        Write-DeploymentLog "Deployment failed: $($Item.Name)" "ERROR"
    }

    Write-DeploymentLog "========================================" "INFO"
    return $success
}

# Execute PowerShell script
function Invoke-PowerShellScript {
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters
    )

    try {
        Write-DeploymentLog "Executing PowerShell script: $ScriptPath" "INFO"

        # Build parameter string
        $paramString = ""
        foreach ($key in $Parameters.Keys) {
            $paramString += " -$key `"$($Parameters[$key])`""
        }

        $output = & $ScriptPath @Parameters 2>&1

        foreach ($line in $output) {
            Write-DeploymentLog $line.ToString() "INFO"
        }

        if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
            Write-DeploymentLog "PowerShell script executed successfully" "SUCCESS"
            return $true
        } else {
            Write-DeploymentLog "PowerShell script failed with exit code: $LASTEXITCODE" "ERROR"
            return $false
        }
    }
    catch {
        Write-DeploymentLog "PowerShell script execution error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Execute executable
function Invoke-Executable {
    param(
        [string]$ExePath,
        [string]$Arguments,
        [hashtable]$Parameters
    )

    try {
        Write-DeploymentLog "Executing: $ExePath" "INFO"

        # Replace parameter placeholders in arguments
        $finalArgs = $Arguments
        foreach ($key in $Parameters.Keys) {
            $finalArgs = $finalArgs -replace "\{\{$key\}\}", $Parameters[$key]
        }

        Write-DeploymentLog "Arguments: $finalArgs" "INFO"

        $process = Start-Process -FilePath $ExePath -ArgumentList $finalArgs -Wait -PassThru -NoNewWindow

        if ($process.ExitCode -eq 0) {
            Write-DeploymentLog "Executable completed successfully" "SUCCESS"
            return $true
        } else {
            Write-DeploymentLog "Executable failed with exit code: $($process.ExitCode)" "ERROR"
            return $false
        }
    }
    catch {
        Write-DeploymentLog "Executable execution error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Execute SQL script
function Invoke-SQLScript {
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters
    )

    try {
        Write-DeploymentLog "Executing SQL script: $ScriptPath" "INFO"

        if (-not $Parameters.ContainsKey("ServerName") -or -not $Parameters.ContainsKey("DatabaseName")) {
            Write-DeploymentLog "SQL scripts require ServerName and DatabaseName parameters" "ERROR"
            return $false
        }

        $serverName = $Parameters["ServerName"]
        $databaseName = $Parameters["DatabaseName"]

        # Check if sqlcmd is available
        $sqlcmd = Get-Command sqlcmd -ErrorAction SilentlyContinue
        if (-not $sqlcmd) {
            Write-DeploymentLog "sqlcmd not found. Please install SQL Server Command Line Utilities." "ERROR"
            return $false
        }

        $output = sqlcmd -S $serverName -d $databaseName -i $ScriptPath -b 2>&1

        foreach ($line in $output) {
            Write-DeploymentLog $line.ToString() "INFO"
        }

        if ($LASTEXITCODE -eq 0) {
            Write-DeploymentLog "SQL script executed successfully" "SUCCESS"
            return $true
        } else {
            Write-DeploymentLog "SQL script failed with exit code: $LASTEXITCODE" "ERROR"
            return $false
        }
    }
    catch {
        Write-DeploymentLog "SQL script execution error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Execute batch script
function Invoke-BatchScript {
    param(
        [string]$ScriptPath,
        [hashtable]$Parameters
    )

    try {
        Write-DeploymentLog "Executing batch script: $ScriptPath" "INFO"

        # Create temporary batch file with parameters set as environment variables
        $tempBatch = Join-Path $Script:Config.WorkingDirectory "temp_execution.bat"
        $batchContent = "@echo off`r`n"

        foreach ($key in $Parameters.Keys) {
            $batchContent += "set $key=$($Parameters[$key])`r`n"
        }

        $batchContent += "call `"$ScriptPath`"`r`n"
        Set-Content -Path $tempBatch -Value $batchContent

        $output = cmd /c $tempBatch 2>&1

        foreach ($line in $output) {
            Write-DeploymentLog $line.ToString() "INFO"
        }

        Remove-Item $tempBatch -Force -ErrorAction SilentlyContinue

        if ($LASTEXITCODE -eq 0) {
            Write-DeploymentLog "Batch script executed successfully" "SUCCESS"
            return $true
        } else {
            Write-DeploymentLog "Batch script failed with exit code: $LASTEXITCODE" "ERROR"
            return $false
        }
    }
    catch {
        Write-DeploymentLog "Batch script execution error: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Create main UI
function Show-MainUI {
    # Create main form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Bepoz Deployment Toolbox v$($Script:Config.Version)"
    $form.Size = New-Object System.Drawing.Size(900, 700)
    $form.StartPosition = "CenterScreen"
    $form.MinimumSize = New-Object System.Drawing.Size(900, 700)

    # Create menu strip
    $menuStrip = New-Object System.Windows.Forms.MenuStrip

    $fileMenu = New-Object System.Windows.Forms.ToolStripMenuItem
    $fileMenu.Text = "&File"

    $refreshMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $refreshMenuItem.Text = "Refresh Catalog"
    $refreshMenuItem.Add_Click({
        Load-DeploymentCatalog
    })
    $fileMenu.DropDownItems.Add($refreshMenuItem)

    $exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem
    $exitMenuItem.Text = "Exit"
    $exitMenuItem.Add_Click({
        $form.Close()
    })
    $fileMenu.DropDownItems.Add($exitMenuItem)

    $menuStrip.Items.Add($fileMenu)
    $form.Controls.Add($menuStrip)

    # Create split container
    $splitContainer = New-Object System.Windows.Forms.SplitContainer
    $splitContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $splitContainer.Orientation = [System.Windows.Forms.Orientation]::Vertical
    $splitContainer.SplitterDistance = 400
    $splitContainer.Location = New-Object System.Drawing.Point(0, 24)
    $form.Controls.Add($splitContainer)

    # Left panel - Deployment catalog
    $leftPanel = $splitContainer.Panel1

    $catalogLabel = New-Object System.Windows.Forms.Label
    $catalogLabel.Text = "Available Deployments:"
    $catalogLabel.Location = New-Object System.Drawing.Point(10, 10)
    $catalogLabel.Size = New-Object System.Drawing.Size(200, 20)
    $catalogLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $leftPanel.Controls.Add($catalogLabel)

    # Category filter
    $categoryLabel = New-Object System.Windows.Forms.Label
    $categoryLabel.Text = "Category:"
    $categoryLabel.Location = New-Object System.Drawing.Point(10, 40)
    $categoryLabel.Size = New-Object System.Drawing.Size(70, 20)
    $leftPanel.Controls.Add($categoryLabel)

    $Script:CategoryCombo = New-Object System.Windows.Forms.ComboBox
    $Script:CategoryCombo.Location = New-Object System.Drawing.Point(80, 38)
    $Script:CategoryCombo.Size = New-Object System.Drawing.Size(300, 20)
    $Script:CategoryCombo.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    $Script:CategoryCombo.Add_SelectedIndexChanged({
        Filter-DeploymentList
    })
    $leftPanel.Controls.Add($Script:CategoryCombo)

    # Deployment list
    $Script:DeploymentListView = New-Object System.Windows.Forms.ListView
    $Script:DeploymentListView.Location = New-Object System.Drawing.Point(10, 70)
    $Script:DeploymentListView.Size = New-Object System.Drawing.Size(380, 500)
    $Script:DeploymentListView.View = [System.Windows.Forms.View]::Details
    $Script:DeploymentListView.FullRowSelect = $true
    $Script:DeploymentListView.GridLines = $true
    $Script:DeploymentListView.MultiSelect = $false

    $Script:DeploymentListView.Columns.Add("Name", 200) | Out-Null
    $Script:DeploymentListView.Columns.Add("Category", 90) | Out-Null
    $Script:DeploymentListView.Columns.Add("Type", 70) | Out-Null

    $Script:DeploymentListView.Add_SelectedIndexChanged({
        if ($Script:DeploymentListView.SelectedItems.Count -gt 0) {
            $selectedItem = $Script:DeploymentListView.SelectedItems[0]
            $deploymentItem = $Script:AllDeployments | Where-Object { $_.Name -eq $selectedItem.Text }

            if ($deploymentItem) {
                $Script:DescriptionTextBox.Text = $deploymentItem.Description
                if ($deploymentItem.Parameters) {
                    $Script:DescriptionTextBox.Text += "`r`n`r`nRequired Parameters:`r`n"
                    foreach ($param in $deploymentItem.Parameters) {
                        $Script:DescriptionTextBox.Text += "  - $($param.Name): $($param.Description)`r`n"
                    }
                }
            }
        }
    })

    $leftPanel.Controls.Add($Script:DeploymentListView)

    $deployButton = New-Object System.Windows.Forms.Button
    $deployButton.Location = New-Object System.Drawing.Point(10, 580)
    $deployButton.Size = New-Object System.Drawing.Size(180, 40)
    $deployButton.Text = "Deploy Selected"
    $deployButton.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $deployButton.Add_Click({
        if ($Script:DeploymentListView.SelectedItems.Count -gt 0) {
            $selectedItem = $Script:DeploymentListView.SelectedItems[0]
            $deploymentItem = $Script:AllDeployments | Where-Object { $_.Name -eq $selectedItem.Text }

            if ($deploymentItem) {
                $deployButton.Enabled = $false
                Invoke-DeploymentItem -Item $deploymentItem
                $deployButton.Enabled = $true
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select a deployment item first.", "No Selection",
                [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    })
    $leftPanel.Controls.Add($deployButton)

    $openLogsButton = New-Object System.Windows.Forms.Button
    $openLogsButton.Location = New-Object System.Drawing.Point(210, 580)
    $openLogsButton.Size = New-Object System.Drawing.Size(180, 40)
    $openLogsButton.Text = "Open Log Folder"
    $openLogsButton.Add_Click({
        Start-Process explorer.exe $Script:Config.LogDirectory
    })
    $leftPanel.Controls.Add($openLogsButton)

    # Right panel - Description and logs
    $rightPanel = $splitContainer.Panel2

    $descriptionLabel = New-Object System.Windows.Forms.Label
    $descriptionLabel.Text = "Description:"
    $descriptionLabel.Location = New-Object System.Drawing.Point(10, 10)
    $descriptionLabel.Size = New-Object System.Drawing.Size(200, 20)
    $descriptionLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $rightPanel.Controls.Add($descriptionLabel)

    $Script:DescriptionTextBox = New-Object System.Windows.Forms.TextBox
    $Script:DescriptionTextBox.Location = New-Object System.Drawing.Point(10, 35)
    $Script:DescriptionTextBox.Size = New-Object System.Drawing.Size(460, 120)
    $Script:DescriptionTextBox.Multiline = $true
    $Script:DescriptionTextBox.ScrollBars = "Vertical"
    $Script:DescriptionTextBox.ReadOnly = $true
    $rightPanel.Controls.Add($Script:DescriptionTextBox)

    $logLabel = New-Object System.Windows.Forms.Label
    $logLabel.Text = "Deployment Log:"
    $logLabel.Location = New-Object System.Drawing.Point(10, 165)
    $logLabel.Size = New-Object System.Drawing.Size(200, 20)
    $logLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $rightPanel.Controls.Add($logLabel)

    $Script:LogTextBox = New-Object System.Windows.Forms.TextBox
    $Script:LogTextBox.Location = New-Object System.Drawing.Point(10, 190)
    $Script:LogTextBox.Size = New-Object System.Drawing.Size(460, 430)
    $Script:LogTextBox.Multiline = $true
    $Script:LogTextBox.ScrollBars = "Vertical"
    $Script:LogTextBox.ReadOnly = $true
    $Script:LogTextBox.Font = New-Object System.Drawing.Font("Consolas", 9)
    $rightPanel.Controls.Add($Script:LogTextBox)

    # Load catalog function
    $Script:AllDeployments = @()

    function Load-DeploymentCatalog {
        $Script:DeploymentListView.Items.Clear()
        $Script:CategoryCombo.Items.Clear()
        $Script:LogTextBox.Clear()

        Write-DeploymentLog "Loading deployment catalog from GitHub..." "INFO"

        $manifest = Get-DeploymentManifest

        if ($manifest) {
            $Script:AllDeployments = $manifest.Deployments

            # Get unique categories
            $categories = @("All") + ($Script:AllDeployments | Select-Object -ExpandProperty Category -Unique | Sort-Object)
            foreach ($category in $categories) {
                $Script:CategoryCombo.Items.Add($category) | Out-Null
            }
            $Script:CategoryCombo.SelectedIndex = 0

            Write-DeploymentLog "Loaded $($Script:AllDeployments.Count) deployment items" "SUCCESS"
        } else {
            Write-DeploymentLog "Failed to load deployment catalog" "ERROR"
        }
    }

    function Filter-DeploymentList {
        $Script:DeploymentListView.Items.Clear()

        $selectedCategory = $Script:CategoryCombo.SelectedItem

        $filteredItems = $Script:AllDeployments
        if ($selectedCategory -and $selectedCategory -ne "All") {
            $filteredItems = $Script:AllDeployments | Where-Object { $_.Category -eq $selectedCategory }
        }

        foreach ($item in $filteredItems) {
            $listItem = New-Object System.Windows.Forms.ListViewItem($item.Name)
            $listItem.SubItems.Add($item.Category) | Out-Null
            $listItem.SubItems.Add($item.Type) | Out-Null
            $Script:DeploymentListView.Items.Add($listItem) | Out-Null
        }
    }

    # Initial load
    Load-DeploymentCatalog

    # Show form
    $form.Add_Shown({
        $form.Activate()
    })

    [void]$form.ShowDialog()
}

# Main entry point
function Start-DeploymentToolbox {
    Write-Host "========================================"
    Write-Host "Bepoz Deployment Toolbox v$($Script:Config.Version)"
    Write-Host "========================================"
    Write-Host ""

    Initialize-Directories

    if (-not (Test-Prerequisites)) {
        Write-Host "Prerequisites check failed. Please fix the issues and try again." -ForegroundColor Red
        Read-Host "Press Enter to exit"
        return
    }

    Show-MainUI
}

# Start the application
Start-DeploymentToolbox
