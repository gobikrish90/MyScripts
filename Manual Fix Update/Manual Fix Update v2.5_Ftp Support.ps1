# ==============================================================================
# SCRIPT: Manual Fix Update Applicator (v40 - Speed, Syntax & Defaults)
# PURPOSE: Fix "Method" Error -> 1MB Buffer -> Default User -> Auto-Detect -> Apply
# ==============================================================================

# --- CONFIGURATION ---
$minFreeSpaceGB = 5  
$specialPromptApps = @("CAD Client", "WDA", "Phoenix WDA V2", "PhoenixWDA", "WebDeviceAssistant")

# --- STRICT SERVICE LIST ---
$ServiceProductList = @(
    "JobServer", "TraCSServer", "VideoServer", "FingerPrintServer", "EmailWatcher", 
    "CADServer", "CADNLBServer", "CAD2CADTellusServer", "E911Server", "ZetronServer", 
    "ExternalInterface", "GPSServer", "NCICServer", "NCICStateServer", "FTPServer", 
    "LocutionCADVoiceServer", "DeviceNotification", "StreamingNotification", "ReportService", 
    "FolderWatcher", "DocsServer", "PhoenixTonerServer", "PhoenixAlertApp", "PhoenixTExt2Dispatch", 
    "PHOENIXAIWATCHERSERVICE", "PHOENIXJOBSVRV2"
)

# --- RAW MAPPING DATA ---
$RawMappingData = @"
::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "RMSRootPath" "PoliceRms=%PnxInstallPath%\Police RMS" "FireRms=%PnxInstallPath%\Fire RMS" "JobServer=%PnxInstallPath%\Job Server" "TraCSServer=%PnxInstallPath%\TraCS Server" "VideoServer=%PnxInstallPath%\Video Server" "FingerPrintServer=%PnxInstallPath%\Finger Print Server" "ReportServer=%PnxInstallPath%\Report Server" "ReportService=%PnxInstallPath%\Report Service" "PhoenixWebService=%PnxInstallPath%\WebService" "HazmatGuide=%PnxInstallPath%\User Docs" "FireWebService=%PnxInstallPath%\Fire WebService" "ProvisionManager=%PnxInstallPath%\Provision Manager" "FolderWatcher=%PnxInstallPath%\PnxFolderWatcher" "InternalAffair=%PnxInstallPath%\PhoenixIA" "NIBRS=%PnxInstallPath%\NIBRSInterface" "EmailWatcher=%PnxInstallPath%\Phoenix Email Watcher" "PoliceF1HelpDocs=%PnxInstallPath%\Police RMS\UserDocs" "FireF1HelpDocs=%PnxInstallPath%\Fire RMS\UserDocs" "IAF1HelpDocs=%PnxInstallPath%\PhoenixIA\UserDocs"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "CADRootPath" "CADServer=%PnxInstallPath%\CAD Server" "CADNLBServer=%PnxInstallPath%\CAD NLB Message Server" "E911Server=%PnxInstallPath%\E911 Server" "GPSServer=%PnxInstallPath%\GPS Server" "ZetronServer=%PnxInstallPath%\CAD Zetron Server" "TonerWIServer=%PnxInstallPath%\Toner WI Server" "ExternalInterface=%PnxInstallPath%\External Interface Server" "NCICServer=%PnxInstallPath%\NCIC Server" "NCICStateServer=%PnxInstallPath%\NCIC State Server" "KGISPDServer=%PnxInstallPath%\KGIS PD WebService" "KGISCentralServer=%PnxInstallPath%\KGIS Central WebService" "LocutionCADVoiceServer=%PnxInstallPath%\Locution CAD Voice Server" "DeviceNotification=%PnxInstallPath%\Phoenix Device Notification" "DeviceNotification=%PnxInstallPath%\Device Notification Server" "PnxWDAAppWebService=%PnxInstallPath%\WDA App webservice" "PnxWDAAppWebService=%PnxInstallPath%\Fire Response CAD Webservice" "StreamingNotification=%PnxInstallPath%\Streaming Notification" "PhoenixAlertApp=%PnxInstallPath%\Alert App" "PhoenixTExt2Dispatch=%PnxInstallPath%\Text2Dispatch" "PhoenixTExt2Dispatch=%PnxInstallPath%\CADText2Dispatch" "PhoenixTExt2Dispatch=%PnxInstallPath%\CADTxt2Dispatch" "PhoenixTExt2Dispatch=%PnxInstallPath%\Txt2Dispatch" "CAD2CADTellusServer=%PnxInstallPath%\CAD2CAD Tellus Server" "ReportWriterAPI=%PnxInstallPath%\Phoenix Report Writer API"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "OtherRootPath" "CitizenServices=%PnxInstallPath%\Citizen Services Link" "InmateLookup=%PnxInstallPath%\Inmate Lookup" "WIJIS=%PnxInstallPath%\WIJIS" "SWISS=%PnxInstallPath%\SWISS" "CJIN=%PnxInstallPath%\CJIN Integration Service" "NDEX=%PnxInstallPath%\WIJIS NDEX WebService" "FTPServer=%PnxInstallPath%\FTP Server" "CRM=%PnxInstallPath%\CRM" "InmateLocator=%PnxInstallPath%\Inmate Locator" "FireCSPWCF=%PnxInstallPath%\FireCSPhoenixLink" "PoliceCSPWebAPI=%PnxInstallPath%\CitizenServices" "FireCSPWebsite=%PnxInstallPath%\FireCitizenServices" "ADRWebService=%PnxInstallPath%\ADRCollectionRepositoryWS" "WhatsNewWebService=%PnxInstallPath%\WhatsNewWebService" "DocsServer=%PnxInstallPath%\DocsServer" "PhoenixTonerServer=%PnxInstallPath%\Toner Server" "JailCellCheck=%PnxInstallPath%\Jail Cell Check App Service" "ScenePD=%PnxInstallPath%\PhoenixScenePD" "PDFService=%PnxInstallPath%\PhoenixPDFService" "PDFService=%PnxInstallPath%\Phoenix PDF Service" "DBUtility=%PnxInstallPath%\Database Utility"

