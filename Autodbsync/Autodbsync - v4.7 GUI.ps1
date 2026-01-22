# ======================================================================
#  ProPhoenix DB Utility Dashboard - v4.7
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

$fontTitle  = New-Object System.Drawing.Font("Segoe UI Light", 20, [System.Drawing.FontStyle]::Regular)
$fontHeader = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontNorm   = New-Object System.Drawing.Font("Segoe UI", 9)
$fontLog    = New-Object System.Drawing.Font("Consolas", 9) 

# --- FORM SETUP ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProPhoenix DB Utility Dashboard"
$form.Size = New-Object System.Drawing.Size(1150, 750) 
$form.StartPosition = "CenterScreen"
$form.BackColor = $colBg
$form.ForeColor = $colText

# --- MASTER GRID LAYOUT ---
$masterGrid = New-Object System.Windows.Forms.TableLayoutPanel
$masterGrid.Dock = "Fill"
$masterGrid.RowCount = 6
$masterGrid.ColumnCount = 1
# Row Definitions
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70)))  # Header
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70)))  # Admin
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 90)))  # Connection
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))  # Body
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 100))) # Actions
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 25)))  # Status
$form.Controls.Add($masterGrid)

# --- ROW 0: HEADER ---
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Fill"
$picLogo = New-Object System.Windows.Forms.PictureBox; $picLogo.Size="160,50"; $picLogo.Location="15,10"; $picLogo.SizeMode="Zoom"; if(Test-Path $Script:LogoFile){$picLogo.Image=[System.Drawing.Image]::FromFile($Script:LogoFile)}; $pnlHead.Controls.Add($picLogo)
$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="DB Sync Dashboard - Installation"; $lblTitle.AutoSize=$true; $lblTitle.Location="190,15"; $lblTitle.Font=$fontTitle; $lblTitle.ForeColor=$colProc; $pnlHead.Controls.Add($lblTitle)
$lblVerDisplay = New-Object System.Windows.Forms.Label; $lblVerDisplay.Text = "Utility Ver: --"; $lblVerDisplay.AutoSize=$false; $lblVerDisplay.TextAlign="MiddleRight"; $lblVerDisplay.Size="300,30"; $lblVerDisplay.Location="800,20"; $lblVerDisplay.Font=$fontHeader; $lblVerDisplay.ForeColor=$colProc; $pnlHead.Controls.Add($lblVerDisplay)
$masterGrid.Controls.Add($pnlHead, 0, 0)

# --- ROW 1: ADMIN MAINTENANCE ---
$pnlAdmin = New-Object System.Windows.Forms.Panel; $pnlAdmin.Dock="Fill"; $pnlAdmin.BackColor=$colInputBg
$masterGrid.Controls.Add($pnlAdmin, 0, 1)

$lblMaint = New-Object System.Windows.Forms.Label; $lblMaint.Text="Admin Maintenance:"; $lblMaint.Location="20, 25"; $lblMaint.AutoSize=$true; $lblMaint.Font=$fontHeader; $lblMaint.ForeColor="Gray"
$pnlAdmin.Controls.Add($lblMaint)

$btnInstall = New-Object System.Windows.Forms.Button; $btnInstall.Text="Install Utility"; $btnInstall.Location="200,15"; $btnInstall.Size="180,40"; $btnInstall.BackColor=$btnGreen; $btnInstall.ForeColor="White"; $btnInstall.FlatStyle="Flat"; $pnlAdmin.Controls.Add($btnInstall)
$btnUninstall = New-Object System.Windows.Forms.Button; $btnUninstall.Text="Uninstall Utility"; $btnUninstall.Location="400,15"; $btnUninstall.Size="180,40"; $btnUninstall.BackColor=$btnRed; $btnUninstall.ForeColor="White"; $btnUninstall.FlatStyle="Flat"; $pnlAdmin.Controls.Add($btnUninstall)

# --- ROW 2: CONNECTION ---
$grpCon = New-Object System.Windows.Forms.GroupBox; $grpCon.Text=" 1. SQL Connection "; $grpCon.Dock="Fill"; $grpCon.ForeColor=$colSrc; $grpCon.Font=$fontHeader
$masterGrid.Controls.Add($grpCon, 0, 2)

$flowCon = New-Object System.Windows.Forms.FlowLayoutPanel; $flowCon.Dock="Fill"
$flowCon.Padding = New-Object System.Windows.Forms.Padding(10, 15, 0, 0)
$grpCon.Controls.Add($flowCon)

