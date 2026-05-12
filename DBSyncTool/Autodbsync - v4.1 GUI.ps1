# ======================================================================
#  ProPhoenix DB Utility Dashboard - v44.0 (Final Release)
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
$form.Text = "ProPhoenix DB Utility Dashboard"  # <--- RENAMED HERE
$form.Size = New-Object System.Drawing.Size(1000, 850)
$form.StartPosition = "CenterScreen"
$form.BackColor = $colBg
$form.ForeColor = $colText

# --- HEADER PANEL ---
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Top"; $pnlHead.Height=80; $pnlHead.BackColor=$colPanel; $form.Controls.Add($pnlHead)
$picLogo = New-Object System.Windows.Forms.PictureBox; $picLogo.Size="200,60"; $picLogo.Location="15,10"; $picLogo.SizeMode="Zoom"; if(Test-Path $Script:LogoFile){$picLogo.Image=[System.Drawing.Image]::FromFile($Script:LogoFile)}; $pnlHead.Controls.Add($picLogo)
$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="DB Utility Dashboard"; $lblTitle.AutoSize=$true; $lblTitle.Location="230,25"; $lblTitle.Font=$fontTitle; $lblTitle.ForeColor=$colAccent; $pnlHead.Controls.Add($lblTitle)

$lblVerDisplay = New-Object System.Windows.Forms.Label
$lblVerDisplay.Text = "DB Utility Version: --"
$lblVerDisplay.AutoSize = $false; $lblVerDisplay.TextAlign="MiddleRight"; $lblVerDisplay.Size="350,30"; $lblVerDisplay.Location="620,25"; $lblVerDisplay.Font=$fontHead; $lblVerDisplay.ForeColor=[System.Drawing.Color]::LightGray; $pnlHead.Controls.Add($lblVerDisplay)

# --- MAIN LAYOUT ---
$pnlBody = New-Object System.Windows.Forms.Panel; $pnlBody.Dock="Fill"; $pnlBody.Padding=15; $form.Controls.Add($pnlBody)

# --- SQL CONNECTION ---
$grp = New-Object System.Windows.Forms.GroupBox; $grp.Text=" Target Connection "; $grp.Size="950,80"; $grp.Location="15,100"; $grp.ForeColor=$colAccent; $grp.Font=$fontHead; $pnlBody.Controls.Add($grp)

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
    $btnCon.Enabled = $enable; $btnSync.Enabled = $enable; $btnVer.Enabled = $enable
    $btnUninstall.Enabled = $enable; $btnInstall.Enabled = $enable
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

