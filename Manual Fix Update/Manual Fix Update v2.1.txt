# ==============================================================================
# SCRIPT: Manual Fix Update 2.1
# PURPOSE: Auto-Match -> Safe Backup -> Detailed Logs -> Apply -> Instance BAT
# ==============================================================================

# --- CONFIGURATION ---
$minFreeSpaceGB = 5  
$specialPromptApps = @("CAD Client", "WDA", "Phoenix WDA V2", "PhoenixWDA", "WebDeviceAssistant")

$instanceList = @(
    "JobServer", "TraCSServer", "VideoServer", "FingerPrintServer", "EmailWatcher", 
    "CADServer", "CADNLBServer", "CAD2CADTellusServer", "E911Server", "ZetronServer", 
    "ExternalInterface", "GPSServer", "NCICServer", "NCICStateServer", "FTPServer", 
    "LocutionCADVoiceServer", "DeviceNotification", "StreamingNotification", "ReportService", 
    "FolderWatcher", "DocsServer", "PhoenixTonerServer", "PhoenixAlertApp", "PhoenixTExt2Dispatch", 
    "PHOENIXAIWATCHERSERVICE", "PHOENIXJOBSVRV2"
)

# --- HELPER FUNCTIONS ---
function Write-Header ($text) {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "   $text" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Log-Action "HEADER: $text"
}

function Log-Action ($message) {
    # Custom logging that avoids file locks
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp | $message"
    try {
        Add-Content -Path $global:logFile -Value $line -ErrorAction Stop
    } catch {
        Write-Warning "Could not write to log: $message"
    }
}

function Find-ServerAppManager {
    $paths = @(
        "C:\Program Files (x86)\ProPhoenix\Server Application Manager",
        "C:\Program Files\ProPhoenix\Server Application Manager",
        "D:\Program Files (x86)\ProPhoenix\Server Application Manager",
        "D:\Program Files\ProPhoenix\Server Application Manager"
    )
    foreach ($p in $paths) { if (Test-Path "$p\PnxAppMgr.exe") { return $p } }
    return $null
}

# --- STEP 1: INITIALIZE ---
Clear-Host
$fixedDrives = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
$targetDrive = $fixedDrives | Where-Object { $_.DeviceID -ne "C:" } | Select-Object -First 1
if ($targetDrive) { $rootDrive = $targetDrive.DeviceID } else { $rootDrive = "C:" }

$dateFolder = Get-Date -Format "MMddyyyy"
$workPath = "$rootDrive\pnxtemp\manualdll\$dateFolder"
$global:logFile = "$workPath\Update_Log_$(Get-Date -Format 'HHmmss').txt"

if (-not (Test-Path -Path $workPath)) { New-Item -Path $workPath -ItemType Directory -Force | Out-Null }

Write-Header "STEP 1: INITIALIZING"
Write-Host "   Log File: $global:logFile" -ForegroundColor Gray
Log-Action "Started Update Process at $workPath"

# --- STEP 2: EXTRACT ---
$zipFile = Get-ChildItem -Path $workPath -Filter "*.zip" | Select-Object -First 1
if (-not $zipFile) {
    Write-Host "❌ No ZIP file found in $workPath" -ForegroundColor Red
    Log-Action "ERROR: No ZIP file found."
    return
}

Write-Header "STEP 2: EXTRACTING"
Write-Host "   Source: $($zipFile.Name)" -ForegroundColor Yellow
$extractPath = Join-Path $workPath "Extracted_$(Get-Date -Format 'HHmmss')"
Expand-Archive -Path $zipFile.FullName -DestinationPath $extractPath -Force
Write-Host "   ✅ Extraction Complete." -ForegroundColor Green
Log-Action "Extracted $($zipFile.Name) to $extractPath"

# --- STEP 3: DISCOVERY ---
$currentPath = $extractPath
$depth = 0
while ($depth -lt 5) {
    $items = Get-ChildItem -Path $currentPath
    $dirs = $items | Where-Object { $_.PSIsContainer }
    $files = $items | Where-Object { -not $_.PSIsContainer }
    if ($dirs.Count -eq 1 -and $files.Count -eq 0) { $currentPath = $dirs[0].FullName } else { $zipApps = $dirs; break }
    $depth++
}

# --- STEP 4: MAPPING ---
Write-Header "STEP 3: MAPPING"
$appsToUpdate = @()
$unmatchedApps = $zipApps 
$defaultServer = "D:\Program Files\ProPhoenix"
if (-not (Test-Path $defaultServer)) { $defaultServer = "C:\Program Files\ProPhoenix" }

# 4a. Auto-Match
Write-Host "`n🔹 PHASE 1: Server Applications (Auto-Match)" -ForegroundColor Cyan
$serverRoot = Read-Host "   Enter Server Root Path [Press Enter for '$defaultServer']"
if ($serverRoot -eq "") { $serverRoot = $defaultServer }

