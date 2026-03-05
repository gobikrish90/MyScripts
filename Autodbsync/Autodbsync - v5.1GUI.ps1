# ======================================================================
#  ProPhoenix DB Utility Dashboard - v89.0 (Deep Search & Path Memory)
# ======================================================================
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:CredFile  = Join-Path $Script:SetupPath "SavedCreds.xml"
$Script:PathFile  = Join-Path $Script:SetupPath "SavedPath.txt" # NEW: Saves the Utility Path
# Auto-detect background image
$Script:BgImage   = Join-Path $Script:SetupPath "background.png" 
if (!(Test-Path $Script:BgImage)) { $Script:BgImage = Join-Path $Script:SetupPath "background.jpg" }
$Script:LogoFile  = Join-Path $Script:SetupPath "logo.png"

# Dynamic Variables
$Script:DBSyncRoot = $null
$Script:IsRemote = $false
$Script:TargetServer = "localhost"

# --- DETECT PATHS ---
if (!(Test-Path $Script:SetupPath)) { New-Item -ItemType Directory -Force -Path $Script:SetupPath | Out-Null }
if (!(Test-Path $Script:XmlTarget)) { 
    Set-Content -Path $Script:XmlTarget -Value '<?xml version="1.0" encoding="utf-8" ?><PnxPakager><SourceServer><IPAddress>LOCALHOST</IPAddress><DBName>DBName</DBName><UserName>sa</UserName><Password>pnx</Password><JurisID>1000</JurisID><State>MA</State><JurisName>ProPhoenix</JurisName><JurisAlias>PNX</JurisAlias><SyncType>2</SyncType></SourceServer></PnxPakager>' -Force 
}

# --- THEME: DARK MODE ---
$colBg      = [System.Drawing.Color]::Black
$colText    = [System.Drawing.Color]::WhiteSmoke
$colInputBg = [System.Drawing.Color]::FromArgb(60, 60, 60) 
$colList    = [System.Drawing.Color]::FromArgb(40, 40, 40) 

$colSrc     = [System.Drawing.Color]::FromArgb(220, 53, 69)    # Red
$colProc    = [System.Drawing.Color]::FromArgb(23, 162, 184)   # Teal
$colOut     = [System.Drawing.Color]::FromArgb(0, 123, 255)    # Blue

$btnGreen   = [System.Drawing.Color]::SeaGreen
$btnRed     = [System.Drawing.Color]::IndianRed
$btnOrange  = [System.Drawing.Color]::DarkOrange
$btnBlue    = [System.Drawing.Color]::DodgerBlue 

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

if (Test-Path $Script:BgImage) {
    try {
        $form.BackgroundImage = [System.Drawing.Image]::FromFile($Script:BgImage)
        $form.BackgroundImageLayout = "Zoom" 
    } catch { Write-Host "Error loading background image." }
}

# --- MASTER GRID LAYOUT ---
$masterGrid = New-Object System.Windows.Forms.TableLayoutPanel
$masterGrid.Dock = "Fill"
$masterGrid.BackColor = [System.Drawing.Color]::Transparent 
$masterGrid.RowCount = 6
$masterGrid.ColumnCount = 1
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 90)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 100))) 
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 25)))  
$form.Controls.Add($masterGrid)

# --- ROW 0: HEADER ---
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Fill"; $pnlHead.BackColor="Transparent"
$picLogo = New-Object System.Windows.Forms.PictureBox; $picLogo.Size="160,50"; $picLogo.Location="15,10"; $picLogo.SizeMode="Zoom"; 
if(Test-Path $Script:LogoFile){$picLogo.Image=[System.Drawing.Image]::FromFile($Script:LogoFile)}
$pnlHead.Controls.Add($picLogo)

$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="DB Sync Dashboard - Installation"; $lblTitle.AutoSize=$true; $lblTitle.Location="190,15"; $lblTitle.Font=$fontTitle; $lblTitle.ForeColor=$colProc; $pnlHead.Controls.Add($lblTitle)

