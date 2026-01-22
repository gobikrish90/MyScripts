<#
.SYNOPSIS
    ProPhoenix Hotfix Automation (Production / Installation Team).
    
    UPDATES:
    1. LOGIC: Removed "Log Clear". KEPT "SvrSessionData Clear".
    2. FEATURE: Scans PnxConfigMgr.exe.config for "UpdateUserName" and "UpdateLocation".
    3. BATCH: Changed batch file start to "cd ../../../../".
    4. VERIFICATION: Keeps existing 13/13 verification logic.
#>

# ==============================================================================
#  1. INTERACTIVE PROMPT
# ==============================================================================
Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   ProPhoenix Hotfix Automation (PRODUCTION)  " -ForegroundColor Cyan
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
    
    # 1. CLEANUP SCRIPT (SVR SESSION DATA ONLY)
    $SessionClearScriptContent = @"
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
Write-Host "========================================="
Write-Host "      CLEANUP UTILITY (Session Data)     "
Write-Host "========================================="

`$proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    "`$(`$_.Root)\Program Files\ProPhoenix"
} | Where-Object { Test-Path -Path `$_ }

if (`$proPhoenixBasePaths.Count -eq 0) { Write-Host "[WARN] No ProPhoenix Root found."; exit }

Write-Host "[INFO] Clearing SvrSessionData..."
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
Write-Host "[SUCCESS] Session Cleanup Complete."
"@

    # 2. VERIFICATION SCRIPT
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

$RawMappingData = @"
::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "RMSRootPath" "PoliceRms=%PnxInstallPath%\Police RMS" "FireRms=%PnxInstallPath%\Fire RMS" "JobServer=%PnxInstallPath%\Job Server" "TraCSServer=%PnxInstallPath%\TraCS Server" "VideoServer=%PnxInstallPath%\Video Server" "FingerPrintServer=%PnxInstallPath%\Finger Print Server" "ReportServer=%PnxInstallPath%\Report Server" "ReportService=%PnxInstallPath%\Report Service" "PhoenixWebService=%PnxInstallPath%\WebService" "HazmatGuide=%PnxInstallPath%\User Docs" "FireWebService=%PnxInstallPath%\Fire WebService" "ProvisionManager=%PnxInstallPath%\Provision Manager" "FolderWatcher=%PnxInstallPath%\PnxFolderWatcher" "InternalAffair=%PnxInstallPath%\PhoenixIA" "NIBRS=%PnxInstallPath%\NIBRSInterface" "EmailWatcher=%PnxInstallPath%\Phoenix Email Watcher" "PoliceF1HelpDocs=%PnxInstallPath%\Police RMS\UserDocs" "FireF1HelpDocs=%PnxInstallPath%\Fire RMS\UserDocs" "IAF1HelpDocs=%PnxInstallPath%\PhoenixIA\UserDocs"
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "CADRootPath" "CADServer=%PnxInstallPath%\CAD Server" "CADNLBServer=%PnxInstallPath%\CAD NLB Message Server" "E911Server=%PnxInstallPath%\E911 Server" "GPSServer=%PnxInstallPath%\GPS Server" "ZetronServer=%PnxInstallPath%\CAD Zetron Server" "TonerWIServer=%PnxInstallPath%\Toner WI Server" "ExternalInterface=%PnxInstallPath%\External Interface Server" "NCICServer=%PnxInstallPath%\NCIC Server" "NCICStateServer=%PnxInstallPath%\NCIC State Server" "KGISPDServer=%PnxInstallPath%\KGIS PD WebService" "KGISCentralServer=%PnxInstallPath%\KGIS Central WebService" "LocutionCADVoiceServer=%PnxInstallPath%\Locution CAD Voice Server" "DeviceNotification=%PnxInstallPath%\Phoenix Device Notification" "PnxWDAAppWebService=%PnxInstallPath%\WDA App webservice" "PnxWDAAppWebService=%PnxInstallPath%\Fire Response CAD Webservice" "StreamingNotification=%PnxInstallPath%\Streaming Notification" "PhoenixAlertApp=%PnxInstallPath%\Alert App" "PhoenixTExt2Dispatch=%PnxInstallPath%\Text2Dispatch" "CAD2CADTellusServer=%PnxInstallPath%\CAD2CAD Tellus Server" "ReportWriterAPI=%PnxInstallPath%\Phoenix Report Writer API"
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "OtherRootPath" "CitizenServices=%PnxInstallPath%\Citizen Services Link" "InmateLookup=%PnxInstallPath%\Inmate Lookup" "WIJIS=%PnxInstallPath%\WIJIS" "SWISS=%PnxInstallPath%\SWISS" "CJIN=%PnxInstallPath%\CJIN Integration Service" "NDEX=%PnxInstallPath%\WIJIS NDEX WebService" "FTPServer=%PnxInstallPath%\FTP Server" "CRM=%PnxInstallPath%\CRM" "InmateLocator=%PnxInstallPath%\Inmate Locator" "FireCSPWCF=%PnxInstallPath%\FireCSPhoenixLink" "PoliceCSPWebAPI=%PnxInstallPath%\CitizenServices" "FireCSPWebsite=%PnxInstallPath%\FireCitizenServices" "ADRWebService=%PnxInstallPath%\ADRCollectionRepositoryWS" "WhatsNewWebService=%PnxInstallPath%\WhatsNewWebService" "DocsServer=%PnxInstallPath%\DocsServer" "PhoenixTonerServer=%PnxInstallPath%\Toner Server" "JailCellCheck=%PnxInstallPath%\Jail Cell Check App Service" "ScenePD=%PnxInstallPath%\PhoenixScenePD" "PDFService=%PnxInstallPath%\PhoenixPDFService" "DBUtility=%PnxInstallPath%\Database Utility"
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "StageForClientAppsRootPath" "StageCADClient=%PnxInstallPath%\FTP\CAD Client Stage" "StageWDA=%PnxInstallPath%\FTP\WDA Stage" "StagePrintClient=%PnxInstallPath%\FTP\Print Server Stage" "StageClientAppManager=%PnxInstallPath%\FTP\Client Application Manager Stage" "StageFingerPrintClient=%PnxInstallPath%\FTP\Finger Print Client Stage" "StageIDScannerClient=%PnxInstallPath%\FTP\ID Scanner Stage" "StageStationKIOSKRFIDClient=%PnxInstallPath%\FTP\Station KIOSK RFID Client Stage" "StageRFIDClient=%PnxInstallPath%\FTP\RFID Client Stage" "StageAVLRecorder=%PnxInstallPath%\FTP\AVL Recorder Stage" "StageInOutClient=%PnxInstallPath%\FTP\In Out Client Stage" "StageZetronClient=%PnxInstallPath%\FTP\Zetron Client Stage" "StagePhoenixDashboard=%PnxInstallPath%\FTP\Phoenix Dashboard Stage" "StageMobileInspectionApp=%PnxInstallPath%\FTP\Mobile Inspection App Stage" "PHOENIXJOBSVRV2=%PnxInstallPath%\Job Server V2" "PHOENIXAIWATCHERSERVICE=%PnxInstallPath%\Phoenix AI Watcher" "PNXDIAGRAM=%PnxInstallPath%\PNXDiagram" "PNXDIAGRAMAPI=%PnxInstallPath%\PNXDiagramAPI" "INSPECTIONAPI=%PnxInstallPath%\Phoenix Inspection API" "FIRECSPCONVERSION=%PnxInstallPath%\Fire CSP Conversion" "CAMERASERVER=%PnxInstallPath%\Phoenix Camera Server" "PHOENIXPAWN=%PnxInstallPath%\Phoenix Pawn" "StagePhoenixWDAV2=%PnxInstallPath%\FTP\Phoenix WDA V2 Stage"
"PhoenixHub=%PnxInstallPath%\PhoenixHub" "PaymentGateway=%PnxInstallPath%\Payment Gateway" "Authenticator=%PnxInstallPath%\Phoenix Authenticator" "InterfaceFolderWatcher=%PnxInstallPath%\Phoenix Interface Folder Watcher" "RegionalCAD2CAD=%PnxInstallPath%\Phoenix Regional CAD2CAD Service" "CADLiveStreaming=%PnxInstallPath%\Phoenix CAD Live Streaming Service" "DBUtilityCodeBook=%PnxInstallPath%\Phoenix Database Utility CodeBook" "CRMHubAPI=%PnxInstallPath%\CRMHubAPI" "PhoenixGateway=%PnxInstallPath%\Phoenix Gateway" "CSPProcessQueue=%PnxInstallPath%\CSPProcessQueueService" "CSPConversion=%PnxInstallPath%\CSP Conversion" "AIMugMatch=%PnxInstallPath%\PhoenixAIMugMatch" "AIAPI=%PnxInstallPath%\CRMHubAPI\PNXAIAPI" "ExpenseAPI=%PnxInstallPath%\CRMHubAPI\PNXExpenseAPI" "CustomerAPI=%PnxInstallPath%\CRMHubAPI\PNXCustomerAPI" "EmploymentClient=%PnxInstallPath%\Phoenix Employment Client" "AzureFileDownloader=%PnxInstallPath%\Azure File Downloader"
"@

    Clear-Host
    Write-Host "==============================================" -ForegroundColor Yellow
    Write-Host "   ProPhoenix Hotfix Automation (Generation)  " -ForegroundColor Yellow
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
        
        # --- NEW LOGIC: FIND UPDATER SETTINGS ---
        $ConfigFileName = "PnxConfigMgr.exe.config"
        $ConfigFound = $false
        $UpdUser = "N/A"
        $UpdLoc = "N/A"
        
        # Look for Config in AppMgr Folder or siblings
        $PossibleConfigPaths = @(
            Join-Path $AppMgrFolder $ConfigFileName,
            (Join-Path (Split-Path $AppMgrFolder -Parent) "Server Application Manager\$ConfigFileName"),
            (Join-Path (Split-Path $AppMgrFolder -Parent) "Phoenix Server Application Manager\$ConfigFileName")
        )

        foreach ($cfgPath in $PossibleConfigPaths) {
            if (Test-Path $cfgPath) {
                try {
                    [xml]$cfgXml = Get-Content $cfgPath
                    $UpdUserNode = $cfgXml.configuration.appSettings.add | Where-Object { $_.key -eq "UpdateUserName" }
                    $UpdLocNode  = $cfgXml.configuration.appSettings.add | Where-Object { $_.key -eq "UpdateLocation" }
                    if ($UpdUserNode) { $UpdUser = $UpdUserNode.value }
                    if ($UpdLocNode)  { $UpdLoc = $UpdLocNode.value }
                    $ConfigFound = $true
                    break
                } catch {}
            }
        }

        # --- DISPLAY UPDATER SETTINGS ---
        Write-Host "----------------------------------------------" -ForegroundColor Cyan
        Write-Host " UPDATER SETTINGS FOUND:" -ForegroundColor Cyan
        Write-Host "   User     : $UpdUser" -ForegroundColor White
        Write-Host "   Location : $UpdLoc" -ForegroundColor White
        Write-Host "----------------------------------------------" -ForegroundColor Cyan

        
        # Prepare PnxTemp & Scripts
        $PnxTempPath = Join-Path -Path (Split-Path $AppMgrFolder -Parent) -ChildPath "PnxTemp"
        if (-not (Test-Path $PnxTempPath)) { try { New-Item -ItemType Directory -Path $PnxTempPath -Force | Out-Null } catch {} }
        # NOTE: Using SessionClearScript now (No Logs)
        Set-Content -Path (Join-Path $PnxTempPath "SessionClear.ps1") -Value $SessionClearScriptContent -Encoding ASCII
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
        # NOTE: Added cd ../../../../ as requested
        $BatchContent = @"
$InstallDrive
cd ../../../../
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
echo [INFO] Updater User: $UpdUser >> %LOGFILE%
echo [INFO] Updater Loc : $UpdLoc >> %LOGFILE%

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
echo   STEP 3: STOPPING SERVICES (MAINTENANCE START)
echo ===================================================
echo [LOG] Stopping Services... >> %LOGFILE%
%windir%\System32\iisreset.exe /stop >> %LOGFILE% 2>&1
%windir%\System32\taskkill.exe /F /IM "KPI.Phoenix.CADClient.exe" /T 2>nul >> %LOGFILE% 2>&1
%windir%\System32\taskkill.exe /F /IM "KPI.Phoenix.CADMobileClient.exe" /T 2>nul >> %LOGFILE% 2>&1
%windir%\System32\taskkill.exe /F /IM "Phoenix.WDAV2.Client.Shell.exe" /T 2>nul >> %LOGFILE% 2>&1
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name `$_.Name -Force; Write-Host 'Stopped ' `$_.Name }" >> %LOGFILE% 2>&1

echo.
echo ===================================================
echo   STEP 4: CLEANUP (SVR SESSION DATA ONLY)
echo ===================================================
echo [LOG] Cleaning Session Data... >> %LOGFILE%
%PSExe% -ExecutionPolicy Bypass -File "%~dp0SessionClear.ps1" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

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
echo   STEP 6.5: REPORTING INSTANCE STATUS
echo ===================================================
echo [LOG] Reporting Instance Status... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe "SHOWINSTANCES" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   STEP 7: VERIFICATION AND CLIENT LAUNCH
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
        # --- FILE NAMING (1, 2, 3...) ---
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