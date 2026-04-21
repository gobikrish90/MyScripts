#Requires -RunAsAdministrator

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  ProPhoenix Enterprise Backup & Restore Utility" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

# Define the targets to back up
$targetParams = @(13, 16, 22, 29, 36, 39, 40, 190, 203, 204, 205, 206, 207, 220, 221, 222, 231, 630, 1914, 2658)
$targetJobs = @("WDAAppDataExporter", "ReportWriterStaticDataExporter", "CADStaticDataExtractor", "Hot Sheet", "FireLiveDataExporter", "PhoenixBOTQAUploader", "KPICleaner", "FireRMSDataExporter")

# ==========================================
# 1. Select Operation Mode
# ==========================================
Write-Host "`nSelect Operation:" -ForegroundColor Yellow
Write-Host "1. Backup Current Configuration (Export to JSON)"
Write-Host "2. Restore Configuration (Import from JSON)"
$operationChoice = Read-Host "Enter choice (1-2)"

# ==========================================
# 2. Database Configuration Prompts
# ==========================================
Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "  Database Connection" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

$sqlServer = Read-Host "Enter SQL Server Instance (e.g., localhost or SERVER\SQLEXPRESS)"
$saUser = Read-Host "Enter SQL SA Username"
$saPassword = Read-Host -AsSecureString "Enter SQL SA Password"
$saPasswordPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($saPassword))

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
    
    $dbSelection = Read-Host "Enter the number of the Database to connect to"
    $selectedDb = $databases[[int]$dbSelection - 1]
    Write-Host "Selected Database: $selectedDb" -ForegroundColor Green

} catch {
    Write-Host "Error connecting to SQL Server: $_" -ForegroundColor Red
    exit
}

$dbConnString = "Server=$sqlServer;Database=$selectedDb;User Id=$saUser;Password=$saPasswordPlain;TrustServerCertificate=True;"
$dbConnection = New-Object System.Data.SqlClient.SqlConnection($dbConnString)

# ==========================================
# 3. BACKUP LOGIC
# ==========================================
if ($operationChoice -eq "1") {
    Write-Host "`nInitiating Backup for [$selectedDb]..." -ForegroundColor Cyan
    
    $backupData = @{
        Database = $selectedDb
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Parameters = @()
        Jobs = @()
    }

    try {
        $dbConnection.Open()

        # --- Backup Parameters ---
        $paramList = $targetParams -join ","
        $cmd = $dbConnection.CreateCommand()
        $cmd.CommandText = "SELECT ParamID, CAST(ParamValue AS NVARCHAR(MAX)) AS ParamValue FROM Parameter WHERE CAST(ParamID AS VARCHAR(50)) IN ($paramList)"
        $reader = $cmd.ExecuteReader()
        while ($reader.Read()) {
            $val = if ($reader.IsDBNull(1)) { $null } else { $reader.GetString(1) }
            $backupData.Parameters += @{ ParamID = $reader.GetValue(0); ParamValue = $val }
        }
        $reader.Close()
        Write-Host " [Success] Backed up $($backupData.Parameters.Count) System Parameters." -ForegroundColor Green

        # --- Backup Jobs ---
        $jobList = "'" + ($targetJobs -join "','") + "'"
        $cmd.CommandText = "SELECT JobID, JobName, JobType FROM KPIjobs WHERE JobName IN ($jobList)"
        $jobReader = $cmd.ExecuteReader()
        
        $tempJobs = @()
        while ($jobReader.Read()) {
            $jType = if ($jobReader.IsDBNull(2)) { $null } else { $jobReader.GetString(2) }
            $tempJobs += @{ JobID = $jobReader.GetValue(0); JobName = $jobReader.GetString(1); JobType = $jType; Params = @(); Notifies = @() }
        }
        $jobReader.Close()

        foreach ($job in $tempJobs) {
            # Fetch Job Params
            $cmd.CommandText = "SELECT ParamName, ParamValue FROM KPIjobsparam WHERE JobID = $($job.JobID)"
            $pReader = $cmd.ExecuteReader()
            while ($pReader.Read()) {
                $job.Params += @{ ParamName = $pReader.GetString(0); ParamValue = $pReader.GetString(1) }
            }
            $pReader.Close()

            # FIXED: Read Job Notifies using ordinal positions instead of explicit column names
            $cmd.CommandText = "SELECT * FROM KPIJobsNotify WHERE JobID = $($job.JobID)"
            $nReader = $cmd.ExecuteReader()
            while ($nReader.Read()) {
                # In ProPhoenix, the 5th column (Index 4) holds the Folder Path string
                $pathVal = if ($nReader.IsDBNull(4)) { $null } else { $nReader.GetString(4) }
                if (![string]::IsNullOrWhiteSpace($pathVal)) {
                    $job.Notifies += $pathVal
                }
            }
            $nReader.Close()

            # Remove JobID before saving to JSON
            $job.Remove("JobID")
            $backupData.Jobs += $job
        }
        Write-Host " [Success] Backed up $($backupData.Jobs.Count) KPI Jobs." -ForegroundColor Green

        # --- Save JSON ---
        $backupPath = Join-Path $env:USERPROFILE "Desktop\ProPhoenix_Backup_$($selectedDb)_$((Get-Date).ToString('yyyyMMdd_HHmmss')).json"
        $backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupPath -Encoding UTF8
        Write-Host "`nBackup successfully saved to: $backupPath" -ForegroundColor Cyan

    } catch {
        Write-Host "Error during backup: $_" -ForegroundColor Red
    } finally {
        if ($dbConnection.State -eq 'Open') { $dbConnection.Close() }
    }
}

