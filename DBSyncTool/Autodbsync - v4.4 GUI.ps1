# ======================================================================
#  ProPhoenix DB Utility Dashboard - v4.4 (Installation Team)
# ======================================================================
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:CredFile  = Join-Path $Script:SetupPath "SavedCreds.xml"
$Script:LogoFile  = Join-Path $Script:SetupPath "logo.png"

# Dynamic Variables
$Script:DBSyncRoot = $null
$Script:TargetDBUtilVersion = "Not Checked"
$Script:IsRemote = $false
$Script:TargetServer = "localhost"
$Script:WindowsCreds = $null

# --- DETECT PATHS ---
if (!(Test-Path $Script:SetupPath)) { New-Item -ItemType Directory -Force -Path $Script:SetupPath | Out-Null }
if (!(Test-Path $Script:XmlTarget)) { 
    Set-Content -Path $Script:XmlTarget -Value '<?xml version="1.0" encoding="utf-8" ?><PnxPakager><SourceServer><IPAddress>LOCALHOST</IPAddress><DBName>DBName</DBName><UserName>sa</UserName><Password>pnx</Password><JurisID>1000</JurisID><State>MA</State><JurisName>ProPhoenix</JurisName><JurisAlias>PNX</JurisAlias><SyncType>2</SyncType></SourceServer></PnxPakager>' -Force 
}

# --- THEME: INFOGRAPHIC LIGHT ---
$colBg      = [System.Drawing.Color]::White
$colText    = [System.Drawing.Color]::FromArgb(64, 64, 64)
$colInputBg = [System.Drawing.Color]::WhiteSmoke

# Accents
$colSrc     = [System.Drawing.Color]::FromArgb(220, 53, 69)    # Red
$colProc    = [System.Drawing.Color]::FromArgb(23, 162, 184)   # Teal
$colOut     = [System.Drawing.Color]::FromArgb(0, 123, 255)    # Blue

# Buttons
$btnGreen   = [System.Drawing.Color]::SeaGreen
$btnRed     = [System.Drawing.Color]::IndianRed
$btnOrange  = [System.Drawing.Color]::DarkOrange

$fontTitle  = New-Object System.Drawing.Font("Segoe UI Light", 22, [System.Drawing.FontStyle]::Regular)
$fontHeader = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$fontNorm   = New-Object System.Drawing.Font("Segoe UI", 9)
$fontLog    = New-Object System.Drawing.Font("Consolas", 10) 

# --- FORM SETUP ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProPhoenix DB Utility Dashboard"
$form.Size = New-Object System.Drawing.Size(1250, 850)
$form.StartPosition = "CenterScreen"
$form.BackColor = $colBg
$form.ForeColor = $colText

# --- MAIN GRID LAYOUT (The Spine) ---
# This ensures nothing ever overlaps.
# Rows:
# 0: Header (80px)
# 1: Connection (100px)
# 2: Main Body (List + Log) (100% Star)
# 3: Actions (80px)
# 4: Admin Footer (80px)
# 5: Status Bar (25px)
$mainLayout = New-Object System.Windows.Forms.TableLayoutPanel
$mainLayout.Dock = "Fill"
$mainLayout.RowCount = 6
$mainLayout.ColumnCount = 1
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 80)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 100)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 80)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 80)))
$mainLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 25)))
$form.Controls.Add($mainLayout)

# --- ROW 0: HEADER ---
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Fill"
$picLogo = New-Object System.Windows.Forms.PictureBox; $picLogo.Size="180,60"; $picLogo.Location="15,10"; $picLogo.SizeMode="Zoom"; if(Test-Path $Script:LogoFile){$picLogo.Image=[System.Drawing.Image]::FromFile($Script:LogoFile)}; $pnlHead.Controls.Add($picLogo)
$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="DataSync Dashboard"; $lblTitle.AutoSize=$true; $lblTitle.Location="210,18"; $lblTitle.Font=$fontTitle; $lblTitle.ForeColor=$colProc; $pnlHead.Controls.Add($lblTitle)
$lblVerDisplay = New-Object System.Windows.Forms.Label; $lblVerDisplay.Text = "Utility Ver: --"; $lblVerDisplay.AutoSize=$false; $lblVerDisplay.TextAlign="MiddleRight"; $lblVerDisplay.Size="300,30"; $lblVerDisplay.Location="900,25"; $lblVerDisplay.Font=$fontHeader; $lblVerDisplay.ForeColor=$colProc; $pnlHead.Controls.Add($lblVerDisplay)
$mainLayout.Controls.Add($pnlHead, 0, 0)

