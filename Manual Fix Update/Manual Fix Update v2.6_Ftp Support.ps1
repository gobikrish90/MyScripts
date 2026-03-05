# ==============================================================================
# SCRIPT: ProPhoenix Manual Fix Master (v54 - Precision Flow)
# FLOW: Selection -> Confirmation -> Backup -> Stop -> Apply -> Restart -> Verify
# ==============================================================================

# --- ELEVATION CHECK ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- CONFIGURATION ---
$specialPromptApps = @("CAD Client", "WDA", "Phoenix WDA V2", "PhoenixWDA", "WebDeviceAssistant")
$ServiceProductList = @("JobServer", "TraCSServer", "VideoServer", "FingerPrintServer", "EmailWatcher", "CADServer", "CADNLBServer", "CAD2CADTellusServer", "E911Server", "ZetronServer", "ExternalInterface", "GPSServer", "NCICServer", "NCICStateServer", "FTPServer", "LocutionCADVoiceServer", "DeviceNotification", "StreamingNotification", "ReportService", "FolderWatcher", "DocsServer", "PhoenixTonerServer", "PhoenixAlertApp", "PhoenixTExt2Dispatch", "PHOENIXAIWATCHERSERVICE", "PHOENIXJOBSVRV2")

# --- RAW MAPPING DATA ---
$RawMappingData = @"
::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "RMSRootPath" "PoliceRms=%PnxInstallPath%\Police RMS" "FireRms=%PnxInstallPath%\Fire RMS" "JobServer=%PnxInstallPath%\Job Server" "TraCSServer=%PnxInstallPath%\TraCS Server" "VideoServer=%PnxInstallPath%\Video Server" "FingerPrintServer=%PnxInstallPath%\Finger Print Server" "ReportServer=%PnxInstallPath%\Report Server" "ReportService=%PnxInstallPath%\Report Service" "PhoenixWebService=%PnxInstallPath%\WebService" "HazmatGuide=%PnxInstallPath%\User Docs" "FireWebService=%PnxInstallPath%\Fire WebService" "ProvisionManager=%PnxInstallPath%\Provision Manager" "FolderWatcher=%PnxInstallPath%\PnxFolderWatcher" "InternalAffair=%PnxInstallPath%\PhoenixIA" "NIBRS=%PnxInstallPath%\NIBRSInterface" "EmailWatcher=%PnxInstallPath%\Phoenix Email Watcher" "PoliceF1HelpDocs=%PnxInstallPath%\Police RMS\UserDocs" "FireF1HelpDocs=%PnxInstallPath%\Fire RMS\UserDocs" "IAF1HelpDocs=%PnxInstallPath%\PhoenixIA\UserDocs"
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "CADRootPath" "CADServer=%PnxInstallPath%\CAD Server" "CADNLBServer=%PnxInstallPath%\CAD NLB Message Server" "E911Server=%PnxInstallPath%\E911 Server" "GPSServer=%PnxInstallPath%\GPS Server" "ZetronServer=%PnxInstallPath%\CAD Zetron Server" "TonerWIServer=%PnxInstallPath%\Toner WI Server" "ExternalInterface=%PnxInstallPath%\External Interface Server" "NCICServer=%PnxInstallPath%\NCIC Server" "NCICStateServer=%PnxInstallPath%\NCIC State Server" "KGISPDServer=%PnxInstallPath%\KGIS PD WebService" "KGISCentralServer=%PnxInstallPath%\KGIS Central WebService" "LocutionCADVoiceServer=%PnxInstallPath%\Locution CAD Voice Server" "DeviceNotification=%PnxInstallPath%\Phoenix Device Notification" "DeviceNotification=%PnxInstallPath%\Device Notification Server" "PnxWDAAppWebService=%PnxInstallPath%\WDA App webservice" "PnxWDAAppWebService=%PnxInstallPath%\Fire Response CAD Webservice" "StreamingNotification=%PnxInstallPath%\Streaming Notification" "PhoenixAlertApp=%PnxInstallPath%\Alert App" "PhoenixTExt2Dispatch=%PnxInstallPath%\Text2Dispatch" "PhoenixTExt2Dispatch=%PnxInstallPath%\CADText2Dispatch" "PhoenixTExt2Dispatch=%PnxInstallPath%\CADTxt2Dispatch" "PhoenixTExt2Dispatch=%PnxInstallPath%\Txt2Dispatch" "CAD2CADTellusServer=%PnxInstallPath%\CAD2CAD Tellus Server" "ReportWriterAPI=%PnxInstallPath%\Phoenix Report Writer API"
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "OtherRootPath" "CitizenServices=%PnxInstallPath%\Citizen Services Link" "InmateLookup=%PnxInstallPath%\Inmate Lookup" "WIJIS=%PnxInstallPath%\WIJIS" "SWISS=%PnxInstallPath%\SWISS" "CJIN=%PnxInstallPath%\CJIN Integration Service" "NDEX=%PnxInstallPath%\WIJIS NDEX WebService" "FTPServer=%PnxInstallPath%\FTP Server" "CRM=%PnxInstallPath%\CRM" "InmateLocator=%PnxInstallPath%\Inmate Locator" "FireCSPWCF=%PnxInstallPath%\FireCSPhoenixLink" "PoliceCSPWebAPI=%PnxInstallPath%\CitizenServices" "FireCSPWebsite=%PnxInstallPath%\FireCitizenServices" "ADRWebService=%PnxInstallPath%\ADRCollectionRepositoryWS" "WhatsNewWebService=%PnxInstallPath%\WhatsNewWebService" "DocsServer=%PnxInstallPath%\DocsServer" "PhoenixTonerServer=%PnxInstallPath%\Toner Server" "JailCellCheck=%PnxInstallPath%\Jail Cell Check App Service" "ScenePD=%PnxInstallPath%\PhoenixScenePD" "PDFService=%PnxInstallPath%\PhoenixPDFService" "PDFService=%PnxInstallPath%\Phoenix PDF Service" "DBUtility=%PnxInstallPath%\Database Utility"
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "StageForClientAppsRootPath" "StageCADClient=%PnxInstallPath%\FTP\CAD Client Stage" "StageWDA=%PnxInstallPath%\FTP\WDA Stage" "StagePrintClient=%PnxInstallPath%\FTP\Print Server Stage" "StageClientAppManager=%PnxInstallPath%\FTP\Client Application Manager Stage" "StageFingerPrintClient=%PnxInstallPath%\FTP\Finger Print Client Stage" "StageIDScannerClient=%PnxInstallPath%\FTP\ID Scanner Stage" "StageStationKIOSKRFIDClient=%PnxInstallPath%\FTP\Station KIOSK RFID Client Stage" "StageRFIDClient=%PnxInstallPath%\FTP\RFID Client Stage" "StageAVLRecorder=%PnxInstallPath%\FTP\AVL Recorder Stage" "StageInOutClient=%PnxInstallPath%\FTP\In Out Client Stage" "StageZetronClient=%PnxInstallPath%\FTP\Zetron Client Stage" "StagePhoenixDashboard=%PnxInstallPath%\FTP\Phoenix Dashboard Stage" "StageMobileInspectionApp=%PnxInstallPath%\FTP\Mobile Inspection App Stage" "PHOENIXJOBSVRV2=%PnxInstallPath%\Job Server V2" "PHOENIXAIWATCHERSERVICE=%PnxInstallPath%\Phoenix AI Watcher" "PNXDIAGRAM=%PnxInstallPath%\PNXDiagram" "PNXDIAGRAMAPI=%PnxInstallPath%\PNXDiagramAPI" "INSPECTIONAPI=%PnxInstallPath%\Phoenix Inspection API" "FIRECSPCONVERSION=%PnxInstallPath%\Fire CSP Conversion" "CAMERASERVER=%PnxInstallPath%\Phoenix Camera Server" "PHOENIXPAWN=%PnxInstallPath%\Phoenix Pawn" "StagePhoenixWDAV2=%PnxInstallPath%\FTP\Phoenix WDA V2 Stage"
:: --- AUTOMATICALLY ADDED MAPPINGS ---
"Authenticator=%PnxInstallPath%\Phoenix Authenticator" "InterfaceFolderWatcher=%PnxInstallPath%\Phoenix Interface Folder Watcher" "RegionalCAD2CAD=%PnxInstallPath%\Phoenix Regional CAD2CAD Service" "CADLiveStreaming=%PnxInstallPath%\CADLiveStreamingService" "CADLiveStreaming=%PnxInstallPath%\Phoenix CAD Live Streaming Service" "DBUtilityCodeBook=%PnxInstallPath%\Phoenix Database Utility CodeBook" "CRMHubAPI=%PnxInstallPath%\CRMHubAPI" "PhoenixGateway=%PnxInstallPath%\Phoenix Gateway" "CSPProcessQueue=%PnxInstallPath%\CSPProcessQueueService" "CSPConversion=%PnxInstallPath%\CSP Conversion" "AIMugMatch=%PnxInstallPath%\PhoenixAIMugMatch" "AIAPI=%PnxInstallPath%\CRMHubAPI\PNXAIAPI" "ExpenseAPI=%PnxInstallPath%\CRMHubAPI\PNXExpenseAPI" "CustomerAPI=%PnxInstallPath%\CRMHubAPI\PNXCustomerAPI" "EmploymentClient=%PnxInstallPath%\Phoenix Employment Client" "AzureFileDownloader=%PnxInstallPath%\Azure File Downloader"
"@

