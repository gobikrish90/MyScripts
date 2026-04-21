#Requires -RunAsAdministrator
# ======================================================================
#  ProPhoenix DB Utility Dashboard - v7.5
# ======================================================================

# --- AUTO-ELEVATE TO ADMINISTRATOR ---
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Data") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:CurrentDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }

$Script:SessionLogDir = Join-Path $Script:SetupPath "SessionLogs"
if (!(Test-Path $Script:SessionLogDir)) { New-Item -ItemType Directory -Force -Path $Script:SessionLogDir | Out-Null }
$Script:SessionLogFile = Join-Path $Script:SessionLogDir "StatusReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:CredFile  = Join-Path $Script:SetupPath "SavedCreds.xml"
$Script:DefaultBackup = "C:\RMS_Master_Backups"
if (!(Test-Path $Script:DefaultBackup)) { New-Item -ItemType Directory -Force -Path $Script:DefaultBackup | Out-Null }
$Script:FailedLogDir = Join-Path $Script:DefaultBackup "Failed_Sync_Logs"
if (!(Test-Path $Script:FailedLogDir)) { New-Item -ItemType Directory -Force -Path $Script:FailedLogDir | Out-Null }

$Script:LogoFile = Join-Path $Script:CurrentDir "logo.png"
if (-not (Test-Path $Script:LogoFile)) { $Script:LogoFile = Join-Path $Script:SetupPath "logo.png" }

$Script:BgImage = Join-Path $Script:CurrentDir "background.png"
if (-not (Test-Path $Script:BgImage)) { $Script:BgImage = Join-Path $Script:CurrentDir "background.jpg" }
if (-not (Test-Path $Script:BgImage)) { $Script:BgImage = Join-Path $Script:SetupPath "background.png" }
if (-not (Test-Path $Script:BgImage)) { $Script:BgImage = Join-Path $Script:SetupPath "background.jpg" }

$Script:TargetParams = @(13, 16, 22, 29, 36, 39, 40, 190, 203, 204, 205, 206, 207, 220, 221, 222, 231, 630, 1914, 2658)
$Script:TargetJobs = @("WDAAppDataExporter", "ReportWriterStaticDataExporter", "CADStaticDataExtractor", "Hot Sheet", "FireLiveDataExporter", "PhoenixBOTQAUploader", "KPICleaner", "FireRMSDataExporter")

if (!(Test-Path $Script:SetupPath)) { New-Item -ItemType Directory -Force -Path $Script:SetupPath | Out-Null }

# --- THEME ENGINE (MIDNIGHT OBSIDIAN) ---
$colBg        = [System.Drawing.Color]::FromArgb(10, 10, 10)    # Pure Executive Black
$colText      = [System.Drawing.Color]::FromArgb(212, 212, 216) # Silver Text
$colInputBg   = [System.Drawing.Color]::FromArgb(24, 24, 27)    # Jet Black Inputs
$colInputText = [System.Drawing.Color]::FromArgb(250, 250, 250) # Pure White Data
$colLogBg     = [System.Drawing.Color]::FromArgb(0, 0, 0)       # Void Black for Logs
$colAccent    = [System.Drawing.Color]::FromArgb(250, 204, 21)  # Premium Gold Accents
$colBorder    = [System.Drawing.Color]::FromArgb(63, 63, 70)    # Soft Charcoal Borders

# --- ENTERPRISE BUTTON GENERATOR ---
function Set-ThemeButton($btn, $baseColor) {
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = $colAccent
    $btn.BackColor = $baseColor
    $btn.FlatAppearance.MouseOverBackColor = $colAccent
    $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::White
    $btn.ForeColor = "White"
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
}

# --- FORM SETUP ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProPhoenix DB Utility Dashboard - Enterprise Edition"
$form.Size = New-Object System.Drawing.Size(1300, 950) 
$form.StartPosition = "CenterScreen"
$form.BackColor = $colBg
$form.ForeColor = $colText

if (Test-Path $Script:BgImage) { 
    $form.BackgroundImage = [System.Drawing.Image]::FromFile($Script:BgImage)
    $form.BackgroundImageLayout = "Stretch" 
} elseif (Test-Path $Script:LogoFile) {
    $form.BackgroundImage = [System.Drawing.Image]::FromFile($Script:LogoFile)
    $form.BackgroundImageLayout = "Center" 
}

# --- LAYOUT ---
$masterGrid = New-Object System.Windows.Forms.TableLayoutPanel; $masterGrid.Dock="Fill"; $masterGrid.BackColor="Transparent"; $masterGrid.RowCount=6; $masterGrid.ColumnCount=1
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 90)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 130))) 
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 25)))  
$form.Controls.Add($masterGrid)

# --- HEADER ---
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Fill"; $pnlHead.BackColor=[System.Drawing.Color]::Transparent
$picLogo = New-Object System.Windows.Forms.PictureBox; $picLogo.Size="80,50"; $picLogo.Location="15,10"; $picLogo.SizeMode="Zoom"; $picLogo.BackColor=[System.Drawing.Color]::Transparent
if(Test-Path $Script:LogoFile){$picLogo.Image=[System.Drawing.Image]::FromFile($Script:LogoFile)}
$pnlHead.Controls.Add($picLogo)

$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="DB Sync Dashboard"; $lblTitle.AutoSize=$true; $lblTitle.Location="100,15"; $lblTitle.Font=$fontTitle; $lblTitle.ForeColor=$colAccent; $pnlHead.Controls.Add($lblTitle)
$lblPath = New-Object System.Windows.Forms.Label; $lblPath.Text="Utility Path:"; $lblPath.Location="750,18"; $lblPath.AutoSize=$true; $lblPath.ForeColor=$colText; $pnlHead.Controls.Add($lblPath)
$Script:txtPath = New-Object System.Windows.Forms.TextBox; $Script:txtPath.Location="825,15"; $Script:txtPath.Size="350,25"; $Script:txtPath.BackColor=$colInputBg; $Script:txtPath.ForeColor=$colInputText; $Script:txtPath.BorderStyle="FixedSingle"; $pnlHead.Controls.Add($Script:txtPath)
$Script:btnBrowse = New-Object System.Windows.Forms.Button; $Script:btnBrowse.Text="Browse"; $Script:btnBrowse.Location="1185,14"; $Script:btnBrowse.Size="80,26"; Set-ThemeButton $Script:btnBrowse ([System.Drawing.Color]::FromArgb(100, 30, 41, 59)); $pnlHead.Controls.Add($Script:btnBrowse)
$lblVerDisplay = New-Object System.Windows.Forms.Label; $lblVerDisplay.Text="Ver: --"; $lblVerDisplay.AutoSize=$false; $lblVerDisplay.TextAlign="MiddleRight"; $lblVerDisplay.Size="300,20"; $lblVerDisplay.Location="965,42"; $lblVerDisplay.ForeColor="Gray"; $pnlHead.Controls.Add($lblVerDisplay)
[void]$masterGrid.Controls.Add($pnlHead, 0, 0)

# --- ADMIN ROW ---
$pnlAdmin = New-Object System.Windows.Forms.Panel; $pnlAdmin.Dock="Fill"; $pnlAdmin.BackColor=[System.Drawing.Color]::Transparent
[void]$masterGrid.Controls.Add($pnlAdmin, 0, 1)

$Script:btnCreateDB = New-Object System.Windows.Forms.Button; $Script:btnCreateDB.Text="Create New DB"; $Script:btnCreateDB.Location="200,15"; $Script:btnCreateDB.Size="160,40"; Set-ThemeButton $Script:btnCreateDB ([System.Drawing.Color]::FromArgb(180, 30, 144, 255)); $pnlAdmin.Controls.Add($Script:btnCreateDB)
$Script:btnInstall = New-Object System.Windows.Forms.Button; $Script:btnInstall.Text="Install Utility"; $Script:btnInstall.Location="380,15"; $Script:btnInstall.Size="160,40"; Set-ThemeButton $Script:btnInstall ([System.Drawing.Color]::FromArgb(180, 46, 139, 87)); $pnlAdmin.Controls.Add($Script:btnInstall)
$Script:btnUninstall = New-Object System.Windows.Forms.Button; $Script:btnUninstall.Text="Uninstall Utility"; $Script:btnUninstall.Location="560,15"; $Script:btnUninstall.Size="160,40"; Set-ThemeButton $Script:btnUninstall ([System.Drawing.Color]::FromArgb(180, 205, 92, 92)); $pnlAdmin.Controls.Add($Script:btnUninstall)
$Script:btnSqlMem = New-Object System.Windows.Forms.Button; $Script:btnSqlMem.Text="Config SQL RAM (75%)"; $Script:btnSqlMem.Location="740,15"; $Script:btnSqlMem.Size="180,40"; Set-ThemeButton $Script:btnSqlMem ([System.Drawing.Color]::FromArgb(180, 147, 112, 219)); $pnlAdmin.Controls.Add($Script:btnSqlMem)

# --- CONNECTION ---
$grpCon = New-Object System.Windows.Forms.GroupBox; $grpCon.Text=" SQL Connection "; $grpCon.Dock="Fill"; $grpCon.ForeColor=$colAccent; $grpCon.Font=$fontHeader; $grpCon.BackColor=[System.Drawing.Color]::Transparent
[void]$masterGrid.Controls.Add($grpCon, 0, 2)
$flowCon = New-Object System.Windows.Forms.FlowLayoutPanel; $flowCon.Dock="Fill"; $flowCon.Padding=New-Object System.Windows.Forms.Padding(10,15,0,0); $grpCon.Controls.Add($flowCon)

function Add-Input($p, $l, $w, $d, $pass=$false){ 
    $pn=New-Object System.Windows.Forms.Panel; $pn.Size=New-Object System.Drawing.Size($w,50); $pn.BackColor=[System.Drawing.Color]::Transparent
    $lb=New-Object System.Windows.Forms.Label; $lb.Text=$l; $lb.AutoSize=$true; $lb.ForeColor=$colText; $lb.Font=$fontNorm; $pn.Controls.Add($lb)
    $bx=New-Object System.Windows.Forms.TextBox; $bx.Text=$d; $bx.Location="0,20"; $bx.Width=$w-10; $bx.BackColor=$colInputBg; $bx.ForeColor=$colInputText; $bx.BorderStyle="FixedSingle"
    if($pass){$bx.PasswordChar="*"}; $pn.Controls.Add($bx); $p.Controls.Add($pn); return $bx 
}