# --- ROW 1: CONNECTION (RED) ---
$grpCon = New-Object System.Windows.Forms.GroupBox; $grpCon.Text=" 1. SQL Connection "; $grpCon.Dock="Fill"; $grpCon.ForeColor=$colSrc; $grpCon.Font=$fontHeader
$mainLayout.Controls.Add($grpCon, 0, 1)

function Add-Field($parent, $lbl, $y, $def, $isPass=$false) {
    $l = New-Object System.Windows.Forms.Label; $l.Text=$lbl; $l.Location="20,$y"; $l.AutoSize=$true; $l.Font=$fontNorm; $l.ForeColor=$colText; $parent.Controls.Add($l)
    $t = New-Object System.Windows.Forms.TextBox; $t.Location="20,$($y+25)"; $t.Size="280,30"; $t.Text=$def; $t.Font=$fontNorm; $t.BackColor=$colInputBg; $t.BorderStyle="FixedSingle"; if($isPass){$t.PasswordChar="*"}; $parent.Controls.Add($t)
    return $t
}
# Connection Inputs (Manual placement inside fixed-height groupbox is safe)
$txtS = Add-Field $grpCon "Server IP / Name" 35 $env:COMPUTERNAME
$txtU = Add-Field $grpCon "SQL Username" 35 "sa"
$txtU.Location = "320, 60"; $grpCon.Controls[0].Location = "320, 35" # Move Label manually
$txtP = Add-Field $grpCon "SQL Password" 35 "" $true
$txtP.Location = "620, 60"; $grpCon.Controls[2].Location = "620, 35" # Move Label manually

$chkSave = New-Object System.Windows.Forms.CheckBox; $chkSave.Text="Remember"; $chkSave.Location="920, 35"; $chkSave.AutoSize=$true; $chkSave.Font=$fontNorm; $chkSave.ForeColor=$colText; $grpCon.Controls.Add($chkSave)
$btnCon = New-Object System.Windows.Forms.Button; $btnCon.Text="CONNECT"; $btnCon.Location="920, 60"; $btnCon.Size="150,30"; $btnCon.BackColor=$colSrc; $btnCon.ForeColor="White"; $btnCon.FlatStyle="Flat"; $btnCon.Font=$fontNorm; $grpCon.Controls.Add($btnCon)

# --- ROW 2: SPLIT VIEW (LIST & LOG) ---
$splitLayout = New-Object System.Windows.Forms.TableLayoutPanel
$splitLayout.Dock = "Fill"
$splitLayout.ColumnCount = 2
$splitLayout.RowCount = 1
$splitLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 35))) # 35% List
$splitLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 65))) # 65% Log
$mainLayout.Controls.Add($splitLayout, 0, 2)

# LEFT SIDE: DB List Group
$grpList = New-Object System.Windows.Forms.GroupBox; $grpList.Text=" 2. Select Targets "; $grpList.Dock="Fill"; $grpList.ForeColor=$colProc; $grpList.Font=$fontHeader
$splitLayout.Controls.Add($grpList, 0, 0)

# Inner Grid for List Group (To separate Checkbox from List)
$listInnerGrid = New-Object System.Windows.Forms.TableLayoutPanel; $listInnerGrid.Dock="Fill"; $listInnerGrid.RowCount=2; $listInnerGrid.Padding = New-Object System.Windows.Forms.Padding(10, 20, 10, 10)
$listInnerGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30))) # Fixed Row for Checkbox
$listInnerGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) # Rest for List
$grpList.Controls.Add($listInnerGrid)

$chkAll = New-Object System.Windows.Forms.CheckBox; $chkAll.Text="Select All Databases"; $chkAll.Dock="Fill"; $chkAll.Font=$fontNorm; $chkAll.ForeColor="Black"
$listInnerGrid.Controls.Add($chkAll, 0, 0)

$listDBs = New-Object System.Windows.Forms.CheckedListBox; $listDBs.Dock="Fill"; $listDBs.BorderStyle="FixedSingle"; $listDBs.BackColor=$colInputBg; $listDBs.Font=$fontNorm; $listDBs.CheckOnClick=$true
$listInnerGrid.Controls.Add($listDBs, 0, 1)

# RIGHT SIDE: Log Group
$grpLog = New-Object System.Windows.Forms.GroupBox; $grpLog.Text=" 3. Activity Log "; $grpLog.Dock="Fill"; $grpLog.ForeColor=$colOut; $grpLog.Font=$fontHeader
$splitLayout.Controls.Add($grpLog, 1, 0)

