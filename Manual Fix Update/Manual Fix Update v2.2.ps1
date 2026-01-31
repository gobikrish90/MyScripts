# ==============================================================================
# SCRIPT: Manual Fix Update Applicator (v26 - Mapping Logic Edition)
# PURPOSE: Auto-Match -> Manual Map -> Exact Instance ID Translation -> Backup/Apply -> Verify
# ==============================================================================

# --- CONFIGURATION ---
$minFreeSpaceGB = 5  
$specialPromptApps = @("CAD Client", "WDA", "Phoenix WDA V2", "PhoenixWDA", "WebDeviceAssistant")

# --- INSTANCE ID MAPPING TABLE (Derived from your UPDATED MAPPING DATA.txt) ---
# Format: "Folder Name" = "InstanceID"
$FolderToInstanceMap = @{
    "Job Server"                  = "JobServer"
    "TraCS Server"                = "TraCSServer"
    "Video Server"                = "VideoServer"
    "Finger Print Server"         = "FingerPrintServer"
    "Phoenix Email Watcher"       = "EmailWatcher"
    "CAD Server"                  = "CADServer"
    "CAD NLB Message Server"      = "CADNLBServer"
    "CAD2CAD Tellus Server"       = "CAD2CADTellusServer"
    "E911 Server"                 = "E911Server"
    "CAD Zetron Server"           = "ZetronServer"
    "External Interface Server"   = "ExternalInterface"
    "GPS Server"                  = "GPSServer"
    "NCIC Server"                 = "NCICServer"
    "NCIC State Server"           = "NCICStateServer"
    "FTP Server"                  = "FTPServer"
    "Locution CAD Voice Server"   = "LocutionCADVoiceServer"
    "Phoenix Device Notification" = "DeviceNotification"
    "Device Notification Server"  = "DeviceNotification"
    "Streaming Notification"      = "StreamingNotification"
    "Report Service"              = "ReportService"
    "PnxFolderWatcher"            = "FolderWatcher"
    "DocsServer"                  = "DocsServer"
    "Toner Server"                = "PhoenixTonerServer"
    "Alert App"                   = "PhoenixAlertApp"
    "Text2Dispatch"               = "PhoenixTExt2Dispatch"
    "CADText2Dispatch"            = "PhoenixTExt2Dispatch"
    "Phoenix AI Watcher"          = "PHOENIXAIWATCHERSERVICE"
    "Job Server V2"               = "PHOENIXJOBSVRV2"
}

# --- HELPER FUNCTIONS ---
function Write-Header ($text) {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "   $text" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Log-Action "HEADER: $text"
}

function Log-Action ($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp | $message"
    try { Add-Content -Path $global:logFile -Value $line -ErrorAction Stop } catch { }
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

Write-Header "STEP 1: PREPARATION"
Write-Host "   Working Path: $workPath" -ForegroundColor Gray

# OPEN FOLDER
Write-Host "   📂 Opening folder..." -ForegroundColor Yellow
Invoke-Item $workPath

# PAUSE
Write-Host "`n   ⚠️  ACTION REQUIRED:" -ForegroundColor Magenta
Write-Host "   1. The folder has been opened."
Write-Host "   2. Please PASTE the zip file into this folder."
Write-Host "   3. Press ENTER here when you are done."
Read-Host "   > Press Enter to continue..."

# CHECK ZIP
$zipFile = Get-ChildItem -Path $workPath -Filter "*.zip" | Select-Object -First 1
if (-not $zipFile) {
    Write-Host "❌ No ZIP file found! Did you paste it?" -ForegroundColor Red
    Pause; return
}

Write-Header "STEP 2: EXTRACTING"
Write-Host "   Found: $($zipFile.Name)" -ForegroundColor Yellow
$extractPath = Join-Path $workPath "Extracted_$(Get-Date -Format 'HHmmss')"
Expand-Archive -Path $zipFile.FullName -DestinationPath $extractPath -Force
Write-Host "   ✅ Extraction Complete." -ForegroundColor Green

# DISCOVERY
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
Write-Host "`n🔹 PHASE 1: Server Applications" -ForegroundColor Cyan
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
            
            $appsToUpdate += [PSCustomObject]@{ AppName = $specialApp.Name; SourcePath = $specialApp.FullName; DestPath = $userPath }
            $unmatchedApps = $unmatchedApps | Where-Object { $_.Name -ne $specialApp.Name }
            Write-Host "      ✅ Configured." -ForegroundColor Green
        } else {
            $unmatchedApps = $unmatchedApps | Where-Object { $_.Name -ne $specialApp.Name }
        }
    }
}

