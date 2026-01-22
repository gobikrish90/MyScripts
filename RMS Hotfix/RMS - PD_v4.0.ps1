<#
.SYNOPSIS
    RMS - PD Hotfix - Installation Team"
    
.DESCRIPTION
    1. Auto-detects ProPhoenix Drive.
    2. CHECKS PnxConfigMgr for 'UpdateUserName'.
    3. PROMPTS: "Are you going to run rms application in this or using Minimal downtime?"
       - YES: Adds RMS Apps to LOGIC 2 (Stop Services).
       - NO:  Skips RMS Apps.
    4. Writes helper scripts (SessionClear - NO LOGS, Verification, Launcher).
    5. Generates 'Production_Update.bat' with 'cd ..\..\..\..' fix.
    6. Launches the batch file.
#>

$ErrorActionPreference = "Continue"
Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   RMS - PD Hotfix - Installation Team" -ForegroundColor Cyan
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

# ==============================================================================
# 2. WRITE SUPPORTING FILES
# ==============================================================================

# A. SESSION DATA CLEANUP (ONLY - NO LOGS)
$SessionClearContent = @'
Write-Host "Cleaning CAD Server Session Data..."
$proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object { 
    "$($_.Root)Program Files (x86)\ProPhoenix", "$($_.Root)Program Files\ProPhoenix" 
} | Where-Object { Test-Path -Path $_ }

foreach ($basePath in $proPhoenixBasePaths) {
    $cadServerPath = Join-Path -Path $basePath -ChildPath "CAD Server\_Instances"
    if (Test-Path $cadServerPath) {
        $cadInstances = Get-ChildItem -Path $cadServerPath -Directory -ErrorAction SilentlyContinue
        foreach ($inst in $cadInstances) {
            $sessionDataPath = Join-Path -Path $inst.FullName -ChildPath "SvrSessionData"
            if (Test-Path $sessionDataPath) {
                Write-Host "   Target: $($inst.Name)"
                $delCount = 0
                Get-ChildItem -Path $sessionDataPath -File -ErrorAction SilentlyContinue | ForEach-Object { 
                    try { 
                        Remove-Item -Path $_.FullName -Force -ErrorAction Stop 
                        $delCount++
                    } catch { 
                        Write-Host "      [LOCKED] $($_.Name)" -ForegroundColor Gray 
                    }
                }
                if ($delCount -gt 0) { Write-Host "      Removed $delCount session files." -ForegroundColor DarkGray }
            }
        }
    }
}
Write-Host "Session Cleanup Complete."
'@

# B. VERIFICATION SCRIPT
$VerifyContent = @'
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
function Log-Msg { param([string]$Msg, [ConsoleColor]$Color = "White") Write-Host $Msg -ForegroundColor $Color }
Log-Msg "[INFO] Starting DLL verification..." "Cyan"
$prophoenixPaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object { "$($_.Root)Program Files\ProPhoenix" } | Where-Object { Test-Path $_ }
$excludedFolders = @("Finger Print Client","ID Scanner","Phoenix WDA V2","Police RMS","PoliceRMS","Print Server","WDA")
$completedCount = 0; $notCompletedCount = 0;
foreach ($basePath in $prophoenixPaths) {
    $appFolders = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue | Where-Object { $excludedFolders -notcontains $_.Name }
    foreach ($app in $appFolders) {
        $instancesPath = Join-Path $app.FullName "_Instances"
        if (Test-Path $instancesPath) {
            $instanceEnvs = Get-ChildItem -Path $instancesPath -Directory
            foreach ($env in $instanceEnvs) {
                $baseDlls = Get-ChildItem -Path $app.FullName -Filter *.dll -File
                $instanceDlls = Get-ChildItem -Path $env.FullName -Filter *.dll -File
                $status = "Completed"
                foreach ($dll in $baseDlls) {
                    $match = $instanceDlls | Where-Object { $_.Name -eq $dll.Name }
                    if ($match) {
                        if (($match.LastWriteTime -lt $dll.LastWriteTime) -or ($match.Length -ne $dll.Length)) { $status = "Not Completed"; break }
                    } else { $status = "Not Completed"; break }
                }
                if ($status -eq "Completed") { $completedCount++; Log-Msg "[OK] $($app.Name) -> $($env.Name)" "Green" } 
                else { $notCompletedCount++; Log-Msg "[FAIL] $($app.Name) -> $($env.Name) (DLL Mismatch)" "Red" }
            }
        }
    }
}
Log-Msg ("Completed: " + $completedCount + " / Failed: " + $notCompletedCount) "Yellow"
'@