# --- HELPER FUNCTIONS ---
function Write-Header ($text) {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "   $text" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Log-Action ($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp | $message"
    try { Add-Content -Path $global:logFile -Value $line -ErrorAction Stop } catch { }
}

function Find-ServerAppManager {
    $paths = @("C:\Program Files (x86)\ProPhoenix\Server Application Manager","C:\Program Files\ProPhoenix\Server Application Manager","D:\Program Files (x86)\ProPhoenix\Server Application Manager","D:\Program Files\ProPhoenix\Server Application Manager")
    foreach ($p in $paths) { if (Test-Path "$p\PnxAppMgr.exe") { return $p } }
    return $null
}

function Fix-InternetSettings {
    $zonePaths = @("HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Zones\3")
    foreach ($path in $zonePaths) {
        if (Test-Path $path) {
            Set-ItemProperty -Path $path -Name "1803" -Value 0 -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $path -Name "1400" -Value 0 -ErrorAction SilentlyContinue
        }
    }
}

function Download-FtpFile ($url, $dest, $creds) {
    $ftpRequest = [System.Net.FtpWebRequest]::Create($url)
    $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
    $ftpRequest.Credentials = $creds
    $ftpRequest.UseBinary = $true; $ftpRequest.KeepAlive = $false; $ftpRequest.UsePassive = $true
    $ftpResponse = $ftpRequest.GetResponse(); $responseStream = $ftpResponse.GetResponseStream()
    $fileStream = [System.IO.File]::Create($dest); $buffer = New-Object byte[] (1024 * 1024); $count = 0
    do { $count = $responseStream.Read($buffer, 0, $buffer.Length); $fileStream.Write($buffer, 0, $count) } while ($count -gt 0)
    $fileStream.Flush(); $fileStream.Close(); $responseStream.Close(); $ftpResponse.Close()
}

# --- STEP 1: INITIALIZE ---
Clear-Host; Fix-InternetSettings
$fixedDrives = Get-CimInstance Win32_LogicalDisk | ? {$_.DriveType -eq 3}
$targetDrive = $fixedDrives | ? {$_.DeviceID -ne "C:"} | Select -First 1
$rootDrive = if ($targetDrive) { $targetDrive.DeviceID } else { "C:" }
$dateFolder = Get-Date -Format "MMddyyyy"
$workPath = "$rootDrive\pnxtemp\manualdll\$dateFolder"
$global:logFile = "$workPath\Update_Log_$(Get-Date -Format 'HHmmss').txt"
if (-not (Test-Path $workPath)) { New-Item $workPath -ItemType Directory -Force | Out-Null }

Write-Header "STEP 1: DOWNLOAD & SETUP"
Write-Host "   Working Path: $workPath" -ForegroundColor Gray

# --- FTP LOGIC ---
$ftpUrlRaw = Read-Host "   🌐 Enter FTP Folder URL (Leave empty for Manual Copy)"
if ($ftpUrlRaw -ne "") {
    if (-not $ftpUrlRaw.EndsWith("/")) { $ftpUrlRaw += "/" }
    $ftpUser = Read-Host "   👤 FTP Username [Default: manualdll]"; if ($ftpUser -eq "") { $ftpUser = "manualdll" }
    $ftpPass = Read-Host "   🔑 FTP Password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ftpPass); $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR); $creds = New-Object System.Net.NetworkCredential($ftpUser, $plainPass)

    Write-Host "`n   🔄 Connecting to FTP to browse files..." -ForegroundColor Cyan
    try {
        $req = [System.Net.WebRequest]::Create($ftpUrlRaw); $req.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails; $req.Credentials = $creds; $req.UsePassive = $true
        $resp = $req.GetResponse(); $rdr = New-Object System.IO.StreamReader($resp.GetResponseStream()); $data = $rdr.ReadToEnd(); $rdr.Close(); $resp.Close()
        $lines = $data -split "`r`n"; $zipFound = $null
        foreach ($line in $lines) { if ($line -match ".*\.zip$") { $parts = $line -split "\s+"; $zipFound = $parts[-1]; Write-Host "      ✅ FOUND ZIP: $zipFound" -ForegroundColor Green } }
        
        if ($zipFound) {
            $dlUrl = "$ftpUrlRaw$zipFound"; $localZip = Join-Path $workPath $zipFound
            Write-Host "   ⬇️  Streaming Download (Reliable Mode): $zipFound" -ForegroundColor Yellow
            Download-FtpFile -url $dlUrl -dest $localZip -creds $creds
            if ((Get-Item $localZip).Length -gt 0) { Write-Host "   ✅ Download Complete: $localZip" -ForegroundColor Green } else { throw "0KB File" }
        } else { Write-Host "   ⚠️  No ZIP file found." -ForegroundColor Red }
    } catch { Write-Host "   ❌ FTP Error: $($_.Exception.Message)" -ForegroundColor Red; Write-Host "   ⚠️  Manual Copy Required." -ForegroundColor Yellow; Invoke-Item $workPath; Pause }
} else {
    Write-Host "   📂 Opening folder for manual paste..." -ForegroundColor Yellow
    Invoke-Item $workPath
    Write-Host "`n   ⚠️  ACTION REQUIRED: Paste ZIP file and press Enter." -ForegroundColor Magenta
    Pause
}

# --- EXTRACT ---
$zipFile = Get-ChildItem -Path $workPath -Filter "*.zip" | Select-Object -First 1
if (-not $zipFile) { Write-Host "❌ No ZIP found." -ForegroundColor Red; return }
$extractPath = Join-Path $workPath "Extracted_$(Get-Date -Format 'HHmmss')"
Expand-Archive -Path $zipFile.FullName -DestinationPath $extractPath -Force

# --- AUTO-DETECT ---
$detectedPaths = @(); Get-CimInstance Win32_LogicalDisk | ? {$_.DriveType -eq 3} | % { $p = "$($_.DeviceID)\Program Files\ProPhoenix"; if (Test-Path $p) { $detectedPaths += $p } }
$serverRoot = if ($detectedPaths.Count -gt 0) { $detectedPaths[0] } else { "C:\Program Files\ProPhoenix" }

# Discovery
$currentPath = $extractPath; $depth = 0
while ($depth -lt 5) {
    $items = Get-ChildItem -Path $currentPath
    $dirs = $items | Where-Object { $_.PSIsContainer }; $files = $items | Where-Object { -not $_.PSIsContainer }
    if ($dirs.Count -eq 1 -and $files.Count -eq 0) { $currentPath = $dirs[0].FullName } else { $zipApps = $dirs; break }
    $depth++
}

# --- MATCH & SELECT ---
$analysisList = @()
foreach ($app in $zipApps) {
    $status = "Unmatched"; $dPath = "N/A"; $cPath = Join-Path $serverRoot $app.Name
    if ($specialPromptApps -contains $app.Name) { $status = "Special/Manual" } elseif (Test-Path $cPath) { $status = "Matched"; $dPath = $cPath }
    $analysisList += [PSCustomObject]@{ AppName=$app.Name; Status=$status; Path=$dPath; Src=$app.FullName }
}

Write-Host "`n"
foreach ($i in $analysisList) {
    $lineColor = if($i.Status -eq "Matched"){"Green"}elseif($i.Status -eq "Unmatched"){"Red"}else{"Magenta"}
    Write-Host ("{0,-40} {1,-15} {2}" -f $i.AppName, $i.Status, $i.Path) -ForegroundColor $lineColor
}

Write-Host "`n[COPY-FRIENDLY LIST]" -ForegroundColor Cyan
Write-Host ($analysisList.AppName -join ", ") -ForegroundColor Yellow

Write-Host "`n[SELECTION]" -ForegroundColor Cyan
Write-Host "Type app names to update (comma separated)." -ForegroundColor Green
Write-Host "OR Press ENTER to update ALL (Matched apps auto-added, Unmatched apps will prompt)." -ForegroundColor Green
$selRaw = Read-Host "> Selection"

$appsToUpdate = @()
if ($selRaw -eq "") { $selectedApps = $analysisList } else { $names = $selRaw -split "," | % { $_.Trim() }; $selectedApps = $analysisList | ? { $names -contains $_.AppName } }

foreach ($item in $selectedApps) {
    if ($item.Status -eq "Matched") { $appsToUpdate += [PSCustomObject]@{ AppName=$item.AppName; SourcePath=$item.Src; DestPath=$item.Path } }
    else {
        $man = Read-Host "   Path for $($item.AppName)? (Enter to Skip)"
        if ($man -ne "") { $appsToUpdate += [PSCustomObject]@{ AppName=$item.AppName; SourcePath=$item.Src; DestPath=$man.Trim('"') } }
    }
}
if ($appsToUpdate.Count -eq 0) { return }

# --- SMART LOGIC ---
$FolderToInstanceMap = @{}
[regex]::Matches($RawMappingData, '"([^"=]+)=%PnxInstallPath%\\([^"]+)"') | % { $FolderToInstanceMap[$(Split-Path $_.Groups[2].Value -Leaf)] = $_.Groups[1].Value }

$StopIIS = $false; $StopPnx = $false
foreach ($app in $appsToUpdate) {
    $n = $app.AppName; $isInst = $false
    if ($FolderToInstanceMap.ContainsKey($n)) { if ($ServiceProductList -contains $FolderToInstanceMap[$n]) { $isInst = $true } } elseif ($ServiceProductList -contains $n) { $isInst = $true }
    if ($isInst) { $StopPnx = $true } else { $StopIIS = $true }
}

# --- EXECUTION CONFIRMATION ---
Write-Host "`n? Ready to STOP SERVICES and APPLY updates?" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------" -ForegroundColor Gray
Write-Host "[IIS]     Will be STOPPED (Web apps detected)" -ForegroundColor $(if($StopIIS){"Yellow"}else{"Green"})
Write-Host "[PHOENIX] Will be STOPPED (Instance apps detected)" -ForegroundColor $(if($StopPnx){"Yellow"}else{"Green"})
$response = Read-Host "Type Y to confirm"

if ($response -eq "Y" -or $response -eq "y") {
    
    # 1. BACKUP START (Requested Order: Backup -> Stop -> Apply)
    Write-Header "STEP 4: BACKUP & REVIEW"
    $backupRootBase = "$workPath\Backup"
    foreach ($app in $appsToUpdate) {
        Write-Host "`nScanning: $($app.AppName)" -ForegroundColor Cyan
        $files = Get-ChildItem $app.SourcePath -Recurse -File
        foreach ($f in $files) {
            $rel = $f.FullName.Substring($app.SourcePath.Length).TrimStart('\')
            $dst = Join-Path $app.DestPath $rel; $bak = Join-Path "$backupRootBase\$($app.AppName)" $rel
            if (Test-Path $dst) { 
                $null = New-Item -ItemType Directory -Path (Split-Path $bak) -Force; Copy-Item $dst $bak -Force
                Write-Host "   Backed up: $dst" -ForegroundColor Yellow
            }
        }
    }

    # 2. STOP
    Write-Header "STEP 5: STOPPING SERVICES"
    if ($StopIIS) { Write-Host "   Stopping IIS..." -ForegroundColor Yellow; iisreset /stop }
    if ($StopPnx) { Write-Host "   Stopping Phoenix Services..." -ForegroundColor Yellow; Get-Service | ? {$_.DisplayName -like "*Phoenix*" -and $_.Status -eq 'Running'} | Stop-Service -Force }

    # 3. APPLY
    Write-Header "STEP 6: APPLYING UPDATES"
    foreach ($app in $appsToUpdate) {
        Write-Host "   Applying: $($app.AppName)" -ForegroundColor Cyan
        $files = Get-ChildItem $app.SourcePath -Recurse -File
        foreach ($f in $files) {
            $rel = $f.FullName.Substring($app.SourcePath.Length).TrimStart('\')
            $dst = Join-Path $app.DestPath $rel
            $null = New-Item -ItemType Directory -Path (Split-Path $dst) -Force
            Copy-Item $f.FullName $dst -Force
        }
    }

    # 4. RESTART
    Write-Header "STEP 7: RESTART & FINISH"
    if ($StopIIS) { Write-Host "   Starting IIS..." -ForegroundColor Yellow; iisreset /start }
    
    # 5. INSTANCE BAT
    $batInstances = @()
    foreach ($app in $appsToUpdate) {
        $n = $app.AppName; $id = $null
        if ($FolderToInstanceMap.ContainsKey($n)) { $id = $FolderToInstanceMap[$n] } elseif ($ServiceProductList -contains $n) { $id = $n }
        if ($id -and ($ServiceProductList -contains $id)) { $batInstances += $id }
    }
    $batInstances = $batInstances | Select -Unique
    
    if ($batInstances) {
        $mgr = Find-ServerAppManager
        if ($mgr) {
            $batContent = @"
$((Split-Path $mgr -Qualifier))
cd "$mgr"
PnxAppMgr.exe "UPDATEINSTANCE" "$($batInstances -join '" "')"
PnxAppMgr.exe "SHOWINSTANCES"
"@
            Set-Content "$workPath\UpdateInstances.bat" $batContent
            Start-Process "$workPath\UpdateInstances.bat" -Wait
        }
    }
}

# --- STEP 11: GLOBAL VERIFICATION (DYNAMIC & CUSTOM) ---
Write-Header "STEP 11: GLOBAL VERIFICATION"
$nameMapping = @{ "Fire Response CAD Webservice"="WDA App webservice"; "PnxInspectionApi"="Phoenix Inspection API"; "Device Notification Server"="Phoenix Device Notification" }
$totalVerified = 0; $completed = 0; $notCompleted = 0

foreach ($app in $appsToUpdate) {
    $totalVerified++; $tgtFolder = $app.DestPath
    if (-not (Test-Path $tgtFolder)) { Write-Host "[FAIL] $($app.AppName) -> Live : o Not Installed" -ForegroundColor Red; $notCompleted++; continue }
    $srcFiles = Get-ChildItem $app.SourcePath -Recurse -File; $mismatch = $false
    foreach ($f in $srcFiles) {
        $rel = $f.FullName.Substring($app.SourcePath.Length).TrimStart('\'); $tgtFile = Join-Path $tgtFolder $rel
        if (Test-Path $tgtFile) { if ([Math]::Abs(($f.LastWriteTime - (Get-Item $tgtFile).LastWriteTime).TotalSeconds) -gt 5) { $mismatch = $true } } else { $mismatch = $true }
    }
    if (-not $mismatch) { Write-Host "[OK] $($app.AppName) -> Live : þ Completed" -ForegroundColor Green; $completed++ }
    else { Write-Host "[FAIL] $($app.AppName) -> Live : o Not Completed (Mismatch)" -ForegroundColor Red; $notCompleted++ }
}

Write-Host "`n[INFO] Summary: Total: $totalVerified | Completed: $completed | Errors: $notCompleted" -ForegroundColor Cyan

# --- STEP 12: FINAL START ---
Write-Header "STEP 12: FINALIZING"
if ((Read-Host "❓ Start remaining Phoenix Services? (Y/N)") -eq "Y") {
    Write-Host "   Starting Services..." -ForegroundColor Yellow
    Get-Service | Where-Object { $_.DisplayName -like "*Phoenix*" -and $_.Status -ne 'Running' } | Start-Service
}

Write-Host "`n✅ Done. Log: $global:logFile" -ForegroundColor Green
Pause