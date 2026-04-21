#Requires -RunAsAdministrator

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  ProPhoenix Environment Setup & DB Parameter Updater" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

$hostName = $env:COMPUTERNAME
$folderSummary = @()
$shareSummary = @()

# ==========================================
# 1. Fetch the Base Path Automatically
# ==========================================
$baseFolder = "Program Files\ProPhoenix"
$basePath = ""

foreach ($drive in (Get-PSDrive -PSProvider FileSystem)) {
    $testPath = Join-Path -Path $drive.Root -ChildPath $baseFolder
    if (Test-Path $testPath) {
        $basePath = $testPath
        break
    }
}

if ([string]::IsNullOrEmpty($basePath)) {
    $basePath = "$($env:SystemDrive)\$baseFolder"
    Write-Host "ProPhoenix base path not found. Defaulting to: $basePath" -ForegroundColor Yellow
} else {
    Write-Host "Found Base Path: $basePath" -ForegroundColor Green
}

# ==========================================
# 2. Fetch Instance Folders & Process Directories
# ==========================================
$cadInstances = @()
$pnxInstances = @()

$cadInstancePath = Join-Path $basePath "CAD Server\_Instances"
if (Test-Path $cadInstancePath) { $cadInstances = (Get-ChildItem -Path $cadInstancePath -Directory).Name }

$pnxInstancePath = Join-Path $basePath "PnxFolderWatcher\_Instance"
if (Test-Path $pnxInstancePath) { $pnxInstances = (Get-ChildItem -Path $pnxInstancePath -Directory).Name }

# Build the dynamic list of required folders
$foldersToCreate = @(
    "Custom", "Attachment", "Attachment\Job", "Watch", "WatchTr", "ScreenDocs", "Attachment\BulkUpload"
)

if (Test-Path (Join-Path $basePath "Police RMS\Records")) { $foldersToCreate += "Police RMS\Records\Hotsheet" }
if (Test-Path (Join-Path $basePath "FTP")) { 
    $foldersToCreate += "FTP\CAD Data\KPI Data"
    $foldersToCreate += "FTP\WDA Data\KPI Data"
}

foreach ($cadInst in $cadInstances) { $foldersToCreate += "CAD Server\_Instances\$cadInst\Bolo" }
foreach ($pnxInst in $pnxInstances) {
    $foldersToCreate += "PnxFolderWatcher\_Instance\$pnxInst\Rpt"
    $foldersToCreate += "PnxFolderWatcher\_Instance\$pnxInst\Rpt\GettxtFile"
    $foldersToCreate += "PnxFolderWatcher\_Instance\$pnxInst\Rpt\ProcessedRpt"
    $foldersToCreate += "PnxFolderWatcher\_Instance\$pnxInst\Rpt\ErrorRpt"
}

Write-Host "`nScanning and Validating Directories..." -ForegroundColor Cyan
foreach ($folder in $foldersToCreate) {
    $fullPath = Join-Path $basePath $folder
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        $folderSummary += [PSCustomObject]@{ Status = "Created"; Path = $fullPath }
    } else {
        $folderSummary += [PSCustomObject]@{ Status = "Existing (Used)"; Path = $fullPath }
    }
}

# ==========================================
# 3. Create/Verify Shared Folders
# ==========================================
Write-Host "`nScanning and Validating Network Shares..." -ForegroundColor Cyan

# Define exact share names and their relative paths
$sharesToManage = @{
    "prophoenix" = "" 
    "Custom" = "Custom"
    "Job" = "Attachment\Job"
    "Hotsheet" = "Police RMS\Records\Hotsheet"
    "ScreenDocs" = "ScreenDocs"
    "Attachment" = "Attachment"
    "BulkUpload" = "Attachment\BulkUpload"
    "ftp" = "FTP"
}

foreach ($shareName in $sharesToManage.Keys) {
    $targetFolderPath = Join-Path $basePath $sharesToManage[$shareName]
    
    if (Test-Path $targetFolderPath) {
        $existingShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
        $uncPath = "\\$hostName\$shareName"

        if (-not $existingShare) {
            New-SmbShare -Name $shareName -Path $targetFolderPath -FullAccess "Everyone" | Out-Null
            $shareSummary += [PSCustomObject]@{ Status = "Created"; ShareName = $shareName; UNC = $uncPath }
        } else {
            $shareSummary += [PSCustomObject]@{ Status = "Existing (Used)"; ShareName = $shareName; UNC = $uncPath }
        }
    }
}

# Apply base NTFS Permissions
try {
    $acl = Get-Acl $basePath
    $inheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagationFlag = [System.Security.AccessControl.PropagationFlags]::None
    $accountsToAdd = @("NETWORK SERVICE", "IUSR")
    
    foreach ($account in $accountsToAdd) {
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($account, "FullControl", $inheritanceFlag, $propagationFlag, "Allow")
        $acl.AddAccessRule($accessRule)
    }
    Set-Acl -Path $basePath -AclObject $acl
} catch {
    Write-Host " [Warning] Failed to apply NTFS permissions: $_" -ForegroundColor Yellow
}

# ==========================================
# 4. Summary Output
# ==========================================
Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "  Setup Summary Report" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

