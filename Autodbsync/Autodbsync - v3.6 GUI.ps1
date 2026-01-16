# ======================================================================
#  ProPhoenix Sync Manager - v21.0 (Auto-Save Credentials)
# ======================================================================
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:CredFile  = Join-Path $Script:SetupPath "SavedCreds.xml" # <--- NEW CRED FILE
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
$form.Size = New-Object System.Drawing.Size(960, 820)
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
$txtS = New-Object System.Windows.Forms.TextBox; $txtS.Location="70,28"; $txtS.Size="160,25"; $txtS.BackColor=$colorIn; $txtS.ForeColor="White"; $txtS.Text=$env:COMPUTERNAME; $grp.Controls.Add($txtS)

$lblU = New-Object System.Windows.Forms.Label; $lblU.Text="User:"; $lblU.Location="240,30"; $lblU.AutoSize=$true; $grp.Controls.Add($lblU)
$txtU = New-Object System.Windows.Forms.TextBox; $txtU.Location="280,28"; $txtU.Size="120,25"; $txtU.BackColor=$colorIn; $txtU.ForeColor="White"; $txtU.Text="sa"; $grp.Controls.Add($txtU)

$lblP = New-Object System.Windows.Forms.Label; $lblP.Text="Pass:"; $lblP.Location="410,30"; $lblP.AutoSize=$true; $grp.Controls.Add($lblP)
$txtP = New-Object System.Windows.Forms.TextBox; $txtP.Location="450,28"; $txtP.Size="120,25"; $txtP.BackColor=$colorIn; $txtP.ForeColor="White"; $txtP.PasswordChar="*"; $grp.Controls.Add($txtP)

# --- AUTO SAVE CHECKBOX ---
$chkSave = New-Object System.Windows.Forms.CheckBox
$chkSave.Text = "Auto-Save"
$chkSave.Location = "580,28"
$chkSave.AutoSize = $true
$chkSave.ForeColor = "Yellow"
$grp.Controls.Add($chkSave)

$btnCon = New-Object System.Windows.Forms.Button; $btnCon.Text="Connect"; $btnCon.Location="680,26"; $btnCon.Size="100,28"; $btnCon.BackColor=$colorBtn; $btnCon.FlatStyle="Flat"; $grp.Controls.Add($btnCon)

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

# --- ACTION BUTTONS ---
$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="Start Sync"; $btnSync.Location="10,550"; $btnSync.Size="400,45"; $btnSync.BackColor="Green"; $btnSync.ForeColor="White"; $btnSync.Font=$fontHead; $btnSync.FlatStyle="Flat"; $btnSync.Enabled=$false
$form.Controls.Add($btnSync)

$btnVer = New-Object System.Windows.Forms.Button; $btnVer.Text="Check Versions"; $btnVer.Location="420,550"; $btnVer.Size="250,45"; $btnVer.BackColor="DarkOrange"; $btnVer.FlatStyle="Flat"; $btnVer.Font=$fontHead; $btnVer.Enabled=$false
$form.Controls.Add($btnVer)

# --- UTILITY MAINTENANCE GROUP ---
$grpUtil = New-Object System.Windows.Forms.GroupBox
$grpUtil.Text = " DB Utility Maintenance (Runs as Admin) "; $grpUtil.Location = "10,610"; $grpUtil.Size = "920,80"; $grpUtil.ForeColor = "Magenta"
$form.Controls.Add($grpUtil)

$btnUninstall = New-Object System.Windows.Forms.Button; $btnUninstall.Text="Uninstall DB Utility"; $btnUninstall.Location="20,25"; $btnUninstall.Size="200,40"; $btnUninstall.BackColor=[System.Drawing.Color]::DarkRed; $btnUninstall.ForeColor="White"; $btnUninstall.FlatStyle="Flat"; $grpUtil.Controls.Add($btnUninstall)

