#Requires -RunAsAdministrator
# ======================================================================
#  ProPhoenix DB Utility Dashboard v8.2
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

# --- THEME (ENTERPRISE MIRROR / GLASS THEME) ---
$colBg = [System.Drawing.Color]::FromArgb(15, 15, 15) 
$colText = [System.Drawing.Color]::WhiteSmoke
$colInputBg = [System.Drawing.Color]::FromArgb(25, 25, 25) 
$colGlassBtn = [System.Drawing.Color]::FromArgb(160, 30, 30, 30) 
$colBorder = [System.Drawing.Color]::FromArgb(80, 255, 255, 255) 
$fontTitle = New-Object System.Drawing.Font("Segoe UI Light", 22, [System.Drawing.FontStyle]::Regular)
$fontHeader = New-Object System.Drawing.Font("Segoe UI Semibold", 10)
$fontNorm = New-Object System.Drawing.Font("Segoe UI", 9)
$fontLog = New-Object System.Drawing.Font("Consolas", 10) 

# --- GLASS BUTTON GENERATOR ---
function Set-MirrorButton($btn, $hoverAccent) {
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 1
    $btn.FlatAppearance.BorderColor = $colBorder
    $btn.BackColor = $colGlassBtn
    $btn.FlatAppearance.MouseOverBackColor = $hoverAccent
    $btn.FlatAppearance.MouseDownBackColor = [System.Drawing.Color]::White
    $btn.ForeColor = "White"
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
}

# --- FORM SETUP ---
$Script:form = New-Object System.Windows.Forms.Form
$Script:form.Text = "ProPhoenix DB Utility Dashboard v8.2.0"
$Script:form.Size = New-Object System.Drawing.Size(1300, 980) 
$Script:form.StartPosition = "CenterScreen"
$Script:form.BackColor = $colBg
$Script:form.ForeColor = $colText

if (Test-Path $Script:BgImage) { 
    $Script:form.BackgroundImage = [System.Drawing.Image]::FromFile($Script:BgImage)
    $Script:form.BackgroundImageLayout = "Stretch" 
} elseif (Test-Path $Script:LogoFile) {
    $Script:form.BackgroundImage = [System.Drawing.Image]::FromFile($Script:LogoFile)
    $Script:form.BackgroundImageLayout = "Center" 
}

# --- LAYOUT ---
$masterGrid = New-Object System.Windows.Forms.TableLayoutPanel; $masterGrid.Dock="Fill"; $masterGrid.BackColor="Transparent"; $masterGrid.RowCount=6; $masterGrid.ColumnCount=1
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 90)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 70)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 90)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))  
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 180))) 
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 25)))  
$Script:form.Controls.Add($masterGrid)

# --- HEADER ---
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Fill"; $pnlHead.BackColor=[System.Drawing.Color]::Transparent
$picLogo = New-Object System.Windows.Forms.PictureBox; $picLogo.Size="80,50"; $picLogo.Location="15,10"; $picLogo.SizeMode="Zoom"; $picLogo.BackColor=[System.Drawing.Color]::Transparent
if(Test-Path $Script:LogoFile){$picLogo.Image=[System.Drawing.Image]::FromFile($Script:LogoFile)}
$pnlHead.Controls.Add($picLogo)

$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="ProPhoenix DB Sync Dashboard"; $lblTitle.AutoSize=$true; $lblTitle.Location="100,15"; $lblTitle.Font=$fontTitle; $lblTitle.ForeColor=[System.Drawing.Color]::DeepSkyBlue; $lblTitle.BackColor=[System.Drawing.Color]::Transparent; $pnlHead.Controls.Add($lblTitle)
$lblPath = New-Object System.Windows.Forms.Label; $lblPath.Text="Utility Path:"; $lblPath.Location="750,18"; $lblPath.AutoSize=$true; $lblPath.ForeColor="WhiteSmoke"; $lblPath.BackColor=[System.Drawing.Color]::Transparent; $pnlHead.Controls.Add($lblPath)
$Script:txtPath = New-Object System.Windows.Forms.TextBox; $Script:txtPath.Location="825,15"; $Script:txtPath.Size="350,25"; $Script:txtPath.BackColor=$colInputBg; $Script:txtPath.ForeColor="White"; $Script:txtPath.BorderStyle="FixedSingle"; $pnlHead.Controls.Add($Script:txtPath)
$Script:btnBrowse = New-Object System.Windows.Forms.Button; $Script:btnBrowse.Text="Browse"; $Script:btnBrowse.Location="1185,14"; $Script:btnBrowse.Size="80,26"; Set-MirrorButton $Script:btnBrowse ([System.Drawing.Color]::DeepSkyBlue); $pnlHead.Controls.Add($Script:btnBrowse)

$Script:lblVerDisplay = New-Object System.Windows.Forms.Label; $Script:lblVerDisplay.Text="DB Ver: --"; $Script:lblVerDisplay.AutoSize=$false; $Script:lblVerDisplay.TextAlign="MiddleRight"; $Script:lblVerDisplay.Size="300,20"; $Script:lblVerDisplay.Location="965,38"; $Script:lblVerDisplay.ForeColor="LightGray"; $Script:lblVerDisplay.BackColor=[System.Drawing.Color]::Transparent; $pnlHead.Controls.Add($Script:lblVerDisplay)
$Script:lblCBVerDisplay = New-Object System.Windows.Forms.Label; $Script:lblCBVerDisplay.Text="CB Ver: --"; $Script:lblCBVerDisplay.AutoSize=$false; $Script:lblCBVerDisplay.TextAlign="MiddleRight"; $Script:lblCBVerDisplay.Size="300,20"; $Script:lblCBVerDisplay.Location="965,60"; $Script:lblCBVerDisplay.ForeColor="LightGray"; $Script:lblCBVerDisplay.BackColor=[System.Drawing.Color]::Transparent; $pnlHead.Controls.Add($Script:lblCBVerDisplay)
[void]$masterGrid.Controls.Add($pnlHead, 0, 0)

# --- ADMIN ROW ---
$pnlAdmin = New-Object System.Windows.Forms.Panel; $pnlAdmin.Dock="Fill"; $pnlAdmin.BackColor=[System.Drawing.Color]::Transparent
[void]$masterGrid.Controls.Add($pnlAdmin, 0, 1)

$Script:btnCreateDB = New-Object System.Windows.Forms.Button; $Script:btnCreateDB.Text="Create New DB"; $Script:btnCreateDB.Location="200,15"; $Script:btnCreateDB.Size="160,40"; Set-MirrorButton $Script:btnCreateDB ([System.Drawing.Color]::DodgerBlue); $pnlAdmin.Controls.Add($Script:btnCreateDB)
$Script:btnInstall = New-Object System.Windows.Forms.Button; $Script:btnInstall.Text="Install Utility"; $Script:btnInstall.Location="380,15"; $Script:btnInstall.Size="160,40"; Set-MirrorButton $Script:btnInstall ([System.Drawing.Color]::SeaGreen); $pnlAdmin.Controls.Add($Script:btnInstall)
$Script:btnUninstall = New-Object System.Windows.Forms.Button; $Script:btnUninstall.Text="Uninstall Utility"; $Script:btnUninstall.Location="560,15"; $Script:btnUninstall.Size="160,40"; Set-MirrorButton $Script:btnUninstall ([System.Drawing.Color]::IndianRed); $pnlAdmin.Controls.Add($Script:btnUninstall)
$Script:btnSqlMem = New-Object System.Windows.Forms.Button; $Script:btnSqlMem.Text="SQL Memory Setting"; $Script:btnSqlMem.Location="740,15"; $Script:btnSqlMem.Size="180,40"; Set-MirrorButton $Script:btnSqlMem ([System.Drawing.Color]::MediumPurple); $pnlAdmin.Controls.Add($Script:btnSqlMem)

