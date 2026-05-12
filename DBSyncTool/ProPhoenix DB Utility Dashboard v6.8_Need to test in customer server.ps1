#Requires -RunAsAdministrator
# ======================================================================
#  ProPhoenix DB Utility Dashboard - v181.0 (Manual Upgrade Toggle)
# ======================================================================

# --- AUTO-ELEVATE TO ADMINISTRATOR ---
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $powershell = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    Start-Process $powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
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

# --- THEME ---
$colBg = [System.Drawing.Color]::Black
$colText = [System.Drawing.Color]::WhiteSmoke
$colInputBg = [System.Drawing.Color]::FromArgb(60, 60, 60) 
$colList = [System.Drawing.Color]::FromArgb(40, 40, 40) 
$colBtn = [System.Drawing.Color]::FromArgb(70, 70, 70)
$fontTitle = New-Object System.Drawing.Font("Segoe UI Light", 20, [System.Drawing.FontStyle]::Regular)
$fontHeader = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontNorm = New-Object System.Drawing.Font("Segoe UI", 9)
$fontLog = New-Object System.Drawing.Font("Consolas", 9) 

# --- FORM SETUP ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProPhoenix DB Utility Dashboard v181"
$form.Size = New-Object System.Drawing.Size(1250, 950) 
$form.StartPosition = "CenterScreen"
$form.BackColor = $colBg
$form.ForeColor = $colText

