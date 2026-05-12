# ======================================================================
#  ProPhoenix DB Utility Dashboard - v106.0 (Integrated Fix)
# ======================================================================
# Merges v105 UI (Auto-Queue) with v66 Logic (Deep Scan/Remote Exec)
# ======================================================================

[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 
[void] [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.VisualBasic") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:CredFile  = Join-Path $Script:SetupPath "SavedCreds.xml"
$Script:BgImage   = Join-Path $Script:SetupPath "background.png" 
if (!(Test-Path $Script:BgImage)) { $Script:BgImage = Join-Path $Script:SetupPath "background.jpg" }
$Script:LogoFile  = Join-Path $Script:SetupPath "logo.png"

# Dynamic Variables (from v66 logic)
$Script:DBSyncRoot = $null
$Script:IsRemote = $false
$Script:TargetServer = "localhost"
$Script:WindowsCreds = $null
$Script:TargetMap = @{}

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
$colBtn     = [System.Drawing.Color]::FromArgb(70, 70, 70)

$fontTitle  = New-Object System.Drawing.Font("Segoe UI Light", 20, [System.Drawing.FontStyle]::Regular)
$fontHeader = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontNorm   = New-Object System.Drawing.Font("Segoe UI", 9)
$fontLog    = New-Object System.Drawing.Font("Consolas", 9) 

# --- FORM SETUP ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "ProPhoenix DB Utility Dashboard v106"
$form.Size = New-Object System.Drawing.Size(1200, 800) 
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
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 100))) 
$masterGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 25)))  
$form.Controls.Add($masterGrid)

# --- ROW 0: HEADER ---
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Fill"
$picLogo = New-Object System.Windows.Forms.PictureBox; $picLogo.Size="160,50"; $picLogo.Location="15,10"; $picLogo.SizeMode="Zoom"; if(Test-Path $Script:LogoFile){$picLogo.Image=[System.Drawing.Image]::FromFile($Script:LogoFile)}; $pnlHead.Controls.Add($picLogo)
$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="DB Sync Dashboard - Installation"; $lblTitle.AutoSize=$true; $lblTitle.Location="190,15"; $lblTitle.Font=$fontTitle; $lblTitle.ForeColor=[System.Drawing.Color]::DodgerBlue; $pnlHead.Controls.Add($lblTitle)

# Path & Version UI
$lblPath = New-Object System.Windows.Forms.Label; $lblPath.Text="Utility Path:"; $lblPath.Location="600,15"; $lblPath.AutoSize=$true; $lblPath.ForeColor="Gray"; $pnlHead.Controls.Add($lblPath)
$txtPath = New-Object System.Windows.Forms.TextBox; $txtPath.Location="680,12"; $txtPath.Size="350,25"; $txtPath.BackColor=$colInputBg; $txtPath.ForeColor="White"; $txtPath.BorderStyle="FixedSingle"; $pnlHead.Controls.Add($txtPath)
$btnBrowse = New-Object System.Windows.Forms.Button; $btnBrowse.Text="Browse"; $btnBrowse.Location="1040,12"; $btnBrowse.Size="80,25"; $btnBrowse.BackColor=$colBtn; $btnBrowse.ForeColor="White"; $btnBrowse.FlatStyle="Flat"; $pnlHead.Controls.Add($btnBrowse)
$lblVerDisplay = New-Object System.Windows.Forms.Label; $lblVerDisplay.Text="Ver: --"; $lblVerDisplay.AutoSize=$false; $lblVerDisplay.TextAlign="Right"; $lblVerDisplay.Size="300,20"; $lblVerDisplay.Location="820,40"; $lblVerDisplay.ForeColor="Gray"; $pnlHead.Controls.Add($lblVerDisplay)
[void]$masterGrid.Controls.Add($pnlHead, 0, 0)