# --- CONNECTION ---
$grpCon = New-Object System.Windows.Forms.GroupBox; $grpCon.Text=" SQL Connection "; $grpCon.Dock="Fill"; $grpCon.ForeColor=[System.Drawing.Color]::DeepSkyBlue; $grpCon.Font=$fontHeader; $grpCon.BackColor=[System.Drawing.Color]::Transparent
[void]$masterGrid.Controls.Add($grpCon, 0, 2)
$flowCon = New-Object System.Windows.Forms.FlowLayoutPanel; $flowCon.Dock="Fill"; $flowCon.Padding=New-Object System.Windows.Forms.Padding(10,15,0,0); $flowCon.BackColor=[System.Drawing.Color]::Transparent; $grpCon.Controls.Add($flowCon)

function Add-Input($p, $l, $w, $d, $pass=$false){ 
    $pn=New-Object System.Windows.Forms.Panel; $pn.Size=New-Object System.Drawing.Size($w,50); $pn.BackColor=[System.Drawing.Color]::Transparent
    $lb=New-Object System.Windows.Forms.Label; $lb.Text=$l; $lb.AutoSize=$true; $lb.ForeColor="WhiteSmoke"; $lb.Font=$fontNorm; $lb.BackColor=[System.Drawing.Color]::Transparent; $pn.Controls.Add($lb)
    $bx=New-Object System.Windows.Forms.TextBox; $bx.Text=$d; $bx.Location="0,20"; $bx.Width=$w-10; $bx.BackColor=$colInputBg; $bx.ForeColor="White"; $bx.BorderStyle="FixedSingle"
    if($pass){$bx.PasswordChar="*"}; $pn.Controls.Add($bx); $p.Controls.Add($pn); return $bx 
}

$Script:txtS = Add-Input $flowCon "Server IP" 180 $env:COMPUTERNAME
$Script:txtU = Add-Input $flowCon "Username" 100 "sa"
$Script:txtP = Add-Input $flowCon "Password" 100 "" $true

# ENVIRONMENT SELECTOR
$pnEnv = New-Object System.Windows.Forms.Panel; $pnEnv.Size=New-Object System.Drawing.Size(100,50); $pnEnv.BackColor=[System.Drawing.Color]::Transparent
$lbEnv = New-Object System.Windows.Forms.Label; $lbEnv.Text="Environment"; $lbEnv.AutoSize=$true; $lbEnv.ForeColor="WhiteSmoke"; $lbEnv.Font=$fontNorm; $lbEnv.BackColor=[System.Drawing.Color]::Transparent; $pnEnv.Controls.Add($lbEnv)
$Script:cmbEnv = New-Object System.Windows.Forms.ComboBox; $Script:cmbEnv.Items.AddRange(@("LIVE", "TEST", "ALL")); $Script:cmbEnv.SelectedIndex=0; $Script:cmbEnv.Location="0,20"; $Script:cmbEnv.Width=90; $Script:cmbEnv.BackColor=$colInputBg; $Script:cmbEnv.ForeColor="White"; $Script:cmbEnv.DropDownStyle="DropDownList"; $Script:cmbEnv.FlatStyle="Flat"; $pnEnv.Controls.Add($Script:cmbEnv)
$flowCon.Controls.Add($pnEnv)

# SYNC TYPE SELECTOR
$pnSyncType = New-Object System.Windows.Forms.Panel; $pnSyncType.Size=New-Object System.Drawing.Size(220,50); $pnSyncType.BackColor=[System.Drawing.Color]::Transparent
$lbSyncType = New-Object System.Windows.Forms.Label; $lbSyncType.Text="Sync Mode"; $lbSyncType.AutoSize=$true; $lbSyncType.ForeColor="Cyan"; $lbSyncType.Font=$fontNorm; $lbSyncType.BackColor=[System.Drawing.Color]::Transparent; $pnSyncType.Controls.Add($lbSyncType)
$Script:cmbSyncType = New-Object System.Windows.Forms.ComboBox
$Script:cmbSyncType.Items.AddRange(@("1 - Make a database", "2 - Update\Upgrade database", "3 - Update Multiple databases"))
$Script:cmbSyncType.SelectedIndex=1
$Script:cmbSyncType.Location="0,20"; $Script:cmbSyncType.Width=210; $Script:cmbSyncType.BackColor=$colInputBg; $Script:cmbSyncType.ForeColor="White"; $Script:cmbSyncType.DropDownStyle="DropDownList"; $Script:cmbSyncType.FlatStyle="Flat"
$pnSyncType.Controls.Add($Script:cmbSyncType)
$flowCon.Controls.Add($pnSyncType)

$Script:chkSave = New-Object System.Windows.Forms.CheckBox; $Script:chkSave.Text="Save"; $Script:chkSave.ForeColor="WhiteSmoke"; $Script:chkSave.BackColor=[System.Drawing.Color]::Transparent; $Script:chkSave.AutoSize=$true; $Script:chkSave.Margin=New-Object System.Windows.Forms.Padding(0,25,0,0); $flowCon.Controls.Add($Script:chkSave)
$Script:chkAutoSync = New-Object System.Windows.Forms.CheckBox; $Script:chkAutoSync.Text="Auto Update DB"; $Script:chkAutoSync.ForeColor="Yellow"; $Script:chkAutoSync.BackColor=[System.Drawing.Color]::Transparent; $Script:chkAutoSync.AutoSize=$true; $Script:chkAutoSync.Checked=$true; $Script:chkAutoSync.Margin=New-Object System.Windows.Forms.Padding(10,25,0,0); $flowCon.Controls.Add($Script:chkAutoSync)

$Script:btnCon = New-Object System.Windows.Forms.Button; $Script:btnCon.Text="CONNECT"; $Script:btnCon.Size="110,35"; $Script:btnCon.Margin=New-Object System.Windows.Forms.Padding(15,12,0,0); Set-MirrorButton $Script:btnCon ([System.Drawing.Color]::Crimson); $flowCon.Controls.Add($Script:btnCon)

# --- LIST & LOG ---
$split = New-Object System.Windows.Forms.TableLayoutPanel; $split.Dock="Fill"; $split.BackColor="Transparent"; $split.ColumnCount=2; $split.RowCount=1
$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 40)))
$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 60)))
[void]$masterGrid.Controls.Add($split, 0, 3)

$grpList = New-Object System.Windows.Forms.GroupBox; $grpList.Text=" Detected Targets "; $grpList.Dock="Fill"; $grpList.ForeColor=[System.Drawing.Color]::DeepSkyBlue; $grpList.Font=$fontHeader; $grpList.BackColor=[System.Drawing.Color]::Transparent; $split.Controls.Add($grpList, 0, 0)
$pnlListInner = New-Object System.Windows.Forms.TableLayoutPanel; $pnlListInner.Dock="Fill"; $pnlListInner.BackColor="Transparent"; $pnlListInner.RowCount=2; $pnlListInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 25))); $pnlListInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))); $grpList.Controls.Add($pnlListInner)
$chkAll = New-Object System.Windows.Forms.CheckBox; $chkAll.Text="Select All Databases"; $chkAll.ForeColor="WhiteSmoke"; $chkAll.BackColor=[System.Drawing.Color]::Transparent; $chkAll.AutoSize=$true; $chkAll.Margin=New-Object System.Windows.Forms.Padding(5,0,0,0); $pnlListInner.Controls.Add($chkAll, 0, 0)
$Script:listDBs = New-Object System.Windows.Forms.CheckedListBox; $Script:listDBs.Dock="Fill"; $Script:listDBs.BackColor=$colInputBg; $Script:listDBs.ForeColor="White"; $Script:listDBs.BorderStyle="FixedSingle"; $Script:listDBs.Font=$fontNorm; $Script:listDBs.CheckOnClick=$true; $pnlListInner.Controls.Add($Script:listDBs, 0, 1)
$chkAll.Add_CheckedChanged({ for($i=0; $i -lt $Script:listDBs.Items.Count; $i++){ $Script:listDBs.SetItemChecked($i, $chkAll.Checked) } })

