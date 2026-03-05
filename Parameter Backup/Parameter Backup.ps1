# =============================================================================
#  RMS MASTER SCRIPT: BACKUP & SMART RESTORE
# =============================================================================

# --- 1. CONNECTION SETUP ---
$ServerName   = Read-Host "Enter SQL Server Name"
Write-Host "Tip: If 'sa' fails, try using 'PnxMgmt'" -ForegroundColor DarkGray
$SqlUser      = Read-Host "Enter SQL User (e.g., sa or PnxMgmt)"
$SqlPassword  = Read-Host "Enter Password" -AsSecureString

# Convert Password
$PassPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPassword)
$PlainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($PassPtr)

# --- 2. PRE-FLIGHT CONNECTION TEST ---
Write-Host "`nTesting Connection..." -NoNewline
try {
    $TestConn = "Server=$ServerName;Database=master;User ID=$SqlUser;Password=$PlainPass;TrustServerCertificate=True;Connect Timeout=5"
    $TestResult = Invoke-Sqlcmd -ConnectionString $TestConn -Query "SELECT @@VERSION" -ErrorAction Stop
    Write-Host " [OK] Connected successfully as '$SqlUser'" -ForegroundColor Green
}
catch {
    Write-Host " [FAILED]" -ForegroundColor Red
    Write-Host "ERROR: Login failed. Please check your Username or Password." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Gray
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PassPtr)
    exit 
}

