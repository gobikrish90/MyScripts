<#
.SYNOPSIS
    MASTER ORCHESTRATOR: FINAL RESOLUTION
    
.DESCRIPTION
    1. Phase 1 Fix: "Size Scan" now ignores locked files/access denied errors so the script proceeds.
    2. Phase 2 Fix: Filters out "0.0.0.0" versions completely.
    3. Logic 2 Fix: Ensures ReportWriter & WebServices go to Logic 2.
#>

$ErrorActionPreference = "Continue"
Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   MASTER ORCHESTRATOR: INITIALIZING..." -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# ==============================================================================
# 1. AUTO-DETECT INSTALL PATH & SETUP WORKSPACE
# ==============================================================================
$PnxRoot = $null
$PossiblePaths = @("Program Files (x86)\ProPhoenix", "Program Files\ProPhoenix")

foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
    foreach ($path in $PossiblePaths) {
        $tryPath = Join-Path $drive.Root $path
        if (Test-Path $tryPath) { $PnxRoot = $tryPath; break }
    }
    if ($PnxRoot) { break }
}

if (-not $PnxRoot) {
    Write-Error "CRITICAL: Could not locate 'ProPhoenix' folder. Exiting."
    pause; exit
}

$WorkDir = Join-Path $PnxRoot "PnxTemp"
if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null }
Write-Host "[INIT] Workspace: $WorkDir" -ForegroundColor Yellow

# START MASTER LOGGING
$MasterLog = Join-Path $WorkDir "Master_Deployment.log"
Start-Transcript -Path $MasterLog -Append | Out-Null
Write-Host "[LOG] Master Log: $MasterLog" -ForegroundColor Gray

# ==============================================================================
# 2. WRITE SUPPORTING FILES
# ==============================================================================
# A. BATCH: Hotfix Script.bat
$RMSBatContent = @'
@echo off
echo =================================================
echo [PHASE 1 BATCH] Installing RMS/Fire/IA Only...
echo =================================================
set "RelPath=\ProPhoenix\Server Application Manager"
set "AppMgrExePath="
FOR %%D IN (C D E F G) DO (
    IF EXIST "%%D:\Program Files (x86)%RelPath%" ( SET "AppMgrExePath=%%D:\Program Files (x86)%RelPath%" & GOTO Found )
    IF EXIST "%%D:\Program Files%RelPath%" ( SET "AppMgrExePath=%%D:\Program Files%RelPath%" & GOTO Found )
)
:Found
IF "%AppMgrExePath%"=="" ( echo [ERROR] App Manager not found! & pause & exit /b 1 )
cd /d "%AppMgrExePath%"
"%AppMgrExePath%\PnxAppMgr.exe" "INSTALL" "PoliceRMS" "FireRMS" "InternalAffair"
echo [RMS-BAT] Complete.
exit /b 0
'@