$Script:txtS = Add-Input $flowCon "Server IP" 180 $env:COMPUTERNAME
$Script:txtU = Add-Input $flowCon "Username" 100 "sa"
$Script:txtP = Add-Input $flowCon "Password" 100 "" $true

# ENVIRONMENT SELECTOR
$pnEnv = New-Object System.Windows.Forms.Panel; $pnEnv.Size=New-Object System.Drawing.Size(100,50); $pnEnv.BackColor=[System.Drawing.Color]::Transparent
$lbEnv = New-Object System.Windows.Forms.Label; $lbEnv.Text="Environment"; $lbEnv.AutoSize=$true; $lbEnv.ForeColor=$colText; $lbEnv.Font=$fontNorm; $pnEnv.Controls.Add($lbEnv)
$Script:cmbEnv = New-Object System.Windows.Forms.ComboBox; $Script:cmbEnv.Items.AddRange(@("LIVE", "TEST", "ALL")); $Script:cmbEnv.SelectedIndex=0; $Script:cmbEnv.Location="0,20"; $Script:cmbEnv.Width=90; $Script:cmbEnv.BackColor=$colInputBg; $Script:cmbEnv.ForeColor=$colInputText; $Script:cmbEnv.DropDownStyle="DropDownList"; $Script:cmbEnv.FlatStyle="Flat"; $pnEnv.Controls.Add($Script:cmbEnv)
$flowCon.Controls.Add($pnEnv)

# SYNC TYPE SELECTOR
$pnSyncType = New-Object System.Windows.Forms.Panel; $pnSyncType.Size=New-Object System.Drawing.Size(220,50); $pnSyncType.BackColor=[System.Drawing.Color]::Transparent
$lbSyncType = New-Object System.Windows.Forms.Label; $lbSyncType.Text="Sync Mode"; $lbSyncType.AutoSize=$true; $lbSyncType.ForeColor=$colAccent; $lbSyncType.Font=$fontNorm; $pnSyncType.Controls.Add($lbSyncType)
$Script:cmbSyncType = New-Object System.Windows.Forms.ComboBox
$Script:cmbSyncType.Items.AddRange(@("1 - Make a database", "2 - Upgrade an existing database", "3 - Upgrade multiple databases"))
$Script:cmbSyncType.SelectedIndex=1
$Script:cmbSyncType.Location="0,20"; $Script:cmbSyncType.Width=210; $Script:cmbSyncType.BackColor=$colInputBg; $Script:cmbSyncType.ForeColor=$colInputText; $Script:cmbSyncType.DropDownStyle="DropDownList"; $Script:cmbSyncType.FlatStyle="Flat"
$pnSyncType.Controls.Add($Script:cmbSyncType)
$flowCon.Controls.Add($pnSyncType)

$Script:chkSave = New-Object System.Windows.Forms.CheckBox; $Script:chkSave.Text="Save"; $Script:chkSave.ForeColor=$colText; $Script:chkSave.AutoSize=$true; $Script:chkSave.Margin=New-Object System.Windows.Forms.Padding(0,25,0,0); $flowCon.Controls.Add($Script:chkSave)
$Script:chkAutoSync = New-Object System.Windows.Forms.CheckBox; $Script:chkAutoSync.Text="Auto Update DB"; $Script:chkAutoSync.ForeColor=$colAccent; $Script:chkAutoSync.AutoSize=$true; $Script:chkAutoSync.Checked=$true; $Script:chkAutoSync.Margin=New-Object System.Windows.Forms.Padding(10,25,0,0); $flowCon.Controls.Add($Script:chkAutoSync)

$Script:btnCon = New-Object System.Windows.Forms.Button; $Script:btnCon.Text="CONNECT"; $Script:btnCon.Size="110,35"; $Script:btnCon.Margin=New-Object System.Windows.Forms.Padding(15,12,0,0); Set-ThemeButton $Script:btnCon ([System.Drawing.Color]::FromArgb(180, 220, 20, 60)); $flowCon.Controls.Add($Script:btnCon)

# --- LIST & LOG ---
$split = New-Object System.Windows.Forms.TableLayoutPanel; $split.Dock="Fill"; $split.BackColor="Transparent"; $split.ColumnCount=2; $split.RowCount=1
$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 40)))
$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 60)))
[void]$masterGrid.Controls.Add($split, 0, 3)

$grpList = New-Object System.Windows.Forms.GroupBox; $grpList.Text=" Detected Targets "; $grpList.Dock="Fill"; $grpList.ForeColor=$colAccent; $grpList.Font=$fontHeader; $split.Controls.Add($grpList, 0, 0)
$pnlListInner = New-Object System.Windows.Forms.TableLayoutPanel; $pnlListInner.Dock="Fill"; $pnlListInner.RowCount=2; $pnlListInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 25))); $pnlListInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))); $grpList.Controls.Add($pnlListInner)
$chkAll = New-Object System.Windows.Forms.CheckBox; $chkAll.Text="Select All Databases"; $chkAll.ForeColor=$colText; $chkAll.AutoSize=$true; $chkAll.Margin=New-Object System.Windows.Forms.Padding(5,0,0,0); $pnlListInner.Controls.Add($chkAll, 0, 0)
$Script:listDBs = New-Object System.Windows.Forms.CheckedListBox; $Script:listDBs.Dock="Fill"; $Script:listDBs.BackColor=$colLogBg; $Script:listDBs.ForeColor=$colInputText; $Script:listDBs.BorderStyle="FixedSingle"; $Script:listDBs.Font=$fontNorm; $Script:listDBs.CheckOnClick=$true; $pnlListInner.Controls.Add($Script:listDBs, 0, 1)
$chkAll.Add_CheckedChanged({ for($i=0; $i -lt $Script:listDBs.Items.Count; $i++){ $Script:listDBs.SetItemChecked($i, $chkAll.Checked) } })

# ACTIVITY LOG WITH PADDING
$grpLog = New-Object System.Windows.Forms.GroupBox; $grpLog.Text=" Activity Log "; $grpLog.Dock="Fill"; $grpLog.ForeColor=$colAccent; $grpLog.Font=$fontHeader; $split.Controls.Add($grpLog, 1, 0)
$btnClear = New-Object System.Windows.Forms.Button; $btnClear.Text = "Clear Log"; $btnClear.Size = New-Object System.Drawing.Size(75, 23); $btnClear.Location = New-Object System.Drawing.Point(550, 15); $btnClear.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right; Set-ThemeButton $btnClear ([System.Drawing.Color]::FromArgb(100, 105, 105, 105)); $grpLog.Controls.Add($btnClear)

$pnlLogBg = New-Object System.Windows.Forms.Panel; $pnlLogBg.Dock = "Fill"; $pnlLogBg.Padding = New-Object System.Windows.Forms.Padding(8); $pnlLogBg.BackColor = [System.Drawing.Color]::Transparent; $grpLog.Controls.Add($pnlLogBg)
$Script:txtLog = New-Object System.Windows.Forms.RichTextBox; $Script:txtLog.Dock="Fill"; $Script:txtLog.BackColor=$colLogBg; $Script:txtLog.ForeColor=$colInputText; $Script:txtLog.BorderStyle="FixedSingle"; $Script:txtLog.Font=$fontLog; $pnlLogBg.Controls.Add($Script:txtLog)
$btnClear.Add_Click({ $Script:txtLog.Clear() })

# --- ACTIONS ---
$pnlAct = New-Object System.Windows.Forms.TableLayoutPanel; $pnlAct.Dock="Fill"; $pnlAct.BackColor="Transparent"; $pnlAct.ColumnCount=3; $pnlAct.RowCount=2
$pnlAct.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$pnlAct.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
for($i=0; $i -lt 3; $i++){ $pnlAct.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.33))) }
$pnlAct.Padding = New-Object System.Windows.Forms.Padding(10,5,10,5)
[void]$masterGrid.Controls.Add($pnlAct, 0, 4)

$btnMargin = New-Object System.Windows.Forms.Padding(8)

$Script:btnSync = New-Object System.Windows.Forms.Button; $Script:btnSync.Text="START SYNC PACKAGE"; $Script:btnSync.Dock="Fill"; Set-ThemeButton $Script:btnSync ([System.Drawing.Color]::FromArgb(180, 0, 191, 255)); $Script:btnSync.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnSync, 0, 0)
$Script:btnCopyDB = New-Object System.Windows.Forms.Button; $Script:btnCopyDB.Text="COPY TO TRAIN/TEST"; $Script:btnCopyDB.Dock="Fill"; Set-ThemeButton $Script:btnCopyDB ([System.Drawing.Color]::FromArgb(180, 0, 128, 128)); $Script:btnCopyDB.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnCopyDB, 1, 0)
$Script:btnVer = New-Object System.Windows.Forms.Button; $Script:btnVer.Text="CHECK VERSION"; $Script:btnVer.Dock="Fill"; Set-ThemeButton $Script:btnVer ([System.Drawing.Color]::FromArgb(180, 255, 140, 0)); $Script:btnVer.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnVer, 2, 0)
$Script:btnBackup = New-Object System.Windows.Forms.Button; $Script:btnBackup.Text="BACKUP JOBS & PARAMS"; $Script:btnBackup.Dock="Fill"; Set-ThemeButton $Script:btnBackup ([System.Drawing.Color]::FromArgb(180, 147, 112, 219)); $Script:btnBackup.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnBackup, 0, 1)
$Script:btnRestore = New-Object System.Windows.Forms.Button; $Script:btnRestore.Text="RESTORE JOBS & PARAMS"; $Script:btnRestore.Dock="Fill"; Set-ThemeButton $Script:btnRestore ([System.Drawing.Color]::FromArgb(180, 72, 61, 139)); $Script:btnRestore.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnRestore, 1, 1)
$Script:btnDeleteDB = New-Object System.Windows.Forms.Button; $Script:btnDeleteDB.Text="DELETE DATABASE"; $Script:btnDeleteDB.Dock="Fill"; Set-ThemeButton $Script:btnDeleteDB ([System.Drawing.Color]::FromArgb(180, 220, 20, 60)); $Script:btnDeleteDB.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnDeleteDB, 2, 1)

# --- STATUS ---
$stat = New-Object System.Windows.Forms.StatusStrip; $stat.BackColor=[System.Drawing.Color]::FromArgb(220, 10, 10, 10); $lblStat = New-Object System.Windows.Forms.ToolStripStatusLabel; $lblStat.Text="Ready."; $lblStat.ForeColor="White"; $stat.Items.Add($lblStat); [void]$masterGrid.Controls.Add($stat, 0, 5)