# 4c. Manual Mapping (THE FIX)
if ($unmatchedApps.Count -gt 0) {
    Write-Host "`n🔹 PHASE 3: Other Unmatched Items (Manual Mapping)" -ForegroundColor Yellow
    foreach ($app in $unmatchedApps) {
        $response = Read-Host "   ❓ Update $($app.Name)? (Y/N)"
        if ($response -eq "Y") {
             $manPathRaw = Read-Host "      Enter Destination Path for $($app.Name)"
             $manPath = $manPathRaw.Trim('"')

             # Force add to list regardless of existence (script creates folders)
             $appsToUpdate += [PSCustomObject]@{ AppName = $app.Name; SourcePath = $app.FullName; DestPath = $manPath }
             Write-Host "      ✅ Added Manual Path: $manPath" -ForegroundColor Green
        }
    }
}

if ($appsToUpdate.Count -eq 0) { Write-Host "No apps configured."; return }

# --- STEP 5: BACKUP & REVIEW ---
Write-Header "STEP 4: BACKUP & REVIEW"
Log-Action "--- STARTING BACKUP PHASE ---"

$filesByFolder = @{}
$backupRootBase = "$workPath\Backup"

foreach ($app in $appsToUpdate) {
    Write-Host "`n📁 Processing: $($app.AppName)" -ForegroundColor Cyan
    $sourceFiles = Get-ChildItem -Path $app.SourcePath -Recurse -File
    
    foreach ($sourceFile in $sourceFiles) {
        $relativePath = $sourceFile.FullName.Substring($app.SourcePath.Length).TrimStart('\')
        $destinationFilePath = Join-Path $app.DestPath $relativePath
        $backupFilePath = Join-Path "$backupRootBase\$($app.AppName)" $relativePath

        # 1. Backup if exists
        if (Test-Path $destinationFilePath) {
            $backupDir = Split-Path $backupFilePath -Parent
            if (-not (Test-Path $backupDir)) { New-Item -Path $backupDir -ItemType Directory -Force | Out-Null }
            
            Copy-Item -Path $destinationFilePath -Destination $backupFilePath -Force -ErrorAction SilentlyContinue
            
            if (-not $filesByFolder.ContainsKey($app.AppName)) { $filesByFolder[$app.AppName] = @() }
            $filesByFolder[$app.AppName] += [PSCustomObject]@{
                Source      = $sourceFile.FullName
                Destination = $destinationFilePath
                Backup      = $backupFilePath
            }
        } else {
            # 2. Track new files too (for Apply phase)
             if (-not $filesByFolder.ContainsKey($app.AppName)) { $filesByFolder[$app.AppName] = @() }
             $filesByFolder[$app.AppName] += [PSCustomObject]@{
                Source      = $sourceFile.FullName
                Destination = $destinationFilePath
                Backup      = "NEW FILE (No Backup)"
            }
        }
    }
}

# Display Summary
foreach ($folderName in $filesByFolder.Keys) {
    Write-Host "`n📁 $folderName" -ForegroundColor Cyan
    foreach ($file in $filesByFolder[$folderName]) {
        if ($file.Backup -like "NEW*") {
            Write-Host "   🆕 New File: $($file.Destination)" -ForegroundColor DarkGray
        } else {
            Write-Host "   📦 Backed up: $($file.Destination)" -ForegroundColor Yellow
        }
    }
}

# --- STEP 6: APPLY & INSTANCE BAT ---
Write-Host "`n❓ Do you want to replace/add all these files?" -ForegroundColor Cyan
$response = Read-Host "   Type Y to confirm, any other key to skip"

if ($response -eq "Y" -or $response -eq "y") {
    
    # 1. STOP SERVICES
    Write-Header "STEP 5: STOPPING SERVICES"
    Write-Host "   Stopping IIS..." -ForegroundColor Yellow
    iisreset /stop
    Write-Host "   Stopping Phoenix Services..." -ForegroundColor Yellow
    Get-Service | Where-Object { $_.DisplayName -like "*Phoenix*" -and $_.Status -eq 'Running' } | Stop-Service -Force

    # 2. APPLY
    Write-Header "STEP 6: APPLYING UPDATES"
    foreach ($folderName in $filesByFolder.Keys) {
        Write-Host "`n📁 $folderName" -ForegroundColor Cyan
        foreach ($file in $filesByFolder[$folderName]) {
            # Ensure dest dir exists (Crucial for Manual Paths)
            $destDir = Split-Path $file.Destination -Parent
            if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
            
            Copy-Item -Path $file.Source -Destination $file.Destination -Force
            Write-Host "   🔄 Applied: $($file.Destination)" -ForegroundColor Green
            Log-Action "APPLIED | $($file.Source) -> $($file.Destination)"
        }
    }
    
    # 3. RESTORE IIS
    Write-Header "STEP 7: RESTORING IIS"
    Write-Host "   🚀 Starting IIS..." -ForegroundColor Cyan
    iisreset /start

    # 4. INSTANCE BAT GENERATION (Using Mapping Table)
    Write-Header "STEP 8: INSTANCE MANAGER"
    $batInstances = @()
    
    foreach ($appKey in $filesByFolder.Keys) {
        # Check against the Mapping Table First
        if ($FolderToInstanceMap.ContainsKey($appKey)) {
            $mappedID = $FolderToInstanceMap[$appKey]
            $batInstances += $mappedID
        } else {
            # Fallback: Remove spaces
            $cleanName = $appKey -replace " ", ""
            if ($FolderToInstanceMap.Values -contains $cleanName) {
                $batInstances += $cleanName
            }
        }
    }
    # Deduplicate
    $batInstances = $batInstances | Select-Object -Unique

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
            Write-Host "      Instances: $instanceListString" -ForegroundColor Gray
            
            if ((Read-Host "   🚀 Run Instance Update Script NOW? (Y/N)") -eq "Y") {
                Start-Process -FilePath $batFile -Wait
            }
        }
    }

} else {
    Write-Host "`n⛔ Replacement cancelled." -ForegroundColor Red
}