# ==========================================
# 4. RESTORE LOGIC
# ==========================================
elseif ($operationChoice -eq "2") {
    $backupFilePath = Read-Host "`nEnter the full path to the Backup JSON file (e.g., C:\Users\Admin\Desktop\Backup.json)"
    
    if (-not (Test-Path $backupFilePath)) {
        Write-Host "❌ File not found! Exiting." -ForegroundColor Red
        exit
    }

    $backupData = Get-Content $backupFilePath -Raw | ConvertFrom-Json
    Write-Host "`nRestoring Configuration from Backup (Dated: $($backupData.Timestamp)) into [$selectedDb]..." -ForegroundColor Cyan

    try {
        $dbConnection.Open()

        # --- Restore Parameters (With FK Check) ---
        Write-Host "`nRestoring Parameters..." -ForegroundColor Yellow
        $totalParamUpdated = 0; $totalParamInserted = 0; $totalParamSkipped = 0

        foreach ($param in $backupData.Parameters) {
            $pID = $param.ParamID
            $pVal = $param.ParamValue.Replace("'", "''")

            $upsertQuery = @"
            SET NOCOUNT ON;
            DECLARE @tID INT = $pID;
            DECLARE @tVal NVARCHAR(MAX) = '$pVal';

            IF EXISTS (SELECT 1 FROM Parameter WHERE CAST(ParamID AS VARCHAR(50)) = CAST(@tID AS VARCHAR(50)))
            BEGIN
                UPDATE Parameter SET ParamValue = @tVal WHERE CAST(ParamID AS VARCHAR(50)) = CAST(@tID AS VARCHAR(50));
                SELECT 'Updated' AS Action;
            END
            ELSE
            BEGIN
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
            $cmd = $dbConnection.CreateCommand()
            $cmd.CommandText = $upsertQuery
            try {
                $res = $cmd.ExecuteScalar()
                if ($res -eq 'Updated') { Write-Host " [Restored] ParamID $pID" -ForegroundColor Green; $totalParamUpdated++ }
                elseif ($res -eq 'Inserted') { Write-Host " [Restored (New)] ParamID $pID" -ForegroundColor Yellow; $totalParamInserted++ }
                elseif ($res -eq 'Skipped_FK') { Write-Host " [Skipped] ParamID $pID (Not applicable to this product DB)" -ForegroundColor DarkGray; $totalParamSkipped++ }
            } catch { Write-Host " [Error] ParamID $($pID): $_" -ForegroundColor Red }
        }
        Write-Host "Parameter Restore Summary: $totalParamUpdated Updated, $totalParamInserted Inserted, $totalParamSkipped Skipped." -ForegroundColor Cyan

        # --- Restore Jobs ---
        Write-Host "`nRestoring KPI Jobs..." -ForegroundColor Yellow
        foreach ($job in $backupData.Jobs) {
            $jName = $job.JobName
            $jType = if ($job.JobType) { "'$($job.JobType)'" } else { "JobType" }

            $jobQuery = @"
            DECLARE @jID BIGINT;
            SELECT TOP 1 @jID = JobID FROM KPIjobs WHERE JobName = '$jName';
            
            IF @jID IS NOT NULL
            BEGIN
                -- Activate job and set dates
                UPDATE KPIjobs SET IsInactive = 1, StartDttm = GETDATE(), EndDttm = '2099-12-31', NextExDttm = GETDATE(), JobType = $jType WHERE JobID = @jID;
                
                -- Clear old params and notifies to prevent duplicates
                DELETE FROM KPIjobsparam WHERE JobID = @jID;
                DELETE FROM KPIJobsNotify WHERE JobID = @jID;
                
                SELECT @jID AS FoundJobID;
            END
"@
            $cmd.CommandText = $jobQuery
            $returnedJobID = $cmd.ExecuteScalar()

            if ($returnedJobID) {
                # Insert Job Params
                if ($job.Params) {
                    foreach ($jp in $job.Params) {
                        $pName = $jp.ParamName; $pVal = $jp.ParamValue
                        $cmd.CommandText = "INSERT INTO KPIjobsparam(JobID, SeqNo, ParamName, ParamValue) SELECT @jID, ISNULL(MAX(SeqNo),0)+1, '$pName', '$pVal' FROM KPIjobsparam WHERE JobID = $returnedJobID"
                        $cmd.ExecuteNonQuery() | Out-Null
                    }
                }
                
                # FIXED: Insert Job Notifies (Folders) using Legacy Ordinal Position logic
                if ($job.Notifies) {
                    foreach ($folder in $job.Notifies) {
                        $fSafe = $folder.Replace("'", "''")
                        $cmd.CommandText = "INSERT INTO KPIJobsNotify SELECT JobID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIJobsNotify WHERE JobID = j.JobID), NULL, NULL, '$fSafe', 1, NULL, NULL, NULL, NULL FROM KPIJobs j WHERE JobID = $returnedJobID"
                        $cmd.ExecuteNonQuery() | Out-Null
                    }
                }
                Write-Host " [Restored] KPI Job: $jName" -ForegroundColor Green
            } else {
                Write-Host " [Skipped] KPI Job: $jName (Job definition does not exist in this database)" -ForegroundColor DarkGray
            }
        }
        
    } catch {
        Write-Host "Error during restore: $_" -ForegroundColor Red
    } finally {
        if ($dbConnection.State -eq 'Open') { $dbConnection.Close() }
    }
} else {
    Write-Host "Invalid selection. Exiting." -ForegroundColor Red
}

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host " Script Execution Completed." -ForegroundColor Green
Write-Host "=======================================================" -ForegroundColor Cyan