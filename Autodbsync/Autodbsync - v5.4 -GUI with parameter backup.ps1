# ======================================================================
#  ProPhoenix DB Utility Dashboard - v113.0 (Restore Fix)
# ======================================================================
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Data") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:CredFile  = Join-Path $Script:SetupPath "SavedCreds.xml"
$Script:BackupDir = "C:\RMS_Master_Backups"
$Script:BgImage   = Join-Path $Script:SetupPath "background.png" 
if (!(Test-Path $Script:BgImage)) { $Script:BgImage = Join-Path $Script:SetupPath "background.jpg" }
$Script:LogoFile  = Join-Path $Script:SetupPath "logo.png"

# Dynamic Variables
$Script:DBSyncRoot = $null
$Script:AppMgrPath = $null
$Script:IsRemote = $false
$Script:TargetServer = "localhost"
$Script:TargetMap = @{}

# --- DETECT PATHS ---
if (!(Test-Path $Script:SetupPath)) { New-Item -ItemType Directory -Force -Path $Script:SetupPath | Out-Null }
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
$form.Text = "ProPhoenix DB Utility Dashboard v113"
$form.Size = New-Object System.Drawing.Size(1250, 850) 
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
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 80)))
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
$txtS = Add-Input $flowCon "Server IP" 200 $env:COMPUTERNAME
$txtU = Add-Input $flowCon "Username" 150 "sa"
$txtP = Add-Input $flowCon "Password" 150 "" $true
$chkSave = New-Object System.Windows.Forms.CheckBox; $chkSave.Text="Save"; $chkSave.ForeColor="White"; $chkSave.AutoSize=$true; $chkSave.Margin=New-Object System.Windows.Forms.Padding(0,25,0,0); $flowCon.Controls.Add($chkSave)
$btnCon = New-Object System.Windows.Forms.Button; $btnCon.Text="CONNECT"; $btnCon.Size="120,35"; $btnCon.BackColor=[System.Drawing.Color]::Crimson; $btnCon.ForeColor="White"; $btnCon.FlatStyle="Flat"; $btnCon.Margin=New-Object System.Windows.Forms.Padding(20,15,0,0); $flowCon.Controls.Add($btnCon)

# --- LIST & LOG ---
$split = New-Object System.Windows.Forms.TableLayoutPanel; $split.Dock="Fill"; $split.ColumnCount=2; $split.RowCount=1
$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 40)))
$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 60)))
[void]$masterGrid.Controls.Add($split, 0, 3)
$grpList = New-Object System.Windows.Forms.GroupBox; $grpList.Text=" Detected Targets "; $grpList.Dock="Fill"; $grpList.ForeColor=[System.Drawing.Color]::DeepSkyBlue; $grpList.Font=$fontHeader; $split.Controls.Add($grpList, 0, 0)
$listDBs = New-Object System.Windows.Forms.CheckedListBox; $listDBs.Dock="Fill"; $listDBs.BackColor=$colList; $listDBs.ForeColor="White"; $listDBs.BorderStyle="None"; $listDBs.Font=$fontNorm; $listDBs.CheckOnClick=$true; $grpList.Controls.Add($listDBs)
$grpLog = New-Object System.Windows.Forms.GroupBox; $grpLog.Text=" Activity Log "; $grpLog.Dock="Fill"; $grpLog.ForeColor=[System.Drawing.Color]::LimeGreen; $grpLog.Font=$fontHeader; $split.Controls.Add($grpLog, 1, 0)
$btnClear = New-Object System.Windows.Forms.Button; $btnClear.Text = "Clear Log"; $btnClear.Size = New-Object System.Drawing.Size(75, 23); $btnClear.Location = New-Object System.Drawing.Point(550, 15); $btnClear.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right; $btnClear.BackColor = [System.Drawing.Color]::DimGray; $btnClear.ForeColor="White"; $btnClear.FlatStyle="Flat"; $btnClear.Font=New-Object System.Drawing.Font("Segoe UI", 8); $grpLog.Controls.Add($btnClear)
$txtLog = New-Object System.Windows.Forms.RichTextBox; $txtLog.Dock="Fill"; $txtLog.BackColor=$colList; $txtLog.ForeColor="LightGray"; $txtLog.BorderStyle="None"; $txtLog.Font=$fontLog; $grpLog.Controls.Add($txtLog); $btnClear.Add_Click({ $txtLog.Clear() })