# ======================================================================
#  CORE FUNCTIONS
# ======================================================================

function Log($msg, $color="White") { 
    $mappedColor = switch ($color) {
        "Lime" { [System.Drawing.Color]::MediumSpringGreen }
        "Cyan" { [System.Drawing.Color]::DeepSkyBlue }
        "Red" { [System.Drawing.Color]::Salmon }
        "Yellow" { [System.Drawing.Color]::Gold }
        "Orange" { [System.Drawing.Color]::DarkOrange }
        "Gray" { [System.Drawing.Color]::DarkGray }
        "DarkGray" { [System.Drawing.Color]::Gray }
        "White" { [System.Drawing.Color]::WhiteSmoke }
        "IndianRed" { [System.Drawing.Color]::LightCoral }
        Default { [System.Drawing.Color]::FromName($color) }
    }

    $ts = "[$(Get-Date -Format 'HH:mm:ss')] "

    $Script:txtLog.SelectionStart = $Script:txtLog.TextLength
    $Script:txtLog.SelectionColor = [System.Drawing.Color]::Gray
    $Script:txtLog.AppendText($ts)

    $Script:txtLog.SelectionStart = $Script:txtLog.TextLength
    $Script:txtLog.SelectionColor = $mappedColor
    $Script:txtLog.AppendText("$msg`r`n")
    $Script:txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
    
    try { Add-Content -Path $Script:SessionLogFile -Value "$ts $msg" } catch {}
}

function Toggle($s) { 
    $Script:btnCon.Enabled=$s; $Script:btnSync.Enabled=$s; $Script:btnBackup.Enabled=$s; 
    $Script:btnRestore.Enabled=$s; $Script:btnVer.Enabled=$s; $Script:btnCreateDB.Enabled=$s; 
    $Script:btnCopyDB.Enabled=$s; $Script:btnDeleteDB.Enabled=$s; $Script:btnSqlMem.Enabled=$s;
    $Script:btnInstall.Enabled=$s; $Script:btnUninstall.Enabled=$s;
}

function Save-Creds {
    if ($Script:chkSave.Checked) {
        $pw = $Script:txtP.Text | ConvertTo-SecureString -AsPlainText -Force
        [PSCustomObject]@{ Server=$Script:txtS.Text; User=$Script:txtU.Text; Password=$pw } | Export-Clixml -Path $Script:CredFile
    } else { if (Test-Path $Script:CredFile) { Remove-Item $Script:CredFile -Force } }
}

function Load-Creds {
    if (Test-Path $Script:CredFile) {
        try {
            $c = Import-Clixml $Script:CredFile
            $Script:txtS.Text=$c.Server; $Script:txtU.Text=$c.User
            $Script:txtP.Text=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($c.Password))
            $Script:chkSave.Checked=$true
        } catch {}
    }
}

function Scan-Server {
    param($Target)
    $TargetClean = $Target -replace "\\",""
    $Script:IsRemote = -not ($TargetClean -match "localhost|127\.0\.0\.1|\." -or $env:COMPUTERNAME -match "^$TargetClean$" -or $TargetClean -match "^$env:COMPUTERNAME$")
    
    $FoundPath = $null
    $Result = [PSCustomObject]@{ Valid=$false; Version="Not Found"; Path=$null; InstallPath=$null }

    $CommonPaths = @(
        "ProPhoenix\Server Application Manager\AppReg_Main.xml",
        "Program Files (x86)\ProPhoenix\Server Application Manager\AppReg_Main.xml",
        "Program Files\ProPhoenix\Server Application Manager\AppReg_Main.xml"
    )

    if ($Script:IsRemote) {
        foreach ($drive in @("C$","D$","E$")) {
            foreach ($sub in $CommonPaths) {
                $p = "\\$TargetClean\$drive\$sub"
                if (Test-Path $p -ErrorAction SilentlyContinue) { $FoundPath = $p; break }
            }
            if ($FoundPath) { break }
        }
    } else {
        foreach ($d in (Get-PSDrive -PSProvider FileSystem).Root) {
            foreach ($sub in $CommonPaths) {
                $p = Join-Path $d $sub
                if (Test-Path $p -ErrorAction SilentlyContinue) { $FoundPath = $p; break }
            }
            if ($FoundPath) { break }
        }
    }

    if ($FoundPath) {
        $Result.Path = $FoundPath
        try {
            [xml]$x = Get-Content $FoundPath -ErrorAction Stop
            if ($x.PhoenixApplications.AppReg) {
                foreach ($app in $x.PhoenixApplications.AppReg) {
                    if ($app.AppPath -like "*Database Utility*" -and $app.AppPath -notlike "*CodeBook*") {
                        $v = if ($app.CurrentVersion) { $app.CurrentVersion } else { $app.Version }
                        $Result.Version = if ([string]::IsNullOrWhiteSpace($v)) { "0.0.0.0" } else { $v }
                        $Result.InstallPath = $app.AppPath; $Result.Valid = $true; break
                    }
                }
            }
        } catch { $Result.Err = "Read Error" }
    }

    if ($Result.Valid) {
        $Script:DBSyncRoot = Join-Path $Result.InstallPath "DB Sync"
        $Script:txtPath.Text = $Script:DBSyncRoot
        $lblVerDisplay.Text = "Ver: $($Result.Version)"; $lblVerDisplay.ForeColor = [System.Drawing.Color]::MediumSpringGreen
        Log "  ✔ Found DB Utility: $($Result.Version)" "Lime"
        $Script:AppMgrPath = Join-Path (Split-Path $Result.Path -Parent) "PnxAppMgr.exe"
    } else { 
        $lblVerDisplay.Text = "Not Found"; $lblVerDisplay.ForeColor = "Red"
        $Script:DBSyncRoot = $null
        if ($Script:IsRemote) {
            Log "  ⚠ Could not auto-detect remote path. Please click 'Browse' and select the DB Sync folder manually (UNC path)." "Orange"
        }
    }
}

$Script:btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select DB Sync Folder"
    if ($fbd.ShowDialog() -eq "OK") { $Script:txtPath.Text=$fbd.SelectedPath; $Script:DBSyncRoot=$fbd.SelectedPath; Log "Path Set Manually." "Gray" }
})

# --- FRONTEND ERROR MONITOR HELPER ---
function Show-SyncErrorAlert {
    param($DBName, $LogLines)
    $errForm = New-Object System.Windows.Forms.Form
    $errForm.Text = "🚨 SYNC FAILURE MONITOR : $DBName"
    $errForm.Size = New-Object System.Drawing.Size(700, 450)
    $errForm.StartPosition = "CenterScreen"
    $errForm.BackColor = [System.Drawing.Color]::FromArgb(30, 10, 10)
    $errForm.ForeColor = [System.Drawing.Color]::WhiteSmoke
    $errForm.TopMost = $true

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "CRITICAL ERROR DETECTED ON: $DBName"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::Salmon
    $lblTitle.Dock = "Top"
    $lblTitle.TextAlign = "MiddleCenter"
    $lblTitle.Height = 40
    $errForm.Controls.Add($lblTitle)

    $txtErr = New-Object System.Windows.Forms.RichTextBox
    $txtErr.Dock = "Fill"
    $txtErr.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
    $txtErr.ForeColor = [System.Drawing.Color]::LightCoral
    $txtErr.Font = New-Object System.Drawing.Font("Consolas", 10)
    $txtErr.ReadOnly = $true
    $txtErr.Text = ($LogLines -join "`r`n")
    $errForm.Controls.Add($txtErr)

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "ACKNOWLEDGE ERROR"
    $btnOk.Dock = "Bottom"
    $btnOk.Height = 45
    $btnOk.BackColor = [System.Drawing.Color]::Crimson
    $btnOk.ForeColor = [System.Drawing.Color]::White
    $btnOk.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnOk.FlatStyle = "Flat"
    $btnOk.DialogResult = "OK"
    $errForm.Controls.Add($btnOk)
    
    [void]$errForm.ShowDialog()
}

function Get-SyncErrorDetails {
    param($WorkDir)
    try {
        $logDirs = @($WorkDir, "$WorkDir\Logs", "$WorkDir\Log")
        $latestLog = Get-ChildItem -Path $logDirs -File -Include DBToolLog*.txt, sync_*.txt, *.log, *.txt -Exclude "PnxAutoNewDBSyn.xml" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if ($latestLog -and ($latestLog.LastWriteTime -ge (Get-Date).AddMinutes(-5))) {
            return Get-Content $latestLog.FullName -Tail 25 -ErrorAction SilentlyContinue
        }
        return @("No recent crash logs found in $WorkDir.", "Please check Windows Event Viewer or SQL Logs.")
    } catch { return @("Error parsing log directory.") }
}

# --- REUSABLE HELPER: KILL SESSIONS & TEMP DBS ---
$CleanAndKill = {
    param($dbTarget, $killMainDbSessions)
    try {
        $killCS = "Server=$($Script:txtS.Text);Database=master;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Connection Timeout=15"
        $killCN = New-Object System.Data.SqlClient.SqlConnection($killCS); $killCN.Open()
        $killCmd = $killCN.CreateCommand()
        
        if ($killMainDbSessions) {
            $killCmd.CommandText = "IF DB_ID('$dbTarget') IS NOT NULL BEGIN DECLARE @k1 varchar(8000) = ''; SELECT @k1 = @k1 + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$dbTarget'); EXEC(@k1); END"
            $killCmd.ExecuteNonQuery() | Out-Null
        }
        
        $tempDbName = "$dbTarget" + "PnxDBSync"
        $killCmd.CommandText = "IF DB_ID('$tempDbName') IS NOT NULL BEGIN DECLARE @k2 varchar(8000) = ''; SELECT @k2 = @k2 + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$tempDbName'); EXEC(@k2); EXEC('ALTER DATABASE [$tempDbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$tempDbName];'); END"
        $killCmd.ExecuteNonQuery() | Out-Null
        
        $killCN.Close()
    } catch {}
}