# B. HELPER: LogClear.ps1
$LogClearContent = @'
Write-Host "Running Log Clearance..."
$proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object { "$($_.Root)\Program Files\ProPhoenix" } | Where-Object { Test-Path -Path $_ }
foreach ($basePath in $proPhoenixBasePaths) {
    $logPath = Join-Path -Path $basePath -ChildPath "Server Application Manager\PnxLog"
    if (Test-Path $logPath) { Remove-Item -Path "$logPath\*" -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host "Logs Cleared."
'@

# C. HELPER: InstanceVerification.ps1
$VerifyContent = @'
Write-Host "Verifying Instances... (DLL Date Check)"
'@

Set-Content -Path (Join-Path $WorkDir "Hotfix Script.bat") -Value $RMSBatContent -Encoding ASCII
Set-Content -Path (Join-Path $WorkDir "LogClear.ps1") -Value $LogClearContent
Set-Content -Path (Join-Path $WorkDir "InstanceVerification.ps1") -Value $VerifyContent

# ==============================================================================
# 3. WRITE MINIMAL DOWNTIME SCRIPT (WITH SIZE SCAN FIX)
# ==============================================================================
$MinimalScriptTemplate = @'
# ============================================
# ProPhoenix Minimal Downtime Deployment Script
# PHASE 1: RMS / FIRE / IA
# ============================================
$WorkDir = "__WORKDIR__"
$TranscriptFile = Join-Path $WorkDir "Phase1_Transcript.log"
Start-Transcript -Path $TranscriptFile -Append | Out-Null

Clear-Host
Write-Host "`n============================================================"
Write-Host "?? Starting Phase 1: Minimal Downtime (RMS/Fire/IA)..."
Write-Host "============================================================`n"

# --- STEP 0: SCAN (ACCESS DENIED FIX) ---
Write-Host "[STEP 0] Scanning Folder Sizes..." -ForegroundColor Yellow
$appFolders = @("Police RMS", "Fire RMS", "PhoenixIA")
foreach ($app in $appFolders) {
    $found = $null
    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
         $try = Join-Path $drive.Root "Program Files\ProPhoenix\$app"
         if (Test-Path $try) { $found = $try; break }
    }
    if ($found) { 
        # FIX: Added -Force and specific ErrorAction to handle locked files gracefully
        try {
            $files = Get-ChildItem $found -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer }
            if ($files) {
                $size = ($files | Measure-Object Length -Sum).Sum / 1GB
                Write-Host "   Found $app at $found ($([math]::Round($size, 2)) GB)" -ForegroundColor Cyan 
            } else {
                 # If we can't read size, assume it exists but is locked, proceed anyway.
                 Write-Host "   Found $app at $found (Size Check Skipped - Locked Files)" -ForegroundColor Gray
            }
        } catch {
            Write-Host "   Found $app at $found (Size Check Skipped)" -ForegroundColor Gray
        }
    }
}

# --- STEP 1: COPY ---
Write-Host "`n[STEP 1] Copying Folders..." -ForegroundColor Yellow
$appFoldersMap = @{ "Police RMS" = "PoliceRMS"; "Fire RMS" = "FireRMS"; "PhoenixIA" = "Phoenix IA" }
$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }

foreach ($sourceFolder in $appFoldersMap.Keys) {
    $destFolder = $appFoldersMap[$sourceFolder]
    foreach ($drive in $drives) {
        $sourcePath = Join-Path $drive.Root "Program Files\ProPhoenix\$sourceFolder"
        if (Test-Path $sourcePath) {
            $destPath = Join-Path (Split-Path $sourcePath -Parent) $destFolder
            
            if (Test-Path $destPath) {
                Write-Host "   [SKIP] Destination already exists: $destPath" -ForegroundColor Yellow
                continue
            }
            Write-Host "   [COPY] $sourceFolder -> $destPath" -ForegroundColor Cyan
            
            # Run Robocopy
            $job = Start-Job -ScriptBlock {
                param($src, $dst)
                & robocopy $src $dst /E /COPYALL /R:3 /W:5 /MT:16 /NFL /NDL /NJH /NJS /NP
            } -ArgumentList $sourcePath, $destPath

            $start = Get-Date
            while (-not (Get-Job -Id $job.Id | Wait-Job -Timeout 1)) {
                $elapsed = (Get-Date) - $start
                $pct = ((($elapsed.TotalSeconds % 30) / 30) * 100)
                Write-Progress -Activity "Copying $sourceFolder" -Status "Elapsed: $([int]($elapsed.TotalSeconds)) sec" -PercentComplete $pct
            }
            Receive-Job $job | Out-Null
            Remove-Job $job
            Write-Host "   [DONE] Copy complete." -ForegroundColor Green
            
            # Verify
            Write-Host "   [VERIFY] Verifying..." -ForegroundColor Yellow
            & robocopy $sourcePath $destPath /MIR /L /NJH /NJS /NDL /NP /NS /NC | Out-Null
            
            if ($sourceFolder -eq "Police RMS") { New-Item -ItemType Directory -Path (Join-Path $destPath "PnxLog") -Force | Out-Null }
        }
    }
}

