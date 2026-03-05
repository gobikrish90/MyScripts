# --- 1. Connection Setup ---
$ServerName   = Read-Host "Enter SQL Server Name"
$SqlUser      = Read-Host "Enter SQL User (e.g., sa)"
$SqlPassword  = Read-Host "Enter Password" -AsSecureString

# Convert Password for connection strings
$PassPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPassword)
$PlainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($PassPtr)

# --- 2. Database List ---
# You can add or remove databases from this default list
$DefaultDBs = "PhoenixPolice, PhoenixFire, PhoenixIA, PhoenixPoliceTrain, PhoenixFireTrain, PhoenixIATrain"

Write-Host "`nDefault Database List: $DefaultDBs" -ForegroundColor Gray
$InputDBs = Read-Host "Enter Database list (Leave blank to use default)"
if ($InputDBs -eq "") { $TargetDBs = $DefaultDBs } else { $TargetDBs = $InputDBs }

# Clean up list
$DatabaseArray = $TargetDBs -split "," | ForEach-Object { $_.Trim() }

# --- 3. CONFIGURATION ---
$BackupDir = "C:\RMS_Master_Backups"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmm"

# A. The RMS Job List (From your screenshots)
$RMSJobs = "'CAD Static Data Extractor', 'Fire Live Data Exporter', 'Hot Sheet', 'KPICleaner', 'Phoenix BOT QA Uploader', 'ReportWriterStaticDataExporter', 'WDA App Data Exporter'"

# B. The Global Parameter IDs (From your text file)
$GlobalParamIDs = "13, 16, 22, 29, 36, 39, 40, 190, 203, 204, 205, 206, 207, 220, 221, 231, 630, 1914, 2658, 5712, 5714"

# Create Output Directory
if (!(Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir }

Write-Host "`nStarting Master Backup..." -ForegroundColor Cyan

# --- 4. EXECUTION LOOP ---
foreach ($DB in $DatabaseArray) {
    Write-Host "`n------------------------------------------------" -ForegroundColor Gray
    Write-Host "PROCESSING DATABASE: $DB" -ForegroundColor Yellow
    Write-Host "------------------------------------------------" -ForegroundColor Gray
    
    $ConnStr = "Server=$ServerName;Database=$DB;User ID=$SqlUser;Password=$PlainPass;TrustServerCertificate=True;Connect Timeout=15"

    try {
        # =========================================================
        # PART 1: RMS JOBS & LINKED DATA
        # =========================================================
        Write-Host "   > Backing up RMS Jobs..." -NoNewline
        
        # 1.1 Export KPIJobs
        $JobFile = Join-Path $BackupDir "$($DB)_KPIJobs_$Timestamp.txt"
        $QueryJobs = "SELECT * FROM dbo.KPIJobs WITH (NOLOCK) WHERE JobName IN ($RMSJobs)"
        
        $JobRows = Invoke-Sqlcmd -ConnectionString $ConnStr -Query $QueryJobs -ErrorAction Stop
        
        if ($JobRows.Count -gt 0) {
            $JobRows | Export-Csv -Path $JobFile -NoTypeInformation -Delimiter "`t"
            Write-Host " [DONE]" -ForegroundColor Green

            # 1.2 Get IDs to find linked Parameters and Notifications
            $JobIds = $JobRows | Select-Object -ExpandProperty JobID
            $IdList = $JobIds -join ","

            if ($IdList) {
                # Export KPIJobsParam
                $FileParam = Join-Path $BackupDir "$($DB)_KPIJobsParam_$Timestamp.txt"
                $QueryParam = "SELECT * FROM dbo.KPIJobsParam WITH (NOLOCK) WHERE JobID IN ($IdList)"
                Invoke-Sqlcmd -ConnectionString $ConnStr -Query $QueryParam -ErrorAction Stop | Export-Csv -Path $FileParam -NoTypeInformation -Delimiter "`t"
                
                # Export KPIJobsNotify (Emails)
                $FileNotify = Join-Path $BackupDir "$($DB)_KPIJobsNotify_$Timestamp.txt"
                $QueryNotify = "SELECT * FROM dbo.KPIJobsNotify WITH (NOLOCK) WHERE JobID IN ($IdList)"
                Invoke-Sqlcmd -ConnectionString $ConnStr -Query $QueryNotify -ErrorAction Stop | Export-Csv -Path $FileNotify -NoTypeInformation -Delimiter "`t"
            }
        }
        else {
            Write-Host " [SKIPPED - No RMS Jobs Found]" -ForegroundColor DarkGray
        }

        # =========================================================
        # PART 2: GLOBAL PARAMETERS (dbo.ParameterName)
        # =========================================================
        Write-Host "   > Backing up Global Parameters..." -NoNewline
        
        $GlobalFile = Join-Path $BackupDir "$($DB)_GlobalParameters.txt"
        
        # Query specific IDs
        $QueryGlobal = "SELECT ParamID, DefaultValue FROM dbo.ParameterName WITH (NOLOCK) WHERE ParamID IN ($GlobalParamIDs) ORDER BY ParamID"
        $GlobalRows = Invoke-Sqlcmd -ConnectionString $ConnStr -Query $QueryGlobal -ErrorAction Stop
        
        # Custom Format (ID = Value)
        $OutputList = @()
        $OutputList += "# Global Parameters for Database: $DB"
        $OutputList += "----------------------------------------"
        
        foreach ($Row in $GlobalRows) {
            $Val = if ($Row.DefaultValue -ne $null) { $Row.DefaultValue } else { "" }
            $OutputList += "{0} = {1}" -f $Row.ParamID, $Val
        }
        
        $OutputList | Out-File -FilePath $GlobalFile -Encoding UTF8
        Write-Host " [DONE]" -ForegroundColor Green

    }
    catch {
        Write-Host "`n   ! ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PassPtr)
Write-Host "`nAll tasks complete. Opening output folder..." -ForegroundColor Yellow
explorer $BackupDir