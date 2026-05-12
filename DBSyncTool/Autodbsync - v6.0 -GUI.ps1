# ======================================================================
#  ProPhoenix DB Utility Dashboard - v6.0 
# ======================================================================
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Data") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"

# Session Logging Setup
$Script:SessionLogDir = Join-Path $Script:SetupPath "SessionLogs"
if (!(Test-Path $Script:SessionLogDir)) { New-Item -ItemType Directory -Force -Path $Script:SessionLogDir | Out-Null }
$Script:SessionLogFile = Join-Path $Script:SessionLogDir "StatusReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:CredFile  = Join-Path $Script:SetupPath "SavedCreds.xml"
$Script:DefaultBackup = "C:\RMS_Master_Backups"
$Script:BgImage   = Join-Path $Script:SetupPath "background.png" 
if (!(Test-Path $Script:BgImage)) { $Script:BgImage = Join-Path $Script:SetupPath "background.jpg" }
$Script:LogoFile  = Join-Path $Script:SetupPath "logo.png"

# --- JOB CONFIGURATIONS (Hardcoded Baseline) ---
$Script:PoliceJobParams = @{
    "WDAAppDataExporter"             = @{ Instance="CAD test"; Folder="\\PROTESTSRV\Fire Response CAD Webservice" }
    "ReportWriterStaticDataExporter" = @{ Instance="CAD test"; Folder="\\PROTESTSRV\Phoenix Report Writer API" }
    "FireLiveDataExporter"           = @{ Instance="CAD test"; Folder="\\PROTESTSRV\Fire Response CAD Webservice" }
    "PhoenixBOTQAUploader"           = @{ Folder="\\PROTESTSRV\Attachment\Job" }
    "KPICleaner"                     = @{ Folder="\\PROTESTSRV\Police RMS\Log" }
    "CADStaticDataExtractor"         = @{ MultiFolder=@("\\Protestsrv\ftp\CAD DATA\KPIDATA", "\\Protestsrv\ftp\WDA DATA\KPIDATA") }
    "Hot Sheet"                      = @{ MultiFolder=@("\\PROTESTSRV\Bolo", "\\PROTESTSRV\Hot Sheet") }
}
$Script:FireJobParams = @{
    "FireLiveDataExporter" = @{ Instance="CAD test"; Folder="\\PROTESTSRV\Fire Response CAD Webservice" }
    "FireRMSDataExporter"  = @{ Folder="\\PROTESTSRV\Fire Webservice" }
    "WDAAppDataExporter"   = @{ Instance="CAD test"; Folder="\\PROTESTSRV\Fire Response CAD Webservice" }
}
$Script:IAJobParams = @{ "KPICleaner" = @{ Folder="\\PROTESTSRV\IA RMS\Log" } }

# Known Jobs to Scan
$Script:KnownJobs = @("WDAAppDataExporter", "ReportWriterStaticDataExporter", "FireLiveDataExporter", "PhoenixBOTQAUploader", "KPICleaner", "CADStaticDataExtractor", "Hot Sheet", "FireRMSDataExporter")