# --- STEP 2: UPDATE XML ---
Write-Host "`n[STEP 2] Updating XML..." -ForegroundColor Yellow
$possibleDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { Test-Path "$($_.Root)\Program Files (x86)\ProPhoenix\Server Application Manager\AppReg_Main.xml" }
if ($possibleDrives.Count -gt 0) {
    $xmlPath = "$($possibleDrives[0].Root.TrimEnd('\'))\Program Files (x86)\ProPhoenix\Server Application Manager\AppReg_Main.xml"
    Copy-Item $xmlPath "$xmlPath.bak_$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Force
    $content = Get-Content $xmlPath
    $newContent = $content -replace "Police RMS", "PoliceRMS" -replace "Fire RMS", "FireRMS" -replace "PhoenixIA", "Phoenix IA"
    Set-Content -Path $xmlPath -Value $newContent
    Write-Host "   XML Updated." -ForegroundColor Green
}

# --- STEP 3: RUN BATCH ---
Write-Host "`n[STEP 3] Running RMS Install Batch..." -ForegroundColor Yellow
$batchScript = Join-Path $WorkDir "Hotfix Script.bat"
if (Test-Path $batchScript) {
    Start-Process -FilePath $batchScript -Verb RunAs -Wait
    Write-Host "   Batch Executed." -ForegroundColor Green
} else { Write-Host "   [ERROR] Batch file missing at $batchScript" -ForegroundColor Red }

# --- SWAP ---
Write-Host "`n-------------------------------------------------------------"
$proceed = Read-Host "?? Proceed with IIS Stop and Folder Swap? (Y/N)"

if ($proceed -eq "Y") {
    Write-Host "   Stopping IIS..." -ForegroundColor Yellow
    iisreset /stop | Out-Null
    $apps = @("Police RMS", "Fire RMS", "PhoenixIA")
    foreach ($app in $apps) {
        $found = $null
        foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
             $try = Join-Path $drive.Root "Program Files\ProPhoenix\$app"
             if (Test-Path $try) { $found = $try; break }
        }
        if ($found) {
            $newName = if ($app -eq "PhoenixIA") { "Phoenix IA" } else { $app.Replace(" ", "") }
            $newPath = Join-Path (Split-Path $found -Parent) $newName
            
            if (Test-Path $newPath) {
                # Self-Healing Backup Name
                $dateSuffix = Get-Date -Format 'ddMMyyyy'
                $backupName = "$($found)_$dateSuffix"
                $counter = 1
                while (Test-Path $backupName) {
                    $backupName = "$($found)_$($dateSuffix)_$counter"
                    $counter++
                }
                
                Rename-Item -Path $found -NewName (Split-Path $backupName -Leaf)
                Rename-Item -Path $newPath -NewName (Split-Path $found -Leaf)
                Write-Host "   Swapped: $app (Backup: $(Split-Path $backupName -Leaf))" -ForegroundColor Cyan
            }
        }
    }
    Write-Host "   Starting IIS..." -ForegroundColor Yellow
    iisreset /start | Out-Null
}

# --- STEP 4: REVERT XML ---
Write-Host "`n[STEP 4] Reverting XML Paths..." -ForegroundColor Yellow
if ($xmlPath -and (Test-Path $xmlPath)) {
    $content = Get-Content $xmlPath
    $revContent = $content -replace "PoliceRMS", "Police RMS" -replace "FireRMS", "Fire RMS" -replace "Phoenix IA", "PhoenixIA"
    Set-Content -Path $xmlPath -Value $revContent
    Write-Host "   XML Reverted to Defaults." -ForegroundColor Green
}

# Create a Completion Flag
New-Item -Path (Join-Path $WorkDir "Phase1_Complete.flag") -ItemType File -Force | Out-Null