::Script - Updating Root path for all products
%AppMgrExePath%\PnxAppMgr.exe "MAINSETTINGS" "StageForClientAppsRootPath" "StageCADClient=%PnxInstallPath%\FTP\CAD Client Stage" "StageWDA=%PnxInstallPath%\FTP\WDA Stage" "StagePrintClient=%PnxInstallPath%\FTP\Print Server Stage" "StageClientAppManager=%PnxInstallPath%\FTP\Client Application Manager Stage" "StageFingerPrintClient=%PnxInstallPath%\FTP\Finger Print Client Stage" "StageIDScannerClient=%PnxInstallPath%\FTP\ID Scanner Stage" "StageStationKIOSKRFIDClient=%PnxInstallPath%\FTP\Station KIOSK RFID Client Stage" "StageRFIDClient=%PnxInstallPath%\FTP\RFID Client Stage" "StageAVLRecorder=%PnxInstallPath%\FTP\AVL Recorder Stage" "StageInOutClient=%PnxInstallPath%\FTP\In Out Client Stage" "StageZetronClient=%PnxInstallPath%\FTP\Zetron Client Stage" "StagePhoenixDashboard=%PnxInstallPath%\FTP\Phoenix Dashboard Stage" "StageMobileInspectionApp=%PnxInstallPath%\FTP\Mobile Inspection App Stage" "PHOENIXJOBSVRV2=%PnxInstallPath%\Job Server V2" "PHOENIXAIWATCHERSERVICE=%PnxInstallPath%\Phoenix AI Watcher" "PNXDIAGRAM=%PnxInstallPath%\PNXDiagram" "PNXDIAGRAMAPI=%PnxInstallPath%\PNXDiagramAPI" "INSPECTIONAPI=%PnxInstallPath%\Phoenix Inspection API" "FIRECSPCONVERSION=%PnxInstallPath%\Fire CSP Conversion" "CAMERASERVER=%PnxInstallPath%\Phoenix Camera Server" "PHOENIXPAWN=%PnxInstallPath%\Phoenix Pawn" "StagePhoenixWDAV2=%PnxInstallPath%\FTP\Phoenix WDA V2 Stage"