# --- ROW 1: ADMIN ---
$pnlAdmin = New-Object System.Windows.Forms.Panel; $pnlAdmin.Dock="Fill"; $pnlAdmin.BackColor=[System.Drawing.Color]::FromArgb(40,40,40)
[void]$masterGrid.Controls.Add($pnlAdmin, 0, 1)
$btnCreateDB = New-Object System.Windows.Forms.Button; $btnCreateDB.Text="Create New DB"; $btnCreateDB.Location="200,15"; $btnCreateDB.Size="160,40"; $btnCreateDB.BackColor=[System.Drawing.Color]::DodgerBlue; $btnCreateDB.ForeColor="White"; $btnCreateDB.FlatStyle="Flat"; $pnlAdmin.Controls.Add($btnCreateDB)
$btnInstall = New-Object System.Windows.Forms.Button; $btnInstall.Text="Install Utility"; $btnInstall.Location="380,15"; $btnInstall.Size="160,40"; $btnInstall.BackColor=[System.Drawing.Color]::SeaGreen; $btnInstall.ForeColor="White"; $btnInstall.FlatStyle="Flat"; $pnlAdmin.Controls.Add($btnInstall)
$btnUninstall = New-Object System.Windows.Forms.Button; $btnUninstall.Text="Uninstall Utility"; $btnUninstall.Location="560,15"; $btnUninstall.Size="160,40"; $btnUninstall.BackColor=[System.Drawing.Color]::IndianRed; $btnUninstall.ForeColor="White"; $btnUninstall.FlatStyle="Flat"; $pnlAdmin.Controls.Add($btnUninstall)

# --- ROW 2: CONNECTION ---
$grpCon = New-Object System.Windows.Forms.GroupBox; $grpCon.Text=" SQL Connection "; $grpCon.Dock="Fill"; $grpCon.ForeColor="LightGray"; $grpCon.Font=$fontHeader
[void]$masterGrid.Controls.Add($grpCon, 0, 2)
$flowCon = New-Object System.Windows.Forms.FlowLayoutPanel; $flowCon.Dock="Fill"; $flowCon.Padding=New-Object System.Windows.Forms.Padding(10,15,0,0); $grpCon.Controls.Add($flowCon)

function Add-Input($p, $l, $w, $d, $pass=$false){
    $pn=New-Object System.Windows.Forms.Panel;$pn.Size=New-Object System.Drawing.Size($w,50);
    $lb=New-Object System.Windows.Forms.Label;$lb.Text=$l;$lb.AutoSize=$true;$lb.ForeColor="White";$lb.Font=$fontNorm;$pn.Controls.Add($lb);
    $bx=New-Object System.Windows.Forms.TextBox;$bx.Text=$d;$bx.Location="0,20";$bx.Width=$w-10;$bx.BackColor=$colInputBg;$bx.ForeColor="White";$bx.BorderStyle="FixedSingle";if($pass){$bx.PasswordChar="*"};$pn.Controls.Add($bx);
    $p.Controls.Add($pn); return $bx
}
$txtS = Add-Input $flowCon "Server IP" 200 $env:COMPUTERNAME
$txtU = Add-Input $flowCon "Username" 150 "sa"
$txtP = Add-Input $flowCon "Password" 150 "" $true
$chkSave = New-Object System.Windows.Forms.CheckBox; $chkSave.Text="Save"; $chkSave.ForeColor="White"; $chkSave.AutoSize=$true; $chkSave.Margin=New-Object System.Windows.Forms.Padding(0,25,0,0); $flowCon.Controls.Add($chkSave)
$btnCon = New-Object System.Windows.Forms.Button; $btnCon.Text="CONNECT"; $btnCon.Size="120,35"; $btnCon.BackColor=[System.Drawing.Color]::Crimson; $btnCon.ForeColor="White"; $btnCon.FlatStyle="Flat"; $btnCon.Margin=New-Object System.Windows.Forms.Padding(20,15,0,0); $flowCon.Controls.Add($btnCon)

# --- ROW 3: LIST & LOG ---
$split = New-Object System.Windows.Forms.TableLayoutPanel; $split.Dock="Fill"; $split.ColumnCount=2; $split.RowCount=1
$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 40)))
$split.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 60)))
[void]$masterGrid.Controls.Add($split, 0, 3)

$grpList = New-Object System.Windows.Forms.GroupBox; $grpList.Text=" Detected Targets "; $grpList.Dock="Fill"; $grpList.ForeColor=[System.Drawing.Color]::DeepSkyBlue; $grpList.Font=$fontHeader
$split.Controls.Add($grpList, 0, 0)
$listDBs = New-Object System.Windows.Forms.CheckedListBox; $listDBs.Dock="Fill"; $listDBs.BackColor=$colList; $listDBs.ForeColor="White"; $listDBs.BorderStyle="None"; $listDBs.Font=$fontNorm; $listDBs.CheckOnClick=$true; $grpList.Controls.Add($listDBs)