# --- ACTIONS ---
$pnlAct = New-Object System.Windows.Forms.TableLayoutPanel; $pnlAct.Dock="Fill"; $pnlAct.ColumnCount=4; $pnlAct.RowCount=1
$pnlAct.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)))
$pnlAct.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)))
$pnlAct.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)))
$pnlAct.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 25)))
$pnlAct.Padding = New-Object System.Windows.Forms.Padding(10,10,10,10)
[void]$masterGrid.Controls.Add($pnlAct, 0, 4)

$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="START AUTO-UPDATE"; $btnSync.Dock="Fill"; $btnSync.BackColor=[System.Drawing.Color]::DeepSkyBlue; $btnSync.ForeColor="White"; $btnSync.FlatStyle="Flat"; $btnSync.Font=$fontHeader; $pnlAct.Controls.Add($btnSync, 0, 0)
$btnBackup = New-Object System.Windows.Forms.Button; $btnBackup.Text="BACKUP PARAMS"; $btnBackup.Dock="Fill"; $btnBackup.BackColor=[System.Drawing.Color]::MediumPurple; $btnBackup.ForeColor="White"; $btnBackup.FlatStyle="Flat"; $btnBackup.Font=$fontHeader; $btnBackup.Margin=New-Object System.Windows.Forms.Padding(5,0,5,0); $pnlAct.Controls.Add($btnBackup, 1, 0)
$btnRestore = New-Object System.Windows.Forms.Button; $btnRestore.Text="RESTORE PARAMS"; $btnRestore.Dock="Fill"; $btnRestore.BackColor=[System.Drawing.Color]::DarkSlateBlue; $btnRestore.ForeColor="White"; $btnRestore.FlatStyle="Flat"; $btnRestore.Font=$fontHeader; $btnRestore.Margin=New-Object System.Windows.Forms.Padding(5,0,5,0); $pnlAct.Controls.Add($btnRestore, 2, 0)
$btnVer = New-Object System.Windows.Forms.Button; $btnVer.Text="CHECK VERSION"; $btnVer.Dock="Fill"; $btnVer.BackColor=[System.Drawing.Color]::DarkOrange; $btnVer.ForeColor="White"; $btnVer.FlatStyle="Flat"; $btnVer.Font=$fontHeader; $pnlAct.Controls.Add($btnVer, 3, 0)

# --- STATUS ---
$stat = New-Object System.Windows.Forms.StatusStrip; $stat.BackColor=[System.Drawing.Color]::FromArgb(30,30,30); $lblStat = New-Object System.Windows.Forms.ToolStripStatusLabel; $lblStat.Text="Ready."; $lblStat.ForeColor="White"; $stat.Items.Add($lblStat); [void]$masterGrid.Controls.Add($stat, 0, 5)

# ======================================================================
#  CORE FUNCTIONS
# ======================================================================

function Log($msg, $color="White") { $txtLog.SelectionStart=$txtLog.TextLength; $txtLog.SelectionColor=[System.Drawing.Color]::FromName($color); $txtLog.AppendText("$msg`r`n"); $txtLog.ScrollToCaret(); [System.Windows.Forms.Application]::DoEvents() }
function Toggle($s) { $btnCon.Enabled=$s; $btnSync.Enabled=$s; $btnBackup.Enabled=$s; $btnRestore.Enabled=$s; $btnVer.Enabled=$s; $btnCreateDB.Enabled=$s }

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

