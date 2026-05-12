# ======================================================================
#  ProPhoenix Auto Database Sync Utility - v1.5 - Installation Team 
# ======================================================================

Clear-Host
Write-Host "===== ProPhoenix Auto Database Sync Utility (v5.0) =====" -ForegroundColor Cyan

# ----------------------------------------------------------------------
# CONFIGURATION & PATHS
# ----------------------------------------------------------------------
$setupPath = "C:\pnxtemp\dbsynctool"
$setupFile = Join-Path $setupPath "DBDetails.txt"
$xmlTarget = Join-Path $setupPath "PnxAutoNewDBSyn.xml"

# Ensure Temp Directory Exists
if (!(Test-Path $setupPath)) {
    New-Item -ItemType Directory -Force -Path $setupPath | Out-Null
    Write-Host "✓ Created directory: $setupPath" -ForegroundColor Green
}

# ----------------------------------------------------------------------
# STEP 1: GENERATE XML FILE (Embedded Content)
# ----------------------------------------------------------------------
# This creates the XML file from scratch using the format you provided.
$xmlContent = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
	<SourceServer>
		<IPAddress>CHPNX947\MSSQLSERVER01</IPAddress> 
		<DBName>DBName</DBName> <UserName>sa</UserName> 
		<Password>pnx</Password> 
		<JurisID>1000</JurisID> <State>MA</State> <JurisName>ProPhoenix</JurisName> <JurisAlias>PNX</JurisAlias> <SyncType>2</SyncType> </SourceServer>
</PnxPakager>
"@

if (!(Test-Path $xmlTarget)) {
    Set-Content -Path $xmlTarget -Value $xmlContent -Force
    Write-Host "✓ Generated default PnxAutoNewDBSyn.xml in temp folder." -ForegroundColor Green
} else {
    Write-Host "✓ XML Template already exists in temp folder." -ForegroundColor Gray
}