# ACTIVITY LOG WITH PADDING
$grpLog = New-Object System.Windows.Forms.GroupBox; $grpLog.Text=" Activity Log "; $grpLog.Dock="Fill"; $grpLog.ForeColor=[System.Drawing.Color]::MediumSpringGreen; $grpLog.Font=$fontHeader; $grpLog.BackColor=[System.Drawing.Color]::Transparent; $split.Controls.Add($grpLog, 1, 0)
$btnClear = New-Object System.Windows.Forms.Button; $btnClear.Text = "Clear Log"; $btnClear.Size = New-Object System.Drawing.Size(75, 23); $btnClear.Location = New-Object System.Drawing.Point(550, 15); $btnClear.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right; Set-MirrorButton $btnClear ([System.Drawing.Color]::Gray); $grpLog.Controls.Add($btnClear)

$pnlLogBg = New-Object System.Windows.Forms.Panel
$pnlLogBg.Dock = "Fill"
$pnlLogBg.Padding = New-Object System.Windows.Forms.Padding(5)
$pnlLogBg.BackColor = [System.Drawing.Color]::Transparent
$grpLog.Controls.Add($pnlLogBg)

$Script:txtLog = New-Object System.Windows.Forms.RichTextBox
$Script:txtLog.Dock="Fill"
$Script:txtLog.BackColor=$colInputBg
$Script:txtLog.ForeColor="LightGray"
$Script:txtLog.BorderStyle="FixedSingle"
$Script:txtLog.Font=$fontLog
$pnlLogBg.Controls.Add($Script:txtLog)
$btnClear.Add_Click({ $Script:txtLog.Clear() })

# --- ACTIONS (3 ROWS COMPLETELY RESTORED) ---
$pnlAct = New-Object System.Windows.Forms.TableLayoutPanel; $pnlAct.Dock="Fill"; $pnlAct.BackColor="Transparent"; $pnlAct.ColumnCount=3; $pnlAct.RowCount=3
$pnlAct.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 33.33)))
$pnlAct.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 33.33)))
$pnlAct.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 33.33)))
for($i=0; $i -lt 3; $i++){ $pnlAct.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.33))) }
$pnlAct.Padding = New-Object System.Windows.Forms.Padding(10,5,10,5)
[void]$masterGrid.Controls.Add($pnlAct, 0, 4)

$btnMargin = New-Object System.Windows.Forms.Padding(8)

$Script:btnSync = New-Object System.Windows.Forms.Button; $Script:btnSync.Text="START DB SYNC"; $Script:btnSync.Dock="Fill"; Set-MirrorButton $Script:btnSync ([System.Drawing.Color]::DeepSkyBlue); $Script:btnSync.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnSync, 0, 0)
$Script:btnCopyDB = New-Object System.Windows.Forms.Button; $Script:btnCopyDB.Text="LIVE TO TRAIN/TEST"; $Script:btnCopyDB.Dock="Fill"; Set-MirrorButton $Script:btnCopyDB ([System.Drawing.Color]::Teal); $Script:btnCopyDB.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnCopyDB, 1, 0)
$Script:btnVer = New-Object System.Windows.Forms.Button; $Script:btnVer.Text="CHECK VERSION"; $Script:btnVer.Dock="Fill"; Set-MirrorButton $Script:btnVer ([System.Drawing.Color]::DarkOrange); $Script:btnVer.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnVer, 2, 0)

$Script:btnBackup = New-Object System.Windows.Forms.Button; $Script:btnBackup.Text="BACKUP JOBS & PARAMS"; $Script:btnBackup.Dock="Fill"; Set-MirrorButton $Script:btnBackup ([System.Drawing.Color]::MediumPurple); $Script:btnBackup.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnBackup, 0, 1)
$Script:btnRestore = New-Object System.Windows.Forms.Button; $Script:btnRestore.Text="RESTORE JOBS & PARAMS"; $Script:btnRestore.Dock="Fill"; Set-MirrorButton $Script:btnRestore ([System.Drawing.Color]::MediumSlateBlue); $Script:btnRestore.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnRestore, 1, 1)
$Script:btnDeleteDB = New-Object System.Windows.Forms.Button; $Script:btnDeleteDB.Text="DELETE DATABASE"; $Script:btnDeleteDB.Dock="Fill"; Set-MirrorButton $Script:btnDeleteDB ([System.Drawing.Color]::Crimson); $Script:btnDeleteDB.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnDeleteDB, 2, 1)

$Script:btnCodebook = New-Object System.Windows.Forms.Button; $Script:btnCodebook.Text="SYNC CODEBOOK (FIRE)"; $Script:btnCodebook.Dock="Fill"; Set-MirrorButton $Script:btnCodebook ([System.Drawing.Color]::Crimson); $Script:btnCodebook.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnCodebook, 0, 2)
$Script:btnBackupDB = New-Object System.Windows.Forms.Button; $Script:btnBackupDB.Text="BACKUP DB (SQL)"; $Script:btnBackupDB.Dock="Fill"; Set-MirrorButton $Script:btnBackupDB ([System.Drawing.Color]::SeaGreen); $Script:btnBackupDB.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnBackupDB, 1, 2)
$Script:btnRestoreDB = New-Object System.Windows.Forms.Button; $Script:btnRestoreDB.Text="RESTORE DB (SQL)"; $Script:btnRestoreDB.Dock="Fill"; Set-MirrorButton $Script:btnRestoreDB ([System.Drawing.Color]::IndianRed); $Script:btnRestoreDB.Margin=$btnMargin; $pnlAct.Controls.Add($Script:btnRestoreDB, 2, 2)

# --- FIX: HARD SCOPED STATUS LABEL ---
$stat = New-Object System.Windows.Forms.StatusStrip; $stat.BackColor=[System.Drawing.Color]::FromArgb(200, 10, 10, 10); $Script:lblStat = New-Object System.Windows.Forms.ToolStripStatusLabel; $Script:lblStat.Text="Ready."; $Script:lblStat.ForeColor="White"; $stat.Items.Add($Script:lblStat); [void]$masterGrid.Controls.Add($stat, 0, 5)

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
    $Script:btnInstall.Enabled=$s; $Script:btnUninstall.Enabled=$s; $Script:btnCodebook.Enabled=$s;
    $Script:btnBackupDB.Enabled=$s; $Script:btnRestoreDB.Enabled=$s;
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
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
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

