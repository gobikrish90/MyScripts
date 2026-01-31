# ============================================
# ProPhoenix Minimal Downtime Deployment Script
# Combines Step 1, Step 2, Step 3, and Step 4
# ============================================

Clear-Host
Write-Host "`n============================================================"
Write-Host "🚀 Starting Deployment Script with Minimal Downtime..."
Write-Host "============================================================`n"

# =============================================================
# LOGGING & TRANSCRIPT SETUP (C:\PnxTemp ONLY)
# =============================================================

$ScriptStartTime = Get-Date

$PrimaryPnxTemp = "C:\PnxTemp"
$PnxTempFolders = @()
$TranscriptFile = $null

if (-not (Test-Path $PrimaryPnxTemp)) {
    New-Item -ItemType Directory -Path $PrimaryPnxTemp -Force | Out-Null
}

$PnxTempFolders += $PrimaryPnxTemp

# Build path safely (Error fixed: Removed invalid parameter)
$TranscriptFile = Join-Path $PrimaryPnxTemp ("Deployment_Transcript_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

Write-Host "📂 Transcript will be saved to:" 
Write-Host "   $TranscriptFile" -ForegroundColor Cyan

try {
    Start-Transcript -Path $TranscriptFile -Force
    Write-Host "📝 Transcript started successfully." 
}
catch {
    Write-Host "⚠️ Transcript could not be started."
}

# -------------------------------
# STEP 1: Copy and Rename Folders
# -------------------------------
Write-Host "`n-------------------------------------------------------------"
Write-Host "📌 STEP 1: Copying and Renaming Folders with Minimal Downtime"
Write-Host "-------------------------------------------------------------`n"

# Source → Destination mapping
$appFoldersMap = @{
    "Police RMS" = "PoliceRMS"
    "Fire RMS"   = "FireRMS"
    "PhoenixIA"  = "Phoenix IA"
}

$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }

foreach ($sourceFolder in $appFoldersMap.Keys) {

    $destFolder = $appFoldersMap[$sourceFolder]

    foreach ($drive in $drives) {

        $sourcePath = Join-Path $drive.Root "Program Files\ProPhoenix\$sourceFolder"

        if (Test-Path $sourcePath) {

            Write-Host "`n🔎 Found $sourceFolder in: $sourcePath" -ForegroundColor Cyan
            $destPath = Join-Path (Split-Path $sourcePath -Parent) $destFolder

            if (Test-Path $destPath) {
                Write-Host "⚠️ Destination already exists: $destPath (Skipping)`n" -ForegroundColor Yellow
                continue
            }

            Write-Host "🚀 Copying $sourceFolder → $destPath`n" -ForegroundColor Yellow

            $job = Start-Job -ScriptBlock {
                param($src, $dst)
                cmd.exe /c "robocopy `"$src`" `"$dst`" /E /COPYALL /R:3 /W:5 /MT:16 /NFL /NDL /NJH /NJS /NP"
                exit $LASTEXITCODE
            } -ArgumentList $sourcePath, $destPath

            $start = Get-Date
            while (-not (Get-Job -Id $job.Id | Wait-Job -Timeout 1)) {
                $elapsed = (Get-Date) - $start
                $pct = ((($elapsed.TotalSeconds % 30) / 30) * 100)

                Write-Progress -Activity "Copying $sourceFolder" `
                               -Status "Elapsed: $([int]$elapsed.TotalSeconds) sec" `
                               -PercentComplete $pct
            }

            Receive-Job $job | Out-Null
            Remove-Job $job
            Write-Progress -Activity "Copying $sourceFolder" -Completed

            Write-Host "`n✅ Copy of $sourceFolder completed" -ForegroundColor Green

            # ---------------------------
            # Verification (Post Copy)
            # ---------------------------
            Write-Host "🔎 Verifying copy for $sourceFolder..." -ForegroundColor Yellow
            $verify = cmd.exe /c "robocopy `"$sourcePath`" `"$destPath`" /MIR /L /NJH /NJS /NDL /NP /NS /NC"

            if ($verify) {
                Write-Host "⚠️ Verification found differences:" -ForegroundColor Red
                $verify | ForEach-Object { Write-Host "   $_" -ForegroundColor DarkYellow }
            } else {
                Write-Host "✅ Verification passed: Source and Destination match" -ForegroundColor Green
            }

            # Special case: Create PnxLog for Police RMS
            if ($sourceFolder -eq "Police RMS") {
                $pnxLog = Join-Path $destPath "PnxLog"
                if (-not (Test-Path $pnxLog)) {
                    New-Item -ItemType Directory -Path $pnxLog | Out-Null
                    Write-Host "📂 Created folder: $pnxLog" -ForegroundColor Cyan
                }
            }

            Write-Host "`n-------------------------------------------------------------`n"
        }
    }
}