$grpLog = New-Object System.Windows.Forms.GroupBox; $grpLog.Text=" Activity Log "; $grpLog.Dock="Fill"; $grpLog.ForeColor=[System.Drawing.Color]::LimeGreen; $grpLog.Font=$fontHeader
$split.Controls.Add($grpLog, 1, 0)

$btnClear = New-Object System.Windows.Forms.Button; $btnClear.Text = "Clear Log"; $btnClear.Size = New-Object System.Drawing.Size(75, 23); $btnClear.Location = New-Object System.Drawing.Point(550, 15); $btnClear.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right; $btnClear.BackColor = [System.Drawing.Color]::DimGray; $btnClear.ForeColor="White"; $btnClear.FlatStyle="Flat"; $btnClear.Font=New-Object System.Drawing.Font("Segoe UI", 8); $grpLog.Controls.Add($btnClear)

$txtLog = New-Object System.Windows.Forms.RichTextBox; $txtLog.Dock="Fill"; $txtLog.BackColor=$colList; $txtLog.ForeColor="LightGray"; $txtLog.BorderStyle="None"; $txtLog.Font=$fontLog; 
$pnlLogPad = New-Object System.Windows.Forms.Panel; $pnlLogPad.Dock="Fill"; $pnlLogPad.Padding=New-Object System.Windows.Forms.Padding(10,25,10,10); $grpLog.Controls.Add($pnlLogPad); $pnlLogPad.Controls.Add($txtLog)

$btnClear.Add_Click({ $txtLog.Clear(); Log "Log Cleared." "Gray" })

# --- ROW 4: ACTIONS ---
$pnlAct = New-Object System.Windows.Forms.Panel; $pnlAct.Dock="Fill"; $pnlAct.Padding=New-Object System.Windows.Forms.Padding(50,20,50,20)
[void]$masterGrid.Controls.Add($pnlAct, 0, 4)
$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text="START AUTO-UPDATE"; $btnSync.Dock="Left"; $btnSync.Width=500; $btnSync.BackColor=[System.Drawing.Color]::DeepSkyBlue; $btnSync.ForeColor="White"; $btnSync.FlatStyle="Flat"; $btnSync.Font=$fontHeader; $pnlAct.Controls.Add($btnSync)
$btnVer = New-Object System.Windows.Forms.Button; $btnVer.Text="CHECK DB VERSIONS"; $btnVer.Dock="Right"; $btnVer.Width=500; $btnVer.BackColor=[System.Drawing.Color]::DarkOrange; $btnVer.ForeColor="White"; $btnVer.FlatStyle="Flat"; $btnVer.Font=$fontHeader; $pnlAct.Controls.Add($btnVer)

# --- ROW 5: STATUS ---
$stat = New-Object System.Windows.Forms.StatusStrip; $stat.BackColor=[System.Drawing.Color]::FromArgb(30,30,30)
$lblStat = New-Object System.Windows.Forms.ToolStripStatusLabel; $lblStat.Text="Ready."; $lblStat.ForeColor="White"
$stat.Items.Add($lblStat); [void]$masterGrid.Controls.Add($stat, 0, 5)

# ======================================================================
#  CORE LOGIC
# ======================================================================

function Log($msg, $color="White") {
    $txtLog.SelectionStart=$txtLog.TextLength; $txtLog.SelectionColor=[System.Drawing.Color]::FromName($color); $txtLog.AppendText("$msg`r`n"); $txtLog.ScrollToCaret(); [System.Windows.Forms.Application]::DoEvents()
}

function Toggle($state) { $btnCon.Enabled=$state; $btnSync.Enabled=$state; $btnCreateDB.Enabled=$state }