# C. SHORTCUT LAUNCHER
$ShortcutLauncherContent = @'
$DesktopPaths = @(
    [Environment]::GetFolderPath("Desktop"),
    [Environment]::GetFolderPath("CommonDesktopDirectory")
)
Write-Host "Searching Desktops for Stage/Client Shortcuts..."
$Found = 0
foreach ($path in $DesktopPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Filter "*.lnk" | ForEach-Object {
            $n = $_.Name
            # EXCLUDE Application Manager
            if ($n -match "Manager") { return }
            
            # INCLUDE CAD Client, WDA, WDA V2
            if (($n -match "CAD" -and $n -match "Client") -or $n -match "WDA") {
                 Write-Host "   [LAUNCH] $n" -ForegroundColor Green; Start-Process -FilePath $_.FullName -Verb RunAs; $Found++
            }
        }
    }
}
if ($Found -eq 0) { Write-Host "   (No WDA/CAD shortcuts found)" -ForegroundColor DarkGray }
'@

Set-Content -Path (Join-Path $WorkDir "SessionClear.ps1") -Value $SessionClearContent
Set-Content -Path (Join-Path $WorkDir "InstanceVerification.ps1") -Value $VerifyContent
Set-Content -Path (Join-Path $WorkDir "LaunchShortcuts.ps1") -Value $ShortcutLauncherContent
Write-Host "   -> Helper scripts created." -ForegroundColor Green

# ==============================================================================
# 3. MAPPING DATA, SERVICE LIST & CONFIG CHECK
# ==============================================================================
Write-Host "`n[STEP 3] Loading Definitions & Checking Config..." -ForegroundColor Yellow

# --- CHECK UPDATER SETTINGS ---
$ConfigPaths = @(
    (Join-Path $PnxRoot "Server Application Manager\PnxConfigMgr.exe.config"),
    (Join-Path $PnxRoot "Phoenix Server Application Manager\PnxConfigMgr.exe.config")
)

$UpdaterSettingFound = $false
foreach ($cfg in $ConfigPaths) {
    if (Test-Path $cfg) {
        try {
            [xml]$xmlCfg = Get-Content $cfg
            $UpdateUser = $xmlCfg.configuration.appSettings.add | Where-Object { $_.key -eq "UpdateUserName" }
            if ($UpdateUser) {
                Write-Host "   [CONFIG] Updater User: $($UpdateUser.value)" -ForegroundColor Cyan
                $UpdaterSettingFound = $true
            }
        } catch {
            Write-Host "   [WARN] Could not parse $cfg" -ForegroundColor DarkGray
        }
    }
}
if (-not $UpdaterSettingFound) { Write-Host "   [CONFIG] No Updater settings found." -ForegroundColor DarkGray }

$ServiceProductList = @(
    "JobServer", "TraCSServer", "VideoServer", "FingerPrintServer", "EmailWatcher", 
    "CADServer", "CADNLBServer", "CAD2CADTellusServer", "E911Server", "ZetronServer", 
    "ExternalInterface", "GPSServer", "NCICServer", "NCICStateServer", "FTPServer", 
    "LocutionCADVoiceServer", "DeviceNotification", "StreamingNotification", "ReportService", 
    "FolderWatcher", "DocsServer", "PhoenixTonerServer", "PhoenixAlertApp", "PhoenixTExt2Dispatch", 
    "PHOENIXAIWATCHERSERVICE", "PHOENIXJOBSVRV2"
)