if (Test-Path $Script:BgImage) { 
    $form.BackgroundImage = [System.Drawing.Image]::FromFile($Script:BgImage)
    $form.BackgroundImageLayout = "Zoom" 
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

$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="DB Sync Dashboard"; $lblTitle.AutoSize=$true; $lblTitle.Location="100,15"; $lblTitle.Font=$fontTitle; $lblTitle.ForeColor=[System.Drawing.Color]::DodgerBlue; $pnlHead.Controls.Add($lblTitle)
$lblPath = New-Object System.Windows.Forms.Label; $lblPath.Text="Utility Path:"; $lblPath.Location="700,15"; $lblPath.AutoSize=$true; $lblPath.ForeColor="Gray"; $pnlHead.Controls.Add($lblPath)
$txtPath = New-Object System.Windows.Forms.TextBox; $txtPath.Location="770,12"; $txtPath.Size="350,25"; $txtPath.BackColor=$colInputBg; $txtPath.ForeColor="White"; $txtPath.BorderStyle="FixedSingle"; $pnlHead.Controls.Add($txtPath)
$btnBrowse = New-Object System.Windows.Forms.Button; $btnBrowse.Text="Browse"; $btnBrowse.Location="1130,12"; $btnBrowse.Size="80,25"; $btnBrowse.BackColor=$colBtn; $btnBrowse.ForeColor="White"; $btnBrowse.FlatStyle="Flat"; $pnlHead.Controls.Add($btnBrowse)
$lblVerDisplay = New-Object System.Windows.Forms.Label; $lblVerDisplay.Text="Ver: --"; $lblVerDisplay.AutoSize=$false; $lblVerDisplay.TextAlign="Right"; $lblVerDisplay.Size="300,20"; $lblVerDisplay.Location="910,40"; $lblVerDisplay.ForeColor="Gray"; $pnlHead.Controls.Add($lblVerDisplay)
[void]$masterGrid.Controls.Add($pnlHead, 0, 0)

# --- ADMIN ROW ---
$pnlAdmin = New-Object System.Windows.Forms.Panel; $pnlAdmin.Dock="Fill"; $pnlAdmin.BackColor=[System.Drawing.Color]::FromArgb(40,40,40)
[void]$masterGrid.Controls.Add($pnlAdmin, 0, 1)
$btnCreateDB = New-Object System.Windows.Forms.Button; $btnCreateDB.Text="Create New DB"; $btnCreateDB.Location="200,15"; $btnCreateDB.Size="160,40"; $btnCreateDB.BackColor=[System.Drawing.Color]::DodgerBlue; $btnCreateDB.ForeColor="White"; $btnCreateDB.FlatStyle="Flat"; $pnlAdmin.Controls.Add($btnCreateDB)
$btnInstall = New-Object System.Windows.Forms.Button; $btnInstall.Text="Install Utility"; $btnInstall.Location="380,15"; $btnInstall.Size="160,40"; $btnInstall.BackColor=[System.Drawing.Color]::SeaGreen; $btnInstall.ForeColor="White"; $btnInstall.FlatStyle="Flat"; $pnlAdmin.Controls.Add($btnInstall)
$btnUninstall = New-Object System.Windows.Forms.Button; $btnUninstall.Text="Uninstall Utility"; $btnUninstall.Location="560,15"; $btnUninstall.Size="160,40"; $btnUninstall.BackColor=[System.Drawing.Color]::IndianRed; $btnUninstall.ForeColor="White"; $btnUninstall.FlatStyle="Flat"; $pnlAdmin.Controls.Add($btnUninstall)

# --- CONNECTION ---
$grpCon = New-Object System.Windows.Forms.GroupBox; $grpCon.Text=" SQL Connection "; $grpCon.Dock="Fill"; $grpCon.ForeColor="LightGray"; $grpCon.Font=$fontHeader
[void]$masterGrid.Controls.Add($grpCon, 0, 2)
$flowCon = New-Object System.Windows.Forms.FlowLayoutPanel; $flowCon.Dock="Fill"; $flowCon.Padding=New-Object System.Windows.Forms.Padding(10,15,0,0); $grpCon.Controls.Add($flowCon)
function Add-Input($p, $l, $w, $d, $pass=$false){ $pn=New-Object System.Windows.Forms.Panel;$pn.Size=New-Object System.Drawing.Size($w,50); $lb=New-Object System.Windows.Forms.Label;$lb.Text=$l;$lb.AutoSize=$true;$lb.ForeColor="White";$lb.Font=$fontNorm;$pn.Controls.Add($lb); $bx=New-Object System.Windows.Forms.TextBox;$bx.Text=$d;$bx.Location="0,20";$bx.Width=$w-10;$bx.BackColor=$colInputBg;$bx.ForeColor="White";$bx.BorderStyle="FixedSingle";if($pass){$bx.PasswordChar="*"};$pn.Controls.Add($bx); $p.Controls.Add($pn); return $bx }

$txtS = Add-Input $flowCon "Server IP" 180 $env:COMPUTERNAME
$txtU = Add-Input $flowCon "Username" 100 "sa"
$txtP = Add-Input $flowCon "Password" 100 "" $true

$pnEnv = New-Object System.Windows.Forms.Panel; $pnEnv.Size=New-Object System.Drawing.Size(100,50)
$lbEnv = New-Object System.Windows.Forms.Label; $lbEnv.Text="Environment"; $lbEnv.AutoSize=$true; $lbEnv.ForeColor="White"; $lbEnv.Font=$fontNorm; $pnEnv.Controls.Add($lbEnv)
$cmbEnv = New-Object System.Windows.Forms.ComboBox; $cmbEnv.Items.AddRange(@("LIVE", "TEST")); $cmbEnv.SelectedIndex=0; $cmbEnv.Location="0,20"; $cmbEnv.Width=90; $cmbEnv.BackColor=$colInputBg; $cmbEnv.ForeColor="White"; $cmbEnv.DropDownStyle="DropDownList"; $pnEnv.Controls.Add($cmbEnv)
$flowCon.Controls.Add($pnEnv)

$chkSave = New-Object System.Windows.Forms.CheckBox; $chkSave.Text="Save"; $chkSave.ForeColor="White"; $chkSave.AutoSize=$true; $chkSave.Margin=New-Object System.Windows.Forms.Padding(0,25,0,0); $flowCon.Controls.Add($chkSave)

# NEW UPGRADE CHECKBOX
$chkUpgrade = New-Object System.Windows.Forms.CheckBox; $chkUpgrade.Text="Enable Upgrade (SyncType=2)"; $chkUpgrade.ForeColor="Cyan"; $chkUpgrade.AutoSize=$true; $chkUpgrade.Checked=$true; $chkUpgrade.Margin=New-Object System.Windows.Forms.Padding(15,25,0,0); $flowCon.Controls.Add($chkUpgrade)

$chkAutoSync = New-Object System.Windows.Forms.CheckBox; $chkAutoSync.Text="Auto Update DB"; $chkAutoSync.ForeColor="Yellow"; $chkAutoSync.AutoSize=$true; $chkAutoSync.Checked=$true; $chkAutoSync.Margin=New-Object System.Windows.Forms.Padding(15,25,0,0); $flowCon.Controls.Add($chkAutoSync)

$btnCon = New-Object System.Windows.Forms.Button; $btnCon.Text="CONNECT"; $btnCon.Size="110,35"; $btnCon.BackColor=[System.Drawing.Color]::Crimson; $btnCon.ForeColor="White"; $btnCon.FlatStyle="Flat"; $btnCon.Margin=New-Object System.Windows.Forms.Padding(20,15,0,0); $flowCon.Controls.Add($btnCon)

# --- LIST & LOG ---
$split = New-Object System.Windows.Forms.TableLayoutPanel; $split.Dock="Fill"; $split.ColumnCount=2; $split.RowCount=1
$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 40)))
$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 60)))
[void]$masterGrid.Controls.Add($split, 0, 3)
$grpList = New-Object System.Windows.Forms.GroupBox; $grpList.Text=" Detected Targets "; $grpList.Dock="Fill"; $grpList.ForeColor=[System.Drawing.Color]::DeepSkyBlue; $grpList.Font=$fontHeader; $split.Controls.Add($grpList, 0, 0)
$pnlListInner = New-Object System.Windows.Forms.TableLayoutPanel; $pnlListInner.Dock="Fill"; $pnlListInner.RowCount=2; $pnlListInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 25))); $pnlListInner.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))); $grpList.Controls.Add($pnlListInner)
$chkAll = New-Object System.Windows.Forms.CheckBox; $chkAll.Text="Select All Databases"; $chkAll.ForeColor="White"; $chkAll.AutoSize=$true; $chkAll.Margin=New-Object System.Windows.Forms.Padding(5,0,0,0); $pnlListInner.Controls.Add($chkAll, 0, 0)
$listDBs = New-Object System.Windows.Forms.CheckedListBox; $listDBs.Dock="Fill"; $listDBs.BackColor=$colList; $listDBs.ForeColor="White"; $listDBs.BorderStyle="None"; $listDBs.Font=$fontNorm; $listDBs.CheckOnClick=$true; $pnlListInner.Controls.Add($listDBs, 0, 1)
$chkAll.Add_CheckedChanged({ for($i=0; $i -lt $listDBs.Items.Count; $i++){ $listDBs.SetItemChecked($i, $chkAll.Checked) } })
$grpLog = New-Object System.Windows.Forms.GroupBox; $grpLog.Text=" Activity Log "; $grpLog.Dock="Fill"; $grpLog.ForeColor=[System.Drawing.Color]::LimeGreen; $grpLog.Font=$fontHeader; $split.Controls.Add($grpLog, 1, 0)
$btnClear = New-Object System.Windows.Forms.Button; $btnClear.Text = "Clear Log"; $btnClear.Size = New-Object System.Drawing.Size(75, 23); $btnClear.Location = New-Object System.Drawing.Point(550, 15); $btnClear.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right; $btnClear.BackColor = [System.Drawing.Color]::DimGray; $btnClear.ForeColor="White"; $btnClear.FlatStyle="Flat"; $btnClear.Font=New-Object System.Drawing.Font("Segoe UI", 8); $grpLog.Controls.Add($btnClear)
$txtLog = New-Object System.Windows.Forms.RichTextBox; $txtLog.Dock="Fill"; $txtLog.BackColor=$colList; $txtLog.ForeColor="LightGray"; $txtLog.BorderStyle="None"; $txtLog.Font=$fontLog; $grpLog.Controls.Add($txtLog); $btnClear.Add_Click({ $txtLog.Clear() })