# NEW: PATH INPUT & BROWSE
$lblPath = New-Object System.Windows.Forms.Label; $lblPath.Text="Utility Path:"; $lblPath.Location="750,15"; $lblPath.AutoSize=$true; $lblPath.ForeColor="Gray"; $pnlHead.Controls.Add($lblPath)
$txtPath = New-Object System.Windows.Forms.TextBox; $txtPath.Location="830,12"; $txtPath.Size="200,25"; $txtPath.BackColor=$colInputBg; $txtPath.ForeColor="White"; $txtPath.BorderStyle="FixedSingle"; $pnlHead.Controls.Add($txtPath)
$btnBrowse = New-Object System.Windows.Forms.Button; $btnBrowse.Text="Browse..."; $btnBrowse.Location="1040,12"; $btnBrowse.Size="80,25"; $btnBrowse.BackColor="DimGray"; $btnBrowse.ForeColor="White"; $btnBrowse.FlatStyle="Flat"; $pnlHead.Controls.Add($btnBrowse)

[void]$masterGrid.Controls.Add($pnlHead, 0, 0)

# --- ROW 1: ADMIN MAINTENANCE ---
$pnlAdmin = New-Object System.Windows.Forms.Panel; $pnlAdmin.Dock="Fill"; $pnlAdmin.BackColor=[System.Drawing.Color]::FromArgb(150, 40, 40, 40) 
[void]$masterGrid.Controls.Add($pnlAdmin, 0, 1)

$lblMaint = New-Object System.Windows.Forms.Label; $lblMaint.Text="Admin Maintenance:"; $lblMaint.Location="20, 25"; $lblMaint.AutoSize=$true; $lblMaint.Font=$fontHeader; $lblMaint.ForeColor="LightGray"; $lblMaint.BackColor="Transparent"
$pnlAdmin.Controls.Add($lblMaint)

$btnCreateDB = New-Object System.Windows.Forms.Button; $btnCreateDB.Text="Create New DB"; $btnCreateDB.Location="200,15"; $btnCreateDB.Size="160,40"; $btnCreateDB.BackColor=$btnBlue; $btnCreateDB.ForeColor="White"; $btnCreateDB.FlatStyle="Flat"; $pnlAdmin.Controls.Add($btnCreateDB)
$btnInstall = New-Object System.Windows.Forms.Button; $btnInstall.Text="Install Utility"; $btnInstall.Location="380,15"; $btnInstall.Size="160,40"; $btnInstall.BackColor=$btnGreen; $btnInstall.ForeColor="White"; $btnInstall.FlatStyle="Flat"; $pnlAdmin.Controls.Add($btnInstall)
$btnUninstall = New-Object System.Windows.Forms.Button; $btnUninstall.Text="Uninstall Utility"; $btnUninstall.Location="560,15"; $btnUninstall.Size="160,40"; $btnUninstall.BackColor=$btnRed; $btnUninstall.ForeColor="White"; $btnUninstall.FlatStyle="Flat"; $pnlAdmin.Controls.Add($btnUninstall)

# --- ROW 2: CONNECTION ---
$grpCon = New-Object System.Windows.Forms.GroupBox; $grpCon.Text=" 1. SQL Connection "; $grpCon.Dock="Fill"; $grpCon.ForeColor=$colSrc; $grpCon.Font=$fontHeader; $grpCon.BackColor="Transparent"
[void]$masterGrid.Controls.Add($grpCon, 0, 2)

$flowCon = New-Object System.Windows.Forms.FlowLayoutPanel; $flowCon.Dock="Fill"; $flowCon.BackColor="Transparent"
$flowCon.Padding = New-Object System.Windows.Forms.Padding(10, 15, 0, 0)
$grpCon.Controls.Add($flowCon)

function Add-FlowInput($parent, $lbl, $w, $def, $isPass=$false) {
    $p = New-Object System.Windows.Forms.Panel; $p.Size = New-Object System.Drawing.Size($w, 50); $p.BackColor="Transparent"
    $l = New-Object System.Windows.Forms.Label; $l.Text=$lbl; $l.Location="0,0"; $l.AutoSize=$true; $l.Font=$fontNorm; $l.ForeColor="White"; $p.Controls.Add($l)
    $t = New-Object System.Windows.Forms.TextBox; $t.Location="0,20"; $t.Width=($w-10); $t.Text=$def; $t.Font=$fontNorm; $t.BackColor=$colInputBg; $t.ForeColor="White"; $t.BorderStyle="FixedSingle"; if($isPass){$t.PasswordChar="*"}; $p.Controls.Add($t)
    $parent.Controls.Add($p)
    return $t
}
$txtS = Add-FlowInput $flowCon "Server IP / Name" 200 $env:COMPUTERNAME
$txtU = Add-FlowInput $flowCon "SQL Username" 150 "sa"
$txtP = Add-FlowInput $flowCon "SQL Password" 150 "" $true

