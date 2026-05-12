# ======================================================================
#  ProPhoenix Sync Manager - v3.9 (Installation Team)
# ======================================================================
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:CredFile  = Join-Path $Script:SetupPath "SavedCreds.xml"
$Script:LogoFile  = Join-Path $Script:SetupPath "logo.png"
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

# --- COLORS & FONTS ---
$colBg      = [System.Drawing.Color]::FromArgb(32, 32, 32)
$colPanel   = [System.Drawing.Color]::FromArgb(45, 45, 48)
$colText    = [System.Drawing.Color]::WhiteSmoke
$colAccent  = [System.Drawing.Color]::FromArgb(0, 122, 204)
$colSuccess = [System.Drawing.Color]::FromArgb(28, 151, 65)
$colWarn    = [System.Drawing.Color]::FromArgb(209, 100, 0)
$colErr     = [System.Drawing.Color]::FromArgb(200, 50, 50)

$fontTitle  = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$fontHead   = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontNorm   = New-Object System.Drawing.Font("Segoe UI", 9)
$fontLog    = New-Object System.Drawing.Font("Consolas", 9)

# --- FORM SETUP ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProPhoenix Sync Manager (Installation Team)"
$form.Size = New-Object System.Drawing.Size(1000, 850)
$form.StartPosition = "CenterScreen"
$form.BackColor = $colBg
$form.ForeColor = $colText

# --- HEADER PANEL ---
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Top"; $pnlHead.Height=80; $pnlHead.BackColor=$colPanel; $form.Controls.Add($pnlHead)
$picLogo = New-Object System.Windows.Forms.PictureBox; $picLogo.Size="200,60"; $picLogo.Location="15,10"; $picLogo.SizeMode="Zoom"; if(Test-Path $Script:LogoFile){$picLogo.Image=[System.Drawing.Image]::FromFile($Script:LogoFile)}; $pnlHead.Controls.Add($picLogo)
$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="Database Synchronization Utility"; $lblTitle.AutoSize=$true; $lblTitle.Location="230,25"; $lblTitle.Font=$fontTitle; $lblTitle.ForeColor=$colAccent; $pnlHead.Controls.Add($lblTitle)

# --- MAIN LAYOUT ---
$pnlBody = New-Object System.Windows.Forms.Panel; $pnlBody.Dock="Fill"; $pnlBody.Padding=15; $form.Controls.Add($pnlBody)

# --- SQL CONNECTION ---
$grp = New-Object System.Windows.Forms.GroupBox; $grp.Text=" SQL Connection "; $grp.Size="950,80"; $grp.Location="15,100"; $grp.ForeColor=$colAccent; $grp.Font=$fontHead; $pnlBody.Controls.Add($grp)

function Add-Input($parent, $label, $x, $w, $defVal, $isPass=$false) {
    $l = New-Object System.Windows.Forms.Label; $l.Text=$label; $l.Location="$x,30"; $l.AutoSize=$true; $l.Font=$fontNorm; $l.ForeColor=$colText; $parent.Controls.Add($l)
    $t = New-Object System.Windows.Forms.TextBox; $t.Location="$($x+60),27"; $t.Size="$w,25"; $t.BackColor=[System.Drawing.Color]::FromArgb(60,60,60); $t.ForeColor="White"; $t.Font=$fontNorm; $t.Text=$defVal; if($isPass){$t.PasswordChar="*"}; $parent.Controls.Add($t)
    return $t
}
$txtS = Add-Input $grp "Server:" 15 150 $env:COMPUTERNAME; $txtU = Add-Input $grp "User:" 240 100 "sa"; $txtP = Add-Input $grp "Pass:" 420 100 "" $true

$chkSave = New-Object System.Windows.Forms.CheckBox; $chkSave.Text="Remember Me"; $chkSave.Location="600,27"; $chkSave.AutoSize=$true; $chkSave.Font=$fontNorm; $chkSave.ForeColor="White"; $grp.Controls.Add($chkSave)
$btnCon = New-Object System.Windows.Forms.Button; $btnCon.Text="Connect"; $btnCon.Location="750,23"; $btnCon.Size="120,32"; $btnCon.BackColor=$colAccent; $btnCon.ForeColor="White"; $btnCon.FlatStyle="Flat"; $btnCon.Font=$fontNorm; $grp.Controls.Add($btnCon)

# --- SPLIT CONTAINER ---
$split = New-Object System.Windows.Forms.SplitContainer; $split.Location="15,190"; $split.Size="950,380"; $split.SplitterDistance=300; $split.BackColor=$colBg; $pnlBody.Controls.Add($split)