$btnInstall = New-Object System.Windows.Forms.Button; $btnInstall.Text="Install DB Utility"; $btnInstall.Location="240,25"; $btnInstall.Size="200,40"; $btnInstall.BackColor=[System.Drawing.Color]::DarkGreen; $btnInstall.ForeColor="White"; $btnInstall.FlatStyle="Flat"; $grpUtil.Controls.Add($btnInstall)

$lblStat = New-Object System.Windows.Forms.Label; $lblStat.Text="Ready."; $lblStat.Location="10,720"; $lblStat.AutoSize=$true; $lblStat.ForeColor="Yellow"
$form.Controls.Add($lblStat)

# --- HELPER FUNCTIONS ---
function Log-Write($text, $color="White") {
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.SelectionColor = [System.Drawing.Color]::FromName($color)
    $txtLog.AppendText("$text`r`n")
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Toggle-Inputs($enable) {
    $btnCon.Enabled = $enable
    $btnSync.Enabled = $enable
    $btnVer.Enabled = $enable
    $btnUninstall.Enabled = $enable
    $btnInstall.Enabled = $enable
}

# --- CREDENTIAL FUNCTIONS ---
function Save-Creds {
    if ($chkSave.Checked) {
        $PlainTextPass = $txtP.Text
        $SecurePass = $PlainTextPass | ConvertTo-SecureString -AsPlainText -Force
        
        # Create Custom Object including Server Name
        $CredData = [PSCustomObject]@{
            Server   = $txtS.Text
            User     = $txtU.Text
            Password = $SecurePass
        }
        
        # Export Securely using CLIXML (Locked to current user/machine)
        $CredData | Export-Clixml -Path $Script:CredFile
        Log-Write "Credentials Saved (Securely)." "Gray"
    } else {
        if (Test-Path $Script:CredFile) { Remove-Item $Script:CredFile -Force }
    }
}

function Load-Creds {
    if (Test-Path $Script:CredFile) {
        try {
            $CredData = Import-Clixml -Path $Script:CredFile
            $txtS.Text = $CredData.Server
            $txtU.Text = $CredData.User
            
            # Decode Secure String back to Plain Text for the TextBox
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredData.Password)
            $Plain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            $txtP.Text = $Plain
            
            $chkSave.Checked = $true
            Log-Write "Auto-Filled Saved Credentials." "Lime"
        } catch {
            Log-Write "Could not load saved credentials (maybe changed user?)" "Orange"
        }
    }
}

# --- FORM LOAD EVENT ---
$form.Add_Load({
    Load-Creds
})

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
        
        # AUTO SAVE TRIGGER
        Save-Creds
    }
    catch {
        Log-Write "❌ Error: $($_.Exception.Message)" "Red"
        if ($_.Exception.Message -match "error: 40") { Log-Write "   Hint: Check Server Name / Instance / Firewall" "Yellow" }
    }
    finally {
        Toggle-Inputs $true
    }
})

