# ======================================================================
#  ProPhoenix Auto Database Sync Utility - WITH INTERACTIVE SETUP
# ======================================================================

Clear-Host
Write-Host "===== ProPhoenix Auto Database Sync Utility (v2.0) =====" -ForegroundColor Cyan

# ----------------------------------------------------------------------
# STEP 1: INTERACTIVE SETUP & FILE CREATION
# ----------------------------------------------------------------------
$setupPath = "C:\pnxtemp\dbsynctool"
$setupFile = Join-Path $setupPath "DBDetails.txt"

Write-Host "`n[Checking Environment Configuration]" -ForegroundColor Yellow

# 1. Create Directory if missing
if (!(Test-Path $setupPath)) {
    New-Item -ItemType Directory -Force -Path $setupPath | Out-Null
    Write-Host "✓ Created directory: $setupPath" -ForegroundColor Green
} else {
    Write-Host "✓ Directory exists: $setupPath" -ForegroundColor Gray
}

# 2. Check for DBDetails.txt - Prompt if missing or user wants to update
$runSetup = $true
if (Test-Path $setupFile) {
    Write-Host "✓ Configuration file found: $setupFile" -ForegroundColor Green
    $response = Read-Host "⚠ Do you want to use existing details? (Y = Use Existing / N = Enter New Details)"
    if ($response -match "^[Yy]") { $runSetup = $false }
}

if ($runSetup) {
    Write-Host "`n--- ENTER DATABASE DETAILS ---" -ForegroundColor Cyan
    
    $in_IP   = Read-Host "Enter SQL Instance/IP (e.g., 192.168.1.10)"
    $in_User = Read-Host "Enter SQL Username      (e.g., sa)"
    $in_Pass = Read-Host "Enter SQL Password"
    
    Write-Host "`nList Databases separated by commas (e.g., Police, Fire, IA, PoliceDW)"
    $in_DBs  = Read-Host "Enter Database Names"

    # Format DB list to match required format: ;Name;Name;
    $formattedDBs = $in_DBs -replace ",", ";" -replace "\s", "" 
    if (-not $formattedDBs.StartsWith(";")) { $formattedDBs = ";" + $formattedDBs }
    if (-not $formattedDBs.EndsWith(";"))   { $formattedDBs = $formattedDBs + ";" }

    # Construct File Content
    $fileContent = @"
IPAddress=$in_IP
DBName=$formattedDBs
UserName=$in_User
Password=$in_Pass
SyncType=2
"@

    # Write File
    Set-Content -Path $setupFile -Value $fileContent -Force
    Write-Host "`n✓ DBDetails.txt created successfully at: $setupFile" -ForegroundColor Green
    Write-Host "  Content Preview: DBName=$formattedDBs" -ForegroundColor Gray
}

# ----------------------------------------------------------------------
# Identify EXACT script location (Updated to point to new location)
# ----------------------------------------------------------------------
# We now force the script to look in the pnxtemp folder for the config
$ScriptFolder = $setupPath
$txtPath      = $setupFile

# We still need to find the XML template. 
# Assumption: The XML template is in the SAME folder where you ran the script script, 
# OR we can copy it to the temp folder if needed. 
# For safety, let's look in the current executing directory for the XML.
if ($MyInvocation.MyCommand.Path) {
    $ExecFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $ExecFolder = (Get-Location).Path
}

$xmlTemplate = Join-Path $ExecFolder "PnxAutoNewDBSyn.xml"

# If XML is not in the execution folder, check the temp folder
if (!(Test-Path $xmlTemplate)) {
    $xmlTemplate = Join-Path $ScriptFolder "PnxAutoNewDBSyn.xml"
}

if (!(Test-Path $xmlTemplate)) {
    Write-Host "❌ ERROR: Missing PnxAutoNewDBSyn.xml in $ExecFolder OR $ScriptFolder" -ForegroundColor Red
    Write-Host "Please ensure the XML template is available."
    exit
}

Write-Host "✓ XML Template found: $xmlTemplate" -ForegroundColor Green

# ----------------------------------------------------------------------
# READ TXT FILE (Robust parsing)
# ----------------------------------------------------------------------
$rawContent = Get-Content $txtPath | Where-Object { $_ -match '\S' -and $_ -notmatch '^\s*#|^\s*//' }

$params = $rawContent | ForEach-Object {
    $kv = $_ -split "="
    if ($kv.Length -eq 2) {
        [PSCustomObject]@{
            Key   = $kv[0].Trim()
            Value = $kv[1].Trim()
        }
    }
}