function Add-FlowInput($parent, $lbl, $w, $def, $isPass=$false) {
    $p = New-Object System.Windows.Forms.Panel; $p.Size = New-Object System.Drawing.Size($w, 50)
    $l = New-Object System.Windows.Forms.Label; $l.Text=$lbl; $l.Location="0,0"; $l.AutoSize=$true; $l.Font=$fontNorm; $l.ForeColor="Black"; $p.Controls.Add($l)
    $t = New-Object System.Windows.Forms.TextBox; $t.Location="0,20"; $t.Width=($w-10); $t.Text=$def; $t.Font=$fontNorm; $t.BackColor=$colInputBg; $t.BorderStyle="FixedSingle"; if($isPass){$t.PasswordChar="*"}; $p.Controls.Add($t)
    $parent.Controls.Add($p)
    return $t
}
$txtS = Add-FlowInput $flowCon "Server IP / Name" 200 $env:COMPUTERNAME
$txtU = Add-FlowInput $flowCon "SQL Username" 150 "sa"
$txtP = Add-FlowInput $flowCon "SQL Password" 150 "" $true

$pChk = New-Object System.Windows.Forms.Panel; $pChk.Size="120,50"; $flowCon.Controls.Add($pChk)
$chkSave = New-Object System.Windows.Forms.CheckBox; $chkSave.Text="Remember"; $chkSave.Location="0,22"; $chkSave.AutoSize=$true; $chkSave.Font=$fontNorm; $chkSave.ForeColor="Black"; $pChk.Controls.Add($chkSave)

$pBtn = New-Object System.Windows.Forms.Panel; $pBtn.Size="150,50"; $flowCon.Controls.Add($pBtn)
$btnCon = New-Object System.Windows.Forms.Button; $btnCon.Text="CONNECT"; $btnCon.Location="0,15"; $btnCon.Size="130,32"; $btnCon.BackColor=$colSrc; $btnCon.ForeColor="White"; $btnCon.FlatStyle="Flat"; $btnCon.Font=$fontHeader; $pBtn.Controls.Add($btnCon)

# --- ROW 3: MAIN BODY ---
$splitGrid = New-Object System.Windows.Forms.TableLayoutPanel; $splitGrid.Dock="Fill"; $splitGrid.ColumnCount=2; $splitGrid.RowCount=1
$splitGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 35)))
$splitGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 65)))
$masterGrid.Controls.Add($splitGrid, 0, 3)

# LEFT: LIST
$grpList = New-Object System.Windows.Forms.GroupBox; $grpList.Text=" 2. Select Targets "; $grpList.Dock="Fill"; $grpList.ForeColor=$colProc; $grpList.Font=$fontHeader
$splitGrid.Controls.Add($grpList, 0, 0)

$listInner = New-Object System.Windows.Forms.TableLayoutPanel; $listInner.Dock="Fill"; $listInner.RowCount=2
$listInner.Padding = New-Object System.Windows.Forms.Padding(10, 20, 10, 10)
$listInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
$listInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$grpList.Controls.Add($listInner)

$chkAll = New-Object System.Windows.Forms.CheckBox; $chkAll.Text="Select All Databases"; $chkAll.Dock="Fill"; $chkAll.Font=$fontNorm; $chkAll.ForeColor="Black"
$listInner.Controls.Add($chkAll, 0, 0)

$listDBs = New-Object System.Windows.Forms.CheckedListBox; $listDBs.Dock="Fill"; $listDBs.BorderStyle="FixedSingle"; $listDBs.BackColor=$colInputBg; $listDBs.Font=$fontNorm; $listDBs.CheckOnClick=$true
$listInner.Controls.Add($listDBs, 0, 1)

# RIGHT: LOG
$grpLog = New-Object System.Windows.Forms.GroupBox; $grpLog.Text=" 3. Activity Log "; $grpLog.Dock="Fill"; $grpLog.ForeColor=$colOut; $grpLog.Font=$fontHeader
$splitGrid.Controls.Add($grpLog, 1, 0)

$txtLog = New-Object System.Windows.Forms.RichTextBox; $txtLog.Dock="Fill"; $txtLog.BorderStyle="None"; $txtLog.BackColor="White"; $txtLog.ForeColor="Black"; $txtLog.Font=$fontLog; $txtLog.ReadOnly=$true; $txtLog.ScrollBars="Vertical"
$pnlLogPad = New-Object System.Windows.Forms.Panel; $pnlLogPad.Dock="Fill"; $pnlLogPad.Padding=New-Object System.Windows.Forms.Padding(10, 20, 10, 10); $grpLog.Controls.Add($pnlLogPad); $pnlLogPad.Controls.Add($txtLog)

# --- ROW 4: ACTION BUTTONS (GRID LAYOUT FIX) ---
# Using a 2-Column Table ensures 50/50 split and guarantees visibility
$pnlAction = New-Object System.Windows.Forms.TableLayoutPanel
$pnlAction.Dock="Fill"; $pnlAction.BackColor="White"; $pnlAction.ColumnCount=2; $pnlAction.RowCount=1
$pnlAction.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$pnlAction.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$pnlAction.Padding = New-Object System.Windows.Forms.Padding(50, 25, 50, 25) 
$masterGrid.Controls.Add($pnlAction, 0, 4)