# --- DETECT PATHS ---
if (!(Test-Path $Script:SetupPath)) { New-Item -ItemType Directory -Force -Path $Script:SetupPath | Out-Null }
if (!(Test-Path $Script:DefaultBackup)) { New-Item -ItemType Directory -Force -Path $Script:DefaultBackup | Out-Null }
if (!(Test-Path $Script:XmlTarget)) { 
    Set-Content -Path $Script:XmlTarget -Value '<?xml version="1.0" encoding="utf-8" ?><PnxPakager><SourceServer><IPAddress>LOCALHOST</IPAddress><DBName>DBName</DBName><UserName>sa</UserName><Password>pnx</Password><JurisID>1000</JurisID><State>MA</State><JurisName>ProPhoenix</JurisName><JurisAlias>PNX</JurisAlias><SyncType>2</SyncType></SourceServer></PnxPakager>' -Force 
}

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
$form.Text = "ProPhoenix DB Utility Dashboard v6.0"
$form.Size = New-Object System.Drawing.Size(1250, 900) 
$form.StartPosition = "CenterScreen"
$form.BackColor = $colBg
$form.ForeColor = $colText
if (Test-Path $Script:BgImage) { $form.BackgroundImage = [System.Drawing.Image]::FromFile($Script:BgImage); $form.BackgroundImageLayout = "Zoom" }

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
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Fill"
$picLogo = New-Object System.Windows.Forms.PictureBox; $picLogo.Size="160,50"; $picLogo.Location="15,10"; $picLogo.SizeMode="Zoom"; if(Test-Path $Script:LogoFile){$picLogo.Image=[System.Drawing.Image]::FromFile($Script:LogoFile)}; $pnlHead.Controls.Add($picLogo)
$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="DB Sync Dashboard"; $lblTitle.AutoSize=$true; $lblTitle.Location="190,15"; $lblTitle.Font=$fontTitle; $lblTitle.ForeColor=[System.Drawing.Color]::DodgerBlue; $pnlHead.Controls.Add($lblTitle)
$lblPath = New-Object System.Windows.Forms.Label; $lblPath.Text="Utility Path:"; $lblPath.Location="600,15"; $lblPath.AutoSize=$true; $lblPath.ForeColor="Gray"; $pnlHead.Controls.Add($lblPath)
$txtPath = New-Object System.Windows.Forms.TextBox; $txtPath.Location="680,12"; $txtPath.Size="350,25"; $txtPath.BackColor=$colInputBg; $txtPath.ForeColor="White"; $txtPath.BorderStyle="FixedSingle"; $pnlHead.Controls.Add($txtPath)
$btnBrowse = New-Object System.Windows.Forms.Button; $btnBrowse.Text="Browse"; $btnBrowse.Location="1040,12"; $btnBrowse.Size="80,25"; $btnBrowse.BackColor=$colBtn; $btnBrowse.ForeColor="White"; $btnBrowse.FlatStyle="Flat"; $pnlHead.Controls.Add($btnBrowse)
$lblVerDisplay = New-Object System.Windows.Forms.Label; $lblVerDisplay.Text="Ver: --"; $lblVerDisplay.AutoSize=$false; $lblVerDisplay.TextAlign="Right"; $lblVerDisplay.Size="300,20"; $lblVerDisplay.Location="820,40"; $lblVerDisplay.ForeColor="Gray"; $pnlHead.Controls.Add($lblVerDisplay)
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
$txtU = Add-Input $flowCon "Username" 130 "sa"
$txtP = Add-Input $flowCon "Password" 130 "" $true

# ENVIRONMENT SELECTOR
$pnEnv = New-Object System.Windows.Forms.Panel; $pnEnv.Size=New-Object System.Drawing.Size(100,50)
$lbEnv = New-Object System.Windows.Forms.Label; $lbEnv.Text="Environment"; $lbEnv.AutoSize=$true; $lbEnv.ForeColor="White"; $lbEnv.Font=$fontNorm; $pnEnv.Controls.Add($lbEnv)
$cmbEnv = New-Object System.Windows.Forms.ComboBox; $cmbEnv.Items.AddRange(@("LIVE", "TEST")); $cmbEnv.SelectedIndex=0; $cmbEnv.Location="0,20"; $cmbEnv.Width=90; $cmbEnv.BackColor=$colInputBg; $cmbEnv.ForeColor="White"; $cmbEnv.DropDownStyle="DropDownList"; $pnEnv.Controls.Add($cmbEnv)
$flowCon.Controls.Add($pnEnv)