# Setup Output Directory
$BackupDir = "C:\RMS_Master_Backups"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmm"
if (!(Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir }

# --- 3. BACKUP PHASE ---
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "               PHASE 1: BACKUP PROCESS" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Define Backup Targets
$DefaultDBs = "PhoenixPolice, PhoenixFire, PhoenixIA"
Write-Host "Default Backup List: $DefaultDBs" -ForegroundColor Gray
$InputDBs = Read-Host "Enter Databases to BACKUP (Leave blank for default)"
if ($InputDBs -eq "") { $BackupDBs = $DefaultDBs } else { $BackupDBs = $InputDBs }

$BackupArray = $BackupDBs -split "," | ForEach-Object { $_.Trim() }

# Configurations
$RMSJobs = "'CAD Static Data Extractor', 'Fire Live Data Exporter', 'Hot Sheet', 'KPICleaner', 'Phoenix BOT QA Uploader', 'ReportWriterStaticDataExporter', 'WDA App Data Exporter'"
$GlobalParamIDs = "13, 16, 22, 29, 36, 39, 40, 190, 203, 204, 205, 206, 207, 220, 221, 231, 630, 1914, 2658, 5712, 5714"

foreach ($DB in $BackupArray) {
    if ($DB -eq "") { continue }
    Write-Host "`nBacking up: $DB ..." -ForegroundColor Yellow
    $ConnStr = "Server=$ServerName;Database=$DB;User ID=$SqlUser;Password=$PlainPass;TrustServerCertificate=True;Connect Timeout=15"

    try {
        # A. RMS Jobs
        $JobFile = Join-Path $BackupDir "$($DB)_KPIJobs_$Timestamp.txt"
        $JobRows = Invoke-Sqlcmd -ConnectionString $ConnStr -Query "SELECT * FROM dbo.KPIJobs WITH (NOLOCK) WHERE JobName IN ($RMSJobs)" -ErrorAction Stop
        
        if ($JobRows.Count -gt 0) {
            $JobRows | Export-Csv -Path $JobFile -NoTypeInformation -Delimiter "`t"
            Write-Host "   + Jobs Exported" -ForegroundColor Green
            
            $JobIds = ($JobRows | Select-Object -ExpandProperty JobID) -join ","
            if ($JobIds) {
                Invoke-Sqlcmd -ConnectionString $ConnStr -Query "SELECT * FROM dbo.KPIJobsParam WITH (NOLOCK) WHERE JobID IN ($JobIds)" | Export-Csv -Path "$BackupDir\$($DB)_KPIJobsParam_$Timestamp.txt" -NoTypeInformation -Delimiter "`t"
                Invoke-Sqlcmd -ConnectionString $ConnStr -Query "SELECT * FROM dbo.KPIJobsNotify WITH (NOLOCK) WHERE JobID IN ($JobIds)" | Export-Csv -Path "$BackupDir\$($DB)_KPIJobsNotify_$Timestamp.txt" -NoTypeInformation -Delimiter "`t"
                Write-Host "   + Linked Params & Notifications Exported" -ForegroundColor Green
            }
        }

        # B. Global Parameters
        $GlobalFile = Join-Path $BackupDir "$($DB)_GlobalParameters.txt"
        $GlobalRows = Invoke-Sqlcmd -ConnectionString $ConnStr -Query "SELECT ParamID, DefaultValue FROM dbo.ParameterName WITH (NOLOCK) WHERE ParamID IN ($GlobalParamIDs) ORDER BY ParamID" -ErrorAction Stop
        
        $OutputList = @()
        foreach ($Row in $GlobalRows) {
            $Val = if ($Row.DefaultValue -ne $null) { $Row.DefaultValue } else { "" }
            $OutputList += "{0} = {1}" -f $Row.ParamID, $Val
        }
        $OutputList | Out-File -FilePath $GlobalFile -Encoding UTF8
        Write-Host "   + Global Parameters Exported" -ForegroundColor Green
    }
    catch {
        Write-Host "   ! BACKUP FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- 4. RESTORE PHASE ---
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "               PHASE 2: RESTORE PROCESS" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$DoRestore = Read-Host "Do you want to restore/update parameters in other databases? (Y/N)"
if ($DoRestore -ne "Y") { 
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PassPtr)
    Write-Host "Exiting script." -ForegroundColor Green
    exit 
}

# List Databases
Write-Host "`n--- Available Databases on $ServerName ---" -ForegroundColor Gray
try {
    $SysConn = "Server=$ServerName;Database=master;User ID=$SqlUser;Password=$PlainPass;TrustServerCertificate=True"
    $AllDBs = Invoke-Sqlcmd -ConnectionString $SysConn -Query "SELECT name FROM sys.databases WHERE name NOT IN ('master','tempdb','model','msdb') ORDER BY name"
    $AllDBs | ForEach-Object { Write-Host " - $($_.name)" -ForegroundColor DarkGray }
} catch { Write-Host "Could not list databases." -ForegroundColor Red }

# Select Source & Target
Write-Host "`n------------------------------------------------" -ForegroundColor Gray
$SourceDBName = Read-Host "Which Database Backup should be the SOURCE? (e.g. PhoenixPolice)"
$SourceFile   = Join-Path $BackupDir "$($SourceDBName)_GlobalParameters.txt"

if (!(Test-Path $SourceFile)) {
    Write-Host "ERROR: Could not find backup file: $SourceFile" -ForegroundColor Red
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PassPtr)
    exit
}

$RestoreInput = Read-Host "Enter TARGET Databases for Restore (comma separated)"
$RestoreArray = $RestoreInput -split "," | ForEach-Object { $_.Trim() }

foreach ($TargetDB in $RestoreArray) {
    if ($TargetDB -eq "") { continue }
    Write-Host "`nConnecting to: $TargetDB ..." -ForegroundColor Yellow
    $TargetConn = "Server=$ServerName;Database=$TargetDB;User ID=$SqlUser;Password=$PlainPass;TrustServerCertificate=True;Connect Timeout=15"
    
    try {
        # --- NEW: Check if Table Exists First ---
        $TableCheck = Invoke-Sqlcmd -ConnectionString $TargetConn -Query "SELECT COUNT(*) AS Cnt FROM information_schema.tables WHERE table_schema = 'dbo' AND table_name = 'ParameterName'" -ErrorAction Stop
        
        if ($TableCheck.Cnt -eq 0) {
            Write-Host "   SKIPPING: Table 'dbo.ParameterName' NOT FOUND in $TargetDB." -ForegroundColor Red
            continue
        }

        # If table exists, proceed with updates
        $Content = Get-Content -Path $SourceFile
        $Count = 0

        foreach ($Line in $Content) {
            if ($Line.Trim().StartsWith("#") -or $Line.Trim() -eq "" -or $Line.Contains("----")) { continue }

            $Parts = $Line -split "=", 2
            if ($Parts.Count -eq 2) {
                $ParamID   = $Parts[0].Trim()
                $Value     = $Parts[1].Trim()
                $SafeValue = $Value -replace "'", "''"

                try {
                    $UpdateQ = "UPDATE dbo.ParameterName SET DefaultValue = '$SafeValue' WHERE ParamID = $ParamID"
                    Invoke-Sqlcmd -ConnectionString $TargetConn -Query $UpdateQ -ErrorAction Stop
                    $Count++
                }
                catch {
                    Write-Host "   Failed to update ID $($ParamID): $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        Write-Host "   SUCCESS: Updated $Count parameters in $TargetDB" -ForegroundColor Green
    }
    catch {
        Write-Host "   CONNECTION FAILED: $($_.Exception.Message)" -ForegroundColor Red
    }
}

[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PassPtr)
Write-Host "`nAll operations complete. Opening Backup Folder..." -ForegroundColor Yellow
explorer $BackupDir