Write-Host "`n✅ STEP 1 completed. Proceeding to STEP 2...`n" -ForegroundColor Green

# -------------------------------
# Step 2: Update AppReg_Main.xml
# -------------------------------
Write-Host "`n-------------------------------------------------------------"
Write-Host "📌 STEP 2: Updating AppReg_Main.xml paths"
Write-Host "-------------------------------------------------------------`n"

$possibleDrives = Get-PSDrive -PSProvider FileSystem | Where-Object {
    Test-Path "$($_.Root)\Program Files (x86)\ProPhoenix\Server Application Manager\AppReg_Main.xml"
}

if ($possibleDrives.Count -eq 0) {
    Write-Host "❌ Could not find AppReg_Main.xml on any drive.`n" -ForegroundColor Red
    return
}

$drive      = $possibleDrives[0].Root.TrimEnd('\')
$xmlPath    = "$drive\Program Files (x86)\ProPhoenix\Server Application Manager\AppReg_Main.xml"
$backupPath = "$xmlPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Host "📂 Found AppReg_Main.xml at: $xmlPath" -ForegroundColor Cyan
Write-Host "🗂️ Backup will be saved as: $backupPath" -ForegroundColor Yellow

Copy-Item -Path $xmlPath -Destination $backupPath -Force
Write-Host "`n✅ Backup created successfully`n" -ForegroundColor Green

# Store original lines for rollback
$originalContent = Get-Content $xmlPath

$folderReplacements = @{
    'Police RMS' = 'PoliceRMS'
    'Fire RMS'   = 'FireRMS'
    'PhoenixIA'  = 'Phoenix IA'
}

$content     = Get-Content $xmlPath
$updateCount = 0
$changeLog   = @()

for ($i = 0; $i -lt $content.Count; $i++) {
    $line = $content[$i]
    if ($line -match '<AppPath>(.*?)</AppPath>') {
        $originalPath = $matches[1]
        $newPath = $originalPath

        foreach ($oldFolder in $folderReplacements.Keys) {
            if ($newPath -match "[\\/]$oldFolder$") {
                $replacement = $folderReplacements[$oldFolder]
                $newPath = $newPath -replace [regex]::Escape($oldFolder), $replacement
            }
        }

        if ($originalPath -ne $newPath) {
            $content[$i] = "    <AppPath>$newPath</AppPath>"
            $updateCount++

            $changeLog += [PSCustomObject]@{
                LineNumber   = $i + 1
                OriginalPath = $originalPath
                UpdatedPath  = $newPath
            }

            Write-Host "`n🔄 Updated line $($i + 1):" -ForegroundColor Cyan
            Write-Host "   Old: <AppPath>$originalPath</AppPath>"
            Write-Host "   New: <AppPath>$newPath</AppPath>`n"
        }
    }
}

if ($updateCount -eq 0) {
    Write-Host "ℹ️ No AppPath entries required updating`n" -ForegroundColor Yellow
} else {
    Set-Content -Path $xmlPath -Value $content -Encoding UTF8
    Write-Host "✅ Updated $updateCount AppPath line(s)`n" -ForegroundColor Green
}

$global:RollbackChanges         = $changeLog
$global:RollbackOriginalContent = $originalContent
$global:RollbackXmlPath         = $xmlPath

Write-Host "`n✅ STEP 2 completed. Proceeding to STEP 3...`n" -ForegroundColor Green

# -------------------------------
# STEP 3: Specific Search in C:\PnxTemp & Execute
# -------------------------------
Write-Host "`n-------------------------------------------------------------"
Write-Host "📌 STEP 3: Running Hotfix from C:\PnxTemp\Phoenix Installation Master"
Write-Host "-------------------------------------------------------------`n"

# 1. Define the specific target path
$targetFolder = "C:\PnxTemp\Phoenix Installation Master"
$batchPattern = "Hotfix*.bat" # Matches "Hotfix.bat" or "Hotfix Script.bat"

$finalBatchPath = $null

Write-Host "🔎 Checking directory: $targetFolder" -ForegroundColor Cyan

if (Test-Path $targetFolder) {
    # 2. Search for the batch file inside this folder
    $foundBatch = Get-ChildItem -Path $targetFolder -Filter $batchPattern -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($foundBatch) {
        $finalBatchPath = $foundBatch.FullName
        Write-Host "🎯 Found Batch File: $($foundBatch.Name)" -ForegroundColor Green
    } else {
        Write-Host "❌ Folder exists, but no file matching '$batchPattern' was found inside." -ForegroundColor Red
    }
}
else {
    Write-Host "❌ The specific folder '$targetFolder' does not exist." -ForegroundColor Red
}

# 3. Execute Batch Script if found
if ($finalBatchPath) {
    Write-Host "`n▶️ Running batch script..." -ForegroundColor Yellow
    Start-Process -FilePath $finalBatchPath -Verb RunAs -Wait
    Write-Host "✅ Batch script completed`n" -ForegroundColor Green
} else {
    Write-Host "⚠️ Skipping batch execution (File not found).`n" -ForegroundColor Yellow
}

# -------------------------------
# Original Logic: IIS Stop and Folder Swap
# -------------------------------
$proceed = Read-Host "❓ Proceed with IIS Stop and Folder Swap? (Y/N)"

if ($proceed -notin @("Y", "y")) {
    Write-Host "`n⚠️ User chose to skip IIS Stop and Folder Swap." -ForegroundColor Yellow
    Write-Host "➡️ STEP 3 swap operations skipped."
    Write-Host "➡️ Script will continue to STEP 4.`n"
}
else {
    try {
        Write-Host "`n🛑 Attempting to stop IIS...`n" -ForegroundColor Yellow

        iisreset /stop | Out-Null
        Start-Sleep -Seconds 3

        $apps = @("Police RMS", "Fire RMS", "PhoenixIA")

        foreach ($app in $apps) {

            $basePath = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
                $path = "$($_.Root)\Program Files\ProPhoenix\$app"
                if (Test-Path $path) { return $path }
            }

            if (!$basePath) {
                Write-Host "⚠️ Folder not found: $app (Skipping)`n" -ForegroundColor Yellow
                continue
            }

            switch ($app) {
                "Police RMS" { $newName = "PoliceRMS" }
                "Fire RMS"   { $newName = "FireRMS" }
                "PhoenixIA"  { $newName = "Phoenix IA" }
            }

            $newPath = Join-Path ([System.IO.Path]::GetDirectoryName($basePath)) $newName

            if (-not (Test-Path $newPath)) {
                Write-Host "⚠️ New folder not found: $newPath (Skipping)`n" -ForegroundColor Yellow
                continue
            }

            # Date-based backup folder (DDMMYYYY)
            $execDate   = Get-Date -Format "ddMMyyyy"
            $backupPath = "${basePath}_$execDate"

            $index = 1
            while (Test-Path $backupPath) {
                $backupPath = "${basePath}_${execDate}_$index"
                $index++
            }

            Rename-Item -Path $basePath -NewName (Split-Path -Leaf $backupPath)
            Rename-Item -Path $newPath  -NewName (Split-Path -Leaf $basePath)

            Write-Host "🔁 Swapped:" -ForegroundColor Cyan
            Write-Host "   New Live : $app"
            Write-Host "   Backup   : $backupPath`n"
        }

        Write-Host "`n▶️ Starting IIS...`n" -ForegroundColor Yellow
        iisreset /start | Out-Null
        Write-Host "✅ IIS restarted successfully`n" -ForegroundColor Green
    }
    catch {
        Write-Host "`n❌ STEP 3 encountered an issue:" -ForegroundColor Red
        Write-Host "   $($_.Exception.Message)" -ForegroundColor DarkYellow
        Write-Host "➡️ IIS swap may be partial or skipped."
        Write-Host "➡️ Script will continue to STEP 4.`n"
    }
}