# --- SCANNER LOGIC (IMPORTED FROM v66 - FIXES REMOTE/PATH DETECTION) ---
function Scan-Server {
    param($Target)
    $Script:TargetServer = $Target
    $Script:IsRemote = ($Target -ne "localhost" -and $Target -ne $env:COMPUTERNAME -and $Target -ne "127.0.0.1")
    
    $Block = {
        $Result = [PSCustomObject]@{ Valid=$false; Version="Not Found"; Path=$null; InstallPath=$null }
        $CommonPaths = @()
        if ($env:ProgramFiles) { $CommonPaths += Join-Path $env:ProgramFiles "ProPhoenix\Server Application Manager\AppReg_Main.xml" }
        if (${env:ProgramFiles(x86)}) { $CommonPaths += Join-Path ${env:ProgramFiles(x86)} "ProPhoenix\Server Application Manager\AppReg_Main.xml" }
        
        # Deep Scan Drives (C:, D:, etc.) - This fixes the D: drive detection
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
                        # Fuzzy match for DB Utility logic
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
                Log "Scanning Remote: $Target..." "Gray"
                $Args = @{ ComputerName=$Target; ScriptBlock=$Block; ErrorAction="Stop" }
                if ($Script:WindowsCreds) { $Args.Credential = $Script:WindowsCreds }
                $Data = Invoke-Command @Args
            } catch {
                Log "⚠ Remote scan failed ($($_.Exception.Message)). Falling back to Local." "Orange"
                $Data = Invoke-Command -ScriptBlock $Block
            }
        } else {
            $Data = Invoke-Command -ScriptBlock $Block
        }

        if ($Data.Valid) {
            $Script:DBSyncRoot = Join-Path $Data.InstallPath "DB Sync"
            $txtPath.Text = $Script:DBSyncRoot
            $lblVerDisplay.Text = "Ver: $($Data.Version)"; $lblVerDisplay.ForeColor = [System.Drawing.Color]::LimeGreen
            Log "✔ Found Utility: $($Data.Version)" "Lime"
        } else {
            $lblVerDisplay.Text = "Utility Not Found"; $lblVerDisplay.ForeColor = [System.Drawing.Color]::Red
            Log "❌ Utility Not Found on Target." "Red"
        }
    } catch { Log "Scan Error: $($_.Exception.Message)" "Red" }
}

$btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select DB Sync Folder"
    if ($fbd.ShowDialog() -eq "OK") { $txtPath.Text=$fbd.SelectedPath; $Script:DBSyncRoot=$fbd.SelectedPath; Log "Path Set Manually." "Gray" }
})

# --- CONNECT & AUTO-TARGET ---
$btnCon.Add_Click({
    Toggle $false; $listDBs.Items.Clear(); $Script:TargetMap=@{}
    Log "Connecting..." "White"
    try {
        $cs = "Server=$($txtS.Text);Network Library=DBMSSOCN;User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=5"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        
        $cmd = $cn.CreateCommand()
        $cmd.CommandText = "SELECT Name FROM sys.databases WHERE database_id > 4 AND Name NOT IN ('master','model','msdb','tempdb','ReportServer') ORDER BY Name"
        $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        
        Log "✔ Connected." "Lime"; $lblStat.Text = "Connected."
        if ($chkSave.Checked) {
            $pw = $txtP.Text | ConvertTo-SecureString -AsPlainText -Force
            [PSCustomObject]@{ Server=$txtS.Text; User=$txtU.Text; Password=$pw } | Export-Clixml $Script:CredFile
        }
        
        # Trigger Scan Logic (v66 integration)
        Scan-Server $txtS.Text

        # Auto-Match
        if ($Script:DBSyncRoot) {
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
                    # Handle folder spaces (v66 style path checking)
                    $TestPath = Join-Path $Script:DBSyncRoot $Folder
                    if ($Script:IsRemote) {
                        # Simple assumption for remote to avoid double invoke
                        $Key = "$Tag $db"; $listDBs.Items.Add($Key, $true); $Script:TargetMap[$Key] = @{ DB=$db; Folder=$Folder }
                        Log "   + Auto-Queued: $db" "Cyan"
                    } else {
                        if (!(Test-Path $TestPath)) { $Folder = $Folder.Replace(" ", "") }
                        if (Test-Path (Join-Path $Script:DBSyncRoot $Folder)) {
                            $Key = "$Tag $db"; $listDBs.Items.Add($Key, $true); $Script:TargetMap[$Key] = @{ DB=$db; Folder=$Folder }
                            Log "   + Auto-Queued: $db" "Cyan"
                        }
                    }
                }
            }
        } 
    } catch { Log "❌ Error: $($_.Exception.Message)" "Red" } finally { Toggle $true }
})

