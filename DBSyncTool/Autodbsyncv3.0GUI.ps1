# ======================================================================
#  ProPhoenix Sync Manager - v14.0 (Async Jobs + Select All)
# ======================================================================
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:SetupFile = Join-Path $Script:SetupPath "DBDetails.txt"
$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:DBSyncRoot = $null

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

# --- TIMER FOR JOBS ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 500 # Check every 0.5s

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

# --- CONNECT (BACKGROUND JOB) ---
$btnCon.Add_Click({
    $btnCon.Enabled=$false; $btnSync.Enabled=$false; $btnVer.Enabled=$false
    $listDBs.Items.Clear()
    $lblStat.Text = "Connecting..."
    Log-Write "Connecting to SQL Server..." "Cyan"
    
    $args = @($txtS.Text, $txtU.Text, $txtP.Text)
    $job = Start-Job -ScriptBlock {
        param($s, $u, $p)
        try {
            $cs = "Server=$s;User Id=$u;Password=$p;Database=master;Connection Timeout=10"
            $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
            $cmd = $cn.CreateCommand()
            $cmd.CommandText = "SELECT Name FROM sys.databases WHERE database_id > 4 AND Name NOT IN ('master','model','msdb','tempdb') ORDER BY Name"
            $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null
            $cn.Close()
            return $ds.Tables[0].Rows.Name
        } catch { return "ERROR: $($_.Exception.Message)" }
    } -ArgumentList $args

    $timer.Tag = "CONNECT"
    $timer.Start()
})

# --- SYNC (BACKGROUND JOB) ---
$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select a DB!"); return }
    if (!$Script:DBSyncRoot) { Log-Write "DB Sync Not Installed!" "Red"; return }
    
    $btnSync.Enabled=$false; $btnCon.Enabled=$false; $btnVer.Enabled=$false
    $lblStat.Text = "Syncing..."
    
    # Prepare List for Job
    $dbs = @(); foreach($x in $listDBs.CheckedItems){ $dbs += $x }
    
    $args = @($txtS.Text, $txtU.Text, $txtP.Text, $dbs, $Script:DBSyncRoot, $Script:XmlTarget)
    
    $job = Start-Job -ScriptBlock {
        param($s, $u, $p, $dblist, $root, $xmlTemplate)
        $logOut = @()
        
        $folders = @{
            Police = Join-Path $root "Police"; Fire = Join-Path $root "Fire"; IA = Join-Path $root "IA"; PhoenixMaster = Join-Path $root "Phoenix Master"; PoliceDW = Join-Path $root "Police DW"
        }

        foreach ($db in $dblist) {
            $logOut += "PROCESSING::$db"
            if ($db -match "Master$") { $k="PhoenixMaster" } elseif ($db -match "DW$") { $k="PoliceDW" } elseif ($db -match "Police") { $k="Police" } elseif ($db -match "Fire") { $k="Fire" } elseif ($db -match "IA") { $k="IA" } else { continue }
            
            $target = $folders[$k]
            if (!(Test-Path $target)) { continue }

            # XML Update
            [xml]$x = Get-Content $xmlTemplate
            $x.PnxPakager.SourceServer.IPAddress=$s; $x.PnxPakager.SourceServer.DBName=$db
            $x.PnxPakager.SourceServer.UserName=$u; $x.PnxPakager.SourceServer.Password=$p
            $x.Save((Join-Path $target "PnxAutoNewDBSyn.xml"))

            # Run
            $exe = Join-Path $target "PnxDBSync.exe"
            $proc = Start-Process -FilePath $exe -Wait -PassThru -WindowStyle Minimized
            
            # Check Log
            Start-Sleep -s 2
            $l = Get-ChildItem $target -Filter "DBToolLog*.txt" | Sort LastWriteTime -Desc | Select -First 1
            if ($l) {
                $c = Get-Content $l.FullName -Raw
                if ($c -match "DB Version Updated") { $logOut += "SUCCESS::$db" } else { $logOut += "FAIL::$db" }
            }
        }
        return $logOut
    } -ArgumentList $args

    $timer.Tag = "SYNC"
    $timer.Start()
})

