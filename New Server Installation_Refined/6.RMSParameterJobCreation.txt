#Requires -RunAsAdministrator

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  ProPhoenix Enterprise Setup, DB & Jobs Configurator" -ForegroundColor Cyan
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

$foldersToCreate = @(
    "Custom", "Attachment", "Attachment\Job", "Watch", "WatchTr", "ScreenDocs", "Attachment\BulkUpload",
    "WDA App webservice", "Phoenix Report Writer API", "Fire WebService", "Fire Response CAD Webservice",
    "Police RMS\Log"
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

$sharesToManage = @{
    "prophoenix" = "" 
    "Custom" = "Custom"
    "Job" = "Attachment\Job"
    "Hotsheet" = "Police RMS\Records\Hotsheet"
    "ScreenDocs" = "ScreenDocs"
    "Attachment" = "Attachment"
    "BulkUpload" = "Attachment\BulkUpload"
    "ftp" = "FTP"
    "Watch" = "Watch"
    "WDA App webservice" = "WDA App webservice"
    "Phoenix Report Writer API" = "Phoenix Report Writer API"
    "Fire WebService" = "Fire WebService"
    "Fire Response CAD Webservice" = "Fire Response CAD Webservice"
    "Bolo" = "CAD Server\_Instances\Live\Bolo" 
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
# 5. Database Configuration Prompts
# ==========================================
Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "  Database & Job Configuration" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

$hostHeader = Read-Host "Enter Hostheader (e.g., rms.yourcity.gov)"
$sqlServer = Read-Host "Enter SQL Server Instance (e.g., localhost or SERVER\SQLEXPRESS)"
$saUser = Read-Host "Enter SQL SA Username"
$saPassword = Read-Host -AsSecureString "Enter SQL SA Password"
$saPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($saPassword))

$selectedCadInstance = "CAD test"
if ($cadInstances.Count -gt 0) {
    Write-Host "`nSelect CAD Instance Type for Jobs:" -ForegroundColor Yellow
    for ($i=0; $i -lt $cadInstances.Count; $i++) { Write-Host "$($i + 1). $($cadInstances[$i])" }
    $cadChoice = Read-Host "Enter choice"
    $selectedCadInstance = $cadInstances[[int]$cadChoice - 1]
} else {
    $selectedCadInstance = Read-Host "`nEnter CAD Instance Type (e.g., Live or CAD test)"
}
Write-Host "CAD Instance set to: $selectedCadInstance" -ForegroundColor Green

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
    222  = "\\$hostName\Watch"
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

$dbConnString = "Server=$sqlServer;Database=$selectedDb;User Id=$saUser;Password=$saPasswordPlain;TrustServerCertificate=True;"
$dbConnection = New-Object System.Data.SqlClient.SqlConnection($dbConnString)

try {
    $dbConnection.Open()
    
    # ==========================================
    # 6. FK-Aware Parameter UPSERT Execution
    # ==========================================
    Write-Host "`nExecuting System Parameters in Database [$selectedDb]..." -ForegroundColor Cyan
    $totalUpdated = 0; $totalInserted = 0; $totalSkipped = 0

    foreach ($paramID in $paramValues.Keys) {
        $safeValue = $paramValues[$paramID].Replace("'", "''")
        
        $upsertQuery = @"
        SET NOCOUNT ON;
        DECLARE @tID INT = $paramID;
        DECLARE @tVal NVARCHAR(MAX) = '$safeValue';

        IF EXISTS (SELECT 1 FROM Parameter WHERE CAST(ParamID AS VARCHAR(50)) = CAST(@tID AS VARCHAR(50)))
        BEGIN
            UPDATE Parameter SET ParamValue = @tVal WHERE CAST(ParamID AS VARCHAR(50)) = CAST(@tID AS VARCHAR(50));
            SELECT 'Updated' AS Action;
        END
        ELSE
        BEGIN
            -- FK Integrity Check: Only insert if the ParamID exists in the ParameterName dictionary
            IF OBJECT_ID('dbo.ParameterName', 'U') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ParameterName WHERE CAST(ParamID AS VARCHAR(50)) = CAST(@tID AS VARCHAR(50)))
            BEGIN
                SELECT 'Skipped_FK' AS Action;
            END
            ELSE
            BEGIN
                DECLARE @nextSLNo BIGINT;
                SELECT @nextSLNo = ISNULL(MAX(CAST(SLNo AS BIGINT)), 0) + 1 FROM Parameter WITH (UPDLOCK, HOLDLOCK);

                DECLARE @sysJurisID INT;
                SELECT TOP 1 @sysJurisID = JurisID FROM Parameter WHERE JurisID IS NOT NULL;
                SET @sysJurisID = ISNULL(@sysJurisID, 0);

                INSERT INTO Parameter (SLNo, ParamID, ParamValue, JurisID) VALUES (@nextSLNo, @tID, @tVal, @sysJurisID);
                SELECT 'Inserted' AS Action;
            END
        END
"@
        $command = $dbConnection.CreateCommand()
        $command.CommandText = $upsertQuery
        try {
            $actionResult = $command.ExecuteScalar()
            if ($actionResult -eq 'Updated') { 
                Write-Host " [Updated]  ParamID $paramID -> $safeValue" -ForegroundColor Green; $totalUpdated++ 
            } 
            elseif ($actionResult -eq 'Inserted') { 
                Write-Host " [Inserted] ParamID $paramID -> $safeValue" -ForegroundColor Yellow; $totalInserted++ 
            }
            elseif ($actionResult -eq 'Skipped_FK') {
                Write-Host " [Skipped]  ParamID $paramID -> Base definition missing in Product (Skipped to prevent FK Error)" -ForegroundColor DarkGray; $totalSkipped++
            }
        } catch { Write-Host " [Error] Failed on ParamID $($paramID): $_" -ForegroundColor Red }
    }
    Write-Host "`nParameter Summary: $totalUpdated updated, $totalInserted inserted, $totalSkipped gracefully skipped." -ForegroundColor Cyan

    # ==========================================
    # 7. Execute KPI Jobs Configuration
    # ==========================================
    Write-Host "`nConfiguring KPI Background Jobs..." -ForegroundColor Cyan
    
    # Added optional $jobType parameter to modify JobType column dynamically
    function Setup-KPIJob($jobName, $jobInstance, $folder1, $folder2, $jobType) {
        $jobScript = "UPDATE KPIjobs SET IsInactive = 1 WHERE JobName = '$jobName';`n"
        $jobScript += "UPDATE KPIjobs SET StartDttm = GETDATE(), EndDttm = '2099-12-31', NextExDttm = GETDATE() WHERE JobName = '$jobName';`n"
        
        # If a specific job type is passed (like 'System'), update the DB
        if ($jobType) {
            $jobScript += "UPDATE KPIjobs SET JobType = '$jobType' WHERE JobName = '$jobName';`n"
        }

        if ($jobInstance) {
            $jobScript += "INSERT INTO KPIjobsparam(JobID, SeqNo, ParamName, ParamValue) SELECT JobID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIjobsparam WHERE JobID = j.JobID), 'Instance', '$jobInstance' FROM KPIJobs j WHERE JobName = '$jobName';`n"
        }
        if ($folder1) {
            $jobScript += "INSERT INTO KPIJobsNotify SELECT JobID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIJobsNotify WHERE JobID = j.JobID), NULL, NULL, '$folder1', 1, NULL, NULL, NULL, NULL FROM KPIJobs j WHERE JobName = '$jobName';`n"
        }
        if ($folder2) {
            $jobScript += "INSERT INTO KPIJobsNotify SELECT JobID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIJobsNotify WHERE JobID = j.JobID), NULL, NULL, '$folder2', 1, NULL, NULL, NULL, NULL FROM KPIJobs j WHERE JobName = '$jobName';`n"
        }

        $cmd = $dbConnection.CreateCommand()
        $cmd.CommandText = $jobScript
        try {
            $cmd.ExecuteNonQuery() | Out-Null
            Write-Host " [Configured Job] $jobName" -ForegroundColor Green
        } catch {
            Write-Host " [Error] Failed to configure Job: $jobName`n$_" -ForegroundColor Red
        }
    }

    if ($productChoice -eq "1" -or $productChoice -eq "") {
        # POLICE JOBS (WDAAppDataExporter is updated with JobType = 'System')
        Setup-KPIJob -jobName "WDAAppDataExporter" -jobInstance $selectedCadInstance -folder1 "\\$hostName\Fire Response CAD Webservice" -jobType "System"
        Setup-KPIJob -jobName "ReportWriterStaticDataExporter" -jobInstance $selectedCadInstance -folder1 "\\$hostName\Phoenix Report Writer API"
        Setup-KPIJob -jobName "CADStaticDataExtractor" -jobInstance $null -folder1 "\\$hostName\ftp\CAD Data\KPI Data" -folder2 "\\$hostName\ftp\WDA Data\KPI Data"
        Setup-KPIJob -jobName "Hot Sheet" -jobInstance $null -folder1 "\\$hostName\Bolo" -folder2 "\\$hostName\Hotsheet"
        Setup-KPIJob -jobName "FireLiveDataExporter" -jobInstance $selectedCadInstance -folder1 "\\$hostName\Fire Response CAD Webservice"
        Setup-KPIJob -jobName "PhoenixBOTQAUploader" -jobInstance $null -folder1 "\\$hostName\Job"
        Setup-KPIJob -jobName "KPICleaner" -jobInstance $null -folder1 "\\$hostName\prophoenix\Police RMS\Log"
    } 
    elseif ($productChoice -eq "2") {
        # FIRE JOBS (WDAAppDataExporter is updated with JobType = 'System')
        Setup-KPIJob -jobName "FireLiveDataExporter" -jobInstance $selectedCadInstance -folder1 "\\$hostName\Fire Response CAD Webservice"
        Setup-KPIJob -jobName "FireRMSDataExporter" -jobInstance $null -folder1 "\\$hostName\Fire WebService"
        Setup-KPIJob -jobName "WDAAppDataExporter" -jobInstance $selectedCadInstance -folder1 "\\$hostName\Fire Response CAD Webservice" -jobType "System"
    }

} catch {
    Write-Host "Error executing database scripts: $_" -ForegroundColor Red
} finally {
    if ($dbConnection.State -eq 'Open') { $dbConnection.Close() }
}

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host " Enterprise Setup Completed Successfully." -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Cyan