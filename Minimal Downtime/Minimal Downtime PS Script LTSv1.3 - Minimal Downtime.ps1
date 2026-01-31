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

# Build path safely
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
Write-Host "📌 STEP 2: Updating AppReg_Main.xml paths (Redirect to TEMP)"
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

$content     = Get-Content $xmlPath
$updateCount = 0

# --- STEP 2 LOGIC: Point LIVE -> TEMP (PhoenixIA -> Phoenix IA) ---
for ($i = 0; $i -lt $content.Count; $i++) {
    $line = $content[$i]
    
    # We only care about lines containing <AppPath>
    if ($line -match "<AppPath>(.*)</AppPath>") {
        $originalLine = $line
        $modified = $false
        
        # 1. PhoenixIA -> Phoenix IA (Target logic: ProPhoenix\PhoenixIA -> ProPhoenix\Phoenix IA)
        if ($line -match "\\ProPhoenix\\PhoenixIA") {
            # Use strict replace to avoid modifying other paths
            $content[$i] = $line -replace "\\PhoenixIA", "\Phoenix IA"
            $modified = $true
        }
        # 2. Police RMS -> PoliceRMS
        elseif ($line -match "\\ProPhoenix\\Police RMS") {
            $content[$i] = $line -replace "\\Police RMS", "\PoliceRMS"
            $modified = $true
        }
        # 3. Fire RMS -> FireRMS
        elseif ($line -match "\\ProPhoenix\\Fire RMS") {
            $content[$i] = $line -replace "\\Fire RMS", "\FireRMS"
            $modified = $true
        }

        if ($modified) {
            $updateCount++
            Write-Host "`n🔄 Updated line $($i + 1):" -ForegroundColor Cyan
            Write-Host "   Old: $originalLine"
            Write-Host "   New: $($content[$i])`n"
        }
    }
}

if ($updateCount -eq 0) {
    Write-Host "ℹ️ No AppPath entries required updating`n" -ForegroundColor Yellow
} else {
    Set-Content -Path $xmlPath -Value $content -Encoding UTF8
    Write-Host "✅ Updated $updateCount AppPath line(s)`n" -ForegroundColor Green
}

Write-Host "`n✅ STEP 2 completed. Proceeding to STEP 3...`n" -ForegroundColor Green

# -------------------------------
# STEP 3: Execute Batch and Swap
# -------------------------------
Write-Host "`n-------------------------------------------------------------"
Write-Host "📌 STEP 3: Running Batch Script and Swapping Folders"
Write-Host "-------------------------------------------------------------`n"

# 1. Specific Search in C:\PnxTemp\Phoenix Installation Master
$targetFolder = "C:\PnxTemp\Phoenix Installation Master"
$batchPattern = "Hotfix*.bat"
$finalBatchPath = $null

Write-Host "🔎 Checking directory: $targetFolder" -ForegroundColor Cyan

if (Test-Path $targetFolder) {
    $foundBatch = Get-ChildItem -Path $targetFolder -Filter $batchPattern -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($foundBatch) {
        $finalBatchPath = $foundBatch.FullName
        Write-Host "🎯 Found Batch File: $($foundBatch.Name)" -ForegroundColor Green
    } else {
        Write-Host "❌ Batch file not found in $targetFolder" -ForegroundColor Red
    }
} else {
    Write-Host "❌ Folder not found: $targetFolder" -ForegroundColor Red
}

# 2. Execute Batch
if ($finalBatchPath) {
    Write-Host "`n▶️ Running batch script..." -ForegroundColor Yellow
    Start-Process -FilePath $finalBatchPath -Verb RunAs -Wait
    Write-Host "✅ Batch script completed`n" -ForegroundColor Green
} else {
    Write-Host "⚠️ Skipping batch execution (File not found).`n" -ForegroundColor Yellow
}