# --- REUSABLE HELPER: EXTRACT CRASH LOGS ---
function Extract-SyncLog {
    param($WorkDir)
    try {
        $logDirs = @($WorkDir)
        if (Test-Path "$WorkDir\Logs") { $logDirs += "$WorkDir\Logs" }
        if (Test-Path "$WorkDir\Log") { $logDirs += "$WorkDir\Log" }

        $latestLog = Get-ChildItem -Path $logDirs -File -Include DBToolLog*.txt, sync_*.txt, *.log, *.txt -Exclude "PnxAutoNewDBSyn.xml" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if ($latestLog -and ($latestLog.LastWriteTime -ge (Get-Date).AddMinutes(-5))) {
            Log "   📄 Extracted Crash Log -> $($latestLog.Name):" "Yellow"
            $errContent = Get-Content $latestLog.FullName -Tail 20 -ErrorAction SilentlyContinue
            if ($errContent) {
                foreach ($line in $errContent) {
                    if (-not [string]::IsNullOrWhiteSpace($line)) { Log "      $line" "IndianRed" }
                }
            } else {
                Log "      [Log file is empty]" "Gray"
            }
        } else {
            Log "   ! No recent crash log files found in $WorkDir" "Gray"
        }
    } catch {
        Log "   ! Could not parse log directory." "Gray"
    }
}

# --- REUSABLE SYNC FUNCTION ---
function Execute-DBSync {
    param($RawItems)
    
    try {
        if ($RawItems.Count -eq 0) { return }
        
        $safeItems = @()
        foreach ($i in $RawItems) { $safeItems += $i }
        
        $FailedDBs = @()
        $syncMode = $Script:cmbSyncType.SelectedItem.Substring(0,1)
        $wshell = New-Object -ComObject wscript.shell

        # -------------------------------------------------------------
        # SYNCTYPE 3: BATCH / MULTIPLE DB EXECUTION
        # -------------------------------------------------------------
        if ($syncMode -eq "3") {
            Log "▶ BATCH SYNC INITIATED (SyncType 3)" "Cyan"
            
            $groupedDBs = @{}
            foreach ($i in $safeItems) {
                $I = $Script:TargetMap[$i]; $D = $I.DB; $F = $I.Folder
                if ($F -eq "None") { Log "   ! Skipped $($D): No Utility Folder Mapped" "Orange"; continue }
                if (-not $groupedDBs.ContainsKey($F)) { $groupedDBs[$F] = @() }
                $groupedDBs[$F] += $D
            }

            $safeKeys = @()
            foreach ($k in $groupedDBs.Keys) { $safeKeys += $k }
            $sortedFolders = $safeKeys | Sort-Object { if ($_ -eq 'Phoenix Master') { 0 } else { 1 } }

            foreach ($F in $sortedFolders) {
                $dbList = $groupedDBs[$F] -join ";"
                $WD = "$($Script:DBSyncRoot)\$F"
                $XmlPath = "$WD\PnxAutoNewDBSyn.xml"

                Log "▶ Processing Group [$F]" "Yellow"; [System.Windows.Forms.Application]::DoEvents()
                Log "  Targets: $dbList" "White"

                if (!(Test-Path "$WD\PnxDBSync.exe")) { Log "   ! Skipped: Missing EXE in $WD" "Orange"; continue }

                foreach ($D in $groupedDBs[$F]) { & $CleanAndKill $D $true }
                Start-Sleep -Seconds 2

                if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }

                $XmlString = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
	<SourceServer>
		<IPAddress>$($Script:txtS.Text)</IPAddress> 
		<DBName>$dbList</DBName> <UserName>$($Script:txtU.Text)</UserName> 
		<Password>$($Script:txtP.Text)</Password> 
		<JurisID>1000</JurisID> <State>MA</State> <JurisName>ProPhoenix</JurisName> <JurisAlias>PNX</JurisAlias> <SyncType>3</SyncType> </SourceServer>
</PnxPakager>
"@
                [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))

                $SyncProc = Start-Process "$WD\PnxDBSync.exe" -WorkingDirectory $WD -WindowStyle Normal -PassThru
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $promptHandled = $false
                
                while (-not $SyncProc.HasExited) {
                    [System.Windows.Forms.Application]::DoEvents()
                    Start-Sleep -Milliseconds 250

                    if (-not $promptHandled -and $stopwatch.Elapsed.TotalSeconds -gt 3 -and $stopwatch.Elapsed.TotalSeconds -lt 20) {
                        try {
                            if ($wshell.AppActivate($SyncProc.Id)) {
                                Start-Sleep -Milliseconds 100
                                $wshell.SendKeys("Y")
                                Start-Sleep -Milliseconds 50
                                $wshell.SendKeys("%Y")
                                Start-Sleep -Milliseconds 50
                                $wshell.SendKeys("{ENTER}")
                                $promptHandled = $true
                                Log "   > Auto-Answered Upgrade Prompt." "DarkGray"
                            }
                        } catch {}
                    }
                }
                $stopwatch.Stop()
                
                if ($SyncProc.ExitCode -eq 0) {
                    Log "   ✔ Batch Sync Completed Successfully" "Lime"
                } else {
                    $FailedDBs += "Group: $F ($dbList)"
                    Log "   ❌ Batch Sync Process Failed! (Exit Code: $($SyncProc.ExitCode))" "Red"
                    
                    # --- FRONTEND MONITOR TRIGGER ---
                    $errorData = Get-SyncErrorDetails -WorkDir $WD
                    Log "   📄 Extracted Crash Log -> Triggering Frontend Monitor" "Yellow"
                    foreach ($line in $errorData) { if (-not [string]::IsNullOrWhiteSpace($line)) { Log "      $line" "IndianRed" } }
                    
                    Show-SyncErrorAlert -DBName "BATCH GROUP: $F" -LogLines $errorData
                }

                if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
                foreach ($D in $groupedDBs[$F]) { & $CleanAndKill $D $true }
            }
        } 
        # -------------------------------------------------------------
        # SYNCTYPE 1 OR 2: INDIVIDUAL DB EXECUTION
        # -------------------------------------------------------------
        else {
            $sortedItems = $safeItems | Sort-Object { if ($Script:TargetMap[$_].Folder -eq 'Phoenix Master') { 0 } else { 1 } }

            foreach ($i in $sortedItems) {
                $I = $Script:TargetMap[$i]; $D = $I.DB; $F = $I.Folder
                $XmlPath = "$($Script:DBSyncRoot)\$F\PnxAutoNewDBSyn.xml"

                Log "▶ EXECUTING SYNC: $($D) (SyncType $syncMode)" "Cyan"; [System.Windows.Forms.Application]::DoEvents()
                
                try {
                    if ($F -eq "None") { Log "   ! Skipped $($D): No Utility Folder Mapped" "Orange"; continue }
                    $WD = "$($Script:DBSyncRoot)\$F"
                    if (!(Test-Path "$WD\PnxDBSync.exe")) { Log "   ! Skipped: Missing EXE in $WD" "Orange"; continue }

                    # ---------------------------------------------------------
                    # THE SYNCTYPE 1 FIX: Do NOT disrupt live users
                    # ---------------------------------------------------------
                    $killMain = if ($syncMode -eq "1") { $false } else { $true }
                    if ($syncMode -eq "1") {
                        Log "   > SyncType 1: Keeping live sessions active. Dropping Temp DB only." "DarkGray"
                    } else {
                        Log "   > Cleared locks & dropped orphaned Temp databases (Exclusive Access)." "DarkGray"
                    }

                    & $CleanAndKill $D $killMain
                    Start-Sleep -Seconds 2 

                    if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }

                    $XmlString = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
	<SourceServer>
		<IPAddress>$($Script:txtS.Text)</IPAddress> 
		<DBName>$D</DBName> <UserName>$($Script:txtU.Text)</UserName> 
		<Password>$($Script:txtP.Text)</Password> 
		<JurisID>1000</JurisID> <State>MA</State> <JurisName>ProPhoenix</JurisName> <JurisAlias>PNX</JurisAlias> <SyncType>$syncMode</SyncType> </SourceServer>
</PnxPakager>
"@
                    [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))

                    $SyncProc = Start-Process "$WD\PnxDBSync.exe" -WorkingDirectory $WD -WindowStyle Normal -PassThru
                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    $promptHandled = $false

                    while (-not $SyncProc.HasExited) {
                        [System.Windows.Forms.Application]::DoEvents()
                        Start-Sleep -Milliseconds 250

                        if (-not $promptHandled -and $stopwatch.Elapsed.TotalSeconds -gt 3 -and $stopwatch.Elapsed.TotalSeconds -lt 20) {
                            try {
                                if ($wshell.AppActivate($SyncProc.Id)) {
                                    Start-Sleep -Milliseconds 100
                                    $wshell.SendKeys("Y")
                                    Start-Sleep -Milliseconds 50
                                    $wshell.SendKeys("%Y")
                                    Start-Sleep -Milliseconds 50
                                    $wshell.SendKeys("{ENTER}")
                                    $promptHandled = $true
                                    Log "   > Auto-Answered Upgrade Prompt." "DarkGray"
                                }
                            } catch {}
                        }
                    }
                    $stopwatch.Stop()
                    
                    if ($SyncProc.ExitCode -eq 0) {
                        if ($syncMode -eq "1") {
                            Log "   ✔ Sync Completed Successfully (Note: Make DB skips existing DBs)" "Lime"
                        } else {
                            Log "   ✔ Sync Completed Successfully" "Lime"
                        }
                    } else {
                        $FailedDBs += $D
                        Log "   ❌ Sync Process Failed! (Exit Code: $($SyncProc.ExitCode))" "Red"
                        
                        # --- FRONTEND MONITOR TRIGGER ---
                        $errorData = Get-SyncErrorDetails -WorkDir $WD
                        Log "   📄 Extracted Crash Log -> Triggering Frontend Monitor" "Yellow"
                        foreach ($line in $errorData) { if (-not [string]::IsNullOrWhiteSpace($line)) { Log "      $line" "IndianRed" } }
                        
                        Show-SyncErrorAlert -DBName $D -LogLines $errorData
                    }

                } catch { 
                    Log "   ❌ Exception during execution: $($_.Exception.Message)" "Red" 
                    $FailedDBs += $D
                } finally {
                    if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
                    & $CleanAndKill $D $killMain
                }
            }
        }

        if ($FailedDBs.Count -gt 0) {
            $msg = "The following databases encountered hard crashes during sync:`n`n" + ($FailedDBs -join "`n") + "`n`nCheck the Activity Log for crash details."
            [System.Windows.Forms.MessageBox]::Show($msg, "Sync Completed with Hard Errors", "OK", "Warning")
        } else {
            Log "✔ All databases processed successfully." "Lime"
        }
    } catch {
        Log "❌ CRITICAL PIPELINE ERROR: $($_.Exception.Message)" "Red"
    }
}

