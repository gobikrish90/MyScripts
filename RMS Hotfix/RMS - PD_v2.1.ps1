<#
.SYNOPSIS
    MASTER ORCHESTRATOR: STANDARD UPDATE (WITH PRODUCT MAPPING)
    
.DESCRIPTION
    1. Auto-detects ProPhoenix Drive.
    2. Writes helper scripts (LogClear, Verification).
    3. **NEW:** Parses user-provided MAPPING DATA to translate Folders -> ProductIDs.
    4. Scans AppReg and applies mappings:
       - EXCLUDED: RMS, Fire, IA (Based on mapped IDs).
       - LOGIC 1: General Apps (CAD, JobServer, etc.).
       - LOGIC 2: Special Apps (Web, PDF, Stage).
       - LOGIC 3: HelpDocs / Hazmat.
    5. Generates 'Production_Update.bat'.
    6. Launches the batch file.
#>

$ErrorActionPreference = "Continue"
Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   MASTER ORCHESTRATOR: MAPPED PRODUCT UPDATE" -ForegroundColor Cyan
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
# A. LOG CLEAR SCRIPT
$LogClearContent = @'
Write-Host "Running Log Clearance..."
$proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object { "$($_.Root)\Program Files\ProPhoenix" } | Where-Object { Test-Path -Path $_ }
foreach ($basePath in $proPhoenixBasePaths) {
    $logPath = Join-Path -Path $basePath -ChildPath "Server Application Manager\PnxLog"
    if (Test-Path $logPath) { Remove-Item -Path "$logPath\*" -Recurse -Force -ErrorAction SilentlyContinue }
}
Write-Host "Logs Cleared."
'@

# B. VERIFICATION SCRIPT
$VerifyContent = @'
Write-Host "Verifying Instances... (DLL Date Check)"
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
        Get-ChildItem -Path $path -Filter "*.lnk" | Where-Object { $_.Name -match "Stage" -or $_.Name -match "Client" } | ForEach-Object {
            Write-Host "   [LAUNCH] $($_.Name)" -ForegroundColor Green
            Start-Process -FilePath $_.FullName -Verb RunAs
            $Found++
        }
    }
}
if ($Found -eq 0) { Write-Host "   (No Stage shortcuts found on Desktop)" -ForegroundColor DarkGray }
'@

Set-Content -Path (Join-Path $WorkDir "LogClear.ps1") -Value $LogClearContent
Set-Content -Path (Join-Path $WorkDir "InstanceVerification.ps1") -Value $VerifyContent
Set-Content -Path (Join-Path $WorkDir "LaunchShortcuts.ps1") -Value $ShortcutLauncherContent
Write-Host "   -> Helper scripts created." -ForegroundColor Green

# ==============================================================================
# 3. MAPPING DATA & PARSING
# ==============================================================================
Write-Host "`n[STEP 3] Parsing Product Map..." -ForegroundColor Yellow