$pChk = New-Object System.Windows.Forms.Panel; $pChk.Size="120,50"; $pChk.BackColor="Transparent"; $flowCon.Controls.Add($pChk)
$chkSave = New-Object System.Windows.Forms.CheckBox; $chkSave.Text="Remember"; $chkSave.Location="0,22"; $chkSave.AutoSize=$true; $chkSave.Font=$fontNorm; $chkSave.ForeColor="White"; $pChk.Controls.Add($chkSave)

$pBtn = New-Object System.Windows.Forms.Panel; $pBtn.Size="150,50"; $pBtn.BackColor="Transparent"; $flowCon.Controls.Add($pBtn)
$btnCon = New-Object System.Windows.Forms.Button; $btnCon.Text="CONNECT"; $btnCon.Location="0,15"; $btnCon.Size="130,32"; $btnCon.BackColor=$colSrc; $btnCon.ForeColor="White"; $btnCon.FlatStyle="Flat"; $btnCon.Font=$fontHeader; $pBtn.Controls.Add($btnCon)

# --- ROW 3: MAIN BODY ---
$splitGrid = New-Object System.Windows.Forms.TableLayoutPanel; $splitGrid.Dock="Fill"; $splitGrid.ColumnCount=2; $splitGrid.RowCount=1; $splitGrid.BackColor="Transparent"
$splitGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 35)))
$splitGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 65)))
[void]$masterGrid.Controls.Add($splitGrid, 0, 3)

# LEFT: LIST
$grpList = New-Object System.Windows.Forms.GroupBox; $grpList.Text=" 2. Select Targets "; $grpList.Dock="Fill"; $grpList.ForeColor=$colProc; $grpList.Font=$fontHeader; $grpList.BackColor="Transparent"
[void]$splitGrid.Controls.Add($grpList, 0, 0)

$listInner = New-Object System.Windows.Forms.TableLayoutPanel; $listInner.Dock="Fill"; $listInner.RowCount=2; $listInner.BackColor="Transparent"
$listInner.Padding = New-Object System.Windows.Forms.Padding(10, 20, 10, 10)
$listInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 30)))
$listInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
$grpList.Controls.Add($listInner)

$chkAll = New-Object System.Windows.Forms.CheckBox; $chkAll.Text="Select All Databases"; $chkAll.Dock="Fill"; $chkAll.Font=$fontNorm; $chkAll.ForeColor="White"
$listInner.Controls.Add($chkAll, 0, 0)

$listDBs = New-Object System.Windows.Forms.CheckedListBox; $listDBs.Dock="Fill"; $listDBs.BorderStyle="FixedSingle"; $listDBs.BackColor=$colList; $listDBs.ForeColor="White"; $listDBs.Font=$fontNorm; $listDBs.CheckOnClick=$true
$listInner.Controls.Add($listDBs, 0, 1)

# RIGHT: LOG
$grpLog = New-Object System.Windows.Forms.GroupBox; $grpLog.Text=" 3. Activity Log "; $grpLog.Dock="Fill"; $grpLog.ForeColor=$colOut; $grpLog.Font=$fontHeader; $grpLog.BackColor="Transparent"
[void]$splitGrid.Controls.Add($grpLog, 1, 0)

# Clear Button
$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = "Clear Log"
$btnClear.Size = New-Object System.Drawing.Size(80, 22)
$safeGrp = $grpLog | Select-Object -Last 1
$safeWidth = [int]$safeGrp.Width
$btnClear.Location = New-Object System.Drawing.Point(($safeWidth - 90), 0)
$btnClear.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$btnClear.BackColor = "DimGray"; $btnClear.ForeColor = "White"; $btnClear.FlatStyle = "Flat"
$btnClear.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$grpLog.Controls.Add($btnClear)

$txtLog = New-Object System.Windows.Forms.RichTextBox; $txtLog.Dock="Fill"; $txtLog.BorderStyle="None"; $txtLog.BackColor=$colList; $txtLog.ForeColor="LightGray"; $txtLog.Font=$fontLog; $txtLog.ReadOnly=$true; $txtLog.ScrollBars="Vertical"
$pnlLogPad = New-Object System.Windows.Forms.Panel; $pnlLogPad.Dock="Fill"; $pnlLogPad.Padding=New-Object System.Windows.Forms.Padding(10, 25, 10, 10); $pnlLogPad.BackColor="Transparent"; $grpLog.Controls.Add($pnlLogPad); $pnlLogPad.Controls.Add($txtLog)

