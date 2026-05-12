# 1. Prioritize local drive detection to locate the repository
$drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
$repoSubPath = "OneDrive\OneDrive - ProPhoenix Corporation\Documents\GitHub"
$basePath = $null
$repoPath = $null

Write-Host "--> Detecting repository across local drives..." -ForegroundColor Cyan
foreach ($drive in $drives) {
    $checkPath = Join-Path $drive "$repoSubPath\MyScripts"
    if (Test-Path $checkPath) {
        $basePath = $checkPath
        $repoPath = Join-Path $drive $repoSubPath
        Write-Host "Repository located on drive: $drive" -ForegroundColor Green
        break
    }
}

if (-not $basePath) {
    Write-Host "Error: Could not locate the GitHub repository on any drive." -ForegroundColor Red
    exit
}

$zipFileName = "Phoenix Installation Master.zip"
$zipPath = Join-Path $repoPath $zipFileName
$tempStaging = Join-Path $env:TEMP "PhoenixStagingArea"

# Define explicitly excluded folders to omit from the process
$excludedFolders = @(
    "AutoPrecompiler",
    "Installation Master",
    "License Comparision Tool",
    "Manual Fix Update",
    "New Server Installation Scripts_old",
    "New Server Installation_Refined",
    "Parameter Backup",
    "Pre-requisite Script",
    "Useful Scripts"
)

# 2. Prepare a clean temporary staging area
if (Test-Path $tempStaging) { Remove-Item -Path $tempStaging -Recurse -Force }
New-Item -ItemType Directory -Path $tempStaging | Out-Null
Write-Host "--> Created temporary staging area..." -ForegroundColor Cyan

# 3. Get subdirectories (Strictly skipping Hub, Gateway, AND specifically excluded folders)
$folders = Get-ChildItem -Path $basePath -Directory | Where-Object { 
    $_.Name -notmatch 'Hub' -and 
    $_.Name -notmatch 'Gateway' -and 
    $excludedFolders -notcontains $_.Name 
}

foreach ($folder in $folders) {
    $targetStagingFolder = Join-Path $tempStaging $folder.Name
    New-Item -ItemType Directory -Path $targetStagingFolder | Out-Null

    if ($folder.Name -eq "Dashboard Scripts") {
        Write-Host "Processing [$($folder.Name)] -> Copying folder contents." -ForegroundColor Yellow
        
        # Copy files, strictly skipping Hub/Gateway
        $files = Get-ChildItem -Path $folder.FullName -File -Recurse | Where-Object { $_.FullName -notmatch 'Hub' -and $_.FullName -notmatch 'Gateway' }
        foreach ($file in $files) {
            $destPath = $file.FullName.Replace($folder.FullName, $targetStagingFolder)
            $destDir = Split-Path $destPath
            if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
            Copy-Item -Path $file.FullName -Destination $destPath -Force
        }
    }
    else {
        # DEFAULT: Copy only the latest file, strictly skipping Hub/Gateway
        $latestFile = Get-ChildItem -Path $folder.FullName -File | 
                      Where-Object { $_.Name -notmatch 'Hub' -and $_.Name -notmatch 'Gateway' } | 
                      Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if ($latestFile) {
            Write-Host "Processing [$($folder.Name)] -> Copying latest version: $($latestFile.Name)" -ForegroundColor Green
            Copy-Item -Path $latestFile.FullName -Destination $targetStagingFolder -Force
        }
        else {
            Write-Host "Processing [$($folder.Name)] -> Folder empty or files excluded, skipping." -ForegroundColor DarkGray
        }
    }
}

# 4. Create the ZIP Archive
Write-Host "`n--> Compressing files into $zipFileName..." -ForegroundColor Cyan
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$tempStaging\*" -DestinationPath $zipPath -Force

# 5. Cleanup temporary files
Remove-Item -Path $tempStaging -Recurse -Force

Write-Host "`n=================================================" -ForegroundColor Green
Write-Host " SUCCESS: Archive created successfully!" -ForegroundColor Green
Write-Host " Location: $zipPath" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Green

# 6. Git Confirmation & Commit Logic
Write-Host "`n--> Git Version Control" -ForegroundColor Cyan
Set-Location $repoPath
    
$commitChoice = Read-Host "Do you want to commit the new ZIP file and changes to Git? (Y/N)"
if ($commitChoice -match "^[Yy]$") {
    $commitMessage = Read-Host "Enter your commit message (Leave blank for default)"
    if ([string]::IsNullOrWhiteSpace($commitMessage)) {
        $commitMessage = "Update scripts and generate new $zipFileName"
    }
        
    Write-Host "Staging $zipFileName and other changes..." -ForegroundColor Yellow
    
    # Explicitly add the newly generated zip file, then add any other tracked changes
    git add $zipFileName
    git add .
        
    Write-Host "Committing changes..." -ForegroundColor Yellow
    git commit -m "$commitMessage"
        
    $pushChoice = Read-Host "Do you want to push these changes to the remote repository? (Y/N)"
    if ($pushChoice -match "^[Yy]$") {
        Write-Host "Pushing to remote..." -ForegroundColor Yellow
        git push
        Write-Host "Push complete!" -ForegroundColor Green
    }
} else {
    Write-Host "Git commit skipped." -ForegroundColor DarkGray
}