# --- ACTIONS ---
$pnlAct = New-Object System.Windows.Forms.TableLayoutPanel; $pnlAct.Dock="Fill"; $pnlAct.ColumnCount=3; $pnlAct.RowCount=2
$pnlAct.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$pnlAct.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
for($i=0; $i -lt 3; $i++){ $pnlAct.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.33))) }
$pnlAct.Padding = New-Object System.Windows.Forms.Padding(10,5,10,5)
[void]$masterGrid.Controls.Add($pnlAct, 0, 4)

$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="START SYNC PACKAGE"; $btnSync.Dock="Fill"; $btnSync.BackColor=[System.Drawing.Color]::DeepSkyBlue; $btnSync.ForeColor="White"; $btnSync.FlatStyle="Flat"; $btnSync.Font=$fontHeader; $pnlAct.Controls.Add($btnSync, 0, 0)
$btnCopyDB = New-Object System.Windows.Forms.Button; $btnCopyDB.Text="COPY TO TRAIN/TEST"; $btnCopyDB.Dock="Fill"; $btnCopyDB.BackColor=[System.Drawing.Color]::Teal; $btnCopyDB.ForeColor="White"; $btnCopyDB.FlatStyle="Flat"; $btnCopyDB.Font=$fontHeader; $btnCopyDB.Margin=New-Object System.Windows.Forms.Padding(10,0,10,0); $pnlAct.Controls.Add($btnCopyDB, 1, 0)
$btnVer = New-Object System.Windows.Forms.Button; $btnVer.Text="CHECK VERSION"; $btnVer.Dock="Fill"; $btnVer.BackColor=[System.Drawing.Color]::DarkOrange; $btnVer.ForeColor="White"; $btnVer.FlatStyle="Flat"; $btnVer.Font=$fontHeader; $pnlAct.Controls.Add($btnVer, 2, 0)
$btnBackup = New-Object System.Windows.Forms.Button; $btnBackup.Text="BACKUP JOBS & PARAMS"; $btnBackup.Dock="Fill"; $btnBackup.BackColor=[System.Drawing.Color]::MediumPurple; $btnBackup.ForeColor="White"; $btnBackup.FlatStyle="Flat"; $btnBackup.Font=$fontHeader; $pnlAct.Controls.Add($btnBackup, 0, 1)
$btnRestore = New-Object System.Windows.Forms.Button; $btnRestore.Text="RESTORE JOBS & PARAMS"; $btnRestore.Dock="Fill"; $btnRestore.BackColor=[System.Drawing.Color]::DarkSlateBlue; $btnRestore.ForeColor="White"; $btnRestore.FlatStyle="Flat"; $btnRestore.Font=$fontHeader; $btnRestore.Margin=New-Object System.Windows.Forms.Padding(10,0,10,0); $pnlAct.Controls.Add($btnRestore, 1, 1)
$btnDeleteDB = New-Object System.Windows.Forms.Button; $btnDeleteDB.Text="DELETE DATABASE"; $btnDeleteDB.Dock="Fill"; $btnDeleteDB.BackColor=[System.Drawing.Color]::Crimson; $btnDeleteDB.ForeColor="White"; $btnDeleteDB.FlatStyle="Flat"; $btnDeleteDB.Font=$fontHeader; $pnlAct.Controls.Add($btnDeleteDB, 2, 1)

# --- STATUS ---
$stat = New-Object System.Windows.Forms.StatusStrip; $stat.BackColor=[System.Drawing.Color]::FromArgb(30,30,30); $lblStat = New-Object System.Windows.Forms.ToolStripStatusLabel; $lblStat.Text="Ready."; $lblStat.ForeColor="White"; $stat.Items.Add($lblStat); [void]$masterGrid.Controls.Add($stat, 0, 5)

# ======================================================================
#  CORE FUNCTIONS
# ======================================================================

function Log($msg, $color="White") { 
    $txtLog.SelectionStart=$txtLog.TextLength
    $txtLog.SelectionColor=[System.Drawing.Color]::FromName($color)
    $txtLog.AppendText("$msg`r`n")
    $txtLog.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
    
    try { Add-Content -Path $Script:SessionLogFile -Value "[$(Get-Date -Format 'HH:mm:ss')] $msg" } catch {}
}

function Toggle($s) { $btnCon.Enabled=$s; $btnSync.Enabled=$s; $btnBackup.Enabled=$s; $btnRestore.Enabled=$s; $btnVer.Enabled=$s; $btnCreateDB.Enabled=$s; $btnCopyDB.Enabled=$s; $btnDeleteDB.Enabled=$s; }

function Save-Creds {
    if ($chkSave.Checked) {
        $pw = $txtP.Text | ConvertTo-SecureString -AsPlainText -Force
        [PSCustomObject]@{ Server=$txtS.Text; User=$txtU.Text; Password=$pw } | Export-Clixml -Path $Script:CredFile
    } else { if (Test-Path $Script:CredFile) { Remove-Item $Script:CredFile -Force } }
}