# ----------------------------------------------------------------------
# STEP 2: HELPER TO FETCH DBS (Excluding System DBs)
# ----------------------------------------------------------------------
function Get-PhoenixDBs {
    param($Server, $User, $Password)

    try {
        $connString = "Server=$Server;User Id=$User;Password=$Password;Database=master;Connection Timeout=10;"
        $conn = New-Object System.Data.SqlClient.SqlConnection
        $conn.ConnectionString = $connString
        $conn.Open()

        $cmd = $conn.CreateCommand()
        # EXCLUDE 'master', 'model', 'msdb', 'tempdb' to prevent system sync errors
        $cmd.CommandText = "SELECT Name FROM sys.databases WHERE (Name LIKE '%Police%' OR Name LIKE '%Fire%' OR Name LIKE '%IA%' OR Name LIKE '%Master%') AND Name NOT IN ('master', 'model', 'msdb', 'tempdb') ORDER BY Name"
        
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataset) | Out-Null
        $conn.Close()

        $dbList = $dataset.Tables[0].Rows | Select-Object -ExpandProperty Name
        return $dbList
    }
    catch {
        Write-Host "❌ SQL Connection Failed: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# ----------------------------------------------------------------------
# STEP 3: INTERACTIVE SETUP & DBDetails.txt CREATION
# ----------------------------------------------------------------------
$runSetup = $true
if (Test-Path $setupFile) {
    Write-Host "✓ Configuration file found: $setupFile" -ForegroundColor Green
    $response = Read-Host "⚠ Do you want to use existing details? (Y = Use Existing / N = Reset & Fetch New)"
    if ($response -match "^[Yy]") { $runSetup = $false }
}

if ($runSetup) {
    Write-Host "`n--- ENTER SQL CONNECTION DETAILS ---" -ForegroundColor Cyan
    
    $in_IP   = Read-Host "Enter SQL Instance/IP (e.g., 192.168.1.10)"
    $in_User = Read-Host "Enter SQL Username      (e.g., sa)"
    $in_Pass = Read-Host "Enter SQL Password"
    
    Write-Host "`nAttempting to fetch databases from SQL Server..." -ForegroundColor DarkYellow
    $fetchedDBs = Get-PhoenixDBs -Server $in_IP -User $in_User -Password $in_Pass

    # Double-check safety filter (remove 'master' if it slipped in)
    $fetchedDBs = $fetchedDBs | Where-Object { $_ -ne "master" }

    if ($fetchedDBs) {
        Write-Host "✓ Successfully found databases:" -ForegroundColor Green
        $fetchedDBs | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
        $formattedDBs = ";" + ($fetchedDBs -join ";") + ";"
    }
    else {
        Write-Host "⚠ Could not fetch databases automatically." -ForegroundColor Red
        $manual = Read-Host "Please manually enter DB names (comma separated)"
        $formattedDBs = ";" + ($manual -replace ",", ";" -replace "\s", "") + ";"
    }

    $fileContent = @"
IPAddress=$in_IP
DBName=$formattedDBs
UserName=$in_User
Password=$in_Pass
SyncType=2
"@
    Set-Content -Path $setupFile -Value $fileContent -Force
    Write-Host "✓ DBDetails.txt created successfully." -ForegroundColor Green
}

# ----------------------------------------------------------------------
# STEP 4: READ CONFIGURATION
# ----------------------------------------------------------------------
$rawContent = Get-Content $setupFile | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#|^\s*//' }
$params = $rawContent | ForEach-Object {
    $kv = $_ -split "="
    if ($kv.Length -eq 2) { [PSCustomObject]@{ Key = $kv[0].Trim(); Value = $kv[1].Trim() } }
}

$IPAddress  = ($params | Where-Object { $_.Key -eq "IPAddress" }).Value
$DBNamesRaw = ($params | Where-Object { $_.Key -eq "DBName" }).Value
$DBNames    = $DBNamesRaw -split ";" | Where-Object { $_ -ne "" } | ForEach-Object { $_.Trim() }
$UserName   = ($params | Where-Object { $_.Key -eq "UserName" }).Value
$Password   = ($params | Where-Object { $_.Key -eq "Password" }).Value
$SyncType   = ($params | Where-Object { $_.Key -eq "SyncType" }).Value

if (-not $SyncType) { $SyncType = 2 }

if (-not $IPAddress -or -not $DBNames -or -not $UserName -or -not $Password) {
    Write-Host "❌ ERROR: Missing required fields in DBDetails.txt." -ForegroundColor Red
    exit
}

# ----------------------------------------------------------------------
# STEP 5: AUTO-DETECT DB SYNC INSTALLATION PATH
# ----------------------------------------------------------------------
$DBSyncRoot = $null
foreach ($drive in (Get-PSDrive -PSProvider FileSystem).Root) {
    $candidate = Join-Path $drive "Program Files\ProPhoenix\Database Utility\DB Sync"
    if (Test-Path $candidate) {
        $DBSyncRoot = $candidate
        break
    }
}

if (-not $DBSyncRoot) {
    Write-Host "❌ ERROR: Cannot locate DB Sync folder on ANY drive." -ForegroundColor Red
    exit
}
Write-Host "✓ DB Sync root detected: $DBSyncRoot" -ForegroundColor Green

# ----------------------------------------------------------------------
# STEP 6: FIXED MODULE FOLDERS
# ----------------------------------------------------------------------
$folders = @{
    Police        = Join-Path $DBSyncRoot "Police"
    Fire          = Join-Path $DBSyncRoot "Fire"
    IA            = Join-Path $DBSyncRoot "IA"
    PhoenixMaster = Join-Path $DBSyncRoot "Phoenix Master"
    PoliceDW      = Join-Path $DBSyncRoot "Police DW"
}

# ----------------------------------------------------------------------
# HELPER: WATCH FOR NEW LOG FILE
# ----------------------------------------------------------------------
function Get-NewLogFile {
    param($Folder, $StartTime, [int]$TimeoutSeconds = 120)
    $stopTime = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $stopTime) {
        $log = Get-ChildItem $Folder -Filter "DBToolLog*.txt" -ErrorAction SilentlyContinue |
               Where-Object { $_.LastWriteTime -gt $StartTime } |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 1
        if ($log) { return $log.FullName }
        Start-Sleep -Seconds 5
    }
    return $null
}

