# ======================================================================
#  ProPhoenix Sync Manager - v15.0 (Queue Engine)
# ======================================================================
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:SetupFile = Join-Path $Script:SetupPath "DBDetails.txt"
$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:DBSyncRoot = $null
$Script:WorkQueue = [System.Collections.Queue]::new()
$Script:CurrentMode = "" # "SYNC" or "VERSION"

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
$form.Size = New-Object System.Drawing.Size(920, 680)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White

# --- STYLES ---
$fontHead = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$colorIn  = [System.Drawing.Color]::FromArgb(50, 50, 50)
$colorBtn = [System.Drawing.Color]::FromArgb(0, 122, 204)

# --- SQL GROUP ---
$grp = New-Object System.Windows.Forms.GroupBox
$grp.Text = " SQL Connection "; $grp.Location = "10,10"; $grp.Size = "880,80"; $grp.ForeColor = "Cyan"
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
$listDBs.Location = "10,130"; $listDBs.Size = "300,380"; $listDBs.BackColor=$colorIn; $listDBs.ForeColor="White"; $listDBs.CheckOnClick=$true
$form.Controls.Add($listDBs)

# --- LOG ---
$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.Location = "330,130"; $txtLog.Size = "560,380"; $txtLog.BackColor="Black"; $txtLog.ForeColor="LightGray"; $txtLog.ReadOnly=$true; $txtLog.Font="Consolas,9"
$form.Controls.Add($txtLog)

# --- BUTTONS ---
$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="Start Sync"; $btnSync.Location="10,530"; $btnSync.Size="300,40"; $btnSync.BackColor="Green"; $btnSync.ForeColor="White"; $btnSync.Font=$fontHead; $btnSync.FlatStyle="Flat"; $btnSync.Enabled=$false
$form.Controls.Add($btnSync)

$btnVer = New-Object System.Windows.Forms.Button; $btnVer.Text="Check Versions"; $btnVer.Location="330,530"; $btnVer.Size="200,40"; $btnVer.BackColor="DarkOrange"; $btnVer.FlatStyle="Flat"; $btnVer.Font=$fontHead; $btnVer.Enabled=$false
$form.Controls.Add($btnVer)

$lblStat = New-Object System.Windows.Forms.Label; $lblStat.Text="Ready."; $lblStat.Location="10,580"; $lblStat.AutoSize=$true; $lblStat.ForeColor="Yellow"
$form.Controls.Add($lblStat)

$progBar = New-Object System.Windows.Forms.ProgressBar; $progBar.Location="540,540"; $progBar.Size="350,20"; $form.Controls.Add($progBar)

# --- WORKER TIMER ---
$worker = New-Object System.Windows.Forms.Timer
$worker.Interval = 100 # Fast tick

# --- LOG HELPER ---
function Log-Write($text, $color="White") {
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.SelectionColor = [System.Drawing.Color]::FromName($color)
    $txtLog.AppendText("$text`r`n")
    $txtLog.ScrollToCaret()
}

# --- SELECT ALL EVENT ---
$chkAll.Add_CheckedChanged({
    for ($i=0; $i -lt $listDBs.Items.Count; $i++) {
        $listDBs.SetItemChecked($i, $chkAll.Checked)
    }
})

# --- CONNECT ---
$btnCon.Add_Click({
    $listDBs.Items.Clear()
    $lblStat.Text = "Connecting..."
    Log-Write "Connecting to SQL..." "Cyan"
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=5"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $cmd = $cn.CreateCommand()
        $cmd.CommandText = "SELECT Name FROM sys.databases WHERE database_id > 4 AND Name NOT IN ('master','model','msdb','tempdb') ORDER BY Name"
        $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null
        $cn.Close()
        
        $listDBs.Items.AddRange($ds.Tables[0].Rows.Name)
        Log-Write "Connected! Found $($listDBs.Items.Count) databases." "Lime"
        $btnSync.Enabled=$true; $btnVer.Enabled=$true
        $lblStat.Text = "Connected."
    } catch {
        Log-Write "Error: $($_.Exception.Message)" "Red"
        $lblStat.Text = "Failed."
    }
})