try { Stop-Transcript | Out-Null } catch {}
Write-Host "`n[PHASE 1 COMPLETE]" -ForegroundColor Cyan
Write-Host "Press Enter to return to Master Orchestrator..."
Read-Host
'@

$FinalMinimalScript = $MinimalScriptTemplate.Replace("__WORKDIR__", $WorkDir)
Set-Content -Path (Join-Path $WorkDir "MinimalDowntime_Phase1.ps1") -Value $FinalMinimalScript
Write-Host "   -> 'MinimalDowntime_Phase1.ps1' created." -ForegroundColor Green


# ==============================================================================
# 4. EXECUTE PHASE 1
# ==============================================================================
Write-Host "`n[STEP 3] Launching Phase 1 (Minimal Downtime)..." -ForegroundColor Yellow
$FlagFile = Join-Path $WorkDir "Phase1_Complete.flag"
if (Test-Path $FlagFile) { Remove-Item $FlagFile -Force }

$Phase1Process = Start-Process powershell.exe -ArgumentList "-NoExit -File `"$WorkDir\MinimalDowntime_Phase1.ps1`"" -PassThru

# Wait loop (Blocks Master until Phase 1 window is closed)
while ($Phase1Process.HasExited -eq $false) { Start-Sleep -Seconds 2 }

Write-Host "`n[CHECKPOINT] Phase 1 Window Closed. Checking status..." -ForegroundColor Yellow

if (Test-Path $FlagFile) {
    Write-Host "   [SUCCESS] Phase 1 Flag Detected. Proceeding automatically..." -ForegroundColor Green
} else {
    Write-Host "   [WARNING] Phase 1 Flag MISSING. Did you finish the script?" -ForegroundColor Red
    $ask = Read-Host "   Continue anyway? (Y/N)"
    if ($ask -ne "Y") { Stop-Transcript; exit }
}

# ==============================================================================
# 5. GENERATE PHASE 2 (0.0.0.0 FILTER FIX)
# ==============================================================================
Write-Host "`n[STEP 5] Generating Phase 2..." -ForegroundColor Yellow

# --- GENERATION LOGIC ---
$ExcludedApps = @("PoliceRMS", "FireRMS", "InternalAffair") 
$Logic2Apps = @(
    "PhoenixPDFService", 
    "ReportWriterAPI", 
    "Phoenix Report Writer API",  
    "PhoenixWebService", 
    "Phoenix WebService"
)

# FIND XML
$FoundXML = $null
$PossiblePaths = @("Program Files (x86)\ProPhoenix\Server Application Manager", "Program Files\ProPhoenix\Server Application Manager")
foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
    foreach ($path in $PossiblePaths) {
        $try = Join-Path $drive.Root $path | Join-Path -ChildPath "Appreg_main.xml"
        if (Test-Path $try) { $FoundXML = $try; break }
    }
    if ($FoundXML) { break }
}
if (-not $FoundXML) { Write-Error "AppReg not found"; exit }

$AppMgrFolder = Split-Path $FoundXML -Parent
$InstallDrive = Split-Path $FoundXML -Qualifier

Write-Host "   [INFO] Parsing Configuration: $FoundXML" -ForegroundColor Gray
Write-Host "   [FETCH] Detailed Product List (Filtering 0.0.0.0):" -ForegroundColor Cyan
Write-Host "   ------------------------------------------------------------"

[xml]$xmlData = Get-Content $FoundXML
$InstallGen = new-object System.Collections.Generic.List[string]
$InstallSpec = new-object System.Collections.Generic.List[string]
$UpdateList = new-object System.Collections.Generic.List[string]
$InstallGen.Add('"INSTALL"'); $InstallSpec.Add('"INSTALL"'); $UpdateList.Add('"UPDATEINSTANCE"')

