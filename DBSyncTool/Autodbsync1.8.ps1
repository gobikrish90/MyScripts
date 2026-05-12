# ======================================================================
#  ProPhoenix Auto Database Sync Utility - v1.8 (Installation Team)
# ======================================================================

Clear-Host
Write-Host "===== ProPhoenix Auto Database Sync Utility - v1.8 (Installation Team) =====" -ForegroundColor Cyan

# ----------------------------------------------------------------------
# CONFIGURATION & PATHS
# ----------------------------------------------------------------------
$setupPath = "C:\pnxtemp\dbsynctool"
$setupFile = Join-Path $setupPath "DBDetails.txt"
$xmlTarget = Join-Path $setupPath "PnxAutoNewDBSyn.xml"

if (!(Test-Path $setupPath)) {
    New-Item -ItemType Directory -Force -Path $setupPath | Out-Null
    Write-Host "✓ Created directory: $setupPath" -ForegroundColor Green
}

# ----------------------------------------------------------------------
# STEP 1: GENERATE XML FILE
# ----------------------------------------------------------------------
$xmlContent = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
	<SourceServer>
		<IPAddress>CHPNX947\MSSQLSERVER01</IPAddress> 
		<DBName>DBName</DBName> 
		<UserName>sa</UserName> 
		<Password>pnx</Password> 
		<JurisID>1000</JurisID>
		<State>MA</State>
		<JurisName>ProPhoenix</JurisName>
		<JurisAlias>PNX</JurisAlias>
		<SyncType>2</SyncType>
	</SourceServer>
</PnxPakager>
"@

if (!(Test-Path $xmlTarget)) {
    Set-Content -Path $xmlTarget -Value $xmlContent -Force
    Write-Host "✓ Generated default XML template." -ForegroundColor Green
}