:: --- AUTOMATICALLY ADDED MAPPINGS ---
"Authenticator=%PnxInstallPath%\Phoenix Authenticator" "InterfaceFolderWatcher=%PnxInstallPath%\Phoenix Interface Folder Watcher" "RegionalCAD2CAD=%PnxInstallPath%\Phoenix Regional CAD2CAD Service" "CADLiveStreaming=%PnxInstallPath%\CADLiveStreamingService" "CADLiveStreaming=%PnxInstallPath%\Phoenix CAD Live Streaming Service" "DBUtilityCodeBook=%PnxInstallPath%\Phoenix Database Utility CodeBook" "CRMHubAPI=%PnxInstallPath%\CRMHubAPI" "PhoenixGateway=%PnxInstallPath%\Phoenix Gateway" "CSPProcessQueue=%PnxInstallPath%\CSPProcessQueueService" "CSPConversion=%PnxInstallPath%\CSP Conversion" "AIMugMatch=%PnxInstallPath%\PhoenixAIMugMatch" "AIAPI=%PnxInstallPath%\CRMHubAPI\PNXAIAPI" "ExpenseAPI=%PnxInstallPath%\CRMHubAPI\PNXExpenseAPI" "CustomerAPI=%PnxInstallPath%\CRMHubAPI\PNXCustomerAPI" "EmploymentClient=%PnxInstallPath%\Phoenix Employment Client" "AzureFileDownloader=%PnxInstallPath%\Azure File Downloader"
"@

# --- HELPER FUNCTIONS ---
function Write-Header ($text) {
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "   $text" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Log-Action "HEADER: $text"
}

function Log-Action ($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp | $message"
    try { Add-Content -Path $global:logFile -Value $line -ErrorAction Stop } catch { }
}

function Find-ServerAppManager {
    $paths = @(
        "C:\Program Files (x86)\ProPhoenix\Server Application Manager",
        "C:\Program Files\ProPhoenix\Server Application Manager",
        "D:\Program Files (x86)\ProPhoenix\Server Application Manager",
        "D:\Program Files\ProPhoenix\Server Application Manager"
    )
    foreach ($p in $paths) { if (Test-Path "$p\PnxAppMgr.exe") { return $p } }
    return $null
}

# --- FAST FTP DOWNLOADER (FIXED) ---
function Download-FtpFile ($url, $dest, $creds) {
    $ftpRequest = [System.Net.FtpWebRequest]::Create($url)
    $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
    $ftpRequest.Credentials = $creds
    $ftpRequest.UseBinary = $true
    $ftpRequest.KeepAlive = $false
    $ftpRequest.UsePassive = $true

    $ftpResponse = $ftpRequest.GetResponse()
    $responseStream = $ftpResponse.GetResponseStream()
    
    $fileStream = [System.IO.File]::Create($dest)
    # INCREASED BUFFER SIZE TO 1MB FOR SPEED
    $buffer = New-Object byte[] (1024 * 1024) 
    $count = 0
    
    do {
        $count = $responseStream.Read($buffer, 0, $buffer.Length)
        $fileStream.Write($buffer, 0, $count)
    } while ($count -gt 0)
    
    $fileStream.Flush()
    $fileStream.Close()
    $responseStream.Close()
    $ftpResponse.Close()
}

# --- STEP 1: INITIALIZE ---
Clear-Host
$fixedDrives = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
$targetDrive = $fixedDrives | Where-Object { $_.DeviceID -ne "C:" } | Select-Object -First 1
if ($targetDrive) { $rootDrive = $targetDrive.DeviceID } else { $rootDrive = "C:" }