$btnClear.Add_Click({ $txtLog.Clear(); Log-Write "Log Cleared." "Gray" })

# --- ROW 4: ACTION BUTTONS ---
$pnlAction = New-Object System.Windows.Forms.TableLayoutPanel
$pnlAction.Dock="Fill"; $pnlAction.BackColor="Transparent"; $pnlAction.ColumnCount=2; $pnlAction.RowCount=1
$pnlAction.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$pnlAction.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$pnlAction.Padding = New-Object System.Windows.Forms.Padding(50, 25, 50, 25) 
[void]$masterGrid.Controls.Add($pnlAction, 0, 4)

$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="START SYNC ➜"; $btnSync.Dock="Fill"; $btnSync.BackColor=$colProc; $btnSync.ForeColor="White"; $btnSync.Font=$fontHeader; $btnSync.FlatStyle="Flat"
$pnlAction.Controls.Add($btnSync, 0, 0)

$btnVer = New-Object System.Windows.Forms.Button; $btnVer.Text="CHECK DB VERSIONS"; $btnVer.Dock="Fill"; $btnVer.BackColor=$btnOrange; $btnVer.ForeColor="White"; $btnVer.Font=$fontHeader; $btnVer.FlatStyle="Flat"
$btnVer.Margin = New-Object System.Windows.Forms.Padding(20, 0, 0, 0) 
$pnlAction.Controls.Add($btnVer, 1, 0)

# --- ROW 5: STATUS ---
$statusStrip = New-Object System.Windows.Forms.StatusStrip; $statusStrip.BackColor=[System.Drawing.Color]::FromArgb(30,30,30); $statusStrip.Dock="Fill"
$lblStat = New-Object System.Windows.Forms.ToolStripStatusLabel; $lblStat.Text="Ready."; $lblStat.ForeColor="White"
$pbStat = New-Object System.Windows.Forms.ToolStripProgressBar; $pbStat.Size="400,16"
$statusStrip.Items.Add($lblStat); $statusStrip.Items.Add($pbStat)
[void]$masterGrid.Controls.Add($statusStrip, 0, 5)

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
    $btnCon.Enabled = $enable; $btnSync.Enabled = $enable
    $btnVer.Enabled = $enable; $btnUninstall.Enabled = $enable; $btnInstall.Enabled = $enable; $btnCreateDB.Enabled = $enable
}

function Save-Creds {
    if ($chkSave.Checked) {
        $SecurePass = $txtP.Text | ConvertTo-SecureString -AsPlainText -Force
        [PSCustomObject]@{ Server=$txtS.Text; User=$txtU.Text; Password=$SecurePass } | Export-Clixml -Path $Script:CredFile
    } else { if (Test-Path $Script:CredFile) { Remove-Item $Script:CredFile -Force } }
    
    # Also save the path!
    if ($Script:DBSyncRoot) { Set-Content -Path $Script:PathFile -Value $Script:DBSyncRoot -Force }
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
    # Load Path
    if (Test-Path $Script:PathFile) {
        $loadedPath = Get-Content $Script:PathFile -Raw
        if (Test-Path $loadedPath) {
            $Script:DBSyncRoot = $loadedPath.Trim()
            $txtPath.Text = $Script:DBSyncRoot
            Log-Write "✔ Loaded saved utility path: $Script:DBSyncRoot" "Gray"
        }
    }
}

# --- BROWSE LOGIC (DEEP SEARCH) ---
$btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    $fbd.Description = "Select a folder to search for DB Utility (e.g. C:\ or Program Files)"
    $fbd.ShowNewFolderButton = $false
    
    if ($fbd.ShowDialog() -eq "OK") {
        $selPath = $fbd.SelectedPath
        Log-Write "Scanning '$selPath' for PnxDBSync.exe..." "Cyan"
        [System.Windows.Forms.Application]::DoEvents()

        # DEEP SEARCH: Find the EXE anywhere
        $foundExe = Get-ChildItem -Path $selPath -Filter "PnxDBSync.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        
        if ($foundExe) {
            # Standard structure: ...\RootFolder\Police\PnxDBSync.exe
            # We want "RootFolder" (the Grandparent of the EXE)
            $parentFolder = Split-Path $foundExe.DirectoryName -Parent 
            
            $Script:DBSyncRoot = $parentFolder
            $txtPath.Text = $parentFolder
            Log-Write "✔ FOUND! Utility Root set to: $parentFolder" "Lime"
            Save-Creds
        } else {
            [System.Windows.Forms.MessageBox]::Show("Could not find 'PnxDBSync.exe' anywhere inside:`n$selPath", "Search Failed", 0, 48)
            Log-Write "❌ Scan failed. Utility not found in selection." "Red"
        }
    }
})