$IPAddress  = ($params | Where-Object { $_.Key -eq "IPAddress" }).Value
$DBNamesRaw = ($params | Where-Object { $_.Key -eq "DBName" }).Value
# Clean up delimiters to get array
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
# AUTO-DETECT DB SYNC INSTALLATION PATH
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
# FIXED MODULE FOLDERS
# ----------------------------------------------------------------------
$folders = @{
    Police        = Join-Path $DBSyncRoot "Police"
    Fire          = Join-Path $DBSyncRoot "Fire"
    IA            = Join-Path $DBSyncRoot "IA"
    PhoenixMaster = Join-Path $DBSyncRoot "Phoenix Master"
    PoliceDW      = Join-Path $DBSyncRoot "Police DW"
}


# ----------------------------------------------------------------------
# WATCH FOR NEW LOG FILE
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

        $remaining = (($stopTime - (Get-Date)).TotalSeconds).ToString('N0')
        Write-Host "⏳ Waiting for DBToolLog in: $Folder (Timeout: $remaining s)" -ForegroundColor DarkYellow
        Start-Sleep -Seconds 5
    }

    Write-Host "❌ TIMEOUT: No new log file generated." -ForegroundColor Red
    return $null
}


# ----------------------------------------------------------------------
# FINAL STRICT SUCCESS/FAIL FUNCTION
# ----------------------------------------------------------------------
function Run-DBSync {
    param($DB, $TargetFolder)

    Write-Host "`nProcessing DB: $DB" -ForegroundColor Yellow

    # Load XML template
    [xml]$xmlData = Get-Content $xmlTemplate

    $xmlData.PnxPakager.SourceServer.IPAddress = $IPAddress
    $xmlData.PnxPakager.SourceServer.DBName    = $DB
    $xmlData.PnxPakager.SourceServer.UserName  = $UserName
    $xmlData.PnxPakager.SourceServer.Password  = $Password
    $xmlData.PnxPakager.SourceServer.SyncType  = $SyncType

    $xmlOut = Join-Path $TargetFolder "PnxAutoNewDBSyn.xml"
    $xmlData.Save($xmlOut)

    Write-Host "✓ XML updated: $xmlOut" -ForegroundColor Green

    $exe = Join-Path $TargetFolder "PnxDBSync.exe"
    if (!(Test-Path $exe)) {
        Write-Host "❌ ERROR: Missing $exe" -ForegroundColor Red
        return $false
    }

    Write-Host "▶ Starting DB Sync ($exe)..." -ForegroundColor Cyan
    $start = Get-Date
    Start-Process -FilePath $exe -Wait -PassThru | Out-Null

    $logPath = Get-NewLogFile -Folder $TargetFolder -StartTime $start
    if (-not $logPath) { return $false }

    $content = Get-Content $logPath -Raw


    # =====================================================
    # STRICT SUCCESS CHECK — ALL 3 SUCCESS LINES REQUIRED
    # =====================================================
    $success1 = "ExecuteForUpdatePS() : DB Version Updated."
    $success2 = "ExecuteForUpdatePS() : Deleting PnxAutoNewDBSyn.xml file."
    $success3 = "ExecuteForUpdatePS() : PnxAutoNewDBSyn.xml file deleted."

    $pass1 = ($content -match [regex]::Escape($success1))
    $pass2 = ($content -match [regex]::Escape($success2))
    $pass3 = ($content -match [regex]::Escape($success3))

    if ($pass1 -and $pass2 -and $pass3) {
        Write-Host "✔ SYNC SUCCESS for $DB" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "❌ SYNC FAILED for $DB (Missing final success markers)" -ForegroundColor Red
        Write-Host "Log: $logPath" -ForegroundColor DarkRed
        
        if (-not $pass1) { Write-Host "❌ Missing: $success1" -ForegroundColor Red }
        if (-not $pass2) { Write-Host "❌ Missing: $success2" -ForegroundColor Red }
        if (-not $pass3) { Write-Host "❌ Missing: $success3" -ForegroundColor Red }

        return $false
    }
}


# ----------------------------------------------------------------------
# MAIN LOOP — RUN SYNC FOR EACH DB
# ----------------------------------------------------------------------
foreach ($db in $DBNames) {

    $db = $db.Trim()
    if ([string]::IsNullOrEmpty($db)) { continue }

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

Write-Host "`n🎉 All DB Sync operations completed (or stopped after failure)." -ForegroundColor Cyan