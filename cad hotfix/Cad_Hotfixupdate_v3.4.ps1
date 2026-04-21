<#
.SYNOPSIS
    ProPhoenix Hotfix Automation (Production / Installation Team).
    
    FINAL CHANGE LOG:
    1. BUG FIX: Completely removed the residual regex "-replace" line that contained hidden emojis. This stops the "Invalid Regular Expression ?" red font error during Instance Verification.
    2. ORDER: App Manager Update -> Step 1.
    3. EXCLUSIONS: Always skips "Hub" and "Gateway".
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
    
    # 1. CLEANUP SCRIPT
    $SessionClearScriptContent = @"
try { [Console]::OutputEncoding = [System.Text.Encoding]::ASCII } catch {}
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

    # 2. VERIFICATION SCRIPT (REGEX BUG COMPLETELY FIXED)
    $VerificationScriptContent = @"
# -----------------------------------------------
# DLL Verification Script for ProPhoenix Applications
# -----------------------------------------------
try { [Console]::OutputEncoding = [System.Text.Encoding]::ASCII } catch {}

# Sanitize Log Path
`$cleanLogFile = `$env:LOGFILE -replace '"', ''

# Helper to write to Screen (Color) AND File (Plain)
function Log-Msg {
    param([string]`$Msg, [ConsoleColor]`$Color = "White", [bool]`$NoFile = `$false)
    
    Write-Host `$Msg -ForegroundColor `$Color
    
    if (`$cleanLogFile -and -not `$NoFile) {
        # Directly output to file. No replacement regex needed anymore.
        `$Msg | Out-File -FilePath `$cleanLogFile -Append -Encoding ASCII -ErrorAction SilentlyContinue
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
`$prophoenixPaths | ForEach-Object { Log-Msg " - `$_" }

`$excludedFolders = @("Finger Print Client","ID Scanner","Phoenix WDA V2","Police RMS","PoliceRMS","Print Server","WDA")

`$completedCount = 0
`$notCompletedCount = 0
`$totalChecked = 0

foreach (`$basePath in `$prophoenixPaths) {
    Log-Msg "`n[INFO] Scanning applications in: `$basePath" "Yellow"

    `$appFolders = Get-ChildItem -Path `$basePath -Directory -ErrorAction SilentlyContinue |
                  Where-Object { `$excludedFolders -notcontains `$_.Name }

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
                            `$status = "Not Completed"
                            break
                        }
                    } else {
                        `$status = "Not Completed"
                        break
                    }
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
Log-Msg "--------------------------------------"
Log-Msg ("Total Verified : " + `$totalChecked)
Log-Msg ("Completed      : " + `$completedCount) "Green"
Log-Msg ("Not Completed  : " + `$notCompletedCount) "Red"
Log-Msg "--------------------------------------"
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
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "CADRootPath" "CADServer=%PnxInstallPath%\CAD Server" "CADNLBServer=%PnxInstallPath%\CAD NLB Message Server" "E911Server=%PnxInstallPath%\E911 Server" "GPSServer=%PnxInstallPath%\GPS Server" "ZetronServer=%PnxInstallPath%\CAD Zetron Server" "TonerWIServer=%PnxInstallPath%\Toner WI Server" "ExternalInterface=%PnxInstallPath%\External Interface Server" "NCICServer=%PnxInstallPath%\NCIC Server" "NCICStateServer=%PnxInstallPath%\NCIC State Server" "KGISPDServer=%PnxInstallPath%\KGIS PD WebService" "KGISCentralServer=%PnxInstallPath%\KGIS Central WebService" "LocutionCADVoiceServer=%PnxInstallPath%\Locution CAD Voice Server" "DeviceNotification=%PnxInstallPath%\Phoenix Device Notification" "DeviceNotification=%PnxInstallPath%\Device Notification Server" "PnxWDAAppWebService=%PnxInstallPath%\WDA App webservice" "PnxWDAAppWebService=%PnxInstallPath%\Fire Response CAD Webservice" "StreamingNotification=%PnxInstallPath%\Streaming Notification" "PhoenixAlertApp=%PnxInstallPath%\Alert App" "PhoenixTExt2Dispatch=%PnxInstallPath%\Text2Dispatch" "PhoenixTExt2Dispatch=%PnxInstallPath%\CADText2Dispatch" "PhoenixTExt2Dispatch=%PnxInstallPath%\CADTxt2Dispatch" "PhoenixTExt2Dispatch=%PnxInstallPath%\Txt2Dispatch" "CAD2CADTellusServer=%PnxInstallPath%\CAD2CAD Tellus Server" "ReportWriterAPI=%PnxInstallPath%\Phoenix Report Writer API"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "OtherRootPath" "CitizenServices=%PnxInstallPath%\Citizen Services Link" "InmateLookup=%PnxInstallPath%\Inmate Lookup" "WIJIS=%PnxInstallPath%\WIJIS" "SWISS=%PnxInstallPath%\SWISS" "CJIN=%PnxInstallPath%\CJIN Integration Service" "NDEX=%PnxInstallPath%\WIJIS NDEX WebService" "FTPServer=%PnxInstallPath%\FTP Server" "CRM=%PnxInstallPath%\CRM" "InmateLocator=%PnxInstallPath%\Inmate Locator" "FireCSPWCF=%PnxInstallPath%\FireCSPhoenixLink" "PoliceCSPWebAPI=%PnxInstallPath%\CitizenServices" "FireCSPWebsite=%PnxInstallPath%\FireCitizenServices" "ADRWebService=%PnxInstallPath%\ADRCollectionRepositoryWS" "WhatsNewWebService=%PnxInstallPath%\WhatsNewWebService" "DocsServer=%PnxInstallPath%\DocsServer" "PhoenixTonerServer=%PnxInstallPath%\Toner Server" "JailCellCheck=%PnxInstallPath%\Jail Cell Check App Service" "ScenePD=%PnxInstallPath%\PhoenixScenePD" "PDFService=%PnxInstallPath%\PhoenixPDFService" "PDFService=%PnxInstallPath%\Phoenix PDF Service" "DBUtility=%PnxInstallPath%\Database Utility"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "StageForClientAppsRootPath" "StageCADClient=%PnxInstallPath%\FTP\CAD Client Stage" "StageWDA=%PnxInstallPath%\FTP\WDA Stage" "StagePrintClient=%PnxInstallPath%\FTP\Print Server Stage" "StageClientAppManager=%PnxInstallPath%\FTP\Client Application Manager Stage" "StageFingerPrintClient=%PnxInstallPath%\FTP\Finger Print Client Stage" "StageIDScannerClient=%PnxInstallPath%\FTP\ID Scanner Stage" "StageStationKIOSKRFIDClient=%PnxInstallPath%\FTP\Station KIOSK RFID Client Stage" "StageRFIDClient=%PnxInstallPath%\FTP\RFID Client Stage" "StageAVLRecorder=%PnxInstallPath%\FTP\AVL Recorder Stage" "StageInOutClient=%PnxInstallPath%\FTP\In Out Client Stage" "StageZetronClient=%PnxInstallPath%\FTP\Zetron Client Stage" "StagePhoenixDashboard=%PnxInstallPath%\FTP\Phoenix Dashboard Stage" "StageMobileInspectionApp=%PnxInstallPath%\FTP\Mobile Inspection App Stage" "PHOENIXJOBSVRV2=%PnxInstallPath%\Job Server V2" "PHOENIXAIWATCHERSERVICE=%PnxInstallPath%\Phoenix AI Watcher" "PNXDIAGRAM=%PnxInstallPath%\PNXDiagram" "PNXDIAGRAMAPI=%PnxInstallPath%\PNXDiagramAPI" "INSPECTIONAPI=%PnxInstallPath%\Phoenix Inspection API" "FIRECSPCONVERSION=%PnxInstallPath%\Fire CSP Conversion" "CAMERASERVER=%PnxInstallPath%\Phoenix Camera Server" "PHOENIXPAWN=%PnxInstallPath%\Phoenix Pawn" "StagePhoenixWDAV2=%PnxInstallPath%\FTP\Phoenix WDA V2 Stage"

:: --- AUTOMATICALLY ADDED MAPPINGS (FOUND IN YOUR APPREG_MAIN.XML BUT MISSING ABOVE) ---
"Authenticator=%PnxInstallPath%\Phoenix Authenticator" "InterfaceFolderWatcher=%PnxInstallPath%\Phoenix Interface Folder Watcher" "RegionalCAD2CAD=%PnxInstallPath%\Phoenix Regional CAD2CAD Service" "CADLiveStreaming=%PnxInstallPath%\CADLiveStreamingService" "CADLiveStreaming=%PnxInstallPath%\Phoenix CAD Live Streaming Service" "DBUtilityCodeBook=%PnxInstallPath%\Phoenix Database Utility CodeBook" "CRMHubAPI=%PnxInstallPath%\CRMHubAPI" "PhoenixGateway=%PnxInstallPath%\Phoenix Gateway" "CSPProcessQueue=%PnxInstallPath%\CSPProcessQueueService" "CSPConversion=%PnxInstallPath%\CSP Conversion" "AIMugMatch=%PnxInstallPath%\PhoenixAIMugMatch" "AIAPI=%PnxInstallPath%\CRMHubAPI\PNXAIAPI" "ExpenseAPI=%PnxInstallPath%\CRMHubAPI\PNXExpenseAPI" "CustomerAPI=%PnxInstallPath%\CRMHubAPI\PNXCustomerAPI" "EmploymentClient=%PnxInstallPath%\Phoenix Employment Client" "AzureFileDownloader=%PnxInstallPath%\Azure File Downloader"
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
        
        # --- FIND UPDATER SETTINGS ---
        $ConfigFileName = "PnxConfigMgr.exe.config"
        $ConfigFound = $false
        $UpdUser = "N/A"
        $UpdLoc = "N/A"
        
        $PossibleConfigPaths = @(
            (Join-Path -Path $AppMgrFolder -ChildPath $ConfigFileName),
            (Join-Path -Path (Split-Path $AppMgrFolder -Parent) -ChildPath "Server Application Manager\$ConfigFileName"),
            (Join-Path -Path (Split-Path $AppMgrFolder -Parent) -ChildPath "Phoenix Server Application Manager\$ConfigFileName")
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
                        # --- EXCLUSION LOGIC (HUB / GATEWAY) ---
                        if ($BestID -match "(?i)Hub" -or $BestID -match "(?i)Gateway") {
                            Write-Host "  [SKIPPED] $BestID (Excluded Hub/Gateway)" -ForegroundColor DarkGray
                            continue
                        }
                        
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
echo   STEP 1: UPDATING APPLICATION MANAGER
echo ===================================================
echo [LOG] Updating Application Manager... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe "UPDAPPMANAGER"
timeout 10 > NUL

echo.
echo ===================================================
echo   STEP 2: PRODUCTION APPLICATION INSTALL
echo   (Services are still RUNNING)
echo ===================================================
echo [LOG] Installing Production Apps... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe $ProdLine | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   STEP 3: STAGE APPLICATION INSTALL
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
echo   STEP 4: STOPPING SERVICES (MAINTENANCE START)
echo ===================================================
echo [LOG] Stopping Services... >> %LOGFILE%
%windir%\System32\iisreset.exe /stop >> %LOGFILE% 2>&1
%windir%\System32\taskkill.exe /F /IM "KPI.Phoenix.CADClient.exe" /T 2>nul >> %LOGFILE% 2>&1
%windir%\System32\taskkill.exe /F /IM "KPI.Phoenix.CADMobileClient.exe" /T 2>nul >> %LOGFILE% 2>&1
%windir%\System32\taskkill.exe /F /IM "Phoenix.WDAV2.Client.Shell.exe" /T 2>nul >> %LOGFILE% 2>&1
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name `$_.Name -Force; Write-Host 'Stopped ' `$_.Name }" >> %LOGFILE% 2>&1

echo.
echo ===================================================
echo   STEP 5: CLEANUP (SVR SESSION DATA ONLY)
echo ===================================================
echo [LOG] Cleaning Session Data... >> %LOGFILE%
%PSExe% -ExecutionPolicy Bypass -File "%~dp0SessionClear.ps1" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   STEP 6: UPDATING INSTANCES
echo ===================================================
echo [LOG] Starting IIS for Instance Update... >> %LOGFILE%
%windir%\System32\iisreset.exe /start >> %LOGFILE% 2>&1

echo [LOG] Running UPDATEINSTANCE... >> %LOGFILE%
$UpdateCmd

echo.
echo ===================================================
echo   STEP 7: STARTING PHOENIX SERVICES
echo ===================================================
echo [LOG] Starting Services... >> %LOGFILE%
timeout /t 5 >nul
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -ne 'Running' } | ForEach-Object { try { Start-Service -Name `$_.Name -ErrorAction Stop; Write-Host 'Started ' `$_.Name } catch { Write-Host 'Failed to start ' `$_.Name `$_.Exception.Message } }" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   STEP 8: REPORTING INSTANCE STATUS
echo ===================================================
echo [LOG] Reporting Instance Status... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe "SHOWINSTANCES" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   STEP 9: VERIFICATION AND CLIENT LAUNCH
echo ===================================================
echo [LOG] Verifying DLLs... >> %LOGFILE%
%PSExe% -ExecutionPolicy Bypass -File "%~dp0InstanceVerification.ps1"

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