# --- NEW: SQL MEMORY CONFIGURATION ---
$Script:btnSqlMem.Add_Click({
    try {
        Toggle $false
        Log "▶ INITIATING SQL MEMORY CONFIGURATION (75% RULE)" "Cyan"
        Log "  Connecting to $($Script:txtS.Text)..." "Gray"
        [System.Windows.Forms.Application]::DoEvents()

        $MinMemoryMB = 1024
        $cs = "Server=$($Script:txtS.Text);User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Database=master;Connection Timeout=15"
        $conn = New-Object System.Data.SqlClient.SqlConnection($cs)
        $conn.Open()

        $checkQuery = @"
        SELECT 
            (SELECT physical_memory_kb / 1024 FROM sys.dm_os_sys_info) AS TotalRAM_MB,
            (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'min server memory (MB)') AS CurrentMin,
            (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'max server memory (MB)') AS CurrentMax
"@
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = $checkQuery
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd)
        $dt = New-Object System.Data.DataTable
        $adapter.Fill($dt) | Out-Null

        if ($dt.Rows.Count -eq 0) { throw "Could not read memory info from SQL." }

        $totalRamMB = [math]::Round($dt.Rows[0]["TotalRAM_MB"])
        $currentMin = $dt.Rows[0]["CurrentMin"]
        $currentMax = $dt.Rows[0]["CurrentMax"]

        $newMaxMB = [math]::Round($totalRamMB * 0.75)
        if ($newMaxMB -lt $MinMemoryMB) { $newMaxMB = $MinMemoryMB }

        Log "  [ANALYSIS] Total Server RAM : $totalRamMB MB" "White"
        Log "  [SETTING]  Min Memory (MB)  : $currentMin ➔ $MinMemoryMB" "Yellow"
        Log "  [SETTING]  Max Memory (MB)  : $currentMax ➔ $newMaxMB" "Yellow"

        if ($currentMin -eq $MinMemoryMB -and $currentMax -eq $newMaxMB) {
            Log "  ✔ SKIPPED: Memory values are already optimal." "Lime"
        }
        else {
            Log "  [ACTION]   Updating SQL Server Configuration..." "Cyan"
            [System.Windows.Forms.Application]::DoEvents()
            
            $updateQuery = @"
            EXEC sys.sp_configure N'show advanced options', N'1';
            RECONFIGURE WITH OVERRIDE;
            EXEC sys.sp_configure N'min server memory (MB)', $MinMemoryMB;
            EXEC sys.sp_configure N'max server memory (MB)', $newMaxMB;
            RECONFIGURE WITH OVERRIDE;
"@
            $cmd.CommandText = $updateQuery
            $cmd.ExecuteNonQuery() | Out-Null
            
            Log "  ✔ SUCCESS: Memory successfully clamped to 75% ($newMaxMB MB)." "Lime"
        }
        $conn.Close()
    } catch {
        Log "  ❌ [ERROR] Failed to configure SQL RAM: $($_.Exception.Message)" "Red"
    } finally {
        Toggle $true
    }
})

# --- CONNECT ---
$Script:btnCon.Add_Click({
    try {
        Toggle $false; $Script:listDBs.Items.Clear(); $Script:TargetMap=@{}
        
        Log "▶ INITIALIZING CONNECTION..." "Cyan"
        Log "  Session Log: $($Script:SessionLogFile)" "Gray"
        Log "  Target Environment: [$($Script:cmbEnv.SelectedItem)]" "White"
        
        $cs = "Server=$($Script:txtS.Text);User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Database=master;Connection Timeout=5"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $da = New-Object System.Data.SqlClient.SqlDataAdapter("SELECT Name FROM sys.databases WHERE database_id>4 AND Name NOT IN ('master','model','msdb','tempdb','ReportServer') ORDER BY Name", $cn)
        $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        Log "  ✔ SQL Server Connected Successfully." "Lime"; $lblStat.Text = "Connected."; Save-Creds; Scan-Server $Script:txtS.Text 

        # --- FIX: ROBUST INSTALL WAIT LOOP ---
        if ($Script:chkAutoSync.Checked -and $Script:AppMgrPath -and (Test-Path $Script:AppMgrPath)) {
            Log "  > Auto-Uninstalling old utility..." "Yellow"; [System.Windows.Forms.Application]::DoEvents()
            $Dir = Split-Path $Script:AppMgrPath -Parent
            Start-Process $Script:AppMgrPath -ArgumentList "UNINSTALL DBUtility" -WorkingDirectory $Dir -WindowStyle Hidden -Wait
            
            Start-Sleep -Seconds 2
            [System.Windows.Forms.Application]::DoEvents()

            Log "  > Auto-Installing new utility..." "Yellow"; [System.Windows.Forms.Application]::DoEvents()
            Start-Process $Script:AppMgrPath -ArgumentList "INSTALL DBUtility" -WorkingDirectory $Dir -WindowStyle Hidden -Wait
            
            Log "  > Waiting for file extraction..." "DarkGray"; [System.Windows.Forms.Application]::DoEvents()
            $waitCounter = 0
            while ($waitCounter -lt 30) {
                Start-Sleep -Seconds 2
                if (Test-Path "$($Script:DBSyncRoot)\Phoenix Master\PnxDBSync.exe") { break }
                if (Test-Path "$($Script:DBSyncRoot)\Police\PnxDBSync.exe") { break }
                $waitCounter++
                [System.Windows.Forms.Application]::DoEvents()
            }
            if ($waitCounter -ge 30) {
                Log "   ! Warning: Extraction timed out." "Orange"
            } else {
                Start-Sleep -Seconds 5
                Log "  ✔ AppMgr Refreshed & Utility Verified." "Lime"
            }
        }

        # --- CATEGORY LOGIC (UPDATED FOR 'ALL' SELECTION) ---
        $EnvMode = $Script:cmbEnv.SelectedItem

        foreach ($row in $ds.Tables[0].Rows) {
            $db = $row.Name; $Folder = $null; $Tag = ""; $Type = ""
            
            $IsTrain = ($db -match "Tr" -or $db -match "Train")
            $IsTest = ($db -match "Test" -and -not $IsTrain) 
            $IsMaster = ($db -match "Master")

            # Environment Filter
            if ($EnvMode -eq "LIVE") { 
                if ($IsTest) { continue } 
            } elseif ($EnvMode -eq "TEST") { 
                if (-not $IsTest -and -not $IsMaster) { continue } 
            }

            if ($db -match "DW") { $Type = "Police DW"; $Folder = "Police DW" }
            elseif ($db -match "CSP") { 
                if($db -match "Fire") { $Type = "Fire CSP"; $Folder = "Fire CSP" } 
                else { $Type = "Police CSP"; $Folder = "Police CSP" } 
            }
            elseif ($db -match "Master") { $Type = "Phoenix Master"; $Folder = "Phoenix Master" }
            elseif ($db -match "IA") { $Type = "IA"; $Folder = "IA" }
            elseif ($db -match "Fire") { $Type = "Fire"; $Folder = "Fire" }
            elseif ($db -match "Police") { $Type = "Police"; $Folder = "Police" }
            else { $Type = "Other"; $Folder = "None" }

            $Cat = if ($IsTest) { "TEST" } elseif ($IsTrain) { "LIVE" } else { "LIVE" }

            if ($Script:DBSyncRoot -and (-not $Script:IsRemote) -and $Folder -ne "None") {
                $P1 = Join-Path $Script:DBSyncRoot $Folder; if (!(Test-Path $P1)) { $Folder = $Folder.Replace(" ", "") } 
            }

            $Key = "[$Cat - $Type] $db"
            $Script:listDBs.Items.Add($Key, $Script:chkAutoSync.Checked)
            $Script:TargetMap[$Key] = @{ DB=$db; Folder=$Folder }
        }
        if($Script:listDBs.Items.Count -gt 0){ Log "  + Listed & Grouped $($Script:listDBs.Items.Count) Databases" "Cyan" }

        if ($Script:chkAutoSync.Checked) {
            Log "▶ AUTO-UPDATE INITIATED" "Yellow"; [System.Windows.Forms.Application]::DoEvents()
            Execute-DBSync $Script:listDBs.CheckedItems
        }
    } 
    catch { Log "❌ Error: $($_.Exception.Message)" "Red" } 
    finally { Toggle $true }
})