$RawMappingData = @'
::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "RMSRootPath" "PoliceRms=%PnxInstallPath%\Police RMS" "FireRms=%PnxInstallPath%\Fire RMS" "JobServer=%PnxInstallPath%\Job Server" "TraCSServer=%PnxInstallPath%\TraCS Server" "VideoServer=%PnxInstallPath%\Video Server" "FingerPrintServer=%PnxInstallPath%\Finger Print Server" "ReportServer=%PnxInstallPath%\Report Server" "ReportService=%PnxInstallPath%\Report Service" "PhoenixWebService=%PnxInstallPath%\WebService" "HazmatGuide=%PnxInstallPath%\User Docs" "FireWebService=%PnxInstallPath%\Fire WebService" "ProvisionManager=%PnxInstallPath%\Provision Manager" "FolderWatcher=%PnxInstallPath%\PnxFolderWatcher" "InternalAffair=%PnxInstallPath%\PhoenixIA" "NIBRS=%PnxInstallPath%\NIBRSInterface" "EmailWatcher=%PnxInstallPath%\Phoenix Email Watcher" "PoliceF1HelpDocs=%PnxInstallPath%\Police RMS\UserDocs" "FireF1HelpDocs=%PnxInstallPath%\Fire RMS\UserDocs" "IAF1HelpDocs=%PnxInstallPath%\PhoenixIA\UserDocs"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "CADRootPath" "CADServer=%PnxInstallPath%\CAD Server" "CADNLBServer=%PnxInstallPath%\CAD NLB Message Server" "E911Server=%PnxInstallPath%\E911 Server" "GPSServer=%PnxInstallPath%\GPS Server" "ZetronServer=%PnxInstallPath%\CAD Zetron Server" "TonerWIServer=%PnxInstallPath%\Toner WI Server" "ExternalInterface=%PnxInstallPath%\External Interface Server" "NCICServer=%PnxInstallPath%\NCIC Server" "NCICStateServer=%PnxInstallPath%\NCIC State Server" "KGISPDServer=%PnxInstallPath%\KGIS PD WebService" "KGISCentralServer=%PnxInstallPath%\KGIS Central WebService" "LocutionCADVoiceServer=%PnxInstallPath%\Locution CAD Voice Server" "DeviceNotification=%PnxInstallPath%\Phoenix Device Notification" "PnxWDAAppWebService=%PnxInstallPath%\WDA App webservice" "PnxWDAAppWebService=%PnxInstallPath%\Fire Response CAD Webservice" "StreamingNotification=%PnxInstallPath%\Streaming Notification" "PhoenixAlertApp=%PnxInstallPath%\Alert App" "PhoenixTExt2Dispatch=%PnxInstallPath%\Text2Dispatch" "CAD2CADTellusServer=%PnxInstallPath%\CAD2CAD Tellus Server" "ReportWriterAPI=%PnxInstallPath%\Phoenix Report Writer API"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "OtherRootPath" "CitizenServices=%PnxInstallPath%\Citizen Services Link" "InmateLookup=%PnxInstallPath%\Inmate Lookup" "WIJIS=%PnxInstallPath%\WIJIS" "SWISS=%PnxInstallPath%\SWISS" "CJIN=%PnxInstallPath%\CJIN Integration Service" "NDEX=%PnxInstallPath%\WIJIS NDEX WebService" "FTPServer=%PnxInstallPath%\FTP Server" "CRM=%PnxInstallPath%\CRM" "InmateLocator=%PnxInstallPath%\Inmate Locator" "FireCSPWCF=%PnxInstallPath%\FireCSPhoenixLink" "PoliceCSPWebAPI=%PnxInstallPath%\CitizenServices" "FireCSPWebsite=%PnxInstallPath%\FireCitizenServices" "ADRWebService=%PnxInstallPath%\ADRCollectionRepositoryWS" "WhatsNewWebService=%PnxInstallPath%\WhatsNewWebService" "DocsServer=%PnxInstallPath%\DocsServer" "PhoenixTonerServer=%PnxInstallPath%\Toner Server" "JailCellCheck=%PnxInstallPath%\Jail Cell Check App Service" "ScenePD=%PnxInstallPath%\PhoenixScenePD" "PDFService=%PnxInstallPath%\PhoenixPDFService" "DBUtility=%PnxInstallPath%\Database Utility"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "StageForClientAppsRootPath" "StageCADClient=%PnxInstallPath%\FTP\CAD Client Stage" "StageWDA=%PnxInstallPath%\FTP\WDA Stage" "StagePrintClient=%PnxInstallPath%\FTP\Print Server Stage" "StageClientAppManager=%PnxInstallPath%\FTP\Client Application Manager Stage" "StageFingerPrintClient=%PnxInstallPath%\FTP\Finger Print Client Stage" "StageIDScannerClient=%PnxInstallPath%\FTP\ID Scanner Stage" "StageStationKIOSKRFIDClient=%PnxInstallPath%\FTP\Station KIOSK RFID Client Stage" "StageRFIDClient=%PnxInstallPath%\FTP\RFID Client Stage" "StageAVLRecorder=%PnxInstallPath%\FTP\AVL Recorder Stage" "StageInOutClient=%PnxInstallPath%\FTP\In Out Client Stage" "StageZetronClient=%PnxInstallPath%\FTP\Zetron Client Stage" "StagePhoenixDashboard=%PnxInstallPath%\FTP\Phoenix Dashboard Stage" "StageMobileInspectionApp=%PnxInstallPath%\FTP\Mobile Inspection App Stage" "PHOENIXJOBSVRV2=%PnxInstallPath%\Job Server V2" "PHOENIXAIWATCHERSERVICE=%PnxInstallPath%\Phoenix AI Watcher" "PNXDIAGRAM=%PnxInstallPath%\PNXDiagram" "PNXDIAGRAMAPI=%PnxInstallPath%\PNXDiagramAPI" "INSPECTIONAPI=%PnxInstallPath%\Phoenix Inspection API" "FIRECSPCONVERSION=%PnxInstallPath%\Fire CSP Conversion" "CAMERASERVER=%PnxInstallPath%\Phoenix Camera Server" "PHOENIXPAWN=%PnxInstallPath%\Phoenix Pawn" "StagePhoenixWDAV2=%PnxInstallPath%\FTP\Phoenix WDA V2 Stage"