$txtLog = New-Object System.Windows.Forms.RichTextBox; $txtLog.Dock="Fill"; $txtLog.BorderStyle="FixedSingle"; $txtLog.BackColor="White"; $txtLog.ForeColor="Black"; $txtLog.Font=$fontLog; $txtLog.ReadOnly=$true; $txtLog.ScrollBars="Vertical"
# Add padding inside groupbox using a panel
$pnlLogPad = New-Object System.Windows.Forms.Panel; $pnlLogPad.Dock="Fill"; $pnlLogPad.Padding=New-Object System.Windows.Forms.Padding(10, 20, 10, 10); $grpLog.Controls.Add($pnlLogPad); $pnlLogPad.Controls.Add($txtLog)

# --- ROW 3: ACTION BUTTONS (SYNC & VERSION) ---
$pnlAction = New-Object System.Windows.Forms.Panel; $pnlAction.Dock="Fill"; $pnlAction.BackColor="White"
$mainLayout.Controls.Add($pnlAction, 0, 3)

# Use FlowLayoutPanel to center buttons
$flowAction = New-Object System.Windows.Forms.FlowLayoutPanel; $flowAction.Dock="Fill"; $flowAction.FlowDirection="LeftToRight"; $flowAction.Alignment="Center"; $flowAction.Padding=New-Object System.Windows.Forms.Padding(0, 15, 0, 0)
$pnlAction.Controls.Add($flowAction)

$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="START SYNC ➜"; $btnSync.Size="300,50"; $btnSync.BackColor=$colProc; $btnSync.ForeColor="White"; $btnSync.Font=$fontHeader; $btnSync.FlatStyle="Flat"; $btnSync.Margin=New-Object System.Windows.Forms.Padding(10)
$flowAction.Controls.Add($btnSync)

$btnVer = New-Object System.Windows.Forms.Button; $btnVer.Text="CHECK DB VERSIONS"; $btnVer.Size="300,50"; $btnVer.BackColor=$btnOrange; $btnVer.ForeColor="White"; $btnVer.Font=$fontHeader; $btnVer.FlatStyle="Flat"; $btnVer.Margin=New-Object System.Windows.Forms.Padding(10)
$flowAction.Controls.Add($btnVer)

# --- ROW 4: ADMIN FOOTER ---
$pnlFoot = New-Object System.Windows.Forms.Panel; $pnlFoot.Dock="Fill"; $pnlFoot.BackColor=$colInputBg
$mainLayout.Controls.Add($pnlFoot, 0, 4)

$lblMaint = New-Object System.Windows.Forms.Label; $lblMaint.Text="Admin Maintenance:"; $lblMaint.Location="20, 30"; $lblMaint.AutoSize=$true; $lblMaint.Font=$fontHeader; $lblMaint.ForeColor="Gray"
$pnlFoot.Controls.Add($lblMaint)

$btnInstall = New-Object System.Windows.Forms.Button; $btnInstall.Text="Install Utility"; $btnInstall.Location="220,20"; $btnInstall.Size="200,40"; $btnInstall.BackColor=$btnGreen; $btnInstall.ForeColor="White"; $btnInstall.FlatStyle="Flat"; $pnlFoot.Controls.Add($btnInstall)
$btnUninstall = New-Object System.Windows.Forms.Button; $btnUninstall.Text="Uninstall Utility"; $btnUninstall.Location="440,20"; $btnUninstall.Size="200,40"; $btnUninstall.BackColor=$btnRed; $btnUninstall.ForeColor="White"; $btnUninstall.FlatStyle="Flat"; $pnlFoot.Controls.Add($btnUninstall)

# --- ROW 5: STATUS BAR ---
$statusStrip = New-Object System.Windows.Forms.StatusStrip; $statusStrip.BackColor="White"; $statusStrip.Dock="Fill"
$lblStat = New-Object System.Windows.Forms.ToolStripStatusLabel; $lblStat.Text="Ready."; $lblStat.ForeColor="DimGray"
$pbStat = New-Object System.Windows.Forms.ToolStripProgressBar; $pbStat.Size="400,16"
$statusStrip.Items.Add($lblStat); $statusStrip.Items.Add($pbStat)
$mainLayout.Controls.Add($statusStrip, 0, 5)

# ======================================================================
#  LOGIC BLOCK
# ======================================================================

