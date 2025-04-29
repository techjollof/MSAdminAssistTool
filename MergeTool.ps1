# Check if the current directory is a Git repository
if (-not (Test-Path ".git")) {
    Write-Error "❌ This is not a Git repository. Please navigate to your MSAdminAssistTool repo."
    exit 1
}

# Define your repositories: Name = URL
$repos = @{
    "M365UserLicensesManager" = "https://github.com/techjollof/M365UserLicensesManager.git"
    "PasswordExpiryNotifier" = "https://github.com/techjollof/PasswordExpiryNotifier.git"
    "StampMailboxFolderMRMTag" = "https://github.com/techjollof/StampMailboxFolderMRMTag.git"
    "TeamsBulkNumberAssignment" = "https://github.com/techjollof/TeamsBulkNumberAssignment.git"
    "UserLicenseInformationLastLogin" = "https://github.com/techjollof/UserLicenseInformationLastLogin.git"
    "SPOandOneDriveSiteAdminReportGenerator" = "https://github.com/techjollof/SPOandOneDriveSiteAdminReportGenerator.git"
    "EXOReportToolBox" = "https://github.com/techjollof/EXOReportToolBox.git"
    "o365SecuritPresetPolicyClonner" = "https://github.com/techjollof/o365SecuritPresetPolicyClonner.git"
}

# Create MSAdminAssistToolDev branch
Write-Host "🔄 Creating and switching to MSAdminAssistToolDev branch..." -ForegroundColor Cyan

# Check if the branch already exists
$branchExists = git show-ref --verify --quiet refs/heads/MSAdminAssistToolDev
if ($branchExists) {
    # If it exists, switch to it
    git checkout MSAdminAssistToolDev
} else {
    # If it doesn't exist, create it
    git checkout -b MSAdminAssistToolDev
}

Write-Host "🚀 Starting repository consolidation process with FULL history preservation..." -ForegroundColor Cyan
Write-Host "📂 Working in directory: $(Get-Location)" -ForegroundColor Cyan

# Add .gitattributes file to handle conflicts
$gitAttributesPath = Join-Path (Get-Location) ".gitattributes"
if (-not (Test-Path $gitAttributesPath)) {
    Set-Content -Path $gitAttributesPath -Value "* merge=ours"
    git add .gitattributes
    git commit -m "Add .gitattributes for conflict resolution"
}

foreach ($repoName in $repos.Keys) {
    $repoUrl = $repos[$repoName]
    Write-Host "`n===================================" -ForegroundColor Yellow
    Write-Host "🔄 Processing $repoName from $repoUrl" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Yellow
    
    # Add remote for the repository (remove if it already exists)
    Write-Host "📥 Adding remote repository..." -ForegroundColor Green
    git remote remove "remote-$repoName" 2>$null
    git remote add "remote-$repoName" $repoUrl
    
    # Fetch from remote
    Write-Host "📥 Fetching repository data..." -ForegroundColor Green
    git fetch "remote-$repoName"
    
    # Detect the default branch
    Write-Host "🔍 Detecting default branch..." -ForegroundColor Green
    $defaultBranch = git remote show "remote-$repoName" | Select-String 'HEAD branch' | ForEach-Object {
        ($_ -replace '.*: ', '').Trim()
    }

    if (-not $defaultBranch) {
        Write-Error "❌ Could not detect default branch for $repoName"
        git remote remove "remote-$repoName"
        continue
    }

    Write-Host "📋 Default branch detected: $defaultBranch" -ForegroundColor Green
    
    # Configure git to automatically resolve conflicts
    git config merge.ours.driver true
    
    # Add subtree with FULL historical commits preserved (NO squash)
    Write-Host "🌲 Adding git subtree for $repoName with FULL history..." -ForegroundColor Green
    
    try {
        # Add subtree WITHOUT squash to preserve full history
        git subtree add --prefix="$repoName" "remote-$repoName" "$defaultBranch"
        
        if ($LASTEXITCODE -ne 0) {
            throw "Subtree add failed with exit code $LASTEXITCODE"
        }
    }
    catch {
        Write-Host "⚠️ Standard subtree approach failed. Using alternative method..." -ForegroundColor Yellow
        
        # Create a temporary branch from the remote repository
        $tempBranchName = "temp-import-$repoName"
        git checkout -b $tempBranchName "remote-$repoName/$defaultBranch"
        
        # Create the target directory
        New-Item -ItemType Directory -Path $repoName -Force | Out-Null
        
        # Move all files to the subdirectory (preserving history)
        $files = Get-ChildItem -Path . -Force | Where-Object { $_.Name -ne ".git" -and $_.Name -ne $repoName }
        foreach ($file in $files) {
            # Create parent directories if needed
            if (Test-Path $file.FullName -PathType Container) {
                git mv $file.Name "$repoName/" 2>$null
                if ($LASTEXITCODE -ne 0) {
                    # If git mv fails, use PowerShell move
                    Move-Item -Path $file.FullName -Destination "$repoName/" -Force
                }
            } else {
                git mv $file.Name "$repoName/" 2>$null
                if ($LASTEXITCODE -ne 0) {
                    # If git mv fails, use PowerShell move
                    Move-Item -Path $file.FullName -Destination "$repoName/" -Force
                }
            }
        }
        
        # Commit this reorganization
        git add .
        git commit -m "Reorganize $repoName files into subdirectory (preserving history)"
        
        # Switch back to our dev branch and merge
        git checkout MSAdminAssistToolDev
        git merge --allow-unrelated-histories -X theirs $tempBranchName -m "Import $repoName with FULL history (alternative method)"
        
        # Clean up the temporary branch
        git branch -D $tempBranchName
    }
    
    # Reset conflict resolution to default
    git config --unset merge.ours.driver
    
    # Clean up the remote
    git remote remove "remote-$repoName"
    
    Write-Host "✅ $repoName added successfully with FULL history preserved!" -ForegroundColor Yellow
}

Write-Host "`n🎉 All repositories consolidated into MSAdminAssistToolDev branch with FULL history preserved!" -ForegroundColor Magenta
Write-Host "ℹ️ You can review the changes and merge to main later using:" -ForegroundColor Cyan
Write-Host "   git checkout main" -ForegroundColor White
Write-Host "   git merge MSAdminAssistToolDev" -ForegroundColor White
Write-Host "   git push origin main" -ForegroundColor White