# --- DELETE DB ---
$Script:btnDeleteDB.Add_Click({
    try {
        if($Script:listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database to Delete!", "Warning", "OK", "Warning"); return }
        $Targets = @(); foreach($i in $Script:listDBs.CheckedItems){ $Targets += $Script:TargetMap[$i].DB }
        $Names = $Targets -join ", "
        if([System.Windows.Forms.MessageBox]::Show("DELETE DATABASE(S): $Names`n`nThis will PERMANENTLY REMOVE the database and files (.mdf/.ldf).`n`nAre you absolutely sure?", "CRITICAL WARNING", "YesNo", "Error") -ne "Yes"){ return }
        if([System.Windows.Forms.MessageBox]::Show("Double Check: Delete $Names?", "Final Confirmation", "YesNo", "Error") -ne "Yes"){ return }
        
        Toggle $false; Log "▶ DELETING DATABASES..." "Red"
        
        $CS="Server=$($Script:txtS.Text);Database=master;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Connection Timeout=30"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
        foreach($DB in $Targets){
            Log "  > Dropping $DB..." "Orange"; [System.Windows.Forms.Application]::DoEvents()
            
            $KillCmd = New-Object System.Data.SqlClient.SqlCommand("IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$DB') BEGIN DECLARE @kill varchar(8000) = ''; SELECT @kill = @kill + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$DB'); EXEC(@kill); END", $CN)
            try { $KillCmd.ExecuteNonQuery()|Out-Null } catch {}

            $Cmd=$CN.CreateCommand()
            $Cmd.CommandTimeout = 0
            $Cmd.CommandText = "IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$DB') BEGIN ALTER DATABASE [$DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$DB]; END"
            $Cmd.ExecuteNonQuery()|Out-Null
            Log "  ✔ Deleted $DB" "Red"
        }
        $CN.Close(); $Script:btnCon.PerformClick()
    } 
    catch { Log "  ❌ Error: $($_.Exception.Message)" "Red" } 
    finally { Toggle $true }
})

# --- ENTERPRISE HELPER: APPLY TXT CONFIG TO A SPECIFIC DB ---
function Apply-EnterpriseConfig {
    param($TargetDB, $SourceFile)
    
    $Content = Get-Content $SourceFile
    $restoreParams = @{}
    $restoreJobs = @()
    $currentMode = "NONE"
    $currentJob = $null

    foreach ($line in $Content) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }
        
        if ($line -eq "[PARAMETERS]") { $currentMode = "PARAMS"; continue }
        if ($line -match "^\[JOB:(.+)\]$") { 
            $currentMode = "JOB"
            if ($currentJob -ne $null) { $restoreJobs += $currentJob }
            $currentJob = @{ Name = $Matches[1]; Type = $null; Params = @(); Notifies = @() }
            continue 
        }

        if ($currentMode -eq "PARAMS") {
            $parts = $line -split "=", 2
            if ($parts.Count -eq 2) { $restoreParams[$parts[0].Trim()] = $parts[1].Trim() }
        }
        elseif ($currentMode -eq "JOB" -and $currentJob -ne $null) {
            $parts = $line -split "=", 2
            if ($parts.Count -eq 2) {
                $k = $parts[0].Trim(); $v = $parts[1].Trim()
                if ($k -eq "JobType") { $currentJob.Type = $v }
                elseif ($k -match "^Param:(.+)$") { $currentJob.Params += @{ Name = $Matches[1]; Value = $v } }
                elseif ($k -eq "NotifyPath") { $currentJob.Notifies += $v }
            }
        }
    }
    if ($currentJob -ne $null) { $restoreJobs += $currentJob }

    try {
        $CS="Server=$($Script:txtS.Text);Database=$TargetDB;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Connection Timeout=15"; $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
        
        $pUpdated = 0; $pInserted = 0; $pSkipped = 0
        foreach ($paramID in $restoreParams.Keys) {
            $paramVal = $restoreParams[$paramID].Replace("'", "''")
            $upsertQuery = @"
            SET NOCOUNT ON;
            DECLARE @tID INT = $paramID;
            DECLARE @tVal NVARCHAR(MAX) = '$paramVal';

            IF EXISTS (SELECT 1 FROM Parameter WHERE CAST(ParamID AS VARCHAR(50)) = CAST(@tID AS VARCHAR(50)))
            BEGIN
                UPDATE Parameter SET ParamValue = @tVal WHERE CAST(ParamID AS VARCHAR(50)) = CAST(@tID AS VARCHAR(50));
                SELECT 'Updated' AS Action;
            END
            ELSE
            BEGIN
                IF OBJECT_ID('dbo.ParameterName', 'U') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ParameterName WHERE CAST(ParamID AS VARCHAR(50)) = CAST(@tID AS VARCHAR(50)))
                BEGIN
                    SELECT 'Skipped_FK' AS Action;
                END
                ELSE
                BEGIN
                    DECLARE @nextSLNo BIGINT;
                    SELECT @nextSLNo = ISNULL(MAX(CAST(SLNo AS BIGINT)), 0) + 1 FROM Parameter WITH (UPDLOCK, HOLDLOCK);
                    DECLARE @sysJurisID INT;
                    SELECT TOP 1 @sysJurisID = JurisID FROM Parameter WHERE JurisID IS NOT NULL;
                    SET @sysJurisID = ISNULL(@sysJurisID, 0);
                    INSERT INTO Parameter (SLNo, ParamID, ParamValue, JurisID) VALUES (@nextSLNo, @tID, @tVal, @sysJurisID);
                    SELECT 'Inserted' AS Action;
                END
            END
"@
            $cmd = $CN.CreateCommand()
            $cmd.CommandText = $upsertQuery
            try {
                $res = $cmd.ExecuteScalar()
                if ($res -eq 'Updated') { $pUpdated++ }
                elseif ($res -eq 'Inserted') { $pInserted++ }
                elseif ($res -eq 'Skipped_FK') { $pSkipped++ }
            } catch { }
        }
        Log "   ✔ Params: $pUpdated Updated | $pInserted Inserted | $pSkipped Skipped" "Lime"

        $jRestored = 0
        foreach ($job in $restoreJobs) {
            $jName = $job.Name.Replace("'", "''")
            $jType = if ([string]::IsNullOrWhiteSpace($job.Type)) { "JobType" } else { "'$($job.Type.Replace("'", "''"))'" }
            
            $jobQuery = @"
            DECLARE @jID BIGINT;
            SELECT TOP 1 @jID = JobID FROM KPIjobs WHERE JobName = '$jName';
            IF @jID IS NOT NULL
            BEGIN
                UPDATE KPIjobs SET IsInactive = 0, StartDttm = GETDATE(), EndDttm = '2099-12-31', NextExDttm = GETDATE(), JobType = $jType WHERE JobID = @jID;
                DELETE FROM KPIjobsparam WHERE JobID = @jID;
                DELETE FROM KPIJobsNotify WHERE JobID = @jID;
                SELECT @jID AS FoundJobID;
            END
"@
            $cmd = $CN.CreateCommand()
            $cmd.CommandText = $jobQuery
            $returnedJobID = $cmd.ExecuteScalar()

            if ($returnedJobID) {
                if ($job.Params) {
                    foreach ($jp in $job.Params) {
                        $pName = $jp.Name.Replace("'", "''")
                        $pVal = $jp.Value.Replace("'", "''")
                        $cmd.CommandText = "INSERT INTO KPIjobsparam(JobID, SeqNo, ParamName, ParamValue) SELECT $returnedJobID, ISNULL(MAX(SeqNo),0)+1, '$pName', '$pVal' FROM KPIjobsparam WHERE JobID = $returnedJobID"
                        $cmd.ExecuteNonQuery() | Out-Null
                    }
                }
                if ($job.Notifies) {
                    foreach ($folder in $job.Notifies) {
                        $fSafe = $folder.Replace("'", "''")
                        $cmd.CommandText = "INSERT INTO KPIJobsNotify SELECT $returnedJobID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIJobsNotify WHERE JobID = j.JobID), NULL, NULL, '$fSafe', 1, NULL, NULL, NULL, NULL FROM KPIJobs j WHERE JobID = $returnedJobID"
                        $cmd.ExecuteNonQuery() | Out-Null
                    }
                }
                $jRestored++
            }
        }
        Log "   ✔ Jobs: $jRestored Configured Successfully (Old Details Replaced)" "Lime"
        $CN.Close()
    } catch { Log "   ❌ Config Apply Failed: $($_.Exception.Message)" "Red" }
}

# --- COPY DB ---
function Show-CopyDialog {
    $d = New-Object System.Windows.Forms.Form; $d.Text="DB Copy"; $d.Size="300,150"; $d.StartPosition="CenterParent"
    $l = New-Object System.Windows.Forms.Label; $l.Text="Select Target Type:"; $l.Location="20,20"; $l.AutoSize=$true; $d.Controls.Add($l)
    $cb = New-Object System.Windows.Forms.ComboBox; $cb.Items.AddRange(@("Train (Tr)","Test (Test)")); $cb.SelectedIndex=0; $cb.Location="20,50"; $cb.Width=240; $d.Controls.Add($cb)
    $b = New-Object System.Windows.Forms.Button; $b.Text="PROCEED"; $b.DialogResult="OK"; $b.Location="80,80"; $d.Controls.Add($b); $d.AcceptButton=$b
    if($d.ShowDialog()-eq"OK"){return $cb.SelectedItem} return $null
}

function Show-InputBox { param($T,$P,$D) $f=New-Object System.Windows.Forms.Form;$f.Text=$T;$f.Size="350,150";$f.StartPosition="CenterParent";$l=New-Object System.Windows.Forms.Label;$l.Text=$P;$l.Location="10,10";$l.AutoSize=$true;$f.Controls.Add($l);$t=New-Object System.Windows.Forms.TextBox;$t.Text=$D;$t.Location="10,35";$t.Width=310;$f.Controls.Add($t);$b=New-Object System.Windows.Forms.Button;$b.Text="OK";$b.DialogResult="OK";$b.Location="120,70";$f.Controls.Add($b);$f.AcceptButton=$b;if($f.ShowDialog()-eq"OK"){return $t.Text} return $null }