$lblList = New-Object System.Windows.Forms.Label; $lblList.Text="Target Databases"; $lblList.Dock="Top"; $lblList.Font=$fontHead; $split.Panel1.Controls.Add($lblList)
$chkAll = New-Object System.Windows.Forms.CheckBox; $chkAll.Text="Select All"; $chkAll.Dock="Top"; $chkAll.ForeColor="Yellow"; $split.Panel1.Controls.Add($chkAll)
$listDBs = New-Object System.Windows.Forms.CheckedListBox; $listDBs.Dock="Fill"; $listDBs.BackColor=[System.Drawing.Color]::FromArgb(40,40,40); $listDBs.ForeColor="White"; $listDBs.CheckOnClick=$true; $split.Panel1.Controls.Add($listDBs)

$lblLog = New-Object System.Windows.Forms.Label; $lblLog.Text="Activity Log"; $lblLog.Dock="Top"; $lblLog.Font=$fontHead; $split.Panel2.Controls.Add($lblLog)
$txtLog = New-Object System.Windows.Forms.RichTextBox; $txtLog.Dock="Fill"; $txtLog.BackColor="Black"; $txtLog.ForeColor="LightGray"; $txtLog.ReadOnly=$true; $txtLog.Font=$fontLog; $split.Panel2.Controls.Add($txtLog)

# --- SYNC BUTTONS ---
$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="START SYNC"; $btnSync.Location="15,590"; $btnSync.Size="250,50"; $btnSync.BackColor=$colSuccess; $btnSync.ForeColor="White"; $btnSync.Font=$fontHead; $btnSync.FlatStyle="Flat"; $btnSync.Enabled=$false; $pnlBody.Controls.Add($btnSync)
$btnVer = New-Object System.Windows.Forms.Button; $btnVer.Text="CHECK VERSIONS"; $btnVer.Location="270,590"; $btnVer.Size="250,50"; $btnVer.BackColor=$colWarn; $btnVer.ForeColor="White"; $btnVer.Font=$fontHead; $btnVer.FlatStyle="Flat"; $btnVer.Enabled=$false; $pnlBody.Controls.Add($btnVer)

# --- UTILITY MAINTENANCE ---
$grpUtil = New-Object System.Windows.Forms.GroupBox; $grpUtil.Text=" DB Utility Maintenance (Admin) "; $grpUtil.Location="15,660"; $grpUtil.Size="950,80"; $grpUtil.ForeColor="Magenta"; $grpUtil.Font=$fontHead; $pnlBody.Controls.Add($grpUtil)
$btnUninstall = New-Object System.Windows.Forms.Button; $btnUninstall.Text="Uninstall Utility"; $btnUninstall.Location="20,25"; $btnUninstall.Size="200,40"; $btnUninstall.BackColor=$colErr; $btnUninstall.ForeColor="White"; $btnUninstall.FlatStyle="Flat"; $grpUtil.Controls.Add($btnUninstall)
$btnInstall = New-Object System.Windows.Forms.Button; $btnInstall.Text="Install Utility"; $btnInstall.Location="240,25"; $btnInstall.Size="200,40"; $btnInstall.BackColor=$colSuccess; $btnInstall.ForeColor="White"; $btnInstall.FlatStyle="Flat"; $grpUtil.Controls.Add($btnInstall)

# --- STATUS & PROGRESS ---
$statusStrip = New-Object System.Windows.Forms.StatusStrip; $statusStrip.BackColor=$colPanel; $form.Controls.Add($statusStrip)
$lblStat = New-Object System.Windows.Forms.ToolStripStatusLabel; $lblStat.Text="Ready."; $lblStat.ForeColor="White"; $statusStrip.Items.Add($lblStat)
$pbStat = New-Object System.Windows.Forms.ToolStripProgressBar; $pbStat.Size="400,16"; $statusStrip.Items.Add($pbStat)

# ======================================================================
#  LOGIC BLOCK
# ======================================================================

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

function Save-Creds {
    if ($chkSave.Checked) {
        $SecurePass = $txtP.Text | ConvertTo-SecureString -AsPlainText -Force
        [PSCustomObject]@{ Server=$txtS.Text; User=$txtU.Text; Password=$SecurePass } | Export-Clixml -Path $Script:CredFile
        Log-Write "Credentials Saved." "Gray"
    } else { if (Test-Path $Script:CredFile) { Remove-Item $Script:CredFile -Force } }
}

function Load-Creds {
    if (Test-Path $Script:CredFile) {
        try {
            $CredData = Import-Clixml -Path $Script:CredFile
            $txtS.Text = $CredData.Server; $txtU.Text = $CredData.User
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($CredData.Password)
            $txtP.Text = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            $chkSave.Checked = $true
            Log-Write "Loaded Saved Credentials." "Lime"
        } catch {}
    }
}

