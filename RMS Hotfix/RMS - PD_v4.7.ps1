<#
.SYNOPSIS
    ProPhoenix Hotfix RMS - PD
    
.DESCRIPTION
  #>

$ErrorActionPreference = "Continue"
Clear-Host
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   ProPhoenix Hotfix RMS - PD          " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$TargetServer = Read-Host "Enter Target Server Name (Press ENTER for Localhost)"

if ([string]::IsNullOrWhiteSpace($TargetServer)) {
    $TargetServer = "localhost"
    $RunRemote = $false
    Write-Host "-> Selected Mode: LOCAL EXECUTION" -ForegroundColor Green
} else {
    $RunRemote = $true
    Write-Host "-> Selected Mode: REMOTE EXECUTION on $TargetServer" -ForegroundColor Yellow
}
Write-Host "==========================================================" -ForegroundColor Cyan

# ==============================================================================
#  CORE LOGIC BLOCK
# ==============================================================================
$GeneratorLogic = {
    $ErrorActionPreference = "Continue"
    $CurrentHostName = $env:COMPUTERNAME

    # --- 1. CONFIGURATION CHECK (UPDATER SETTINGS) ---
    $PnxRoot = $null
    $PossiblePaths = @("Program Files (x86)\ProPhoenix", "Program Files\ProPhoenix")
    foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
        foreach ($path in $PossiblePaths) {
            $try = Join-Path $drive.Root $path
            if (Test-Path $try) { $PnxRoot = $try; break }
        }
        if ($PnxRoot) { break }
    }

    # --- 2. HELPER SCRIPTS ---
    $WorkDir = Join-Path $PnxRoot "PnxTemp"
    if (-not (Test-Path $WorkDir)) { New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null }
    Write-Host "`n[INIT] Workspace: $WorkDir" -ForegroundColor Yellow
    
    if ($PnxRoot) {
        $ConfigPaths = @(
            (Join-Path $PnxRoot "Server Application Manager\PnxConfigMgr.exe.config"),
            (Join-Path $PnxRoot "Phoenix Server Application Manager\PnxConfigMgr.exe.config")
        )
        foreach ($cfg in $ConfigPaths) {
            if (Test-Path $cfg) {
                try {
                    [xml]$xmlCfg = Get-Content $cfg
                    $UpdateUser = $xmlCfg.configuration.appSettings.add | Where-Object { $_.key -eq "UpdateUserName" }
                    if ($UpdateUser) {
                        Write-Host "   [CONFIG] Updater User: $($UpdateUser.value)" -ForegroundColor Cyan
                    }
                } catch {}
            }
        }
    }
    
    # A. SESSION CLEANUP ONLY
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
                    try { Remove-Item -Path $_.FullName -Force -ErrorAction Stop; $delCount++ } catch {}
                }
                if ($delCount -gt 0) { Write-Host "      Removed $delCount session files." -ForegroundColor DarkGray }
            }
        }
    }
}
Write-Host "Session Cleanup Complete."
'@

    # B. VERIFICATION SCRIPT
    $VerificationScriptContent = @'
Write-Host "[INFO] Starting DLL verification..." -ForegroundColor Cyan
$prophoenixPaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $driveRoot = "$($_.Root)Program Files\ProPhoenix"
    if (Test-Path $driveRoot) { $driveRoot }
}
if (-not $prophoenixPaths) { Write-Host "[ERROR] No ProPhoenix installation found." -ForegroundColor Red; exit }

$excludedFolders = @("Finger Print Client","ID Scanner","Phoenix WDA V2","Police RMS","PoliceRMS","Print Server","WDA")
$completedCount = 0; $notCompletedCount = 0; $totalChecked = 0