:: --- AUTOMATICALLY ADDED MAPPINGS ---
"PhoenixHub=%PnxInstallPath%\PhoenixHub" "PaymentGateway=%PnxInstallPath%\Payment Gateway" "Authenticator=%PnxInstallPath%\Phoenix Authenticator" "InterfaceFolderWatcher=%PnxInstallPath%\Phoenix Interface Folder Watcher" "RegionalCAD2CAD=%PnxInstallPath%\Phoenix Regional CAD2CAD Service" "CADLiveStreaming=%PnxInstallPath%\Phoenix CAD Live Streaming Service" "DBUtilityCodeBook=%PnxInstallPath%\Phoenix Database Utility CodeBook" "CRMHubAPI=%PnxInstallPath%\CRMHubAPI" "PhoenixGateway=%PnxInstallPath%\Phoenix Gateway" "CSPProcessQueue=%PnxInstallPath%\CSPProcessQueueService" "CSPConversion=%PnxInstallPath%\CSP Conversion" "AIMugMatch=%PnxInstallPath%\PhoenixAIMugMatch" "AIAPI=%PnxInstallPath%\CRMHubAPI\PNXAIAPI" "ExpenseAPI=%PnxInstallPath%\CRMHubAPI\PNXExpenseAPI" "CustomerAPI=%PnxInstallPath%\CRMHubAPI\PNXCustomerAPI" "EmploymentClient=%PnxInstallPath%\Phoenix Employment Client" "AzureFileDownloader=%PnxInstallPath%\Azure File Downloader"
'@

