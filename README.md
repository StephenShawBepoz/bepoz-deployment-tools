# Bepoz Deployment Toolbox

A comprehensive deployment system for Bepoz POS on-premise installations, designed to work seamlessly with ScreenConnect for remote support operations.

## Overview

The Bepoz Deployment Toolbox provides a centralized, GitHub-backed deployment system that allows support technicians to:
- Download and execute deployment scripts remotely via ScreenConnect
- Manage SQL scripts, installers, and configuration files from a single interface
- Collect parameters interactively for client-specific deployments
- Maintain detailed logs of all deployment activities
- Update deployment tools centrally through GitHub version control

## Features

✅ **Windows Forms UI** - Clean, intuitive interface for browsing and executing deployments
✅ **GitHub Integration** - All deployment files hosted on GitHub with private repository support
✅ **Semi-Automated Execution** - Prompts for client-specific parameters before execution
✅ **Comprehensive Logging** - Detailed logs with timestamps, outputs, and system information
✅ **Multi-Format Support** - PowerShell, SQL, Batch, and Executable deployment types
✅ **ScreenConnect Ready** - One-line launcher for instant remote deployment
✅ **Category Organization** - Deployments organized by category (SQL Scripts, Installers, Configuration, Diagnostics)
✅ **Prerequisite Checking** - Validates system requirements before deployment
✅ **Error Handling** - Stop-on-error behavior with detailed error reporting

## Quick Start

### 1. Set Up GitHub Repository

Create a new private GitHub repository (e.g., `bepoz-deployment-tools`) with the following structure:

```
bepoz-deployment-tools/
├── BepozDeploymentToolbox.ps1          # Main application (copy from outputs)
├── ScreenConnect-Launcher.ps1          # Bootstrap script (copy from outputs)
├── deployment-manifest.json            # Deployment catalog (copy from outputs)
├── sql-scripts/
│   ├── init-database.sql
│   ├── update-schema.sql
│   ├── import-sample-data.sql
│   └── reset-admin-password.sql
├── installers/
│   ├── BepozPOS-Setup.exe
│   └── Install-SQLExpress.ps1
├── configs/
│   ├── Set-ClientConfiguration.ps1
│   ├── Set-FirewallRules.ps1
│   ├── Set-BackupSchedule.ps1
│   └── Update-License.ps1
└── diagnostics/
    ├── Test-SystemHealth.ps1
    └── Export-DiagnosticLogs.ps1
```