# --- QUEUE LOADER (SYNC) ---
$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { return }
    if (!$Script:DBSyncRoot) { Log-Write "DB Sync Not Installed!" "Red"; return }
    
    $Script:WorkQueue.Clear()
    foreach ($item in $listDBs.CheckedItems) { $Script:WorkQueue.Enqueue($item) }
    
    $Script:CurrentMode = "SYNC"
    $progBar.Value = 0; $progBar.Maximum = $Script:WorkQueue.Count
    $btnSync.Enabled=$false; $btnVer.Enabled=$false; $btnCon.Enabled=$false
    
    Log-Write "--- STARTED BATCH SYNC ---" "Yellow"
    $worker.Start()
})

# --- QUEUE LOADER (VERSION) ---
$btnVer.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { return }
    
    $Script:WorkQueue.Clear()
    foreach ($item in $listDBs.CheckedItems) { $Script:WorkQueue.Enqueue($item) }
    
    $Script:CurrentMode = "VERSION"
    $progBar.Value = 0; $progBar.Maximum = $Script:WorkQueue.Count
    $btnSync.Enabled=$false; $btnVer.Enabled=$false; $btnCon.Enabled=$false
    
    Log-Write "--- STARTED VERSION CHECK ---" "Cyan"
    $worker.Start()
})

# --- THE ENGINE (TIMER TICK) ---
$worker.Add_Tick({
    $worker.Stop() # Pause timer while working
    
    if ($Script:WorkQueue.Count -gt 0) {
        $db = $Script:WorkQueue.Dequeue()
        $progBar.Value++
        $lblStat.Text = "Processing: $db"
        
        if ($Script:CurrentMode -eq "SYNC") {
            # --- SYNC LOGIC ---
            if ($db -match "Master$") { $k="PhoenixMaster" } elseif ($db -match "DW$") { $k="PoliceDW" } elseif ($db -match "Police") { $k="Police" } elseif ($db -match "Fire") { $k="Fire" } elseif ($db -match "IA") { $k="IA" } else { $k="Unknown" }
            
            $target = Join-Path $Script:DBSyncRoot $k
            if (Test-Path $target) {
                # Config
                [xml]$x = Get-Content $Script:XmlTarget
                $x.PnxPakager.SourceServer.IPAddress=$txtS.Text; $x.PnxPakager.SourceServer.DBName=$db
                $x.PnxPakager.SourceServer.UserName=$txtU.Text; $x.PnxPakager.SourceServer.Password=$txtP.Text
                $x.Save((Join-Path $target "PnxAutoNewDBSyn.xml"))
                
                # Execute
                Log-Write "Syncing $db..." "White"
                $proc = Start-Process -FilePath (Join-Path $target "PnxDBSync.exe") -Wait -PassThru -WindowStyle Minimized
                
                # Verify
                $l = Get-ChildItem $target -Filter "DBToolLog*.txt" | Sort LastWriteTime -Desc | Select -First 1
                if ($l) {
                    $c = Get-Content $l.FullName -Raw
                    if ($c -match "DB Version Updated") { Log-Write "  [OK] Success" "Lime" } else { Log-Write "  [X] Failed" "Red" }
                }
            } else {
                Log-Write "Skipping $db (No Folder)" "Gray"
            }
        }
        elseif ($Script:CurrentMode -eq "VERSION") {
            # --- VERSION LOGIC ---
            try {
                $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=$db;Connection Timeout=5"
                $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
                $cmd = $cn.CreateCommand()
                $cmd.CommandText = "SELECT TOP 1 Version FROM KPIDBVersion"
                $ver = $cmd.ExecuteScalar()
                $cn.Close()
                if ($ver) { Log-Write "$db : $ver" "White" } else { Log-Write "$db : No Version" "Gray" }
            } catch {
                Log-Write "$db : Connection Error" "Red"
            }
        }
        
        # Resume Timer for next item
        $worker.Start()
    } else {
        # --- FINISHED ---
        $lblStat.Text = "Completed."
        Log-Write "--- BATCH COMPLETED ---" "Cyan"
        $btnSync.Enabled=$true; $btnVer.Enabled=$true; $btnCon.Enabled=$true
        [System.Windows.Forms.MessageBox]::Show("Process Completed!", "Done")
    }
})

$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()