# --- CONNECT ---
$btnCon.Add_Click({
    Toggle $false; $listDBs.Items.Clear(); $Script:TargetMap=@{}
    Log "Connecting..." "White"
    try {
        $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=5"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $da = New-Object System.Data.SqlClient.SqlDataAdapter("SELECT Name FROM sys.databases WHERE database_id>4 AND Name NOT IN ('master','model','msdb','tempdb','ReportServer') ORDER BY Name", $cn)
        $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        Log "✔ Connected." "Lime"; $lblStat.Text = "Connected."; Save-Creds; Scan-Server $txtS.Text 
        foreach ($row in $ds.Tables[0].Rows) {
            $db = $row.Name; $Folder = $null; $Tag = ""
            if ($db -match "Master$") { $Folder="Phoenix Master"; $Tag="[MASTER]" }
            elseif ($db -match "Police$") { $Folder="Police"; $Tag="[POLICE]" }
            elseif ($db -match "Fire$") { $Folder="Fire"; $Tag="[FIRE]" }
            elseif ($db -match "IA$") { $Folder="IA"; $Tag="[IA]" }
            elseif ($db -match "PoliceCSP$") { $Folder="Police CSP"; $Tag="[POLICE CSP]" }
            elseif ($db -match "FireCSP$") { $Folder="Fire CSP"; $Tag="[FIRE CSP]" }
            elseif ($db -match "DW$") { $Folder="Police DW"; $Tag="[DW]" }
            if ($Folder) {
                if ($Script:DBSyncRoot -and (-not $Script:IsRemote)) {
                    if (!(Test-Path (Join-Path $Script:DBSyncRoot $Folder))) { $Folder = $Folder.Replace(" ", "") }
                    if (!(Test-Path (Join-Path $Script:DBSyncRoot $Folder))) { continue }
                }
                $Key = "$Tag $db"; $listDBs.Items.Add($Key, $true); $Script:TargetMap[$Key] = @{ DB=$db; Folder=$Folder }
            }
        }
    } catch { Log "❌ Error: $($_.Exception.Message)" "Red" } finally { Toggle $true }
})