function Log-Write($text, $color="Black") {
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.SelectionColor = [System.Drawing.Color]::FromName($color)
    $txtLog.AppendText("$text`r`n")
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

function Toggle-Inputs($enable) {
    $btnCon.Enabled = $enable; $btnSync.Enabled = $enable
    $btnVer.Enabled = $enable; $btnUninstall.Enabled = $enable; $btnInstall.Enabled = $enable
}

function Save-Creds {
    if ($chkSave.Checked) {
        $SecurePass = $txtP.Text | ConvertTo-SecureString -AsPlainText -Force
        [PSCustomObject]@{ Server=$txtS.Text; User=$txtU.Text; Password=$SecurePass } | Export-Clixml -Path $Script:CredFile
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
        } catch {}
    }
}

# --- SCANNER LOGIC ---
function Scan-Server {
    param($Target)
    $Script:TargetServer = $Target
    $Script:IsRemote = ($Target -ne "localhost" -and $Target -ne $env:COMPUTERNAME -and $Target -ne "127.0.0.1")
    
    $Block = {
        $Result = [PSCustomObject]@{ Valid=$false; Version="Not Found"; Path=$null; InstallPath=$null }
        $CommonPaths = @()
        if ($env:ProgramFiles) { $CommonPaths += Join-Path $env:ProgramFiles "ProPhoenix\Server Application Manager\AppReg_Main.xml" }
        if (${env:ProgramFiles(x86)}) { $CommonPaths += Join-Path ${env:ProgramFiles(x86)} "ProPhoenix\Server Application Manager\AppReg_Main.xml" }
        foreach($p in $CommonPaths) { if(Test-Path $p) { $FoundPath=$p; break } }
        if (-not $FoundPath) {
            $Dirs = @("ProPhoenix\Server Application Manager", "Program Files (x86)\ProPhoenix\Server Application Manager", "Program Files\ProPhoenix\Server Application Manager")
            foreach ($d in Get-PSDrive -PSProvider FileSystem) {
                foreach ($sub in $Dirs) {
                    $p = Join-Path $d.Root $sub | Join-Path -ChildPath "Appreg_main.xml"; if (Test-Path $p) { $FoundPath=$p; break }
                }
                if ($FoundPath) { break }
            }
        }
        if ($FoundPath) {
            $Result.Path = $FoundPath
            try {
                [xml]$x = Get-Content $FoundPath
                if ($x.PhoenixApplications.AppReg) {
                    foreach ($app in $x.PhoenixApplications.AppReg) {
                        if ($app.AppPath -like "*Database Utility*" -and $app.AppPath -notlike "*CodeBook*") {
                            $v = if ($app.CurrentVersion) { $app.CurrentVersion } else { $app.Version }
                            $Result.Version = if ([string]::IsNullOrWhiteSpace($v)) { "0.0.0.0" } else { $v }
                            $Result.InstallPath = $app.AppPath; $Result.Valid = $true; return $Result
                        }
                    }
                }
            } catch { $Result.Err = "Read Error" }
        }
        return $Result
    }

    try {
        if ($Script:IsRemote) {
            try {
                $Args = @{ ComputerName=$Target; ScriptBlock=$Block; ErrorAction="Stop" }
                if ($Script:WindowsCreds) { $Args.Credential = $Script:WindowsCreds }
                $Data = Invoke-Command @Args
            } catch {
                if ($_.Exception.Message -match "Access is denied") {
                    $Script:WindowsCreds = $host.ui.PromptForCredential("Remote Admin", "Enter Admin Creds for $Target", "$Target\Administrator", "")
                    if ($Script:WindowsCreds) { $Args.Credential = $Script:WindowsCreds; $Data = Invoke-Command @Args } else { throw "Cancelled" }
                } else { throw $_ }
            }
        } else { $Data = Invoke-Command -ScriptBlock $Block }
        
        $Script:TargetDBUtilVersion = $Data.Version
        if ($Data.Valid) {
            $Script:DBSyncRoot = Join-Path $Data.InstallPath "DB Sync"
            $lblVerDisplay.Text = "Utility Ver: $($Data.Version)"; $lblVerDisplay.ForeColor = [System.Drawing.Color]::SeaGreen
            Log-Write "✔ Found Utility: $($Data.Version)" "Green"
        } else {
            $lblVerDisplay.Text = "Utility Not Found"; $lblVerDisplay.ForeColor = [System.Drawing.Color]::Red
            $Script:DBSyncRoot = $null; Log-Write "⚠ Utility Not Found on Target." "Red"
        }
    } catch { Log-Write "Scan Error: $($_.Exception.Message)" "Red" }
}