# --- SYNC LOGIC (IMPORTED FROM v66) ---
$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select a DB!"); return }
    if (!$Script:DBSyncRoot) { [System.Windows.Forms.MessageBox]::Show("Utility Path Not Set!", "Error"); return }
    Toggle $false
    
    foreach ($item in $listDBs.CheckedItems) {
        $Info = $Script:TargetMap[$item]; $db = $Info.DB; $f = $Info.Folder
        Log "Updating $db..." "Cyan"; [System.Windows.Forms.Application]::DoEvents()
        
        $targetFolder = Join-Path $Script:DBSyncRoot $f
        $jobBlock = {
            param($TargetFolder, $IP, $DB, $User, $Pass, $XML)
            if (!(Test-Path $TargetFolder)) { return "MISSING_FOLDER" }
            [xml]$x = $XML; $x.PnxPakager.SourceServer.IPAddress=$IP; $x.PnxPakager.SourceServer.DBName=$DB
            $x.PnxPakager.SourceServer.UserName=$User; $x.PnxPakager.SourceServer.Password=$Pass; $x.PnxPakager.SourceServer.SyncType="2"
            $x.Save((Join-Path $TargetFolder "PnxAutoNewDBSyn.xml"))
            $Exe = Join-Path $TargetFolder "PnxDBSync.exe"
            $proc = Start-Process -FilePath $Exe -WorkingDirectory $TargetFolder -PassThru -WindowStyle Minimized; $proc.WaitForExit()
            return "DONE"
        }

        try {
            $xmlContent = Get-Content $Script:XmlTarget -Raw
            $argsList = @($targetFolder, $txtS.Text, $db, $txtU.Text, $txtP.Text, $xmlContent)
            
            if ($Script:IsRemote) {
                $cmdArgs = @{ ComputerName=$Script:TargetServer; ScriptBlock=$jobBlock; ArgumentList=$argsList }
                if ($Script:WindowsCreds) { $cmdArgs.Credential = $Script:WindowsCreds }
                Invoke-Command @cmdArgs | Out-Null
            } else {
                Invoke-Command -ScriptBlock $jobBlock -ArgumentList $argsList | Out-Null
            }
            Log "   ✔ Completed" "Lime"
        } catch { Log "Error: $($_.Exception.Message)" "Red" }
    }
    Log "Finished." "White"; Toggle $true
})