function Scan-Server {
    param($Target)
    $TargetClean = $Target -replace "\\",""
    $Script:IsRemote = -not ($TargetClean -match "localhost|127\.0\.0\.1|\." -or $env:COMPUTERNAME -match "^$TargetClean$" -or $TargetClean -match "^$env:COMPUTERNAME$")
    
    $FoundPath = $null
    $Result = [PSCustomObject]@{ Valid=$false; Version="Not Found"; Path=$null; InstallPath=$null; CBValid=$false; CBVersion="Not Found"; CBInstallPath=$null }

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
                    if ($app.AppPath -like "*Database Utility*" -and $app.AppPath -notlike "*CodeBook*" -and $app.AppPath -notlike "*CRM*") {
                        $v = if ($app.CurrentVersion) { $app.CurrentVersion } else { $app.Version }
                        $Result.Version = if ([string]::IsNullOrWhiteSpace($v)) { "0.0.0.0" } else { $v }
                        $Result.InstallPath = $app.AppPath; $Result.Valid = $true
                    }
                    if ($app.AppPath -like "*CodeBook*") {
                        $v = if ($app.CurrentVersion) { $app.CurrentVersion } else { $app.Version }
                        $Result.CBVersion = if ([string]::IsNullOrWhiteSpace($v)) { "0.0.0.0" } else { $v }
                        $Result.CBInstallPath = $app.AppPath; $Result.CBValid = $true
                    }
                }
            }
        } catch { $Result.Err = "Read Error" }
    }

    if ($Result.Valid) {
        $Script:DBSyncRoot = Join-Path $Result.InstallPath "DB Sync"
        $Script:txtPath.Text = $Script:DBSyncRoot
        $Script:lblVerDisplay.Text = "DB Ver: $($Result.Version)"; $Script:lblVerDisplay.ForeColor = [System.Drawing.Color]::MediumSpringGreen
        Log "  ✔ Found Main Utility: $($Result.Version)" "Lime"
        $Script:AppMgrPath = Join-Path (Split-Path $Result.Path -Parent) "PnxAppMgr.exe"
    } else { 
        $Script:lblVerDisplay.Text = "DB Ver: Not Found"; $Script:lblVerDisplay.ForeColor = [System.Drawing.Color]::Salmon
        $Script:DBSyncRoot = $null
        if ($Script:IsRemote) { Log "  ⚠ Could not auto-detect remote path. Please click 'Browse'." "Orange" }
    }

    if ($Result.CBValid) {
        $Script:CodebookRoot = Join-Path $Result.CBInstallPath "DB Sync"
        Log "  ✔ Found Codebook Utility: $($Result.CBVersion)" "Lime"
        $Script:lblCBVerDisplay.Text = "CB Ver: $($Result.CBVersion)"
        $Script:lblCBVerDisplay.ForeColor = [System.Drawing.Color]::MediumSpringGreen
    } else {
        $Script:CodebookRoot = $null
        $Script:lblCBVerDisplay.Text = "CB Ver: Not Found"
        $Script:lblCBVerDisplay.ForeColor = [System.Drawing.Color]::Salmon
    }
}

$Script:btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select DB Sync Folder"
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { 
        $Script:txtPath.Text=$fbd.SelectedPath; $Script:DBSyncRoot=$fbd.SelectedPath; Log "Path Set Manually." "Gray" 
    }
})

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