$Script:btnCopyDB.Add_Click({
    try {
        if($Script:listDBs.CheckedItems.Count -ne 1){ [System.Windows.Forms.MessageBox]::Show("Select exactly ONE source database.", "Warning", "OK", "Warning"); return }
        $SourceDB = $Script:TargetMap[$Script:listDBs.CheckedItems[0]].DB
        $TypeSel = Show-CopyDialog; if(!$TypeSel){return}
        $Tag = if($TypeSel -match "Train"){"Tr"}else{"Test"}
        $DefName = if($SourceDB -match "^Phoenix") { $SourceDB.Replace("Phoenix", "Phoenix$Tag") } else { "$($SourceDB)_$Tag" }
        $TargetDB = Show-InputBox "Target Name" "Confirm Target Database Name:" $DefName
        if ([string]::IsNullOrWhiteSpace($TargetDB)) { return }

        $applyConfig = [System.Windows.Forms.MessageBox]::Show("Do you want to apply an Enterprise Configuration Backup (.txt) to the newly copied database ($TargetDB)?`n`nIf Yes, you will be prompted to select the .txt file.", "Apply Configuration?", "YesNo", "Question")
        $ConfigFilePath = $null
        if ($applyConfig -eq "Yes") {
            $f = New-Object System.Windows.Forms.OpenFileDialog
            $f.Filter = "Text Backup (*.txt)|*.txt"
            $f.Title = "Select Enterprise Config Backup to Apply"
            $f.InitialDirectory = $Script:DefaultBackup
            if ($f.ShowDialog() -eq "OK") { $ConfigFilePath = $f.FileName }
        }

        Toggle $false; Log "▶ COPYING DATABASE: $SourceDB..." "Cyan"
        
        $CS="Server=$($Script:txtS.Text);Database=master;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Connection Timeout=30"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS)
        
        $CN.FireInfoMessageEventOnUserErrors = $true
        $CN.add_InfoMessage({ param($sender, $e) if ($e.Message -match "percent processed" -or $e.Message -match "processed.") { Log "   > $($e.Message)" "DarkGray" } })
        $CN.Open()
        
        $Cmd=$CN.CreateCommand()
        $Cmd.CommandTimeout = 0
        $Cmd.CommandText="SELECT CAST(SUM(size)*8/1024 AS VARCHAR) FROM sys.master_files WHERE database_id=DB_ID('$SourceDB')"; $SizeMB=$Cmd.ExecuteScalar()
        $Cmd.CommandText="SELECT physical_name FROM sys.master_files WHERE database_id=DB_ID('$SourceDB') AND type=0"; $Mdf=$Cmd.ExecuteScalar()
        
        if([System.Windows.Forms.MessageBox]::Show("SOURCE: $SourceDB`nSIZE: $SizeMB MB`nFILE: $Mdf`n`nProceed with Backup?", "Confirm", "YesNo", "Question") -ne "Yes"){ $CN.Close(); return }
        
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select Backup Location"; $fbd.SelectedPath = $Script:DefaultBackup
        if($fbd.ShowDialog() -ne "OK"){ $CN.Close(); return }
        $BackupPath = $fbd.SelectedPath
        $BakFile = Join-Path $BackupPath "$SourceDB`_Copy.bak"

        Log "  > Backing up to $BakFile (WITH LIVE PROGRESS)..." "White"; [System.Windows.Forms.Application]::DoEvents()
        $Cmd.CommandText="BACKUP DATABASE [$SourceDB] TO DISK='$BakFile' WITH COPY_ONLY, INIT, FORMAT, COMPRESSION, STATS=10"
        $Cmd.ExecuteNonQuery()|Out-Null
        Log "  ✔ Backup Complete (Compressed)" "Lime"
        
        $BkpInfo = Get-Item $BakFile; $NewSize = [math]::Round($BkpInfo.Length / 1MB, 2)
        if([System.Windows.Forms.MessageBox]::Show("Backup: $NewSize MB`nTarget: $TargetDB`n`nWARNING: Overwriting $TargetDB. Proceed?", "Confirm Restore", "YesNo", "Warning") -ne "Yes"){ $CN.Close(); return }
        
        Log "  > Setting $TargetDB to Single User..." "Orange"; [System.Windows.Forms.Application]::DoEvents()
        try { 
            $CmdDrop = New-Object System.Data.SqlClient.SqlCommand("IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$TargetDB') BEGIN DECLARE @kill varchar(8000) = ''; SELECT @kill = @kill + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$TargetDB'); EXEC(@kill); ALTER DATABASE [$TargetDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; END", $CN)
            $CmdDrop.CommandTimeout = 0
            $CmdDrop.ExecuteNonQuery()|Out-Null 
        } catch { Log "   > Notice: Could not force Single User" "DarkGray" }

        Log "  > Restoring (WITH LIVE PROGRESS)..." "White"; [System.Windows.Forms.Application]::DoEvents()
        $Cmd.CommandText="RESTORE FILELISTONLY FROM DISK='$BakFile'"; $Rdr=$Cmd.ExecuteReader(); $Files=@(); while($Rdr.Read()){$Files+=@{L=$Rdr["LogicalName"];P=$Rdr["PhysicalName"];T=$Rdr["Type"]}}; $Rdr.Close()
        
        $MoveStr = ""; foreach($f in $Files){ 
            $Ext=[System.IO.Path]::GetExtension($f.P); $Dir=[System.IO.Path]::GetDirectoryName($f.P)
            $NewName = "$TargetDB"; if ($f.T -eq "L") { $NewName += "_log" }; $NewName += $Ext
            $NewPath = Join-Path $Dir $NewName
            $MoveStr += "MOVE '$($f.L)' TO '$NewPath', " 
        }

        Log "  > Bypassing tail-log backup (uncheck status)..." "DarkGray"
        $Cmd.CommandText="RESTORE DATABASE [$TargetDB] FROM DISK='$BakFile' WITH RECOVERY, REPLACE, STATS=10, $($MoveStr.TrimEnd(', '))"
        $Cmd.ExecuteNonQuery()|Out-Null
        
        $Cmd.CommandText = "ALTER DATABASE [$TargetDB] SET MULTI_USER"; $Cmd.ExecuteNonQuery()|Out-Null
        Log "  ✔ Restore Complete" "Lime"

        if ($ConfigFilePath -and (Test-Path $ConfigFilePath)) {
            Log "▶ Applying Enterprise Configuration Backup to $TargetDB..." "Yellow"
            Apply-EnterpriseConfig -TargetDB $TargetDB -SourceFile $ConfigFilePath
        } else {
            Log "▶ Applying Default Safe Hardcoded Configuration..." "Yellow"
            $CleanCN = New-Object System.Data.SqlClient.SqlConnection("Server=$($Script:txtS.Text);Database=$TargetDB;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text)"); $CleanCN.Open()
            
            $ConfigMap = $null
            if ($SourceDB -match "Police") { $ConfigMap = $Script:PoliceJobParams }
            elseif ($SourceDB -match "Fire") { $ConfigMap = $Script:FireJobParams }
            elseif ($SourceDB -match "IA") { $ConfigMap = $Script:IAJobParams }

            if ($ConfigMap) {
                foreach ($JobName in $ConfigMap.Keys) {
                    $JData = $ConfigMap[$JobName]; $Instance = $JData["Instance"]
                    $Folders = @(); if ($JData.ContainsKey("MultiFolder")) { $Folders = $JData["MultiFolder"] } elseif ($JData.ContainsKey("Folder")) { $Folders += $JData["Folder"] }

                    $Qry = "DECLARE @jID BIGINT; SELECT TOP 1 @jID = JobID FROM KPIjobs WHERE JobName = '$JobName'; "
                    $Qry += "IF @jID IS NOT NULL BEGIN "
                    $Qry += "UPDATE KPIjobs SET IsInactive = 0, StartDttm=GETDATE(), EndDttm='2099-12-31' WHERE JobID = @jID; "
                    $Qry += "DELETE FROM KPIjobsparam WHERE JobID = @jID AND ParamName = 'Instance'; "
                    $Qry += "DELETE FROM KPIJobsNotify WHERE JobID = @jID; "
                    
                    if ($Instance) { $Qry += "INSERT INTO KPIjobsparam(JobID, SeqNo, ParamName, ParamValue) SELECT @jID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIjobsparam WHERE JobID=@jID), 'Instance', '$Instance' FROM KPIJobs j WHERE JobID=@jID; " }
                    foreach ($Fld in $Folders) { $Qry += "INSERT INTO KPIJobsNotify SELECT @jID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIJobsNotify WHERE JobID=@jID), NULL, NULL, '$Fld', 1, NULL, NULL, NULL, NULL FROM KPIJobs j WHERE JobID=@jID; " }
                    $Qry += "END;"
                    $CCmd = $CleanCN.CreateCommand(); $CCmd.CommandText = $Qry; $CCmd.ExecuteNonQuery()|Out-Null
                    Log "   + Configured: $JobName (Old Details Replaced)" "Gray"
                }
            }
            
            $DelCmd = $CleanCN.CreateCommand()
            $DelCmd.CommandTimeout = 0
            $DelCmd.CommandText = "IF OBJECT_ID('CADScheduleUnit') IS NOT NULL DELETE FROM CADScheduleUnit; IF OBJECT_ID('CADSchedule') IS NOT NULL DELETE FROM CADSchedule; UPDATE kpijobs SET IsInactive = 0;" 
            if ($SourceDB -match "Police") {
                $DelCmd.CommandText += " DELETE FROM Parameter WHERE ParamID IN (203, 204, 205, 206, 207, 1722, 1757, 609, 610, 616, 618, 659, 2010, 2011, 2012, 2013, 2018, 2019, 2023, 774, 778); DELETE FROM Parameter WHERE ParamID IN (4416, 4423, 4424, 4426, 4439, 4447, 4454, 4455, 4456, 4460, 4626, 4702, 4703, 222); IF OBJECT_ID('ParameterName') IS NOT NULL UPDATE ParameterName SET DefaultValue = NULL WHERE ParamID = 295;"
            } elseif ($SourceDB -match "Fire") {
                $DelCmd.CommandText += " DELETE FROM Parameter WHERE ParamID IN (203, 204, 205, 206, 207, 221); IF OBJECT_ID('ParameterName') IS NOT NULL UPDATE ParameterName SET DefaultValue = NULL WHERE ParamID = 295;"
            }
            $DelCmd.ExecuteNonQuery()|Out-Null
            Log "  ✔ Final Default Cleanup Done" "Lime"
            $CleanCN.Close()
        }
        
        $CN.Close(); $Script:btnCon.PerformClick()
    } 
    catch { Log "  ❌ Failed: $($_.Exception.Message)" "Red" } 
    finally { Toggle $true }
})