$form.Add_Load({ Load-Creds })
$chkAll.Add_CheckedChanged({ for ($i=0; $i -lt $listDBs.Items.Count; $i++) { $listDBs.SetItemChecked($i, $chkAll.Checked) } })

$btnCon.Add_Click({
    Toggle-Inputs $false; $listDBs.Items.Clear(); $lblStat.Text="Connecting..."; Log-Write "Connecting..." "Black"
    try {
        $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=5"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $cmd = $cn.CreateCommand(); 
        $cmd.CommandText = "SELECT Name FROM sys.databases WHERE database_id > 4 AND Name NOT IN ('master','model','msdb','tempdb', 'ReportServer', 'ReportServerTempDB') ORDER BY Name"
        $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        foreach($row in $ds.Tables[0].Rows) { [void]$listDBs.Items.Add($row.Name) }
        Log-Write "✔ SQL Connected." "Green"; $lblStat.Text="Connected."; Save-Creds; Scan-Server $txtS.Text
    } catch { Log-Write "❌ Error: $($_.Exception.Message)" "Red"; $lblStat.Text="Connection Failed." } finally { Toggle-Inputs $true }
})

# --- SYNC LOGIC ---
$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select a DB!"); return }
    if (!$Script:DBSyncRoot) { [System.Windows.Forms.MessageBox]::Show("Utility Path Not Found!", "Error"); return }
    Toggle-Inputs $false
    
    $TargetDBs = @(); foreach ($item in $listDBs.CheckedItems) { $TargetDBs += $item }
    $totalCount = $TargetDBs.Count; $dbIndex = 0; $pbStat.Maximum = 100; $pbStat.Value = 0
    $folders = @{ Police="Police"; Fire="Fire"; IA="IA"; PhoenixMaster="Phoenix Master"; PoliceDW="Police DW"; PoliceCSP="Police CSP"; FireCSP="Fire CSP" }

    foreach ($db in $TargetDBs) {
        $dbIndex++; $pct = [int](($dbIndex - 1) / $totalCount * 100)
        $lblStat.Text = "Processing $dbIndex of ${totalCount}: $db ( $pct % )"; $pbStat.Value = $pct; $pbStat.Style = "Marquee"
        Log-Write "Processing: $db..." "Blue"; [System.Windows.Forms.Application]::DoEvents()

        if ($db -match "Master$") { $k="PhoenixMaster" } elseif ($db -match "DW$") { $k="PoliceDW" } elseif ($db -match "Police") { $k="Police" } elseif ($db -match "Fire") { $k="Fire" } elseif ($db -match "IA") { $k="IA" } elseif ($db -match "PoliceCSP$") { $k="PoliceCSP" } elseif ($db -match "FireCSP$") { $k="FireCSP" } else { Log-Write "   Skipped (Unknown Type)" "Gray"; continue }
        
        $targetFolder = Join-Path $Script:DBSyncRoot $folders[$k]
        $jobBlock = {
            param($TargetFolder, $IP, $DB, $User, $Pass, $XML)
            if (!(Test-Path $TargetFolder)) { return "MISSING_FOLDER: $TargetFolder" }
            [xml]$x = $XML; $x.PnxPakager.SourceServer.IPAddress=$IP; $x.PnxPakager.SourceServer.DBName=$DB; $x.PnxPakager.SourceServer.UserName=$User; $x.PnxPakager.SourceServer.Password=$Pass; $x.Save((Join-Path $TargetFolder "PnxAutoNewDBSyn.xml"))
            $Exe = Join-Path $TargetFolder "PnxDBSync.exe"; if (!(Test-Path $Exe)) { return "MISSING_EXE: $Exe" }
            $proc = Start-Process -FilePath $Exe -WorkingDirectory $TargetFolder -PassThru -WindowStyle Minimized; $proc.WaitForExit()
            $l = Get-ChildItem $TargetFolder -Filter "DBToolLog*.txt" | Sort LastWriteTime -Desc | Select -First 1; if ($l) { return Get-Content $l.FullName -Raw } else { return "NO_LOG_CREATED" }
        }

        try {
            $xmlContent = Get-Content $Script:XmlTarget -Raw
            $argsList = @($targetFolder, $txtS.Text, $db, $txtU.Text, $txtP.Text, $xmlContent)
            $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            if ($Script:IsRemote) {
                $cmdArgs = @{ ComputerName=$Script:TargetServer; ScriptBlock=$jobBlock; ArgumentList=$argsList }
                if ($Script:WindowsCreds) { $cmdArgs.Credential = $Script:WindowsCreds }
                $logData = Invoke-Command @cmdArgs
            } else { $logData = Invoke-Command -ScriptBlock $jobBlock -ArgumentList $argsList }
            $stopWatch.Stop(); $finalTime = $stopWatch.Elapsed.ToString("ss\.f") + "s"
            if ($logData -match "DB Version Updated") { Log-Write "   ✔ Success [$finalTime]" "Green" } else { Log-Write "   ❌ Failed [$finalTime]" "Red" }
        } catch { Log-Write "Error: $($_.Exception.Message)" "Red" }
    }
    Log-Write "Completed." "Black"; Toggle-Inputs $true; $pbStat.Style="Blocks"; $pbStat.Value=100
})

