<#
.SYNOPSIS
    ProPhoenix Installation Master
    - Auto-Creates C:\pnxtemp\ProPhoenixSuite
    - Extracts embedded tools to that folder
    - Provides Admin GUI to launch them
#>

# ==============================================================================
#  1. SELF-ELEVATE TO ADMINISTRATOR
# ==============================================================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";
    $newProcess.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"";
    $newProcess.Verb = "runas";
    [System.Diagnostics.Process]::Start($newProcess);
    Exit;
}

# ==============================================================================
#  2. DEFINE EMBEDDED SCRIPTS (FULL CONTENT)
# ==============================================================================

# --- SCRIPT 1: Autodefinedproducts_Vers3.1.ps1 (Demo / Test) ---
$Content_DemoTest = @'
<#
.SYNOPSIS
    ProPhoenix Hotfix Automation  (Installation Team).
#>
Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   ProPhoenix Hotfix Automation (Demo/Test)" -ForegroundColor Cyan
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
if (`$instanceFolders.Count -eq 0) { Write-Host "[WARNING] No '_Instances' folders found."; exit }
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
            } else { Write-Host "[INFO] No log files in: `$targetPath. Skipping..." }
        }
    }
}
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
                Get-ChildItem -Path `$sessionDataPath -File | ForEach-Object { Remove-Item -Path `$_.FullName -Force; `$filesDeleted++ }
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
if (-not `$prophoenixPaths) { Log-Msg "[ERROR] No ProPhoenix installation found." "Red"; exit }
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
                        if ((`$match.LastWriteTime -lt `$dll.LastWriteTime) -or (`$match.Length -ne `$dll.Length)) { `$status = "Not Completed"; break }
                    } else { `$status = "Not Completed"; break }
                }
                `$totalChecked++
                if (`$status -eq "Completed") {
                    `$completedCount++; Log-Msg ("[OK] " + `$app.Name + " -> " + `$env.Name + " : Completed") "Green"
                } else {
                    `$notCompletedCount++; Log-Msg ("[WARN] " + `$app.Name + " -> " + `$env.Name + " : Not Completed") "Red"
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
    $ClientAppsDef = @{ "CAD Client"="KPI.Phoenix.CADClient.exe"; "WDA"="KPI.Phoenix.CADMobileClient.exe"; "Phoenix WDA V2"="Phoenix.WDAV2.Client.Shell.exe" }
    $ServiceProductList = @("JobServer", "TraCSServer", "VideoServer", "FingerPrintServer", "EmailWatcher", "CADServer", "CADNLBServer", "CAD2CADTellusServer", "E911Server", "ZetronServer", "ExternalInterface", "GPSServer", "NCICServer", "NCICStateServer", "FTPServer", "LocutionCADVoiceServer", "DeviceNotification", "StreamingNotification", "ReportService", "FolderWatcher", "DocsServer", "PhoenixTonerServer", "PhoenixAlertApp", "PhoenixTExt2Dispatch", "PHOENIXAIWATCHERSERVICE", "PHOENIXJOBSVRV2")

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
    Write-Host "   ProPhoenix Hotfix Automation  (Installation Team)" -ForegroundColor Yellow
    Write-Host "   HOST: $CurrentHostName" -ForegroundColor Yellow
    Write-Host "==============================================" -ForegroundColor Yellow
    $FileName = "Appreg_main.xml"
    Write-Host "`n[STEP 1] Scanning for $FileName..." -ForegroundColor Cyan
    $PossibleParents = @("ProPhoenix\Server Application Manager","Program Files (x86)\ProPhoenix\Server Application Manager","Program Files\ProPhoenix\Server Application Manager","ProPhoenix\Phoenix Server Application Manager","Program Files (x86)\ProPhoenix\Phoenix Server Application Manager","Program Files\ProPhoenix\Phoenix Server Application Manager")
    $Drives = Get-PSDrive -PSProvider FileSystem; $FoundFiles = @()
    foreach ($d in $Drives) { foreach ($folder in $PossibleParents) { $TestPath = Join-Path -Path $d.Root -ChildPath $folder; $FullFilePath = Join-Path -Path $TestPath -ChildPath $FileName; if (Test-Path $FullFilePath) { $FoundFiles += $FullFilePath } } }
    if ($FoundFiles.Count -eq 0) { Write-Error "No instances found on $CurrentHostName. Exiting."; return }

    Write-Host "`n[STEP 1.5] Scanning for Client Applications..." -ForegroundColor Cyan
    $ClientLaunchLogic = ""
    $CommonRoots = @("ProPhoenix", "Program Files\ProPhoenix", "Program Files (x86)\ProPhoenix")
    foreach ($key in ($ClientAppsDef.Keys | Sort-Object)) {
        $FolderName = $key; $ExeName = $ClientAppsDef[$key]; $FoundClient = $false
        foreach ($d in $Drives) {
            foreach ($root in $CommonRoots) {
                $TryPath = Join-Path -Path $d.Root -ChildPath $root | Join-Path -ChildPath $FolderName | Join-Path -ChildPath $ExeName
                if (Test-Path $TryPath) {
                    Write-Host "  [FOUND] $FolderName -> $TryPath" -ForegroundColor Green
                    $ClientLaunchLogic += "echo Launching $FolderName...`r`n"
                    $ClientLaunchLogic += "echo [LOG] Launching $FolderName... >> %LOGFILE%`r`n"
                    $PSCommand = "`$path = '$TryPath'; `$desktop = [Environment]::GetFolderPath('Desktop'); `$public = [Environment]::GetFolderPath('CommonDesktopDirectory'); `$shell = New-Object -ComObject WScript.Shell; `$shortcut = Get-ChildItem -Path `$desktop, `$public -Filter '*.lnk' | Where-Object { `$shell.CreateShortcut(`$_.FullName).TargetPath -eq `$path } | Select-Object -First 1; if (`$shortcut) { Start-Process `$shortcut.FullName -Verb RunAs; } else { Start-Process `$path -Verb RunAs; }"
                    $PSCommandFlat = $PSCommand -replace "`r`n", " " -replace "\s+", " "
                    $ClientLaunchLogic += "%PSExe% -WindowStyle Hidden -Command `"$PSCommandFlat`"`r`n"
                    $FoundClient = $true; break
                }
            }
            if ($FoundClient) { break }
        }
    }

    $InstanceCount = 1; $GeneratedBatFiles = @()
    foreach ($FoundPath in $FoundFiles) {
        Write-Host "`n--------------------------------------------------" -ForegroundColor Yellow
        Write-Host " PROCESSING INSTANCE #$InstanceCount" -ForegroundColor Yellow
        Write-Host " Source: $FoundPath" -ForegroundColor Gray
        Write-Host "--------------------------------------------------" -ForegroundColor Yellow
        $InstallDrive = (Split-Path $FoundPath -Qualifier); $AppMgrFolder = (Split-Path $FoundPath -Parent)
        $LogDir = Join-Path -Path $AppMgrFolder -ChildPath "PnxLog\PrintLog"
        if (-not (Test-Path $LogDir)) { try { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null } catch {} }
        if (-not (Test-Path $LogDir)) { $LogDir = $env:TEMP }
        $LogFileName = "InstallGen_Inst${InstanceCount}_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        $LogFile = Join-Path -Path $LogDir -ChildPath $LogFileName
        $LogMsg = { param([string]$Msg, [string]$Lvl="INFO", [string]$Clr="White"); $TS = Get-Date -Format "yyyy-MM-dd HH:mm:ss"; Add-Content -Path $LogFile -Value "[$TS] [$Lvl] $Msg"; Write-Host $Msg -ForegroundColor $Clr }
        & $LogMsg -Msg "Logging started: $LogFile" -Clr Cyan

        Write-Host "`n[STEP 2] Backing up Configuration..." -ForegroundColor Cyan
        $BackupFile = "$FoundPath.$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
        try { Copy-Item -Path $FoundPath -Destination $BackupFile -ErrorAction Stop; & $LogMsg -Msg "Backup created: $BackupFile" -Lvl SUCCESS -Clr Green } catch { & $LogMsg -Msg "Backup Failed" -Lvl ERROR -Clr Red; continue }

        Write-Host "`n[STEP 3] Preparing PnxTemp & Helper Scripts..." -ForegroundColor Cyan
        $PnxTempPath = Join-Path -Path (Split-Path $AppMgrFolder -Parent) -ChildPath "PnxTemp"
        if (-not (Test-Path $PnxTempPath)) { try { New-Item -ItemType Directory -Path $PnxTempPath -Force | Out-Null } catch {} }
        Set-Content -Path (Join-Path $PnxTempPath "LogClear.ps1") -Value $LogClearScriptContent -Encoding ASCII
        Set-Content -Path (Join-Path $PnxTempPath "InstanceVerification.ps1") -Value $VerificationScriptContent -Encoding ASCII

        Write-Host "`n[STEP 4] Analyzing Products..." -ForegroundColor Cyan
        $PathMap = @{}; $Regex = '"([^"]+)=%PnxInstallPath%\\([^"]+)"'
        foreach ($m in [regex]::Matches($RawMappingData, $Regex)) { $ShortID = $m.Groups[1].Value; $Suffix = $m.Groups[2].Value.Replace("/", "\").Trim(); if (-not $PathMap.ContainsKey($Suffix)) { $PathMap[$Suffix] = $ShortID } }

        try { [xml]$xmlData = Get-Content $FoundPath } catch { & $LogMsg -Msg "Invalid XML" -Lvl ERROR -Clr Red; continue }
        $InstallArgs = new-object System.Collections.Generic.List[string]; $UpdateArgs = new-object System.Collections.Generic.List[string]
        $InstallArgs.Add('"INSTALL"'); $UpdateArgs.Add('"UPDATEINSTANCE"')

        if ($xmlData.PhoenixApplications.AppReg) {
            foreach ($app in $xmlData.PhoenixApplications.AppReg) {
                $Ver = $app.CurrentVersion; $FPath = $app.AppPath.Replace("/", "\").Trim()
                if ($Ver -ne "0.0.0.0") {
                    $BestID = $null; $BestLen = 0
                    foreach ($k in $PathMap.Keys) { if ($FPath.EndsWith($k, [System.StringComparison]::OrdinalIgnoreCase)) { if ($k.Length -gt $BestLen) { $BestID = $PathMap[$k]; $BestLen = $k.Length } } }
                    if ($BestID) { $InstallArgs.Add("`"$BestID`""); if ($ServiceProductList -contains $BestID) { $UpdateArgs.Add("`"$BestID`"") }; & $LogMsg -Msg "Included: $($app.AppName) -> $BestID" -Lvl SUCCESS -Clr Green } else { & $LogMsg -Msg "Skipped: $($app.AppName)" -Lvl WARN -Clr Yellow }
                }
            }
        }
        Write-Host "`n[STEP 5] Generating Final Script..." -ForegroundColor Cyan
        $InstallLine = $InstallArgs -join " "; $UpdateLine = $UpdateArgs -join " "
        $BaseName = "${CurrentHostName}_Hotfix_Automation"; $Ext = ".bat"; $Counter = 0; $FinalName = "$BaseName$Ext"; $OutputBatFile = Join-Path -Path $PnxTempPath -ChildPath $FinalName
        while (Test-Path $OutputBatFile) { $Counter++; $FinalName = "${BaseName}${Counter}${Ext}"; $OutputBatFile = Join-Path -Path $PnxTempPath -ChildPath $FinalName }
        $GeneratedBatFiles += $OutputBatFile
        $PathParts = $AppMgrFolder.Split('\'); $CdBlock = "$InstallDrive`r`ncd ..\..\`r`n"
        for ($i = 1; $i -lt $PathParts.Count; $i++) { if ($PathParts[$i]) { $CdBlock += "cd `"$($PathParts[$i])`"`r`n" } }
        $UpdateCmd = ""; if ($UpdateArgs.Count -gt 1) { $UpdateCmd = "::Script - Updating Windows Service Instance`r`n%AppMgrExePath%\PnxAppMgr.exe $UpdateLine | %PSExe% -Command `"`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }`"`r`n" }

        $BatchContent = @"
$CdBlock
@echo off
SET AppMgrExePath="$AppMgrFolder"
SET PSExe=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
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
echo [LOG] Updating Application Manager... >> %LOGFILE%
%AppMgrExePath%\PnxAppMgr.exe "UPDAPPMANAGER" 
echo Waiting 5 minutes for App Manager to settle...
timeout 300 > NUL
:loopSelf
%windir%\System32\tasklist.exe /fi "imagename eq PnxAppMgr.exe" |find ":" > nul
if "%ERRORLEVEL%"=="1" goto loopSelf
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
timeout /t 5 >nul
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
"@
        try { Set-Content -Path $OutputBatFile -Value $BatchContent -Encoding ASCII; & $LogMsg -Msg "SUCCESS! Script created at: $OutputBatFile" -Lvl SUCCESS -Clr Green } catch { & $LogMsg -Msg "Failed to write BAT file" -Lvl ERROR -Clr Red }
        $InstanceCount++
    }
    return $GeneratedBatFiles
}

if ($RunRemote) {
    $Creds = Get-Credential; Write-Host "Connecting to $TargetServer..." -ForegroundColor Cyan
    try { Invoke-Command -ComputerName $TargetServer -Credential $Creds -ScriptBlock $GeneratorLogic; Write-Host "`n[INFO] Files generated on REMOTE server ($TargetServer)." -ForegroundColor Yellow } catch { Write-Error "Connection failed: $_" }
} else {
    Write-Host "Executing Locally..." -ForegroundColor Green; $LocalBatFiles = & $GeneratorLogic
    if ($LocalBatFiles.Count -gt 0) { $RunChoice = Read-Host "`n[QUESTION] Would you like to run the Hotfix Automation file(s) now? (Y/N)"; if ($RunChoice -eq "Y") { foreach ($bat in $LocalBatFiles) { Write-Host "Launching as Administrator: $bat ..." -ForegroundColor Green; Start-Process -FilePath $bat -Verb RunAs } } }
}
'@

# --- SCRIPT 2: Autodbsync - v3.5 GUI.ps1 (DB Sync) ---
$Content_DBSync = @'
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:DBSyncRoot = $null
if (!(Test-Path $Script:SetupPath)) { New-Item -ItemType Directory -Force -Path $Script:SetupPath | Out-Null }
if (!(Test-Path $Script:XmlTarget)) { Set-Content -Path $Script:XmlTarget -Value '<?xml version="1.0" encoding="utf-8" ?><PnxPakager><SourceServer><IPAddress>LOCALHOST</IPAddress><DBName>DBName</DBName><UserName>sa</UserName><Password>pnx</Password><JurisID>1000</JurisID><State>MA</State><JurisName>ProPhoenix</JurisName><JurisAlias>PNX</JurisAlias><SyncType>2</SyncType></SourceServer></PnxPakager>' -Force }
foreach ($drive in (Get-PSDrive -PSProvider FileSystem).Root) { $candidate = Join-Path $drive "Program Files\ProPhoenix\Database Utility\DB Sync"; if (Test-Path $candidate) { $Script:DBSyncRoot = $candidate; break } }
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProPhoenix Sync Manager (Installation Team)"; $form.Size = New-Object System.Drawing.Size(960, 800); $form.StartPosition = "CenterScreen"; $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30); $form.ForeColor = [System.Drawing.Color]::White
$fontHead = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold); $colorIn = [System.Drawing.Color]::FromArgb(50, 50, 50); $colorBtn = [System.Drawing.Color]::FromArgb(0, 122, 204)
$grp = New-Object System.Windows.Forms.GroupBox; $grp.Text = " SQL Connection "; $grp.Location = "10,10"; $grp.Size = "920,80"; $grp.ForeColor = "Cyan"; $form.Controls.Add($grp)
$lblS = New-Object System.Windows.Forms.Label; $lblS.Text="Server:"; $lblS.Location="15,30"; $lblS.AutoSize=$true; $grp.Controls.Add($lblS)
$txtS = New-Object System.Windows.Forms.TextBox; $txtS.Location="70,28"; $txtS.Size="180,25"; $txtS.BackColor=$colorIn; $txtS.ForeColor="White"; $txtS.Text=$env:COMPUTERNAME; $grp.Controls.Add($txtS)
$lblU = New-Object System.Windows.Forms.Label; $lblU.Text="User:"; $lblU.Location="260,30"; $lblU.AutoSize=$true; $grp.Controls.Add($lblU)
$txtU = New-Object System.Windows.Forms.TextBox; $txtU.Location="310,28"; $txtU.Size="120,25"; $txtU.BackColor=$colorIn; $txtU.ForeColor="White"; $txtU.Text="sa"; $grp.Controls.Add($txtU)
$lblP = New-Object System.Windows.Forms.Label; $lblP.Text="Pass:"; $lblP.Location="440,30"; $lblP.AutoSize=$true; $grp.Controls.Add($lblP)
$txtP = New-Object System.Windows.Forms.TextBox; $txtP.Location="490,28"; $txtP.Size="120,25"; $txtP.BackColor=$colorIn; $txtP.ForeColor="White"; $txtP.PasswordChar="*"; $grp.Controls.Add($txtP)
$btnCon = New-Object System.Windows.Forms.Button; $btnCon.Text="Connect"; $btnCon.Location="630,26"; $btnCon.Size="100,28"; $btnCon.BackColor=$colorBtn; $btnCon.FlatStyle="Flat"; $grp.Controls.Add($btnCon)
$chkAll = New-Object System.Windows.Forms.CheckBox; $chkAll.Text = "Select All"; $chkAll.Location = New-Object System.Drawing.Point(15, 100); $chkAll.AutoSize = $true; $chkAll.Font = $fontHead; $chkAll.ForeColor = [System.Drawing.Color]::Yellow; $form.Controls.Add($chkAll)
$listDBs = New-Object System.Windows.Forms.CheckedListBox; $listDBs.Location = "10,130"; $listDBs.Size = "300,400"; $listDBs.BackColor=$colorIn; $listDBs.ForeColor="White"; $listDBs.CheckOnClick=$true; $form.Controls.Add($listDBs)
$txtLog = New-Object System.Windows.Forms.RichTextBox; $txtLog.Location = "330,130"; $txtLog.Size = "600,400"; $txtLog.BackColor="Black"; $txtLog.ForeColor="LightGray"; $txtLog.ReadOnly=$true; $txtLog.Font="Consolas,9"; $form.Controls.Add($txtLog)
$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="Start Sync"; $btnSync.Location="10,550"; $btnSync.Size="250,45"; $btnSync.BackColor="Green"; $btnSync.ForeColor="White"; $btnSync.Font=$fontHead; $btnSync.FlatStyle="Flat"; $btnSync.Enabled=$false; $form.Controls.Add($btnSync)
$btnVer = New-Object System.Windows.Forms.Button; $btnVer.Text="Check Versions"; $btnVer.Location="270,550"; $btnVer.Size="250,45"; $btnVer.BackColor="DarkOrange"; $btnVer.FlatStyle="Flat"; $btnVer.Font=$fontHead; $btnVer.Enabled=$false; $form.Controls.Add($btnVer)
$grpUtil = New-Object System.Windows.Forms.GroupBox; $grpUtil.Text = " DB Utility Maintenance (Runs as Admin) "; $grpUtil.Location = "10,610"; $grpUtil.Size = "920,80"; $grpUtil.ForeColor = "Magenta"; $form.Controls.Add($grpUtil)
$btnUninstall = New-Object System.Windows.Forms.Button; $btnUninstall.Text="Uninstall DB Utility"; $btnUninstall.Location="20,25"; $btnUninstall.Size="200,40"; $btnUninstall.BackColor=[System.Drawing.Color]::DarkRed; $btnUninstall.ForeColor="White"; $btnUninstall.FlatStyle="Flat"; $grpUtil.Controls.Add($btnUninstall)
$btnInstall = New-Object System.Windows.Forms.Button; $btnInstall.Text="Install DB Utility"; $btnInstall.Location="240,25"; $btnInstall.Size="200,40"; $btnInstall.BackColor=[System.Drawing.Color]::DarkGreen; $btnInstall.ForeColor="White"; $btnInstall.FlatStyle="Flat"; $grpUtil.Controls.Add($btnInstall)
$lblStat = New-Object System.Windows.Forms.Label; $lblStat.Text="Ready."; $lblStat.Location="10,700"; $lblStat.AutoSize=$true; $lblStat.ForeColor="Yellow"; $form.Controls.Add($lblStat)
function Log-Write($text, $color="White") { $txtLog.SelectionStart = $txtLog.TextLength; $txtLog.SelectionColor = [System.Drawing.Color]::FromName($color); $txtLog.AppendText("$text`r`n"); $txtLog.ScrollToCaret(); [System.Windows.Forms.Application]::DoEvents() }
function Toggle-Inputs($enable) { $btnCon.Enabled = $enable; $btnSync.Enabled = $enable; $btnVer.Enabled = $enable; $btnUninstall.Enabled = $enable; $btnInstall.Enabled = $enable }
$chkAll.Add_CheckedChanged({ for ($i=0; $i -lt $listDBs.Items.Count; $i++) { $listDBs.SetItemChecked($i, $chkAll.Checked) } })
$btnCon.Add_Click({ Toggle-Inputs $false; $listDBs.Items.Clear(); $lblStat.Text = "Connecting..."; Log-Write "Connecting to SQL Server..." "Cyan"; try { $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=5"; $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open(); $cmd = $cn.CreateCommand(); $cmd.CommandText = "SELECT Name FROM sys.databases WHERE database_id > 4 AND Name NOT IN ('master','model','msdb','tempdb','ReportServer','ReportServerTempDB') ORDER BY Name"; $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close(); foreach($row in $ds.Tables[0].Rows) { [void]$listDBs.Items.Add($row.Name) }; Log-Write "✔ Connected! Found $($listDBs.Items.Count) databases." "Lime"; $lblStat.Text = "Connected." } catch { Log-Write "❌ Error: $($_.Exception.Message)" "Red"; if ($_.Exception.Message -match "error: 40") { Log-Write "   Hint: Check Server Name / Instance / Firewall" "Yellow" } } finally { Toggle-Inputs $true } })
$btnSync.Add_Click({ if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select a DB!"); return }; if (!$Script:DBSyncRoot) { Log-Write "DB Sync Not Installed!" "Red"; return }; Toggle-Inputs $false; $lblStat.Text = "Syncing..."; $folders = @{ Police = Join-Path $Script:DBSyncRoot "Police"; Fire = Join-Path $Script:DBSyncRoot "Fire"; IA = Join-Path $Script:DBSyncRoot "IA"; PhoenixMaster = Join-Path $Script:DBSyncRoot "Phoenix Master"; PoliceDW = Join-Path $Script:DBSyncRoot "Police DW" }; foreach ($db in $listDBs.CheckedItems) { Log-Write "--------------------------------" "Gray"; Log-Write "Processing: $db" "Yellow"; $lblStat.Text = "Processing $db..."; [System.Windows.Forms.Application]::DoEvents(); if ($db -match "Master$") { $k="PhoenixMaster" } elseif ($db -match "DW$") { $k="PoliceDW" } elseif ($db -match "Police") { $k="Police" } elseif ($db -match "Fire") { $k="Fire" } elseif ($db -match "IA") { $k="IA" } else { Log-Write "Skipped (Unknown Type)" "Gray"; continue }; $target = $folders[$k]; if (!(Test-Path $target)) { Log-Write "Missing Folder: $target" "Red"; continue }; try { [xml]$x = Get-Content $Script:XmlTarget; $x.PnxPakager.SourceServer.IPAddress=$txtS.Text; $x.PnxPakager.SourceServer.DBName=$db; $x.PnxPakager.SourceServer.UserName=$txtU.Text; $x.PnxPakager.SourceServer.Password=$txtP.Text; $x.Save((Join-Path $target "PnxAutoNewDBSyn.xml")); $exe = Join-Path $target "PnxDBSync.exe"; if (!(Test-Path $exe)) { Log-Write "Missing EXE" "Red"; continue }; $proc = Start-Process -FilePath $exe -Wait -PassThru -WindowStyle Minimized; while (-not $proc.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 200 }; Start-Sleep -Seconds 1; $l = Get-ChildItem $target -Filter "DBToolLog*.txt" | Sort LastWriteTime -Desc | Select -First 1; if ($l) { $c = Get-Content $l.FullName -Raw; if ($c -match "DB Version Updated") { Log-Write "✔ SUCCESS" "Lime" } else { Log-Write "❌ FAILED (Check Log)" "Red"; $backupName = "DBToolLog_${db}_FAILED_$(Get-Date -f yyyyMMdd_HHmmss).txt"; $backupPath = Join-Path $target $backupName; Copy-Item $l.FullName $backupPath -Force; Log-Write "   ↳ Log Backed Up: $backupName" "Orange" } } else { Log-Write "⚠ LOG MISSING" "Red" } } catch { Log-Write "Error: $($_.Exception.Message)" "Red" } }; $lblStat.Text = "Ready."; Toggle-Inputs $true; [System.Windows.Forms.MessageBox]::Show("Operation Completed", "Done") })
$btnVer.Add_Click({ if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select databases to check!"); return }; Toggle-Inputs $false; $lblStat.Text = "Checking Versions..."; Log-Write "Checking DB Versions for SELECTED items..." "Cyan"; try { $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=30"; $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open(); $sb = New-Object System.Text.StringBuilder; $sb.Append("DECLARE @s NVARCHAR(MAX)=''; CREATE TABLE #R(N NVARCHAR(255),V NVARCHAR(MAX)); "); foreach ($db in $listDBs.CheckedItems) { $safeDB = $db.ToString().Replace("'", "''"); $sb.Append(" IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$safeDB') "); $sb.Append("   BEGIN IF EXISTS(SELECT 1 FROM [$safeDB].sys.tables WHERE name='KPIDBVersion') "); $sb.Append("     INSERT INTO #R SELECT '$safeDB', CAST(Version AS NVARCHAR(MAX)) FROM [$safeDB].dbo.KPIDBVersion; "); $sb.Append("   ELSE INSERT INTO #R VALUES ('$safeDB', 'Table Missing'); END "); $sb.Append(" ELSE INSERT INTO #R VALUES ('$safeDB', 'DB Not Found'); ") }; $sb.Append(" SELECT * FROM #R ORDER BY N; DROP TABLE #R;"); $cmd = $cn.CreateCommand(); $cmd.CommandText = $sb.ToString(); $da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds=New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close(); Log-Write "=== VERSION REPORT ===" "White"; foreach($r in $ds.Tables[0].Rows) { Log-Write "$($r.N) : $($r.V)" "White" } } catch { Log-Write "Error: $($_.Exception.Message)" "Red" } finally { Toggle-Inputs $true; $lblStat.Text = "Ready." } })
$RunAppMgrAction = { param($Action, $IsLocal); $FileName = "Appreg_main.xml"; $PossibleParents = @("ProPhoenix\Server Application Manager", "Program Files (x86)\ProPhoenix\Server Application Manager", "Program Files\ProPhoenix\Server Application Manager"); $Drives = Get-PSDrive -PSProvider FileSystem; $AppRegPath = $null; foreach ($d in $Drives) { foreach ($folder in $PossibleParents) { $TryPath = Join-Path -Path $d.Root -ChildPath $folder | Join-Path -ChildPath $FileName; if (Test-Path $TryPath) { $AppRegPath = $TryPath; break } }; if ($AppRegPath) { break } }; if (-not $AppRegPath) { return "ERROR: Appreg_main.xml not found." }; $AppMgrFolder = Split-Path -Path $AppRegPath -Parent; $ExePath = Join-Path $AppMgrFolder "PnxAppMgr.exe"; if (-not (Test-Path $ExePath)) { return "ERROR: PnxAppMgr.exe not found." }; $PnxTemp = "C:\pnxtemp\dbsynctool"; if (-not (Test-Path $PnxTemp)) { New-Item -ItemType Directory -Path $PnxTemp -Force | Out-Null }; $BatFile = Join-Path $PnxTemp "Execute_DBUtil_$Action.bat"; $BatchContent = @"
@echo off
echo ===========================================
echo   PROPHOENIX DB UTILITY MANAGER
echo   Action: $Action
echo ===========================================
cd /d "$AppMgrFolder"
echo Running: PnxAppMgr.exe $Action DBUtility
"PnxAppMgr.exe" "$Action" "DBUtility"
echo.
echo Process Complete.
pause
"@; Set-Content -Path $BatFile -Value $BatchContent -Encoding ASCII; if ($IsLocal) { Start-Process -FilePath $BatFile -Verb RunAs; return "SUCCESS: Launched $Action (Check Popup Window)" } else { Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$BatFile`"" -Wait; return "SUCCESS: Executed $Action Remotely" } }
function Exec-Utility($actionName) { Toggle-Inputs $false; $lblStat.Text = "$actionName DB Utility..."; Log-Write "Preparing $actionName for DB Utility..." "Cyan"; $Target = $txtS.Text; $IsLocal = ($Target -eq "localhost" -or $Target -eq $env:COMPUTERNAME -or $Target -eq "127.0.0.1"); try { if ($IsLocal) { $res = & $RunAppMgrAction -Action $actionName -IsLocal $true; if ($res -match "SUCCESS") { Log-Write $res "Lime" } else { Log-Write $res "Red" } } else { Log-Write "Connecting to Remote Server: $Target..." "Yellow"; $s = New-PSSession -ComputerName $Target -ErrorAction Stop; $res = Invoke-Command -Session $s -ScriptBlock $RunAppMgrAction -ArgumentList $actionName, $false; Remove-PSSession $s; if ($res -match "SUCCESS") { Log-Write $res "Lime" } else { Log-Write $res "Red" } } } catch { Log-Write "Utility Error: $($_.Exception.Message)" "Red" } finally { Toggle-Inputs $true; $lblStat.Text = "Ready." } }
$btnUninstall.Add_Click({ Exec-Utility "UNINSTALL" }); $btnInstall.Add_Click({ Exec-Utility "INSTALL" }); $form.Add_Shown({ $form.Activate() }); [void] $form.ShowDialog()
'@

# --- SCRIPT 3: Cad_Hotfixupdate_v2.0.ps1 (PD CAD) ---
$Content_CAD = @'
<#
.SYNOPSIS
    ProPhoenix Hotfix Automation (Production / Installation Team).
#>
Clear-Host
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "   ProPhoenix Hotfix Automation v2.0 (PRODUCTION)  " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
$TargetServer = Read-Host "Enter Target Server Name (Press ENTER for Localhost)"
if ([string]::IsNullOrWhiteSpace($TargetServer)) { $TargetServer = "localhost"; $RunRemote = $false; Write-Host "-> Selected Mode: LOCAL EXECUTION" -ForegroundColor Green } else { $RunRemote = $true; Write-Host "-> Selected Mode: REMOTE EXECUTION on $TargetServer" -ForegroundColor Yellow }
Write-Host "==============================================" -ForegroundColor Cyan

$GeneratorLogic = {
    $ErrorActionPreference = "Continue"
    $CurrentHostName = $env:COMPUTERNAME

    $LogClearScriptContent = @"
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
Write-Host "========================================="
Write-Host "      CLEANUP UTILITY (Logs & Session)   "
Write-Host "========================================="
`$proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object { "`$(`$_.Root)\Program Files\ProPhoenix" } | Where-Object { Test-Path -Path `$_ }
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
                Get-ChildItem -Path `$oldPath -File -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-Item -Path `$_.FullName -Force -ErrorAction Stop } catch { } }
                `$movedCount = 0
                Get-ChildItem -Path `$logPath -File -ErrorAction SilentlyContinue | Where-Object { `$_.FullName -notlike "*\old*" } | ForEach-Object { try { Move-Item -LiteralPath `$_.FullName -Destination `$oldPath -Force -ErrorAction Stop; Write-Host "   [MOVED] `$(`$_.Name) -> old"; `$movedCount++ } catch { Write-Host "   [LOCKED] `$(`$_.Name) (Skipped)" -ForegroundColor DarkGray } }
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
                Get-ChildItem -Path `$sessionDataPath -File -ErrorAction SilentlyContinue | ForEach-Object { try { Remove-Item -Path `$_.FullName -Force -ErrorAction Stop; Write-Host "   [DELETED] `$(`$_.Name)"; `$delCount++ } catch { Write-Host "   [LOCKED] `$(`$_.Name)" -ForegroundColor DarkGray } }
                if (`$delCount -eq 0) { Write-Host "   (No session files found)" }
            }
        }
    }
}
Write-Host "[SUCCESS] Cleanup Complete."
"@

    $VerificationScriptContent = @"
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
function Log-Msg { param([string]`$Msg, [ConsoleColor]`$Color = "White"); Write-Host `$Msg -ForegroundColor `$Color }
Log-Msg "[INFO] Starting DLL verification..." "Cyan"
`$prophoenixPaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object { "`$(`$_.Root)Program Files\ProPhoenix" } | Where-Object { Test-Path `$_ }
`$excludedFolders = @("Finger Print Client","ID Scanner","Phoenix WDA V2","Police RMS","PoliceRMS","Print Server","WDA"); `$completedCount = 0; `$notCompletedCount = 0;
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
                    if (`$match) { if ((`$match.LastWriteTime -lt `$dll.LastWriteTime) -or (`$match.Length -ne `$dll.Length)) { `$status = "Not Completed"; break } } else { `$status = "Not Completed"; break }
                }
                if (`$status -eq "Completed") { `$completedCount++; Log-Msg "[OK] `$(`$app.Name) -> `$(`$env.Name)" "Green" } else { `$notCompletedCount++; Log-Msg "[FAIL] `$(`$app.Name) -> `$(`$env.Name) (DLL Mismatch)" "Red" }
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

    $ClientAppsDef = @{ "CAD Client"="KPI.Phoenix.CADClient.exe"; "WDA"="KPI.Phoenix.CADMobileClient.exe"; "Phoenix WDA V2"="Phoenix.WDAV2.Client.Shell.exe" }
    $ServiceProductList = @("JobServer", "TraCSServer", "VideoServer", "FingerPrintServer", "EmailWatcher", "CADServer", "CADNLBServer", "CAD2CADTellusServer", "E911Server", "ZetronServer", "ExternalInterface", "GPSServer", "NCICServer", "NCICStateServer", "FTPServer", "LocutionCADVoiceServer", "DeviceNotification", "StreamingNotification", "ReportService", "FolderWatcher", "DocsServer", "PhoenixTonerServer", "PhoenixAlertApp", "PhoenixTExt2Dispatch", "PHOENIXAIWATCHERSERVICE", "PHOENIXJOBSVRV2")
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
    Write-Host "   ProPhoenix Hotfix Automation (Installation Team)  " -ForegroundColor Yellow
    Write-Host "   HOST: $CurrentHostName" -ForegroundColor Yellow
    Write-Host "==============================================" -ForegroundColor Yellow
    $FileName = "Appreg_main.xml"
    $PossibleParents = @("ProPhoenix\Server Application Manager","Program Files (x86)\ProPhoenix\Server Application Manager","Program Files\ProPhoenix\Server Application Manager","ProPhoenix\Phoenix Server Application Manager","Program Files (x86)\ProPhoenix\Phoenix Server Application Manager","Program Files\ProPhoenix\Phoenix Server Application Manager")
    $Drives = Get-PSDrive -PSProvider FileSystem; $FoundFiles = @()
    foreach ($d in $Drives) { foreach ($folder in $PossibleParents) { $TestPath = Join-Path -Path $d.Root -ChildPath $folder; $FullFilePath = Join-Path -Path $TestPath -ChildPath $FileName; if (Test-Path $FullFilePath) { $FoundFiles += $FullFilePath } } }
    if ($FoundFiles.Count -eq 0) { Write-Error "No instances found. Exiting."; return }
    $ClientLaunchLogic = ""
    $CommonRoots = @("ProPhoenix", "Program Files\ProPhoenix", "Program Files (x86)\ProPhoenix")
    foreach ($key in ($ClientAppsDef.Keys | Sort-Object)) {
        $FoundClient = $false
        foreach ($d in $Drives) { foreach ($root in $CommonRoots) { $TryPath = Join-Path -Path $d.Root -ChildPath $root | Join-Path -ChildPath $key | Join-Path -ChildPath $ClientAppsDef[$key]; if (Test-Path $TryPath) { $ClientLaunchLogic += "echo Launching $key...`r`n"; $PSCommand = "`$path = '$TryPath'; `$desktop = [Environment]::GetFolderPath('Desktop'); `$public = [Environment]::GetFolderPath('CommonDesktopDirectory'); `$shell = New-Object -ComObject WScript.Shell; `$shortcut = Get-ChildItem -Path `$desktop, `$public -Filter '*.lnk' | Where-Object { `$shell.CreateShortcut(`$_.FullName).TargetPath -eq `$path } | Select-Object -First 1; if (`$shortcut) { Start-Process `$shortcut.FullName -Verb RunAs; } else { Start-Process `$path -Verb RunAs; }"; $ClientLaunchLogic += "%PSExe% -WindowStyle Hidden -Command `"$($PSCommand -replace "`r`n", " " -replace "\s+", " ")`"`r`n"; $FoundClient = $true; break } }; if ($FoundClient) { break } }
    }
    $InstanceCount = 1; $GeneratedBatFiles = @()
    foreach ($FoundPath in $FoundFiles) {
        Write-Host "`nPROCESSING INSTANCE #${InstanceCount}: $FoundPath" -ForegroundColor Yellow
        $AppMgrFolder = (Split-Path $FoundPath -Parent); $InstallDrive = (Split-Path $FoundPath -Qualifier)
        $LogDir = Join-Path -Path $AppMgrFolder -ChildPath "PnxLog\PrintLog"
        if (-not (Test-Path $LogDir)) { try { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null } catch {} }
        $PnxTempPath = Join-Path -Path (Split-Path $AppMgrFolder -Parent) -ChildPath "PnxTemp"
        if (-not (Test-Path $PnxTempPath)) { try { New-Item -ItemType Directory -Path $PnxTempPath -Force | Out-Null } catch {} }
        Set-Content -Path (Join-Path $PnxTempPath "LogClear.ps1") -Value $LogClearScriptContent -Encoding ASCII
        Set-Content -Path (Join-Path $PnxTempPath "InstanceVerification.ps1") -Value $VerificationScriptContent -Encoding ASCII
        $PathMap = @{}
        foreach ($m in [regex]::Matches($RawMappingData, '"([^"]+)=%PnxInstallPath%\\([^"]+)"')) { $PathMap[$m.Groups[2].Value.Replace("/", "\").Trim()] = $m.Groups[1].Value }
        try { [xml]$xmlData = Get-Content $FoundPath } catch { Write-Error "Invalid XML"; continue }
        $ProdInstallArgs = new-object System.Collections.Generic.List[string]; $StageInstallArgs = new-object System.Collections.Generic.List[string]; $UpdateArgs = new-object System.Collections.Generic.List[string]
        $ProdInstallArgs.Add('"INSTALL"'); $StageInstallArgs.Add('"INSTALL"'); $UpdateArgs.Add('"UPDATEINSTANCE"')
        if ($xmlData.PhoenixApplications.AppReg) { foreach ($app in $xmlData.PhoenixApplications.AppReg) { if ($app.CurrentVersion -ne "0.0.0.0") { $FPath = $app.AppPath.Replace("/", "\").Trim(); $BestID = $null; $BestLen = 0; foreach ($k in $PathMap.Keys) { if ($FPath.EndsWith($k, [System.StringComparison]::OrdinalIgnoreCase)) { if ($k.Length -gt $BestLen) { $BestID = $PathMap[$k]; $BestLen = $k.Length } } }; if ($BestID) { if ($BestID -match "(?i)Stage") { $StageInstallArgs.Add("`"$BestID`""); Write-Host "  [STAGE] $BestID" -ForegroundColor Gray } else { $ProdInstallArgs.Add("`"$BestID`""); if ($ServiceProductList -contains $BestID) { $UpdateArgs.Add("`"$BestID`"") }; Write-Host "  [PROD]  $BestID" -ForegroundColor Green } } } } }
        $ProdLine = $ProdInstallArgs -join " "; $StageLine = $StageInstallArgs -join " "; $UpdateLine = $UpdateArgs -join " "
        $UpdateCmd = ""; if ($UpdateArgs.Count -gt 1) { $UpdateCmd = "%AppMgrExePath%\PnxAppMgr.exe $UpdateLine | %PSExe% -Command `"`$input | ForEach-Object { Write-Host `$_; `$_ | Out-File -FilePath '%LOGFILE%' -Append -Encoding ASCII }`"" }
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
        $BaseName = "${CurrentHostName}_HotfixAutomation"; $Ext = ".bat"; $FinalName = "$BaseName$Ext"; $OutputBatFile = Join-Path -Path $PnxTempPath -ChildPath $FinalName; $Counter = 1
        while (Test-Path $OutputBatFile) { $FinalName = "${BaseName}_${Counter}${Ext}"; $OutputBatFile = Join-Path -Path $PnxTempPath -ChildPath $FinalName; $Counter++ }
        Set-Content -Path $OutputBatFile -Value $BatchContent -Encoding ASCII; $GeneratedBatFiles += $OutputBatFile
        Write-Host " [SUCCESS] Generated: $OutputBatFile" -ForegroundColor Green
        $InstanceCount++
    }
    return $GeneratedBatFiles
}

if ($RunRemote) {
    $Creds = Get-Credential
    try { Invoke-Command -ComputerName $TargetServer -Credential $Creds -ScriptBlock $GeneratorLogic; Write-Host "`n[INFO] Remote generation complete." -ForegroundColor Yellow } catch { Write-Error "Connection failed: $_" }
} else {
    $LocalBatFiles = & $GeneratorLogic
    if ($LocalBatFiles.Count -gt 0) { if ((Read-Host "`nRun Automation now? (Y/N)") -eq "Y") { foreach ($bat in $LocalBatFiles) { Start-Process -FilePath $bat -Verb RunAs } } }
}
'@

# ==============================================================================
#  3. DEPLOYMENT & EXECUTION LOGIC
# ==============================================================================
$SuitePath = "C:\pnxtemp\ProPhoenixSuite"
if (-not (Test-Path $SuitePath)) { New-Item -ItemType Directory -Path $SuitePath -Force | Out-Null }

# Define target paths
$Path_Demo = Join-Path $SuitePath "Autodefinedproducts_Vers3.1.ps1"
$Path_Sync = Join-Path $SuitePath "Autodbsync_v3.5_GUI.ps1"
$Path_CAD  = Join-Path $SuitePath "Cad_Hotfixupdate_v2.0.ps1"

# Write embedded scripts to disk
Set-Content -Path $Path_Demo -Value $Content_DemoTest -Force
Set-Content -Path $Path_Sync -Value $Content_DBSync -Force
Set-Content -Path $Path_CAD  -Value $Content_CAD -Force

# ==============================================================================
#  4. GUI LAUNCHER
# ==============================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "ProPhoenix Master Launcher"
$form.Size = New-Object System.Drawing.Size(420, 480)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = "White"

$fontBtn = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)

# --- TITLE ---
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "TOOL SELECTOR"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(0, 20)
$lblTitle.Size = New-Object System.Drawing.Size(400, 40)
$lblTitle.TextAlign = "MiddleCenter"
$lblTitle.ForeColor = "Cyan"
$form.Controls.Add($lblTitle)

# --- BUTTON 1: DEMO / TEST ---
$btnDemo = New-Object System.Windows.Forms.Button
$btnDemo.Text = "Hotfix Update - Demo / Test"
$btnDemo.Location = New-Object System.Drawing.Point(50, 80)
$btnDemo.Size = New-Object System.Drawing.Size(300, 60)
$btnDemo.BackColor = [System.Drawing.Color]::FromArgb(255, 140, 0) # Dark Orange
$btnDemo.ForeColor = "Black"
$btnDemo.Font = $fontBtn
$btnDemo.FlatStyle = "Flat"
$form.Controls.Add($btnDemo)

# --- BUTTON 2: DB SYNC ---
$btnSync = New-Object System.Windows.Forms.Button
$btnSync.Text = "DB Sync Update"
$btnSync.Location = New-Object System.Drawing.Point(50, 160)
$btnSync.Size = New-Object System.Drawing.Size(300, 60)
$btnSync.BackColor = [System.Drawing.Color]::FromArgb(0, 122, 204) # Blue
$btnSync.ForeColor = "White"
$btnSync.Font = $fontBtn
$btnSync.FlatStyle = "Flat"
$form.Controls.Add($btnSync)

# --- BUTTON 3: PD CAD ---
$btnCAD = New-Object System.Windows.Forms.Button
$btnCAD.Text = "Hotfix Update - PD CAD"
$btnCAD.Location = New-Object System.Drawing.Point(50, 240)
$btnCAD.Size = New-Object System.Drawing.Size(300, 60)
$btnCAD.BackColor = [System.Drawing.Color]::FromArgb(220, 20, 60) # Crimson Red
$btnCAD.ForeColor = "White"
$btnCAD.Font = $fontBtn
$btnCAD.FlatStyle = "Flat"
$form.Controls.Add($btnCAD)

# --- STATUS ---
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready. (Running as Administrator)"
$lblStatus.Location = New-Object System.Drawing.Point(0, 330)
$lblStatus.Size = New-Object System.Drawing.Size(400, 30)
$lblStatus.TextAlign = "MiddleCenter"
$lblStatus.ForeColor = "Gray"
$form.Controls.Add($lblStatus)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "Tools Path: $SuitePath"
$lblPath.Location = New-Object System.Drawing.Point(0, 360)
$lblPath.Size = New-Object System.Drawing.Size(400, 30)
$lblPath.TextAlign = "MiddleCenter"
$lblPath.ForeColor = "DarkGray"
$form.Controls.Add($lblPath)

# --- FUNCTION TO LAUNCH ---
function Launch-Script($scriptName, $fullPath) {
    if (Test-Path $fullPath) {
        $lblStatus.Text = "Launching $scriptName..."
        $lblStatus.ForeColor = "Yellow"
        [System.Windows.Forms.Application]::DoEvents()
        
        # Start separate process (keeps Launcher open)
        Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$fullPath`"" -Verb RunAs
        
        Start-Sleep -Seconds 1
        $lblStatus.Text = "Ready."
        $lblStatus.ForeColor = "Gray"
    } else {
        [System.Windows.Forms.MessageBox]::Show("Error: Script not found at $fullPath", "Missing File", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

# --- EVENTS ---
$btnDemo.Add_Click({ Launch-Script "Demo/Test" $Path_Demo })
$btnSync.Add_Click({ Launch-Script "DB Sync" $Path_Sync })
$btnCAD.Add_Click({  Launch-Script "PD CAD" $Path_CAD })

# --- SHOW FORM ---
$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()