function Load-Creds {
    if (Test-Path $Script:CredFile) {
        try {
            $c = Import-Clixml $Script:CredFile
            $txtS.Text=$c.Server; $txtU.Text=$c.User
            $txtP.Text=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($c.Password))
            $chkSave.Checked=$true
        } catch {}
    }
}

function Scan-Server {
    param($Target)
    $Script:TargetServer = $Target
    $Script:IsRemote = ($Target -ne "localhost" -and $Target -ne $env:COMPUTERNAME -and $Target -ne "127.0.0.1")
    $Block = {
        $Result = [PSCustomObject]@{ Valid=$false; Version="Not Found"; Path=$null; InstallPath=$null }
        $CommonPaths = @()
        if ($env:ProgramFiles) { $CommonPaths += Join-Path $env:ProgramFiles "ProPhoenix\Server Application Manager\AppReg_Main.xml" }
        if (${env:ProgramFiles(x86)}) { $CommonPaths += Join-Path ${env:ProgramFiles(x86)} "ProPhoenix\Server Application Manager\AppReg_Main.xml" }
        $Dirs = @("ProPhoenix\Server Application Manager", "Program Files (x86)\ProPhoenix\Server Application Manager", "Phoenix Server Application Manager")
        foreach ($d in Get-PSDrive -PSProvider FileSystem) {
            foreach ($sub in $Dirs) {
                $p = Join-Path $d.Root $sub | Join-Path -ChildPath "Appreg_main.xml"
                if (Test-Path $p) { $CommonPaths += $p }
            }
        }
        foreach($p in $CommonPaths) { if(Test-Path $p) { $FoundPath=$p; break } }
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
                    $Script:WindowsCreds = $host.ui.PromptForCredential("Remote Admin", "Enter Admin Creds", "$Target\Administrator", "")
                    if ($Script:WindowsCreds) { $Args.Credential = $Script:WindowsCreds; $Data = Invoke-Command @Args } else { throw "Cancelled" }
                } else { throw $_ }
            }
        } else { $Data = Invoke-Command -ScriptBlock $Block }
        if ($Data.Valid) {
            $Script:DBSyncRoot = Join-Path $Data.InstallPath "DB Sync"
            $txtPath.Text = $Script:DBSyncRoot
            $lblVerDisplay.Text = "Ver: $($Data.Version)"; $lblVerDisplay.ForeColor = [System.Drawing.Color]::LimeGreen
            Log "✔ Found Utility: $($Data.Version)" "Lime"
            $Script:AppMgrPath = Join-Path (Split-Path $Data.Path -Parent) "PnxAppMgr.exe"
        } else { $lblVerDisplay.Text = "Not Found"; $lblVerDisplay.ForeColor = "Red"; $Script:DBSyncRoot = $null }
    } catch { Log "Scan Error: $($_.Exception.Message)" "Red" }
}

$btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select DB Sync Folder"
    if ($fbd.ShowDialog() -eq "OK") { $txtPath.Text=$fbd.SelectedPath; $Script:DBSyncRoot=$fbd.SelectedPath; Log "Path Set Manually." "Gray" }
})