# --- STEP 9: DLL VERIFICATION ---
Write-Header "STEP 9: DLL VERIFICATION"
Write-Host "   Starting verification scan..." -ForegroundColor Cyan

$prophoenixPaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $driveRoot = "$($_.Root)Program Files\ProPhoenix"
    if (Test-Path $driveRoot) { $driveRoot }
}

if ($prophoenixPaths) {
    $excludedFolders = @("Finger Print Client", "ID Scanner", "Phoenix WDA V2", "Police RMS", "PoliceRMS", "Print Server", "WDA")
    $completedCount = 0; $notCompletedCount = 0; $totalChecked = 0

    foreach ($basePath in $prophoenixPaths) {
        $appFolders = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue | Where-Object { $excludedFolders -notcontains $_.Name }

        foreach ($app in $appFolders) {
            $instancesPath = Join-Path $app.FullName "_Instances"
            if (Test-Path $instancesPath) {
                $instanceEnvs = Get-ChildItem -Path $instancesPath -Directory -ErrorAction SilentlyContinue
                foreach ($env in $instanceEnvs) {
                    $baseDlls = Get-ChildItem -Path $app.FullName -Filter *.dll -File -ErrorAction SilentlyContinue
                    $instanceDlls = Get-ChildItem -Path $env.FullName -Filter *.dll -File -ErrorAction SilentlyContinue
                    $status = "Completed"

                    foreach ($dll in $baseDlls) {
                        $match = $instanceDlls | Where-Object { $_.Name -eq $dll.Name }
                        if ($match) {
                            if (($match.LastWriteTime -lt $dll.LastWriteTime) -or ($match.Length -ne $dll.Length)) {
                                $status = "Not Completed"; break
                            }
                        } else { $status = "Not Completed"; break }
                    }

                    $totalChecked++
                    if ($status -eq "Completed") {
                        $completedCount++
                        Write-Host ("[OK] " + $app.Name + " -> " + $env.Name + " : ✅ Completed") -ForegroundColor Green
                    } else {
                        $notCompletedCount++
                        Write-Host ("[WARN] " + $app.Name + " -> " + $env.Name + " : ❌ Not Completed") -ForegroundColor Red
                    }
                }
            }
        }
    }
    Write-Host "`nTotal Verified : $totalChecked"
    Write-Host "Completed      : $completedCount" -ForegroundColor Green
    Write-Host "Not Completed  : $notCompletedCount" -ForegroundColor Red
}

# --- STEP 10: FINAL START ---
Write-Header "STEP 10: FINALIZING"
if ((Read-Host "❓ Start remaining Phoenix Services? (Y/N)") -eq "Y") {
    Write-Host "   Starting Services..." -ForegroundColor Yellow
    Get-Service | Where-Object { $_.DisplayName -like "*Phoenix*" -and $_.Status -ne 'Running' } | Start-Service
}

Write-Host "`n✅ Done. Log: $global:logFile" -ForegroundColor Green
Pause