function Execute-CodebookSync {
    param($RawItems)
    try {
        if(-not $Script:CodebookRoot -or -not (Test-Path $Script:CodebookRoot)) {
            [System.Windows.Forms.MessageBox]::Show("Codebook Utility is not installed or detected on this server.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return
        }

        $fireTargets = @()
        foreach($i in $RawItems) { if ($Script:TargetMap[$i].Folder -match "Fire") { $fireTargets += $Script:TargetMap[$i].DB } }
        
        if ($fireTargets.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No Fire databases selected! Codebook sync only applies to Fire DBs.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return
        }

        Log "▶ INITIATING CODEBOOK SYNC (FIRE ONLY)..." "Red"
        
        $cbExePath = Get-ChildItem -Path $Script:CodebookRoot -Filter "PnxDBSync.exe" -Recurse | Select-Object -First 1
        if (-not $cbExePath) { Log "   ❌ Could not find PnxDBSync.exe inside Codebook folder." "Red"; return }
        
        $cbWd = $cbExePath.DirectoryName
        $XmlPath = Join-Path $cbWd "PnxAutoNewDBSyn.xml"
        $syncMode = $Script:cmbSyncType.SelectedItem.Substring(0,1)
        $isMulti = ($Script:cmbSyncType.SelectedItem -match "Multiple")
        $wshell = New-Object -ComObject wscript.shell

        if ($isMulti) {
            $dbList = $fireTargets -join ";"
            Log "  > Grouping Fire DBs for Codebook: $dbList" "White"
            foreach($D in $fireTargets) { & $CleanAndKill $D $true }
            Start-Sleep -Seconds 2

            if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
            
            $XmlString = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
	<SourceServer>
		<IPAddress>$($Script:txtS.Text)</IPAddress> 
		<DBName>$dbList</DBName>
		<UserName>$($Script:txtU.Text)</UserName> 
		<Password>$($Script:txtP.Text)</Password> 
		<JurisID>1000</JurisID>
		<State>MA</State>
		<JurisName>ProPhoenix</JurisName>
		<JurisAlias>PNX</JurisAlias>
		<SyncType>3</SyncType>
	</SourceServer>
</PnxPakager>
"@
            [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))
            
            $SyncProc = Start-Process $cbExePath.FullName -WorkingDirectory $cbWd -WindowStyle Normal -PassThru
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $promptHandled = $false
            
            while (-not $SyncProc.HasExited) {
                [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 250
                if (-not $promptHandled -and $stopwatch.Elapsed.TotalSeconds -gt 3 -and $stopwatch.Elapsed.TotalSeconds -lt 20) {
                    try { if ($wshell.AppActivate($SyncProc.Id)) { Start-Sleep -Milliseconds 100; $wshell.SendKeys("Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("%Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("{ENTER}"); $promptHandled = $true; Log "   > Auto-Answered Codebook Prompt." "DarkGray" } } catch {}
                }
            }
            $stopwatch.Stop()
            if ($SyncProc.ExitCode -eq 0) { Log "   ✔ Codebook Batch Sync Completed" "Lime" } 
            else { 
                Log "   ❌ Codebook Batch Process Failed! (Exit Code: $($SyncProc.ExitCode))" "Red"
                Show-SyncErrorAlert -DBName "CODEBOOK BATCH" -LogLines (Get-SyncErrorDetails -WorkDir $cbWd)
            }
            if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
            foreach($D in $fireTargets) { & $CleanAndKill $D $true }
        } 
        else {
            foreach ($D in $fireTargets) {
                Log "  > Syncing Codebook for: $D" "White"
                $killMain = if ($syncMode -eq "1") { $false } else { $true }
                & $CleanAndKill $D $killMain
                Start-Sleep -Seconds 2
                
                if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
                $XmlString = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
	<SourceServer>
		<IPAddress>$($Script:txtS.Text)</IPAddress> 
		<DBName>$D</DBName>
		<UserName>$($Script:txtU.Text)</UserName> 
		<Password>$($Script:txtP.Text)</Password> 
		<JurisID>1000</JurisID>
		<State>MA</State>
		<JurisName>ProPhoenix</JurisName>
		<JurisAlias>PNX</JurisAlias>
		<SyncType>$syncMode</SyncType>
	</SourceServer>
</PnxPakager>
"@
                [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))
                
                $SyncProc = Start-Process $cbExePath.FullName -WorkingDirectory $cbWd -WindowStyle Normal -PassThru
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $promptHandled = $false
                
                while (-not $SyncProc.HasExited) {
                    [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 250
                    if (-not $promptHandled -and $stopwatch.Elapsed.TotalSeconds -gt 3 -and $stopwatch.Elapsed.TotalSeconds -lt 20) {
                        try { if ($wshell.AppActivate($SyncProc.Id)) { Start-Sleep -Milliseconds 100; $wshell.SendKeys("Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("%Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("{ENTER}"); $promptHandled = $true; Log "   > Auto-Answered Codebook Prompt." "DarkGray" } } catch {}
                    }
                }
                $stopwatch.Stop()
                if ($SyncProc.ExitCode -eq 0) { Log "   ✔ Codebook Sync Completed for $D" "Lime" } 
                else { 
                    Log "   ❌ Codebook Sync Failed for $D (Exit Code: $($SyncProc.ExitCode))" "Red"
                    Show-SyncErrorAlert -DBName "CODEBOOK: $D" -LogLines (Get-SyncErrorDetails -WorkDir $cbWd)
                }
                if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
                & $CleanAndKill $D $killMain
            }
        }
    } catch { Log "❌ Codebook Error: $($_.Exception.Message)" "Red" }
}

function Execute-DBSync {
    param($RawItems)
    try {
        if ($RawItems.Count -eq 0) { return }
        
        $safeItems = @()
        foreach ($i in $RawItems) { $safeItems += $i }
        
        $FailedDBs = @()
        $syncMode = $Script:cmbSyncType.SelectedItem.Substring(0,1)
        $isMulti = ($Script:cmbSyncType.SelectedItem -match "Multiple")
        $wshell = New-Object -ComObject wscript.shell

        if ($isMulti) {
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
		<DBName>$dbList</DBName>
		<UserName>$($Script:txtU.Text)</UserName> 
		<Password>$($Script:txtP.Text)</Password> 
		<JurisID>1000</JurisID>
		<State>MA</State>
		<JurisName>ProPhoenix</JurisName>
		<JurisAlias>PNX</JurisAlias>
		<SyncType>3</SyncType>
	</SourceServer>
</PnxPakager>
"@
                [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))

                $SyncProc = Start-Process "$WD\PnxDBSync.exe" -WorkingDirectory $WD -WindowStyle Normal -PassThru
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $promptHandled = $false
                
                while (-not $SyncProc.HasExited) {
                    [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 250
                    if (-not $promptHandled -and $stopwatch.Elapsed.TotalSeconds -gt 3 -and $stopwatch.Elapsed.TotalSeconds -lt 20) {
                        try { if ($wshell.AppActivate($SyncProc.Id)) { Start-Sleep -Milliseconds 100; $wshell.SendKeys("Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("%Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("{ENTER}"); $promptHandled = $true; Log "   > Auto-Answered Upgrade Prompt." "DarkGray" } } catch {}
                    }
                }
                $stopwatch.Stop()
                
                if ($SyncProc.ExitCode -eq 0) { Log "   ✔ Batch Sync Completed Successfully" "Lime" } 
                else {
                    $FailedDBs += "Group: $F ($dbList)"
                    Log "   ❌ Batch Sync Process Failed! (Exit Code: $($SyncProc.ExitCode))" "Red"
                    Show-SyncErrorAlert -DBName "BATCH GROUP: $F" -LogLines (Get-SyncErrorDetails -WorkDir $WD)
                }

                if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
                foreach ($D in $groupedDBs[$F]) { & $CleanAndKill $D $true }
            }
        } 
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

                    $killMain = if ($syncMode -eq "1") { $false } else { $true }
                    & $CleanAndKill $D $killMain
                    Start-Sleep -Seconds 2 

                    if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }

                    $XmlString = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
	<SourceServer>
		<IPAddress>$($Script:txtS.Text)</IPAddress> 
		<DBName>$D</DBName>
		<UserName>$($Script:txtU.Text)</UserName> 
		<Password>$($Script:txtP.Text)</Password> 
		<JurisID>1000</JurisID>
		<State>MA</State>
		<JurisName>ProPhoenix</JurisName>
		<JurisAlias>PNX</JurisAlias>
		<SyncType>$syncMode</SyncType>
	</SourceServer>
</PnxPakager>
"@
                    [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))

                    $SyncProc = Start-Process "$WD\PnxDBSync.exe" -WorkingDirectory $WD -WindowStyle Normal -PassThru
                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    $promptHandled = $false

                    while (-not $SyncProc.HasExited) {
                        [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 250
                        if (-not $promptHandled -and $stopwatch.Elapsed.TotalSeconds -gt 3 -and $stopwatch.Elapsed.TotalSeconds -lt 20) {
                            try { if ($wshell.AppActivate($SyncProc.Id)) { Start-Sleep -Milliseconds 100; $wshell.SendKeys("Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("%Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("{ENTER}"); $promptHandled = $true; Log "   > Auto-Answered Upgrade Prompt." "DarkGray" } } catch {}
                        }
                    }
                    $stopwatch.Stop()
                    
                    if ($SyncProc.ExitCode -eq 0) {
                        if ($syncMode -eq "1") { Log "   ✔ Sync Completed Successfully (Note: Make DB skips existing DBs)" "Lime" } 
                        else { Log "   ✔ Sync Completed Successfully" "Lime" }
                    } else {
                        $FailedDBs += $D
                        Log "   ❌ Sync Process Failed! (Exit Code: $($SyncProc.ExitCode))" "Red"
                        Show-SyncErrorAlert -DBName $D -LogLines (Get-SyncErrorDetails -WorkDir $WD)
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
            $msg = "The following databases encountered hard crashes during sync:`n`n" + ($FailedDBs -join "`n")
            [System.Windows.Forms.MessageBox]::Show($msg, "Sync Completed with Errors", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        } else { Log "✔ All databases processed successfully." "Lime" }
    } catch { Log "❌ CRITICAL PIPELINE ERROR: $($_.Exception.Message)" "Red" }
}

# --- DB BACKUP LOGIC (NATIVE SQL) ---
$Script:btnBackupDB.Add_Click({
    try {
        if($Script:listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database(s) to Backup!", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select Backup Destination Folder"; $fbd.SelectedPath = $Script:DefaultBackup
        if($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){ return }
        $TargetDirBase = $fbd.SelectedPath

        Toggle $false; Log "▶ STARTING NATIVE SQL DATABASE BACKUP..." "Cyan"
        
        $CS="Server=$($Script:txtS.Text);Database=master;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Connection Timeout=30"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS)
        $CN.FireInfoMessageEventOnUserErrors = $true
        $CN.add_InfoMessage({ param($sender, $e) if ($e.Message -match "percent processed" -or $e.Message -match "processed.") { Log "   > $($e.Message)" "DarkGray" } })
        $CN.Open()

        $Cmd=$CN.CreateCommand(); $Cmd.CommandTimeout = 0

        foreach ($item in $Script:listDBs.CheckedItems) {
            $DB = $Script:TargetMap[$item].DB
            $BakFile = Join-Path $TargetDirBase "$DB`_ManualBackup_$(Get-Date -Format 'yyyyMMdd_HHmm').bak"
            Log "  > Backing up $DB to $BakFile..." "White"; [System.Windows.Forms.Application]::DoEvents()
            
            $Cmd.CommandText="BACKUP DATABASE [$DB] TO DISK='$BakFile' WITH INIT, COMPRESSION, STATS=10"
            try {
                $Cmd.ExecuteNonQuery()|Out-Null
                $BkpInfo = Get-Item $BakFile; $NewSize = [math]::Round($BkpInfo.Length / 1MB, 2)
                Log "  ✔ Backup Complete ($NewSize MB)" "Lime"
            } catch { Log "  ❌ Backup Failed: $($_.Exception.Message)" "Red" }
        }
        $CN.Close(); Log "✔ All Backups Finished." "Cyan"
    } 
    catch { Log "  ❌ Error: $($_.Exception.Message)" "Red" } 
    finally { Toggle $true }
})

# --- DB RESTORE LOGIC (NATIVE SQL) ---
$Script:btnRestoreDB.Add_Click({
    try {
        if($Script:listDBs.CheckedItems.Count -ne 1){ [System.Windows.Forms.MessageBox]::Show("Select exactly ONE database to restore into.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
        $TargetDB = $Script:TargetMap[$Script:listDBs.CheckedItems[0]].DB

        $f = New-Object System.Windows.Forms.OpenFileDialog
        $f.Filter = "SQL Backup Files (*.bak)|*.bak"
        $f.Title = "Select .BAK File to Restore into $TargetDB"
        $f.InitialDirectory = $Script:DefaultBackup
        if ($f.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $BakFile = $f.FileName

        $ans = [System.Windows.Forms.MessageBox]::Show("CRITICAL WARNING:`n`nYou are about to overwrite the existing database [$TargetDB] with:`n$BakFile`n`nAre you absolutely sure?", "Confirm RESTORE", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Error)
        if($ans -ne [System.Windows.Forms.DialogResult]::Yes){ return }

        Toggle $false; Log "▶ INITIATING NATIVE SQL DATABASE RESTORE OVER [$TargetDB]..." "Red"
        
        $CS="Server=$($Script:txtS.Text);Database=master;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Connection Timeout=30"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS)
        $CN.FireInfoMessageEventOnUserErrors = $true
        $CN.add_InfoMessage({ param($sender, $e) if ($e.Message -match "percent processed" -or $e.Message -match "processed.") { Log "   > $($e.Message)" "DarkGray" } })
        $CN.Open()
        
        $Cmd=$CN.CreateCommand(); $Cmd.CommandTimeout = 0

        Log "  > Dropping user sessions on $TargetDB..." "Orange"; [System.Windows.Forms.Application]::DoEvents()
        try { 
            $CmdDrop = New-Object System.Data.SqlClient.SqlCommand("IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$TargetDB') BEGIN DECLARE @kill varchar(8000) = ''; SELECT @kill = @kill + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$TargetDB'); EXEC(@kill); ALTER DATABASE [$TargetDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; END", $CN)
            $CmdDrop.CommandTimeout = 0
            $CmdDrop.ExecuteNonQuery()|Out-Null 
        } catch { Log "   > Notice: Could not force Single User" "DarkGray" }

        Log "  > Analyzing Backup File..." "White"; [System.Windows.Forms.Application]::DoEvents()
        $Cmd.CommandText="RESTORE FILELISTONLY FROM DISK='$BakFile'"; $Rdr=$Cmd.ExecuteReader(); $Files=@(); while($Rdr.Read()){$Files+=@{L=$Rdr["LogicalName"];P=$Rdr["PhysicalName"];T=$Rdr["Type"]}}; $Rdr.Close()
        
        $MoveStr = ""; foreach($f in $Files){ 
            $Ext=[System.IO.Path]::GetExtension($f.P); $Dir=[System.IO.Path]::GetDirectoryName($f.P)
            $NewName = "$TargetDB"; if ($f.T -eq "L") { $NewName += "_log" }; $NewName += $Ext
            $NewPath = Join-Path $Dir $NewName
            $MoveStr += "MOVE '$($f.L)' TO '$NewPath', " 
        }

        Log "  > Restoring $TargetDB (WITH LIVE PROGRESS)..." "White"; [System.Windows.Forms.Application]::DoEvents()
        $Cmd.CommandText="RESTORE DATABASE [$TargetDB] FROM DISK='$BakFile' WITH RECOVERY, REPLACE, STATS=10, $($MoveStr.TrimEnd(', '))"
        $Cmd.ExecuteNonQuery()|Out-Null
        
        $Cmd.CommandText = "ALTER DATABASE [$TargetDB] SET MULTI_USER"; $Cmd.ExecuteNonQuery()|Out-Null
        $CN.Close()
        Log "  ✔ Restore Complete." "Lime"
        $Script:btnCon.PerformClick()
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

            DECLARE @sysJurisID INT;
            IF OBJECT_ID('TempDB..#Juris') IS NOT NULL DROP TABLE #Juris;
            SELECT TOP 1 JurisID INTO #Juris FROM Juris WITH(NOLOCK);
            SELECT @sysJurisID = JurisID FROM #Juris;
            SET @sysJurisID = ISNULL(@sysJurisID, 0);

            IF EXISTS (SELECT 1 FROM Parameter WHERE CAST(ParamID AS VARCHAR(50)) = CAST(@tID AS VARCHAR(50)) AND JurisID=@sysJurisID)
            BEGIN
                UPDATE Parameter SET ParamValue = @tVal WHERE CAST(ParamID AS VARCHAR(50)) = CAST(@tID AS VARCHAR(50)) AND JurisID=@sysJurisID;
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
        Log "   ✔ Params: $pUpdated Updated | $pInserted Inserted" "Lime"

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
                        $pName = $jp.Name.Replace("'", "''"); $pVal = $jp.Value.Replace("'", "''")
                        $cmd.CommandText = "INSERT INTO KPIjobsparam(JobID, SeqNo, ParamName, ParamValue) VALUES ($returnedJobID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIjobsparam WHERE JobID = $returnedJobID), '$pName', '$pVal')"
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
        Log "   ✔ Jobs: $jRestored Configured Successfully" "Lime"
        $CN.Close()
    } catch { Log "   ❌ Config Apply Failed: $($_.Exception.Message)" "Red" }
}

# --- COPY DB ---
function Show-CopyDialog {
    $d = New-Object System.Windows.Forms.Form; $d.Text="DB Copy"; $d.Size="300,150"; $d.StartPosition="CenterParent"
    $l = New-Object System.Windows.Forms.Label; $l.Text="Select Target Type:"; $l.Location="20,20"; $l.AutoSize=$true; $d.Controls.Add($l)
    $cb = New-Object System.Windows.Forms.ComboBox; $cb.Items.AddRange(@("Train (Tr)","Test (Test)")); $cb.SelectedIndex=0; $cb.Location="20,50"; $cb.Width=240; $d.Controls.Add($cb)
    $b = New-Object System.Windows.Forms.Button; $b.Text="PROCEED"; $b.DialogResult=[System.Windows.Forms.DialogResult]::OK; $b.Location="80,80"; $d.Controls.Add($b); $d.AcceptButton=$b
    if($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){return $cb.SelectedItem} return $null
}

function Show-InputBox { param($T,$P,$D) $f=New-Object System.Windows.Forms.Form;$f.Text=$T;$f.Size="350,150";$f.StartPosition="CenterParent";$l=New-Object System.Windows.Forms.Label;$l.Text=$P;$l.Location="10,10";$l.AutoSize=$true;$f.Controls.Add($l);$t=New-Object System.Windows.Forms.TextBox;$t.Text=$D;$t.Location="10,35";$t.Width=310;$f.Controls.Add($t);$b=New-Object System.Windows.Forms.Button;$b.Text="OK";$b.DialogResult=[System.Windows.Forms.DialogResult]::OK;$b.Location="120,70";$f.Controls.Add($b);$f.AcceptButton=$b;if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){return $t.Text} return $null }

$Script:btnCopyDB.Add_Click({
    try {
        if($Script:listDBs.CheckedItems.Count -ne 1){ [System.Windows.Forms.MessageBox]::Show("Select exactly ONE source database.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
        $SourceDB = $Script:TargetMap[$Script:listDBs.CheckedItems[0]].DB
        $TypeSel = Show-CopyDialog; if(!$TypeSel){return}
        $Tag = if($TypeSel -match "Train"){"Tr"}else{"Test"}
        $DefName = if($SourceDB -match "^Phoenix") { $SourceDB.Replace("Phoenix", "Phoenix$Tag") } else { "$($SourceDB)_$Tag" }
        $TargetDB = Show-InputBox "Target Name" "Confirm Target Database Name:" $DefName
        if ([string]::IsNullOrWhiteSpace($TargetDB)) { return }

        $ans = [System.Windows.Forms.MessageBox]::Show("Do you want to apply an Enterprise Configuration Backup (.txt) to the newly copied database ($TargetDB)?`n`nIf Yes, you will be prompted to select the .txt file.", "Apply Configuration?", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        $ConfigFilePath = $null
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) {
            $f = New-Object System.Windows.Forms.OpenFileDialog
            $f.Filter = "Text Backup (*.txt)|*.txt"
            $f.Title = "Select Enterprise Config Backup to Apply"
            $f.InitialDirectory = $Script:DefaultBackup
            if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $ConfigFilePath = $f.FileName }
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
        
        $ans = [System.Windows.Forms.MessageBox]::Show("SOURCE: $SourceDB`nSIZE: $SizeMB MB`nFILE: $Mdf`n`nProceed with Backup?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if($ans -ne [System.Windows.Forms.DialogResult]::Yes){ $CN.Close(); return }
        
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select Backup Location"; $fbd.SelectedPath = $Script:DefaultBackup
        if($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){ $CN.Close(); return }
        $BackupPath = $fbd.SelectedPath
        $BakFile = Join-Path $BackupPath "$SourceDB`_Copy.bak"

        Log "  > Backing up to $BakFile (WITH LIVE PROGRESS)..." "White"; [System.Windows.Forms.Application]::DoEvents()
        $Cmd.CommandText="BACKUP DATABASE [$SourceDB] TO DISK='$BakFile' WITH COPY_ONLY, INIT, FORMAT, COMPRESSION, STATS=10"
        $Cmd.ExecuteNonQuery()|Out-Null
        Log "  ✔ Backup Complete (Compressed)" "Lime"
        
        $BkpInfo = Get-Item $BakFile; $NewSize = [math]::Round($BkpInfo.Length / 1MB, 2)
        $ans = [System.Windows.Forms.MessageBox]::Show("Backup: $NewSize MB`nTarget: $TargetDB`n`nWARNING: Overwriting $TargetDB. Proceed?", "Confirm Restore", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if($ans -ne [System.Windows.Forms.DialogResult]::Yes){ $CN.Close(); return }
        
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
        if($Script:listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select DBs to Backup!", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select Folder to Save Backups"; $fbd.SelectedPath = $Script:DefaultBackup
        if($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){ return }
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
            
            $paramList = $Script:TargetParams -join ","
            $cmd = $CN.CreateCommand()
            $cmd.CommandText = @"
            SET NOCOUNT ON;
            DECLARE @JurisID INT;
            IF OBJECT_ID('TempDB..#Juris') IS NOT NULL DROP TABLE #Juris;
            SELECT TOP 1 JurisID INTO #Juris FROM Juris WITH(NOLOCK);
            SELECT @JurisID=JurisID FROM #Juris;
            SELECT ParamID, CAST(ParamValue AS NVARCHAR(MAX)) AS ParamValue 
            FROM Parameter 
            WHERE CAST(ParamID AS VARCHAR(50)) IN ($paramList) AND JurisID=@JurisID;
"@
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
            Log "    + Exported $paramCount Parameters (Base Juris Only)" "Lime"
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
        if($Script:listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select DBs to Restore!", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
        $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Filter="Text Backup (*.txt)|*.txt"; $f.InitialDirectory=$Script:DefaultBackup; 
        if($f.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return}; $SourceFile=$f.FileName
        
        $ans = [System.Windows.Forms.MessageBox]::Show("RESTORE Configuration from:`n$SourceFile`n`nAre you absolutely sure?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if($ans -ne [System.Windows.Forms.DialogResult]::Yes){ return }
        
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

# --- CONNECT & AUTO-SYNC PIPELINE ---
$Script:btnCon.Add_Click({
    try {
        if (-not $Script:txtPath.Text -and (-not $Script:DBSyncRoot)) {
            # Let the scan logic attempt to find it before failing
        }

        Toggle $false; $Script:listDBs.Items.Clear(); $Script:TargetMap=@{}
        Log "▶ INITIALIZING CONNECTION..." "Cyan"
        
        $cs = "Server=$($Script:txtS.Text);User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Database=master;Connection Timeout=5"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $da = New-Object System.Data.SqlClient.SqlDataAdapter("SELECT Name FROM sys.databases WHERE database_id>4 AND Name NOT IN ('master','model','msdb','tempdb','ReportServer') ORDER BY Name", $cn)
        $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        Log "  ✔ SQL Server Connected Successfully." "Lime"; $Script:lblStat.Text = "Connected."; Save-Creds; Scan-Server $Script:txtS.Text 

        $Script:AutoCodebook = $false
        
        $hasAppMgr = $false
        if (-not [string]::IsNullOrWhiteSpace($Script:AppMgrPath)) {
            if (Test-Path $Script:AppMgrPath) { $hasAppMgr = $true }
        }

        if ($Script:chkAutoSync.Checked -and $hasAppMgr) {
            $ans = [System.Windows.Forms.MessageBox]::Show("Auto Update DB is checked.`n`nDo you also need to INSTALL and SYNC the Codebook Utility?", "Codebook Integration Pipeline", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) { $Script:AutoCodebook = $true }

            Log "  > Auto-Uninstalling utilities..." "Yellow"; [System.Windows.Forms.Application]::DoEvents()
            $Dir = Split-Path $Script:AppMgrPath -Parent
            $bat1 = "@echo off`ncd /d `"$Dir`"`n`"$($Script:AppMgrPath)`" UNINSTALL `"DBUtility`"`n"
            if ($Script:AutoCodebook) { $bat1 += "`"$($Script:AppMgrPath)`" UNINSTALL `"DatabaseUtilityCodebook`"`n" }
            Set-Content (Join-Path $env:TEMP "PnxAction.bat") $bat1
            Start-Process (Join-Path $env:TEMP "PnxAction.bat") -WindowStyle Hidden -Wait
            
            Start-Sleep -Seconds 2
            [System.Windows.Forms.Application]::DoEvents()

            Log "  > Auto-Installing utilities..." "Yellow"; [System.Windows.Forms.Application]::DoEvents()
            $bat2 = "@echo off`ncd /d `"$Dir`"`n`"$($Script:AppMgrPath)`" INSTALL `"DBUtility`"`n"
            if ($Script:AutoCodebook) { $bat2 += "`"$($Script:AppMgrPath)`" INSTALL `"DatabaseUtilityCodebook`"`n" }
            Set-Content (Join-Path $env:TEMP "PnxAction.bat") $bat2
            Start-Process (Join-Path $env:TEMP "PnxAction.bat") -WindowStyle Hidden -Wait
            
            Log "  > Waiting for file extraction..." "DarkGray"; [System.Windows.Forms.Application]::DoEvents()
            $waitCounter = 0
            while ($waitCounter -lt 30) {
                Start-Sleep -Seconds 2
                if (Test-Path "$($Script:DBSyncRoot)\Phoenix Master\PnxDBSync.exe") { break }
                if (Test-Path "$($Script:DBSyncRoot)\Police\PnxDBSync.exe") { break }
                $waitCounter++
                [System.Windows.Forms.Application]::DoEvents()
            }
            if ($waitCounter -ge 30) { Log "   ! Warning: Extraction timed out." "Orange" } 
            else { Start-Sleep -Seconds 5; Log "  ✔ AppMgr Refreshed & Utility Verified." "Lime" }
            
            # Rescan to catch newly installed codebook path
            Scan-Server $Script:txtS.Text 
        }

        # --- CATEGORY LOGIC ---
        $EnvMode = $Script:cmbEnv.SelectedItem

        foreach ($row in $ds.Tables[0].Rows) {
            $db = $row.Name; $Folder = $null; $Tag = ""; $Type = ""
            
            $IsTrain = ($db -match "Tr" -or $db -match "Train")
            $IsTest = ($db -match "Test" -and -not $IsTrain) 
            $IsMaster = ($db -match "Master")

            if ($EnvMode -eq "LIVE") { if ($IsTest) { continue } } 
            elseif ($EnvMode -eq "TEST") { if (-not $IsTest -and -not $IsMaster) { continue } }

            if ($db -match "DW") { $Type = "Police DW"; $Folder = "Police DW" }
            elseif ($db -match "CSP") { 
                if($db -match "Fire") { $Type = "Fire CSP"; $Folder = "Fire CSP" } else { $Type = "Police CSP"; $Folder = "Police CSP" } 
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

        # --- AUTO EXECUTION PIPELINE ---
        if ($Script:chkAutoSync.Checked) {
            if ($Script:AutoCodebook) {
                Log "▶ AUTO-UPDATE PIPELINE: CODEBOOK FIRST" "Yellow"; [System.Windows.Forms.Application]::DoEvents()
                Execute-CodebookSync $Script:listDBs.CheckedItems
            }
            Log "▶ AUTO-UPDATE PIPELINE: MAIN UTILITY" "Yellow"; [System.Windows.Forms.Application]::DoEvents()
            Execute-DBSync $Script:listDBs.CheckedItems
        }
    } 
    catch { Log "❌ Error: $($_.Exception.Message)" "Red" } 
    finally { Toggle $true }
})

# --- SYNC BUTTONS ---
$Script:btnSync.Add_Click({ 
    try {
        if($Script:listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database(s) to Sync!", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
        Toggle $false; Execute-DBSync $Script:listDBs.CheckedItems; 
    } 
    catch { Log "❌ Error: $($_.Exception.Message)" "Red" }
    finally { Toggle $true } 
})

$Script:btnCodebook.Add_Click({
    try {
        Toggle $false; Execute-CodebookSync $Script:listDBs.CheckedItems; 
    } 
    catch { Log "❌ Error: $($_.Exception.Message)" "Red" }
    finally { Toggle $true } 
})

# --- VER & INSTALL ---
$Script:btnVer.Add_Click({ 
    try {
        if($Script:listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database(s) first!", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
        Toggle $false; Log "▶ CHECKING VERSIONS..." "Cyan"; Scan-Server $Script:txtS.Text; 
        $cn=New-Object System.Data.SqlClient.SqlConnection("Server=$($Script:txtS.Text);User Id=$($Script:txtU.Text);Password=$($Script:txtP.Text);Database=master"); $cn.Open(); 
        foreach($i in $Script:listDBs.CheckedItems){ $D=$Script:TargetMap[$i].DB; $cmd=$cn.CreateCommand(); $cmd.CommandText="SELECT Version FROM [$D].dbo.KPIDBVersion"; try{ $v=$cmd.ExecuteScalar(); Log "  $D : $v" "White" }catch{Log "  $D : Error" "Red"} }; 
        $cn.Close() 
    } catch {} finally { Toggle $true } 
})

$RunAppMgr = { param($Mode)
    $hasAppMgr = $false
    if (-not [string]::IsNullOrWhiteSpace($Script:AppMgrPath)) {
        if (Test-Path $Script:AppMgrPath) { $hasAppMgr = $true }
    }

    if (-not $hasAppMgr) {
        if (-not [string]::IsNullOrWhiteSpace($Script:txtPath.Text) -and (Test-Path $Script:txtPath.Text)) { $Script:AppMgrPath = Join-Path (Split-Path $Script:txtPath.Text -Parent) "PnxAppMgr.exe" }
        if (-not [string]::IsNullOrWhiteSpace($Script:AppMgrPath) -and (Test-Path $Script:AppMgrPath)) { $hasAppMgr = $true }
        
        if (-not $hasAppMgr) {
            [System.Windows.Forms.MessageBox]::Show("Please locate PnxAppMgr.exe", "Notice", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
            $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Filter="PnxAppMgr.exe|PnxAppMgr.exe"; 
            if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$Script:AppMgrPath=$f.FileName}else{return}
        }
    }
    
    $Bat = Join-Path $env:TEMP "PnxAction.bat"
    $Dir = Split-Path $Script:AppMgrPath -Parent
    $BatContent = "@echo off`ncd /d `"$Dir`"`n"
    
    if ($Mode -eq "INSTALL") {
        $BatContent += "`"$($Script:AppMgrPath)`" INSTALL `"DBUtility`"`n"
        $ans = [System.Windows.Forms.MessageBox]::Show("Do you also want to install the Codebook Utility (DatabaseUtilityCodebook)?", "Install Codebook?", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) { $BatContent += "`"$($Script:AppMgrPath)`" INSTALL `"DatabaseUtilityCodebook`"`n" }
    } elseif ($Mode -eq "UNINSTALL") {
        $BatContent += "`"$($Script:AppMgrPath)`" UNINSTALL `"DBUtility`"`n"
        $ans = [System.Windows.Forms.MessageBox]::Show("Do you also want to uninstall the Codebook Utility?", "Uninstall Codebook?", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) { $BatContent += "`"$($Script:AppMgrPath)`" UNINSTALL `"DatabaseUtilityCodebook`"`n" }
    }
    $BatContent += "pause"
    
    Set-Content $Bat $BatContent
    Start-Process $Bat -Verb RunAs
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

$Script:btnInstall.Add_Click({ & $RunAppMgr "INSTALL" })
$Script:btnUninstall.Add_Click({ & $RunAppMgr "UNINSTALL" })

# --- INIT ---
function Show-NewDBDialog { $dbForm=New-Object System.Windows.Forms.Form;$dbForm.Text="Create DB";$dbForm.Size="400,380";$dbForm.StartPosition="CenterParent";$lblC=New-Object System.Windows.Forms.Label;$lblC.Text="Category:";$lblC.Location="20,30";$dbForm.Controls.Add($lblC);$cmbCat=New-Object System.Windows.Forms.ComboBox;$cmbCat.Items.AddRange(@("Police","Fire","Phoenix Master","IA","Police CSP","Fire CSP"));$cmbCat.SelectedIndex=0;$cmbCat.Location="120,27";$cmbCat.Width=240;$dbForm.Controls.Add($cmbCat);function Add-Field($lbl,$y,$def){$l=New-Object System.Windows.Forms.Label;$l.Text=$lbl;$l.Location="20,$y";$dbForm.Controls.Add($l);$t=New-Object System.Windows.Forms.TextBox;$t.Text=$def;$t.Location="120,$($y-3)";$t.Width=240;$dbForm.Controls.Add($t);return $t};$inDB=Add-Field "Database" 70 "PhoenixPolice";$inJID=Add-Field "JurisID" 110 "1000";$inSt=Add-Field "State" 150 "MA";$inN=Add-Field "Name" 190 "ProPhoenix";$inA=Add-Field "Alias" 230 "PNX";$btn=New-Object System.Windows.Forms.Button;$btn.Text="CREATE";$btn.DialogResult=[System.Windows.Forms.DialogResult]::OK;$btn.Location="120,280";$dbForm.Controls.Add($btn);$dbForm.AcceptButton=$btn;if($dbForm.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){return @{DB=$inDB.Text;JID=$inJID.Text;St=$inSt.Text;Nm=$inN.Text;Al=$inA.Text;Cat=$cmbCat.SelectedItem}} return $null }
$Script:form.Add_Load({ Load-Creds }); $Script:form.Add_Shown({$Script:form.Activate()}); [void]$Script:form.ShowDialog()