# --- ENTERPRISE BACKUP PARAMS ---
$Script:btnBackup.Add_Click({
    try {
        if($Script:listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select DBs to Backup!", "Warning", "OK", "Warning"); return }
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select Folder to Save Backups"; $fbd.SelectedPath = $Script:DefaultBackup
        if($fbd.ShowDialog() -ne "OK"){ return }
        $TargetDirBase = $fbd.SelectedPath

        Toggle $false; Log "▶ STARTING CONFIGURATION BACKUP..." "Cyan"; $TS=Get-Date -Format "yyyyMMdd_HHmm"

        foreach ($item in $Script:listDBs.CheckedItems) {
            $DB = $Script:TargetMap[$item].DB
            Log "  > Backing up Configuration for $DB..." "White"; [System.Windows.Forms.Application]::DoEvents()
            
            $BackupLines = New-Object System.Collections.Generic.List[String]
            $BackupLines.Add("# ProPhoenix Database Configuration Backup")
            $BackupLines.Add("# Database: $DB")
            $BackupLines.Add("# Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
            $BackupLines.Add("")
            
            $CS="Server=$($Script:txtS.Text);Database=$DB;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Connection Timeout=15"
            $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
            
            # --- Parameters Export ---
            $paramList = $Script:TargetParams -join ","
            $cmd = $CN.CreateCommand()
            $cmd.CommandText = "SELECT ParamID, CAST(ParamValue AS NVARCHAR(MAX)) AS ParamValue FROM Parameter WHERE CAST(ParamID AS VARCHAR(50)) IN ($paramList)"
            $reader = $cmd.ExecuteReader()
            
            $BackupLines.Add("[PARAMETERS]")
            $paramCount = 0
            while ($reader.Read()) {
                $paramID = $reader.GetValue(0)
                $paramVal = if ($reader.IsDBNull(1)) { "" } else { $reader.GetString(1) }
                $BackupLines.Add("$paramID=$paramVal")
                $paramCount++
            }
            $reader.Close()
            Log "    + Exported $paramCount Parameters" "Lime"
            $BackupLines.Add("")

            # --- Jobs Export ---
            $jobList = "'" + ($Script:TargetJobs -join "','") + "'"
            $cmd.CommandText = "SELECT JobID, JobName, JobType FROM KPIjobs WHERE JobName IN ($jobList)"
            $jobReader = $cmd.ExecuteReader()
            
            $tempJobs = @()
            while ($jobReader.Read()) {
                $jID = $jobReader.GetValue(0)
                $jName = if ($jobReader.IsDBNull(1)) { "UNKNOWN" } else { $jobReader.GetString(1) }
                $jType = if ($jobReader.IsDBNull(2)) { "" } else { $jobReader.GetString(2) }
                $tempJobs += @{ ID = $jID; Name = $jName; Type = $jType }
            }
            $jobReader.Close()

            foreach ($job in $tempJobs) {
                $BackupLines.Add("[JOB:$($job.Name)]")
                if ($job.Type -ne "") { $BackupLines.Add("JobType=$($job.Type)") }

                $cmd.CommandText = "SELECT ParamName, ParamValue FROM KPIjobsparam WHERE JobID = $($job.ID)"
                $pReader = $cmd.ExecuteReader()
                while ($pReader.Read()) {
                    $pName = if ($pReader.IsDBNull(0)) { "" } else { $pReader.GetString(0) }
                    $pVal = if ($pReader.IsDBNull(1)) { "" } else { $pReader.GetString(1) }
                    $BackupLines.Add("Param:$pName=$pVal")
                }
                $pReader.Close()

                $cmd.CommandText = "SELECT * FROM KPIJobsNotify WHERE JobID = $($job.ID)"
                $nReader = $cmd.ExecuteReader()
                while ($nReader.Read()) {
                    $pathVal = if ($nReader.IsDBNull(4)) { $null } else { $nReader.GetString(4) }
                    if (![string]::IsNullOrWhiteSpace($pathVal)) {
                        $BackupLines.Add("NotifyPath=$pathVal")
                    }
                }
                $nReader.Close()
                $BackupLines.Add("")
            }
            Log "    + Exported $($tempJobs.Count) KPI Jobs" "Lime"
            
            $SavePath = Join-Path $TargetDirBase "$($DB)_ConfigBackup_$TS.txt"
            [IO.File]::WriteAllLines($SavePath, $BackupLines)
            Log "  ✔ Saved to $(Split-Path $SavePath -Leaf)" "Yellow"
            
            $CN.Close()
        }
        Log "✔ Backup Complete." "Cyan"
    }
    catch { Log "  ❌ Failed: $($_.Exception.Message)" "Red" }
    finally { Toggle $true }
})

# --- ENTERPRISE RESTORE PARAMS ---
$Script:btnRestore.Add_Click({
    try {
        if($Script:listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select DBs to Restore!", "Warning", "OK", "Warning"); return }
        $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Filter="Text Backup (*.txt)|*.txt"; $f.InitialDirectory=$Script:DefaultBackup; 
        if($f.ShowDialog()-ne"OK"){return}; $SourceFile=$f.FileName
        
        if([System.Windows.Forms.MessageBox]::Show("RESTORE Configuration from:`n$SourceFile`n`nAre you absolutely sure?", "Confirm", "YesNo", "Warning") -ne "Yes"){ return }
        
        Toggle $false; Log "▶ PARSING CONFIGURATION FILE..." "Orange"; [System.Windows.Forms.Application]::DoEvents()
        
        foreach ($item in $Script:listDBs.CheckedItems) {
            $DB=$Script:TargetMap[$item].DB; Log "  > Restoring Config to $DB..." "White"; [System.Windows.Forms.Application]::DoEvents()
            Apply-EnterpriseConfig -TargetDB $DB -SourceFile $SourceFile
        }
        Log "✔ Restore Process Complete." "Cyan"
    }
    catch { Log "  ❌ Error: $($_.Exception.Message)" "Red" } 
    finally { Toggle $true }
})

# --- SYNC BUTTON LOGIC ---
$Script:btnSync.Add_Click({ 
    try {
        if($Script:listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database(s) to Sync!", "Warning", "OK", "Warning"); return }
        Toggle $false; Execute-DBSync $Script:listDBs.CheckedItems; 
    } 
    catch { Log "❌ Error: $($_.Exception.Message)" "Red" }
    finally { Toggle $true } 
})

# --- VER & INSTALL ---
$Script:btnVer.Add_Click({ 
    try {
        if($Script:listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database(s) first!", "Warning", "OK", "Warning"); return }
        Toggle $false; Log "▶ CHECKING VERSIONS..." "Cyan"; Scan-Server $Script:txtS.Text; 
        $cn=New-Object System.Data.SqlClient.SqlConnection("Server=$($Script:txtS.Text);User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Database=master"); $cn.Open(); 
        foreach($i in $Script:listDBs.CheckedItems){ $D=$Script:TargetMap[$i].DB; $cmd=$cn.CreateCommand(); $cmd.CommandText="SELECT Version FROM [$D].dbo.KPIDBVersion"; try{ $v=$cmd.ExecuteScalar(); Log "  $D : $v" "White" }catch{Log "  $D : Error" "Red"} }; 
        $cn.Close() 
    } catch {} finally { Toggle $true } 
})

$RunAppMgr = { param($Mode)
    if ([string]::IsNullOrWhiteSpace($Script:AppMgrPath) -or !(Test-Path $Script:AppMgrPath)) {
        if ($Script:txtPath.Text -and (Test-Path $Script:txtPath.Text)) { $Script:AppMgrPath = Join-Path (Split-Path $Script:txtPath.Text -Parent) "PnxAppMgr.exe" }
        if (!($Script:AppMgrPath) -or !(Test-Path $Script:AppMgrPath)) {
            [System.Windows.Forms.MessageBox]::Show("Please locate PnxAppMgr.exe"); $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Filter="PnxAppMgr.exe|PnxAppMgr.exe"; if($f.ShowDialog()-eq"OK"){$Script:AppMgrPath=$f.FileName}else{return}
        }
    }
    $Bat = Join-Path $env:TEMP "PnxAction.bat"; $Dir = Split-Path $Script:AppMgrPath -Parent
    Set-Content $Bat "@echo off`ncd /d `"$Dir`"`n`"$($Script:AppMgrPath)`" `"$Mode`" `"DBUtility`"`npause"; Start-Process $Bat -Verb RunAs
}

$Script:btnCreateDB.Add_Click({ 
    try {
        if(!$Script:DBSyncRoot){return}; $d=Show-NewDBDialog; if(!$d){return}; 
        Toggle $false; Log "▶ CREATING NEW DATABASE..." "Cyan"; 
        $Folder=$d.Cat; $TargetDir=Join-Path $Script:DBSyncRoot $Folder; if(!(Test-Path $TargetDir)){$Folder=$Folder.Replace(" ","");$TargetDir=Join-Path $Script:DBSyncRoot $Folder}; 
        [xml]$x=Get-Content $Script:XmlTarget; $x.PnxPakager.SourceServer.IPAddress=$Script:txtS.Text; $x.PnxPakager.SourceServer.DBName=$d.DB; $x.PnxPakager.SourceServer.UserName=$Script:txtU.Text; $x.PnxPakager.SourceServer.Password=$Script:txtP.Text; $x.PnxPakager.SourceServer.JurisID=$d.JID; $x.PnxPakager.SourceServer.State=$d.St; $x.PnxPakager.SourceServer.JurisName=$d.Nm; $x.PnxPakager.SourceServer.JurisAlias=$d.Al; $x.PnxPakager.SourceServer.SyncType="1"; $x.Save("$TargetDir\PnxAutoNewDBSyn.xml"); 
        Start-Process "$TargetDir\PnxDBSync.exe" -WorkingDirectory $TargetDir -Verb RunAs -Wait; 
        Log "  ✔ Created" "Lime"; $Script:btnCon.PerformClick() 
    } catch {Log "  ❌ Error" "Red"} finally { Toggle $true } 
})

$Script:btnInstall.Add_Click({ & $RunAppMgr "INSTALL" }); $Script:btnUninstall.Add_Click({ & $RunAppMgr "UNINSTALL" })

# --- INIT ---
function Show-NewDBDialog { $dbForm=New-Object System.Windows.Forms.Form;$dbForm.Text="Create DB";$dbForm.Size="400,380";$dbForm.StartPosition="CenterParent";$lblC=New-Object System.Windows.Forms.Label;$lblC.Text="Category:";$lblC.Location="20,30";$dbForm.Controls.Add($lblC);$cmbCat=New-Object System.Windows.Forms.ComboBox;$cmbCat.Items.AddRange(@("Police","Fire","Phoenix Master","IA","Police CSP","Fire CSP"));$cmbCat.SelectedIndex=0;$cmbCat.Location="120,27";$cmbCat.Width=240;$dbForm.Controls.Add($cmbCat);function Add-Field($lbl,$y,$def){$l=New-Object System.Windows.Forms.Label;$l.Text=$lbl;$l.Location="20,$y";$dbForm.Controls.Add($l);$t=New-Object System.Windows.Forms.TextBox;$t.Text=$def;$t.Location="120,$($y-3)";$t.Width=240;$dbForm.Controls.Add($t);return $t};$inDB=Add-Field "Database" 70 "PhoenixPolice";$inJID=Add-Field "JurisID" 110 "1000";$inSt=Add-Field "State" 150 "MA";$inN=Add-Field "Name" 190 "ProPhoenix";$inA=Add-Field "Alias" 230 "PNX";$btn=New-Object System.Windows.Forms.Button;$btn.Text="CREATE";$btn.DialogResult="OK";$btn.Location="120,280";$dbForm.Controls.Add($btn);$dbForm.AcceptButton=$btn;if($dbForm.ShowDialog()-eq"OK"){return @{DB=$inDB.Text;JID=$inJID.Text;St=$inSt.Text;Nm=$inN.Text;Al=$inA.Text;Cat=$cmbCat.SelectedItem}} return $null }
$form.Add_Load({ Load-Creds }); $form.Add_Shown({$form.Activate()}); [void]$form.ShowDialog()