# --- REUSABLE SYNC FUNCTION (MANUAL UPGRADE ACCEPTANCE) ---
function Execute-DBSync {
    param($Items)
    if ($Items.Count -eq 0) { return }
    
    $FailedDBs = @()

    foreach ($i in $Items) {
        $I = $Script:TargetMap[$i]; $D = $I.DB; $F = $I.Folder
        $XmlPath = "$($Script:DBSyncRoot)\$F\PnxAutoNewDBSyn.xml"

        Log "Updating $D..." "Cyan"; [System.Windows.Forms.Application]::DoEvents()
        
        try {
            if ($F -eq "None") { 
                Log "   ! Skipped: No Utility Folder Mapped" "Orange"
                continue 
            }
            
            $WD = "$($Script:DBSyncRoot)\$F"
            if (!(Test-Path "$WD\PnxDBSync.exe")) { 
                Log "   ! Skipped: Missing EXE in $WD" "Orange"
                continue 
            }

            # 1. PRE-CLEANUP: Kill Sessions & Drop Orphaned Temp DBs
            try {
                $killCS = "Server=$($txtS.Text);Database=master;User Id=$($txtU.Text);Password=$($txtP.Text);Connection Timeout=15"
                $killCN = New-Object System.Data.SqlClient.SqlConnection($killCS); $killCN.Open()
                $killCmd = $killCN.CreateCommand()
                
                # Drop locks on target DB
                $killCmd.CommandText = "DECLARE @k1 varchar(8000) = ''; SELECT @k1 = @k1 + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$D'); EXEC(@k1);"
                $killCmd.ExecuteNonQuery() | Out-Null
                
                # Drop orphaned PnxDBSync Temp DB
                $tempDbName = "$D" + "PnxDBSync"
                $killCmd.CommandText = "IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$tempDbName') BEGIN DECLARE @k2 varchar(8000) = ''; SELECT @k2 = @k2 + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$tempDbName'); EXEC(@k2); EXEC('ALTER DATABASE [$tempDbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$tempDbName];'); END"
                $killCmd.ExecuteNonQuery() | Out-Null
                
                $killCN.Close()
                Log "   > Cleared locks and removed old Temp databases" "DarkGray"
                Start-Sleep -Seconds 2 # Lock release buffer
            } catch {}

            # 2. EXACT XML GENERATION
            if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }

            # Dynamically set SyncType based on user Checkbox
            $syncMode = if ($chkUpgrade.Checked) { "2" } else { "1" }

            $XmlString = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
	<SourceServer>
		<IPAddress>$($txtS.Text)</IPAddress> 
		<DBName>$D</DBName> <UserName>$($txtU.Text)</UserName> 
		<Password>$($txtP.Text)</Password> 
		<JurisID>1000</JurisID> <State>MA</State> <JurisName>ProPhoenix</JurisName> <JurisAlias>PNX</JurisAlias> <SyncType>$syncMode</SyncType> </SourceServer>
</PnxPakager>
"@
            # Writing exactly as UTF8 to preserve C# compatibility
            $XmlString | Out-File -FilePath $XmlPath -Encoding UTF8 -Force

            # 3. VISIBLE EXECUTION (Wait for user to manually click YES)
            if ($chkUpgrade.Checked) {
                Log "   > Mode = Upgrade (2). Please click 'Yes' on the prompt if it appears." "Yellow"
            } else {
                Log "   > Mode = Standard Sync (1)." "Cyan"
            }

            $SyncProc = Start-Process "$WD\PnxDBSync.exe" -WorkingDirectory $WD -WindowStyle Normal -PassThru
            
            # Non-blocking UI loop while waiting for the tool to finish
            while (-not $SyncProc.HasExited) {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 250
            }
            
            if ($SyncProc.ExitCode -eq 0) {
                Log "   ✔ Sync Completed Successfully" "Lime"
            } else {
                $FailedDBs += $D
                Log "   ❌ Sync Process Crashed! (Code: $($SyncProc.ExitCode))" "Red"
            }

        } catch { 
            Log "   ❌ Exception during execution: $($_.Exception.Message)" "Red" 
            $FailedDBs += $D
        } finally {
            # 4. POST-CLEANUP
            if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
            try {
                $killCS = "Server=$($txtS.Text);Database=master;User Id=$($txtU.Text);Password=$($txtP.Text);Connection Timeout=15"
                $killCN = New-Object System.Data.SqlClient.SqlConnection($killCS); $killCN.Open()
                $killCmd = $killCN.CreateCommand()
                $tempDbName = "$D" + "PnxDBSync"
                $killCmd.CommandText = "IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$tempDbName') BEGIN DECLARE @k2 varchar(8000) = ''; SELECT @k2 = @k2 + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$tempDbName'); EXEC(@k2); EXEC('ALTER DATABASE [$tempDbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$tempDbName];'); END"
                $killCmd.ExecuteNonQuery() | Out-Null
                $killCN.Close()
            } catch {}
        }
    }

    if ($FailedDBs.Count -gt 0) {
        $msg = "The following databases encountered hard crashes during sync:`n`n" + ($FailedDBs -join "`n")
        [System.Windows.Forms.MessageBox]::Show($msg, "Sync Completed with Hard Errors", "OK", "Warning")
    } else {
        Log "✔ All databases processed successfully." "Lime"
    }
}

# --- CONNECT ---
$btnCon.Add_Click({
    Toggle $false; $listDBs.Items.Clear(); $Script:TargetMap=@{}
    Log "Session Log: $($Script:SessionLogFile)" "Gray"
    Log "Connecting in [$($cmbEnv.SelectedItem)] Mode..." "White"
    try {
        $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=5"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $da = New-Object System.Data.SqlClient.SqlDataAdapter("SELECT Name FROM sys.databases WHERE database_id>4 AND Name NOT IN ('master','model','msdb','tempdb','ReportServer') ORDER BY Name", $cn)
        $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        Log "✔ Connected." "Lime"; $lblStat.Text = "Connected."; Save-Creds; Scan-Server $txtS.Text 

        # --- FIX: ROBUST INSTALL WAIT LOOP ---
        if ($chkAutoSync.Checked -and $Script:AppMgrPath -and (Test-Path $Script:AppMgrPath)) {
            Log "Auto-Uninstalling old utility..." "Yellow"; [System.Windows.Forms.Application]::DoEvents()
            $Dir = Split-Path $Script:AppMgrPath -Parent
            Start-Process $Script:AppMgrPath -ArgumentList "UNINSTALL DBUtility" -WorkingDirectory $Dir -WindowStyle Hidden -Wait
            
            Start-Sleep -Seconds 2
            [System.Windows.Forms.Application]::DoEvents()

            Log "Auto-Installing new utility..." "Yellow"; [System.Windows.Forms.Application]::DoEvents()
            Start-Process $Script:AppMgrPath -ArgumentList "INSTALL DBUtility" -WorkingDirectory $Dir -WindowStyle Hidden -Wait
            
            Log "Waiting for file extraction..." "DarkGray"; [System.Windows.Forms.Application]::DoEvents()
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
                Log "✔ AppMgr Refreshed & Utility Verified." "Lime"
            }
        }

        # --- CATEGORY LOGIC ---
        $EnvMode = $cmbEnv.SelectedItem

        foreach ($row in $ds.Tables[0].Rows) {
            $db = $row.Name; $Folder = $null; $Tag = ""; $Type = ""
            
            $IsTrain = ($db -match "Tr" -or $db -match "Train")
            $IsTest = ($db -match "Test" -and -not $IsTrain) 
            $IsMaster = ($db -match "Master")

            if ($EnvMode -eq "LIVE") { if ($IsTest) { continue } } 
            else { if (-not $IsTest -and -not $IsMaster) { continue } }

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
            $listDBs.Items.Add($Key, $chkAutoSync.Checked)
            $Script:TargetMap[$Key] = @{ DB=$db; Folder=$Folder }
        }
        if($listDBs.Items.Count -gt 0){ Log "   + Listed & Grouped Databases" "Cyan" }

        if ($chkAutoSync.Checked) {
            Log "Initiating Automatic DB Sync for all targets..." "Yellow"; [System.Windows.Forms.Application]::DoEvents()
            Execute-DBSync $listDBs.CheckedItems
        }

    } catch { Log "❌ Error: $($_.Exception.Message)" "Red" } finally { Toggle $true }
})

