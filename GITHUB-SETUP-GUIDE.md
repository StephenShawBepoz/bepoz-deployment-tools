# GitHub Repository Setup Guide

This guide walks you through setting up your GitHub repository for the Bepoz Deployment Toolbox.

## Step 1: Create GitHub Repository

1. Go to [GitHub](https://github.com) and sign in
2. Click the **+** icon in the top-right corner
3. Select **New repository**
4. Configure your repository:
   - **Repository name**: `bepoz-deployment-tools`
   - **Description**: `Bepoz POS deployment and configuration tools`
   - **Visibility**: **Private** (recommended for security)
   - **Initialize**: Leave unchecked (we'll add files manually)
5. Click **Create repository**

## Step 2: Create Personal Access Token (PAT)

1. Click your profile picture → **Settings**
2. Scroll down and click **Developer settings** (bottom of left menu)
3. Click **Personal access tokens** → **Tokens (classic)**
4. Click **Generate new token** → **Generate new token (classic)**
5. Configure the token:
   - **Note**: `Bepoz Deployment Toolbox`
   - **Expiration**: Choose appropriate duration (90 days, 1 year, or no expiration)
   - **Scopes**: Check `repo` (Full control of private repositories)
     - This automatically checks all sub-items under `repo`
6. Click **Generate token**
7. **IMPORTANT**: Copy the token immediately and save it securely
   - Format: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`
   - You won't be able to see it again!

## Step 3: Prepare Your Local Files

Create a folder on your computer with this structure:

```
bepoz-deployment-tools/
├── BepozDeploymentToolbox.ps1
├── ScreenConnect-Launcher.ps1
├── deployment-manifest.json
├── README.md
├── .gitignore
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

## Step 4: Update Configuration Files

### A. Update `ScreenConnect-Launcher.ps1`

Open the file and modify these lines:

```powershell
# Line 6-7
$GitHubRepo = "YOUR_USERNAME/bepoz-deployment-tools"  # Replace with your actual username
$GitHubToken = "ghp_your_token_here"                  # Paste your PAT here
```

**Example:**
```powershell
$GitHubRepo = "johndoe/bepoz-deployment-tools"
$GitHubToken = "ghp_1234567890abcdefghijklmnopqrstuvwxyz"
```

### B. Update `BepozDeploymentToolbox.ps1`

Open the file and modify these lines:

```powershell
# Lines 14-15
GitHubRepo = "YOUR_GITHUB_USERNAME/bepoz-deployment-tools"
GitHubToken = "YOUR_GITHUB_PAT_HERE"
```

**Example:**
```powershell
GitHubRepo = "johndoe/bepoz-deployment-tools"
GitHubToken = "ghp_1234567890abcdefghijklmnopqrstuvwxyz"
```

## Step 5: Create .gitignore File

Create a `.gitignore` file in the root directory:

```gitignore
# Logs
*.log

# Temporary files
*.tmp
*.temp

# Large installers (optional - remove if you want to commit them)
*.exe
*.msi

# Sensitive data
config.local.*
secrets.*

# Windows
Thumbs.db
Desktop.ini

# IDE
.vscode/
.idea/
*.sublime-project
*.sublime-workspace
```

**Note**: If you want to store .exe/.msi installers in GitHub, remove those lines from .gitignore. However, GitHub has a 100MB file size limit.

## Step 6: Upload to GitHub

### Option A: Using Git Command Line

```bash
# Navigate to your folder
cd path/to/bepoz-deployment-tools

# Initialize git
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit: Bepoz Deployment Toolbox"

# Add remote (replace with your repo URL)
git remote add origin https://github.com/YOUR_USERNAME/bepoz-deployment-tools.git

# Push to GitHub
git branch -M main
git push -u origin main
```

When prompted for credentials:
- **Username**: Your GitHub username
- **Password**: Use your Personal Access Token (not your GitHub password!)

### Option B: Using GitHub Desktop

1. Download and install [GitHub Desktop](https://desktop.github.com/)
2. Sign in to GitHub Desktop
3. File → Add Local Repository
4. Choose your `bepoz-deployment-tools` folder
5. Click **Publish repository**
6. Uncheck "Keep this code private" if you want it public
7. Click **Publish repository**

### Option C: Using GitHub Web Interface

1. Go to your repository on GitHub
2. Click **Add file** → **Upload files**
3. Drag and drop all your files and folders
4. Add commit message: "Initial commit"
5. Click **Commit changes**

**Note**: This method doesn't work well for folders with many files. Use Git command line or GitHub Desktop for better results.

## Step 7: Verify Repository Structure

Go to your repository on GitHub and verify this structure:

```
https://github.com/YOUR_USERNAME/bepoz-deployment-tools

├── BepozDeploymentToolbox.ps1          ✓
├── ScreenConnect-Launcher.ps1          ✓
├── deployment-manifest.json            ✓
├── README.md                           ✓
├── sql-scripts/
│   └── (your SQL files)                ✓
├── installers/
│   └── (your installer files)          ✓
├── configs/
│   └── (your config scripts)           ✓
└── diagnostics/
    └── (your diagnostic scripts)       ✓
```

**CRITICAL**: Ensure `deployment-manifest.json` is in the **root** of the repository, not in a subfolder!

## Step 8: Test the Setup

### Test 1: Download Manifest Manually

Open PowerShell and run:

```powershell
$token = "YOUR_GITHUB_PAT"
$repo = "YOUR_USERNAME/bepoz-deployment-tools"
$url = "https://api.github.com/repos/$repo/contents/deployment-manifest.json"

$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github.v3.raw"
}

Invoke-RestMethod -Uri $url -Headers $headers
```

You should see the JSON content of your manifest file.

### Test 2: Run ScreenConnect Launcher Locally

```powershell
# Download and run (replace URL with your actual repo URL)
irm https://raw.githubusercontent.com/YOUR_USERNAME/bepoz-deployment-tools/main/ScreenConnect-Launcher.ps1 | iex
```

If everything is configured correctly, the toolbox UI should launch.

## Step 9: Create ScreenConnect Command

Now create your one-line ScreenConnect command:

```powershell
powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/YOUR_USERNAME/bepoz-deployment-tools/main/ScreenConnect-Launcher.ps1 | iex"
```

**Replace `YOUR_USERNAME`** with your actual GitHub username.

Save this command somewhere handy for quick access in ScreenConnect.

## Troubleshooting

### "404 Not Found" Error

- Verify repository name is correct
- Check that branch is `main` (not `master`)
- Ensure files are in the correct locations
- For private repos, verify your PAT is correct

### "401 Unauthorized" Error

- Your Personal Access Token is invalid or expired
- Generate a new token and update both scripts
- Ensure the token has `repo` scope

### Files Not Appearing

- Check `.gitignore` - you might be excluding necessary files
- Use `git status` to see which files are tracked
- Ensure you committed and pushed all changes

### Large File Errors

- GitHub has a 100MB file size limit
- For large installers, consider:
  - Hosting them elsewhere (AWS S3, Azure Blob, etc.)
  - Using Git LFS (Large File Storage)
  - Downloading from vendor directly in your scripts

## Security Best Practices

1. **Never commit PAT to public repositories**
   - Always use private repositories
   - Or use GitHub Secrets for CI/CD

2. **Rotate tokens regularly**
   - Set expiration dates on PATs
   - Update scripts when rotating

3. **Use least privilege**
   - Only grant `repo` scope, nothing more
   - Create separate tokens for different purposes

4. **Audit access**
   - Regularly review who has access to your repository
   - Monitor token usage in GitHub settings

5. **Secure ScreenConnect**
   - Only use on trusted client machines
   - Clear command history after use
   - Use ScreenConnect security features

## Updating Your Deployment Tools

### Update Deployment Files

1. Edit files locally or directly on GitHub
2. Commit and push changes
3. Users will automatically get the latest version when they:
   - Run the ScreenConnect launcher again
   - Click "Refresh Catalog" in the UI

### Update the Manifest

1. Edit `deployment-manifest.json`
2. Add/remove/modify deployment entries
3. Commit and push
4. Users click "Refresh Catalog" to see changes (no restart needed)

### Version Control Best Practices

```bash
# Create a new branch for changes
git checkout -b feature/new-deployment

# Make your changes
# ... edit files ...

# Commit changes
git add .
git commit -m "Added new deployment: X"

# Push branch
git push origin feature/new-deployment

# Create Pull Request on GitHub
# Merge after review
```

## Need Help?

Common issues and solutions:

| Issue | Solution |
|-------|----------|
| Can't generate PAT | Need admin rights on GitHub account |
| Git commands not working | Install [Git for Windows](https://git-scm.com/download/win) |
| Large files won't upload | Use Git LFS or host externally |
| 403 Forbidden | PAT expired or has wrong scope |
| Changes not appearing | Make sure you pushed (not just committed) |

## Next Steps

Once your repository is set up:

1. ✅ Test locally first
2. ✅ Test via ScreenConnect on a dev machine
3. ✅ Document your custom deployments
4. ✅ Train your team on using the toolbox
5. ✅ Create a backup of your repository
6. ✅ Set up branch protection rules (optional)

---

**Your repository is now ready for deployment!** 🎉

Save your ScreenConnect one-liner and start deploying!