$chkSave = New-Object System.Windows.Forms.CheckBox; $chkSave.Text="Save"; $chkSave.ForeColor="White"; $chkSave.AutoSize=$true; $chkSave.Margin=New-Object System.Windows.Forms.Padding(0,25,0,0); $flowCon.Controls.Add($chkSave)
$chkAutoSync = New-Object System.Windows.Forms.CheckBox; $chkAutoSync.Text="Auto Update & Sync"; $chkAutoSync.ForeColor="Yellow"; $chkAutoSync.AutoSize=$true; $chkAutoSync.Checked=$true; $chkAutoSync.Margin=New-Object System.Windows.Forms.Padding(15,25,0,0); $flowCon.Controls.Add($chkAutoSync)
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
$grpLog = New-Object System.Windows.Forms.GroupBox; $grpLog.Text=" Activity Log (Live Progress) "; $grpLog.Dock="Fill"; $grpLog.ForeColor=[System.Drawing.Color]::LimeGreen; $grpLog.Font=$fontHeader; $split.Controls.Add($grpLog, 1, 0)
$btnClear = New-Object System.Windows.Forms.Button; $btnClear.Text = "Clear Log"; $btnClear.Size = New-Object System.Drawing.Size(75, 23); $btnClear.Location = New-Object System.Drawing.Point(550, 15); $btnClear.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right; $btnClear.BackColor = [System.Drawing.Color]::DimGray; $btnClear.ForeColor="White"; $btnClear.FlatStyle="Flat"; $btnClear.Font=New-Object System.Drawing.Font("Segoe UI", 8); $grpLog.Controls.Add($btnClear)
$txtLog = New-Object System.Windows.Forms.RichTextBox; $txtLog.Dock="Fill"; $txtLog.BackColor=$colList; $txtLog.ForeColor="LightGray"; $txtLog.BorderStyle="None"; $txtLog.Font=$fontLog; $grpLog.Controls.Add($txtLog); $btnClear.Add_Click({ $txtLog.Clear() })

# --- ACTIONS ---
$pnlAct = New-Object System.Windows.Forms.TableLayoutPanel; $pnlAct.Dock="Fill"; $pnlAct.ColumnCount=3; $pnlAct.RowCount=2
$pnlAct.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
$pnlAct.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 50)))
for($i=0;$i -lt 3;$i++){ $pnlAct.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 33.33))) }
$pnlAct.Padding = New-Object System.Windows.Forms.Padding(10,5,10,5)
[void]$masterGrid.Controls.Add($pnlAct, 0, 4)

$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="START AUTO-UPDATE"; $btnSync.Dock="Fill"; $btnSync.BackColor=[System.Drawing.Color]::DeepSkyBlue; $btnSync.ForeColor="White"; $btnSync.FlatStyle="Flat"; $btnSync.Font=$fontHeader; $pnlAct.Controls.Add($btnSync, 0, 0)
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
    
    try {
        $timestamp = Get-Date -Format "HH:mm:ss"
        Add-Content -Path $Script:SessionLogFile -Value "[$timestamp] $msg"
    } catch {}
}

function Toggle($s) { $btnCon.Enabled=$s; $btnSync.Enabled=$s; $btnBackup.Enabled=$s; $btnRestore.Enabled=$s; $btnVer.Enabled=$s; $btnCreateDB.Enabled=$s; $btnCopyDB.Enabled=$s; $btnDeleteDB.Enabled=$s }

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

# --- REUSABLE SYNC FUNCTION (PURE EXECUTION ONLY) ---
function Execute-DBSync {
    param($Items)
    if ($Items.Count -eq 0) { return }

    foreach ($i in $Items) {
        $I = $Script:TargetMap[$i]; $D = $I.DB; $F = $I.Folder
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

            # Update XML exactly as in v145
            [xml]$x = Get-Content $Script:XmlTarget
            $x.PnxPakager.SourceServer.IPAddress = $txtS.Text
            $x.PnxPakager.SourceServer.DBName = $D
            $x.PnxPakager.SourceServer.UserName = $txtU.Text
            $x.PnxPakager.SourceServer.Password = $txtP.Text
            $x.PnxPakager.SourceServer.SyncType = "2"
            $x.Save("$WD\PnxAutoNewDBSyn.xml")

            # PURE EXECUTION - NO LOG READING, NO ERROR CATCHING
            Start-Process "$WD\PnxDBSync.exe" -WorkingDirectory $WD -WindowStyle Minimized -Wait
            Log "   ✔ Done" "Lime"

        } catch { 
            Log "   ! Skipped: $($_.Exception.Message)" "Orange" 
        }
    }
}

# --- CONNECT (WITH CATEGORIES AND WAIT BUFFER) ---
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
                Log "   ! Warning: Extraction timed out. Sync might skip missing files." "Orange"
            } else {
                Start-Sleep -Seconds 5 # Buffer to ensure full package extraction
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

            # Filter Logic
            if ($EnvMode -eq "LIVE") { if ($IsTest) { continue } } 
            else { if (-not $IsTest -and -not $IsMaster) { continue } }

            # Determine Base Type & Folder mapping
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
            Log "✔ Automatic Routine Complete" "Lime"
        }

    } catch { Log "❌ Error: $($_.Exception.Message)" "Red" } finally { Toggle $true }
})