$dateFolder = Get-Date -Format "MMddyyyy"
$workPath = "$rootDrive\pnxtemp\manualdll\$dateFolder"
$global:logFile = "$workPath\Update_Log_$(Get-Date -Format 'HHmmss').txt"

if (-not (Test-Path -Path $workPath)) { New-Item -Path $workPath -ItemType Directory -Force | Out-Null }

Write-Header "STEP 1: DOWNLOAD & SETUP"
Write-Host "   Working Path: $workPath" -ForegroundColor Gray
Log-Action "Started at $workPath"

# --- FTP AUTO-DOWNLOAD ---
$ftpUrlRaw = Read-Host "   🌐 Enter FTP Folder URL (e.g. ftp://site.com/Release/)"
if ($ftpUrlRaw -ne "") {
    
    if (-not $ftpUrlRaw.EndsWith("/")) { $ftpUrlRaw += "/" }
    
    # Default Username: manualdll
    $ftpUser = Read-Host "   👤 FTP Username [Default: manualdll]"
    if ($ftpUser -eq "") { $ftpUser = "manualdll" }
    
    $ftpPass = Read-Host "   🔑 FTP Password" -AsSecureString
    
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ftpPass)
    $plainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    $creds = New-Object System.Net.NetworkCredential($ftpUser, $plainPass)

    Write-Host "`n   🔄 Connecting to FTP..." -ForegroundColor Cyan
    
    try {
        # 1. LIST & FIND
        $listRequest = [System.Net.WebRequest]::Create($ftpUrlRaw)
        $listRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
        $listRequest.Credentials = $creds
        $listRequest.UsePassive = $true
        
        $response = $listRequest.GetResponse()
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        $listing = $reader.ReadToEnd()
        $reader.Close()
        $response.Close()
        
        $lines = $listing -split "`r`n"
        $zipFound = $null
        
        Write-Host "   📂 FTP Contents:" -ForegroundColor Gray
        foreach ($line in $lines) {
            if ($line -match ".*\.zip$") {
                $parts = $line -split "\s+"
                $fileName = $parts[-1]
                $zipFound = $fileName
                Write-Host "      ✅ FOUND ZIP: $fileName" -ForegroundColor Green
            }
        }
        
        if ($zipFound) {
            $fullFileUrl = "$ftpUrlRaw$zipFound"
            $destZip = Join-Path $workPath $zipFound
            
            Write-Host "`n   ⬇️  Streaming Download (High Speed): $zipFound" -ForegroundColor Yellow
            
            # 2. DOWNLOAD
            Download-FtpFile -url $fullFileUrl -dest $destZip -creds $creds
            
            $finalItem = Get-Item $destZip
            if ($finalItem.Length -gt 0) {
                # FIXED: SYNTAX ERROR [Math]::Round instead of Method ::Round
                $sizeMB = [Math]::Round($finalItem.Length / 1MB, 2)
                Write-Host "   ✅ Download Complete: $sizeMB MB" -ForegroundColor Green
                Log-Action "Downloaded $fullFileUrl ($sizeMB MB)"
            } else {
                throw "File size is 0KB after download."
            }
        } else {
            Write-Host "   ⚠️  No .zip file found." -ForegroundColor Red
        }
        
    } catch {
        Write-Host "`n   ❌ FTP ERROR: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.InnerException) { Write-Host "      Details: $($_.Exception.InnerException.Message)" -ForegroundColor Red }
        Write-Host "`n   ⚠️  Fallback: Please manually copy the ZIP to: $workPath" -ForegroundColor Yellow
        Invoke-Item $workPath
        Pause
    }
}

# CHECK ZIP
$zipFile = Get-ChildItem -Path $workPath -Filter "*.zip" | Select-Object -First 1
if (-not $zipFile) {
    Write-Host "❌ No ZIP file found in $workPath." -ForegroundColor Red
    return
}

