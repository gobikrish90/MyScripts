# ======================================================================
#  ProPhoenix Sync Manager - v17.0 (Direct Control + Anti-Freeze)
# ======================================================================
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:DBSyncRoot = $null
$Script:StopOperation = $false  # Flag to control stopping

# --- DETECT PATHS ---
if (!(Test-Path $Script:SetupPath)) { New-Item -ItemType Directory -Force -Path $Script:SetupPath | Out-Null }
if (!(Test-Path $Script:XmlTarget)) { 
    Set-Content -Path $Script:XmlTarget -Value '<?xml version="1.0" encoding="utf-8" ?><PnxPakager><SourceServer><IPAddress>LOCALHOST</IPAddress><DBName>DBName</DBName><UserName>sa</UserName><Password>pnx</Password><JurisID>1000</JurisID><State>MA</State><JurisName>ProPhoenix</JurisName><JurisAlias>PNX</JurisAlias><SyncType>2</SyncType></SourceServer></PnxPakager>' -Force 
}
foreach ($drive in (Get-PSDrive -PSProvider FileSystem).Root) {
    $candidate = Join-Path $drive "Program Files\ProPhoenix\Database Utility\DB Sync"
    if (Test-Path $candidate) { $Script:DBSyncRoot = $candidate; break }
}

# --- FORM SETUP ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProPhoenix Sync Manager (Installation Team)"
$form.Size = New-Object System.Drawing.Size(960, 720)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White

# --- STYLES ---
$fontHead = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$colorIn  = [System.Drawing.Color]::FromArgb(50, 50, 50)
$colorBtn = [System.Drawing.Color]::FromArgb(0, 122, 204)

# --- SQL GROUP ---
$grp = New-Object System.Windows.Forms.GroupBox
$grp.Text = " SQL Connection "; $grp.Location = "10,10"; $grp.Size = "920,80"; $grp.ForeColor = "Cyan"
$form.Controls.Add($grp)

$lblS = New-Object System.Windows.Forms.Label; $lblS.Text="Server:"; $lblS.Location="15,30"; $lblS.AutoSize=$true; $grp.Controls.Add($lblS)
$txtS = New-Object System.Windows.Forms.TextBox; $txtS.Location="70,28"; $txtS.Size="180,25"; $txtS.BackColor=$colorIn; $txtS.ForeColor="White"; $txtS.Text=$env:COMPUTERNAME; $grp.Controls.Add($txtS)

$lblU = New-Object System.Windows.Forms.Label; $lblU.Text="User:"; $lblU.Location="260,30"; $lblU.AutoSize=$true; $grp.Controls.Add($lblU)
$txtU = New-Object System.Windows.Forms.TextBox; $txtU.Location="310,28"; $txtU.Size="120,25"; $txtU.BackColor=$colorIn; $txtU.ForeColor="White"; $txtU.Text="sa"; $grp.Controls.Add($txtU)

$lblP = New-Object System.Windows.Forms.Label; $lblP.Text="Pass:"; $lblP.Location="440,30"; $lblP.AutoSize=$true; $grp.Controls.Add($lblP)
$txtP = New-Object System.Windows.Forms.TextBox; $txtP.Location="490,28"; $txtP.Size="120,25"; $txtP.BackColor=$colorIn; $txtP.ForeColor="White"; $txtP.PasswordChar="*"; $grp.Controls.Add($txtP)

$btnCon = New-Object System.Windows.Forms.Button; $btnCon.Text="Connect"; $btnCon.Location="630,26"; $btnCon.Size="100,28"; $btnCon.BackColor=$colorBtn; $btnCon.FlatStyle="Flat"; $grp.Controls.Add($btnCon)

# --- SELECT ALL CHECKBOX ---
$chkAll = New-Object System.Windows.Forms.CheckBox
$chkAll.Text = "Select All"
$chkAll.Location = New-Object System.Drawing.Point(15, 100)
$chkAll.AutoSize = $true
$chkAll.Font = $fontHead
$chkAll.ForeColor = [System.Drawing.Color]::Yellow
$form.Controls.Add($chkAll)

# --- LIST BOX ---
$listDBs = New-Object System.Windows.Forms.CheckedListBox
$listDBs.Location = "10,130"; $listDBs.Size = "300,400"; $listDBs.BackColor=$colorIn; $listDBs.ForeColor="White"; $listDBs.CheckOnClick=$true
$form.Controls.Add($listDBs)

