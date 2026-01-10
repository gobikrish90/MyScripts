<#
.SYNOPSIS
    ProPhoenix Master Automation Controller
    Author: Gemini / User
    Description: Self-installing tool that deploys and manages 4 ProPhoenix automation scripts.
#>

# ==============================================================================
#  INITIALIZATION & ADMIN CHECK
# ==============================================================================
$ErrorActionPreference = "SilentlyContinue"

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease right-click and select 'Run as Administrator'."
    Start-Sleep -Seconds 5
    Break
}

# ==============================================================================
#  ENVIRONMENT SETUP (AUTO-CREATE FOLDERS)
# ==============================================================================
$ToolRoot = "C:\ProPhoenix_AutoTool"
$ScriptDir = Join-Path -Path $ToolRoot -ChildPath "Scripts"
$LogDir    = Join-Path -Path $ToolRoot -ChildPath "Logs"

# Create Directories if they don't exist
if (!(Test-Path $ToolRoot)) { New-Item -ItemType Directory -Force -Path $ToolRoot | Out-Null }
if (!(Test-Path $ScriptDir)) { New-Item -ItemType Directory -Force -Path $ScriptDir | Out-Null }
if (!(Test-Path $LogDir))    { New-Item -ItemType Directory -Force -Path $LogDir | Out-Null }

# Define Script Paths
$File_HotfixProd  = Join-Path $ScriptDir "Cad_Hotfixupdate_v2.0.ps1"
$File_DBSync      = Join-Path $ScriptDir "Autodbsync2.0.ps1"
$File_PreComp     = Join-Path $ScriptDir "Autoprecompilerurlconfig1.6.ps1"
$File_HotfixInst  = Join-Path $ScriptDir "Autodefinedproducts_Vers3.1.ps1"

# ==============================================================================
#  EMBEDDED SCRIPTS (WRITING YOUR CODE TO FILES)
# ==============================================================================
Write-Host "Verifying Script Environment..." -ForegroundColor Cyan

# --- 1. HOTFIX PRODUCTION ---
$Content_HotfixProd = @'
<#
.SYNOPSIS
    ProPhoenix Hotfix Automation (Production / Installation Team).
#>
# ==============================================================================
#  1. INTERACTIVE PROMPT
# ==============================================================================
Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   ProPhoenix Hotfix Automation v2.0 (PRODUCTION)  " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

$TargetServer = Read-Host "Enter Target Server Name (Press ENTER for Localhost)"

if ([string]::IsNullOrWhiteSpace($TargetServer)) {
    $TargetServer = "localhost"
    $RunRemote = $false
    Write-Host "-> Selected Mode: LOCAL EXECUTION" -ForegroundColor Green
} else {
    $RunRemote = $true
    Write-Host "-> Selected Mode: REMOTE EXECUTION on $TargetServer" -ForegroundColor Yellow
}
Write-Host "==============================================" -ForegroundColor Cyan