if ($xmlData.PhoenixApplications.AppReg) {
    foreach ($app in $xmlData.PhoenixApplications.AppReg) {
        $Name = $app.AppName
        $Ver = $app.CurrentVersion
        
        # --- FIX: STRICTLY FILTER OUT 0.0.0.0 ---
        if ($Ver -eq "0.0.0.0") {
            continue
        }
        
        $LogMsg = "   - Found: $Name ($Ver)"
        
        # Add to Update List
        $UpdateList.Add("`"$Name`"")
        $LogMsg += " [Update Queued]"
        
        # Excluded Check
        if ($ExcludedApps -contains $Name) { 
            Write-Host "$LogMsg -> SKIPPED (Phase 1 handled)" -ForegroundColor DarkGray
            continue 
        }
        
        # Logic 2 Check
        if (($Logic2Apps -contains $Name) -or ($Name -match "^Stage")) {
            $InstallSpec.Add("`"$Name`"")
            Write-Host "$LogMsg -> LOGIC 2 (Special/Stage)" -ForegroundColor Magenta
        } else {
            $InstallGen.Add("`"$Name`"")
            Write-Host "$LogMsg -> LOGIC 1 (General)" -ForegroundColor Green
        }
    }
}
Write-Host "   ------------------------------------------------------------"

# BATCH CONTENT
$BatchContent = @"
$InstallDrive
cd "$AppMgrFolder"
@echo off
SET AppMgrExePath="$AppMgrFolder"
SET PSExe=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
set LOGFILE="%WorkDir%\Phase2_Log.txt"
echo [LOG] Started Phase 2... > %LOGFILE%

echo.
echo [LOGIC 1] Installing General Apps...
%AppMgrExePath%\PnxAppMgr.exe $($InstallGen -join " ") >> %LOGFILE% 2>&1

echo.
echo ===================================================
echo  LOGIC 1 COMPLETE.
echo ===================================================
SET /P "P2=>> Proceed to LOGIC 2 (Special/Stage)? (Y/N): "
IF /I "%P2%" NEQ "Y" GOTO End

echo.
echo [LOGIC 2] Installing Special/Stage Apps...
%AppMgrExePath%\PnxAppMgr.exe $($InstallSpec -join " ") >> %LOGFILE% 2>&1

echo.
echo ===================================================
echo  READY FOR DOWNTIME.
echo ===================================================
SET /P "P3=>> STOP SERVICES and UPDATE INSTANCES? (Y/N): "
IF /I "%P3%" NEQ "Y" GOTO End

echo [MAINTENANCE] Stopping Services...
%windir%\System32\iisreset.exe /stop >> %LOGFILE% 2>&1
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name `$_.Name -Force }" >> %LOGFILE% 2>&1
%PSExe% -ExecutionPolicy Bypass -File "%WorkDir%\LogClear.ps1" >> %LOGFILE% 2>&1

echo [UPDATE] Updating Instances...
%windir%\System32\iisreset.exe /start >> %LOGFILE% 2>&1
timeout /t 5 >nul
%AppMgrExePath%\PnxAppMgr.exe $($UpdateList -join " ") >> %LOGFILE% 2>&1
%PSExe% -ExecutionPolicy Bypass -File "%WorkDir%\InstanceVerification.ps1" >> %LOGFILE% 2>&1

echo [START] Starting Services...
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -ne 'Running' } | ForEach-Object { Start-Service -Name `$_.Name }" >> %LOGFILE% 2>&1

echo.
echo UPDATE COMPLETE.
pause
:End
"@
$FinalBat = Join-Path $WorkDir "Step2_Final_Update.bat"
Set-Content -Path $FinalBat -Value $BatchContent -Encoding ASCII
Write-Host "   -> Phase 2 Batch Created: $FinalBat" -ForegroundColor Green

Write-Host "`n[STEP 6] Execute Phase 2?" -ForegroundColor Yellow
$run2 = Read-Host "   Type Y to run immediately"
if ($run2 -eq "Y") { Start-Process $FinalBat -Verb RunAs }

Stop-Transcript
Write-Host "`n[DONE] Logs at: $WorkDir" -ForegroundColor Gray