### 2. Create GitHub Personal Access Token

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name: "Bepoz Deployment Toolbox"
4. Select scopes: `repo` (Full control of private repositories)
5. Click "Generate token"
6. **Copy the token immediately** (you won't see it again)

### 3. Configure the Scripts

#### Update `ScreenConnect-Launcher.ps1`:
```powershell
$GitHubRepo = "your-username/bepoz-deployment-tools"  # Your repo
$GitHubToken = "ghp_your_token_here"                  # Your PAT
```

#### Update `BepozDeploymentToolbox.ps1`:
```powershell
GitHubRepo = "your-username/bepoz-deployment-tools"   # Your repo
GitHubToken = "ghp_your_token_here"                   # Your PAT
```

### 4. Upload Files to GitHub

1. Commit all files to your repository
2. Ensure `deployment-manifest.json` is in the root
3. Create the folder structure and add your actual deployment files
4. Push everything to GitHub

### 5. Deploy via ScreenConnect

#### Option A: One-Line Launcher (Recommended)
Copy this into ScreenConnect PowerShell window:
```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/YOUR_USERNAME/bepoz-deployment-tools/main/ScreenConnect-Launcher.ps1 | iex"
```

#### Option B: Manual Upload
1. Use ScreenConnect "Send File" to upload `ScreenConnect-Launcher.ps1`
2. Run: `powershell -ExecutionPolicy Bypass -File "C:\Temp\ScreenConnect-Launcher.ps1"`

## Usage

### Main Interface

1. **Deployment Catalog** (Left Panel)
   - Browse available deployments by category
   - Filter by: All, SQL Scripts, Installers, Configuration, Diagnostics
   - Select a deployment to view details

2. **Description Panel** (Top Right)
   - Shows detailed description of selected deployment
   - Lists required parameters

3. **Log Panel** (Bottom Right)
   - Real-time deployment log output
   - Color-coded messages (INFO, SUCCESS, WARNING, ERROR)
   - Scrolls automatically

4. **Actions**
   - **Deploy Selected**: Executes the selected deployment
   - **Open Log Folder**: Opens the log directory in Explorer
   - **Refresh Catalog**: Reloads the deployment manifest from GitHub

### Deployment Process

1. Select a deployment from the list
2. Click "Deploy Selected"
3. If parameters are required, a dialog will appear:
   - Fill in client-specific values (company name, license key, server name, etc.)
   - Click OK to proceed or Cancel to abort
4. The deployment downloads files from GitHub
5. Files are executed with provided parameters
6. Progress and results appear in the log panel
7. Logs are saved to `C:\Temp\BepozDeployment\Logs\`

## Deployment Manifest

The `deployment-manifest.json` file defines all available deployments:

```json
{
  "Name": "SQL Database Initialization",
  "Description": "Creates initial database schema and tables for Bepoz POS system",
  "Category": "SQL Scripts",
  "Type": "SQL",
  "Files": [
    "sql-scripts/init-database.sql"
  ],
  "Parameters": [
    {
      "Name": "ServerName",
      "Description": "SQL Server instance name",
      "DefaultValue": "localhost"
    },
    {
      "Name": "DatabaseName",
      "Description": "Database name to create/initialize",
      "DefaultValue": "BepozPOS"
    }
  ]
}
```

### Deployment Types

| Type | Description | Example Use Case |
|------|-------------|------------------|
| **SQL** | SQL scripts executed via sqlcmd | Database initialization, schema updates |
| **PowerShell** | PowerShell scripts with parameters | Configuration, system setup, diagnostics |
| **Executable** | EXE/MSI installers | Application installation |
| **Batch** | Batch scripts | Legacy scripts, simple automation |

### Parameter Substitution

For **Executable** type deployments, use `{{ParameterName}}` in the Arguments field:

```json
{
  "Type": "Executable",
  "Files": ["installers/setup.exe"],
  "Arguments": "/silent /installpath={{InstallPath}} /key={{LicenseKey}}",
  "Parameters": [
    {"Name": "InstallPath", "DefaultValue": "C:\\Program Files\\Bepoz"},
    {"Name": "LicenseKey", "DefaultValue": ""}
  ]
}
```

## Adding New Deployments

### Step 1: Add Files to GitHub
Upload your deployment files to the appropriate category folder in your GitHub repository.

### Step 2: Update Manifest
Edit `deployment-manifest.json` and add a new entry:

```json
{
  "Name": "Your Deployment Name",
  "Description": "Clear description of what this does",
  "Category": "SQL Scripts|Installers|Configuration|Diagnostics",
  "Type": "PowerShell|SQL|Executable|Batch",
  "Files": [
    "category-folder/your-file.ext"
  ],
  "Parameters": [
    {
      "Name": "ParameterName",
      "Description": "What this parameter is for",
      "DefaultValue": "default value"
    }
  ]
}
```

### Step 3: Commit and Push
```bash
git add .
git commit -m "Added new deployment: Your Deployment Name"
git push
```

### Step 4: Refresh in Toolbox
Click "Refresh Catalog" in the toolbox to load the new deployment.

## Example Deployment Scripts

### PowerShell Script Example
```powershell
# configs/Set-ClientConfiguration.ps1
param(
    [string]$CompanyName,
    [string]$LicenseKey,
    [string]$Region = "US"
)

Write-Host "Configuring client settings for $CompanyName"

# Your configuration logic here
$configPath = "C:\Program Files\Bepoz\config.xml"
# ... update configuration file ...

Write-Host "Configuration completed successfully"
exit 0
```

### SQL Script Example
```sql
-- sql-scripts/init-database.sql
-- Database initialization script
-- Parameters: ServerName, DatabaseName (provided by sqlcmd context)

IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'BepozPOS')
BEGIN
    CREATE DATABASE BepozPOS
END
GO

USE BepozPOS
GO

-- Create tables
CREATE TABLE Products (
    ProductID INT PRIMARY KEY IDENTITY(1,1),
    ProductName NVARCHAR(100) NOT NULL,
    Price DECIMAL(10,2) NOT NULL
)
GO