# --- DELETE DB (TIMEOUT FIX) ---
$btnDeleteDB.Add_Click({
    if($listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database to Delete!"); return }
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
            $Cmd=$CN.CreateCommand()
            $Cmd.CommandTimeout = 0
            $Cmd.CommandText = "IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$DB') BEGIN ALTER DATABASE [$DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$DB]; END"
            $Cmd.ExecuteNonQuery()|Out-Null
            Log "   ✔ Deleted $DB" "Red"
        }
        $CN.Close(); $btnCon.PerformClick()
    } catch { Log "❌ Error: $($_.Exception.Message)" "Red" } finally { Toggle $true }
})

# --- COPY DB (TIMEOUT FIX & SAFE CAD CLEANUP) ---
function Show-CopyDialog {
    $d = New-Object System.Windows.Forms.Form; $d.Text="DB Copy"; $d.Size="300,150"; $d.StartPosition="CenterParent"
    $l = New-Object System.Windows.Forms.Label; $l.Text="Select Target Type:"; $l.Location="20,20"; $l.AutoSize=$true; $d.Controls.Add($l)
    $cb = New-Object System.Windows.Forms.ComboBox; $cb.Items.AddRange(@("Train (Tr)","Test (Test)")); $cb.SelectedIndex=0; $cb.Location="20,50"; $cb.Width=240; $d.Controls.Add($cb)
    $b = New-Object System.Windows.Forms.Button; $b.Text="PROCEED"; $b.DialogResult="OK"; $b.Location="80,80"; $d.Controls.Add($b); $d.AcceptButton=$b
    if($d.ShowDialog()-eq"OK"){return $cb.SelectedItem} return $null
}

function Show-InputBox { param($T,$P,$D) $f=New-Object System.Windows.Forms.Form;$f.Text=$T;$f.Size="350,150";$f.StartPosition="CenterParent";$l=New-Object System.Windows.Forms.Label;$l.Text=$P;$l.Location="10,10";$l.AutoSize=$true;$f.Controls.Add($l);$t=New-Object System.Windows.Forms.TextBox;$t.Text=$D;$t.Location="10,35";$t.Width=310;$f.Controls.Add($t);$b=New-Object System.Windows.Forms.Button;$b.Text="OK";$b.DialogResult="OK";$b.Location="120,70";$f.Controls.Add($b);$f.AcceptButton=$b;if($f.ShowDialog()-eq"OK"){return $t.Text} return $null }