# --- LOG ---
$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Location = "330,130"; $txtLog.Size = "600,400"; $txtLog.BackColor="Black"; $txtLog.ForeColor="LightGray"; $txtLog.ReadOnly=$true; $txtLog.Font="Consolas,9"
$form.Controls.Add($txtLog)

# --- BUTTONS ---
$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="Start Sync"; $btnSync.Location="10,550"; $btnSync.Size="250,45"; $btnSync.BackColor="Green"; $btnSync.ForeColor="White"; $btnSync.Font=$fontHead; $btnSync.FlatStyle="Flat"; $btnSync.Enabled=$false
$form.Controls.Add($btnSync)

$btnStop = New-Object System.Windows.Forms.Button; $btnStop.Text="STOP OPERATION"; $btnStop.Location="270,550"; $btnStop.Size="180,45"; $btnStop.BackColor="Red"; $btnStop.ForeColor="White"; $btnStop.Font=$fontHead; $btnStop.FlatStyle="Flat"; $btnStop.Enabled=$false
$form.Controls.Add($btnStop)

$btnVer = New-Object System.Windows.Forms.Button; $btnVer.Text="Check Versions"; $btnVer.Location="460,550"; $btnVer.Size="200,45"; $btnVer.BackColor="DarkOrange"; $btnVer.FlatStyle="Flat"; $btnVer.Font=$fontHead; $btnVer.Enabled=$false
$form.Controls.Add($btnVer)

$lblStat = New-Object System.Windows.Forms.Label; $lblStat.Text="Ready."; $lblStat.Location="10,610"; $lblStat.AutoSize=$true; $lblStat.ForeColor="Yellow"
$form.Controls.Add($lblStat)

# --- HELPER FUNCTIONS ---
function Log-Write($text, $color="White") {
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.SelectionColor = [System.Drawing.Color]::FromName($color)
    $txtLog.AppendText("$text`r`n")
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents() # FORCE UI REFRESH
}

function Toggle-Inputs($enable) {
    $btnCon.Enabled = $enable
    $btnSync.Enabled = $enable
    $btnVer.Enabled = $enable
    $btnStop.Enabled = -not $enable
}

# --- SELECT ALL EVENT ---
$chkAll.Add_CheckedChanged({
    for ($i=0; $i -lt $listDBs.Items.Count; $i++) {
        $listDBs.SetItemChecked($i, $chkAll.Checked)
    }
})

# --- CONNECT BUTTON ---
$btnCon.Add_Click({
    Toggle-Inputs $false
    $listDBs.Items.Clear()
    $lblStat.Text = "Connecting..."
    Log-Write "Connecting to SQL Server..." "Cyan"
    
    try {
        $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=5"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs)
        $cn.Open()
        
        $cmd = $cn.CreateCommand()
        $cmd.CommandText = "SELECT Name FROM sys.databases WHERE database_id > 4 AND Name NOT IN ('master','model','msdb','tempdb','ReportServer','ReportServerTempDB') ORDER BY Name"
        $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null
        $cn.Close()

        foreach($row in $ds.Tables[0].Rows) { [void]$listDBs.Items.Add($row.Name) }
        Log-Write "✔ Connected! Found $($listDBs.Items.Count) databases." "Lime"
        $lblStat.Text = "Connected."
    }
    catch {
        Log-Write "❌ Error: $($_.Exception.Message)" "Red"
        if ($_.Exception.Message -match "error: 40") { Log-Write "   Hint: Check Server Name / Instance / Firewall" "Yellow" }
    }
    finally {
        Toggle-Inputs $true
        $btnStop.Enabled = $false
    }
})

# --- STOP BUTTON ---
$btnStop.Add_Click({
    $Script:StopOperation = $true
    $lblStat.Text = "Stopping..."
    Log-Write "🛑 STOP REQUESTED. PLEASE WAIT..." "Red"
})