# --- BACKUP LOGIC ---
$btnBackup.Add_Click({
    if($listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select DBs!"); return }
    $names = ($listDBs.CheckedItems | ForEach-Object { $Script:TargetMap[$_].DB }) -join ", "
    if([System.Windows.Forms.MessageBox]::Show("You are about to BACKUP parameters from these databases:`n`n$names`n`nContinue?", "Confirm Backup", "YesNo", "Question") -ne "Yes"){ return }

    Toggle $false; Log "Starting Backup..." "Cyan"
    $RMSJobs = "'CAD Static Data Extractor', 'Fire Live Data Exporter', 'Hot Sheet', 'KPICleaner', 'Phoenix BOT QA Uploader', 'ReportWriterStaticDataExporter', 'WDA App Data Exporter'"
    $GParams = "13, 16, 22, 29, 36, 39, 40, 190, 203, 204, 205, 206, 207, 220, 221, 231, 630, 1914, 2658, 5712, 5714"
    $TS = Get-Date -Format "yyyyMMdd_HHmm"

    foreach ($item in $listDBs.CheckedItems) {
        $DB = $Script:TargetMap[$item].DB; Log "Backing up $DB..." "White"; [System.Windows.Forms.Application]::DoEvents()
        $Cat = "Other"; if($DB -match "Police"){$Cat="Police"}elseif($DB -match "Fire"){$Cat="Fire"}elseif($DB -match "IA"){$Cat="InternalAffairs"}
        $TDir = Join-Path $Script:BackupDir $Cat; if(!(Test-Path $TDir)){New-Item -ItemType Directory -Path $TDir|Out-Null}
        try {
            $CS="Server=$($txtS.Text);Database=$DB;User Id=$($txtU.Text);Password=$($txtP.Text);Connection Timeout=15"; $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
            $CmdChk = $CN.CreateCommand(); $CmdChk.CommandText = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'KPIJobs'"
            if ($CmdChk.ExecuteScalar() -gt 0) {
                $DA=New-Object System.Data.SqlClient.SqlDataAdapter("SELECT * FROM dbo.KPIJobs WITH (NOLOCK) WHERE JobName IN ($RMSJobs)", $CN); $DT=New-Object System.Data.DataTable; $DA.Fill($DT)|Out-Null
                if($DT.Rows.Count -gt 0){ $DT | Export-Csv -Path "$TDir\$($DB)_KPIJobs_$TS.txt" -NoTypeInformation -Delimiter "`t"; Log "   + Jobs Saved" "Lime" }
            }
            $CmdChk.CommandText = "SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ParameterName'"
            if ($CmdChk.ExecuteScalar() -gt 0) {
                $DA=New-Object System.Data.SqlClient.SqlDataAdapter("SELECT ParamID, DefaultValue FROM dbo.ParameterName WITH (NOLOCK) WHERE ParamID IN ($GParams)", $CN); $DT=New-Object System.Data.DataTable; $DA.Fill($DT)|Out-Null
                if($DT.Rows.Count -gt 0){ $Out=@(); foreach($R in $DT.Rows){ $Out += "{0} = {1}" -f $R.ParamID, $R.DefaultValue }; $Out | Out-File "$TDir\$($DB)_GlobalParameters.txt" -Encoding UTF8; Log "   + Params Saved" "Lime" }
            }
            $CN.Close()
        } catch { Log "   Failed: $($_.Exception.Message)" "Red" }
    }
    Log "Backup Complete." "Cyan"; Toggle $true
})

# --- RESTORE LOGIC (FIXED $PID VARIABLE NAME) ---
$btnRestore.Add_Click({
    if($listDBs.CheckedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Target DBs!"); return }
    $f = New-Object System.Windows.Forms.OpenFileDialog; $f.Title="Select Parameter File"; $f.Filter="Text Files (*.txt)|*.txt"; $f.InitialDirectory=$Script:BackupDir
    if($f.ShowDialog() -ne "OK"){ return }
    $SourceFile = $f.FileName
    $names = ($listDBs.CheckedItems | ForEach-Object { $Script:TargetMap[$_].DB }) -join ", "
    if([System.Windows.Forms.MessageBox]::Show("You are about to RESTORE data from:`n$SourceFile`n`nINTO these databases:`n$names`n`nAre you sure?", "Confirm Restore", "YesNo", "Warning") -ne "Yes"){ return }

    Toggle $false; Log "Starting Restore..." "Orange"
    $Content = Get-Content -Path $SourceFile
    
    foreach ($item in $listDBs.CheckedItems) {
        $DB = $Script:TargetMap[$item].DB; Log "Restoring to $DB..." "White"; [System.Windows.Forms.Application]::DoEvents()
        try {
            $CS="Server=$($txtS.Text);Database=$DB;User Id=$($txtU.Text);Password=$($txtP.Text);Connection Timeout=15"; $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
            $Count=0
            foreach ($Line in $Content) {
                if ($Line.Trim().StartsWith("#") -or $Line.Trim() -eq "") { continue }
                $Parts = $Line -split "=", 2
                if ($Parts.Count -eq 2) {
                    $ParamID = $Parts[0].Trim(); $Val = $Parts[1].Trim().Replace("'", "''") # FIXED VARIABLE NAME
                    try {
                        $Cmd=$CN.CreateCommand(); $Cmd.CommandText="UPDATE dbo.ParameterName SET DefaultValue = '$Val' WHERE ParamID = $ParamID"; $Cmd.ExecuteNonQuery()|Out-Null; $Count++
                    } catch {}
                }
            }
            Log "   ✔ Updated $Count params" "Lime"; $CN.Close()
        } catch { Log "   Failed: $($_.Exception.Message)" "Red" }
    }
    Log "Restore Complete." "Cyan"; Toggle $true
})

# --- SYNC & VERSION ---
$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select DBs!"); return }; Toggle $false
    foreach ($item in $listDBs.CheckedItems) {
        $Info = $Script:TargetMap[$item]; $db = $Info.DB; $f = $Info.Folder
        Log "Updating $db..." "Cyan"; [System.Windows.Forms.Application]::DoEvents()
        $targetFolder = Join-Path $Script:DBSyncRoot $f
        $jobBlock = {
            param($TargetFolder, $IP, $DB, $User, $Pass, $XML)
            if (!(Test-Path $TargetFolder)) { return "MISSING_FOLDER" }
            [xml]$x = $XML; $x.PnxPakager.SourceServer.IPAddress=$IP; $x.PnxPakager.SourceServer.DBName=$DB; $x.PnxPakager.SourceServer.UserName=$User; $x.PnxPakager.SourceServer.Password=$Pass; $x.PnxPakager.SourceServer.SyncType="2"
            $x.Save((Join-Path $TargetFolder "PnxAutoNewDBSyn.xml"))
            $Exe = Join-Path $TargetFolder "PnxDBSync.exe"
            $proc = Start-Process -FilePath $Exe -WorkingDirectory $TargetFolder -PassThru -WindowStyle Minimized; $proc.WaitForExit()
            return "DONE"
        }
        try {
            $xmlContent = Get-Content $Script:XmlTarget -Raw
            $argsList = @($targetFolder, $txtS.Text, $db, $txtU.Text, $txtP.Text, $xmlContent)
            if ($Script:IsRemote) { $cmdArgs = @{ ComputerName=$Script:TargetServer; ScriptBlock=$jobBlock; ArgumentList=$argsList }; if ($Script:WindowsCreds) { $cmdArgs.Credential = $Script:WindowsCreds }; Invoke-Command @cmdArgs | Out-Null }
            else { Invoke-Command -ScriptBlock $jobBlock -ArgumentList $argsList | Out-Null }
            Log "   ✔ Completed" "Lime"
        } catch { Log "Error: $($_.Exception.Message)" "Red" }
    }
    Log "Finished." "White"; Toggle $true
})