# --- VERSION CHECK (BACKGROUND JOB) ---
$btnVer.Add_Click({
    $btnSync.Enabled=$false; $btnCon.Enabled=$false; $btnVer.Enabled=$false
    $lblStat.Text = "Checking Versions..."
    Log-Write "Checking DB Versions..." "Cyan"

    $args = @($txtS.Text, $txtU.Text, $txtP.Text)
    $job = Start-Job -ScriptBlock {
        param($s, $u, $p)
        try {
            $cs = "Server=$s;User Id=$u;Password=$p;Database=master;Connection Timeout=30"
            $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
            $q = "DECLARE @s NVARCHAR(MAX)=''; CREATE TABLE #R(N NVARCHAR(255),V NVARCHAR(MAX)); SELECT @s=@s+' IF EXISTS(SELECT 1 FROM ['+name+'].sys.tables WHERE name=''KPIDBVersion'') INSERT INTO #R SELECT '''+name+''',CAST(Version AS NVARCHAR(MAX)) FROM ['+name+'].dbo.KPIDBVersion; ' FROM sys.databases WHERE database_id>4 AND state_desc='ONLINE'; EXEC(@s); SELECT * FROM #R ORDER BY N; DROP TABLE #R;"
            $cmd = $cn.CreateCommand(); $cmd.CommandText=$q; $da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds=New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
            
            $res = @(); foreach($r in $ds.Tables[0].Rows){ $res += "$($r.N)|$($r.V)" }; return $res
        } catch { return "ERROR: $($_.Exception.Message)" }
    } -ArgumentList $args

    $timer.Tag = "VERSION"
    $timer.Start()
})

# --- TIMER TICK (HANDLE RESULTS) ---
$timer.Add_Tick({
    $job = Get-Job | Where-Object { $_.State -ne "Running" } | Select-Object -First 1
    if ($job) {
        $results = Receive-Job $job
        Remove-Job $job
        $timer.Stop()
        $btnCon.Enabled=$true; 
        if ($listDBs.Items.Count -gt 0) { $btnSync.Enabled=$true; $btnVer.Enabled=$true }
        $lblStat.Text = "Ready."

        # HANDLE RESULTS BASED ON TAG
        if ($timer.Tag -eq "CONNECT") {
            if ($results -match "ERROR:") { Log-Write $results "Red"; [System.Windows.Forms.MessageBox]::Show("Connection Failed", "Error") }
            else {
                $listDBs.Items.Clear()
                if ($results) { [void]$listDBs.Items.AddRange($results) }
                Log-Write "Connected! Found $($listDBs.Items.Count) databases." "Lime"
            }
        }
        elseif ($timer.Tag -eq "SYNC") {
            foreach ($line in $results) {
                if ($line -match "PROCESSING::") { Log-Write "Syncing: $($line -replace 'PROCESSING::','')" "Yellow" }
                elseif ($line -match "SUCCESS::") { Log-Write "  ✓ Success: $($line -replace 'SUCCESS::','')" "Lime" }
                elseif ($line -match "FAIL::") { Log-Write "  X Failed: $($line -replace 'FAIL::','')" "Red" }
            }
            [System.Windows.Forms.MessageBox]::Show("Sync Completed", "Done")
        }
        elseif ($timer.Tag -eq "VERSION") {
            if ($results -match "ERROR:") { Log-Write $results "Red" }
            else {
                Log-Write "=== VERSION REPORT ===" "White"
                foreach ($r in $results) {
                    $parts = $r -split "\|"
                    if ($parts.Count -eq 2) { Log-Write "$($parts[0]) : $($parts[1])" "White" }
                }
            }
        }
    } else {
        # Animation
        if ($lblStat.Text.Length -lt 20) { $lblStat.Text += "." } else { $lblStat.Text = $lblStat.Text.TrimEnd('.') }
    }
})

$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()