# ==============================================================================
#  2. CORE LOGIC BLOCK
# ==============================================================================
$GeneratorLogic = {
    $ErrorActionPreference = "Continue"
    $CurrentHostName = $env:COMPUTERNAME

    # --- DEFINITIONS: HELPER SCRIPTS ---
    
    # 1. CLEANUP SCRIPT
    $LogClearScriptContent = @"
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
Write-Host "========================================="
Write-Host "      CLEANUP UTILITY (Logs & Session)   "
Write-Host "========================================="

`$proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    "`$(`$_.Root)\Program Files\ProPhoenix"
} | Where-Object { Test-Path -Path `$_ }

if (`$proPhoenixBasePaths.Count -eq 0) { Write-Host "[WARN] No ProPhoenix Root found."; exit }

Write-Host "[INFO] Scanning for Log Files..."

foreach (`$basePath in `$proPhoenixBasePaths) {
    `$instanceRoots = Get-ChildItem -Path `$basePath -Directory -Recurse -ErrorAction SilentlyContinue | Where-Object { `$_.Name -eq "_Instances" }
    
    foreach (`$instRoot in `$instanceRoots) {
        `$environments = Get-ChildItem -Path `$instRoot.FullName -Directory -ErrorAction SilentlyContinue
        
        foreach (`$env in `$environments) {
            `$logPath = Join-Path -Path `$env.FullName -ChildPath "PnxLog"
            
            if (Test-Path `$logPath) {
                Write-Host "------------------------------------------------"
                Write-Host " INSTANCE: `$(`$env.Name)"
                Write-Host " LOCATION: `$logPath"
                Write-Host "------------------------------------------------"
                
                `$oldPath = Join-Path -Path `$logPath -ChildPath "old"
                if (!(Test-Path `$oldPath)) { New-Item -ItemType Directory -Path `$oldPath -Force | Out-Null }
                
                # 1. Clear 'old' folder
                Get-ChildItem -Path `$oldPath -File -ErrorAction SilentlyContinue | ForEach-Object {
                    try { 
                        Remove-Item -Path `$_.FullName -Force -ErrorAction Stop
                    } catch { } 
                }

                # 2. Move current logs
                `$movedCount = 0
                Get-ChildItem -Path `$logPath -File -ErrorAction SilentlyContinue | Where-Object { `$_.FullName -notlike "*\old*" } | ForEach-Object {
                    try {
                        Move-Item -LiteralPath `$_.FullName -Destination `$oldPath -Force -ErrorAction Stop
                        Write-Host "   [MOVED] `$(`$_.Name) -> old"
                        `$movedCount++
                    } catch {
                        Write-Host "   [LOCKED] `$(`$_.Name) (Skipped)" -ForegroundColor DarkGray
                    }
                }
                if (`$movedCount -eq 0) { Write-Host "   (No logs to move)" }
            }
        }
    }
}

Write-Host "`n[INFO] Clearing SvrSessionData..."
foreach (`$basePath in `$proPhoenixBasePaths) {
    `$cadServerPath = Join-Path -Path `$basePath -ChildPath "CAD Server\_Instances"
    if (Test-Path `$cadServerPath) {
        `$cadInstances = Get-ChildItem -Path `$cadServerPath -Directory -ErrorAction SilentlyContinue
        foreach (`$inst in `$cadInstances) {
            `$sessionDataPath = Join-Path -Path `$inst.FullName -ChildPath "SvrSessionData"
            if (Test-Path `$sessionDataPath) {
                Write-Host "------------------------------------------------"
                Write-Host " SESSION DATA: `$(`$inst.Name)"
                Write-Host " LOCATION:     `$sessionDataPath"
                Write-Host "------------------------------------------------"
                
                `$delCount = 0
                Get-ChildItem -Path `$sessionDataPath -File -ErrorAction SilentlyContinue | ForEach-Object { 
                    try { 
                        Remove-Item -Path `$_.FullName -Force -ErrorAction Stop
                        Write-Host "   [DELETED] `$(`$_.Name)"
                        `$delCount++
                    } catch {
                        Write-Host "   [LOCKED] `$(`$_.Name)" -ForegroundColor DarkGray
                    }
                }
                if (`$delCount -eq 0) { Write-Host "   (No session files found)" }
            }
        }
    }
}
Write-Host "[SUCCESS] Cleanup Complete."
"@

    # 2. VERIFICATION SCRIPT (Output Only)
    $VerificationScriptContent = @"
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII

function Log-Msg {
    param([string]`$Msg, [ConsoleColor]`$Color = "White")
    Write-Host `$Msg -ForegroundColor `$Color
}

Log-Msg "[INFO] Starting DLL verification..." "Cyan"

`$prophoenixPaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object { "`$(`$_.Root)Program Files\ProPhoenix" } | Where-Object { Test-Path `$_ }
`$excludedFolders = @("Finger Print Client","ID Scanner","Phoenix WDA V2","Police RMS","PoliceRMS","Print Server","WDA")
`$completedCount = 0; `$notCompletedCount = 0;

foreach (`$basePath in `$prophoenixPaths) {
    Log-Msg "`n[SCAN] `$basePath" "Yellow"
    `$appFolders = Get-ChildItem -Path `$basePath -Directory -ErrorAction SilentlyContinue | Where-Object { `$excludedFolders -notcontains `$_.Name }
    foreach (`$app in `$appFolders) {
        `$instancesPath = Join-Path `$app.FullName "_Instances"
        if (Test-Path `$instancesPath) {
            `$instanceEnvs = Get-ChildItem -Path `$instancesPath -Directory
            foreach (`$env in `$instanceEnvs) {
                `$baseDlls = Get-ChildItem -Path `$app.FullName -Filter *.dll -File
                `$instanceDlls = Get-ChildItem -Path `$env.FullName -Filter *.dll -File
                `$status = "Completed"
                
                foreach (`$dll in `$baseDlls) {
                    `$match = `$instanceDlls | Where-Object { `$_.Name -eq `$dll.Name }
                    if (`$match) {
                        # Exact size/date check
                        if ((`$match.LastWriteTime -lt `$dll.LastWriteTime) -or (`$match.Length -ne `$dll.Length)) { 
                            `$status = "Not Completed"
                            break 
                        }
                    } else { 
                        `$status = "Not Completed"
                        break 
                    }
                }
                
                if (`$status -eq "Completed") { 
                    `$completedCount++
                    Log-Msg "[OK] `$(`$app.Name) -> `$(`$env.Name)" "Green" 
                } else { 
                    `$notCompletedCount++
                    Log-Msg "[FAIL] `$(`$app.Name) -> `$(`$env.Name) (DLL Mismatch)" "Red" 
                }
            }
        }
    }
}
Log-Msg "`n--------------------------------------" "White"
Log-Msg ("Total Verified : " + (`$completedCount + `$notCompletedCount)) "White"
Log-Msg ("Completed      : " + `$completedCount) "Green"
Log-Msg ("Not Completed  : " + `$notCompletedCount) "Red"
Log-Msg "--------------------------------------" "White"
"@

    # --- CONFIGURATION ---
    $ClientAppsDef = @{
        "CAD Client"      = "KPI.Phoenix.CADClient.exe"
        "WDA"             = "KPI.Phoenix.CADMobileClient.exe"
        "Phoenix WDA V2" = "Phoenix.WDAV2.Client.Shell.exe"
    }

    $ServiceProductList = @(
        "JobServer", "TraCSServer", "VideoServer", "FingerPrintServer", "EmailWatcher", 
        "CADServer", "CADNLBServer", "CAD2CADTellusServer", "E911Server", "ZetronServer", 
        "ExternalInterface", "GPSServer", "NCICServer", "NCICStateServer", "FTPServer", 
        "LocutionCADVoiceServer", "DeviceNotification", "StreamingNotification", "ReportService", 
        "FolderWatcher", "DocsServer", "PhoenixTonerServer", "PhoenixAlertApp", "PhoenixTExt2Dispatch", 
        "PHOENIXAIWATCHERSERVICE", "PHOENIXJOBSVRV2"
    )

# UPDATED MAPPING DATA (FROM USER)
$RawMappingData = @"
::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "RMSRootPath" "PoliceRms=%PnxInstallPath%\Police RMS" "FireRms=%PnxInstallPath%\Fire RMS" "JobServer=%PnxInstallPath%\Job Server" "TraCSServer=%PnxInstallPath%\TraCS Server" "VideoServer=%PnxInstallPath%\Video Server" "FingerPrintServer=%PnxInstallPath%\Finger Print Server" "ReportServer=%PnxInstallPath%\Report Server" "ReportService=%PnxInstallPath%\Report Service" "PhoenixWebService=%PnxInstallPath%\WebService" "HazmatGuide=%PnxInstallPath%\User Docs" "FireWebService=%PnxInstallPath%\Fire WebService" "ProvisionManager=%PnxInstallPath%\Provision Manager" "FolderWatcher=%PnxInstallPath%\PnxFolderWatcher" "InternalAffair=%PnxInstallPath%\PhoenixIA" "NIBRS=%PnxInstallPath%\NIBRSInterface" "EmailWatcher=%PnxInstallPath%\Phoenix Email Watcher" "PoliceF1HelpDocs=%PnxInstallPath%\Police RMS\UserDocs" "FireF1HelpDocs=%PnxInstallPath%\Fire RMS\UserDocs" "IAF1HelpDocs=%PnxInstallPath%\PhoenixIA\UserDocs"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "CADRootPath" "CADServer=%PnxInstallPath%\CAD Server" "CADNLBServer=%PnxInstallPath%\CAD NLB Message Server" "E911Server=%PnxInstallPath%\E911 Server" "GPSServer=%PnxInstallPath%\GPS Server" "ZetronServer=%PnxInstallPath%\CAD Zetron Server" "TonerWIServer=%PnxInstallPath%\Toner WI Server" "ExternalInterface=%PnxInstallPath%\External Interface Server" "NCICServer=%PnxInstallPath%\NCIC Server" "NCICStateServer=%PnxInstallPath%\NCIC State Server" "KGISPDServer=%PnxInstallPath%\KGIS PD WebService" "KGISCentralServer=%PnxInstallPath%\KGIS Central WebService" "LocutionCADVoiceServer=%PnxInstallPath%\Locution CAD Voice Server" "DeviceNotification=%PnxInstallPath%\Phoenix Device Notification" "PnxWDAAppWebService=%PnxInstallPath%\WDA App webservice" "PnxWDAAppWebService=%PnxInstallPath%\Fire Response CAD Webservice" "StreamingNotification=%PnxInstallPath%\Streaming Notification" "PhoenixAlertApp=%PnxInstallPath%\Alert App" "PhoenixTExt2Dispatch=%PnxInstallPath%\Text2Dispatch" "CAD2CADTellusServer=%PnxInstallPath%\CAD2CAD Tellus Server" "ReportWriterAPI=%PnxInstallPath%\Phoenix Report Writer API"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "OtherRootPath" "CitizenServices=%PnxInstallPath%\Citizen Services Link" "InmateLookup=%PnxInstallPath%\Inmate Lookup" "WIJIS=%PnxInstallPath%\WIJIS" "SWISS=%PnxInstallPath%\SWISS" "CJIN=%PnxInstallPath%\CJIN Integration Service" "NDEX=%PnxInstallPath%\WIJIS NDEX WebService" "FTPServer=%PnxInstallPath%\FTP Server" "CRM=%PnxInstallPath%\CRM" "InmateLocator=%PnxInstallPath%\Inmate Locator" "FireCSPWCF=%PnxInstallPath%\FireCSPhoenixLink" "PoliceCSPWebAPI=%PnxInstallPath%\CitizenServices" "FireCSPWebsite=%PnxInstallPath%\FireCitizenServices" "ADRWebService=%PnxInstallPath%\ADRCollectionRepositoryWS" "WhatsNewWebService=%PnxInstallPath%\WhatsNewWebService" "DocsServer=%PnxInstallPath%\DocsServer" "PhoenixTonerServer=%PnxInstallPath%\Toner Server" "JailCellCheck=%PnxInstallPath%\Jail Cell Check App Service" "ScenePD=%PnxInstallPath%\PhoenixScenePD" "PDFService=%PnxInstallPath%\PhoenixPDFService" "DBUtility=%PnxInstallPath%\Database Utility"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "StageForClientAppsRootPath" "StageCADClient=%PnxInstallPath%\FTP\CAD Client Stage" "StageWDA=%PnxInstallPath%\FTP\WDA Stage" "StagePrintClient=%PnxInstallPath%\FTP\Print Server Stage" "StageClientAppManager=%PnxInstallPath%\FTP\Client Application Manager Stage" "StageFingerPrintClient=%PnxInstallPath%\FTP\Finger Print Client Stage" "StageIDScannerClient=%PnxInstallPath%\FTP\ID Scanner Stage" "StageStationKIOSKRFIDClient=%PnxInstallPath%\FTP\Station KIOSK RFID Client Stage" "StageRFIDClient=%PnxInstallPath%\FTP\RFID Client Stage" "StageAVLRecorder=%PnxInstallPath%\FTP\AVL Recorder Stage" "StageInOutClient=%PnxInstallPath%\FTP\In Out Client Stage" "StageZetronClient=%PnxInstallPath%\FTP\Zetron Client Stage" "StagePhoenixDashboard=%PnxInstallPath%\FTP\Phoenix Dashboard Stage" "StageMobileInspectionApp=%PnxInstallPath%\FTP\Mobile Inspection App Stage" "PHOENIXJOBSVRV2=%PnxInstallPath%\Job Server V2" "PHOENIXAIWATCHERSERVICE=%PnxInstallPath%\Phoenix AI Watcher" "PNXDIAGRAM=%PnxInstallPath%\PNXDiagram" "PNXDIAGRAMAPI=%PnxInstallPath%\PNXDiagramAPI" "INSPECTIONAPI=%PnxInstallPath%\Phoenix Inspection API" "FIRECSPCONVERSION=%PnxInstallPath%\Fire CSP Conversion" "CAMERASERVER=%PnxInstallPath%\Phoenix Camera Server" "PHOENIXPAWN=%PnxInstallPath%\Phoenix Pawn" "StagePhoenixWDAV2=%PnxInstallPath%\FTP\Phoenix WDA V2 Stage"

:: --- AUTOMATICALLY ADDED MAPPINGS (FOUND IN YOUR APPREG_MAIN.XML BUT MISSING ABOVE) ---
"PhoenixHub=%PnxInstallPath%\PhoenixHub" "PaymentGateway=%PnxInstallPath%\Payment Gateway" "Authenticator=%PnxInstallPath%\Phoenix Authenticator" "InterfaceFolderWatcher=%PnxInstallPath%\Phoenix Interface Folder Watcher" "RegionalCAD2CAD=%PnxInstallPath%\Phoenix Regional CAD2CAD Service" "CADLiveStreaming=%PnxInstallPath%\Phoenix CAD Live Streaming Service" "DBUtilityCodeBook=%PnxInstallPath%\Phoenix Database Utility CodeBook" "CRMHubAPI=%PnxInstallPath%\CRMHubAPI" "PhoenixGateway=%PnxInstallPath%\Phoenix Gateway" "CSPProcessQueue=%PnxInstallPath%\CSPProcessQueueService" "CSPConversion=%PnxInstallPath%\CSP Conversion" "AIMugMatch=%PnxInstallPath%\PhoenixAIMugMatch" "AIAPI=%PnxInstallPath%\CRMHubAPI\PNXAIAPI" "ExpenseAPI=%PnxInstallPath%\CRMHubAPI\PNXExpenseAPI" "CustomerAPI=%PnxInstallPath%\CRMHubAPI\PNXCustomerAPI" "EmploymentClient=%PnxInstallPath%\Phoenix Employment Client" "AzureFileDownloader=%PnxInstallPath%\Azure File Downloader"
"@

    Clear-Host
    Write-Host "==============================================" -ForegroundColor Yellow
    Write-Host "   ProPhoenix Hotfix Automation (Installation Team)  " -ForegroundColor Yellow
    Write-Host "   HOST: $CurrentHostName" -ForegroundColor Yellow
    Write-Host "==============================================" -ForegroundColor Yellow

    # --- 3. FIND INSTANCES ---
    $FileName = "Appreg_main.xml"
    $PossibleParents = @("ProPhoenix\Server Application Manager","Program Files (x86)\ProPhoenix\Server Application Manager","Program Files\ProPhoenix\Server Application Manager","ProPhoenix\Phoenix Server Application Manager","Program Files (x86)\ProPhoenix\Phoenix Server Application Manager","Program Files\ProPhoenix\Phoenix Server Application Manager")
    $Drives = Get-PSDrive -PSProvider FileSystem
    $FoundFiles = @()

    foreach ($d in $Drives) {
        foreach ($folder in $PossibleParents) {
            $TestPath = Join-Path -Path $d.Root -ChildPath $folder
            $FullFilePath = Join-Path -Path $TestPath -ChildPath $FileName
            if (Test-Path $FullFilePath) { $FoundFiles += $FullFilePath }
        }
    }

    if ($FoundFiles.Count -eq 0) { Write-Error "No instances found. Exiting."; return }

    # --- 4. FIND CLIENT APPS ---
    $ClientLaunchLogic = ""
    $CommonRoots = @("ProPhoenix", "Program Files\ProPhoenix", "Program Files (x86)\ProPhoenix")
    foreach ($key in ($ClientAppsDef.Keys | Sort-Object)) {
        $FoundClient = $false
        foreach ($d in $Drives) {
            foreach ($root in $CommonRoots) {
                $TryPath = Join-Path -Path $d.Root -ChildPath $root | Join-Path -ChildPath $key | Join-Path -ChildPath $ClientAppsDef[$key]
                if (Test-Path $TryPath) {
                    $ClientLaunchLogic += "echo Launching $key...`r`n"
                    $PSCommand = "`$path = '$TryPath'; `$desktop = [Environment]::GetFolderPath('Desktop'); `$public = [Environment]::GetFolderPath('CommonDesktopDirectory'); `$shell = New-Object -ComObject WScript.Shell; `$shortcut = Get-ChildItem -Path `$desktop, `$public -Filter '*.lnk' | Where-Object { `$shell.CreateShortcut(`$_.FullName).TargetPath -eq `$path } | Select-Object -First 1; if (`$shortcut) { Start-Process `$shortcut.FullName -Verb RunAs; } else { Start-Process `$path -Verb RunAs; }"
                    $ClientLaunchLogic += "%PSExe% -WindowStyle Hidden -Command `"$($PSCommand -replace "`r`n", " " -replace "\s+", " ")`"`r`n"
                    $FoundClient = $true; break
                }
            }
            if ($FoundClient) { break }
        }
    }

    # --- 5. PROCESS LOOP ---
    $InstanceCount = 1
    $GeneratedBatFiles = @()

    foreach ($FoundPath in $FoundFiles) {
        Write-Host "`nPROCESSING INSTANCE #${InstanceCount}: $FoundPath" -ForegroundColor Yellow
        
        $AppMgrFolder = (Split-Path $FoundPath -Parent)
        $InstallDrive = (Split-Path $FoundPath -Qualifier)
        $LogDir = Join-Path -Path $AppMgrFolder -ChildPath "PnxLog\PrintLog"
        if (-not (Test-Path $LogDir)) { try { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null } catch {} }
        
        # Prepare PnxTemp & Scripts
        $PnxTempPath = Join-Path -Path (Split-Path $AppMgrFolder -Parent) -ChildPath "PnxTemp"
        if (-not (Test-Path $PnxTempPath)) { try { New-Item -ItemType Directory -Path $PnxTempPath -Force | Out-Null } catch {} }
        Set-Content -Path (Join-Path $PnxTempPath "LogClear.ps1") -Value $LogClearScriptContent -Encoding ASCII
        Set-Content -Path (Join-Path $PnxTempPath "InstanceVerification.ps1") -Value $VerificationScriptContent -Encoding ASCII

        # Parse Mappings
        $PathMap = @{}
        foreach ($m in [regex]::Matches($RawMappingData, '"([^"]+)=%PnxInstallPath%\\([^"]+)"')) {
            $PathMap[$m.Groups[2].Value.Replace("/", "\").Trim()] = $m.Groups[1].Value
        }

        try { [xml]$xmlData = Get-Content $FoundPath } catch { Write-Error "Invalid XML"; continue }
        
        # --- SPLIT LOGIC: PROD VS STAGE ---
        $ProdInstallArgs = new-object System.Collections.Generic.List[string]
        $StageInstallArgs = new-object System.Collections.Generic.List[string]
        $UpdateArgs = new-object System.Collections.Generic.List[string]
        
        $ProdInstallArgs.Add('"INSTALL"')
        $StageInstallArgs.Add('"INSTALL"')
        $UpdateArgs.Add('"UPDATEINSTANCE"')

        if ($xmlData.PhoenixApplications.AppReg) {
            foreach ($app in $xmlData.PhoenixApplications.AppReg) {
                if ($app.CurrentVersion -ne "0.0.0.0") {
                    $FPath = $app.AppPath.Replace("/", "\").Trim()
                    $BestID = $null; $BestLen = 0
                    foreach ($k in $PathMap.Keys) {
                        if ($FPath.EndsWith($k, [System.StringComparison]::OrdinalIgnoreCase)) {
                            if ($k.Length -gt $BestLen) { $BestID = $PathMap[$k]; $BestLen = $k.Length }
                        }
                    }
                    if ($BestID) {
                        if ($BestID -match "(?i)Stage") {
                            $StageInstallArgs.Add("`"$BestID`"")
                            Write-Host "  [STAGE] $BestID" -ForegroundColor Gray
                        } else {
                            $ProdInstallArgs.Add("`"$BestID`"")
                            if ($ServiceProductList -contains $BestID) { $UpdateArgs.Add("`"$BestID`"") }
                            Write-Host "  [PROD]  $BestID" -ForegroundColor Green
                        }
                    }
                }
            }
        }

        $ProdLine = $ProdInstallArgs -join " "
        $StageLine = $StageInstallArgs -join " "
        $UpdateLine = $UpdateArgs -join " "

        $UpdateCmd = ""
        if ($UpdateArgs.Count -gt 1) {
            $UpdateCmd = "%AppMgrExePath%\PnxAppMgr.exe $UpdateLine | %PSExe% -Command `"`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }`""
        }

        # --- BATCH FILE GENERATION ---
        $BatchContent = @"
$InstallDrive
cd "$AppMgrFolder"
@echo off
SET AppMgrExePath="$AppMgrFolder"
SET PSExe=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
set "timestamp=%DATE:/=-%_%TIME::=-%"
set "timestamp=%timestamp: =0%"
set LOGFILE="%~dp0Install_Log_%timestamp%.txt"

echo ===================================================
echo   PHOENIX HOTFIX INSTALLER (PRODUCTION)
echo ===================================================
echo [LOG] Execution Started... > %LOGFILE%

echo.
echo ===================================================
echo   STEP 1: PRODUCTION APPLICATION INSTALL
echo   (Services are still RUNNING)
echo ===================================================
echo [LOG] Installing Production Apps... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe $ProdLine | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   STEP 2: STAGE APPLICATION INSTALL
echo ===================================================
SET /P "StagePrompt=Do you want to install STAGE Applications now? (Y/N): "
IF /I "%StagePrompt%"=="Y" GOTO RunStage
GOTO SkipStage

:RunStage
echo [LOG] Installing Stage Apps... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe $StageLine | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1
GOTO StopServices

:SkipStage
echo [INFO] Skipping Stage Installation. >> %LOGFILE%
echo Skipping Stage Installation...

:StopServices
echo.
echo ===================================================
echo   STEP 3: STOPPING PHOENIX SERVICES (MAINTENANCE START)
echo ===================================================
echo [LOG] Stopping Services... >> %LOGFILE%
%windir%\System32\iisreset.exe /stop >> %LOGFILE% 2>&1
%windir%\System32\taskkill.exe /F /IM "KPI.Phoenix.CADClient.exe" /T 2>nul >> %LOGFILE% 2>&1
%windir%\System32\taskkill.exe /F /IM "KPI.Phoenix.CADMobileClient.exe" /T 2>nul >> %LOGFILE% 2>&1
%windir%\System32\taskkill.exe /F /IM "Phoenix.WDAV2.Client.Shell.exe" /T 2>nul >> %LOGFILE% 2>&1
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name `$_.Name -Force; Write-Host 'Stopped ' `$_.Name }" >> %LOGFILE% 2>&1

echo.
echo ===================================================
echo   STEP 4: CLEANUP (LOGS & SVR SESSION DATA)
echo ===================================================
echo [LOG] Cleaning Logs and Session Data... >> %LOGFILE%
%PSExe% -ExecutionPolicy Bypass -File "%~dp0LogClear.ps1" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   STEP 5: UPDATING INSTANCES
echo ===================================================
echo [LOG] Starting IIS for Instance Update... >> %LOGFILE%
%windir%\System32\iisreset.exe /start >> %LOGFILE% 2>&1
echo [LOG] Updating Application Manager... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe "UPDAPPMANAGER"
timeout 10 > NUL

echo [LOG] Running UPDATEINSTANCE... >> %LOGFILE%
$UpdateCmd

echo.
echo ===================================================
echo   STEP 6: STARTING PHOENIX SERVICES
echo ===================================================
echo [LOG] Starting Services... >> %LOGFILE%
timeout /t 5 >nul
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -ne 'Running' } | ForEach-Object { try { Start-Service -Name `$_.Name -ErrorAction Stop; Write-Host 'Started ' `$_.Name } catch { Write-Host 'Failed to start ' `$_.Name `$_.Exception.Message } }" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   STEP 6.5: Live INSTANCE STATUS
echo ===================================================
echo [LOG] Reporting Instance Status... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe "SHOWINSTANCES" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   STEP 7: Instance Update VERIFICATION AND CLIENT LAUNCH
echo ===================================================
echo [LOG] Verifying DLLs... >> %LOGFILE%
%PSExe% -ExecutionPolicy Bypass -File "%~dp0InstanceVerification.ps1" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   READY FOR CLIENT CHECK
echo   Press any key to launch clients for Auto-Update...
pause >nul
echo [LOG] Launching Clients... >> %LOGFILE%
$ClientLaunchLogic

echo.
echo Process Complete. Log saved to: %LOGFILE%
echo Press any key to close...
pause >nul
"@
        # --- NEW FILE NAMING LOGIC (1, 2, 3...) ---
        $BaseName = "${CurrentHostName}_HotfixAutomation"
        $Ext = ".bat"
        $FinalName = "$BaseName$Ext"
        $OutputBatFile = Join-Path -Path $PnxTempPath -ChildPath $FinalName
        $Counter = 1

        while (Test-Path $OutputBatFile) {
            $FinalName = "${BaseName}_${Counter}${Ext}"
            $OutputBatFile = Join-Path -Path $PnxTempPath -ChildPath $FinalName
            $Counter++
        }

        Set-Content -Path $OutputBatFile -Value $BatchContent -Encoding ASCII
        $GeneratedBatFiles += $OutputBatFile
        Write-Host " [SUCCESS] Generated: $OutputBatFile" -ForegroundColor Green
        $InstanceCount++
    }
    return $GeneratedBatFiles
}

# ==============================================================================
#  3. EXECUTION CONTROLLER
# ==============================================================================
if ($RunRemote) {
    $Creds = Get-Credential
    try {
        Invoke-Command -ComputerName $TargetServer -Credential $Creds -ScriptBlock $GeneratorLogic
        Write-Host "`n[INFO] Remote generation complete." -ForegroundColor Yellow
    } catch { Write-Error "Connection failed: $_" }
} else {
    $LocalBatFiles = & $GeneratorLogic
    if ($LocalBatFiles.Count -gt 0) {
        if ((Read-Host "`nRun Automation now? (Y/N)") -eq "Y") {
            foreach ($bat in $LocalBatFiles) { Start-Process -FilePath $bat -Verb RunAs }
        }
    }
}
'@

# --- 2. DB SYNC ---
$Content_DBSync = @'
# ======================================================================
#  ProPhoenix Auto Database Sync Utility - v2.0 ( Installation Team )
# ======================================================================

Clear-Host
Write-Host "===== ProPhoenix Auto Database Sync Utility - v2.0 ( Installation Team )l =====" -ForegroundColor Cyan

# ----------------------------------------------------------------------
# CONFIGURATION & PATHS
# ----------------------------------------------------------------------
$setupPath = "C:\pnxtemp\dbsynctool"
$setupFile = Join-Path $setupPath "DBDetails.txt"
$xmlTarget = Join-Path $setupPath "PnxAutoNewDBSyn.xml"

if (!(Test-Path $setupPath)) {
    New-Item -ItemType Directory -Force -Path $setupPath | Out-Null
    Write-Host "✓ Created directory: $setupPath" -ForegroundColor Green
}

# ----------------------------------------------------------------------
# STEP 1: GENERATE XML FILE
# ----------------------------------------------------------------------
$xmlContent = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
	<SourceServer>
		<IPAddress>CHPNX947\MSSQLSERVER01</IPAddress> 
		<DBName>DBName</DBName> 
		<UserName>sa</UserName> 
		<Password>pnx</Password> 
		<JurisID>1000</JurisID>
		<State>MA</State>
		<JurisName>ProPhoenix</JurisName>
		<JurisAlias>PNX</JurisAlias>
		<SyncType>2</SyncType>
	</SourceServer>
</PnxPakager>
"@

if (!(Test-Path $xmlTarget)) {
    Set-Content -Path $xmlTarget -Value $xmlContent -Force
    Write-Host "✓ Generated default XML template." -ForegroundColor Green
}

# ----------------------------------------------------------------------
# STEP 2: SQL FETCH FUNCTION
# ----------------------------------------------------------------------
function Get-PhoenixDBs {
    param($Server, $User, $Password)

    try {
        $connString = "Server=$Server;User Id=$User;Password=$Password;Database=master;Connection Timeout=15;"
        $conn = New-Object System.Data.SqlClient.SqlConnection
        $conn.ConnectionString = $connString
        $conn.Open()

        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT Name FROM sys.databases WHERE (Name LIKE '%Police%' OR Name LIKE '%Fire%' OR Name LIKE '%IA%' OR Name LIKE '%Master%') AND Name NOT IN ('master', 'model', 'msdb', 'tempdb') ORDER BY Name"
        
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataset) | Out-Null
        $conn.Close()

        $dbList = $dataset.Tables[0].Rows | Select-Object -ExpandProperty Name
        return $dbList
    }
    catch {
        $errMsg = $_.Exception.Message
        Write-Host "❌ LOGIN FAILED: $errMsg" -ForegroundColor Red
        
        if ($errMsg -match "error: 40" -or $errMsg -match "Named Pipes Provider") {
            Write-Host "   💡 HINT: 'Error 40' usually means the Server Name is wrong or unreachable." -ForegroundColor Yellow
            Write-Host "      1. Did you forget the instance? (Try: ServerName\InstanceName)" -ForegroundColor Yellow
            Write-Host "      2. Is the firewall blocking Port 1433?" -ForegroundColor Yellow
        }
        elseif ($errMsg -match "Login failed for user") {
            Write-Host "   💡 HINT: Double-check your Username and Password." -ForegroundColor Yellow
        }

        return $null
    }
}

# ----------------------------------------------------------------------
# STEP 2.5: FINAL DB VERSION CHECK FUNCTION
# ----------------------------------------------------------------------
function Show-DBVersions {
    param($Server, $User, $Password)

    Write-Host "`n[Generatig Final Version Report...]" -ForegroundColor DarkYellow
    
    try {
        $connString = "Server=$Server;User Id=$User;Password=$Password;Database=master;Connection Timeout=30;"
        $conn = New-Object System.Data.SqlClient.SqlConnection
        $conn.ConnectionString = $connString
        $conn.Open()

        $cmd = $conn.CreateCommand()
        
        # === YOUR QUERY INSERTED HERE ===
        $cmd.CommandText = @"
DECLARE @sql NVARCHAR(MAX) = N'';

IF OBJECT_ID('tempdb..##FinalResults') IS NOT NULL DROP TABLE ##FinalResults;
CREATE TABLE ##FinalResults (DatabaseName NVARCHAR(255), VersionInfo NVARCHAR(MAX)); 

SELECT @sql = @sql + '
IF EXISTS (SELECT 1 
           FROM [' + name + '].sys.tables t 
           JOIN [' + name + '].sys.schemas s 
             ON t.schema_id = s.schema_id 
           WHERE t.name = ''KPIDBVersion'' AND s.name = ''dbo'')
BEGIN
    INSERT INTO ##FinalResults
    SELECT ''' + name + ''', CAST(Version AS NVARCHAR(MAX)) 
    FROM [' + name + '].dbo.KPIDBVersion;
END;
'
FROM sys.databases
WHERE database_id > 4 AND state_desc = 'ONLINE'
ORDER BY name;

EXEC sp_executesql @sql;

SELECT * FROM ##FinalResults ORDER BY DatabaseName;
DROP TABLE ##FinalResults;
"@

        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataset) | Out-Null
        $conn.Close()

        $results = $dataset.Tables[0]

        if ($results.Rows.Count -gt 0) {
            Write-Host "`n===== FINAL DATABASE VERSIONS =====" -ForegroundColor Cyan
            $results | Format-Table -AutoSize
        } else {
            Write-Host "⚠ No version information found (KPIDBVersion table might be missing)." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "❌ FAILED TO FETCH VERSIONS: $($_.Exception.Message)" -ForegroundColor Red
    }
}


# ----------------------------------------------------------------------
# STEP 3: INTERACTIVE SETUP
# ----------------------------------------------------------------------
$runSetup = $true
if (Test-Path $setupFile) {
    Write-Host "✓ Configuration file found: $setupFile" -ForegroundColor Green
    $response = Read-Host "⚠ Do you want to use existing details? (Y = Proceed / N = Update or Fetch New)"
    if ($response -match "^[Yy]") { $runSetup = $false }
}

if ($runSetup) {
    $validConnection = $false
    
    while (-not $validConnection) {
        Write-Host "`n--- CONNECTION SETUP ---" -ForegroundColor Cyan
        
        $mode = Read-Host "Select Server Mode: [L] Local (This PC) / [R] Remote Server"
        if ($mode -match "^[Ll]") {
            $in_IP = $env:COMPUTERNAME
            Write-Host "✓ Local Server Selected: $in_IP" -ForegroundColor Green
        } else {
            $in_IP = Read-Host "Enter Remote SQL IP or Name"
        }

        $in_User = Read-Host "Enter SQL Username          (e.g., 'sa')"
        $in_Pass = Read-Host "Enter SQL Password"
        
        Write-Host "`nConnecting to [$in_IP] as user [$in_User]..." -ForegroundColor DarkYellow
        $fetchedDBs = Get-PhoenixDBs -Server $in_IP -User $in_User -Password $in_Pass
        $fetchedDBs = $fetchedDBs | Where-Object { $_ -ne "master" }

        if ($fetchedDBs) {
            $validConnection = $true
            Write-Host "`n✓ LOGIN SUCCESSFUL! FOUND DATABASES:" -ForegroundColor Green
            $displayList = $fetchedDBs -join "; "
            Write-Host "$displayList" -ForegroundColor Gray
        }
        else {
            Write-Host "`n⚠ Connection failed." -ForegroundColor Yellow
            $retry = Read-Host "Do you want to try entering credentials again? (Y/N)"
            if ($retry -match "^[Nn]") {
                $validConnection = $true 
                $fetchedDBs = $null
            }
        }
    }

    # === PASTE LOGIC ===
    Write-Host "`n--- DATABASE SELECTION ---" -ForegroundColor Cyan
    Write-Host "Option 1: Press [ENTER] to sync ALL fetched databases." -ForegroundColor Gray
    Write-Host "Option 2: Paste your list below (Press ENTER on a blank line when done)." -ForegroundColor Yellow
    
    $rawInputList = @()
    do {
        $line = Read-Host "Paste/Type DB >"
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $rawInputList += $line
        }
    } until ([string]::IsNullOrWhiteSpace($line))

    # === CLEANUP & FORMATTING ===
    if ($rawInputList.Count -eq 0 -and $fetchedDBs) {
        $finalList = $fetchedDBs
    }
    elseif ($rawInputList.Count -gt 0) {
        $tempList = @()
        foreach ($item in $rawInputList) {
            $cleaned = $item -replace "^[\s-]*", "" -replace "[\s-]*$", "" 
            $parts = $cleaned -split "," 
            foreach ($p in $parts) {
                if (-not [string]::IsNullOrWhiteSpace($p)) {
                    $tempList += $p.Trim()
                }
            }
        }
        $finalList = $tempList | Select-Object -Unique
    }
    else {
        Write-Host "❌ No databases selected. Exiting." -ForegroundColor Red
        exit
    }

    # Format: ;DB1;DB2;
    $formattedDBs = ";" + ($finalList -join ";") + ";"

    # === SHOW ONLY THE FORMATTED STRING ===
    Write-Host "`n[UPDATED LIST TO BE PROCESSED]" -ForegroundColor Yellow
    Write-Host "$formattedDBs" -ForegroundColor Green

    $fileContent = @"
IPAddress=$in_IP
DBName=$formattedDBs
UserName=$in_User
Password=$in_Pass
SyncType=2
"@
    Set-Content -Path $setupFile -Value $fileContent -Force
    Write-Host "✓ DBDetails.txt updated successfully." -ForegroundColor Gray
}

# ----------------------------------------------------------------------
# STEP 4: READ CONFIGURATION & VALIDATE
# ----------------------------------------------------------------------
$rawContent = Get-Content $setupFile | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#|^\s*//' }
$params = $rawContent | ForEach-Object {
    $kv = $_ -split "="
    if ($kv.Length -eq 2) { [PSCustomObject]@{ Key = $kv[0].Trim(); Value = $kv[1].Trim() } }
}

$IPAddress  = ($params | Where-Object { $_.Key -eq "IPAddress" }).Value
$DBNamesRaw = ($params | Where-Object { $_.Key -eq "DBName" }).Value
$DBNames    = $DBNamesRaw -split ";" | Where-Object { $_ -ne "" } | ForEach-Object { $_.Trim() }
$UserName   = ($params | Where-Object { $_.Key -eq "UserName" }).Value
$Password   = ($params | Where-Object { $_.Key -eq "Password" }).Value
$SyncType   = ($params | Where-Object { $_.Key -eq "SyncType" }).Value

if (-not $SyncType) { $SyncType = 2 }

if (-not $IPAddress -or -not $DBNames -or -not $UserName -or -not $Password) {
    Write-Host "❌ ERROR: Missing required fields in DBDetails.txt." -ForegroundColor Red
    exit
}

# ----------------------------------------------------------------------
# STEP 5: DETECT PATHS & EXECUTE
# ----------------------------------------------------------------------
$DBSyncRoot = $null
foreach ($drive in (Get-PSDrive -PSProvider FileSystem).Root) {
    $candidate = Join-Path $drive "Program Files\ProPhoenix\Database Utility\DB Sync"
    if (Test-Path $candidate) {
        $DBSyncRoot = $candidate
        break
    }
}

if (-not $DBSyncRoot) {
    Write-Host "❌ ERROR: Cannot locate DB Sync folder on ANY drive." -ForegroundColor Red
    exit
}
Write-Host "✓ DB Sync root detected: $DBSyncRoot" -ForegroundColor Green

$folders = @{
    Police        = Join-Path $DBSyncRoot "Police"
    Fire          = Join-Path $DBSyncRoot "Fire"
    IA            = Join-Path $DBSyncRoot "IA"
    PhoenixMaster = Join-Path $DBSyncRoot "Phoenix Master"
    PoliceDW      = Join-Path $DBSyncRoot "Police DW"
}

# ----------------------------------------------------------------------
# HELPER: LOG WATCHER
# ----------------------------------------------------------------------
function Get-NewLogFile {
    param($Folder, $StartTime, [int]$TimeoutSeconds = 120)
    $stopTime = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $stopTime) {
        $log = Get-ChildItem $Folder -Filter "DBToolLog*.txt" -ErrorAction SilentlyContinue |
               Where-Object { $_.LastWriteTime -gt $StartTime } |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 1
        if ($log) { return $log.FullName }
        Start-Sleep -Seconds 5
    }
    return $null
}

# ----------------------------------------------------------------------
# MAIN EXECUTION FUNCTION
# ----------------------------------------------------------------------
function Run-DBSync {
    param($DB, $TargetFolder)

    Write-Host "`nProcessing DB: $DB" -ForegroundColor Yellow

    [xml]$xmlData = Get-Content $xmlTarget
    $xmlData.PnxPakager.SourceServer.IPAddress = $IPAddress
    $xmlData.PnxPakager.SourceServer.DBName    = $DB
    $xmlData.PnxPakager.SourceServer.UserName  = $UserName
    $xmlData.PnxPakager.SourceServer.Password  = $Password
    $xmlData.PnxPakager.SourceServer.SyncType  = $SyncType

    $xmlOut = Join-Path $TargetFolder "PnxAutoNewDBSyn.xml"
    $xmlData.Save($xmlOut)

    Write-Host "✓ XML updated for: $DB" -ForegroundColor Green

    $exe = Join-Path $TargetFolder "PnxDBSync.exe"
    if (!(Test-Path $exe)) {
        Write-Host "❌ ERROR: Missing $exe" -ForegroundColor Red
        return $false
    }

    Write-Host "▶ Starting DB Sync..." -ForegroundColor Cyan
    $start = Get-Date
    Start-Process -FilePath $exe -Wait -PassThru | Out-Null

    $logPath = Get-NewLogFile -Folder $TargetFolder -StartTime $start
    
    if (-not $logPath) { 
        Write-Host "❌ TIMEOUT: No log file generated for $DB." -ForegroundColor Red
        return $false 
    }

    $content = Get-Content $logPath -Raw
    $success1 = "ExecuteForUpdatePS() : DB Version Updated."
    $success2 = "ExecuteForUpdatePS() : Deleting PnxAutoNewDBSyn.xml file."
    $success3 = "ExecuteForUpdatePS() : PnxAutoNewDBSyn.xml file deleted."

    if (($content -match [regex]::Escape($success1)) -and 
        ($content -match [regex]::Escape($success2)) -and 
        ($content -match [regex]::Escape($success3))) {
        Write-Host "✔ SYNC SUCCESS for $DB" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "❌ SYNC FAILED for $DB" -ForegroundColor Red
        $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $backupName = "DBToolLog_${DB}_FAILED_${timestamp}.txt"
        $backupPath = Join-Path $TargetFolder $backupName
        Copy-Item -Path $logPath -Destination $backupPath -Force
        Write-Host "⚠ Log Backup: $backupName" -ForegroundColor DarkYellow
        return $false
    }
}

# ----------------------------------------------------------------------
# MAIN LOOP
# ----------------------------------------------------------------------
foreach ($db in $DBNames) {
    $db = $db.Trim()
    if ([string]::IsNullOrEmpty($db)) { continue }
    if ($db -eq "master") { continue }

    if ($db -match "Master$") { $key = "PhoenixMaster" }
    elseif ($db -match "DW$") { $key = "PoliceDW" }
    elseif ($db -match "Police") { $key = "Police" }
    elseif ($db -match "Fire") { $key = "Fire" }
    elseif ($db -match "IA$") { $key = "IA" }
    else {
        Write-Host "⚠ Unknown DB type: $db - SKIPPED" -ForegroundColor DarkGray
        continue
    }

    $target = $folders[$key]
    if (!(Test-Path $target)) {
        Write-Host "❌ Missing module folder: $target - SKIPPED" -ForegroundColor Red
        continue
    }

    $result = Run-DBSync -DB $db -TargetFolder $target

    if (-not $result) {
        Write-Host "➡ Moving to next database automatically..." -ForegroundColor Cyan
    }
}

# ----------------------------------------------------------------------
# FINAL STEP: RUN VERSION CHECK
# ----------------------------------------------------------------------
Write-Host "`n🎉 All operations completed." -ForegroundColor Cyan

# CALL THE NEW VERSION CHECK FUNCTION
Show-DBVersions -Server $IPAddress -User $UserName -Password $Password
'@

# --- 3. PRECOMPILER ---
$Content_PreComp = @'
# =============================================================================
# PHOENIX PRECOMPILER: Installation Team
# =============================================================================

# --- STEP 1: DISCOVER IIS ENVIRONMENTS (STRICT FILTER) ---
Write-Host "Step 1: Discovering IIS Bindings..." -ForegroundColor Cyan

# Check for Admin rights
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "This script must be run as Administrator."
    Break
}

Import-Module WebAdministration

$results = @()

# STRICT WHITELIST: Only these folders are allowed.
$targetEnvironments = @{
    "Police RMS"  = "\ProPhoenix\Police RMS"
    "Fire RMS"    = "\ProPhoenix\Fire RMS"
    "Phoenix IA"  = "\ProPhoenix\PhoenixIA"
}

$sites = Get-Website
foreach ($site in $sites) {
    $bindings = $site.bindings.Collection
    foreach ($binding in $bindings) {
        $protocol = $binding.protocol
        $info = $binding.bindingInformation -split ":"
        $ip = $info[0]; $port = $info[1]; $hostHeader = $info[2]
        
        if ($port -ne "443") { continue }

        if ($ip -eq "*" -and [string]::IsNullOrEmpty($hostHeader)) { $hostname = "localhost" }
        elseif ([string]::IsNullOrEmpty($hostHeader)) { $hostname = $ip }
        else { $hostname = $hostHeader }

        $cleanBaseUrl = "{0}://{1}" -f $protocol, $hostname

        function Get-StrictEnvironmentName ($path) {
            $cleanPath = $path.TrimEnd('\')
            foreach ($key in $targetEnvironments.Keys) {
                if ($cleanPath.EndsWith($targetEnvironments[$key], [System.StringComparison]::OrdinalIgnoreCase)) { return $key }
            }
            return $null
        }

        $rootEnv = Get-StrictEnvironmentName -path $site.physicalPath
        if ($rootEnv) {
            $results += [PSCustomObject]@{ Environment = $rootEnv; CleanURL = "$cleanBaseUrl/"; LocalDirectory = $site.physicalPath }
        }

        $applications = Get-WebApplication -Site $site.name
        foreach ($app in $applications) {
            $appEnv = Get-StrictEnvironmentName -path $app.PhysicalPath
            if ($appEnv) {
                $results += [PSCustomObject]@{ Environment = $appEnv; CleanURL = "{0}{1}/" -f $cleanBaseUrl, $app.Path; LocalDirectory = $app.PhysicalPath }
            }
        }
    }
}

if ($results.Count -eq 0) {
    Write-Host "Error: No matching environments (Police/Fire/IA) found in IIS." -ForegroundColor Red
    return
}
$results | Format-Table Environment, CleanURL, LocalDirectory -AutoSize

# --- STEP 2: PREPARE MAPPING ---
$configMap = @{ "Police RMS" = "Police"; "Fire RMS" = "Fire"; "Phoenix IA" = "IA" }

# --- STEP 3: LOCATE LOCAL TOOL TARGET ---
Write-Host "`nStep 3: Locate Local Installation" -ForegroundColor Cyan

# STOP RUNNING PROCESSES
Write-Host "Checking for running instances of PnxPrecompilerWin..." -ForegroundColor Yellow
$runningProcs = Get-Process "PnxPrecompilerWin" -ErrorAction SilentlyContinue
if ($runningProcs) {
    Write-Host "Stopping $($runningProcs.Count) running instances..." -ForegroundColor Yellow
    $runningProcs | Stop-Process -Force
    Start-Sleep -Seconds 2
}

$WorkingPath = $null
Write-Host "Searching local drives for installed 'PhoenixPrecompileEx' folder..." -ForegroundColor Cyan

$targetPartialPath = "Program Files (x86)\ProPhoenix\Server Application Manager\PhoenixPrecompileEx"
$drives = Get-PSDrive -PSProvider FileSystem

foreach ($drive in $drives) {
    $potentialPath = Join-Path $drive.Root $targetPartialPath
    if (Test-Path $potentialPath) {
        $WorkingPath = $potentialPath
        Write-Host "Found installed tool at: $WorkingPath" -ForegroundColor Green
        break
    }
}

if (-not $WorkingPath) {
    Write-Host "Error: Tool folder not found on any local drive." -ForegroundColor Red
    return 
}

# --- STEP 4: UPDATE JSON CONFIG (SPECIFIC STRUCTURE) ---
Write-Host "`nStep 4: Updating JSON Config File..." -ForegroundColor Cyan
Write-Host "Target: $WorkingPath" -ForegroundColor Gray

$jsonPath = Join-Path $WorkingPath "products.config.json"

if (-not (Test-Path $jsonPath)) {
    Write-Host "Error: JSON Config file missing at $jsonPath" -ForegroundColor Red
    return
}

try {
    # 1. READ JSON
    $jsonContent = Get-Content -Path $jsonPath -Raw | ConvertFrom-Json
    $updatesCount = 0

    # 2. VALIDATE STRUCTURE
    if (-not $jsonContent.PSObject.Properties['Products']) {
        Write-Host "Error: Invalid JSON format. Root property 'Products' is missing." -ForegroundColor Red
        return
    }

    # 3. UPDATE LOOP
    foreach ($item in $results) {
        $targetName = $configMap[$item.Environment] # e.g., "Police", "Fire", "IA"
        if (-not $targetName) { continue }

        # Find the product object inside the 'Products' array
        $productEntry = $jsonContent.Products | Where-Object { $_.Name -eq $targetName }

        if ($productEntry) {
            Write-Host " -> Updating '$targetName'..." -ForegroundColor Yellow
            
            # Update BasePath
            if ($productEntry.BasePath -ne $item.LocalDirectory) {
                $productEntry.BasePath = $item.LocalDirectory
                Write-Host "    [BasePath] Updated" -ForegroundColor Gray
            }
            
            # Update Url
            if ($productEntry.Url -ne $item.CleanURL) {
                $productEntry.Url = $item.CleanURL
                Write-Host "    [Url] Updated" -ForegroundColor Gray
            }

            $updatesCount++
        } else {
            Write-Host " -> Warning: Product '$targetName' not found in JSON." -ForegroundColor Red
        }
    }

    # 4. SAVE JSON
    if ($updatesCount -gt 0) {
        # Depth 10 preserves the nested 'CriticalModules' array
        $jsonContent | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath
        Write-Host "Success! Updated $updatesCount products in products.config.json." -ForegroundColor Green
    } else {
        Write-Host "No changes were needed." -ForegroundColor Yellow
    }

} catch {
    Write-Host "Error parsing or saving JSON: $_" -ForegroundColor Red
}

Write-Host "Script Complete." -ForegroundColor Green
'@

# --- 4. HOTFIX INSTALLATION TEAM ---
$Content_HotfixInst = @'
<#
.SYNOPSIS
    ProPhoenix Hotfix Automation  (Installation Team).
#>

# ==============================================================================
#  1. INTERACTIVE PROMPT
# ==============================================================================
Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   ProPhoenix Hotfix Automation  (Installation Team)." -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

$TargetServer = Read-Host "Enter Target Server Name (Press ENTER for Localhost)"

if ([string]::IsNullOrWhiteSpace($TargetServer)) {
    $TargetServer = "localhost"
    $RunRemote = $false
    Write-Host "-> Selected Mode: LOCAL EXECUTION" -ForegroundColor Green
} else {
    $RunRemote = $true
    Write-Host "-> Selected Mode: REMOTE EXECUTION on $TargetServer" -ForegroundColor Yellow
}
Write-Host "==============================================" -ForegroundColor Cyan

# ==============================================================================
#  2. CORE LOGIC BLOCK (Runs on the Target Machine)
# ==============================================================================
$GeneratorLogic = {
    $ErrorActionPreference = "Continue"
    $CurrentHostName = $env:COMPUTERNAME

    # --- DEFINITIONS: HELPER SCRIPTS ---
    $LogClearScriptContent = @"
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
Write-Host "========================================="
Write-Host "             SCRIPT STARTED              "
Write-Host "========================================="
`$proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    "`$(`$_.Root)\Program Files\ProPhoenix"
} | Where-Object { Test-Path -Path `$_ }

Write-Host "`n[INFO] Searching for '_Instances' folders..."
`$instanceFolders = foreach (`$basePath in `$proPhoenixBasePaths) {
    Get-ChildItem -Path `$basePath -Directory -Recurse | Where-Object {
        Test-Path -Path "`$(`$_.FullName)\_Instances"
    }
}

if (`$instanceFolders.Count -eq 0) {
    Write-Host "[WARNING] No '_Instances' folders found. Exiting..."
    exit
}

Write-Host "[INFO] Detecting environment types..."
`$environmentTypes = @()
foreach (`$folder in `$instanceFolders) {
    `$envFolders = Get-ChildItem -Path "`$(`$folder.FullName)\_Instances" -Directory | Select-Object -ExpandProperty Name
    `$environmentTypes += `$envFolders
}
`$environmentTypes = `$environmentTypes | Sort-Object -Unique

Write-Host "[SUCCESS] Found environments: `$(`$environmentTypes -join ', ')\n"
Write-Host "========================================="
Write-Host "           PROCESSING LOG FILES          "
Write-Host "========================================="

foreach (`$folder in `$instanceFolders) {
    foreach (`$environmentType in `$environmentTypes) {
        `$targetPath = "`$(`$folder.FullName)\_Instances\`$environmentType\PnxLog"
        `$oldFolderPath = "`$targetPath\old"

        if (Test-Path -Path `$targetPath) {
            `$filesToMove = Get-ChildItem -Path `$targetPath -File | Where-Object { `$_.FullName -notlike "`$oldFolderPath*" }
            if (`$filesToMove.Count -gt 0) {
                if (!(Test-Path -Path `$oldFolderPath)) { New-Item -ItemType Directory -Path `$oldFolderPath | Out-Null }
                Get-ChildItem -Path `$oldFolderPath -File | Remove-Item -Force
                foreach (`$file in `$filesToMove) { Move-Item -Path `$file.FullName -Destination `$oldFolderPath }
                Write-Host "[SUCCESS] Logs processed for: `$environmentType (`$targetPath)"
            } else {
                Write-Host "[INFO] No log files in: `$targetPath. Skipping..."
            }
        }
    }
}

# CLEAR SVR SESSION DATA
Write-Host "`n========================================="
Write-Host "       CLEARING SERVER SESSION DATA      "
Write-Host "========================================="
foreach (`$basePath in `$proPhoenixBasePaths) {
    `$cadServerPath = Join-Path -Path `$basePath -ChildPath "CAD Server\_Instances"
    if (Test-Path `$cadServerPath) {
        `$cadInstances = Get-ChildItem -Path `$cadServerPath -Directory
        foreach (`$inst in `$cadInstances) {
            `$sessionDataPath = Join-Path -Path `$inst.FullName -ChildPath "SvrSessionData"
            if (Test-Path `$sessionDataPath) {
                Write-Host "[INFO] Cleaning Session Data: `$sessionDataPath"
                `$filesDeleted = 0
                Get-ChildItem -Path `$sessionDataPath -File | ForEach-Object { 
                    Remove-Item -Path `$_.FullName -Force 
                    `$filesDeleted++
                }
                if (`$filesDeleted -gt 0) { Write-Host "  [SUCCESS] Removed `$filesDeleted session files." }
            }
        }
    }
}
Write-Host "`n========================================="
Write-Host "             SCRIPT COMPLETED            "
Write-Host "========================================="
"@

    $VerificationScriptContent = @"
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
function Log-Msg {
    param([string]`$Msg, [ConsoleColor]`$Color = "White")
    Write-Host `$Msg -ForegroundColor `$Color
    if (`$env:LOGFILE) {
        for (`$i=0; `$i -lt 5; `$i++) {
            try { Add-Content -Path `$env:LOGFILE -Value `$Msg -Encoding ASCII -ErrorAction Stop; break }
            catch { Start-Sleep -Milliseconds 100 }
        }
    }
}

Log-Msg "[INFO] Starting DLL verification..." "Cyan"

`$prophoenixPaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    `$driveRoot = "`$(`$_.Root)Program Files\ProPhoenix"
    if (Test-Path `$driveRoot) { `$driveRoot }
}
if (-not `$prophoenixPaths) {
    Log-Msg "[ERROR] No ProPhoenix installation found." "Red"
    exit
}
Log-Msg "`n[INFO] Found base paths:" "Cyan"
`$prophoenixPaths | ForEach-Object { Log-Msg " - `$_" "Gray" }

`$excludedFolders = @("Finger Print Client","ID Scanner","Phoenix WDA V2","Police RMS","PoliceRMS","Print Server","WDA")
`$completedCount = 0; `$notCompletedCount = 0; `$totalChecked = 0

foreach (`$basePath in `$prophoenixPaths) {
    Log-Msg "`n[INFO] Scanning applications in: `$basePath" "Yellow"
    `$appFolders = Get-ChildItem -Path `$basePath -Directory -ErrorAction SilentlyContinue | Where-Object { `$excludedFolders -notcontains `$_.Name }

    foreach (`$app in `$appFolders) {
        `$instancesPath = Join-Path `$app.FullName "_Instances"
        if (Test-Path `$instancesPath) {
            `$instanceEnvs = Get-ChildItem -Path `$instancesPath -Directory -ErrorAction SilentlyContinue
            foreach (`$env in `$instanceEnvs) {
                `$baseDlls = Get-ChildItem -Path `$app.FullName -Filter *.dll -File -ErrorAction SilentlyContinue
                `$instanceDlls = Get-ChildItem -Path `$env.FullName -Filter *.dll -File -ErrorAction SilentlyContinue
                `$status = "Completed"

                foreach (`$dll in `$baseDlls) {
                    `$match = `$instanceDlls | Where-Object { `$_.Name -eq `$dll.Name }
                    if (`$match) {
                        if ((`$match.LastWriteTime -lt `$dll.LastWriteTime) -or (`$match.Length -ne `$dll.Length)) {
                            `$status = "Not Completed"; break
                        }
                    } else { `$status = "Not Completed"; break }
                }
                `$totalChecked++
                if (`$status -eq "Completed") {
                    `$completedCount++
                    Log-Msg ("[OK] " + `$app.Name + " -> " + `$env.Name + " : Completed") "Green"
                } else {
                    `$notCompletedCount++
                    Log-Msg ("[WARN] " + `$app.Name + " -> " + `$env.Name + " : Not Completed") "Red"
                }
            }
        }
    }
}
Log-Msg "`n[INFO] DLL verification completed." "Cyan"
Log-Msg "--------------------------------------" "White"
Log-Msg ("Total Verified : " + `$totalChecked) "White"
Log-Msg ("Completed      : " + `$completedCount) "Green"
Log-Msg ("Not Completed  : " + `$notCompletedCount) "Red"
Log-Msg "--------------------------------------" "White"
"@

    # --- CONFIGURATION ---
    $ClientAppsDef = @{
        "CAD Client"      = "KPI.Phoenix.CADClient.exe"
        "WDA"             = "KPI.Phoenix.CADMobileClient.exe"
        "Phoenix WDA V2" = "Phoenix.WDAV2.Client.Shell.exe"
    }

    $ServiceProductList = @(
        "JobServer", "TraCSServer", "VideoServer", "FingerPrintServer", "EmailWatcher", 
        "CADServer", "CADNLBServer", "CAD2CADTellusServer", "E911Server", "ZetronServer", 
        "ExternalInterface", "GPSServer", "NCICServer", "NCICStateServer", "FTPServer", 
        "LocutionCADVoiceServer", "DeviceNotification", "StreamingNotification", "ReportService", 
        "FolderWatcher", "DocsServer", "PhoenixTonerServer", "PhoenixAlertApp", "PhoenixTExt2Dispatch", 
        "PHOENIXAIWATCHERSERVICE", "PHOENIXJOBSVRV2"
    )

# UPDATED MAPPING DATA (FROM USER)
$RawMappingData = @"
::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "RMSRootPath" "PoliceRms=%PnxInstallPath%\Police RMS" "FireRms=%PnxInstallPath%\Fire RMS" "JobServer=%PnxInstallPath%\Job Server" "TraCSServer=%PnxInstallPath%\TraCS Server" "VideoServer=%PnxInstallPath%\Video Server" "FingerPrintServer=%PnxInstallPath%\Finger Print Server" "ReportServer=%PnxInstallPath%\Report Server" "ReportService=%PnxInstallPath%\Report Service" "PhoenixWebService=%PnxInstallPath%\WebService" "HazmatGuide=%PnxInstallPath%\User Docs" "FireWebService=%PnxInstallPath%\Fire WebService" "ProvisionManager=%PnxInstallPath%\Provision Manager" "FolderWatcher=%PnxInstallPath%\PnxFolderWatcher" "InternalAffair=%PnxInstallPath%\PhoenixIA" "NIBRS=%PnxInstallPath%\NIBRSInterface" "EmailWatcher=%PnxInstallPath%\Phoenix Email Watcher" "PoliceF1HelpDocs=%PnxInstallPath%\Police RMS\UserDocs" "FireF1HelpDocs=%PnxInstallPath%\Fire RMS\UserDocs" "IAF1HelpDocs=%PnxInstallPath%\PhoenixIA\UserDocs"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "CADRootPath" "CADServer=%PnxInstallPath%\CAD Server" "CADNLBServer=%PnxInstallPath%\CAD NLB Message Server" "E911Server=%PnxInstallPath%\E911 Server" "GPSServer=%PnxInstallPath%\GPS Server" "ZetronServer=%PnxInstallPath%\CAD Zetron Server" "TonerWIServer=%PnxInstallPath%\Toner WI Server" "ExternalInterface=%PnxInstallPath%\External Interface Server" "NCICServer=%PnxInstallPath%\NCIC Server" "NCICStateServer=%PnxInstallPath%\NCIC State Server" "KGISPDServer=%PnxInstallPath%\KGIS PD WebService" "KGISCentralServer=%PnxInstallPath%\KGIS Central WebService" "LocutionCADVoiceServer=%PnxInstallPath%\Locution CAD Voice Server" "DeviceNotification=%PnxInstallPath%\Phoenix Device Notification" "PnxWDAAppWebService=%PnxInstallPath%\WDA App webservice" "PnxWDAAppWebService=%PnxInstallPath%\Fire Response CAD Webservice" "StreamingNotification=%PnxInstallPath%\Streaming Notification" "PhoenixAlertApp=%PnxInstallPath%\Alert App" "PhoenixTExt2Dispatch=%PnxInstallPath%\Text2Dispatch" "CAD2CADTellusServer=%PnxInstallPath%\CAD2CAD Tellus Server" "ReportWriterAPI=%PnxInstallPath%\Phoenix Report Writer API"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "OtherRootPath" "CitizenServices=%PnxInstallPath%\Citizen Services Link" "InmateLookup=%PnxInstallPath%\Inmate Lookup" "WIJIS=%PnxInstallPath%\WIJIS" "SWISS=%PnxInstallPath%\SWISS" "CJIN=%PnxInstallPath%\CJIN Integration Service" "NDEX=%PnxInstallPath%\WIJIS NDEX WebService" "FTPServer=%PnxInstallPath%\FTP Server" "CRM=%PnxInstallPath%\CRM" "InmateLocator=%PnxInstallPath%\Inmate Locator" "FireCSPWCF=%PnxInstallPath%\FireCSPhoenixLink" "PoliceCSPWebAPI=%PnxInstallPath%\CitizenServices" "FireCSPWebsite=%PnxInstallPath%\FireCitizenServices" "ADRWebService=%PnxInstallPath%\ADRCollectionRepositoryWS" "WhatsNewWebService=%PnxInstallPath%\WhatsNewWebService" "DocsServer=%PnxInstallPath%\DocsServer" "PhoenixTonerServer=%PnxInstallPath%\Toner Server" "JailCellCheck=%PnxInstallPath%\Jail Cell Check App Service" "ScenePD=%PnxInstallPath%\PhoenixScenePD" "PDFService=%PnxInstallPath%\PhoenixPDFService" "DBUtility=%PnxInstallPath%\Database Utility"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "StageForClientAppsRootPath" "StageCADClient=%PnxInstallPath%\FTP\CAD Client Stage" "StageWDA=%PnxInstallPath%\FTP\WDA Stage" "StagePrintClient=%PnxInstallPath%\FTP\Print Server Stage" "StageClientAppManager=%PnxInstallPath%\FTP\Client Application Manager Stage" "StageFingerPrintClient=%PnxInstallPath%\FTP\Finger Print Client Stage" "StageIDScannerClient=%PnxInstallPath%\FTP\ID Scanner Stage" "StageStationKIOSKRFIDClient=%PnxInstallPath%\FTP\Station KIOSK RFID Client Stage" "StageRFIDClient=%PnxInstallPath%\FTP\RFID Client Stage" "StageAVLRecorder=%PnxInstallPath%\FTP\AVL Recorder Stage" "StageInOutClient=%PnxInstallPath%\FTP\In Out Client Stage" "StageZetronClient=%PnxInstallPath%\FTP\Zetron Client Stage" "StagePhoenixDashboard=%PnxInstallPath%\FTP\Phoenix Dashboard Stage" "StageMobileInspectionApp=%PnxInstallPath%\FTP\Mobile Inspection App Stage" "PHOENIXJOBSVRV2=%PnxInstallPath%\Job Server V2" "PHOENIXAIWATCHERSERVICE=%PnxInstallPath%\Phoenix AI Watcher" "PNXDIAGRAM=%PnxInstallPath%\PNXDiagram" "PNXDIAGRAMAPI=%PnxInstallPath%\PNXDiagramAPI" "INSPECTIONAPI=%PnxInstallPath%\Phoenix Inspection API" "FIRECSPCONVERSION=%PnxInstallPath%\Fire CSP Conversion" "CAMERASERVER=%PnxInstallPath%\Phoenix Camera Server" "PHOENIXPAWN=%PnxInstallPath%\Phoenix Pawn" "StagePhoenixWDAV2=%PnxInstallPath%\FTP\Phoenix WDA V2 Stage"

:: --- AUTOMATICALLY ADDED MAPPINGS (FOUND IN YOUR APPREG_MAIN.XML BUT MISSING ABOVE) ---
"PhoenixHub=%PnxInstallPath%\PhoenixHub" "PaymentGateway=%PnxInstallPath%\Payment Gateway" "Authenticator=%PnxInstallPath%\Phoenix Authenticator" "InterfaceFolderWatcher=%PnxInstallPath%\Phoenix Interface Folder Watcher" "RegionalCAD2CAD=%PnxInstallPath%\Phoenix Regional CAD2CAD Service" "CADLiveStreaming=%PnxInstallPath%\Phoenix CAD Live Streaming Service" "DBUtilityCodeBook=%PnxInstallPath%\Phoenix Database Utility CodeBook" "CRMHubAPI=%PnxInstallPath%\CRMHubAPI" "PhoenixGateway=%PnxInstallPath%\Phoenix Gateway" "CSPProcessQueue=%PnxInstallPath%\CSPProcessQueueService" "CSPConversion=%PnxInstallPath%\CSP Conversion" "AIMugMatch=%PnxInstallPath%\PhoenixAIMugMatch" "AIAPI=%PnxInstallPath%\CRMHubAPI\PNXAIAPI" "ExpenseAPI=%PnxInstallPath%\CRMHubAPI\PNXExpenseAPI" "CustomerAPI=%PnxInstallPath%\CRMHubAPI\PNXCustomerAPI" "EmploymentClient=%PnxInstallPath%\Phoenix Employment Client" "AzureFileDownloader=%PnxInstallPath%\Azure File Downloader"
"@

    Clear-Host
    Write-Host "==============================================" -ForegroundColor Yellow
    Write-Host "   ProPhoenix Hotfix Automation  (Installation Team)" -ForegroundColor Yellow
    Write-Host "   HOST: $CurrentHostName" -ForegroundColor Yellow
    Write-Host "==============================================" -ForegroundColor Yellow

    # --- 3. FIND INSTANCES ---
    $FileName = "Appreg_main.xml"
    Write-Host "`n[STEP 1] Scanning for $FileName..." -ForegroundColor Cyan

    $PossibleParents = @(
        "ProPhoenix\Server Application Manager",
        "Program Files (x86)\ProPhoenix\Server Application Manager",
        "Program Files\ProPhoenix\Server Application Manager",
        "ProPhoenix\Phoenix Server Application Manager",
        "Program Files (x86)\ProPhoenix\Phoenix Server Application Manager",
        "Program Files\ProPhoenix\Phoenix Server Application Manager"
    )
    $Drives = Get-PSDrive -PSProvider FileSystem
    $FoundFiles = @()

    foreach ($d in $Drives) {
        foreach ($folder in $PossibleParents) {
            $TestPath = Join-Path -Path $d.Root -ChildPath $folder
            $FullFilePath = Join-Path -Path $TestPath -ChildPath $FileName
            if (Test-Path $FullFilePath) { $FoundFiles += $FullFilePath }
        }
    }

    if ($FoundFiles.Count -eq 0) {
        Write-Error "No instances found on $CurrentHostName. Exiting."
        return
    }

    # --- 4. FIND CLIENT APPS ---
    Write-Host "`n[STEP 1.5] Scanning for Client Applications..." -ForegroundColor Cyan
    $ClientLaunchLogic = ""
    $CommonRoots = @(
        "ProPhoenix", "Program Files\ProPhoenix", "Program Files (x86)\ProPhoenix"
    )

    foreach ($key in ($ClientAppsDef.Keys | Sort-Object)) {
        $FolderName = $key
        $ExeName = $ClientAppsDef[$key]
        $FoundClient = $false
        foreach ($d in $Drives) {
            foreach ($root in $CommonRoots) {
                $TryPath = Join-Path -Path $d.Root -ChildPath $root | Join-Path -ChildPath $FolderName | Join-Path -ChildPath $ExeName
                if (Test-Path $TryPath) {
                    Write-Host "  [FOUND] $FolderName -> $TryPath" -ForegroundColor Green
                    
                    $ClientLaunchLogic += "echo Launching $FolderName...`r`n"
                    $ClientLaunchLogic += "echo [LOG] Launching $FolderName... >> %LOGFILE%`r`n"
                    
                    $PSCommand = "
                    `$path = '$TryPath'; 
                    `$desktop = [Environment]::GetFolderPath('Desktop'); 
                    `$public = [Environment]::GetFolderPath('CommonDesktopDirectory'); 
                    `$shell = New-Object -ComObject WScript.Shell; 
                    `$shortcut = Get-ChildItem -Path `$desktop, `$public -Filter '*.lnk' | Where-Object { `$shell.CreateShortcut(`$_.FullName).TargetPath -eq `$path } | Select-Object -First 1; 
                    if (`$shortcut) { Start-Process `$shortcut.FullName -Verb RunAs; } else { Start-Process `$path -Verb RunAs; }"
                    
                    $PSCommandFlat = $PSCommand -replace "`r`n", " " -replace "\s+", " "
                    $ClientLaunchLogic += "%PSExe% -WindowStyle Hidden -Command `"$PSCommandFlat`"`r`n"
                    
                    $FoundClient = $true
                    break
                }
            }
            if ($FoundClient) { break }
        }
    }

    # --- 5. PROCESS LOOP ---
    $InstanceCount = 1
    $GeneratedBatFiles = @()

    foreach ($FoundPath in $FoundFiles) {
        Write-Host "`n--------------------------------------------------" -ForegroundColor Yellow
        Write-Host " PROCESSING INSTANCE #$InstanceCount" -ForegroundColor Yellow
        Write-Host " Source: $FoundPath" -ForegroundColor Gray
        Write-Host "--------------------------------------------------" -ForegroundColor Yellow
        
        $InstallDrive = (Split-Path $FoundPath -Qualifier)
        $AppMgrFolder = (Split-Path $FoundPath -Parent)
        
        $LogDir = Join-Path -Path $AppMgrFolder -ChildPath "PnxLog\PrintLog"
        if (-not (Test-Path $LogDir)) { try { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null } catch {} }
        if (-not (Test-Path $LogDir)) { $LogDir = $env:TEMP }
        $LogFileName = "InstallGen_Inst${InstanceCount}_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $LogFile = Join-Path -Path $LogDir -ChildPath $LogFileName

        $LogMsg = {
            param([string]$Msg, [string]$Lvl="INFO", [string]$Clr="White")
            $TS = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content -Path $LogFile -Value "[$TS] [$Lvl] $Msg"
            Write-Host $Msg -ForegroundColor $Clr
        }
        & $LogMsg -Msg "Logging started: $LogFile" -Clr Cyan

        # Backup XML
        Write-Host "`n[STEP 2] Backing up Configuration..." -ForegroundColor Cyan
        $BackupFile = "$FoundPath.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
        try {
            Copy-Item -Path $FoundPath -Destination $BackupFile -ErrorAction Stop
            & $LogMsg -Msg "Backup created: $BackupFile" -Lvl SUCCESS -Clr Green
        } catch { & $LogMsg -Msg "Backup Failed" -Lvl ERROR -Clr Red; continue }

        # Prepare PnxTemp
        Write-Host "`n[STEP 3] Preparing PnxTemp & Helper Scripts..." -ForegroundColor Cyan
        $PnxTempPath = Join-Path -Path (Split-Path $AppMgrFolder -Parent) -ChildPath "PnxTemp"
        if (-not (Test-Path $PnxTempPath)) { try { New-Item -ItemType Directory -Path $PnxTempPath -Force | Out-Null } catch {} }

        # Write Helper Scripts (FORCE ASCII)
        Set-Content -Path (Join-Path $PnxTempPath "LogClear.ps1") -Value $LogClearScriptContent -Encoding ASCII
        Set-Content -Path (Join-Path $PnxTempPath "InstanceVerification.ps1") -Value $VerificationScriptContent -Encoding ASCII

        # Parse Mappings
        Write-Host "`n[STEP 4] Analyzing Products..." -ForegroundColor Cyan
        $PathMap = @{}
        $Regex = '"([^"]+)=%PnxInstallPath%\\([^"]+)"'
        foreach ($m in [regex]::Matches($RawMappingData, $Regex)) {
            $ShortID = $m.Groups[1].Value
            $Suffix = $m.Groups[2].Value.Replace("/", "\").Trim()
            if (-not $PathMap.ContainsKey($Suffix)) { $PathMap[$Suffix] = $ShortID }
        }

        try { [xml]$xmlData = Get-Content $FoundPath } catch { & $LogMsg -Msg "Invalid XML" -Lvl ERROR -Clr Red; continue }
        
        $InstallArgs = new-object System.Collections.Generic.List[string]
        $UpdateArgs  = new-object System.Collections.Generic.List[string]
        $InstallArgs.Add('"INSTALL"')
        $UpdateArgs.Add('"UPDATEINSTANCE"')

        if ($xmlData.PhoenixApplications.AppReg) {
            foreach ($app in $xmlData.PhoenixApplications.AppReg) {
                $Ver = $app.CurrentVersion
                $FPath = $app.AppPath.Replace("/", "\").Trim()
                if ($Ver -ne "0.0.0.0") {
                    $BestID = $null; $BestLen = 0
                    foreach ($k in $PathMap.Keys) {
                        if ($FPath.EndsWith($k, [System.StringComparison]::OrdinalIgnoreCase)) {
                            if ($k.Length -gt $BestLen) { $BestID = $PathMap[$k]; $BestLen = $k.Length }
                        }
                    }
                    if ($BestID) {
                        $InstallArgs.Add("`"$BestID`"")
                        if ($ServiceProductList -contains $BestID) { $UpdateArgs.Add("`"$BestID`"") }
                        & $LogMsg -Msg "Included: $($app.AppName) -> $BestID" -Lvl SUCCESS -Clr Green
                    } else { & $LogMsg -Msg "Skipped: $($app.AppName)" -Lvl WARN -Clr Yellow }
                }
            }
        }

        # Generate Batch File (DYNAMIC NAMING)
        Write-Host "`n[STEP 5] Generating Final Script..." -ForegroundColor Cyan
        $InstallLine = $InstallArgs -join " "
        $UpdateLine  = $UpdateArgs -join " "
        
        $BaseName = "${CurrentHostName}_Hotfix_Automation"; $Ext = ".bat"; $Counter = 0
        $FinalName = "$BaseName$Ext"
        $OutputBatFile = Join-Path -Path $PnxTempPath -ChildPath $FinalName
        while (Test-Path $OutputBatFile) {
            $Counter++; $FinalName = "${BaseName}${Counter}${Ext}"; $OutputBatFile = Join-Path -Path $PnxTempPath -ChildPath $FinalName
        }

        # Add to tracking list for "Run Now" prompt
        $GeneratedBatFiles += $OutputBatFile

        $PathParts = $AppMgrFolder.Split('\')
        $CdBlock = "$InstallDrive`r`ncd ..\..\`r`n"
        for ($i = 1; $i -lt $PathParts.Count; $i++) { if ($PathParts[$i]) { $CdBlock += "cd `"$($PathParts[$i])`"`r`n" } }

        $UpdateCmd = ""
        if ($UpdateArgs.Count -gt 1) {
            # FIX: Replaced Tee-Object with compatible method
            $UpdateCmd = "::Script - Updating Windows Service Instance`r`n%AppMgrExePath%\PnxAppMgr.exe $UpdateLine | %PSExe% -Command `"`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }`"`r`n"
        }

        $BatchContent = @"
$CdBlock
@echo off
SET AppMgrExePath="$AppMgrFolder"
SET PSExe=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe

:: --- NEW LOG FILE PER RUN (Timestamped) ---
set "timestamp=%DATE:/=-%_%TIME::=-%"
set "timestamp=%timestamp: =0%"
set LOGFILE="%~dp0Install_Log_%timestamp%.txt"

echo Logging Execution to: %LOGFILE%
echo --- Installation Started --- > %LOGFILE%

echo ===================================================
echo   STEP 1: STOPPING SERVICES AND PROCESSES
echo ===================================================
echo [LOG] Stopping IIS... >> %LOGFILE%
%windir%\System32\iisreset.exe /stop | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1
%windir%\System32\sc.exe query W3SVC | find "STATE" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo Killing Client Applications (if running)...
echo [LOG] Killing Client Apps... >> %LOGFILE%
%windir%\System32\taskkill.exe /F /IM "KPI.Phoenix.CADClient.exe" /T 2>nul >> %LOGFILE% 2>&1
%windir%\System32\taskkill.exe /F /IM "KPI.Phoenix.CADMobileClient.exe" /T 2>nul >> %LOGFILE% 2>&1
%windir%\System32\taskkill.exe /F /IM "Phoenix.WDAV2.Client.Shell.exe" /T 2>nul >> %LOGFILE% 2>&1

echo Stopping Phoenix Services...
echo [LOG] Stopping Phoenix Services... >> %LOGFILE%
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name `$_.Name -Force }" >> %LOGFILE% 2>&1

echo ===================================================
echo   STEP 2: CLEANING LOGS AND SESSION DATA
echo ===================================================
echo Running Cleaner Script...
echo [LOG] Running LogClear.ps1... >> %LOGFILE%
%PSExe% -ExecutionPolicy Bypass -File "%~dp0LogClear.ps1" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo ===================================================
echo   STEP 3: UPDATING APP MANAGER AND INSTALLATION
echo ===================================================

::Script - Updating Application Manager
echo [LOG] Updating Application Manager... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe "UPDAPPMANAGER" 
echo Waiting 5 minutes for App Manager to settle...
timeout 300 > NUL

:loopSelf
%windir%\System32\tasklist.exe /fi "imagename eq PnxAppMgr.exe" |find ":" > nul
if "%ERRORLEVEL%"=="1" goto loopSelf

::Script - Installing products
echo [LOG] Running PnxAppMgr Install... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe $InstallLine | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo ===================================================
echo   STEP 4: STARTING IIS AND UPDATING INSTANCES
echo ===================================================
echo Starting IIS...
echo [LOG] Starting IIS... >> %LOGFILE%
%windir%\System32\iisreset.exe /start | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1
%windir%\System32\sc.exe query W3SVC | find "STATE" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo [LOG] Updating Windows Instances... >> %LOGFILE%
$UpdateCmd

echo ===================================================
echo   STEP 4.5: STARTING PHOENIX SERVICES
echo ===================================================
echo Starting Phoenix Services...
echo [LOG] Starting Phoenix Services... >> %LOGFILE%
:: SAFETY PAUSE: Wait 5 seconds
timeout /t 5 >nul

:: CRASH-PROOF SERVICE START (Using Out-File -Encoding ASCII for safety)
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -ne 'Running' } | ForEach-Object { try { Start-Service -Name `$_.Name -ErrorAction Stop; Write-Host 'Started ' `$_.Name } catch { Write-Host 'Failed to start ' `$_.Name `$_.Exception.Message } }" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo ===================================================
echo   STEP 4.6: REPORTING INSTANCE STATUS
echo ===================================================
echo [LOG] Reporting Instance Status... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe "SHOWINSTANCES" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo ===================================================
echo   STEP 4.7: VERIFYING DLL UPDATES
echo ===================================================
echo Running Instance Verification...
echo [LOG] Running Instance Verification... >> %LOGFILE%
:: --- FIXED LOGGING: Internal Script Handles Logging to %LOGFILE% ---
%PSExe% -ExecutionPolicy Bypass -File "%~dp0InstanceVerification.ps1"

echo.
echo ===================================================
echo   VERIFICATION COMPLETE.
echo   Press any key to proceed to Client Launch...
pause >nul
echo ===================================================
echo   STEP 5: LAUNCHING CLIENT APPLICATIONS
echo ===================================================
echo [LOG] Launching Clients... >> %LOGFILE%
$ClientLaunchLogic

echo.
echo Process Complete. Log saved to: %LOGFILE%
echo Press any key to close...
pause >nul
::End of Script::
"@

        try {
            Set-Content -Path $OutputBatFile -Value $BatchContent -Encoding ASCII
            & $LogMsg -Msg "SUCCESS! Script created at: $OutputBatFile" -Lvl SUCCESS -Clr Green
        } catch { & $LogMsg -Msg "Failed to write BAT file" -Lvl ERROR -Clr Red }

        $InstanceCount++
    }
    
    # RETURN Generated Files for the Controller to use
    return $GeneratedBatFiles
}

# ==============================================================================
#  3. EXECUTION CONTROLLER
# ==============================================================================
if ($RunRemote) {
    # Prompt for credentials safely
    $Creds = Get-Credential
    Write-Host "Connecting to $TargetServer..." -ForegroundColor Cyan
    try {
        Invoke-Command -ComputerName $TargetServer -Credential $Creds -ScriptBlock $GeneratorLogic
        Write-Host "`n[INFO] Files generated on REMOTE server ($TargetServer)." -ForegroundColor Yellow
        Write-Host "       You must log in to the remote server to run them."
    } catch {
        Write-Error "Connection failed. Please check Server Name and Credentials."
        Write-Error $_
    }
} else {
    Write-Host "Executing Locally..." -ForegroundColor Green
    $LocalBatFiles = & $GeneratorLogic
    
    # --- RUN NOW PROMPT (Local Only) ---
    if ($LocalBatFiles.Count -gt 0) {
        $RunChoice = Read-Host "`n[QUESTION] Would you like to run the Hotfix Automation file(s) now? (Y/N)"
        if ($RunChoice -eq "Y") {
            foreach ($bat in $LocalBatFiles) {
                Write-Host "Launching as Administrator: $bat ..." -ForegroundColor Green
                # -Verb RunAs triggers "Run as Administrator"
                Start-Process -FilePath $bat -Verb RunAs
            }
        }
    }
}
'@

# --- WRITE FILES ---
try {
    Set-Content -Path $File_HotfixProd -Value $Content_HotfixProd -Encoding ASCII -Force
    Write-Host " [OK] Hotfix Production Script Created." -ForegroundColor Green
    Set-Content -Path $File_DBSync -Value $Content_DBSync -Encoding ASCII -Force
    Write-Host " [OK] DB Sync Script Created." -ForegroundColor Green
    Set-Content -Path $File_PreComp -Value $Content_PreComp -Encoding ASCII -Force
    Write-Host " [OK] Precompiler Script Created." -ForegroundColor Green
    Set-Content -Path $File_HotfixInst -Value $Content_HotfixInst -Encoding ASCII -Force
    Write-Host " [OK] Hotfix Installation Script Created." -ForegroundColor Green
} catch {
    Write-Error "Failed to write scripts to $ScriptDir. Check permissions."
    Pause; Break
}

# ==============================================================================
#  MAIN MENU LOOP
# ==============================================================================
function Show-Menu {
    Clear-Host
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "   ProPhoenix MASTER AUTOMATION TOOL" -ForegroundColor Cyan
    Write-Host "==============================================" -ForegroundColor Cyan
    Write-Host "1. Hotfix Automation (CAD Production)"
    Write-Host "2. Hotfix Automation (Test / Demo)"
    Write-Host "3. DB Sync Utility"
    Write-Host "4. Precompiler URL Config"
    Write-Host "----------------------------------------------"
    Write-Host "5. Open Scripts Folder"
    Write-Host "Q. Quit"
    Write-Host "==============================================" -ForegroundColor Cyan
}

Do {
    Show-Menu
    $Input = Read-Host "Select an option"
    
    Switch ($Input) {
        '1' { 
            Write-Host "Launching Hotfix Production..." -ForegroundColor Yellow
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$File_HotfixProd`"" -Verb RunAs
        }
        '2' { 
            Write-Host "Launching Hotfix Installation..." -ForegroundColor Yellow
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$File_HotfixInst`"" -Verb RunAs
        }
        '3' { 
            Write-Host "Launching DB Sync..." -ForegroundColor Yellow
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$File_DBSync`"" -Verb RunAs
        }
        '4' { 
            Write-Host "Launching Precompiler Config..." -ForegroundColor Yellow
            Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -File `"$File_PreComp`"" -Verb RunAs
        }
        '5' { 
            Invoke-Item $ScriptDir 
        }
        'Q' { 
            Write-Host "Exiting..."; break 
        }
        Default { 
            Write-Host "Invalid selection." -ForegroundColor Red; Start-Sleep -Seconds 1 
        }
    }
} Until ($Input -eq 'Q')