$btnCopyDB.Add_Click({
    if($listDBs.CheckedItems.Count -ne 1){ [System.Windows.Forms.MessageBox]::Show("Select exactly ONE source database."); return }
    $SourceDB = $Script:TargetMap[$listDBs.CheckedItems[0]].DB
    $TypeSel = Show-CopyDialog; if(!$TypeSel){return}
    $Tag = if($TypeSel -match "Train"){"Tr"}else{"Test"}
    $DefName = if($SourceDB -match "^Phoenix") { $SourceDB.Replace("Phoenix", "Phoenix$Tag") } else { "$($SourceDB)_$Tag" }
    $TargetDB = Show-InputBox "Target Name" "Confirm Target Database Name:" $DefName
    if ([string]::IsNullOrWhiteSpace($TargetDB)) { return }

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
        Log "   ✔ Backup Complete" "Lime"
        
        $BkpInfo = Get-Item $BakFile; $NewSize = [math]::Round($BkpInfo.Length / 1MB, 2)
        if([System.Windows.Forms.MessageBox]::Show("Backup: $NewSize MB`nTarget: $TargetDB`n`nWARNING: Overwriting $TargetDB. Proceed?", "Confirm Restore", "YesNo", "Warning") -ne "Yes"){ $CN.Close(); Toggle $true; return }
        
        Log "Setting $TargetDB to Single User..." "Orange"; [System.Windows.Forms.Application]::DoEvents()
        try { $Cmd.CommandText = "IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$TargetDB') BEGIN ALTER DATABASE [$TargetDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE END"; $Cmd.ExecuteNonQuery()|Out-Null } catch { }

        Log "Restoring (WITH LIVE PROGRESS)..." "White"; [System.Windows.Forms.Application]::DoEvents()
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
        Log "   ✔ Restore Complete" "Lime"

        Log "Applying Hardcoded Job Configuration..." "Yellow"
        $CleanCN = New-Object System.Data.SqlClient.SqlConnection("Server=$($txtS.Text);Database=$TargetDB;User Id=$($txtU.Text);Password=$($txtP.Text)"); $CleanCN.Open()
        
        $ConfigMap = $null
        if ($SourceDB -match "Police") { $ConfigMap = $Script:PoliceJobParams }
        elseif ($SourceDB -match "Fire") { $ConfigMap = $Script:FireJobParams }
        elseif ($SourceDB -match "IA") { $ConfigMap = $Script:IAJobParams }

        if ($ConfigMap) {
            foreach ($JobName in $ConfigMap.Keys) {
                $JData = $ConfigMap[$JobName]; $Instance = $JData["Instance"]
                $Folders = @(); if ($JData.ContainsKey("MultiFolder")) { $Folders = $JData["MultiFolder"] } elseif ($JData.ContainsKey("Folder")) { $Folders += $JData["Folder"] }

                $Qry = "UPDATE KPIjobs SET IsInactive = 1, StartDttm=GETDATE(), EndDttm='2099-12-31' WHERE JobName = '$JobName'; "
                if ($Instance) { $Qry += "INSERT INTO KPIjobsparam(JobID, SeqNo, ParamName, ParamValue) SELECT JobID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIjobsparam WHERE JobID=j.JobID), 'Instance', '$Instance' FROM KPIJobs j WHERE JobName='$JobName'; " }
                foreach ($Fld in $Folders) { $Qry += "INSERT INTO KPIJobsNotify SELECT JobID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIJobsNotify WHERE JobID=j.JobID), NULL, NULL, '$Fld', 1, NULL, NULL, NULL, NULL FROM KPIJobs j WHERE JobName='$JobName'; " }
                $CCmd = $CleanCN.CreateCommand(); $CCmd.CommandText = $Qry; $CCmd.ExecuteNonQuery()|Out-Null
                Log "   + Configured: $JobName" "Gray"
            }
        }
        
        $DelCmd = $CleanCN.CreateCommand()
        $DelCmd.CommandTimeout = 0
        $DelCmd.CommandText = "IF OBJECT_ID('CADScheduleUnit') IS NOT NULL DELETE FROM CADScheduleUnit; IF OBJECT_ID('CADSchedule') IS NOT NULL DELETE FROM CADSchedule; UPDATE kpijobs SET IsInactive = 0;" 
        if ($SourceDB -match "Police") {
            $DelCmd.CommandText += " DELETE FROM Parameter WHERE ParamID IN (203, 204, 205, 206, 207, 1722, 1757, 609, 610, 616, 618, 659, 2010, 2011, 2012, 2013, 2018, 2019, 2023, 774, 778); DELETE FROM Parameter WHERE ParamID IN (4416, 4423, 4424, 4426, 4439, 4447, 4454, 4455, 4456, 4460, 4626, 4702, 4703, 222); DELETE FROM Parameter WHERE ParamID IN (221); UPDATE ParameterName SET DefaultValue = NULL WHERE ParamID = 295;"
        } elseif ($SourceDB -match "Fire") {
            $DelCmd.CommandText += " DELETE FROM Parameter WHERE ParamID IN (203, 204, 205, 206, 207, 221); UPDATE ParameterName SET DefaultValue = NULL WHERE ParamID = 295;"
        }
        $DelCmd.ExecuteNonQuery()|Out-Null
        Log "   ✔ Final Cleanup Done" "Lime"
        
        $CleanCN.Close(); $CN.Close(); $btnCon.PerformClick()

    } catch { Log "❌ Failed: $($_.Exception.Message)" "Red" } finally { Toggle $true }
})