if (Test-Path $serverRoot) {
    $found = @()
    foreach ($app in $unmatchedApps) {
        if ($specialPromptApps -contains $app.Name) { continue }
        $checkPath = Join-Path $serverRoot $app.Name
        if (Test-Path $checkPath) {
            $appsToUpdate += [PSCustomObject]@{ AppName = $app.Name; SourcePath = $app.FullName; DestPath = $checkPath }
            $found += $app
        }
    }
    $unmatchedApps = $unmatchedApps | Where-Object { $found.Name -notcontains $_.Name }
    Write-Host "   ✅ Matched $($found.Count) server applications." -ForegroundColor Green
}

# 4b. Special Prompts
Write-Host "`n🔹 PHASE 2: Special Client/Web Components" -ForegroundColor Cyan
$specialsFound = $unmatchedApps | Where-Object { $specialPromptApps -contains $_.Name }
if ($specialsFound) {
    foreach ($specialApp in $specialsFound) {
        Write-Host "`n   ⚠️  FOUND SPECIAL COMPONENT: $($specialApp.Name)" -ForegroundColor Magenta
        if ((Read-Host "      Update $($specialApp.Name)? (Y/N)") -eq "Y") {
            $guessedPath = Join-Path $serverRoot $specialApp.Name
            if (-not (Test-Path $guessedPath)) {
                $driveLetter = Split-Path $serverRoot -Qualifier
                $guessedPath = "$driveLetter\Program Files\ProPhoenix\$($specialApp.Name)"
            }
            $userPath = Read-Host "      Enter Path [Press Enter for '$guessedPath']"
            if ($userPath -eq "") { $userPath = $guessedPath }
            if (Test-Path $userPath) {
                $appsToUpdate += [PSCustomObject]@{ AppName = $specialApp.Name; SourcePath = $specialApp.FullName; DestPath = $userPath }
                $unmatchedApps = $unmatchedApps | Where-Object { $_.Name -ne $specialApp.Name }
            } else { Write-Host "      ❌ Path not found." -ForegroundColor Red }
        } else {
            $unmatchedApps = $unmatchedApps | Where-Object { $_.Name -ne $specialApp.Name }
        }
    }
}

# 4c. Leftovers
if ($unmatchedApps.Count -gt 0) {
    Write-Host "`n🔹 PHASE 3: Other Unmatched Items" -ForegroundColor Yellow
    foreach ($app in $unmatchedApps) {
        if ((Read-Host "   ❓ Update $($app.Name)? (Y/N)") -eq "Y") {
             $manPath = Read-Host "      Enter Destination Path"
             if (Test-Path $manPath) {
                 $appsToUpdate += [PSCustomObject]@{ AppName = $app.Name; SourcePath = $app.FullName; DestPath = $manPath }
             }
        }
    }
}

if ($appsToUpdate.Count -eq 0) { Write-Host "No apps configured."; return }