PRINT 'Database initialized successfully'
```

## Logging

Logs are automatically created at:
- **Location**: `C:\Temp\BepozDeployment\Logs\`
- **Format**: `deployment_YYYYMMDD.log`
- **Contents**: Timestamps, log levels, messages, command outputs, errors

Example log output:
```
[2026-01-20 14:30:15] [INFO] Loading deployment catalog from GitHub...
[2026-01-20 14:30:17] [SUCCESS] Loaded 12 deployment items
[2026-01-20 14:30:25] [INFO] ========================================
[2026-01-20 14:30:25] [INFO] Starting deployment: SQL Database Initialization
[2026-01-20 14:30:30] [SUCCESS] SQL script executed successfully
```

## Troubleshooting

### "Failed to download manifest"
- Check GitHub repository name and token
- Verify `deployment-manifest.json` is in the root of the repository
- Ensure token has `repo` scope
- Check internet connectivity

### "Prerequisites check failed"
- PowerShell version must be 5.0+
- .NET Framework 4.5+ required
- Check internet access to github.com

### "Cannot reach GitHub"
- Verify internet connectivity
- Check firewall rules
- Ensure github.com is accessible

### SQL Scripts Fail
- Verify sqlcmd is installed (SQL Server Command Line Utilities)
- Check ServerName and DatabaseName parameters
- Ensure SQL Server is running and accessible

### "Access Denied" Errors
- Some operations require administrator rights
- Right-click PowerShell and "Run as Administrator"
- Launch ScreenConnect with elevated privileges

## Security Considerations

⚠️ **IMPORTANT SECURITY NOTES**

1. **GitHub Token Protection**
   - Store PAT in a private repository only
   - Never commit tokens to public repositories
   - Use repository secrets for CI/CD
   - Rotate tokens regularly

2. **ScreenConnect Security**
   - Only use on trusted client machines
   - Verify client before running deployments
   - Use ScreenConnect session security features

3. **Execution Policy**
   - Scripts use `-ExecutionPolicy Bypass`
   - Only run trusted scripts from your GitHub repo
   - Review all scripts before adding to repository

4. **Log Privacy**
   - Logs may contain sensitive information
   - Review logs before sharing
   - Clear logs after deployment if needed

## System Requirements

- **Operating System**: Windows 7/Server 2008 R2 or higher
- **PowerShell**: Version 5.0 or higher
- **.NET Framework**: 4.5 or higher
- **Internet Access**: Required for GitHub communication
- **Optional**: SQL Server Command Line Utilities (for SQL deployments)

## File Structure Reference

### Working Directory: `C:\Temp\BepozDeployment\`
```
C:\Temp\BepozDeployment\
├── BepozDeploymentToolbox.ps1     # Main application (downloaded)
├── deployment-manifest.json       # Deployment catalog (downloaded)
├── Logs\
│   └── deployment_YYYYMMDD.log   # Daily log files
└── [temporary deployment files]   # Downloaded scripts/installers
```

## Updating the Toolbox

To update the toolbox after making changes:

1. Edit files in your GitHub repository
2. Commit and push changes
3. Simply re-run the ScreenConnect launcher
4. The latest version will be downloaded automatically

For deployment catalog updates:
- Just update `deployment-manifest.json` in GitHub
- Click "Refresh Catalog" in the UI (no restart needed)

## Best Practices

✅ **Version Control**: Tag releases in GitHub for rollback capability
✅ **Testing**: Test all deployments in a dev environment first
✅ **Documentation**: Add clear descriptions to all deployments
✅ **Parameters**: Provide sensible defaults for all parameters
✅ **Error Handling**: Include proper error handling in custom scripts
✅ **Logging**: Use Write-Host in scripts for log visibility
✅ **Exit Codes**: Return proper exit codes (0 = success, non-zero = failure)

## Support

For issues or questions:
1. Check the logs in `C:\Temp\BepozDeployment\Logs\`
2. Review the troubleshooting section above
3. Test the deployment manually outside ScreenConnect
4. Verify GitHub repository access and file structure

## License

Internal tool for Bepoz onboarding and support operations.

---

**Version**: 1.0
**Last Updated**: 2026-01-20
**Author**: Bepoz Support Team