# --- UNIVERSAL SCAN LOGIC (LOCAL & REMOTE) ---
function Scan-Server {
    param($Target)
    $Script:TargetServer = $Target
    $Script:IsRemote = ($Target -ne "localhost" -and $Target -ne $env:COMPUTERNAME -and $Target -ne "127.0.0.1")
    
    $Block = {
        $Dirs = @("ProPhoenix\Server Application Manager", "Program Files (x86)\ProPhoenix\Server Application Manager", "Program Files\ProPhoenix\Server Application Manager")
        $Result = [PSCustomObject]@{ Valid=$false; Version="Not Found"; Path=$null; Err="" }
        
        # 1. Quick Scan
        $CommonPaths = @()
        if ($env:ProgramFiles) { $CommonPaths += Join-Path $env:ProgramFiles "ProPhoenix\Server Application Manager\AppReg_Main.xml" }
        if (${env:ProgramFiles(x86)}) { $CommonPaths += Join-Path ${env:ProgramFiles(x86)} "ProPhoenix\Server Application Manager\AppReg_Main.xml" }
        
        $FoundPath = $null
        foreach($p in $CommonPaths) { if(Test-Path $p) { $FoundPath=$p; break } }
        
        # 2. Deep Scan
        if (-not $FoundPath) {
            foreach ($d in Get-PSDrive -PSProvider FileSystem) {
                foreach ($sub in $Dirs) {
                    $p = Join-Path $d.Root $sub | Join-Path -ChildPath "Appreg_main.xml"
                    if (Test-Path $p) { $FoundPath=$p; break }
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
                            # READ CurrentVersion OR Version
                            $v = if ($app.CurrentVersion) { $app.CurrentVersion } else { $app.Version }
                            $Result.Version = if ([string]::IsNullOrWhiteSpace($v)) { "0.0.0.0" } else { $v }
                            $Result.Valid = $true
                            return $Result
                        }
                    }
                }
            } catch { $Result.Err = "Read Error" }
        }
        return $Result
    }

    # Execute Scan
    try {
        if ($Script:IsRemote) {
            try {
                $Args = @{ ComputerName=$Target; ScriptBlock=$Block; ErrorAction="Stop" }
                if ($Script:WindowsCreds) { $Args.Credential = $Script:WindowsCreds }
                $Data = Invoke-Command @Args
            } catch {
                if ($_.Exception.Message -match "Access is denied") {
                    Log-Write "⚠ Access Denied. Prompting for Admin Creds..." "Yellow"
                    $Script:WindowsCreds = $host.ui.PromptForCredential("Remote Admin", "Enter Admin Creds for $Target", "$Target\Administrator", "")
                    if ($Script:WindowsCreds) {
                        $Args.Credential = $Script:WindowsCreds
                        $Data = Invoke-Command @Args
                    } else { throw "Cancelled" }
                } else { throw $_ }
            }
        } else {
            $Data = Invoke-Command -ScriptBlock $Block
        }
        
        $Script:TargetDBUtilVersion = $Data.Version
        if ($Data.Valid) {
            $AppMgrDir = Split-Path $Data.Path -Parent
            $RootDir = Split-Path $AppMgrDir -Parent
            $Script:DBSyncRoot = Join-Path $RootDir "Database Utility\DB Sync"
            $lblVerDisplay.Text = "Utility Version: $($Data.Version)"
            $lblVerDisplay.ForeColor = [System.Drawing.Color]::Lime
            Log-Write "✔ Found Utility: $($Data.Version)" "Lime"
        } else {
            $lblVerDisplay.Text = "Utility Not Found"
            $lblVerDisplay.ForeColor = [System.Drawing.Color]::Red
            $Script:DBSyncRoot = $null
            Log-Write "⚠ Utility Not Found on Target." "Orange"
        }
        return $Data
    } catch {
        Log-Write "Scan Error: $($_.Exception.Message)" "Red"
        $lblVerDisplay.Text = "Scan Failed"
        $lblVerDisplay.ForeColor = [System.Drawing.Color]::Red
        $Script:TargetDBUtilVersion = "Error"
        return $null
    }
}

$form.Add_Load({ Load-Creds })
$chkAll.Add_CheckedChanged({ for ($i=0; $i -lt $listDBs.Items.Count; $i++) { $listDBs.SetItemChecked($i, $chkAll.Checked) } })

$btnCon.Add_Click({
    Toggle-Inputs $false; $listDBs.Items.Clear(); $lblStat.Text="Connecting..."; Log-Write "Connecting..." "Cyan"
    
    try {
        $cs = "Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=5"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $cmd = $cn.CreateCommand(); $cmd.CommandText = "SELECT Name FROM sys.databases WHERE database_id > 4 AND Name NOT IN ('master','model','msdb','tempdb') ORDER BY Name"
        $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        foreach($row in $ds.Tables[0].Rows) { [void]$listDBs.Items.Add($row.Name) }
        
        Log-Write "✔ SQL Connected." "Lime"
        $lblStat.Text="Connected."
        Save-Creds
        
        # TRIGGER SCAN
        Scan-Server $txtS.Text
        
    } catch { Log-Write "❌ Error: $($_.Exception.Message)" "Red"; $lblStat.Text="Connection Failed." } finally { Toggle-Inputs $true }
})