$RawMappingData = @'
::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "RMSRootPath" "PoliceRms=%PnxInstallPath%\Police RMS" "FireRms=%PnxInstallPath%\Fire RMS" "JobServer=%PnxInstallPath%\Job Server" "TraCSServer=%PnxInstallPath%\TraCS Server" "VideoServer=%PnxInstallPath%\Video Server" "FingerPrintServer=%PnxInstallPath%\Finger Print Server" "ReportServer=%PnxInstallPath%\Report Server" "ReportService=%PnxInstallPath%\Report Service" "PhoenixWebService=%PnxInstallPath%\WebService" "HazmatGuide=%PnxInstallPath%\User Docs" "FireWebService=%PnxInstallPath%\Fire WebService" "ProvisionManager=%PnxInstallPath%\Provision Manager" "FolderWatcher=%PnxInstallPath%\PnxFolderWatcher" "InternalAffair=%PnxInstallPath%\PhoenixIA" "NIBRS=%PnxInstallPath%\NIBRSInterface" "EmailWatcher=%PnxInstallPath%\Phoenix Email Watcher" "PoliceF1HelpDocs=%PnxInstallPath%\Police RMS\UserDocs" "FireF1HelpDocs=%PnxInstallPath%\Fire RMS\UserDocs" "IAF1HelpDocs=%PnxInstallPath%\PhoenixIA\UserDocs"
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "CADRootPath" "CADServer=%PnxInstallPath%\CAD Server" "CADNLBServer=%PnxInstallPath%\CAD NLB Message Server" "E911Server=%PnxInstallPath%\E911 Server" "GPSServer=%PnxInstallPath%\GPS Server" "ZetronServer=%PnxInstallPath%\CAD Zetron Server" "TonerWIServer=%PnxInstallPath%\Toner WI Server" "ExternalInterface=%PnxInstallPath%\External Interface Server" "NCICServer=%PnxInstallPath%\NCIC Server" "NCICStateServer=%PnxInstallPath%\NCIC State Server" "KGISPDServer=%PnxInstallPath%\KGIS PD WebService" "KGISCentralServer=%PnxInstallPath%\KGIS Central WebService" "LocutionCADVoiceServer=%PnxInstallPath%\Locution CAD Voice Server" "DeviceNotification=%PnxInstallPath%\Phoenix Device Notification" "PnxWDAAppWebService=%PnxInstallPath%\WDA App webservice" "PnxWDAAppWebService=%PnxInstallPath%\Fire Response CAD Webservice" "StreamingNotification=%PnxInstallPath%\Streaming Notification" "PhoenixAlertApp=%PnxInstallPath%\Alert App" "PhoenixTExt2Dispatch=%PnxInstallPath%\Text2Dispatch" "CAD2CADTellusServer=%PnxInstallPath%\CAD2CAD Tellus Server" "ReportWriterAPI=%PnxInstallPath%\Phoenix Report Writer API"
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "OtherRootPath" "CitizenServices=%PnxInstallPath%\Citizen Services Link" "InmateLookup=%PnxInstallPath%\Inmate Lookup" "WIJIS=%PnxInstallPath%\WIJIS" "SWISS=%PnxInstallPath%\SWISS" "CJIN=%PnxInstallPath%\CJIN Integration Service" "NDEX=%PnxInstallPath%\WIJIS NDEX WebService" "FTPServer=%PnxInstallPath%\FTP Server" "CRM=%PnxInstallPath%\CRM" "InmateLocator=%PnxInstallPath%\Inmate Locator" "FireCSPWCF=%PnxInstallPath%\FireCSPhoenixLink" "PoliceCSPWebAPI=%PnxInstallPath%\CitizenServices" "FireCSPWebsite=%PnxInstallPath%\FireCitizenServices" "ADRWebService=%PnxInstallPath%\ADRCollectionRepositoryWS" "WhatsNewWebService=%PnxInstallPath%\WhatsNewWebService" "DocsServer=%PnxInstallPath%\DocsServer" "PhoenixTonerServer=%PnxInstallPath%\Toner Server" "JailCellCheck=%PnxInstallPath%\Jail Cell Check App Service" "ScenePD=%PnxInstallPath%\PhoenixScenePD" "PDFService=%PnxInstallPath%\PhoenixPDFService" "DBUtility=%PnxInstallPath%\Database Utility"
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "StageForClientAppsRootPath" "StageCADClient=%PnxInstallPath%\FTP\CAD Client Stage" "StageWDA=%PnxInstallPath%\FTP\WDA Stage" "StagePrintClient=%PnxInstallPath%\FTP\Print Server Stage" "StageClientAppManager=%PnxInstallPath%\FTP\Client Application Manager Stage" "StageFingerPrintClient=%PnxInstallPath%\FTP\Finger Print Client Stage" "StageIDScannerClient=%PnxInstallPath%\FTP\ID Scanner Stage" "StageStationKIOSKRFIDClient=%PnxInstallPath%\FTP\Station KIOSK RFID Client Stage" "StageRFIDClient=%PnxInstallPath%\FTP\RFID Client Stage" "StageAVLRecorder=%PnxInstallPath%\FTP\AVL Recorder Stage" "StageInOutClient=%PnxInstallPath%\FTP\In Out Client Stage" "StageZetronClient=%PnxInstallPath%\FTP\Zetron Client Stage" "StagePhoenixDashboard=%PnxInstallPath%\FTP\Phoenix Dashboard Stage" "StageMobileInspectionApp=%PnxInstallPath%\FTP\Mobile Inspection App Stage" "PHOENIXJOBSVRV2=%PnxInstallPath%\Job Server V2" "PHOENIXAIWATCHERSERVICE=%PnxInstallPath%\Phoenix AI Watcher" "PNXDIAGRAM=%PnxInstallPath%\PNXDiagram" "PNXDIAGRAMAPI=%PnxInstallPath%\PNXDiagramAPI" "INSPECTIONAPI=%PnxInstallPath%\Phoenix Inspection API" "FIRECSPCONVERSION=%PnxInstallPath%\Fire CSP Conversion" "CAMERASERVER=%PnxInstallPath%\Phoenix Camera Server" "PHOENIXPAWN=%PnxInstallPath%\Phoenix Pawn" "StagePhoenixWDAV2=%PnxInstallPath%\FTP\Phoenix WDA V2 Stage"
"PhoenixHub=%PnxInstallPath%\PhoenixHub" "PaymentGateway=%PnxInstallPath%\Payment Gateway" "Authenticator=%PnxInstallPath%\Phoenix Authenticator" "InterfaceFolderWatcher=%PnxInstallPath%\Phoenix Interface Folder Watcher" "RegionalCAD2CAD=%PnxInstallPath%\Phoenix Regional CAD2CAD Service" "CADLiveStreaming=%PnxInstallPath%\Phoenix CAD Live Streaming Service" "DBUtilityCodeBook=%PnxInstallPath%\Phoenix Database Utility CodeBook" "CRMHubAPI=%PnxInstallPath%\CRMHubAPI" "PhoenixGateway=%PnxInstallPath%\Phoenix Gateway" "CSPProcessQueue=%PnxInstallPath%\CSPProcessQueueService" "CSPConversion=%PnxInstallPath%\CSP Conversion" "AIMugMatch=%PnxInstallPath%\PhoenixAIMugMatch" "AIAPI=%PnxInstallPath%\CRMHubAPI\PNXAIAPI" "ExpenseAPI=%PnxInstallPath%\CRMHubAPI\PNXExpenseAPI" "CustomerAPI=%PnxInstallPath%\CRMHubAPI\PNXCustomerAPI" "EmploymentClient=%PnxInstallPath%\Phoenix Employment Client" "AzureFileDownloader=%PnxInstallPath%\Azure File Downloader"
'@