# -------------------------------
# STEP 4: Enforce Default AppReg_Main.xml Paths (Targeted by AppName)
# -------------------------------
Write-Host "`n-------------------------------------------------------------"
Write-Host "📌 STEP 4: Enforcing Default AppPath Locations (By AppName)"
Write-Host "-------------------------------------------------------------`n"

# Auto-detect AppReg_Main.xml
$xmlDrive = Get-PSDrive -PSProvider FileSystem | Where-Object {
    Test-Path "$($_.Root)\Program Files (x86)\ProPhoenix\Server Application Manager\AppReg_Main.xml"
} | Select-Object -First 1

if (-not $xmlDrive) {
    Write-Host "❌ AppReg_Main.xml not found on any drive. STEP 4 aborted." -ForegroundColor Red
    return
}

$xmlPath = "$($xmlDrive.Root)Program Files (x86)\ProPhoenix\Server Application Manager\AppReg_Main.xml"
Write-Host "📂 AppReg_Main.xml detected at:" -ForegroundColor Cyan
Write-Host "   $xmlPath`n"

$appRegContent = Get-Content -Path $xmlPath
$updatedCount  = 0

# Target AppName → Folder mapping
$appTargets = @{
    "Phoenix Police RMS" = "Police RMS"
    "Phoenix Fire RMS"   = "Fire RMS"
    "PhoenixIA"          = "PhoenixIA"
}