Write-Header "STEP 2: EXTRACTING"
Write-Host "   Source: $($zipFile.Name)" -ForegroundColor Yellow
$extractPath = Join-Path $workPath "Extracted_$(Get-Date -Format 'HHmmss')"
Expand-Archive -Path $zipFile.FullName -DestinationPath $extractPath -Force
Write-Host "   ✅ Extraction Complete." -ForegroundColor Green

# DISCOVERY
$currentPath = $extractPath
$depth = 0
while ($depth -lt 5) {
    $items = Get-ChildItem -Path $currentPath
    $dirs = $items | Where-Object { $_.PSIsContainer }
    $files = $items | Where-Object { -not $_.PSIsContainer }
    if ($dirs.Count -eq 1 -and $files.Count -eq 0) { $currentPath = $dirs[0].FullName } else { $zipApps = $dirs; break }
    $depth++
}

# --- STEP 3: PATH DETECTION & SELECTION ---
Write-Header "STEP 3: PATH DETECTION & SELECTION"

# 1. Detect Installed Paths
$detectedPaths = @()
$possibleDrives = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DriveType -eq 3 }
foreach ($disk in $possibleDrives) {
    $p = "$($disk.DeviceID)\Program Files\ProPhoenix"
    if (Test-Path $p) { $detectedPaths += $p }
}

# 2. Smart Notification
$serverRoot = $null
if ($detectedPaths.Count -gt 1) {
    Write-Host "   ⚠️  MULTIPLE INSTALLATIONS DETECTED:" -ForegroundColor Magenta
    $detectedPaths | ForEach-Object { Write-Host "      - $_" -ForegroundColor Yellow }
    $defaultServer = $detectedPaths | Where-Object { $_ -like "D:*" } | Select-Object -First 1
    if (-not $defaultServer) { $defaultServer = $detectedPaths[0] }
    Write-Host "`n   (Defaulting to: $defaultServer)" -ForegroundColor Gray
} 
elseif ($detectedPaths.Count -eq 1) {
    $defaultServer = $detectedPaths[0]
    Write-Host "   ✅ Single Installation Detected: $defaultServer" -ForegroundColor Green
} 
else {
    $defaultServer = "C:\Program Files\ProPhoenix"
    Write-Host "   ⚠️  No installation found. Defaulting to C:..." -ForegroundColor DarkGray
}

$serverRoot = Read-Host "   Enter Server Root Path [Press Enter for '$defaultServer']"
if ($serverRoot -eq "") { $serverRoot = $defaultServer }

# 3. Analyze Matches
$analysisList = @()
foreach ($app in $zipApps) {
    $status = "Unmatched"
    $detectedPath = "N/A"
    $checkPath = Join-Path $serverRoot $app.Name
    
    if ($specialPromptApps -contains $app.Name) { $status = "Special/Manual" } 
    elseif (Test-Path $checkPath) { $status = "Matched"; $detectedPath = $checkPath }
    
    $analysisList += [PSCustomObject]@{ AppName = $app.Name; Status = $status; DetectedPath = $detectedPath; SourcePath = $app.FullName }
}

# 4. Display Report (Color Fixed)
Write-Host "`n   [AVAILABLE APPLICATIONS]" -ForegroundColor Cyan
Write-Host "   --------------------------------------------------------------------------------" -ForegroundColor Gray
Write-Host ("   {0,-40} {1,-15} {2}" -f "Application Name", "Status", "Detected Path") -ForegroundColor Gray
Write-Host "   --------------------------------------------------------------------------------" -ForegroundColor Gray

foreach ($item in $analysisList) {
    $color = "White"
    if ($item.Status -eq "Matched") { $color = "Green" }
    elseif ($item.Status -eq "Special/Manual") { $color = "Magenta" }
    elseif ($item.Status -eq "Unmatched") { $color = "Red" }
    Write-Host ("   {0,-40} {1,-15} {2}" -f $item.AppName, $item.Status, $item.DetectedPath) -ForegroundColor $color
}
Write-Host "   --------------------------------------------------------------------------------" -ForegroundColor Gray