# --- SYNC LOGIC ---
$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Select a DB!"); return }
    if (!$Script:DBSyncRoot) { [System.Windows.Forms.MessageBox]::Show("Utility Path Not Found on Target!", "Error", "OK", "Error"); return }
    
    Toggle-Inputs $false
    $totalCount = $listDBs.CheckedItems.Count
    $dbIndex = 0; $pbStat.Maximum = 100; $pbStat.Value = 0
    $folders = @{ Police="Police"; Fire="Fire"; IA="IA"; PhoenixMaster="Phoenix Master"; PoliceDW="Police DW" }

    foreach ($db in $listDBs.CheckedItems) {
        $dbIndex++
        $pct = [int](($dbIndex - 1) / $totalCount * 100)
        $lblStat.Text = "Processing $dbIndex of ${totalCount}: $db ( $pct % )"
        $pbStat.Value = $pct; $pbStat.Style = "Marquee"; $pbStat.MarqueeAnimationSpeed = 30
        
        Log-Write "[ $pct % ] Processing: $db" "Cyan"
        [System.Windows.Forms.Application]::DoEvents()

        if ($db -match "Master$") { $k="PhoenixMaster" } elseif ($db -match "DW$") { $k="PoliceDW" } elseif ($db -match "Police") { $k="Police" } elseif ($db -match "Fire") { $k="Fire" } elseif ($db -match "IA") { $k="IA" } else { continue }
        
        # Use proper Join-Path (handling potential remote paths conceptually)
        # Note: Join-Path works on strings, so it's safe even if path is remote style
        $targetFolder = Join-Path $Script:DBSyncRoot $folders[$k]
        
        $jobBlock = {
            param($TargetFolder, $IP, $DB, $User, $Pass, $XML)
            if (!(Test-Path $TargetFolder)) { return "MISSING_FOLDER" }
            
            # Write XML locally on target
            [xml]$x = $XML
            $x.PnxPakager.SourceServer.IPAddress=$IP; $x.PnxPakager.SourceServer.DBName=$DB
            $x.PnxPakager.SourceServer.UserName=$User; $x.PnxPakager.SourceServer.Password=$Pass
            $x.Save((Join-Path $TargetFolder "PnxAutoNewDBSyn.xml"))
            
            $Exe = Join-Path $TargetFolder "PnxDBSync.exe"
            $proc = Start-Process -FilePath $Exe -PassThru -WindowStyle Minimized
            $proc.WaitForExit()
            
            $l = Get-ChildItem $TargetFolder -Filter "DBToolLog*.txt" | Sort LastWriteTime -Desc | Select -First 1
            if ($l) { return Get-Content $l.FullName -Raw } else { return "NO_LOG" }
        }

        try {
            $xmlContent = Get-Content $Script:XmlTarget -Raw
            $argsList = @($targetFolder, $txtS.Text, $db, $txtU.Text, $txtP.Text, $xmlContent)
            
            $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            if ($Script:IsRemote) {
                $cmdArgs = @{ ComputerName=$Script:TargetServer; ScriptBlock=$jobBlock; ArgumentList=$argsList }
                if ($Script:WindowsCreds) { $cmdArgs.Credential = $Script:WindowsCreds }
                $logData = Invoke-Command @cmdArgs
            } else {
                $logData = Invoke-Command -ScriptBlock $jobBlock -ArgumentList $argsList
            }
            
            $stopWatch.Stop()
            $finalTime = $stopWatch.Elapsed.ToString("ss\.f") + "s"

            if ($logData -match "DB Version Updated") { 
                Log-Write "   ✔ Success [ $finalTime ]" "Lime" 
            } else { 
                Log-Write "   ❌ Failed [ $finalTime ]" "Red"
            }
        } catch { Log-Write "Error: $($_.Exception.Message)" "Red" }
        
        $newPct = [int]($dbIndex / $totalCount * 100)
        $pbStat.Style = "Blocks"; $pbStat.Value = $newPct
        $lblStat.Text = "Completed: $db ( $newPct % ) - Took: $finalTime"
        [System.Windows.Forms.Application]::DoEvents()
    }
    
    Log-Write "[ 100 % ] All Operations Completed." "Lime"
    $lblStat.Text = "Sync Cycle Finished (100 %)"; Toggle-Inputs $true; [System.Windows.Forms.MessageBox]::Show("Sync Complete", "Done")
})