# ----------------------------------------------------------------------
# STEP 2: SQL FETCH FUNCTION
# ----------------------------------------------------------------------
function Get-PhoenixDBs {
    param($Server, $User, $Password)

    try {
        $connString = "Server=$Server;User Id=$User;Password=$Password;Database=master;Connection Timeout=15;"
        $conn = New-Object System.Data.SqlClient.SqlConnection
        $conn.ConnectionString = $connString
        $conn.Open()

        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT Name FROM sys.databases WHERE (Name LIKE '%Police%' OR Name LIKE '%Fire%' OR Name LIKE '%IA%' OR Name LIKE '%Master%') AND Name NOT IN ('master', 'model', 'msdb', 'tempdb') ORDER BY Name"
        
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $cmd
        $dataset = New-Object System.Data.DataSet
        $adapter.Fill($dataset) | Out-Null
        $conn.Close()

        $dbList = $dataset.Tables[0].Rows | Select-Object -ExpandProperty Name
        return $dbList
    }
    catch {
        Write-Host "❌ LOGIN FAILED: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# ----------------------------------------------------------------------
# STEP 3: INTERACTIVE SETUP
# ----------------------------------------------------------------------
$runSetup = $true
if (Test-Path $setupFile) {
    Write-Host "✓ Configuration file found: $setupFile" -ForegroundColor Green
    $response = Read-Host "⚠ Do you want to use existing details? (Y = Proceed / N = Update or Fetch New)"
    if ($response -match "^[Yy]") { $runSetup = $false }
}

if ($runSetup) {
    $validConnection = $false
    
    while (-not $validConnection) {
        Write-Host "`n--- CONNECTION SETUP ---" -ForegroundColor Cyan
        
        $mode = Read-Host "Select Server Mode: [L] Local (This PC) / [R] Remote Server"
        if ($mode -match "^[Ll]") {
            $in_IP = $env:COMPUTERNAME
            Write-Host "✓ Local Server Selected: $in_IP" -ForegroundColor Green
        } else {
            $in_IP = Read-Host "Enter Remote SQL IP or Name"
        }

        $in_User = Read-Host "Enter SQL Username          (e.g., 'sa')"
        $in_Pass = Read-Host "Enter SQL Password"
        
        Write-Host "`nConnecting to [$in_IP] as user [$in_User]..." -ForegroundColor DarkYellow
        $fetchedDBs = Get-PhoenixDBs -Server $in_IP -User $in_User -Password $in_Pass
        $fetchedDBs = $fetchedDBs | Where-Object { $_ -ne "master" }

        if ($fetchedDBs) {
            $validConnection = $true
            Write-Host "`n✓ LOGIN SUCCESSFUL! FOUND DATABASES:" -ForegroundColor Green
            
            # === CHANGED DISPLAY FORMAT HERE ===
            $displayList = $fetchedDBs -join "; "
            Write-Host "$displayList" -ForegroundColor Gray
        }
        else {
            Write-Host "`n⚠ Connection failed." -ForegroundColor Yellow
            $retry = Read-Host "Do you want to try entering credentials again? (Y/N)"
            if ($retry -match "^[Nn]") {
                $validConnection = $true 
                $fetchedDBs = $null
            }
        }
    }

    # === PASTE LOGIC ===
    Write-Host "`n--- DATABASE SELECTION ---" -ForegroundColor Cyan
    Write-Host "Option 1: Press [ENTER] to sync ALL fetched databases." -ForegroundColor Gray
    Write-Host "Option 2: Paste your list below (Press ENTER on a blank line when done)." -ForegroundColor Yellow
    
    $rawInputList = @()
    do {
        $line = Read-Host "Paste/Type DB >"
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            $rawInputList += $line
        }
    } until ([string]::IsNullOrWhiteSpace($line))

    # === CLEANUP & FORMATTING ===
    if ($rawInputList.Count -eq 0 -and $fetchedDBs) {
        $finalList = $fetchedDBs
    }
    elseif ($rawInputList.Count -gt 0) {
        $tempList = @()
        foreach ($item in $rawInputList) {
            $cleaned = $item -replace "^[\s-]*", "" -replace "[\s-]*$", "" 
            $parts = $cleaned -split "," 
            foreach ($p in $parts) {
                if (-not [string]::IsNullOrWhiteSpace($p)) {
                    $tempList += $p.Trim()
                }
            }
        }
        $finalList = $tempList | Select-Object -Unique
    }
    else {
        Write-Host "❌ No databases selected. Exiting." -ForegroundColor Red
        exit
    }

    # Format: ;DB1;DB2;
    $formattedDBs = ";" + ($finalList -join ";") + ";"

    # === SHOW ONLY THE FORMATTED STRING ===
    Write-Host "`n[UPDATED LIST TO BE PROCESSED]" -ForegroundColor Yellow
    Write-Host "$formattedDBs" -ForegroundColor Green

    $fileContent = @"
IPAddress=$in_IP
DBName=$formattedDBs
UserName=$in_User
Password=$in_Pass
SyncType=2
"@
    Set-Content -Path $setupFile -Value $fileContent -Force
    Write-Host "✓ DBDetails.txt updated successfully." -ForegroundColor Gray
}

# ----------------------------------------------------------------------
# STEP 4: READ CONFIGURATION & VALIDATE
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
# STEP 5: DETECT PATHS & EXECUTE
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

$folders = @{
    Police        = Join-Path $DBSyncRoot "Police"
    Fire          = Join-Path $DBSyncRoot "Fire"
    IA            = Join-Path $DBSyncRoot "IA"
    PhoenixMaster = Join-Path $DBSyncRoot "Phoenix Master"
    PoliceDW      = Join-Path $DBSyncRoot "Police DW"
}

# ----------------------------------------------------------------------
# HELPER: LOG WATCHER
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

    [xml]$xmlData = Get-Content $xmlTarget
    $xmlData.PnxPakager.SourceServer.IPAddress = $IPAddress
    $xmlData.PnxPakager.SourceServer.DBName    = $DB
    $xmlData.PnxPakager.SourceServer.UserName  = $UserName
    $xmlData.PnxPakager.SourceServer.Password  = $Password
    $xmlData.PnxPakager.SourceServer.SyncType  = $SyncType

    $xmlOut = Join-Path $TargetFolder "PnxAutoNewDBSyn.xml"
    $xmlData.Save($xmlOut)

    Write-Host "✓ XML updated for: $DB" -ForegroundColor Green

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
        Write-Host "❌ TIMEOUT: No log file generated for $DB." -ForegroundColor Red
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
        $timestamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
        $backupName = "DBToolLog_${DB}_FAILED_${timestamp}.txt"
        $backupPath = Join-Path $TargetFolder $backupName
        Copy-Item -Path $logPath -Destination $backupPath -Force
        Write-Host "⚠ Log Backup: $backupName" -ForegroundColor DarkYellow
        return $false
    }
}

# ----------------------------------------------------------------------
# MAIN LOOP
# ----------------------------------------------------------------------
foreach ($db in $DBNames) {
    $db = $db.Trim()
    if ([string]::IsNullOrEmpty($db)) { continue }
    if ($db -eq "master") { continue }

    if ($db -match "Master$") { $key = "PhoenixMaster" }
    elseif ($db -match "DW$") { $key = "PoliceDW" }
    elseif ($db -match "Police") { $key = "Police" }
    elseif ($db -match "Fire") { $key = "Fire" }
    elseif ($db -match "IA$") { $key = "IA" }
    else {
        Write-Host "⚠ Unknown DB type: $db - SKIPPED" -ForegroundColor DarkGray
        continue
    }

    $target = $folders[$key]
    if (!(Test-Path $target)) {
        Write-Host "❌ Missing module folder: $target - SKIPPED" -ForegroundColor Red
        continue
    }

    $result = Run-DBSync -DB $db -TargetFolder $target

    if (-not $result) {
        Write-Host "➡ Moving to next database automatically..." -ForegroundColor Cyan
    }
}

Write-Host "`n🎉 All operations completed." -ForegroundColor Cyan