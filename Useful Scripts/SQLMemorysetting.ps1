# --- CONFIGURATION ---
$InstanceName = "localhost"   # Set to "localhost" or specific instance
$MinMemoryMB  = 1024          # Minimum allowed setting (1GB)
# ---------------------

# 1. Prompt for SQL Credentials
Write-Host "------------------------------------------------------" -ForegroundColor Cyan
Write-Host " SQL MEMORY CONFIGURATION (75% Rule)" -ForegroundColor Cyan
Write-Host "------------------------------------------------------" -ForegroundColor Cyan

$SqlUser = Read-Host "Enter SQL Username (e.g. sa)"
$SqlPassSecure = Read-Host "Enter SQL Password" -AsSecureString

# Convert to plain text
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPassSecure)
$SqlPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

try {
    # 2. Connect to SQL
    Write-Host "Connecting to $InstanceName..." -ForegroundColor Gray
    $connString = "Server=$InstanceName;User Id=$SqlUser;Password=$SqlPassword;"
    $conn = New-Object System.Data.SqlClient.SqlConnection($connString)
    $conn.Open()

    # 3. Get Total RAM and Current Settings
    $checkQuery = @"
    SELECT 
        (SELECT physical_memory_kb / 1024 FROM sys.dm_os_sys_info) AS TotalRAM_MB,
        (SELECT value_in_use FROM sys.configurations WHERE name = 'min server memory (MB)') AS CurrentMin,
        (SELECT value_in_use FROM sys.configurations WHERE name = 'max server memory (MB)') AS CurrentMax
"@
    $cmd = $conn.CreateCommand()
    $cmd.CommandText = $checkQuery
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
    $dt = New-Object System.Data.DataTable
    $adapter.Fill($dt) | Out-Null

    # 4. Calculate Targets
    $totalRamMB = [math]::Round($dt.Rows[0]["TotalRAM_MB"])
    $currentMin = $dt.Rows[0]["CurrentMin"]
    $currentMax = $dt.Rows[0]["CurrentMax"]

    # Calculate 75% Target
    $newMaxMB = [math]::Round($totalRamMB * 0.75)
    
    # Safety: Ensure Target isn't below Minimum
    if ($newMaxMB -lt $MinMemoryMB) { $newMaxMB = $MinMemoryMB }

    # 5. Display Analysis (Current vs New)
    Write-Host "`n---------------- ANALYSIS ----------------" -ForegroundColor White
    Write-Host " Total Server RAM : $totalRamMB MB"
    Write-Host "------------------------------------------" -ForegroundColor Gray
    
    # Format a table-like output for clarity
    Write-Host " SETTING           CURRENT VALUE      NEW VALUE" -ForegroundColor Yellow
    Write-Host " Min Memory (MB)   $($currentMin.ToString().PadRight(18)) $MinMemoryMB"
    Write-Host " Max Memory (MB)   $($currentMax.ToString().PadRight(18)) $newMaxMB"
    Write-Host "------------------------------------------" -ForegroundColor Gray

    # 6. Compare and Execute
    if ($currentMin -eq $MinMemoryMB -and $currentMax -eq $newMaxMB) {
        Write-Host " [STATUS]  SKIPPED" -ForegroundColor Green
        Write-Host " Reason:   Values are already correct." -ForegroundColor Gray
    }
    else {
        Write-Host " [STATUS]  UPDATING..." -ForegroundColor Cyan
        
        $updateQuery = @"
        EXEC sys.sp_configure N'show advanced options', N'1';
        RECONFIGURE WITH OVERRIDE;
        EXEC sys.sp_configure N'min server memory (MB)', $MinMemoryMB;
        EXEC sys.sp_configure N'max server memory (MB)', $newMaxMB;
        RECONFIGURE;
"@
        $cmd.CommandText = $updateQuery
        $cmd.ExecuteNonQuery() | Out-Null
        
        Write-Host " [RESULT]  SUCCESS" -ForegroundColor Green
        Write-Host " Message:  Memory updated to 75% of RAM ($newMaxMB MB)." -ForegroundColor Gray
    }
    $conn.Close()
}
catch {
    Write-Host "`n [ERROR] Failed to process $InstanceName : $_" -ForegroundColor Red
}