# --- STEP 5: IMPACT & INSTANCE LIST ---
$filesToOverwrite = 0; $filesNew = 0; $batInstances = @()
foreach ($app in $appsToUpdate) {
    $cleanName = $app.AppName -replace " ", ""
    if ($instanceList -contains $app.AppName) { $batInstances += $app.AppName } 
    elseif ($instanceList -contains $cleanName) { $batInstances += $cleanName }
    
    $srcFiles = Get-ChildItem -Path $app.SourcePath -Recurse -File
    foreach ($f in $srcFiles) {
        $dst = Join-Path $app.DestPath $f.FullName.Substring($app.SourcePath.Length).TrimStart('\')
        if (Test-Path $dst) { $filesToOverwrite++ } else { $filesNew++ }
    }
}

Write-Header "STEP 4: SUMMARY"
$appsToUpdate | Format-Table AppName, DestPath -AutoSize
Write-Host "   Files to Update: $filesToOverwrite | New Files: $filesNew" -ForegroundColor Yellow
Log-Action "Impact Analysis: $filesToOverwrite updates, $filesNew new files."

# --- STEP 6: BACKUP PHASE (BEFORE STOPPING SERVICES) ---
Write-Header "STEP 5: PERFORMING BACKUP (Services Running)"
Log-Action "--- STARTING BACKUP PHASE ---"

$appIndex = 0
foreach ($app in $appsToUpdate) {
    $appIndex++
    $percent = ($appIndex / $appsToUpdate.Count) * 100
    Write-Progress -Activity "Backing up..." -Status "$($app.AppName)" -PercentComplete $percent
    
    $backupRoot = "$workPath\Backup\$($app.AppName)"
    $files = Get-ChildItem -Path $app.SourcePath -Recurse -File
    
    foreach ($file in $files) {
        $relPath = $file.FullName.Substring($app.SourcePath.Length).TrimStart('\')
        $destFile = Join-Path $app.DestPath $relPath
        $backupFile = Join-Path $backupRoot $relPath

        if (Test-Path $destFile) {
            $bDir = Split-Path $backupFile -Parent
            if (-not (Test-Path $bDir)) { New-Item -Path $bDir -ItemType Directory -Force | Out-Null }
            
            Copy-Item -Path $destFile -Destination $backupFile -Force -ErrorAction SilentlyContinue
            
            # DETAILED FULL PATH LOGGING FOR BACKUP
            Log-Action "BACKUP | Source: $destFile  -->  Dest: $backupFile"
        }
    }
}
Write-Host "   ✅ Backup Complete. Files saved to: $workPath\Backup" -ForegroundColor Green
Log-Action "Backup Phase Complete."

# --- STEP 7: STOP SERVICES ---
Write-Header "STEP 6: SERVICE MANAGEMENT"
if ((Read-Host "❓ Ready to STOP IIS/Services and APPLY updates? (Y/N)") -ne "Y") { return }

Write-Host "   Stopping IIS..." -ForegroundColor Yellow
iisreset /stop
Log-Action "IIS Stopped."

Write-Host "   Stopping Phoenix Services..." -ForegroundColor Yellow
Get-Service | Where-Object { $_.DisplayName -like "*Phoenix*" -and $_.Status -eq 'Running' } | Stop-Service -Force
Log-Action "Phoenix Services Stopped."

# --- STEP 8: APPLY PHASE ---
Write-Header "STEP 7: APPLYING UPDATES"
Log-Action "--- STARTING APPLY PHASE ---"

$appIndex = 0
foreach ($app in $appsToUpdate) {
    $appIndex++
    $percent = ($appIndex / $appsToUpdate.Count) * 100
    Write-Progress -Activity "Applying Updates..." -Status "$($app.AppName)" -PercentComplete $percent
    
    $files = Get-ChildItem -Path $app.SourcePath -Recurse -File
    foreach ($file in $files) {
        $relPath = $file.FullName.Substring($app.SourcePath.Length).TrimStart('\')
        $destFile = Join-Path $app.DestPath $relPath
        
        $dDir = Split-Path $destFile -Parent
        if (-not (Test-Path $dDir)) { New-Item -Path $dDir -ItemType Directory -Force | Out-Null }
        
        Copy-Item -Path $file.FullName -Destination $destFile -Force
        
        # DETAILED FULL PATH LOGGING FOR APPLY
        Log-Action "APPLIED | Source: $($file.FullName)  -->  Dest: $destFile"
    }
}
Write-Host "   ✅ Files Applied." -ForegroundColor Green
Log-Action "Apply Phase Complete."

# --- STEP 9: RESTORE IIS ---
Write-Header "STEP 8: RESTORING IIS"
Write-Host "   🚀 Starting IIS..." -ForegroundColor Cyan
iisreset /start
Log-Action "IIS Started."

# --- STEP 10: INSTANCE MANAGER ---
Write-Header "STEP 9: INSTANCE MANAGER"
if ($batInstances.Count -gt 0) {
    $appMgrPath = Find-ServerAppManager
    if ($appMgrPath) {
        $batFile = "$workPath\Run_Instance_Update.bat"
        $mgrDrive = Split-Path $appMgrPath -Qualifier
        $instanceListString = $batInstances -join '" "'
        
        $batContent = @"
$mgrDrive
cd \
cd "Program Files (x86)"
cd ProPhoenix
cd "Server Application Manager"

@echo off
SET AppMgrExePath="$appMgrPath"

echo Stopping all services...
powershell -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name `$_.Name -Force }"

echo All Phoenix services have been stopped.
%AppMgrExePath%\PnxAppMgr.exe "UPDATEINSTANCE" "$instanceListString"
%AppMgrExePath%\PnxAppMgr.exe "SHOWINSTANCES"
::End of Script::
"@
        Set-Content -Path $batFile -Value $batContent
        Write-Host "   ✅ BAT File Created: $batFile" -ForegroundColor Yellow
        Log-Action "Generated BAT File for: $instanceListString"
        
        if ((Read-Host "   🚀 Run Instance Update Script NOW? (Y/N)") -eq "Y") {
            Start-Process -FilePath $batFile -Wait
        }
    }
} else { Write-Host "   No Instance-Based apps." -ForegroundColor Gray }

# --- STEP 11: FINAL START ---
Write-Header "STEP 10: FINALIZING"
if ((Read-Host "❓ Start remaining Phoenix Services? (Y/N)") -eq "Y") {
    Write-Host "   Starting Services..." -ForegroundColor Yellow
    Get-Service | Where-Object { $_.DisplayName -like "*Phoenix*" -and $_.Status -ne 'Running' } | Start-Service
}

Write-Host "`n✅ Done. Log: $global:logFile" -ForegroundColor Green
Pause