# 5. Selection
$allAppNames = ($analysisList.AppName -join ", ")
Write-Host "`n   [COPY-FRIENDLY LIST]" -ForegroundColor Cyan
Write-Host "   $allAppNames" -ForegroundColor Yellow

Write-Host "`n   [SELECTION]" -ForegroundColor Cyan
Write-Host "   Paste names to update OR Press ENTER for ALL." -ForegroundColor Green
$selectionRaw = Read-Host "   > Selection"

$appsToUpdate = @()
if ($selectionRaw -eq "") {
    Write-Host "   -> Selected: ALL" -ForegroundColor Gray
    $selectedApps = $analysisList
} else {
    $selectedNames = $selectionRaw -split "," | ForEach-Object { $_.Trim() }
    $selectedApps = $analysisList | Where-Object { $selectedNames -contains $_.AppName }
}

if ($selectedApps.Count -eq 0) { Write-Host "   ❌ No apps selected."; return }

foreach ($item in $selectedApps) {
    if ($item.Status -eq "Matched") {
        $appsToUpdate += [PSCustomObject]@{ AppName = $item.AppName; SourcePath = $item.SourcePath; DestPath = $item.DetectedPath }
    } else {
        Write-Host "`n   ⚠️  Configuration needed for: $($item.AppName)" -ForegroundColor Magenta
        $manPathRaw = Read-Host "      Enter Path (Enter to SKIP)"
        $manPath = $manPathRaw.Trim('"')
        if ($manPath -ne "") {
             $appsToUpdate += [PSCustomObject]@{ AppName = $item.AppName; SourcePath = $item.SourcePath; DestPath = $manPath }
             Write-Host "      ✅ Added." -ForegroundColor Green
        }
    }
}

if ($appsToUpdate.Count -eq 0) { Write-Host "No apps configured."; return }

# --- STEP 4: DOUBLE-SMART OPTIMIZATION ---
$FolderToInstanceMap = @{}
$pattern = '"([^"=]+)=%PnxInstallPath%\\([^"]+)"'
[regex]::Matches($RawMappingData, $pattern) | ForEach-Object {
    $id = $_.Groups[1].Value
    $path = $_.Groups[2].Value
    $fName = Split-Path $path -Leaf
    if (-not $FolderToInstanceMap.ContainsKey($fName)) { $FolderToInstanceMap[$fName] = $id }
}

$RequiresIISStop = $false
$RequiresPhoenixStop = $false

foreach ($app in $appsToUpdate) {
    $fName = $app.AppName
    $isInstance = $false
    
    if ($FolderToInstanceMap.ContainsKey($fName)) {
        if ($ServiceProductList -contains $FolderToInstanceMap[$fName]) { $isInstance = $true }
    }
    elseif ($ServiceProductList -contains $fName) { $isInstance = $true }
    elseif ($ServiceProductList -contains ($fName -replace " ", "")) { $isInstance = $true }
    
    if ($isInstance) { $RequiresPhoenixStop = $true } else { $RequiresIISStop = $true }
}