foreach ($basePath in $prophoenixPaths) {
    Write-Host "`n[INFO] Scanning applications in: $basePath" -ForegroundColor Yellow
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
                        if (($match.LastWriteTime -lt $dll.LastWriteTime) -or ($match.Length -ne $dll.Length)) { $status = "Not Completed"; break }
                    } else { $status = "Not Completed"; break }
                }
                $totalChecked++
                if ($status -eq "Completed") { $completedCount++; Write-Host ("[OK] " + $app.Name + " -> " + $env.Name + " : Completed") -ForegroundColor Green } 
                else { $notCompletedCount++; Write-Host ("[WARN] " + $app.Name + " -> " + $env.Name + " : Not Completed") -ForegroundColor Red }
            }
        }
    }
}
Write-Host "`n[INFO] DLL verification completed." -ForegroundColor Cyan
Write-Host ("--------------------------------------")
Write-Host ("Total Verified : " + $totalChecked)
Write-Host ("Completed      : " + $completedCount) -ForegroundColor Green
Write-Host ("Not Completed  : " + $notCompletedCount) -ForegroundColor Red
Write-Host ("--------------------------------------")
'@

    # C. SHORTCUT LAUNCHER
    $ShortcutLauncherContent = @'
$DesktopPaths = @([Environment]::GetFolderPath("Desktop"), [Environment]::GetFolderPath("CommonDesktopDirectory"))
Write-Host "Searching Desktops for Stage/Client Shortcuts..."
$Found = 0
foreach ($path in $DesktopPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Filter "*.lnk" | ForEach-Object {
            $n = $_.Name
            if ($n -match "Manager") { return }
            if (($n -match "CAD" -and $n -match "Client") -or $n -match "WDA") {
                 Write-Host "   [LAUNCH] $n" -ForegroundColor Green; Start-Process -FilePath $_.FullName -Verb RunAs; $Found++
            }
        }
    }
}
if ($Found -eq 0) { Write-Host "   (No WDA/CAD shortcuts found)" -ForegroundColor DarkGray }
'@

    Set-Content -Path (Join-Path $WorkDir "SessionClear.ps1") -Value $SessionClearContent -Encoding ASCII
    Set-Content -Path (Join-Path $WorkDir "InstanceVerification.ps1") -Value $VerificationScriptContent -Encoding ASCII
    Set-Content -Path (Join-Path $WorkDir "LaunchShortcuts.ps1") -Value $ShortcutLauncherContent -Encoding ASCII

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

    # 4. FIND INSTANCES
    $FileName = "Appreg_main.xml"
    $PossibleParents = @("ProPhoenix\Server Application Manager","Program Files (x86)\ProPhoenix\Server Application Manager","Program Files\ProPhoenix\Server Application Manager")
    $Drives = Get-PSDrive -PSProvider FileSystem
    $FoundFiles = @()

    foreach ($d in $Drives) {
        foreach ($folder in $PossibleParents) {
            $TestPath = Join-Path -Path $d.Root -ChildPath $folder
            $FullFilePath = Join-Path -Path $TestPath -ChildPath $FileName
            if (Test-Path $FullFilePath) { $FoundFiles += $FullFilePath }
        }
    }

    if ($FoundFiles.Count -eq 0) { Write-Error "No AppReg instances found. Exiting."; return }

    # 5. PROCESS LOOP
    $InstanceCount = 1
    $GeneratedBatFiles = @()

    foreach ($FoundPath in $FoundFiles) {
        $AppMgrFolder = (Split-Path $FoundPath -Parent)
        $InstallDrive = (Split-Path $FoundPath -Qualifier)

        # Parse Mappings
        $PathMap = @{}
        $Matches = [regex]::Matches($RawMappingData, '"([^"]+)=%PnxInstallPath%\\([^"]+)"')
        foreach ($m in $Matches) {
            $PathMap[$m.Groups[2].Value.Replace("/", "\").Trim()] = $m.Groups[1].Value
        }
        $SortedKeys = $PathMap.Keys | Sort-Object Length -Descending

        try { [xml]$xmlData = Get-Content $FoundPath } catch { Write-Error "Invalid XML"; continue }
        
        Write-Host "`n[STEP 4] Scanning Products..." -ForegroundColor Yellow
        Write-Host "   [INFO] AppReg: $FoundPath" -ForegroundColor Gray
        Write-Host "   [FETCH] Classification Results:" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------"

        # --- LIST INITIALIZATION ---
        $ListGen   = new-object System.Collections.Generic.List[string]
        $ListWeb   = new-object System.Collections.Generic.List[string]
        $ListDocs  = new-object System.Collections.Generic.List[string]
        $ListUpd   = new-object System.Collections.Generic.List[string]

        $DisplayGen   = @()
        $DisplayWeb   = @()
        $DisplayDocs  = @()

        $ListGen.Add('"INSTALL"'); $ListWeb.Add('"INSTALL"'); $ListDocs.Add('"INSTALL"'); $ListUpd.Add('"UPDATEINSTANCE"')

        # --- HARDCODED EXCLUSIONS ---
        $ExcludedIDs = @("PoliceRms", "FireRms", "InternalAffair", "Phoenix IA", "PhoenixHub", "PhoenixGateway", "PaymentGateway")
        $Logic2IDs = @("PDFService", "ReportWriterAPI", "PhoenixWebService", "StagePhoenixWDAV2")

        if ($xmlData.PhoenixApplications.AppReg) {
            foreach ($app in $xmlData.PhoenixApplications.AppReg) {
                if ($app.CurrentVersion -ne "0.0.0.0") {
                    $FPath = $app.AppPath.Replace("/", "\").Trim()
                    $BestID = $app.AppName # Default
                    
                    foreach ($k in $SortedKeys) {
                        if ($FPath.EndsWith($k, [System.StringComparison]::OrdinalIgnoreCase)) {
                            $BestID = $PathMap[$k]; break
                        }
                    }
                    
                    if ($app.AppName -match "Fire.*Help.*Doc") { $BestID = "FireF1HelpDocs" }
                    if ($app.AppName -match "Police.*Help.*Doc") { $BestID = "PoliceF1HelpDocs" }
                    if ($app.AppName -match "IA.*Help.*Doc") { $BestID = "IAF1HelpDocs" }

                    if ($ListGen -contains "`"$BestID`"" -or $ListWeb -contains "`"$BestID`"" -or $ListDocs -contains "`"$BestID`"") { continue }

                    # --- CONSOLE LINE CONSTRUCTION ---
                    $LogLine = "- Found: $($app.AppName) -> ID: $BestID"
                    
                    if ($ServiceProductList -contains $BestID) {
                        $LogLine += " [Update Queued]"
                        $ListUpd.Add("`"$BestID`"")
                    }

                    if ($ExcludedIDs -contains $BestID -or $app.AppName -match "Hub" -or $app.AppName -match "Gateway") { 
                        Write-Host "$LogLine -> SKIPPED (Excluded)" -ForegroundColor DarkGray
                        continue 
                    }

                    # --- CATEGORIES LOGIC ---
                    if ($BestID -like "*Help*Doc*" -or $BestID -like "*Hazmat*" -or $app.AppName -like "*Help*Doc*" -or $BestID -match "F1HelpDocs") {
                        $ListDocs.Add("`"$BestID`"")
                        $DisplayDocs += $BestID
                        Write-Host "$LogLine -> LOGIC 3 (Docs)" -ForegroundColor Cyan
                    }
                    elseif ($Logic2IDs -contains $BestID -or $BestID -match "(?i)Stage" -or $BestID -like "*Web*Service*" -or $BestID -like "*PDF*" -or $BestID -like "*API*") {
                        $ListWeb.Add("`"$BestID`"")
                        $DisplayWeb += $BestID
                        Write-Host "$LogLine -> LOGIC 2 (Web/Stage/Special)" -ForegroundColor Magenta
                    }
                    else {
                        $ListGen.Add("`"$BestID`"")
                        $DisplayGen += $BestID
                        Write-Host "$LogLine -> LOGIC 1 (General)" -ForegroundColor Green
                    }
                }
            }
        }
        Write-Host "------------------------------------------------------------"

        # --- BATCH STRING BUILDER ---
        $StrGenBlock = if ($DisplayGen) { ($DisplayGen | ForEach-Object { "echo    - $_" }) -join "`r`n" } else { "echo    (None found)" }
        $StrWebBlock = if ($DisplayWeb) { ($DisplayWeb | ForEach-Object { "echo    - $_" }) -join "`r`n" } else { "echo    (None found)" }
        $StrDocsBlock = if ($DisplayDocs) { ($DisplayDocs | ForEach-Object { "echo    - $_" }) -join "`r`n" } else { "echo    (None found)" }
        
        $UpdateCmd = ""
        if ($ListUpd.Count -gt 1) {
            $UpdateLine = $ListUpd -join " "
            $UpdateCmd = "%AppMgrExePath%\PnxAppMgr.exe $UpdateLine | %PSExe% -Command `"`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }`""
        }

        # --- PRIMARY BATCH FILE GENERATION ---
        $BatchContent = @"
$InstallDrive
@echo off
cd ..\..\..\..
cd "$AppMgrFolder"

SET AppMgrExePath="$AppMgrFolder"
SET PSExe=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
set "timestamp=%DATE:/=-%_%TIME::=-%"
set "timestamp=%timestamp: =0%"
set LOGFILE="%WorkDir%\Update_Log_%timestamp%.txt"
echo [LOG] Started Production Update... > %LOGFILE%

:: ===================================================
:: STEP 0: UPDATING APPLICATION MANAGER
:: ===================================================
echo.
echo ---------------------------------------------------
echo  READY: STEP 0 (UPDATE APP MANAGER)
echo ---------------------------------------------------
echo [LOG] Self-Updating App Manager... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe "UPDAPPMANAGER"
timeout 10 > NUL

:: ===================================================
:: LOGIC 1: GENERAL APPS (Services UP)
:: ===================================================
echo.
echo ---------------------------------------------------
echo  CATEGORY 1: GENERAL APPLICATIONS
echo ---------------------------------------------------
echo  The following products will be installed:
$StrGenBlock
echo.
echo  (Phoenix Services: KEEP RUNNING)
echo ---------------------------------------------------
:AskGen
SET /P "StartGen=>> Install General Apps now? (Y/N): "
IF /I "%StartGen%" NEQ "Y" GOTO AskGen

echo [LOG] Installing General Apps...
%AppMgrExePath%\PnxAppMgr.exe $($ListGen -join " ") | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }"

:: ===================================================
:: LOGIC 2: SPECIAL APPS (Maintenance Mode)
:: ===================================================
echo.
echo ---------------------------------------------------
echo  CATEGORY 2: WEB SERVICES / PDF / STAGE
echo ---------------------------------------------------
echo  The following products will be installed:
$StrWebBlock
echo.
echo  WARNING: This will STOP SERVICES -^> CLEANUP -^> INSTALL
echo ---------------------------------------------------
:AskWeb
SET /P "StartWeb=>> Stop Services and Install Web/Stage Apps now? (Y/N): "
IF /I "%StartWeb%" NEQ "Y" GOTO AskWeb

echo [MAINTENANCE] Stopping Services...
%windir%\System32\iisreset.exe /stop
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name `$_.Name -Force }"

echo [CLEANUP] Clearing Session Data (ONLY)...
%PSExe% -ExecutionPolicy Bypass -File "$WorkDir\SessionClear.ps1"

echo [LOGIC 2] Installing Web/Stage Apps...
%AppMgrExePath%\PnxAppMgr.exe $($ListWeb -join " ") | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }"

:: ===================================================
:: STEP 3: UPDATE INSTANCES
:: ===================================================
echo.
echo [UPDATE] Starting IIS for Update...
%windir%\System32\iisreset.exe /start
timeout /t 5 >nul

echo [UPDATE] Updating Instances...
$UpdateCmd

:: ===================================================
:: STEP 4: START SERVICES ^& VERIFY
:: ===================================================
echo.
echo [START] Starting Phoenix Services...
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
echo  CATEGORY 3: HELP DOCS / HAZMAT
echo ---------------------------------------------------
echo  The following products will be installed:
$StrDocsBlock
echo.
echo  (Services: RUNNING)
echo ---------------------------------------------------
:AskFinal
SET /P "StartFinal=>> Install HelpDocs now? (Y/N): "
IF /I "%StartFinal%" NEQ "Y" GOTO AskFinal

echo [LOGIC 3] Installing HelpDocs...
%AppMgrExePath%\PnxAppMgr.exe $($ListDocs -join " ") | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }"

echo.
echo ===================================================
echo  UPDATE PROCESS COMPLETE.
echo ===================================================
echo  Check Log: %LOGFILE%
pause
:End
"@

        $BaseName = "${CurrentHostName}_PrimaryHotfix"
        $FinalName = "$BaseName.bat"
        $OutputBatFile = Join-Path -Path $WorkDir -ChildPath $FinalName
        Set-Content -Path $OutputBatFile -Value $BatchContent -Encoding ASCII
        $GeneratedBatFiles += $OutputBatFile
        Write-Host "`n [SUCCESS] Primary Batch Generated: $OutputBatFile" -ForegroundColor Green

        # --- SECONDARY BATCH FILE GENERATION (INSTANCE UPDATE ONLY) ---
        $SecBatDir = "C:\pnxtemp\Phoenix Installation Master\Phoenix Installation Master"
        if (-not (Test-Path $SecBatDir)) { New-Item -ItemType Directory -Path $SecBatDir -Force | Out-Null }
        
        $SecBatchContent = @"
$InstallDrive
@echo off
cd ..\..\..\..
cd "$AppMgrFolder"

SET AppMgrExePath="$AppMgrFolder"
SET PSExe=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
set LOGFILE="%WorkDir%\InstanceUpdate_BS_Log.txt"
echo [LOG] Started Instance Update (BS)... > %LOGFILE%

echo.
echo ===================================================
echo   STEP 1: STOPPING PHOENIX SERVICES (NO IIS RESET)
echo ===================================================
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name `$_.Name -Force; Write-Host 'Stopped ' `$_.Name }" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   STEP 2: UPDATING INSTANCES
echo ===================================================
$UpdateCmd

echo.
echo ===================================================
echo   STEP 3: STARTING PHOENIX SERVICES
echo ===================================================
timeout /t 5 >nul
%PSExe% -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -ne 'Running' } | ForEach-Object { try { Start-Service -Name `$_.Name -ErrorAction Stop; Write-Host 'Started ' `$_.Name } catch { Write-Host 'Failed to start ' `$_.Name `$_.Exception.Message } }" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo   STEP 4: VERIFYING DLLS
echo ===================================================
%PSExe% -ExecutionPolicy Bypass -File "$WorkDir\InstanceVerification.ps1" | %PSExe% -Command "`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }" 2>&1

echo.
echo ===================================================
echo  INSTANCE UPDATE PROCESS COMPLETE.
echo ===================================================
echo  Check Log: %LOGFILE%
pause
"@
        
        $SecBatPath = Join-Path $SecBatDir "Instance Update(BS).bat"
        Set-Content -Path $SecBatPath -Value $SecBatchContent -Encoding ASCII
        Write-Host " [SUCCESS] Secondary Batch Generated: $SecBatPath" -ForegroundColor Green

        $InstanceCount++
    }
    return $GeneratedBatFiles
}

# --- 3. EXECUTION ---
if ($RunRemote) {
    $Creds = Get-Credential
    try {
        Invoke-Command -ComputerName $TargetServer -Credential $Creds -ScriptBlock $GeneratorLogic
        Write-Host "`n[INFO] Remote generation complete." -ForegroundColor Yellow
    } catch { Write-Error "Connection failed: $_" }
} else {
    $LocalBatFiles = & $GeneratorLogic
    if ($LocalBatFiles.Count -gt 0) {
        # ONLY select and run the Primary Batch File if user types Y
        $PrimaryBatToRun = $LocalBatFiles | Where-Object { $_ -like "*_PrimaryHotfix.bat" } | Select-Object -First 1
        if ($PrimaryBatToRun) {
            if ((Read-Host "`n?? Run Primary Batch File now? (Y/N)") -eq "Y") {
                Start-Process -FilePath $PrimaryBatToRun -Verb RunAs
            }
        }
    }
}