$form.Add_Load({ Load-Creds })
$chkAll.Add_CheckedChanged({ for ($i=0; $i -lt $listDBs.Items.Count; $i++) { $listDBs.SetItemChecked($i, $chkAll.Checked) } })

$btnCon.Add_Click({
    Toggle-Inputs $false; $listDBs.Items.Clear(); $lblStat.Text="Connecting..."; Log-Write "Connecting..." "Cyan"
    try {
        $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=5"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $cmd = $cn.CreateCommand()
        $cmd.CommandText = "SELECT Name FROM sys.databases WHERE database_id > 4 AND Name NOT IN ('master','model','msdb','tempdb','ReportServer','ReportServerTempDB') ORDER BY Name"
        $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        foreach($row in $ds.Tables[0].Rows) { [void]$listDBs.Items.Add($row.Name) }
        Log-Write "✔ Connected! Found $($listDBs.Items.Count) DBs." "Lime"; $lblStat.Text="Connected."; Save-Creds
    } catch { Log-Write "❌ Error: $($_.Exception.Message)" "Red"; $lblStat.Text="Connection Failed." } finally { Toggle-Inputs $true }
})

# --- SYNC LOGIC (DETAILED DURATION) ---
$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select a DB!"); return }
    Toggle-Inputs $false
    
    $totalCount = $listDBs.CheckedItems.Count
    $dbIndex = 0
    $pbStat.Maximum = 100
    $pbStat.Value = 0
    
    $folders = @{ Police=Join-Path $Script:DBSyncRoot "Police"; Fire=Join-Path $Script:DBSyncRoot "Fire"; IA=Join-Path $Script:DBSyncRoot "IA"; PhoenixMaster=Join-Path $Script:DBSyncRoot "Phoenix Master"; PoliceDW=Join-Path $Script:DBSyncRoot "Police DW" }

    foreach ($db in $listDBs.CheckedItems) {
        $dbIndex++
        
        # Calculate Starting Percentage
        $pct = [int](($dbIndex - 1) / $totalCount * 100)
        
        # Status Update
        $pbStat.Value = $pct
        $pbStat.Style = "Marquee"
        $pbStat.MarqueeAnimationSpeed = 30
        
        Log-Write "--------------------------------------------" "Gray"
        Log-Write "[ $pct % ] Processing: $db" "Cyan"
        
        [System.Windows.Forms.Application]::DoEvents()

        if ($db -match "Master$") { $k="PhoenixMaster" } elseif ($db -match "DW$") { $k="PoliceDW" } elseif ($db -match "Police") { $k="Police" } elseif ($db -match "Fire") { $k="Fire" } elseif ($db -match "IA") { $k="IA" } else { continue }
        $target = $folders[$k]
        
        try {
            [xml]$x = Get-Content $Script:XmlTarget
            $x.PnxPakager.SourceServer.IPAddress=$txtS.Text; $x.PnxPakager.SourceServer.DBName=$db
            $x.PnxPakager.SourceServer.UserName=$txtU.Text; $x.PnxPakager.SourceServer.Password=$txtP.Text
            $x.Save((Join-Path $target "PnxAutoNewDBSyn.xml"))

            # --- START EXECUTION ---
            $proc = Start-Process -FilePath (Join-Path $target "PnxDBSync.exe") -PassThru -WindowStyle Minimized
            $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            # --- LIVE TIMER LOOP ---
            while (-not $proc.HasExited) {
                $elapsed = $stopWatch.Elapsed.ToString("ss\.f")
                $lblStat.Text = "Syncing $db ... ( $elapsed sec )"
                [System.Windows.Forms.Application]::DoEvents() 
                Start-Sleep -Milliseconds 100
            }
            $stopWatch.Stop()
            $finalTime = $stopWatch.Elapsed.ToString("ss\.f") + "s"

            $l = Get-ChildItem $target -Filter "DBToolLog*.txt" | Sort LastWriteTime -Desc | Select -First 1
            if ($l -and (Get-Content $l.FullName -Raw) -match "DB Version Updated") { 
                Log-Write "   ✔ Success [ $finalTime ]" "Lime" 
            } else { 
                Log-Write "   ❌ Failed [ $finalTime ]" "Red"
                if ($l) {
                    $errLines = Get-Content $l.FullName -Tail 5
                    Log-Write "   [DETAILS]:" "Orange"
                    foreach($line in $errLines) { Log-Write "   $line" "Gray" }
                    Copy-Item $l.FullName (Join-Path $target "DBToolLog_${db}_FAILED.txt") -Force 
                }
            }
        } catch { Log-Write "Error: $($_.Exception.Message)" "Red" }
        
        # --- COMPLETION UPDATE ---
        $pbStat.Style = "Blocks"
        $newPct = [int]($dbIndex / $totalCount * 100)
        $pbStat.Value = $newPct
        # Fixed syntax error from previous version by using cleaner string concatenation or sub-expressions
        $lblStat.Text = "Completed: $db ( $newPct % ) - Took: $finalTime"
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    Log-Write "--------------------------------------------" "Gray"
    Log-Write "[ 100 % ] All Operations Completed." "Lime"
    $lblStat.Text = "Sync Cycle Finished (100 %)"; 
    Toggle-Inputs $true
    [System.Windows.Forms.MessageBox]::Show("Sync Complete (100%)", "Done")
})

