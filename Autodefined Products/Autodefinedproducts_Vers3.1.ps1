<#
.SYNOPSIS
    ProPhoenix Hotfix Automation  (Installation Team).
    
    FIXES APPLIED:
    1. FIXED BATCH ERROR: Removed the "&" symbol from "STEP 3" title to stop the 
       "'INSTALLATION' is not recognized" crash.
    2. FIXED RED TEXT ERROR: Completely removed "Tee-Object". Replaced with a 
       server-compatible loop that supports ASCII encoding on all Windows versions.
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