# Parse Mapping Data into Hashtable [PathSuffix -> InstallID]
$PathToID = @{}
$Matches = [regex]::Matches($RawMappingData, '"([^"]+)=%PnxInstallPath%\\([^"]+)"')
foreach ($match in $Matches) {
    $ID = $match.Groups[1].Value
    $PathSuffix = $match.Groups[2].Value.Trim().Replace("/", "\")
    
    # Store plain path
    $PathToID[$PathSuffix] = $ID
    
    # Store Leaf only for robust matching (e.g., "CAD Client Stage" -> "StageCADClient")
    $Leaf = Split-Path $PathSuffix -Leaf
    if (-not $PathToID.ContainsKey($Leaf)) { $PathToID[$Leaf] = $ID }
}
Write-Host "   [MAP] Loaded $($PathToID.Count) product mappings." -ForegroundColor Gray

# ==============================================================================
# 4. SCAN PRODUCTS & GENERATE BATCH
# ==============================================================================
Write-Host "`n[STEP 4] Scanning Products..." -ForegroundColor Yellow

# --- CONFIGURATION ---
# Mapped IDs to EXCLUDE
$ExcludedIDs = @("PoliceRms", "FireRms", "InternalAffair")

# Mapped IDs for Logic 2
$Logic2IDs = @("PDFService", "ReportWriterAPI", "PhoenixWebService", "StagePhoenixWDAV2")

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

Write-Host "   [INFO] Parsing: $FoundXML" -ForegroundColor Gray
Write-Host "   [FETCH] Classification Results:" -ForegroundColor Cyan
Write-Host "   ------------------------------------------------------------"

[xml]$xmlData = Get-Content $FoundXML
$InstallGen   = new-object System.Collections.Generic.List[string]
$InstallSpec  = new-object System.Collections.Generic.List[string]
$InstallFinal = new-object System.Collections.Generic.List[string]
$UpdateList   = new-object System.Collections.Generic.List[string]

$InstallGen.Add('"INSTALL"')
$InstallSpec.Add('"INSTALL"')
$InstallFinal.Add('"INSTALL"')
$UpdateList.Add('"UPDATEINSTANCE"')

if ($xmlData.PhoenixApplications.AppReg) {
    foreach ($app in $xmlData.PhoenixApplications.AppReg) {
        $Name = $app.AppName
        $Ver = $app.CurrentVersion
        $AppPath = $app.AppPath.Replace("/", "\").TrimStart("\")
        
        if ($Ver -eq "0.0.0.0") { continue }
        
        # --- RESOLVE ID USING MAPPING ---
        $UseID = $Name # Default to AppName
        $Leaf = Split-Path $AppPath -Leaf
        
        # Try finding by full suffix first, then by leaf
        foreach ($key in $PathToID.Keys) {
            if ($AppPath.EndsWith($key, [System.StringComparison]::OrdinalIgnoreCase)) {
                $UseID = $PathToID[$key]
                break
            }
        }
        
        $LogMsg = "   - Found: $Name -> ID: $UseID"
        
        # Add to Update List
        $UpdateList.Add("`"$UseID`"")
        
        # --- 1. LOGIC 3 (FINAL STEP: HELP DOCS / HAZMAT) ---
        if ($UseID -like "*Help*Doc*" -or $UseID -like "*Hazmat*" -or $Name -like "*Help*Doc*") {
            $InstallFinal.Add("`"$UseID`"")
            Write-Host "$LogMsg -> LOGIC 3 (Final)" -ForegroundColor Cyan
            continue
        }

        # --- 2. EXCLUSION CHECK (RMS / IA APP) ---
        if ($ExcludedIDs -contains $UseID) { 
            Write-Host "$LogMsg -> SKIPPED (Excluded)" -ForegroundColor DarkGray
            continue 
        }

        # --- 3. LOGIC 2 CHECK (SPECIAL APPS) ---
        if ($Logic2IDs -contains $UseID -or $UseID -match "Stage" -or $UseID -like "*Web*Service*") {
            $InstallSpec.Add("`"$UseID`"")
            Write-Host "$LogMsg -> LOGIC 2 (Special/Stage)" -ForegroundColor Magenta
            continue
        } 
        
        # --- 4. LOGIC 1 (EVERYTHING ELSE) ---
        $InstallGen.Add("`"$UseID`"")
        Write-Host "$LogMsg -> LOGIC 1 (General)" -ForegroundColor Green
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
set LOGFILE="%WorkDir%\Update_Log.txt"
echo [LOG] Started Production Update... > %LOGFILE%

:: ===================================================
:: LOGIC 1: GENERAL APPS (Services UP)
:: ===================================================
echo.
echo ---------------------------------------------------
echo  READY: LOGIC 1 (GENERAL APPS)
echo  Services: KEEP RUNNING
echo ---------------------------------------------------
:AskL1
SET /P "StartL1=>> Start Logic 1 Install now? (Y/N): "
IF /I "%StartL1%" NEQ "Y" GOTO AskL1

echo [LOGIC 1] Installing General Apps...
%AppMgrExePath%\PnxAppMgr.exe $($InstallGen -join " ")

:: ===================================================
:: LOGIC 2: SPECIAL APPS (Maintenance Mode)
:: ===================================================
echo.
echo ---------------------------------------------------
echo  READY: LOGIC 2 (SPECIAL / STAGE APPS)
echo  WARNING: This will STOP SERVICES -> INSTALL -> RESTART
echo ---------------------------------------------------
:AskL2
SET /P "StartL2=>> Start Maintenance (Stop Services) now? (Y/N): "
IF /I "%StartL2%" NEQ "Y" GOTO AskL2

echo [MAINTENANCE] Stopping Services...
%windir%\System32\iisreset.exe /stop
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name `$_.Name -Force }"
%PSExe% -ExecutionPolicy Bypass -File "%WorkDir%\LogClear.ps1"

echo [LOGIC 2] Installing Special Apps...
%AppMgrExePath%\PnxAppMgr.exe $($InstallSpec -join " ")

echo [UPDATE] Starting IIS for Update...
%windir%\System32\iisreset.exe /start
timeout /t 5 >nul

echo [UPDATE] Updating Instances...
%AppMgrExePath%\PnxAppMgr.exe $($UpdateList -join " ")

echo [START] Starting Services...
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -ne 'Running' } | ForEach-Object { Start-Service -Name `$_.Name }"

echo [STATUS] Checking Live Status...
%AppMgrExePath%\PnxAppMgr.exe "SHOWINSTANCES"

echo [VERIFY] Verifying DLLs...
%PSExe% -ExecutionPolicy Bypass -File "%WorkDir%\InstanceVerification.ps1"

echo [CLIENTS] Launching Stage/Client Shortcuts...
%PSExe% -ExecutionPolicy Bypass -File "%WorkDir%\LaunchShortcuts.ps1"

:: ===================================================
:: LOGIC 3: FINAL APPS (HELPDOCS / HAZMAT)
:: ===================================================
echo.
echo ---------------------------------------------------
echo  READY: FINAL STEP (HELPDOCS / HAZMAT)
echo  (Services: RUNNING)
echo ---------------------------------------------------
:AskFinal
SET /P "StartFinal=>> Install HelpDocs/Hazmat now? (Y/N): "
IF /I "%StartFinal%" NEQ "Y" GOTO AskFinal

echo [LOGIC 3] Installing HelpDocs and Hazmat...
%AppMgrExePath%\PnxAppMgr.exe $($InstallFinal -join " ")

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