$btnVer.Add_Click({
    Toggle-Inputs $false; $lblStat.Text="Checking Versions..."; Log-Write "Checking Versions..." "Cyan"
    try {
        $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=30"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $sb = New-Object System.Text.StringBuilder
        $sb.Append("DECLARE @s NVARCHAR(MAX)=''; CREATE TABLE #R(N NVARCHAR(255),V NVARCHAR(MAX)); ")
        foreach ($db in $listDBs.CheckedItems) {
            $sDB = $db.ToString().Replace("'","''")
            $sb.Append(" IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$sDB') BEGIN IF EXISTS(SELECT 1 FROM [$sDB].sys.tables WHERE name='KPIDBVersion') INSERT INTO #R SELECT '$sDB', CAST(Version AS NVARCHAR(MAX)) FROM [$sDB].dbo.KPIDBVersion; ELSE INSERT INTO #R VALUES ('$sDB', 'No Table'); END ELSE INSERT INTO #R VALUES ('$sDB', 'Not Found'); ")
        }
        $sb.Append(" SELECT * FROM #R ORDER BY N; DROP TABLE #R;")
        $cmd = $cn.CreateCommand(); $cmd.CommandText = $sb.ToString()
        $da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds=New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        Log-Write "=== VERSION REPORT ===" "White"
        foreach($r in $ds.Tables[0].Rows) { Log-Write "$($r.N) : $($r.V)" "White" }
    } catch { Log-Write "Error: $($_.Exception.Message)" "Red" } finally { Toggle-Inputs $true; $lblStat.Text="Ready." }
})

# --- DB UTIL EXECUTION ---
$RunAppMgrAction = {
    param($Action, $IsLocal)
    $PnxTemp = "C:\pnxtemp\dbsynctool"; if(!(Test-Path $PnxTemp)){New-Item -ItemType Directory -Path $PnxTemp -Force|Out-Null}
    $AppRegPath = $null; $FileName="Appreg_main.xml"; $Paths=@("ProPhoenix\Server Application Manager","Program Files (x86)\ProPhoenix\Server Application Manager","Program Files\ProPhoenix\Server Application Manager")
    foreach($d in Get-PSDrive -PSProvider FileSystem){ foreach($p in $Paths){ $t=Join-Path $d.Root $p|Join-Path -ChildPath $FileName; if(Test-Path $t){$AppRegPath=$t;break} }; if($AppRegPath){break} }
    if(!$AppRegPath){return "Error: Appreg_main.xml not found"}
    $Exe = Join-Path (Split-Path $AppRegPath -Parent) "PnxAppMgr.exe"
    
    # Use Here-String for safe batch content generation
    $BatDir = Split-Path $AppRegPath -Parent
    $BatContent = @"
@echo off
cd /d "$BatDir"
"$Exe" "$Action" "DBUtility"
pause
"@
    $BatFile = Join-Path $PnxTemp "ExecDBUtil.bat"
    Set-Content $BatFile $BatContent -Encoding ASCII
    
    if($IsLocal){ Start-Process $BatFile -Verb RunAs; return "Launched locally" }
    else { Start-Process "cmd.exe" -ArgumentList "/c `"$BatFile`"" -Wait; return "Executed remotely" }
}

function Exec-Util($act) {
    Toggle-Inputs $false; $lblStat.Text="$act Utility..."
    $IsLocal = ($txtS.Text -eq "localhost" -or $txtS.Text -eq $env:COMPUTERNAME)
    try {
        if ($IsLocal) { $r=& $RunAppMgrAction -Action $act -IsLocal $true; Log-Write $r "Lime" }
        else { 
            $s=New-PSSession -ComputerName $txtS.Text -ErrorAction Stop
            $r=Invoke-Command -Session $s -ScriptBlock $RunAppMgrAction -ArgumentList $act,$false
            Remove-PSSession $s; Log-Write $r "Lime"
        }
    } catch { Log-Write "Error: $($_.Exception.Message)" "Red" } finally { Toggle-Inputs $true; $lblStat.Text="Ready." }
}

$btnUninstall.Add_Click({ Exec-Util "UNINSTALL" })
$btnInstall.Add_Click({ Exec-Util "INSTALL" })

$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()