$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="START SYNC ➜"; $btnSync.Dock="Fill"; $btnSync.BackColor=$colProc; $btnSync.ForeColor="White"; $btnSync.Font=$fontHeader; $btnSync.FlatStyle="Flat"
$pnlAction.Controls.Add($btnSync, 0, 0)

$btnVer = New-Object System.Windows.Forms.Button; $btnVer.Text="CHECK DB VERSIONS"; $btnVer.Dock="Fill"; $btnVer.BackColor=$btnOrange; $btnVer.ForeColor="White"; $btnVer.Font=$fontHeader; $btnVer.FlatStyle="Flat"
$btnVer.Margin = New-Object System.Windows.Forms.Padding(20, 0, 0, 0) # Gap between buttons
$pnlAction.Controls.Add($btnVer, 1, 0)

# --- ROW 5: STATUS ---
$statusStrip = New-Object System.Windows.Forms.StatusStrip; $statusStrip.BackColor="White"; $statusStrip.Dock="Fill"
$lblStat = New-Object System.Windows.Forms.ToolStripStatusLabel; $lblStat.Text="Ready."; $lblStat.ForeColor="DimGray"
$pbStat = New-Object System.Windows.Forms.ToolStripProgressBar; $pbStat.Size="400,16"
$statusStrip.Items.Add($lblStat); $statusStrip.Items.Add($pbStat)
$masterGrid.Controls.Add($statusStrip, 0, 5)

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
        if ($env:ProgramFiles) { $CommonPaths += Join-Path $env:ProgramFiles "Phoenix Server Application Manager\AppReg_Main.xml" }
        if (${env:ProgramFiles(x86)}) { $CommonPaths += Join-Path ${env:ProgramFiles(x86)} "Phoenix Server Application Manager\AppReg_Main.xml" }

        foreach($p in $CommonPaths) { if(Test-Path $p) { $FoundPath=$p; break } }
        if (-not $FoundPath) {
            $Dirs = @("ProPhoenix\Server Application Manager", "Program Files (x86)\ProPhoenix\Server Application Manager", "Phoenix Server Application Manager", "Program Files (x86)\Phoenix Server Application Manager")
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

# --- SYNC LOGIC (SORTED PRIORITY) ---
$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select a DB!"); return }
    if (!$Script:DBSyncRoot) { [System.Windows.Forms.MessageBox]::Show("Utility Path Not Found!", "Error"); return }
    Toggle-Inputs $false
    
    # 1. BUILD LIST & ASSIGN PRIORITY
    $ProcessQueue = @()
    foreach ($item in $listDBs.CheckedItems) {
        $p = 99 # Default low priority
        $k = "Unknown"
        
        if ($item -match "Master$") { $p=1; $k="PhoenixMaster" }
        elseif ($item -match "Police$") { $p=2; $k="Police" }
        elseif ($item -match "Fire$") { $p=3; $k="Fire" }
        elseif ($item -match "IA$") { $p=4; $k="IA" }
        elseif ($item -match "CSP$") { $p=5; if ($item -like "*Fire*"){$k="FireCSP"}else{$k="PoliceCSP"} }
        elseif ($item -match "DW$") { $p=6; $k="PoliceDW" }
        
        if ($k -ne "Unknown") {
            $ProcessQueue += [PSCustomObject]@{ Name=$item; Key=$k; Priority=$p }
        } else {
            Log-Write "   Skipped $item (Unknown Type)" "Gray"
        }
    }

    # 2. SORT BY PRIORITY (1 -> 6)
    $SortedQueue = $ProcessQueue | Sort-Object Priority

    # 3. EXECUTE IN ORDER
    $totalCount = $SortedQueue.Count; $dbIndex = 0; $pbStat.Maximum = 100; $pbStat.Value = 0
    $folders = @{ Police="Police"; Fire="Fire"; IA="IA"; PhoenixMaster="Phoenix Master"; PoliceDW="Police DW"; PoliceCSP="Police CSP"; FireCSP="Fire CSP" }

    foreach ($task in $SortedQueue) {
        $db = $task.Name
        $k = $task.Key
        
        $dbIndex++; $pct = [int](($dbIndex - 1) / $totalCount * 100)
        $lblStat.Text = "Processing $dbIndex of ${totalCount}: $db ( $pct % )"; $pbStat.Value = $pct; $pbStat.Style = "Marquee"
        Log-Write "Processing: $db..." "Blue"; [System.Windows.Forms.Application]::DoEvents()
        
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