# --- STEP 5: BACKUP ---
Write-Header "STEP 4: BACKUP & REVIEW"
$backupRootBase = "$workPath\Backup"
foreach ($app in $appsToUpdate) {
    Write-Host "`n📁 Scanning: $($app.AppName)" -ForegroundColor Cyan
    $sourceFiles = Get-ChildItem -Path $app.SourcePath -Recurse -File
    foreach ($sourceFile in $sourceFiles) {
        $relativePath = $sourceFile.FullName.Substring($app.SourcePath.Length).TrimStart('\')
        $destFile = Join-Path $app.DestPath $relativePath
        $backFile = Join-Path "$backupRootBase\$($app.AppName)" $relativePath
        if (Test-Path $destFile) {
            $bDir = Split-Path $backFile -Parent
            if (-not (Test-Path $bDir)) { New-Item -Path $bDir -ItemType Directory -Force | Out-Null }
            Copy-Item -Path $destFile -Destination $backFile -Force -ErrorAction SilentlyContinue
            Write-Host "   📦 Backed up: $destFile" -ForegroundColor Yellow
        }
    }
}

# --- STEP 6: APPLY ---
Write-Header "STEP 6: SERVICE STOP & APPLY"
Write-Host "   -----------------------------------------" -ForegroundColor Gray
if ($RequiresIISStop) { Write-Host "   [IIS]     Will be STOPPED (Web apps detected)" -ForegroundColor Yellow }
else { Write-Host "   [IIS]     Will REMAIN RUNNING (Only instance apps detected)" -ForegroundColor Green }

if ($RequiresPhoenixStop) { Write-Host "   [PHOENIX] Will be STOPPED (Instance apps detected)" -ForegroundColor Yellow }
else { Write-Host "   [PHOENIX] Will REMAIN RUNNING (No instance apps detected)" -ForegroundColor Green }
Write-Host "   -----------------------------------------" -ForegroundColor Gray

$response = Read-Host "   Type Y to confirm and apply"
if ($response -eq "Y" -or $response -eq "y") {
    
    # 1. STOP SERVICES
    if ($RequiresIISStop) {
        Write-Host "   Stopping IIS..." -ForegroundColor Yellow
        iisreset /stop
    }
    
    if ($RequiresPhoenixStop) {
        Write-Host "   Stopping Phoenix Services..." -ForegroundColor Yellow
        Get-Service | Where-Object { $_.DisplayName -like "*Phoenix*" -and $_.Status -eq 'Running' } | Stop-Service -Force
    }

    # 2. APPLY
    foreach ($app in $appsToUpdate) {
        Write-Host "`n📁 Applying: $($app.AppName)" -ForegroundColor Cyan
        $allSourceFiles = Get-ChildItem -Path $app.SourcePath -Recurse -File
        foreach ($file in $allSourceFiles) {
            $relPath = $file.FullName.Substring($app.SourcePath.Length).TrimStart('\')
            $destFile = Join-Path $app.DestPath $relPath
            $destDir = Split-Path $destFile -Parent
            if (-not (Test-Path $destDir)) { New-Item -Path $destDir -ItemType Directory -Force | Out-Null }
            Copy-Item -Path $file.FullName -Destination $destFile -Force
            Write-Host "   🔄 Applied: $destFile" -ForegroundColor Green
            Log-Action "APPLIED | $destFile"
        }
    }
    
    # 3. CLEAR CAD SESSIONS
    $cadApp = $appsToUpdate | Where-Object { $_.AppName -eq "CAD Server" } | Select-Object -First 1
    if ($cadApp) {
        $sessionPath = Join-Path $cadApp.DestPath "SvrSession"
        if (Test-Path $sessionPath) {
            Get-ChildItem -Path $sessionPath -Recurse | Remove-Item -Force -Recurse
            Write-Host "   ✅ Session Data Cleared." -ForegroundColor Green
        }
    }

    # 4. RESTORE SERVICES
    Write-Header "STEP 7: RESTORING SERVICES"
    if ($RequiresIISStop) {
        Write-Host "   🚀 Starting IIS..." -ForegroundColor Cyan
        iisreset /start
    }

    # 5. INSTANCE BAT
    Write-Header "STEP 8: INSTANCE MANAGER"
    $batInstances = @()
    foreach ($app in $appsToUpdate) {
        $fName = $app.AppName
        $foundID = $null
        if ($FolderToInstanceMap.ContainsKey($fName)) { $foundID = $FolderToInstanceMap[$fName] }
        elseif ($ServiceProductList -contains $fName) { $foundID = $fName }
        elseif ($ServiceProductList -contains ($fName -replace " ", "")) { $foundID = ($fName -replace " ", "") }
        
        if ($foundID -and ($ServiceProductList -contains $foundID)) { $batInstances += $foundID }
    }
    $batInstances = $batInstances | Select-Object -Unique

    if ($batInstances.Count -gt 0) {
        $appMgrPath = Find-ServerAppManager
        if ($appMgrPath) {
            $batFile = "$workPath\Run_Instance_Update.bat"
            $mgrDrive = Split-Path $appMgrPath -Qualifier
            $instanceListString = $batInstances -join '" "'
            
            $batContent = @"
$mgrDrive
cd \
cd "Program Files (x86)"
cd ProPhoenix
cd "Server Application Manager"

@echo off
SET AppMgrExePath="$appMgrPath"

echo Stopping all services...
powershell -Command "Get-Service -Name 'Phoenix*' | Where-Object { `$_.Status -eq 'Running' } | ForEach-Object { Stop-Service -Name `$_.Name -Force }"

echo All Phoenix services have been stopped.
%AppMgrExePath%\PnxAppMgr.exe "UPDATEINSTANCE" "$instanceListString"
%AppMgrExePath%\PnxAppMgr.exe "SHOWINSTANCES"
::End of Script::
"@
            Set-Content -Path $batFile -Value $batContent
            Write-Host "   ✅ BAT File Created: $batFile" -ForegroundColor Yellow
            Write-Host "      Instances: $instanceListString" -ForegroundColor Gray
            
            if ((Read-Host "   🚀 Run Instance Update Script NOW? (Y/N)") -eq "Y") {
                Start-Process -FilePath $batFile -Wait
            }
        }
    } else {
        Write-Host "   No Instance-Based apps detected." -ForegroundColor Gray
    }

} else {
    Write-Host "`n⛔ Replacement cancelled." -ForegroundColor Red
}

# --- STEP 9: VERIFY ---
Write-Header "STEP 9: VERIFICATION"
$prophoenixPaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $d = "$($_.Root)Program Files\ProPhoenix"; if (Test-Path $d) { $d }
}
if ($prophoenixPaths) {
    $excluded = @("Finger Print Client", "ID Scanner", "Phoenix WDA V2", "Police RMS", "PoliceRMS", "Print Server", "WDA")
    foreach ($base in $prophoenixPaths) {
        Write-Host "`nScanning: $base" -ForegroundColor Yellow
        $folders = Get-ChildItem $base -Directory | Where-Object { $excluded -notcontains $_.Name }
        foreach ($app in $folders) {
            $instPath = Join-Path $app.FullName "_Instances"
            if (Test-Path $instPath) {
                Get-ChildItem $instPath -Directory | ForEach-Object {
                    $fail = $false
                    $baseFiles = Get-ChildItem $app.FullName -Filter *.dll
                    $instFiles = Get-ChildItem $_.FullName -Filter *.dll
                    foreach ($b in $baseFiles) {
                        $i = $instFiles | Where-Object Name -eq $b.Name
                        if (-not $i -or $i.LastWriteTime -lt $b.LastWriteTime) { $fail = $true; break }
                    }
                    if (-not $fail) { Write-Host ("   [OK] {0} -> {1}" -f $app.Name, $_.Name) -ForegroundColor Green }
                    else { Write-Host ("   [FAIL] {0} -> {1}" -f $app.Name, $_.Name) -ForegroundColor Red }
                }
            }
        }
    }
}

# --- STEP 10: FINAL START ---
Write-Header "STEP 10: FINALIZING"
if ((Read-Host "❓ Start remaining Phoenix Services? (Y/N)") -eq "Y") {
    Write-Host "   Starting Services..." -ForegroundColor Yellow
    Get-Service | Where-Object { $_.DisplayName -like "*Phoenix*" -and $_.Status -ne 'Running' } | Start-Service
}

Write-Host "`n✅ Done. Log: $global:logFile" -ForegroundColor Green
Pause