# --- NEW DB FORM HELPER ---
function Show-NewDBDialog {
    $dbForm = New-Object System.Windows.Forms.Form
    $dbForm.Text = "Create New Database"
    $dbForm.Size = New-Object System.Drawing.Size(400, 350)
    $dbForm.StartPosition = "CenterParent"
    $dbForm.BackColor = "White"
    $dbForm.FormBorderStyle = "FixedDialog"
    $dbForm.MaximizeBox = $false

    function Add-Field($lblTxt, $y, $defVal) {
        $l = New-Object System.Windows.Forms.Label; $l.Text=$lblTxt; $l.Location="20,$y"; $l.AutoSize=$true; $dbForm.Controls.Add($l)
        $t = New-Object System.Windows.Forms.TextBox; $t.Text=$defVal; $t.Location="120,$(($y-3))"; $t.Width=240; $dbForm.Controls.Add($t)
        return $t
    }

    $inDB = Add-Field "Database Name:" 30 "Police"
    $inJID = Add-Field "JurisID:" 70 "1000"
    $inState = Add-Field "State:" 110 "MA"
    $inJName = Add-Field "Juris Name:" 150 "ProPhoenix"
    $inJAlias = Add-Field "Juris Alias:" 190 "PNX"

    $btnOk = New-Object System.Windows.Forms.Button; $btnOk.Text="CREATE"; $btnOk.DialogResult="OK"; $btnOk.Location="120,250"; $btnOk.BackColor="DodgerBlue"; $btnOk.ForeColor="White"; $dbForm.Controls.Add($btnOk)
    $btnCan = New-Object System.Windows.Forms.Button; $btnCan.Text="Cancel"; $btnCan.DialogResult="Cancel"; $btnCan.Location="210,250"; $dbForm.Controls.Add($btnCan)
    $dbForm.AcceptButton = $btnOk

    if ($dbForm.ShowDialog() -eq "OK") {
        return @{ DB=$inDB.Text; JID=$inJID.Text; State=$inState.Text; JName=$inJName.Text; JAlias=$inJAlias.Text }
    }
    return $null
}

# --- CREATE DB LOGIC ---
$btnCreateDB.Add_Click({
    if ([string]::IsNullOrWhiteSpace($Script:DBSyncRoot)) { [System.Windows.Forms.MessageBox]::Show("Utility Path not set! Please Browse first.", "Error"); return }
    
    $InputData = Show-NewDBDialog
    if (!$InputData) { return }

    Toggle-Inputs $false
    Log-Write "Preparing to create database '$($InputData.DB)'..." "Cyan"

    try {
        $targetFolder = Join-Path $Script:DBSyncRoot "Police"
        if (!(Test-Path $targetFolder)) { throw "Police Utility folder not found at $targetFolder" }

        $xmlPath = Join-Path $targetFolder "PnxAutoNewDBSyn.xml"
        if (Test-Path $Script:XmlTarget) { $xmlContent = Get-Content $Script:XmlTarget -Raw } else { throw "Missing Template XML" }
        
        [xml]$x = $xmlContent
        $x.PnxPakager.SourceServer.IPAddress = $txtS.Text
        $x.PnxPakager.SourceServer.DBName = $InputData.DB
        $x.PnxPakager.SourceServer.UserName = $txtU.Text
        $x.PnxPakager.SourceServer.Password = $txtP.Text
        
        # Specifics
        $x.PnxPakager.SourceServer.JurisID = $InputData.JID
        $x.PnxPakager.SourceServer.State = $InputData.State
        $x.PnxPakager.SourceServer.JurisName = $InputData.JName
        $x.PnxPakager.SourceServer.JurisAlias = $InputData.JAlias
        $x.PnxPakager.SourceServer.SyncType = "1" # MAKE DB

        $x.Save($xmlPath)

        $Exe = Join-Path $targetFolder "PnxDBSync.exe"
        Log-Write "Launching Utility..." "Gray"
        $proc = Start-Process -FilePath $Exe -WorkingDirectory $targetFolder -PassThru
        $proc.WaitForExit()
        
        Log-Write "✔ Utility Finished. Refreshing list..." "Lime"
        $btnCon.PerformClick()

    } catch {
        Log-Write "❌ Creation Error: $($_.Exception.Message)" "Red"
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Error", 0, 16)
    } finally { Toggle-Inputs $true }
})