# PARSE MAPPINGS
$PathToID = @{}
$Matches = [regex]::Matches($RawMappingData, '"([^"]+)=%PnxInstallPath%\\([^"]+)"')
foreach ($match in $Matches) {
    $ID = $match.Groups[1].Value
    $PathSuffix = $match.Groups[2].Value.Trim().Replace("/", "\")
    $PathToID[$PathSuffix] = $ID
    $Leaf = Split-Path $PathSuffix -Leaf
    if (-not $PathToID.ContainsKey($Leaf)) { $PathToID[$Leaf] = $ID }
}
Write-Host "   [MAP] Loaded $($PathToID.Count) product definitions." -ForegroundColor Gray

# ==============================================================================
# 4. SCAN & GENERATE BATCH
# ==============================================================================
# --- NEW PROMPT FOR RMS ---
$RMSMode = Read-Host "`n?? Are you going to run rms application in this or using Minimal downtime? (Y/N)"
$ExcludedIDs = @("PoliceRms", "FireRms", "InternalAffair", "Phoenix IA")
$Logic2IDs = @("PDFService", "ReportWriterAPI", "PhoenixWebService", "StagePhoenixWDAV2")

if ($RMSMode -eq "Y") {
    # IF YES: Add RMS to Logic 2, Clear Exclusions
    $Logic2IDs += @("PoliceRms", "FireRms", "InternalAffair", "Phoenix IA")
    $ExcludedIDs = @() # Empty exclusion list
    Write-Host "   [CONFIG] RMS Mode: INCLUDED in LOGIC 2" -ForegroundColor Green
} else {
    Write-Host "   [CONFIG] RMS Mode: SKIPPED (Minimal Downtime)" -ForegroundColor Yellow
}

Write-Host "`n[STEP 4] Scanning Products..." -ForegroundColor Yellow

# FIND APP REG
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

Write-Host "   [INFO] AppReg: $FoundXML" -ForegroundColor Gray
Write-Host "   [FETCH] Classification Results:" -ForegroundColor Cyan
Write-Host "   ------------------------------------------------------------"

[xml]$xmlData = Get-Content $FoundXML

# Lists for PnxAppMgr
$ListL1 = new-object System.Collections.Generic.List[string]
$ListL2 = new-object System.Collections.Generic.List[string]
$ListL3 = new-object System.Collections.Generic.List[string]
$ListUpd = new-object System.Collections.Generic.List[string]

# Lists for Display (Deduplication)
$DisplayL1 = @()
$DisplayL2 = @()
$DisplayL3 = @()

$ListL1.Add('"INSTALL"'); $ListL2.Add('"INSTALL"'); $ListL3.Add('"INSTALL"'); $ListUpd.Add('"UPDATEINSTANCE"')

# SORT MAP KEYS TO MATCH LONGEST PATH FIRST
$SortedMapKeys = $PathToID.Keys | Sort-Object Length -Descending

if ($xmlData.PhoenixApplications.AppReg) {
    foreach ($app in $xmlData.PhoenixApplications.AppReg) {
        $Name = $app.AppName
        $Ver = $app.CurrentVersion
        $AppPath = $app.AppPath.Replace("/", "\").TrimStart("\")
        
        # FILTER 0.0.0.0
        if ($Ver -eq "0.0.0.0") { continue }
        
        # --- RESOLVE ID ---
        $UseID = $Name # Default
        foreach ($key in $SortedMapKeys) {
            if ($AppPath.EndsWith($key, [System.StringComparison]::OrdinalIgnoreCase)) {
                $UseID = $PathToID[$key]
                break
            }
        }
        
        # --- FORCE OVERRIDE FOR DOCS ---
        if ($Name -match "Fire.*Help.*Doc") { $UseID = "FireF1HelpDocs" }
        if ($Name -match "Police.*Help.*Doc") { $UseID = "PoliceF1HelpDocs" }
        if ($Name -match "IA.*Help.*Doc") { $UseID = "IAF1HelpDocs" }
        
        # DEDUPLICATION CHECK
        if ($ListL1 -contains "`"$UseID`"" -or $ListL2 -contains "`"$UseID`"" -or $ListL3 -contains "`"$UseID`"") { continue }
        
        $LogMsg = "   - Found: $Name -> ID: $UseID"
        
        # --- UPDATE INSTANCE ---
        if ($ServiceProductList -contains $UseID) {
            $ListUpd.Add("`"$UseID`"")
            $LogMsg += " [Update Queued]"
        }
        
        # --- 1. LOGIC 3 (FINAL STEP: HELP DOCS) ---
        if ($UseID -like "*Help*Doc*" -or $UseID -like "*Hazmat*" -or $Name -like "*Help*Doc*" -or $UseID -match "F1HelpDocs") {
            $ListL3.Add("`"$UseID`"")
            $DisplayL3 += $UseID
            Write-Host "$LogMsg -> LOGIC 3 (Final)" -ForegroundColor Cyan
            continue
        }

        # --- 2. EXCLUSION CHECK (Affected by Prompt) ---
        if ($ExcludedIDs -contains $UseID) { 
            Write-Host "$LogMsg -> SKIPPED (Excluded)" -ForegroundColor DarkGray
            continue 
        }

        # --- 3. LOGIC 2 CHECK (SPECIAL APPS + RMS IF PROMPTED) ---
        if ($Logic2IDs -contains $UseID -or $UseID -match "Stage" -or $UseID -like "*Web*Service*") {
            $ListL2.Add("`"$UseID`"")
            $DisplayL2 += $UseID
            Write-Host "$LogMsg -> LOGIC 2 (Special/Stage)" -ForegroundColor Magenta
            continue
        } 
        
        # --- 4. LOGIC 1 (EVERYTHING ELSE) ---
        $ListL1.Add("`"$UseID`"")
        $DisplayL1 += $UseID
        Write-Host "$LogMsg -> LOGIC 1 (General)" -ForegroundColor Green
    }
}
Write-Host "   ------------------------------------------------------------"

# BUILD DISPLAY STRINGS
$StrL1Block = ($DisplayL1 | ForEach-Object { "echo    - $_" }) -join "`r`n"
$StrL2Block = ($DisplayL2 | ForEach-Object { "echo    - $_" }) -join "`r`n"
$StrL3Block = ($DisplayL3 | ForEach-Object { "echo    - $_" }) -join "`r`n"

# BATCH CONTENT
$BatchContent = @"
$InstallDrive
@echo off
REM --- DEEP TRAVERSAL ---
cd ..\..\..\..
cd "$AppMgrFolder"

SET AppMgrExePath="$AppMgrFolder"
SET PSExe=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
set LOGFILE="%WorkDir%\Update_Log.txt"
echo [LOG] Started Production Update... > %LOGFILE%

:: ===================================================
:: LOGIC 1: GENERAL APPS (Services UP)
:: ===================================================
echo.
echo ---------------------------------------------------
echo  READY: LOGIC 1 (GENERAL APPS)
echo ---------------------------------------------------
echo  The following products will be installed:
$StrL1Block
echo.
echo  (Services: KEEP RUNNING)
echo ---------------------------------------------------
:AskL1
SET /P "StartL1=>> Start Logic 1 Install now? (Y/N): "
IF /I "%StartL1%" NEQ "Y" GOTO AskL1

echo [LOGIC 1] Installing General Apps...
%AppMgrExePath%\PnxAppMgr.exe $($ListL1 -join " ") | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }"

:: ===================================================
:: LOGIC 2: SPECIAL APPS (Maintenance Mode)
:: ===================================================
echo.
echo ---------------------------------------------------
echo  READY: LOGIC 2 (SPECIAL / STAGE APPS)
echo ---------------------------------------------------
echo  The following products will be installed:
$StrL2Block
echo.
echo  WARNING: This will STOP SERVICES -> INSTALL -> RESTART
echo ---------------------------------------------------
:AskL2
SET /P "StartL2=>> Start Maintenance (Stop Services) now? (Y/N): "
IF /I "%StartL2%" NEQ "Y" GOTO AskL2

echo [MAINTENANCE] Stopping Services...
%windir%\System32\iisreset.exe /stop
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name `$_.Name -Force }"

echo [CLEANUP] Clearing Session Data (ONLY)...
%PSExe% -ExecutionPolicy Bypass -File "$WorkDir\SessionClear.ps1"

echo [LOGIC 2] Installing Special Apps...
%AppMgrExePath%\PnxAppMgr.exe $($ListL2 -join " ") | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }"

echo [UPDATE] Starting IIS for Update...
%windir%\System32\iisreset.exe /start
timeout /t 5 >nul

echo [UPDATE] Updating Instances...
%AppMgrExePath%\PnxAppMgr.exe $($ListUpd -join " ") | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }"

echo [START] Starting Services...
timeout /t 5 >nul
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -ne 'Running' } | ForEach-Object { Start-Service -Name `$_.Name }"

echo [STATUS] Checking Live Status...
%AppMgrExePath%\PnxAppMgr.exe "SHOWINSTANCES" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }"

echo [VERIFY] Verifying DLLs...
%PSExe% -ExecutionPolicy Bypass -File "$WorkDir\InstanceVerification.ps1"

echo [CLIENTS] Launching Stage/Client Shortcuts...
%PSExe% -ExecutionPolicy Bypass -File "$WorkDir\LaunchShortcuts.ps1"

:: ===================================================
:: LOGIC 3: FINAL APPS (HELPDOCS / HAZMAT)
:: ===================================================
echo.
echo ---------------------------------------------------
echo  READY: FINAL STEP (HELPDOCS / HAZMAT)
echo ---------------------------------------------------
echo  The following products will be installed:
$StrL3Block
echo.
echo  (Services: RUNNING)
echo ---------------------------------------------------
:AskFinal
SET /P "StartFinal=>> Install HelpDocs/Hazmat now? (Y/N): "
IF /I "%StartFinal%" NEQ "Y" GOTO AskFinal

echo [LOGIC 3] Installing HelpDocs and Hazmat...
%AppMgrExePath%\PnxAppMgr.exe $($ListL3 -join " ") | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }"

echo.
echo ===================================================
echo  UPDATE PROCESS COMPLETE.
echo ===================================================
echo  Check Log: %LOGFILE%
pause
:End
"@

$FinalBat = Join-Path $WorkDir "Production_Update.bat"
Set-Content -Path $FinalBat -Value $BatchContent -Encoding ASCII
Write-Host "   -> Batch File Created: $FinalBat" -ForegroundColor Green

Write-Host "`n[STEP 4] Execute Update?" -ForegroundColor Yellow
$run2 = Read-Host "   Type Y to run the Batch File now"
if ($run2 -eq "Y") { Start-Process $FinalBat -Verb RunAs }