# --- DELETE DB ---
$btnDeleteDB.Add_Click({
    if($listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database to Delete!", "Warning", "OK", "Warning"); return }
    $Targets = @(); foreach($i in $listDBs.CheckedItems){ $Targets += $Script:TargetMap[$i].DB }
    $Names = $Targets -join ", "
    if([System.Windows.Forms.MessageBox]::Show("DELETE DATABASE(S): $Names`n`nThis will PERMANENTLY REMOVE the database and files (.mdf/.ldf).`n`nAre you absolutely sure?", "CRITICAL WARNING", "YesNo", "Error") -ne "Yes"){ return }
    if([System.Windows.Forms.MessageBox]::Show("Double Check: Delete $Names?", "Final Confirmation", "YesNo", "Error") -ne "Yes"){ return }
    Toggle $false; Log "Deleting Databases..." "Red"
    try {
        $CS="Server=$($txtS.Text);Database=master;User Id=$($txtU.Text);Password=$($txtP.Text);Connection Timeout=30"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
        foreach($DB in $Targets){
            Log "Dropping $DB..." "Orange"; [System.Windows.Forms.Application]::DoEvents()
            
            $KillCmd = New-Object System.Data.SqlClient.SqlCommand("IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$DB') BEGIN DECLARE @kill varchar(8000) = ''; SELECT @kill = @kill + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$DB'); EXEC(@kill); END", $CN)
            try { $KillCmd.ExecuteNonQuery()|Out-Null } catch {}

            $Cmd=$CN.CreateCommand()
            $Cmd.CommandTimeout = 0
            $Cmd.CommandText = "IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$DB') BEGIN ALTER DATABASE [$DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$DB]; END"
            $Cmd.ExecuteNonQuery()|Out-Null
            Log "   ✔ Deleted $DB" "Red"
        }
        $CN.Close(); $btnCon.PerformClick()
    } catch { Log "❌ Error: $($_.Exception.Message)" "Red" } finally { Toggle $true }
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
        $CS="Server=$($txtS.Text);Database=$TargetDB;User Id=$($txtU.Text);Password=$($txtP.Text);Connection Timeout=15"; $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
        
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

$btnCopyDB.Add_Click({
    if($listDBs.CheckedItems.Count -ne 1){ [System.Windows.Forms.MessageBox]::Show("Select exactly ONE source database.", "Warning", "OK", "Warning"); return }
    $SourceDB = $Script:TargetMap[$listDBs.CheckedItems[0]].DB
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

    Toggle $false; Log "Analyzing $SourceDB..." "Cyan"
    try {
        $CS="Server=$($txtS.Text);Database=master;User Id=$($txtU.Text);Password=$($txtP.Text);Connection Timeout=30"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS)
        
        $CN.FireInfoMessageEventOnUserErrors = $true
        $CN.add_InfoMessage({ param($sender, $e) if ($e.Message -match "percent processed" -or $e.Message -match "processed.") { Log "   > $($e.Message)" "DarkGray" } })
        $CN.Open()
        
        $Cmd=$CN.CreateCommand()
        $Cmd.CommandTimeout = 0
        $Cmd.CommandText="SELECT CAST(SUM(size)*8/1024 AS VARCHAR) FROM sys.master_files WHERE database_id=DB_ID('$SourceDB')"; $SizeMB=$Cmd.ExecuteScalar()
        $Cmd.CommandText="SELECT physical_name FROM sys.master_files WHERE database_id=DB_ID('$SourceDB') AND type=0"; $Mdf=$Cmd.ExecuteScalar()
        
        if([System.Windows.Forms.MessageBox]::Show("SOURCE: $SourceDB`nSIZE: $SizeMB MB`nFILE: $Mdf`n`nProceed with Backup?", "Confirm", "YesNo", "Question") -ne "Yes"){ $CN.Close(); Toggle $true; return }
        
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select Backup Location"; $fbd.SelectedPath = $Script:DefaultBackup
        if($fbd.ShowDialog() -ne "OK"){ $CN.Close(); Toggle $true; return }
        $BackupPath = $fbd.SelectedPath
        $BakFile = Join-Path $BackupPath "$SourceDB`_Copy.bak"

        Log "Backing up to $BakFile (WITH LIVE PROGRESS)..." "White"; [System.Windows.Forms.Application]::DoEvents()
        $Cmd.CommandText="BACKUP DATABASE [$SourceDB] TO DISK='$BakFile' WITH COPY_ONLY, INIT, FORMAT, COMPRESSION, STATS=10"
        $Cmd.ExecuteNonQuery()|Out-Null
        Log "   ✔ Backup Complete (Compressed)" "Lime"
        
        $BkpInfo = Get-Item $BakFile; $NewSize = [math]::Round($BkpInfo.Length / 1MB, 2)
        if([System.Windows.Forms.MessageBox]::Show("Backup: $NewSize MB`nTarget: $TargetDB`n`nWARNING: Overwriting $TargetDB. Proceed?", "Confirm Restore", "YesNo", "Warning") -ne "Yes"){ $CN.Close(); Toggle $true; return }
        
        Log "Setting $TargetDB to Single User..." "Orange"; [System.Windows.Forms.Application]::DoEvents()
        try { 
            $CmdDrop = New-Object System.Data.SqlClient.SqlCommand("IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$TargetDB') BEGIN DECLARE @kill varchar(8000) = ''; SELECT @kill = @kill + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$TargetDB'); EXEC(@kill); ALTER DATABASE [$TargetDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; END", $CN)
            $CmdDrop.CommandTimeout = 0
            $CmdDrop.ExecuteNonQuery()|Out-Null 
        } catch { Log "   > Notice: Could not force Single User" "DarkGray" }

        Log "Restoring (WITH LIVE PROGRESS)..." "White"; [System.Windows.Forms.Application]::DoEvents()
        $Cmd.CommandText="RESTORE FILELISTONLY FROM DISK='$BakFile'"; $Rdr=$Cmd.ExecuteReader(); $Files=@(); while($Rdr.Read()){$Files+=@{L=$Rdr["LogicalName"];P=$Rdr["PhysicalName"];T=$Rdr["Type"]}}; $Rdr.Close()
        
        $MoveStr = ""; foreach($f in $Files){ 
            $Ext=[System.IO.Path]::GetExtension($f.P); $Dir=[System.IO.Path]::GetDirectoryName($f.P)
            $NewName = "$TargetDB"; if ($f.T -eq "L") { $NewName += "_log" }; $NewName += $Ext
            $NewPath = Join-Path $Dir $NewName
            $MoveStr += "MOVE '$($f.L)' TO '$NewPath', " 
        }

        Log "   > Bypassing tail-log backup (uncheck status)..." "DarkGray"
        $Cmd.CommandText="RESTORE DATABASE [$TargetDB] FROM DISK='$BakFile' WITH RECOVERY, REPLACE, STATS=10, $($MoveStr.TrimEnd(', '))"
        $Cmd.ExecuteNonQuery()|Out-Null
        
        $Cmd.CommandText = "ALTER DATABASE [$TargetDB] SET MULTI_USER"; $Cmd.ExecuteNonQuery()|Out-Null
        Log "   ✔ Restore Complete" "Lime"

        if ($ConfigFilePath -and (Test-Path $ConfigFilePath)) {
            Log "Applying Enterprise Configuration Backup to $TargetDB..." "Yellow"
            Apply-EnterpriseConfig -TargetDB $TargetDB -SourceFile $ConfigFilePath
        } else {
            Log "Applying Default Safe Hardcoded Configuration..." "Yellow"
            $CleanCN = New-Object System.Data.SqlClient.SqlConnection("Server=$($txtS.Text);Database=$TargetDB;User Id=$($txtU.Text);Password=$($txtP.Text)"); $CleanCN.Open()
            
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
            Log "   ✔ Final Default Cleanup Done" "Lime"
            $CleanCN.Close()
        }
        
        $CN.Close(); $btnCon.PerformClick()

    } catch { Log "❌ Failed: $($_.Exception.Message)" "Red" } finally { Toggle $true }
})

# --- ENTERPRISE BACKUP PARAMS ---
$btnBackup.Add_Click({
    if($listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select DBs to Backup!", "Warning", "OK", "Warning"); return }
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select Folder to Save Backups"; $fbd.SelectedPath = $Script:DefaultBackup
    if($fbd.ShowDialog() -ne "OK"){ return }
    $TargetDirBase = $fbd.SelectedPath

    Toggle $false; Log "Starting Configuration Backup..." "Cyan"; $TS=Get-Date -Format "yyyyMMdd_HHmm"

    foreach ($item in $listDBs.CheckedItems) {
        $DB = $Script:TargetMap[$item].DB
        Log "Backing up Configuration for $DB..." "White"; [System.Windows.Forms.Application]::DoEvents()
        
        $BackupLines = New-Object System.Collections.Generic.List[String]
        $BackupLines.Add("# ProPhoenix Database Configuration Backup")
        $BackupLines.Add("# Database: $DB")
        $BackupLines.Add("# Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
        $BackupLines.Add("")
        
        try {
            $CS="Server=$($txtS.Text);Database=$DB;User Id=$($txtU.Text);Password=$($txtP.Text);Connection Timeout=15"
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
            Log "   + Exported $paramCount Parameters" "Lime"
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
            Log "   + Exported $($tempJobs.Count) KPI Jobs" "Lime"
            
            $SavePath = Join-Path $TargetDirBase "$($DB)_ConfigBackup_$TS.txt"
            [IO.File]::WriteAllLines($SavePath, $BackupLines)
            Log "   ✔ Saved to $(Split-Path $SavePath -Leaf)" "Yellow"
            
            $CN.Close()
        } catch { Log "   ❌ Failed: $($_.Exception.Message)" "Red" }
    }
    Log "Backup Complete." "Cyan"; Toggle $true
})

# --- ENTERPRISE RESTORE PARAMS ---
$btnRestore.Add_Click({
    if($listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select DBs to Restore!", "Warning", "OK", "Warning"); return }
    $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Filter="Text Backup (*.txt)|*.txt"; $f.InitialDirectory=$Script:DefaultBackup; 
    if($f.ShowDialog()-ne"OK"){return}; $SourceFile=$f.FileName
    
    if([System.Windows.Forms.MessageBox]::Show("RESTORE Configuration from:`n$SourceFile`n`nAre you absolutely sure?", "Confirm", "YesNo", "Warning") -ne "Yes"){ return }
    
    Toggle $false; Log "Parsing Configuration File..." "Orange"; [System.Windows.Forms.Application]::DoEvents()
    
    foreach ($item in $listDBs.CheckedItems) {
        $DB=$Script:TargetMap[$item].DB; Log "Restoring Config to $DB..." "White"; [System.Windows.Forms.Application]::DoEvents()
        Apply-EnterpriseConfig -TargetDB $DB -SourceFile $SourceFile
    }
    Log "Restore Process Complete." "Cyan"
    Toggle $true
})

# --- SYNC BUTTON LOGIC ---
$btnSync.Add_Click({ 
    if($listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database(s) to Sync!", "Warning", "OK", "Warning"); return }
    Toggle $false; Execute-DBSync $listDBs.CheckedItems; Toggle $true 
})

# --- VER & INSTALL ---
$btnVer.Add_Click({ 
    if($listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database(s) first!", "Warning", "OK", "Warning"); return }
    Toggle $false; Log "Checking Versions..." "Cyan"; Scan-Server $txtS.Text; try { $cn=New-Object System.Data.SqlClient.SqlConnection("Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master"); $cn.Open(); foreach($i in $listDBs.CheckedItems){ $D=$Script:TargetMap[$i].DB; $cmd=$cn.CreateCommand(); $cmd.CommandText="SELECT Version FROM [$D].dbo.KPIDBVersion"; try{ $v=$cmd.ExecuteScalar(); Log "$D : $v" "White" }catch{Log "$D : Error" "Red"} }; $cn.Close() } catch {} finally { Toggle $true } 
})

$RunAppMgr = { param($Mode)
    if ([string]::IsNullOrWhiteSpace($Script:AppMgrPath) -or !(Test-Path $Script:AppMgrPath)) {
        if ($txtPath.Text -and (Test-Path $txtPath.Text)) { $Script:AppMgrPath = Join-Path (Split-Path $txtPath.Text -Parent) "PnxAppMgr.exe" }
        if (!($Script:AppMgrPath) -or !(Test-Path $Script:AppMgrPath)) {
            [System.Windows.Forms.MessageBox]::Show("Please locate PnxAppMgr.exe"); $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Filter="PnxAppMgr.exe|PnxAppMgr.exe"; if($f.ShowDialog()-eq"OK"){$Script:AppMgrPath=$f.FileName}else{return}
        }
    }
    $Bat = Join-Path $env:TEMP "PnxAction.bat"; $Dir = Split-Path $Script:AppMgrPath -Parent
    Set-Content $Bat "@echo off`ncd /d `"$Dir`"`n`"$($Script:AppMgrPath)`" `"$Mode`" `"DBUtility`"`npause"; Start-Process $Bat -Verb RunAs
}
$btnCreateDB.Add_Click({ if(!$Script:DBSyncRoot){return}; $d=Show-NewDBDialog; if(!$d){return}; Toggle $false; Log "Creating..." "Cyan"; try{ $Folder=$d.Cat; $TargetDir=Join-Path $Script:DBSyncRoot $Folder; if(!(Test-Path $TargetDir)){$Folder=$Folder.Replace(" ","");$TargetDir=Join-Path $Script:DBSyncRoot $Folder}; [xml]$x=Get-Content $Script:XmlTarget; $x.PnxPakager.SourceServer.IPAddress=$txtS.Text; $x.PnxPakager.SourceServer.DBName=$d.DB; $x.PnxPakager.SourceServer.UserName=$txtU.Text; $x.PnxPakager.SourceServer.Password=$txtP.Text; $x.PnxPakager.SourceServer.JurisID=$d.JID; $x.PnxPakager.SourceServer.State=$d.St; $x.PnxPakager.SourceServer.JurisName=$d.Nm; $x.PnxPakager.SourceServer.JurisAlias=$d.Al; $x.PnxPakager.SourceServer.SyncType="1"; $x.Save("$TargetDir\PnxAutoNewDBSyn.xml"); Start-Process "$TargetDir\PnxDBSync.exe" -WorkingDirectory $TargetDir -Verb RunAs -Wait; Log "✔ Created" "Lime"; $btnCon.PerformClick() }catch{Log "Err" "Red"} finally { Toggle $true } })
$btnInstall.Add_Click({ & $RunAppMgr "INSTALL" }); $btnUninstall.Add_Click({ & $RunAppMgr "UNINSTALL" })

# --- INIT ---
function Show-NewDBDialog { $dbForm=New-Object System.Windows.Forms.Form;$dbForm.Text="Create DB";$dbForm.Size="400,380";$dbForm.StartPosition="CenterParent";$lblC=New-Object System.Windows.Forms.Label;$lblC.Text="Category:";$lblC.Location="20,30";$dbForm.Controls.Add($lblC);$cmbCat=New-Object System.Windows.Forms.ComboBox;$cmbCat.Items.AddRange(@("Police","Fire","Phoenix Master","IA","Police CSP","Fire CSP"));$cmbCat.SelectedIndex=0;$cmbCat.Location="120,27";$cmbCat.Width=240;$dbForm.Controls.Add($cmbCat);function Add-Field($lbl,$y,$def){$l=New-Object System.Windows.Forms.Label;$l.Text=$lbl;$l.Location="20,$y";$dbForm.Controls.Add($l);$t=New-Object System.Windows.Forms.TextBox;$t.Text=$def;$t.Location="120,$($y-3)";$t.Width=240;$dbForm.Controls.Add($t);return $t};$inDB=Add-Field "Database" 70 "PhoenixPolice";$inJID=Add-Field "JurisID" 110 "1000";$inSt=Add-Field "State" 150 "MA";$inN=Add-Field "Name" 190 "ProPhoenix";$inA=Add-Field "Alias" 230 "PNX";$btn=New-Object System.Windows.Forms.Button;$btn.Text="CREATE";$btn.DialogResult="OK";$btn.Location="120,280";$dbForm.Controls.Add($btn);$dbForm.AcceptButton=$btn;if($dbForm.ShowDialog()-eq"OK"){return @{DB=$inDB.Text;JID=$inJID.Text;St=$inSt.Text;Nm=$inN.Text;Al=$inA.Text;Cat=$cmbCat.SelectedItem}} return $null }
$form.Add_Load({ Load-Creds }); $form.Add_Shown({$form.Activate()}); [void]$form.ShowDialog()