# Detect LIVE default paths (source of truth)
$defaultAppPaths = @{}

foreach ($target in $appTargets.GetEnumerator()) {
    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        $livePath = Join-Path $drive.Root "Program Files\ProPhoenix\$($target.Value)"
        if (Test-Path $livePath) {
            $defaultAppPaths[$target.Key] = $livePath
            break
        }
    }
}

Write-Host "🔎 Detected Default LIVE Paths:" -ForegroundColor Cyan
foreach ($item in $defaultAppPaths.GetEnumerator()) {
    Write-Host "   ✔ $($item.Key) → $($item.Value)"
}
Write-Host ""

# Walk through file line-by-line (AppName → AppPath aware)
for ($i = 0; $i -lt $appRegContent.Count; $i++) {

    # Match AppName line
    if ($appRegContent[$i] -match "<AppName>(.+?)</AppName>") {

        $appName = $matches[1]

        if ($appTargets.ContainsKey($appName)) {

            # AppPath should be on next non-empty line
            for ($j = $i + 1; $j -lt $appRegContent.Count; $j++) {

                if ($appRegContent[$j] -match "<AppPath>(.+?)</AppPath>") {

                    $currentPath  = $matches[1]
                    $expectedPath = $defaultAppPaths[$appName]

                    if (-not $expectedPath) {
                        Write-Host "⚠️ Live path not found for $appName — skipping" -ForegroundColor Yellow
                        break
                    }

                    if ($currentPath -eq $expectedPath) {
                        Write-Host "ℹ️ $appName already set to default path:" -ForegroundColor Green
                        Write-Host "   $currentPath`n"
                    }
                    else {
                        Write-Host "🔄 Updating $appName AppPath:" -ForegroundColor Yellow
                        Write-Host "   Current : $currentPath"
                        Write-Host "   Default : $expectedPath"

                        $appRegContent[$j] = "    <AppPath>$expectedPath</AppPath>"
                        $updatedCount++

                        Write-Host "   ✅ Updated successfully`n" -ForegroundColor Cyan
                    }

                    break
                }

                # Stop scanning if next AppName starts
                if ($appRegContent[$j] -match "<AppName>") {
                    break
                }
            }
        }
    }
}

# Save only if changes were made
if ($updatedCount -gt 0) {
    Set-Content -Path $xmlPath -Value $appRegContent -Encoding UTF8
    Write-Host "✅ STEP 4 completed: $updatedCount AppPath entrie(s) enforced.`n" -ForegroundColor Green
}
else {
    Write-Host "✅ STEP 4 completed: All targeted AppPath entries already use default locations.`n" -ForegroundColor Green
}
 
Write-Host "`n============================================================"
Write-Host "🎯 Deployment Script Completed Successfully."
Write-Host "============================================================`n" -ForegroundColor Green

# =============================================================
# STOP TRANSCRIPT & COPY TO ALL PnxTemp FOLDERS
# =============================================================

try {
    Stop-Transcript | Out-Null
}
catch {
    # Ignore stop errors
}

# Copy transcript to all other PnxTemp folders
if ($PrimaryPnxTemp -and (Test-Path $TranscriptFile)) {
    foreach ($pnxTemp in $PnxTempFolders | Where-Object { $_ -ne $PrimaryPnxTemp }) {
        try {
            Copy-Item -Path $TranscriptFile -Destination $pnxTemp -Force
        }
        catch {
            # Ignore copy failures
        }
    }
}

$ScriptEndTime = Get-Date
$duration = New-TimeSpan -Start $ScriptStartTime -End $ScriptEndTime

Write-Host "============================================================"
Write-Host "📝 Deployment Transcript Completed"
Write-Host "⏱ Total Execution Time: $($duration.ToString())"
Write-Host "============================================================"