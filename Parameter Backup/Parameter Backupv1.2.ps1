# =============================================================================
#  RMS MASTER SCRIPT: AUTO-DETECT + COPY-PASTE LIST + TABLE CHECKS
# =============================================================================

# --- 1. CONNECTION SETUP ---
$ServerName   = Read-Host "Enter SQL Server Name"
Write-Host "Tip: If 'sa' fails, try using 'PnxMgmt'" -ForegroundColor DarkGray
$SqlUser      = Read-Host "Enter SQL User"
$SqlPassword  = Read-Host "Enter Password" -AsSecureString

# Convert Password
$PassPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPassword)
$PlainPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($PassPtr)

# Setup Output Directory
$MasterBackupDir = "C:\RMS_Master_Backups"
$Timestamp = Get-Date -Format "yyyyMMdd_HHmm"

# --- 2. AUTO-DETECT & GENERATE LIST ---
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "               PHASE 1: DATABASE SCANNING" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

Write-Host "Scanning server '$ServerName'..." -ForegroundColor Yellow

try {
    $MasterConn = "Server=$ServerName;Database=master;User ID=$SqlUser;Password=$PlainPass;TrustServerCertificate=True;Connect Timeout=10"
    
    # Find potential RMS databases
    $QueryDBs = "SELECT name FROM sys.databases WHERE (name LIKE '%Police%' OR name LIKE '%Fire%' OR name LIKE '%IA%') AND name NOT IN ('master', 'tempdb', 'model', 'msdb') ORDER BY name"
    $FoundDBs = Invoke-Sqlcmd -ConnectionString $MasterConn -Query $QueryDBs -ErrorAction Stop
    $AllFound = $FoundDBs | Select-Object -ExpandProperty name

    if ($AllFound.Count -eq 0) { Write-Host "No databases found!" -ForegroundColor Red; exit }

    # --- GENERATE COMMA SEPARATED LIST ---
    $CommaList = $AllFound -join ", "

    Write-Host "`n[DETECTED DATABASES]" -ForegroundColor Green
    $AllFound | ForEach-Object { Write-Host " - $_" -ForegroundColor DarkGray }

    Write-Host "`n----------------------------------------------------------------" -ForegroundColor Gray
    Write-Host "COPY THIS LIST FOR SELECTION:" -ForegroundColor Yellow
    Write-Host $CommaList -ForegroundColor Cyan
    Write-Host "----------------------------------------------------------------" -ForegroundColor Gray

    # --- SELECTION STEP ---
    Write-Host "Paste the list above (or delete the ones you don't want):" -ForegroundColor Yellow
    $Selection = Read-Host "Your Selection"

    if ($Selection -eq "") { 
        $TargetList = $AllFound 
    } else {
        $TargetList = $Selection -split "," | ForEach-Object { $_.Trim() }
    }

} catch {
    Write-Host "FATAL ERROR: Connection failed." -ForegroundColor Red; [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PassPtr); exit
}

# --- 3. EXECUTE BACKUP ---
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "               PHASE 2: EXECUTING BACKUP" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$RMSJobs = "'CAD Static Data Extractor', 'Fire Live Data Exporter', 'Hot Sheet', 'KPICleaner', 'Phoenix BOT QA Uploader', 'ReportWriterStaticDataExporter', 'WDA App Data Exporter'"
$GlobalParamIDs = "13, 16, 22, 29, 36, 39, 40, 190, 203, 204, 205, 206, 207, 220, 221, 231, 630, 1914, 2658, 5712, 5714"