# ----------------------------------------------------------------------
# MAIN EXECUTION FUNCTION
# ----------------------------------------------------------------------
function Run-DBSync {
    param($DB, $TargetFolder)

    Write-Host "`nProcessing DB: $DB" -ForegroundColor Yellow

    # Load XML template FROM TEMP FOLDER
    [xml]$xmlData = Get-Content $xmlTarget

    # UPDATE XML with specific DB details
    $xmlData.PnxPakager.SourceServer.IPAddress = $IPAddress
    $xmlData.PnxPakager.SourceServer.DBName    = $DB
    $xmlData.PnxPakager.SourceServer.UserName  = $UserName
    $xmlData.PnxPakager.SourceServer.Password  = $Password
    $xmlData.PnxPakager.SourceServer.SyncType  = $SyncType

    # Save to the specific module folder (Target)
    $xmlOut = Join-Path $TargetFolder "PnxAutoNewDBSyn.xml"
    $xmlData.Save($xmlOut)

    Write-Host "✓ XML updated in module: $xmlOut" -ForegroundColor Green

    $exe = Join-Path $TargetFolder "PnxDBSync.exe"
    if (!(Test-Path $exe)) {
        Write-Host "❌ ERROR: Missing $exe" -ForegroundColor Red
        return $false
    }

    Write-Host "▶ Starting DB Sync..." -ForegroundColor Cyan
    $start = Get-Date
    Start-Process -FilePath $exe -Wait -PassThru | Out-Null

    $logPath = Get-NewLogFile -Folder $TargetFolder -StartTime $start
    if (-not $logPath) { 
        Write-Host "❌ TIMEOUT: No log file generated." -ForegroundColor Red
        return $false 
    }

    $content = Get-Content $logPath -Raw
    $success1 = "ExecuteForUpdatePS() : DB Version Updated."
    $success2 = "ExecuteForUpdatePS() : Deleting PnxAutoNewDBSyn.xml file."
    $success3 = "ExecuteForUpdatePS() : PnxAutoNewDBSyn.xml file deleted."

    if (($content -match [regex]::Escape($success1)) -and 
        ($content -match [regex]::Escape($success2)) -and 
        ($content -match [regex]::Escape($success3))) {
        Write-Host "✔ SYNC SUCCESS for $DB" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "❌ SYNC FAILED for $DB" -ForegroundColor Red
        Write-Host "Log: $logPath" -ForegroundColor DarkRed
        return $false
    }
}

# ----------------------------------------------------------------------
# LOOP THROUGH DATABASES
# ----------------------------------------------------------------------
foreach ($db in $DBNames) {
    $db = $db.Trim()
    if ([string]::IsNullOrEmpty($db)) { continue }
    
    # SAFETY: Ensure we never try to sync the system 'master'
    if ($db -eq "master") { continue }

    if ($db -match "(Police$|TrPolice$|CNVPolice$|TestPolice$)")    { $key = "Police" }
    elseif ($db -match "(Fire$|TrFire$|TestFire$|CNVFire$)")        { $key = "Fire" }
    elseif ($db -match "(IA$|TrIA$|TestIA$)")                        { $key = "IA" }
    elseif ($db -match "Master$")                                   { $key = "PhoenixMaster" }
    elseif ($db -match "DW$")                                       { $key = "PoliceDW" }
    else {
        Write-Host "❌ Unknown DB type: $db - SKIPPED" -ForegroundColor Red
        continue
    }

    $target = $folders[$key]
    if (!(Test-Path $target)) {
        Write-Host "❌ Missing module folder: $target" -ForegroundColor Red
        continue
    }

    $result = Run-DBSync -DB $db -TargetFolder $target

    if (-not $result) {
        $ans = Read-Host "⚠ Sync failed for $db. Continue next? (Y/N)"
        if ($ans -notmatch "^[Yy]$") { break }
    }
}

Write-Host "`n🎉 All operations completed." -ForegroundColor Cyan