$btnVer.Add_Click({
    Toggle-Inputs $false; $lblStat.Text="Checking Versions..."; Log-Write "Checking Versions..." "Cyan"
    
    # Manual Refresh
    Scan-Server $txtS.Text
    
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
        $cmd = $cn.CreateCommand(); $cmd.CommandText = $sb.ToString(); $da=New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds=New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        Log-Write "=== VERSION REPORT ===" "White"
        foreach($r in $ds.Tables[0].Rows) { Log-Write "$($r.N) : $($r.V)" "White" }
    } catch { Log-Write "Error: $($_.Exception.Message)" "Red" } finally { Toggle-Inputs $true; $lblStat.Text="Ready." }
})

# --- DB UTIL EXECUTION ---
$RunAppMgrAction = {
    param($Action)
    $FileName = "Appreg_main.xml"
    $Dirs = @("ProPhoenix\Server Application Manager", "Program Files (x86)\ProPhoenix\Server Application Manager", "Program Files\ProPhoenix\Server Application Manager")
    $AppRegPath = $null
    
    # Re-Find Path in Session
    foreach ($d in Get-PSDrive -PSProvider FileSystem) { 
        foreach ($sub in $Dirs) { 
            $p=Join-Path $d.Root $sub|Join-Path -ChildPath $FileName
            if(Test-Path $p){$AppRegPath=$p;break} 
        }
        if($AppRegPath){break} 
    }
    
    if(!$AppRegPath){ return "ERROR: AppReg Not Found" }
    $AppMgrDir = Split-Path $AppRegPath -Parent
    $Exe = Join-Path $AppMgrDir "PnxAppMgr.exe"
    
    $BatFile = Join-Path $env:TEMP "ExecDBUtil.bat"
    $BatContent = @"
@echo off
cd /d "$AppMgrDir"
"$Exe" "$Action" "DBUtility"
pause
"@
    Set-Content $BatFile $BatContent -Encoding ASCII
    Start-Process $BatFile -Verb RunAs -Wait
    return "Executed $Action"
}

function Exec-Util($act) {
    Toggle-Inputs $false; $lblStat.Text="$act Utility..."
    try {
        if ($Script:IsRemote) {
            $cmdArgs = @{ ComputerName=$Script:TargetServer; ScriptBlock=$RunAppMgrAction; ArgumentList=$act }
            if ($Script:WindowsCreds) { $cmdArgs.Credential = $Script:WindowsCreds }
            $r = Invoke-Command @cmdArgs
            Log-Write "Remote: $r" "Lime"
        } else {
            $r = Invoke-Command -ScriptBlock $RunAppMgrAction -ArgumentList $act
            Log-Write "Local: $r" "Lime"
        }
        
        # Auto-Verify Loop (Check 5 times)
        Log-Write "Verifying Version Update..." "Cyan"
        for ($i=1; $i -le 5; $i++) {
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Seconds 3
            
            $Data = Scan-Server $Script:TargetServer
            if ($Data.Valid) {
                $lblVerDisplay.Text = "Utility Version: $($Data.Version)"
                $lblVerDisplay.ForeColor = [System.Drawing.Color]::Lime
                if ($act -eq "INSTALL" -and $Data.Version -ne "0.0.0.0") { Log-Write "   Verified: $($Data.Version)" "Lime"; break }
            } else {
                $lblVerDisplay.Text = "Utility Not Found"
                $lblVerDisplay.ForeColor = [System.Drawing.Color]::Red
                if ($act -eq "UNINSTALL") { Log-Write "   Verified: Uninstalled" "Lime"; break }
            }
        }
        
    } catch { Log-Write "Error: $($_.Exception.Message)" "Red" } finally { Toggle-Inputs $true; $lblStat.Text="Ready." }
}

$btnUninstall.Add_Click({ Exec-Util "UNINSTALL" })
$btnInstall.Add_Click({ Exec-Util "INSTALL" })

$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()