# --- AUTO SCAN ON LOAD ---
$form.Add_Load({ 
    Load-Creds
    if (-not $Script:DBSyncRoot) {
        Log-Write "Auto-scanning local Program Files..." "Gray"
        $Roots = @("$env:ProgramFiles", "${env:ProgramFiles(x86)}", "C:\ProPhoenix", "D:\ProPhoenix")
        foreach ($r in $Roots) {
            if (Test-Path $r) {
                $found = Get-ChildItem -Path $r -Filter "PnxDBSync.exe" -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($found) {
                    $Script:DBSyncRoot = (Split-Path (Split-Path $found.FullName -Parent) -Parent)
                    $txtPath.Text = $Script:DBSyncRoot
                    Log-Write "✔ Auto-Detected Utility: $Script:DBSyncRoot" "Lime"
                    Save-Creds
                    break
                }
            }
        }
    }
})

$chkAll.Add_CheckedChanged({ for ($i=0; $i -lt $listDBs.Items.Count; $i++) { $listDBs.SetItemChecked($i, $chkAll.Checked) } })

$btnCon.Add_Click({
    Toggle-Inputs $false; $listDBs.Items.Clear(); $lblStat.Text="Connecting..."; Log-Write "Connecting..." "White"
    try {
        $cs = "Server=$($txtS.Text);Network Library=DBMSSOCN;User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=10"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $cmd = $cn.CreateCommand(); 
        $cmd.CommandText = "SELECT Name FROM sys.databases WHERE database_id > 4 AND Name NOT IN ('master','model','msdb','tempdb', 'ReportServer', 'ReportServerTempDB') ORDER BY Name"
        $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        foreach($row in $ds.Tables[0].Rows) { [void]$listDBs.Items.Add($row.Name) }
        Log-Write "✔ SQL Connected." "Lime"; $lblStat.Text="Connected."; Save-Creds
    } catch { 
        Log-Write "❌ Error: $($_.Exception.Message)" "Red"; $lblStat.Text="Connection Failed." 
    } finally { Toggle-Inputs $true }
})

# --- SYNC LOGIC ---
$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select a DB!"); return }
    if ([string]::IsNullOrWhiteSpace($Script:DBSyncRoot)) { [System.Windows.Forms.MessageBox]::Show("Utility Path Not Set! Use Browse.", "Error"); return }
    Toggle-Inputs $false
    
    $ProcessQueue = @()
    foreach ($item in $listDBs.CheckedItems) {
        $p = 99; $k = "Unknown"
        if ($item -match "Master$") { $p=1; $k="PhoenixMaster" }
        elseif ($item -match "Police$") { $p=2; $k="Police" }
        elseif ($item -match "Fire$") { $p=3; $k="Fire" }
        elseif ($item -match "IA$") { $p=4; $k="IA" }
        elseif ($item -match "CSP$") { $p=5; if ($item -like "*Fire*"){$k="FireCSP"}else{$k="PoliceCSP"} }
        elseif ($item -match "DW$") { $p=6; $k="PoliceDW" }
        if ($k -ne "Unknown") { $ProcessQueue += [PSCustomObject]@{ Name=$item; Key=$k; Priority=$p } }
    }
    $SortedQueue = $ProcessQueue | Sort-Object Priority
    $totalCount = $SortedQueue.Count; $dbIndex = 0
    $folders = @{ Police="Police"; Fire="Fire"; IA="IA"; PhoenixMaster="Phoenix Master"; PoliceDW="Police DW"; PoliceCSP="Police CSP"; FireCSP="Fire CSP" }

    foreach ($task in $SortedQueue) {
        $db = $task.Name; $k = $task.Key
        $dbIndex++; $pct = [int](($dbIndex - 1) / $totalCount * 100)
        $lblStat.Text = "Processing $dbIndex of ${totalCount}: $db"; $pbStat.Value = $pct
        Log-Write "Processing: $db..." "Cyan"; [System.Windows.Forms.Application]::DoEvents()
        
        $targetFolder = Join-Path $Script:DBSyncRoot $folders[$k]
        
        try {
            if (!(Test-Path $targetFolder)) { Log-Write "   ❌ Missing Folder: $targetFolder" "Red"; continue }
            
            $xmlPath = Join-Path $targetFolder "PnxAutoNewDBSyn.xml"
            if (Test-Path $Script:XmlTarget) { $xmlContent = Get-Content $Script:XmlTarget -Raw } else { Log-Write "Missing Template XML" "Red"; continue }
            
            [xml]$x = $xmlContent
            $x.PnxPakager.SourceServer.IPAddress = $txtS.Text 
            $x.PnxPakager.SourceServer.DBName = $db
            $x.PnxPakager.SourceServer.UserName = $txtU.Text
            $x.PnxPakager.SourceServer.Password = $txtP.Text
            $x.PnxPakager.SourceServer.SyncType = "2" # UPGRADE DB
            $x.Save($xmlPath)

            $Exe = Join-Path $targetFolder "PnxDBSync.exe"
            $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            $proc = Start-Process -FilePath $Exe -WorkingDirectory $targetFolder -PassThru -WindowStyle Minimized
            $proc.WaitForExit()
            $stopWatch.Stop()
            
            $l = Get-ChildItem $targetFolder -Filter "DBToolLog*.txt" | Sort LastWriteTime -Desc | Select -First 1
            $status = "Failed"
            if ($l) { 
                $logContent = Get-Content $l.FullName -Raw 
                if ($logContent -match "DB Version Updated") { $status = "Success" }
            }
            if ($status -eq "Success") { Log-Write "   ✔ Success" "Lime" } else { Log-Write "   ❌ Failed" "Red" }

        } catch { Log-Write "Error: $($_.Exception.Message)" "Red" }
    }
    Log-Write "Completed." "White"; Toggle-Inputs $true; $pbStat.Value=100
})