Write-Host "`n--- Folder Status ---" -ForegroundColor Yellow
$folderSummary | Format-Table -AutoSize

Write-Host "--- Share Status ---" -ForegroundColor Yellow
$shareSummary | Format-Table -AutoSize

# ==========================================
# 5. Database Configuration & Updates
# ==========================================
Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "  Database Configuration & Parameter Update" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

$hostHeader = Read-Host "Enter Hostheader (e.g., rms.yourcity.gov)"
$sqlServer = Read-Host "Enter SQL Server Instance (e.g., localhost or SERVER\SQLEXPRESS)"
$saUser = Read-Host "Enter SQL SA Username"
$saPassword = Read-Host -AsSecureString "Enter SQL SA Password"
$saPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($saPassword))

Write-Host "`nSelect the Product to update:" -ForegroundColor Yellow
Write-Host "1. Police"
Write-Host "2. Fire"
Write-Host "3. IA"
$productChoice = Read-Host "Enter choice (1-3)"

$productSuffix = switch ($productChoice) {
    "1" { "law" }
    "2" { "fire" }
    "3" { "ia" }
    Default { "law" }
}

$masterConnString = "Server=$sqlServer;Database=master;User Id=$saUser;Password=$saPasswordPlain;TrustServerCertificate=True;"
$connection = New-Object System.Data.SqlClient.SqlConnection($masterConnString)

try {
    $connection.Open()
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = "SELECT name FROM sys.databases WHERE database_id > 4 ORDER BY name"
    $reader = $cmd.ExecuteReader()
    
    $databases = @()
    while ($reader.Read()) { $databases += $reader["name"] }
    $reader.Close(); $connection.Close()

    Write-Host "`nAvailable Databases:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $databases.Count; $i++) { Write-Host "$($i + 1). $($databases[$i])" }
    
    $dbSelection = Read-Host "Enter the number of the Database to update"
    $selectedDb = $databases[[int]$dbSelection - 1]
    Write-Host "Selected Database: $selectedDb" -ForegroundColor Green

} catch {
    Write-Host "Error connecting to SQL Server: $_" -ForegroundColor Red
    exit
}

$configureSMTP = Read-Host "Do you want to configure SMTP parameters (203-207, 221)? (Y/N)"

# Build dynamic parameter values using the verified shares
$paramValues = @{
    13   = "\\$hostName\Custom"
    16   = "https://$hostHeader/$productSuffix"
    22   = "\\$hostName\ScreenDocs"
    29   = "\\$hostName\Attachment"
    36   = "https://$hostHeader/PnxRptSvr/frmPnxRpt.aspx"
    39   = "\\$hostName\BulkUpload"
    40   = "http://$hostName/ReportServer"
    190  = "https://crmws.prophoenix.com/PNXAIAPI"
    220  = "https://$hostHeader/Webservice/Notify/Notification.asmx"
    231  = "1"
    630  = "https://$hostHeader/WebService/NIST/PhoenixNIST.asmx"
    1914 = "https://$hostHeader/KGIS/KGISCADService.asmx"
    2658 = "https://$hostHeader/WDAV2API"
}

if ($configureSMTP -match "^[Yy]$") {
    $paramValues[203] = Read-Host "Enter SMTP Mail Server (Param 203)"
    $paramValues[204] = Read-Host "Enter SMTP Server User (Param 204)"
    $paramValues[205] = Read-Host "Enter SMTP Server Password (Param 205)"
    $paramValues[206] = Read-Host "Enter From Mail ID (Param 206)"
    $paramValues[207] = Read-Host "Enter Support Mail ID (Param 207)"
    $paramValues[221] = Read-Host "Enter Notification 'From' E-mail Address (Param 221)"
}

Write-Host "`nUpdating Parameters in Database [$selectedDb]..." -ForegroundColor Cyan

$dbConnString = "Server=$sqlServer;Database=$selectedDb;User Id=$saUser;Password=$saPasswordPlain;TrustServerCertificate=True;"
$dbConnection = New-Object System.Data.SqlClient.SqlConnection($dbConnString)

try {
    $dbConnection.Open()
    
    foreach ($paramID in $paramValues.Keys) {
        $paramValue = $paramValues[$paramID]
        
        $updateCmd = $dbConnection.CreateCommand()
        $updateCmd.CommandText = "UPDATE Parameter SET ParamValue = @val WHERE ParamID = @id"
        $updateCmd.Parameters.AddWithValue("@val", $paramValue) | Out-Null
        $updateCmd.Parameters.AddWithValue("@id", $paramID) | Out-Null
        
        $rowsAffected = $updateCmd.ExecuteNonQuery()
        if ($rowsAffected -gt 0) {
            Write-Host " [Updated] ParamID $paramID -> $paramValue"
        } else {
            Write-Host " [Skipped] ParamID $paramID not found in database." -ForegroundColor DarkGray
        }
    }
    Write-Host "`nAll parameter updates processed successfully!" -ForegroundColor Green

} catch {
    Write-Host "Error updating database: $_" -ForegroundColor Red
} finally {
    if ($dbConnection.State -eq 'Open') { $dbConnection.Close() }
}

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " Script Execution Completed." -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Cyan