# 3. Swap Folders
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

            # Date-based backup folder
            $execDate   = Get-Date -Format "ddMMyyyy"
            $backupPath = "${basePath}_$execDate"

            $index = 1
            while (Test-Path $backupPath) {
                $backupPath = "${basePath}_${execDate}_$index"
                $index++
            }

            # --- ROBUST RENAME WITH RETRY ---
            $swapped = $false
            $maxRetries = 5
            
            for ($i = 0; $i -lt $maxRetries; $i++) {
                try {
                    # 1. Rename Current LIVE -> BACKUP
                    Rename-Item -Path $basePath -NewName (Split-Path -Leaf $backupPath) -ErrorAction Stop
                    
                    # 2. Rename NEW -> LIVE
                    Rename-Item -Path $newPath  -NewName (Split-Path -Leaf $basePath) -ErrorAction Stop
                    
                    $swapped = $true
                    break # Success
                }
                catch {
                    Write-Host "   ⏳ Lock detected on $app. Retrying ($($i+1)/$maxRetries)..." -ForegroundColor DarkYellow
                    Start-Sleep -Seconds 2
                }
            }

            if ($swapped) {
                Write-Host "🔁 Swapped: $app" -ForegroundColor Cyan
                Write-Host "   Backup : $backupPath`n"
            } else {
                Write-Host "❌ FAILED to swap $app after $maxRetries attempts." -ForegroundColor Red
                Write-Host "   Folder may be locked by another process.`n" -ForegroundColor Red
            }
        }

        Write-Host "`n▶️ Starting IIS...`n" -ForegroundColor Yellow
        iisreset /start | Out-Null
        Write-Host "✅ IIS restarted successfully`n" -ForegroundColor Green
    }
    catch {
        Write-Host "`n❌ STEP 3 encountered an issue:" -ForegroundColor Red
        Write-Host "   $($_.Exception.Message)" -ForegroundColor DarkYellow
    }
}

# -------------------------------
# STEP 4: Enforce Default AppReg_Main.xml Paths (REVERT)
# -------------------------------
Write-Host "`n-------------------------------------------------------------"
Write-Host "📌 STEP 4: Reverting AppPath Locations to Defaults"
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

# --- STEP 4 LOGIC: Point TEMP -> LIVE (Phoenix IA -> PhoenixIA) ---
for ($i = 0; $i -lt $appRegContent.Count; $i++) {
    $line = $appRegContent[$i]
    
    if ($line -match "<AppPath>(.*)</AppPath>") {
        $originalLine = $line
        $modified = $false
        
        # 1. Phoenix IA -> PhoenixIA (Revert)
        # We explicitly search for 'ProPhoenix\Phoenix IA' to match your requested logic
        if ($line -match "\\ProPhoenix\\Phoenix IA") {
            $appRegContent[$i] = $line -replace "\\Phoenix IA", "\PhoenixIA"
            $modified = $true
        }
        # 2. PoliceRMS -> Police RMS (Revert)
        elseif ($line -match "\\ProPhoenix\\PoliceRMS") {
            $appRegContent[$i] = $line -replace "\\PoliceRMS", "\Police RMS"
            $modified = $true
        }
        # 3. FireRMS -> Fire RMS (Revert)
        elseif ($line -match "\\ProPhoenix\\FireRMS") {
            $appRegContent[$i] = $line -replace "\\FireRMS", "\Fire RMS"
            $modified = $true
        }

        if ($modified) {
            $updatedCount++
            Write-Host "`n🔄 Reverted line $($i + 1):" -ForegroundColor Cyan
            Write-Host "   Old: $originalLine"
            Write-Host "   New: $($appRegContent[$i])`n"
        }
    }
}

# Save only if changes were made
if ($updatedCount -gt 0) {
    Set-Content -Path $xmlPath -Value $appRegContent -Encoding UTF8
    Write-Host "✅ STEP 4 completed: $updatedCount AppPath entrie(s) restored to default.`n" -ForegroundColor Green
}
else {
    Write-Host "✅ STEP 4 completed: No paths needed restoring (Paths already correct).`n" -ForegroundColor Green
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