# --- SYNC BUTTON ---
$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select a DB!"); return }
    if (!$Script:DBSyncRoot) { Log-Write "DB Sync Not Installed!" "Red"; return }
    
    Toggle-Inputs $false
    $lblStat.Text = "Syncing..."
    
    $folders = @{
        Police = Join-Path $Script:DBSyncRoot "Police"; Fire = Join-Path $Script:DBSyncRoot "Fire"; IA = Join-Path $Script:DBSyncRoot "IA"; PhoenixMaster = Join-Path $Script:DBSyncRoot "Phoenix Master"; PoliceDW = Join-Path $Script:DBSyncRoot "Police DW"
    }

    foreach ($db in $listDBs.CheckedItems) {
        Log-Write "--------------------------------" "Gray"
        Log-Write "Processing: $db" "Yellow"
        $lblStat.Text = "Processing $db..."
        [System.Windows.Forms.Application]::DoEvents()

        if ($db -match "Master$") { $k="PhoenixMaster" } elseif ($db -match "DW$") { $k="PoliceDW" } elseif ($db -match "Police") { $k="Police" } elseif ($db -match "Fire") { $k="Fire" } elseif ($db -match "IA") { $k="IA" } else { Log-Write "Skipped (Unknown Type)" "Gray"; continue }
        
        $target = $folders[$k]
        if (!(Test-Path $target)) { Log-Write "Missing Folder: $target" "Red"; continue }

        try {
            [xml]$x = Get-Content $Script:XmlTarget
            $x.PnxPakager.SourceServer.IPAddress=$txtS.Text; $x.PnxPakager.SourceServer.DBName=$db
            $x.PnxPakager.SourceServer.UserName=$txtU.Text; $x.PnxPakager.SourceServer.Password=$txtP.Text
            $x.Save((Join-Path $target "PnxAutoNewDBSyn.xml"))

            $exe = Join-Path $target "PnxDBSync.exe"
            if (!(Test-Path $exe)) { Log-Write "Missing EXE" "Red"; continue }

            $proc = Start-Process -FilePath $exe -Wait -PassThru -WindowStyle Minimized
            
            while (-not $proc.HasExited) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 200
            }

            Start-Sleep -Seconds 1
            $l = Get-ChildItem $target -Filter "DBToolLog*.txt" | Sort LastWriteTime -Desc | Select -First 1
            if ($l) {
                $c = Get-Content $l.FullName -Raw
                if ($c -match "DB Version Updated") { 
                    Log-Write "✔ SUCCESS" "Lime" 
                } else { 
                    Log-Write "❌ FAILED (Check Log)" "Red" 
                    $backupName = "DBToolLog_${db}_FAILED_$(Get-Date -f yyyyMMdd_HHmmss).txt"
                    $backupPath = Join-Path $target $backupName
                    Copy-Item $l.FullName $backupPath -Force
                    Log-Write "   ↳ Log Backed Up: $backupName" "Orange"
                }
            } else { Log-Write "⚠ LOG MISSING" "Red" }

        } catch {
            Log-Write "Error: $($_.Exception.Message)" "Red"
        }
    }
    
    $lblStat.Text = "Ready."
    Toggle-Inputs $true
    [System.Windows.Forms.MessageBox]::Show("Operation Completed", "Done")
})

# --- VERSION CHECK ---
$btnVer.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select databases to check!"); return }
    Toggle-Inputs $false
    $lblStat.Text = "Checking Versions..."
    Log-Write "Checking DB Versions for SELECTED items..." "Cyan"
    
    try {
        $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=30"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        
        $sb = New-Object System.Text.StringBuilder
        $sb.Append("DECLARE @s NVARCHAR(MAX)=''; CREATE TABLE #R(N NVARCHAR(255),V NVARCHAR(MAX)); ")
        
        foreach ($db in $listDBs.CheckedItems) {
            $safeDB = $db.ToString().Replace("'", "''")
            $sb.Append(" IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$safeDB') ")
            $sb.Append("   BEGIN IF EXISTS(SELECT 1 FROM [$safeDB].sys.tables WHERE name='KPIDBVersion') ")
            $sb.Append("     INSERT INTO #R SELECT '$safeDB', CAST(Version AS NVARCHAR(MAX)) FROM [$safeDB].dbo.KPIDBVersion; ")
            $sb.Append("   ELSE INSERT INTO #R VALUES ('$safeDB', 'Table Missing'); END ")
            $sb.Append(" ELSE INSERT INTO #R VALUES ('$safeDB', 'DB Not Found'); ")
        }
        $sb.Append(" SELECT * FROM #R ORDER BY N; DROP TABLE #R;")
        
        $cmd = $cn.CreateCommand(); $cmd.CommandText = $sb.ToString()
        $da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds=New-Object System.Data.DataSet
        $da.Fill($ds)|Out-Null
        $cn.Close()

        Log-Write "=== VERSION REPORT ===" "White"
        foreach($r in $ds.Tables[0].Rows) { Log-Write "$($r.N) : $($r.V)" "White" }
    } catch { Log-Write "Error: $($_.Exception.Message)" "Red" } 
    finally { Toggle-Inputs $true; $lblStat.Text = "Ready." }
})