# --- INSTALL / UNINSTALL (IMPORTED FROM v66) ---
$RunAppMgrAction = {
    param($Action)
    $FileName = "Appreg_main.xml"
    $Dirs = @("ProPhoenix\Server Application Manager", "Program Files (x86)\ProPhoenix\Server Application Manager", "Program Files\ProPhoenix\Server Application Manager")
    $AppRegPath = $null
    
    foreach ($d in Get-PSDrive -PSProvider FileSystem) { 
        foreach ($sub in $Dirs) { 
            $p=Join-Path $d.Root $sub|Join-Path -ChildPath $FileName
            if(Test-Path $p){$AppRegPath=$p;break} 
        }
        if($AppRegPath){break} 
    }
    
    if(!$AppRegPath){ return "ERROR: AppReg Not Found" }
    $AppMgrDir = Split-Path $AppRegPath -Parent; $Exe = Join-Path $AppMgrDir "PnxAppMgr.exe"
    $Bat = Join-Path $env:TEMP "ExecDBUtil.bat"
    Set-Content $Bat "@echo off`ncd /d `"$AppMgrDir`"`n`"$Exe`" `"$Action`" `"DBUtility`"`npause" -Encoding ASCII
    Start-Process $Bat -Verb RunAs -Wait; return "Executed $Action"
}

$RunApp = { param($M)
    if($Script:IsRemote){ 
        $cmdArgs=@{ComputerName=$Script:TargetServer;ScriptBlock=$RunAppMgrAction;ArgumentList=$M}
        if($Script:WindowsCreds){$cmdArgs.Credential=$Script:WindowsCreds}
        Invoke-Command @cmdArgs
    } else { Invoke-Command -ScriptBlock $RunAppMgrAction -ArgumentList $M }
}
$btnInstall.Add_Click({ &$RunApp "INSTALL" }); $btnUninstall.Add_Click({ &$RunApp "UNINSTALL" })

# --- CREATE DB LOGIC ---
function Show-NewDBDialog {
    $dbForm = New-Object System.Windows.Forms.Form; $dbForm.Text="Create DB"; $dbForm.Size="400,350"; $dbForm.StartPosition="CenterParent"
    function Add-Field($lbl,$y,$def){$l=New-Object System.Windows.Forms.Label;$l.Text=$lbl;$l.Location="20,$y";$dbForm.Controls.Add($l);$t=New-Object System.Windows.Forms.TextBox;$t.Text=$def;$t.Location="120,$($y-3)";$t.Width=240;$dbForm.Controls.Add($t);return $t}
    $inDB=Add-Field "Database" 30 "Police"; $inJID=Add-Field "JurisID" 70 "1000"; $inSt=Add-Field "State" 110 "MA"; $inN=Add-Field "Name" 150 "ProPhoenix"; $inA=Add-Field "Alias" 190 "PNX"
    $btn=New-Object System.Windows.Forms.Button;$btn.Text="CREATE";$btn.DialogResult="OK";$btn.Location="120,250";$dbForm.Controls.Add($btn);$dbForm.AcceptButton=$btn
    if($dbForm.ShowDialog() -eq "OK"){return @{DB=$inDB.Text;JID=$inJID.Text;St=$inSt.Text;Nm=$inN.Text;Al=$inA.Text}} return $null
}
$btnCreateDB.Add_Click({ 
    if(!$Script:DBSyncRoot){return} $d=Show-NewDBDialog; if(!$d){return}; Toggle $false; Log "Creating..." "Cyan"
    try {
        $tf=Join-Path $Script:DBSyncRoot "Police"; if(!(Test-Path $tf)){$tf=Join-Path $Script:DBSyncRoot "Phoenix Master"}
        $x=[xml](Get-Content $Script:XmlTarget); $x.PnxPakager.SourceServer.IPAddress=$txtS.Text; $x.PnxPakager.SourceServer.DBName=$d.DB; $x.PnxPakager.SourceServer.SyncType="1"
        $x.PnxPakager.SourceServer.JurisID=$d.JID; $x.PnxPakager.SourceServer.State=$d.St; $x.PnxPakager.SourceServer.JurisName=$d.Nm; $x.PnxPakager.SourceServer.JurisAlias=$d.Al
        $x.Save((Join-Path $tf "PnxAutoNewDBSyn.xml"))
        Start-Process (Join-Path $tf "PnxDBSync.exe") -WorkingDirectory $tf -Wait; Log "✔ Created" "Lime"; $btnCon.PerformClick()
    } catch { Log "Error" "Red" } finally { Toggle $true }
})

$btnVer.Add_Click({ Toggle $false; Log "Checking Versions..." "Cyan"; try { $cs="Server=$($txtS.Text);Network Library=DBMSSOCN;User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=10"; $cn=New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open(); $sb=New-Object System.Text.StringBuilder; $sb.Append("DECLARE @s NVARCHAR(MAX)=''; CREATE TABLE #R(N NVARCHAR(255),V NVARCHAR(MAX)); "); foreach ($item in $listDBs.CheckedItems) { $db=$Script:TargetMap[$item].DB; $sb.Append(" IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$db') BEGIN IF EXISTS(SELECT 1 FROM [$db].sys.tables WHERE name='KPIDBVersion') INSERT INTO #R SELECT '$db', CAST(Version AS NVARCHAR(MAX)) FROM [$db].dbo.KPIDBVersion; ELSE INSERT INTO #R VALUES ('$db', 'No Table'); END ELSE INSERT INTO #R VALUES ('$db', 'Not Found'); ") }; $sb.Append(" SELECT * FROM #R ORDER BY N; DROP TABLE #R;"); $cmd=$cn.CreateCommand(); $cmd.CommandText=$sb.ToString(); $da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds=New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close(); foreach($r in $ds.Tables[0].Rows) { Log "$($r.N) : $($r.V)" "White" } } catch { Log "Error" "Red" } finally { Toggle $true } })

# --- INIT ---
$form.Add_Load({ if (Test-Path $Script:CredFile) { $c = Import-Clixml $Script:CredFile; $txtS.Text=$c.Server; $txtU.Text=$c.User; $txtP.Text=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($c.Password)); $chkSave.Checked=$true } })
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()