foreach ($DB in $TargetList) {
    if ($DB -eq "") { continue }

    # Smart Category
    $Category = "Other"
    if ($DB -match "Police") { $Category = "Police" }
    elseif ($DB -match "Fire") { $Category = "Fire" }
    elseif ($DB -match "IA") { $Category = "InternalAffairs" }

    $TargetDir = Join-Path $MasterBackupDir $Category
    if (!(Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir | Out-Null }

    Write-Host "`nProcessing: $DB ($Category)..." -ForegroundColor Yellow
    $ConnStr = "Server=$ServerName;Database=$DB;User ID=$SqlUser;Password=$PlainPass;TrustServerCertificate=True;Connect Timeout=15"

    try {
        # --- CHECK 1: DOES KPIJobs EXIST? ---
        $CheckJob = Invoke-Sqlcmd -ConnectionString $ConnStr -Query "SELECT COUNT(*) AS C FROM information_schema.tables WHERE table_name = 'KPIJobs'" -ErrorAction Stop
        
        if ($CheckJob.C -gt 0) {
            $JobFile = Join-Path $TargetDir "$($DB)_KPIJobs_$Timestamp.txt"
            $JobRows = Invoke-Sqlcmd -ConnectionString $ConnStr -Query "SELECT * FROM dbo.KPIJobs WITH (NOLOCK) WHERE JobName IN ($RMSJobs)" -ErrorAction Stop
            
            if ($JobRows.Count -gt 0) {
                $JobRows | Export-Csv -Path $JobFile -NoTypeInformation -Delimiter "`t"
                Write-Host "   + Jobs Saved" -ForegroundColor Green
                
                $JobIds = ($JobRows | Select-Object -ExpandProperty JobID) -join ","
                if ($JobIds) {
                    Invoke-Sqlcmd -ConnectionString $ConnStr -Query "SELECT * FROM dbo.KPIJobsParam WITH (NOLOCK) WHERE JobID IN ($JobIds)" | Export-Csv -Path "$TargetDir\$($DB)_KPIJobsParam_$Timestamp.txt" -NoTypeInformation -Delimiter "`t"
                    Invoke-Sqlcmd -ConnectionString $ConnStr -Query "SELECT * FROM dbo.KPIJobsNotify WITH (NOLOCK) WHERE JobID IN ($JobIds)" | Export-Csv -Path "$TargetDir\$($DB)_KPIJobsNotify_$Timestamp.txt" -NoTypeInformation -Delimiter "`t"
                }
            } else { Write-Host "   - No specific RMS Jobs found." -ForegroundColor DarkGray }
        } else {
            Write-Host "   - Skipped Jobs (Table 'KPIJobs' not found)" -ForegroundColor DarkGray
        }

        # --- CHECK 2: DOES ParameterName EXIST? ---
        $CheckParam = Invoke-Sqlcmd -ConnectionString $ConnStr -Query "SELECT COUNT(*) AS C FROM information_schema.tables WHERE table_name = 'ParameterName'" -ErrorAction Stop
        
        if ($CheckParam.C -gt 0) {
            $GlobalFile = Join-Path $TargetDir "$($DB)_GlobalParameters.txt"
            $GlobalRows = Invoke-Sqlcmd -ConnectionString $ConnStr -Query "SELECT ParamID, DefaultValue FROM dbo.ParameterName WITH (NOLOCK) WHERE ParamID IN ($GlobalParamIDs) ORDER BY ParamID" -ErrorAction Stop
            
            $OutputList = @()
            foreach ($Row in $GlobalRows) {
                $Val = if ($Row.DefaultValue -ne $null) { $Row.DefaultValue } else { "" }
                $OutputList += "{0} = {1}" -f $Row.ParamID, $Val
            }
            $OutputList | Out-File -FilePath $GlobalFile -Encoding UTF8
            Write-Host "   + Parameters Saved" -ForegroundColor Green
        } else {
            Write-Host "   - Skipped Parameters (Table 'ParameterName' not found)" -ForegroundColor DarkGray
        }
    }
    catch {
        Write-Host "   ! ERROR: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- 4. RESTORE PHASE ---
Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "               PHASE 3: RESTORE (Optional)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$DoRestore = Read-Host "Do you want to restore parameters? (Y/N)"
if ($DoRestore -ne "Y") { 
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PassPtr)
    Write-Host "Done. Opening Folder..." -ForegroundColor Green
    explorer $MasterBackupDir
    exit 
}

Add-Type -AssemblyName System.Windows.Forms
$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog
$FileBrowser.InitialDirectory = $MasterBackupDir
$FileBrowser.Filter = "Text Files (*.txt)|*.txt"
$FileBrowser.Title = "Select Parameter File to Restore"
if ($FileBrowser.ShowDialog() -ne "OK") { exit }
$SourceFile = $FileBrowser.FileName

# Show the Copy-Paste list again for convenience
Write-Host "`n----------------------------------------------------------------" -ForegroundColor Gray
Write-Host "COPY THIS LIST FOR RESTORE TARGETS:" -ForegroundColor Yellow
Write-Host $CommaList -ForegroundColor Cyan
Write-Host "----------------------------------------------------------------" -ForegroundColor Gray

$RestoreInput = Read-Host "Paste TARGET Databases here"
$RestoreArray = $RestoreInput -split "," | ForEach-Object { $_.Trim() }

foreach ($TargetDB in $RestoreArray) {
    if ($TargetDB -eq "") { continue }
    Write-Host "`nRestoring to: $TargetDB ..." -ForegroundColor Yellow
    $TargetConn = "Server=$ServerName;Database=$TargetDB;User ID=$SqlUser;Password=$PlainPass;TrustServerCertificate=True;Connect Timeout=15"
    
    try {
        $Check = Invoke-Sqlcmd -ConnectionString $TargetConn -Query "SELECT COUNT(*) AS C FROM information_schema.tables WHERE table_name = 'ParameterName'" -ErrorAction Stop
        if ($Check.C -eq 0) { Write-Host "   SKIPPING: Table missing in $TargetDB" -ForegroundColor Red; continue }

        $Content = Get-Content -Path $SourceFile
        $Count = 0
        foreach ($Line in $Content) {
            if ($Line.Trim().StartsWith("#") -or $Line.Trim() -eq "") { continue }
            $Parts = $Line -split "=", 2
            if ($Parts.Count -eq 2) {
                $ParamID = $Parts[0].Trim(); $Val = $Parts[1].Trim().Replace("'", "''")
                try {
                    Invoke-Sqlcmd -ConnectionString $TargetConn -Query "UPDATE dbo.ParameterName SET DefaultValue = '$Val' WHERE ParamID = $ParamID" -ErrorAction Stop
                    $Count++
                } catch {}
            }
        }
        Write-Host "   SUCCESS: Updated $Count parameters" -ForegroundColor Green
    }
    catch { Write-Host "   FAILED: $($_.Exception.Message)" -ForegroundColor Red }
}

[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($PassPtr)
explorer $MasterBackupDir