# --- DB UTILITY FUNCTIONS (BAT + ADMIN) ---
$RunAppMgrAction = {
    param($Action, $IsLocal)
    $FileName = "Appreg_main.xml"
    $PossibleParents = @("ProPhoenix\Server Application Manager", "Program Files (x86)\ProPhoenix\Server Application Manager", "Program Files\ProPhoenix\Server Application Manager")
    $Drives = Get-PSDrive -PSProvider FileSystem; $AppRegPath = $null

    foreach ($d in $Drives) {
        foreach ($folder in $PossibleParents) {
            $TryPath = Join-Path -Path $d.Root -ChildPath $folder | Join-Path -ChildPath $FileName
            if (Test-Path $TryPath) { $AppRegPath = $TryPath; break }
        }
        if ($AppRegPath) { break }
    }

    if (-not $AppRegPath) { return "ERROR: Appreg_main.xml not found." }
    $AppMgrFolder = Split-Path -Path $AppRegPath -Parent
    $ExePath = Join-Path $AppMgrFolder "PnxAppMgr.exe"
    
    if (-not (Test-Path $ExePath)) { return "ERROR: PnxAppMgr.exe not found." }

    $PnxTemp = "C:\pnxtemp\dbsynctool"
    if (-not (Test-Path $PnxTemp)) { New-Item -ItemType Directory -Path $PnxTemp -Force | Out-Null }
    $BatFile = Join-Path $PnxTemp "Execute_DBUtil_$Action.bat"
    
    $BatchContent = @"
@echo off
echo ===========================================
echo   PROPHOENIX DB UTILITY MANAGER
echo   Action: $Action
echo ===========================================
cd /d "$AppMgrFolder"
echo Running: PnxAppMgr.exe $Action DBUtility
"PnxAppMgr.exe" "$Action" "DBUtility"
echo.
echo Process Complete.
pause
"@
    Set-Content -Path $BatFile -Value $BatchContent -Encoding ASCII

    if ($IsLocal) {
        Start-Process -FilePath $BatFile -Verb RunAs
        return "SUCCESS: Launched $Action (Check Popup Window)"
    } else {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$BatFile`"" -Wait
        return "SUCCESS: Executed $Action Remotely"
    }
}

function Exec-Utility($actionName) {
    Toggle-Inputs $false
    $lblStat.Text = "$actionName DB Utility..."
    Log-Write "Preparing $actionName for DB Utility..." "Cyan"
    
    $Target = $txtS.Text
    $IsLocal = ($Target -eq "localhost" -or $Target -eq $env:COMPUTERNAME -or $Target -eq "127.0.0.1")
    
    try {
        if ($IsLocal) {
            $res = & $RunAppMgrAction -Action $actionName -IsLocal $true
            if ($res -match "SUCCESS") { Log-Write $res "Lime" } else { Log-Write $res "Red" }
        } else {
            Log-Write "Connecting to Remote Server: $Target..." "Yellow"
            $s = New-PSSession -ComputerName $Target -ErrorAction Stop
            $res = Invoke-Command -Session $s -ScriptBlock $RunAppMgrAction -ArgumentList $actionName, $false
            Remove-PSSession $s
            if ($res -match "SUCCESS") { Log-Write $res "Lime" } else { Log-Write $res "Red" }
        }
    } catch {
        Log-Write "Utility Error: $($_.Exception.Message)" "Red"
    } finally {
        Toggle-Inputs $true
        $lblStat.Text = "Ready."
    }
}

$btnUninstall.Add_Click({ Exec-Utility "UNINSTALL" })
$btnInstall.Add_Click({ Exec-Utility "INSTALL" })

$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()