$btnVer.Add_Click({ 
    Toggle $false; Log "Checking Versions..." "Cyan"; Scan-Server $txtS.Text; try { 
    $cn=New-Object System.Data.SqlClient.SqlConnection("Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master"); $cn.Open()
    foreach($i in $listDBs.CheckedItems){
        $D=$Script:TargetMap[$i].DB; $cmd=$cn.CreateCommand(); $cmd.CommandText="SELECT Version FROM [$D].dbo.KPIDBVersion"; 
        try{ $v=$cmd.ExecuteScalar(); Log "$D : $v" "White" }catch{Log "$D : Error" "Red"}
    } $cn.Close() } catch { Log "Error" "Red" } finally { Toggle $true } 
})

# --- INSTALL ---
$RunAppMgr = { param($Mode)
    if (!$Script:AppMgrPath) { [System.Windows.Forms.MessageBox]::Show("App Manager (PnxAppMgr.exe) not found!"); return }
    $Bat = Join-Path $env:TEMP "PnxAction.bat"
    $Dir = Split-Path $Script:AppMgrPath -Parent
    Set-Content $Bat "@echo off`ncd /d `"$Dir`"`n`"$($Script:AppMgrPath)`" `"$Mode`" `"DBUtility`"`npause"
    Start-Process $Bat -Verb RunAs
}
$btnInstall.Add_Click({ & $RunAppMgr "INSTALL" })
$btnUninstall.Add_Click({ & $RunAppMgr "UNINSTALL" })

# --- INIT ---
$form.Add_Load({ Load-Creds })
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()