$btnVer.Add_Click({
    Toggle-Inputs $false; $lblStat.Text="Checking Versions..."; Log-Write "Checking Versions..." "Cyan"
    try {
        $cs = "Server=$($txtS.Text);Network Library=DBMSSOCN;User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=10"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $sb = New-Object System.Text.StringBuilder; $sb.Append("DECLARE @s NVARCHAR(MAX)=''; CREATE TABLE #R(N NVARCHAR(255),V NVARCHAR(MAX)); ")
        foreach ($db in $listDBs.CheckedItems) {
            $sDB = $db.ToString().Replace("'","''"); $sb.Append(" IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$sDB') BEGIN IF EXISTS(SELECT 1 FROM [$sDB].sys.tables WHERE name='KPIDBVersion') INSERT INTO #R SELECT '$sDB', CAST(Version AS NVARCHAR(MAX)) FROM [$sDB].dbo.KPIDBVersion; ELSE INSERT INTO #R VALUES ('$sDB', 'No Table'); END ELSE INSERT INTO #R VALUES ('$sDB', 'Not Found'); ")
        }
        $sb.Append(" SELECT * FROM #R ORDER BY N; DROP TABLE #R;")
        $cmd = $cn.CreateCommand(); $cmd.CommandText = $sb.ToString(); $da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds=New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        foreach($r in $ds.Tables[0].Rows) { Log-Write "$($r.N) : $($r.V)" "White" }
    } catch { Log-Write "Error: $($_.Exception.Message)" "Red" } finally { Toggle-Inputs $true; $lblStat.Text="Ready." }
})

# --- DB UTIL EXECUTION ---
$RunAppMgrAction = {
    param($Action)
    if (!$Script:DBSyncRoot) { return }
    $AppMgrDir = Join-Path (Split-Path $Script:DBSyncRoot -Parent) "Server Application Manager" # Derive from root
    $Exe = Join-Path $AppMgrDir "PnxAppMgr.exe"; $BatFile = Join-Path $env:TEMP "ExecDBUtil.bat"
    Set-Content $BatFile "@echo off`ncd /d `"$AppMgrDir`"`n`"$Exe`" `"$Action`" `"DBUtility`"`npause" -Encoding ASCII
    Start-Process $BatFile -Verb RunAs -Wait
}

$btnUninstall.Add_Click({ Invoke-Command -ScriptBlock $RunAppMgrAction -ArgumentList "UNINSTALL" })
$btnInstall.Add_Click({ Invoke-Command -ScriptBlock $RunAppMgrAction -ArgumentList "INSTALL" })

$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()