# --- BACKUP PARAMS (Hardcoded Safe Fallback) ---
$btnBackup.Add_Click({
    if($listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select DBs!"); return }
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select Folder to Save Backups"; $fbd.SelectedPath = $Script:DefaultBackup
    if($fbd.ShowDialog() -ne "OK"){ return }
    $TargetDirBase = $fbd.SelectedPath

    Toggle $false; Log "Starting Backup..." "Cyan"; $TS=Get-Date -Format "yyyyMMdd_HHmm"
    $RMSJobs="'CAD Static Data Extractor','Fire Live Data Exporter','Hot Sheet','KPICleaner','Phoenix BOT QA Uploader','ReportWriterStaticDataExporter','WDA App Data Exporter','FireRMSDataExporter'"
    $GParams="13, 16, 22, 29, 36, 39, 40, 190, 203, 204, 205, 206, 207, 220, 221, 231, 630, 1914, 2658, 5712, 5714"
    foreach ($item in $listDBs.CheckedItems) {
        $DB=$Script:TargetMap[$item].DB; Log "Backing up $DB..." "White"; [System.Windows.Forms.Application]::DoEvents(); $Cat="Other"; if($DB -match "Police"){$Cat="Police"}elseif($DB -match "Fire"){$Cat="Fire"}elseif($DB -match "IA"){$Cat="InternalAffairs"}; $TDir=Join-Path $TargetDirBase $Cat; if(!(Test-Path $TDir)){New-Item -ItemType Directory -Path $TDir|Out-Null}
        try {
            $CS="Server=$($txtS.Text);Database=$DB;User Id=$($txtU.Text);Password=$($txtP.Text);Connection Timeout=15"; $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
            $CmdJob=$CN.CreateCommand(); $CmdJob.CommandTimeout=0; $CmdJob.CommandText="SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME='KPIJobs'"; if($CmdJob.ExecuteScalar()-gt 0){
                $DA=New-Object System.Data.SqlClient.SqlDataAdapter("SELECT * FROM dbo.KPIJobs WITH (NOLOCK) WHERE JobName IN ($RMSJobs)", $CN); $DT=New-Object System.Data.DataTable; $DA.Fill($DT)|Out-Null
                if($DT.Rows.Count-gt 0){ $Exp=@(); foreach($r in $DT.Rows){$o=[ordered]@{};foreach($c in $DT.Columns){$o[$c.ColumnName]=$r[$c]};$Exp+=[PSCustomObject]$o}; $Exp|Export-Csv "$TDir\$($DB)_KPIJobs_$TS.txt" -NoTypeInformation -Delimiter "`t"; Log "   + Jobs Saved" "Lime" 
                } else { Log "   ! No KPI Jobs Found" "Yellow" }
            } else { Log "   - No KPIJobs Table" "Gray" }
            
            $CmdParam=$CN.CreateCommand(); $CmdParam.CommandTimeout=0; $CmdParam.CommandText="SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME IN ('Parameter','ParameterName')"; $Tbl=$CmdParam.ExecuteScalar()
            if($Tbl){
                $Col = if($Tbl -eq "Parameter"){"ParamValue"}else{"DefaultValue"}
                $SQL = "SELECT CAST(ParamID AS VARCHAR(10)) + ' = ' + ISNULL(CAST($Col AS VARCHAR(MAX)), '') FROM dbo.$Tbl WHERE ParamID IN ($GParams) ORDER BY ParamID"
                $DA=New-Object System.Data.SqlClient.SqlDataAdapter($SQL, $CN); $DT=New-Object System.Data.DataTable; $DA.Fill($DT)|Out-Null
                if($DT.Rows.Count-gt 0){ $O=@(); foreach($R in $DT.Rows){$O+=$R[0]}; $O|Out-File "$TDir\$($DB)_GlobalParameters.txt" -Encoding UTF8; Log "   + Params Saved ($Tbl)" "Lime" }
            }
            $CN.Close()
        } catch { Log "   Failed: $($_.Exception.Message)" "Red" }
    }
    Log "Backup Complete." "Cyan"; Toggle $true
})

# --- RESTORE PARAMS ---
$btnRestore.Add_Click({
    if($listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select DBs!"); return }
    $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Filter="Text Files (*.txt)|*.txt"; $f.InitialDirectory=$Script:DefaultBackup; if($f.ShowDialog()-ne"OK"){return}; $SourceFile=$f.FileName
    
    $JobCSV = $SourceFile.Replace("_GlobalParameters.txt", "_KPIJobs_").Replace(".txt", "*.txt")
    $JobPath = Get-ChildItem -Path (Split-Path $SourceFile -Parent) -Filter (Split-Path $JobCSV -Leaf) | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    
    $Msg = "RESTORE from:\n$SourceFile"
    if ($JobPath) { $Msg += "\n\nAND Job CSV Data:\n$($JobPath.Name)" }
    if([System.Windows.Forms.MessageBox]::Show($Msg, "Confirm", "YesNo", "Warning") -ne "Yes"){ return }
    
    Toggle $false; Log "Restoring..." "Orange"; $Content=Get-Content $SourceFile
    foreach ($item in $listDBs.CheckedItems) {
        $DB=$Script:TargetMap[$item].DB; Log "Restoring to $DB..." "White"; [System.Windows.Forms.Application]::DoEvents()
        try {
            $CS="Server=$($txtS.Text);Database=$DB;User Id=$($txtU.Text);Password=$($txtP.Text);Connection Timeout=15"; $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open(); $Count=0
            
            $C=$CN.CreateCommand(); $C.CommandTimeout=0; $C.CommandText="SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME IN ('Parameter','ParameterName')"; $Tbl=$C.ExecuteScalar()
            if($Tbl){ 
                $Col = if($Tbl -eq "Parameter"){"ParamValue"}else{"DefaultValue"}
                foreach ($Line in $Content) {
                    if ($Line.Trim().StartsWith("#") -or $Line.Trim() -eq "") { continue }; $Parts=$Line -split "=", 2; if ($Parts.Count -eq 2) {
                        $ParamID=$Parts[0].Trim(); $Val=$Parts[1].Trim().Replace("'","''"); try { $Cmd=$CN.CreateCommand(); $Cmd.CommandText="UPDATE dbo.$Tbl SET $Col = '$Val' WHERE ParamID = $ParamID"; $Cmd.ExecuteNonQuery()|Out-Null; $Count++ } catch {}
                    }
                }
                Log "   ✔ Updated $Count params ($Tbl)" "Lime" 
            }

            if ($JobPath) {
                $JobData = Import-Csv -Path $JobPath.FullName -Delimiter "`t"
                foreach ($Row in $JobData) {
                    if ($Row.JobName) {
                        $SetParts = @(); foreach ($Prop in $Row.PSObject.Properties) {
                            if ($Prop.Name -ne "JobName" -and $Prop.Name -ne "JobID") { $Val = $Prop.Value.Replace("'", "''"); $SetParts += "$($Prop.Name) = '$Val'" }
                        }
                        $SetClause = $SetParts -join ", "
                        $Cmd=$CN.CreateCommand(); $Cmd.CommandText="UPDATE KPIJobs SET $SetClause WHERE JobName = '$($Row.JobName)'"
                        try { $Cmd.ExecuteNonQuery()|Out-Null } catch {}
                    }
                }
                Log "   ✔ Restored $($JobData.Count) Jobs Data" "Lime"
            }

            $CN.Close()
        } catch { Log "   Failed: $($_.Exception.Message)" "Red" }
    }
    Toggle $true
})

# --- SYNC BUTTON LOGIC ---
$btnSync.Add_Click({ Toggle $false; Execute-DBSync $listDBs.CheckedItems; Toggle $true })

# --- VER & INSTALL ---
$btnVer.Add_Click({ Toggle $false; Log "Checking Versions..." "Cyan"; Scan-Server $txtS.Text; try { $cn=New-Object System.Data.SqlClient.SqlConnection("Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master"); $cn.Open(); foreach($i in $listDBs.CheckedItems){ $D=$Script:TargetMap[$i].DB; $cmd=$cn.CreateCommand(); $cmd.CommandText="SELECT Version FROM [$D].dbo.KPIDBVersion"; try{ $v=$cmd.ExecuteScalar(); Log "$D : $v" "White" }catch{Log "$D : Error" "Red"} }; $cn.Close() } catch {} finally { Toggle $true } })

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