# --- SYNC BUTTON (DIRECT LOOP) ---
$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select a DB!"); return }
    if (!$Script:DBSyncRoot) { Log-Write "DB Sync Not Installed!" "Red"; return }
    
    Toggle-Inputs $false
    $Script:StopOperation = $false
    $lblStat.Text = "Syncing..."
    
    $folders = @{
        Police = Join-Path $Script:DBSyncRoot "Police"; Fire = Join-Path $Script:DBSyncRoot "Fire"; IA = Join-Path $Script:DBSyncRoot "IA"; PhoenixMaster = Join-Path $Script:DBSyncRoot "Phoenix Master"; PoliceDW = Join-Path $Script:DBSyncRoot "Police DW"
    }

    foreach ($db in $listDBs.CheckedItems) {
        # STOP CHECK
        if ($Script:StopOperation) { Log-Write "⚠ Operation Aborted by User." "Orange"; break }

        Log-Write "--------------------------------" "Gray"
        Log-Write "Processing: $db" "Yellow"
        $lblStat.Text = "Processing $db..."
        [System.Windows.Forms.Application]::DoEvents()

        # Categorize
        if ($db -match "Master$") { $k="PhoenixMaster" } elseif ($db -match "DW$") { $k="PoliceDW" } elseif ($db -match "Police") { $k="Police" } elseif ($db -match "Fire") { $k="Fire" } elseif ($db -match "IA") { $k="IA" } else { Log-Write "Skipped (Unknown Type)" "Gray"; continue }
        
        $target = $folders[$k]
        if (!(Test-Path $target)) { Log-Write "Missing Folder: $target" "Red"; continue }

        try {
            # Update XML
            [xml]$x = Get-Content $Script:XmlTarget
            $x.PnxPakager.SourceServer.IPAddress=$txtS.Text; $x.PnxPakager.SourceServer.DBName=$db
            $x.PnxPakager.SourceServer.UserName=$txtU.Text; $x.PnxPakager.SourceServer.Password=$txtP.Text
            $x.Save((Join-Path $target "PnxAutoNewDBSyn.xml"))

            # START TOOL AND WAIT (ANTI-FREEZE LOOP)
            $exe = Join-Path $target "PnxDBSync.exe"
            if (!(Test-Path $exe)) { Log-Write "Missing EXE" "Red"; continue }

            $proc = Start-Process -FilePath $exe -Wait -PassThru -WindowStyle Minimized
            
            # This loop waits for the tool but keeps GUI alive and Stop button working
            while (-not $proc.HasExited) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 200
                
                # HANDLE EMERGENCY STOP
                if ($Script:StopOperation) {
                    Log-Write "Killing Process..." "Red"
                    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
                    break
                }
            }

            if ($Script:StopOperation) { break }

            # Check Log
            Start-Sleep -Seconds 1
            $l = Get-ChildItem $target -Filter "DBToolLog*.txt" | Sort LastWriteTime -Desc | Select -First 1
            if ($l) {
                $c = Get-Content $l.FullName -Raw
                if ($c -match "DB Version Updated") { Log-Write "✔ SUCCESS" "Lime" } else { Log-Write "❌ FAILED (Check Log)" "Red" }
            } else { Log-Write "⚠ LOG MISSING" "Red" }

        } catch {
            Log-Write "Error: $($_.Exception.Message)" "Red"
        }
    }
    
    $lblStat.Text = "Ready."
    Toggle-Inputs $true
    $btnStop.Enabled = $false
    [System.Windows.Forms.MessageBox]::Show("Operation Completed", "Done")
})

# --- VERSION CHECK (DIRECT LOOP) ---
$btnVer.Add_Click({
    Toggle-Inputs $false
    $Script:StopOperation = $false
    $lblStat.Text = "Checking Versions..."
    Log-Write "Checking DB Versions..." "Cyan"
    
    try {
        $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=30"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        
        $q = "DECLARE @s NVARCHAR(MAX)=''; CREATE TABLE #R(N NVARCHAR(255),V NVARCHAR(MAX)); SELECT @s=@s+' IF EXISTS(SELECT 1 FROM ['+name+'].sys.tables WHERE name=''KPIDBVersion'') INSERT INTO #R SELECT '''+name+''',CAST(Version AS NVARCHAR(MAX)) FROM ['+name+'].dbo.KPIDBVersion; ' FROM sys.databases WHERE database_id>4 AND state_desc='ONLINE'; EXEC(@s); SELECT * FROM #R ORDER BY N; DROP TABLE #R;"
        $cmd = $cn.CreateCommand(); $cmd.CommandText=$q
        
        # Async execution simulation not needed here as it's usually fast, but we wrap in DoEvents just in case
        $da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds=New-Object System.Data.DataSet
        $da.Fill($ds)|Out-Null
        $cn.Close()

        Log-Write "=== VERSION REPORT ===" "White"
        foreach($r in $ds.Tables[0].Rows) {
            Log-Write "$($r.N) : $($r.V)" "White"
        }
    } catch {
        Log-Write "Error: $($_.Exception.Message)" "Red"
    } finally {
        Toggle-Inputs $true
        $btnStop.Enabled = $false
        $lblStat.Text = "Ready."
    }
})

$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()