$btnVer.Add_Click({
    Toggle-Inputs $false; $lblStat.Text="Checking Versions..."; Log-Write "Checking Versions..." "Blue"; Scan-Server $txtS.Text
    try {
        $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=30"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $sb = New-Object System.Text.StringBuilder; $sb.Append("DECLARE @s NVARCHAR(MAX)=''; CREATE TABLE #R(N NVARCHAR(255),V NVARCHAR(MAX)); ")
        foreach ($db in $listDBs.CheckedItems) {
            $sDB = $db.ToString().Replace("'","''"); $sb.Append(" IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$sDB') BEGIN IF EXISTS(SELECT 1 FROM [$sDB].sys.tables WHERE name='KPIDBVersion') INSERT INTO #R SELECT '$sDB', CAST(Version AS NVARCHAR(MAX)) FROM [$sDB].dbo.KPIDBVersion; ELSE INSERT INTO #R VALUES ('$sDB', 'No Table'); END ELSE INSERT INTO #R VALUES ('$sDB', 'Not Found'); ")
        }
        $sb.Append(" SELECT * FROM #R ORDER BY N; DROP TABLE #R;")
        $cmd = $cn.CreateCommand(); $cmd.CommandText = $sb.ToString(); $da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds=New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        foreach($r in $ds.Tables[0].Rows) { Log-Write "$($r.N) : $($r.V)" "Black" }
    } catch { Log-Write "Error: $($_.Exception.Message)" "Red" } finally { Toggle-Inputs $true; $lblStat.Text="Ready." }
})

# --- DB UTIL EXECUTION ---
$RunAppMgrAction = {
    param($Action)
    $FileName = "Appreg_main.xml"
    $Dirs = @("ProPhoenix\Server Application Manager", "Program Files (x86)\ProPhoenix\Server Application Manager", "Program Files\ProPhoenix\Server Application Manager")
    foreach ($d in Get-PSDrive -PSProvider FileSystem) { foreach ($sub in $Dirs) { $p=Join-Path $d.Root $sub|Join-Path -ChildPath $FileName; if(Test-Path $p){$AppRegPath=$p;break} }; if($AppRegPath){break} }
    if(!$AppRegPath){ return "ERROR: AppReg Not Found" }
    $AppMgrDir = Split-Path $AppRegPath -Parent; $Exe = Join-Path $AppMgrDir "PnxAppMgr.exe"; $BatFile = Join-Path $env:TEMP "ExecDBUtil.bat"
    Set-Content $BatFile "@echo off`ncd /d `"$AppMgrDir`"`n`"$Exe`" `"$Action`" `"DBUtility`"`npause" -Encoding ASCII
    Start-Process $BatFile -Verb RunAs -Wait; return "Executed $Action"
}

function Exec-Util($act) {
    Toggle-Inputs $false; Log-Write "Running $act..." "Black"
    try {
        if ($Script:IsRemote) {
            $cmdArgs = @{ ComputerName=$Script:TargetServer; ScriptBlock=$RunAppMgrAction; ArgumentList=$act }
            if ($Script:WindowsCreds) { $cmdArgs.Credential = $Script:WindowsCreds }
            Invoke-Command @cmdArgs
        } else { Invoke-Command -ScriptBlock $RunAppMgrAction -ArgumentList $act }
        for ($i=1; $i -le 5; $i++) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Seconds 3; Scan-Server $Script:TargetServer }
    } catch { Log-Write "Error: $($_.Exception.Message)" "Red" } finally { Toggle-Inputs $true; $lblStat.Text="Ready." }
}

$btnUninstall.Add_Click({ Exec-Util "UNINSTALL" })
$btnInstall.Add_Click({ Exec-Util "INSTALL" })

$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()