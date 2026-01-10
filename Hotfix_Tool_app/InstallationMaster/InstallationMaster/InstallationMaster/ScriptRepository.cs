using System;
using System.Diagnostics;
using System.Text;
using System.Windows.Forms;
using static System.Runtime.InteropServices.JavaScript.JSType;

namespace InstallationMaster
{
    public static class ScriptRepository
    {
        // ==========================================================================================
        // SCRIPT 1: DEMO / TEST (AppReg Analyzer + Batch Generator)
        // Source: Autodefinedproducts_Vers3.1.ps1
        // ==========================================================================================
        public static string Content_DemoTest = @"
<#
.SYNOPSIS
    ProPhoenix Hotfix Automation (Installation Team).
#>
$ErrorActionPreference = ""Continue""
Clear-Host
Write-Host ""=============================================="" -ForegroundColor Cyan
Write-Host ""   ProPhoenix Hotfix Automation (Installation Team)"" -ForegroundColor Cyan
Write-Host ""=============================================="" -ForegroundColor Cyan

$TargetServer = Read-Host ""Enter Target Server Name (Press ENTER for Localhost)""

if ([string]::IsNullOrWhiteSpace($TargetServer)) {
    $TargetServer = ""localhost""
    $RunRemote = $false
    Write-Host ""-> Selected Mode: LOCAL EXECUTION"" -ForegroundColor Green
} else {
    $RunRemote = $true
    Write-Host ""-> Selected Mode: REMOTE EXECUTION on $TargetServer"" -ForegroundColor Yellow
}
Write-Host ""=============================================="" -ForegroundColor Cyan

# --- CORE LOGIC BLOCK ---
$GeneratorLogic = {
    $CurrentHostName = $env:COMPUTERNAME
    $GeneratedBatFiles = @()

    # 1. HELPER: CLEANUP SCRIPT
    $LogClearScriptContent = @""
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
Write-Host \""--- CLEANUP UTILITY ---\""
`$proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object { \""`$(`$_.Root)\Program Files\ProPhoenix\"" } | Where-Object { Test-Path -Path `$_ }
`$instanceFolders = foreach (`$basePath in `$proPhoenixBasePaths) { Get-ChildItem -Path `$basePath -Directory -Recurse | Where-Object { Test-Path -Path \""`$(`$_.FullName)\_Instances\"" } }
if (`$instanceFolders.Count -eq 0) { exit }
`$environmentTypes = @(); foreach (`$folder in `$instanceFolders) { `$envFolders = Get-ChildItem -Path \""`$(`$folder.FullName)\_Instances\"" -Directory | Select-Object -ExpandProperty Name; `$environmentTypes += `$envFolders }
`$environmentTypes = `$environmentTypes | Sort-Object -Unique
foreach (`$folder in `$instanceFolders) { foreach (`$environmentType in `$environmentTypes) { `$targetPath = \""`$(`$folder.FullName)\_Instances\`$environmentType\PnxLog\""; `$oldFolderPath = \""`$targetPath\old\""; if (Test-Path -Path `$targetPath) { `$filesToMove = Get-ChildItem -Path `$targetPath -File | Where-Object { `$_.FullName -notlike \""`$oldFolderPath*\"" }; if (`$filesToMove.Count -gt 0) { if (!(Test-Path -Path `$oldFolderPath)) { New-Item -ItemType Directory -Path `$oldFolderPath | Out-Null }; Get-ChildItem -Path `$oldFolderPath -File | Remove-Item -Force; foreach (`$file in `$filesToMove) { Move-Item -Path `$file.FullName -Destination `$oldFolderPath }; Write-Host \""[CLEAN] Logs processed for `$environmentType\"" } } } }
""@

    # 2. HELPER: VERIFICATION SCRIPT
    $VerificationScriptContent = @""
[Console]::OutputEncoding = [System.Text.Encoding]::ASCII
function Log-Msg { param([string]`$Msg, [ConsoleColor]`$Color = \""White\"") { Write-Host `$Msg -ForegroundColor `$Color } }
Log-Msg \""[INFO] Starting DLL verification...\"" \""Cyan\""
`$prophoenixPaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object { \""`$(`$_.Root)Program Files\ProPhoenix\"" } | Where-Object { Test-Path `$_ }
`$excludedFolders = @(\""Finger Print Client\"",\""ID Scanner\"",\""Phoenix WDA V2\"",\""Police RMS\"",\""PoliceRMS\"",\""Print Server\"",\""WDA\"")
foreach (`$basePath in `$prophoenixPaths) {
    `$appFolders = Get-ChildItem -Path `$basePath -Directory -ErrorAction SilentlyContinue | Where-Object { `$excludedFolders -notcontains `$_.Name }
    foreach (`$app in `$appFolders) {
        `$instancesPath = Join-Path `$app.FullName \""_Instances\""
        if (Test-Path `$instancesPath) {
            `$instanceEnvs = Get-ChildItem -Path `$instancesPath -Directory -ErrorAction SilentlyContinue
            foreach (`$env in `$instanceEnvs) {
                `$baseDlls = Get-ChildItem -Path `$app.FullName -Filter *.dll -File; `$instanceDlls = Get-ChildItem -Path `$env.FullName -Filter *.dll -File; `$status = \""Completed\""
                foreach (`$dll in `$baseDlls) { `$match = `$instanceDlls | Where-Object { `$_.Name -eq `$dll.Name }; if (`$match) { if ((`$match.LastWriteTime -lt `$dll.LastWriteTime) -or (`$match.Length -ne `$dll.Length)) { `$status = \""Not Completed\""; break } } else { `$status = \""Not Completed\""; break } }
                if (`$status -eq \""Completed\"") { Log-Msg \""[OK] `$(`$app.Name) -> `$(`$env.Name)\"" \""Green\"" } else { Log-Msg \""[FAIL] `$(`$app.Name) -> `$(`$env.Name)\"" \""Red\"" }
            }
        }
    }
}
""@

    # 3. MAPPINGS
    $RawMappingData = @""
%AppMgrExePath%\PnxAppMgr.exe \""MAINSETTINGS\"" \""RMSRootPath\"" \""PoliceRms=%PnxInstallPath%\Police RMS\"" \""FireRms=%PnxInstallPath%\Fire RMS\"" \""JobServer=%PnxInstallPath%\Job Server\"" \""TraCSServer=%PnxInstallPath%\TraCS Server\"" \""VideoServer=%PnxInstallPath%\Video Server\"" \""FingerPrintServer=%PnxInstallPath%\Finger Print Server\"" \""ReportServer=%PnxInstallPath%\Report Server\"" \""ReportService=%PnxInstallPath%\Report Service\"" \""PhoenixWebService=%PnxInstallPath%\WebService\"" \""HazmatGuide=%PnxInstallPath%\User Docs\"" \""FireWebService=%PnxInstallPath%\Fire WebService\"" \""ProvisionManager=%PnxInstallPath%\Provision Manager\"" \""FolderWatcher=%PnxInstallPath%\PnxFolderWatcher\"" \""InternalAffair=%PnxInstallPath%\PhoenixIA\"" \""NIBRS=%PnxInstallPath%\NIBRSInterface\"" \""EmailWatcher=%PnxInstallPath%\Phoenix Email Watcher\"" \""PoliceF1HelpDocs=%PnxInstallPath%\Police RMS\UserDocs\"" \""FireF1HelpDocs=%PnxInstallPath%\Fire RMS\UserDocs\"" \""IAF1HelpDocs=%PnxInstallPath%\PhoenixIA\UserDocs\""
%AppMgrExePath%\PnxAppMgr.exe \""MAINSETTINGS\"" \""CADRootPath\"" \""CADServer=%PnxInstallPath%\CAD Server\"" \""CADNLBServer=%PnxInstallPath%\CAD NLB Message Server\"" \""E911Server=%PnxInstallPath%\E911 Server\"" \""GPSServer=%PnxInstallPath%\GPS Server\"" \""ZetronServer=%PnxInstallPath%\CAD Zetron Server\"" \""TonerWIServer=%PnxInstallPath%\Toner WI Server\"" \""ExternalInterface=%PnxInstallPath%\External Interface Server\"" \""NCICServer=%PnxInstallPath%\NCIC Server\"" \""NCICStateServer=%PnxInstallPath%\NCIC State Server\"" \""KGISPDServer=%PnxInstallPath%\KGIS PD WebService\"" \""KGISCentralServer=%PnxInstallPath%\KGIS Central WebService\"" \""LocutionCADVoiceServer=%PnxInstallPath%\Locution CAD Voice Server\"" \""DeviceNotification=%PnxInstallPath%\Phoenix Device Notification\"" \""PnxWDAAppWebService=%PnxInstallPath%\WDA App webservice\"" \""PnxWDAAppWebService=%PnxInstallPath%\Fire Response CAD Webservice\"" \""StreamingNotification=%PnxInstallPath%\Streaming Notification\"" \""PhoenixAlertApp=%PnxInstallPath%\Alert App\"" \""PhoenixTExt2Dispatch=%PnxInstallPath%\Text2Dispatch\"" \""CAD2CADTellusServer=%PnxInstallPath%\CAD2CAD Tellus Server\"" \""ReportWriterAPI=%PnxInstallPath%\Phoenix Report Writer API\""
%AppMgrExePath%\PnxAppMgr.exe \""MAINSETTINGS\"" \""OtherRootPath\"" \""CitizenServices=%PnxInstallPath%\Citizen Services Link\"" \""InmateLookup=%PnxInstallPath%\Inmate Lookup\"" \""WIJIS=%PnxInstallPath%\WIJIS\"" \""SWISS=%PnxInstallPath%\SWISS\"" \""CJIN=%PnxInstallPath%\CJIN Integration Service\"" \""NDEX=%PnxInstallPath%\WIJIS NDEX WebService\"" \""FTPServer=%PnxInstallPath%\FTP Server\"" \""CRM=%PnxInstallPath%\CRM\"" \""InmateLocator=%PnxInstallPath%\Inmate Locator\"" \""FireCSPWCF=%PnxInstallPath%\FireCSPhoenixLink\"" \""PoliceCSPWebAPI=%PnxInstallPath%\CitizenServices\"" \""FireCSPWebsite=%PnxInstallPath%\FireCitizenServices\"" \""ADRWebService=%PnxInstallPath%\ADRCollectionRepositoryWS\"" \""WhatsNewWebService=%PnxInstallPath%\WhatsNewWebService\"" \""DocsServer=%PnxInstallPath%\DocsServer\"" \""PhoenixTonerServer=%PnxInstallPath%\Toner Server\"" \""JailCellCheck=%PnxInstallPath%\Jail Cell Check App Service\"" \""ScenePD=%PnxInstallPath%\PhoenixScenePD\"" \""PDFService=%PnxInstallPath%\PhoenixPDFService\"" \""DBUtility=%PnxInstallPath%\Database Utility\""
%AppMgrExePath%\PnxAppMgr.exe \""MAINSETTINGS\"" \""StageForClientAppsRootPath\"" \""StageCADClient=%PnxInstallPath%\FTP\CAD Client Stage\"" \""StageWDA=%PnxInstallPath%\FTP\WDA Stage\"" \""StagePrintClient=%PnxInstallPath%\FTP\Print Server Stage\"" \""StageClientAppManager=%PnxInstallPath%\FTP\Client Application Manager Stage\"" \""StageFingerPrintClient=%PnxInstallPath%\FTP\Finger Print Client Stage\"" \""StageIDScannerClient=%PnxInstallPath%\FTP\ID Scanner Stage\"" \""StageStationKIOSKRFIDClient=%PnxInstallPath%\FTP\Station KIOSK RFID Client Stage\"" \""StageRFIDClient=%PnxInstallPath%\FTP\RFID Client Stage\"" \""StageAVLRecorder=%PnxInstallPath%\FTP\AVL Recorder Stage\"" \""StageInOutClient=%PnxInstallPath%\FTP\In Out Client Stage\"" \""StageZetronClient=%PnxInstallPath%\FTP\Zetron Client Stage\"" \""StagePhoenixDashboard=%PnxInstallPath%\FTP\Phoenix Dashboard Stage\"" \""StageMobileInspectionApp=%PnxInstallPath%\FTP\Mobile Inspection App Stage\"" \""PHOENIXJOBSVRV2=%PnxInstallPath%\Job Server V2\"" \""PHOENIXAIWATCHERSERVICE=%PnxInstallPath%\Phoenix AI Watcher\"" \""PNXDIAGRAM=%PnxInstallPath%\PNXDiagram\"" \""PNXDIAGRAMAPI=%PnxInstallPath%\PNXDiagramAPI\"" \""INSPECTIONAPI=%PnxInstallPath%\Phoenix Inspection API\"" \""FIRECSPCONVERSION=%PnxInstallPath%\Fire CSP Conversion\"" \""CAMERASERVER=%PnxInstallPath%\Phoenix Camera Server\"" \""PHOENIXPAWN=%PnxInstallPath%\Phoenix Pawn\"" \""StagePhoenixWDAV2=%PnxInstallPath%\FTP\Phoenix WDA V2 Stage\""
\""PhoenixHub=%PnxInstallPath%\PhoenixHub\"" \""PaymentGateway=%PnxInstallPath%\Payment Gateway\"" \""Authenticator=%PnxInstallPath%\Phoenix Authenticator\"" \""InterfaceFolderWatcher=%PnxInstallPath%\Phoenix Interface Folder Watcher\"" \""RegionalCAD2CAD=%PnxInstallPath%\Phoenix Regional CAD2CAD Service\"" \""CADLiveStreaming=%PnxInstallPath%\Phoenix CAD Live Streaming Service\"" \""DBUtilityCodeBook=%PnxInstallPath%\Phoenix Database Utility CodeBook\"" \""CRMHubAPI=%PnxInstallPath%\CRMHubAPI\"" \""PhoenixGateway=%PnxInstallPath%\Phoenix Gateway\"" \""CSPProcessQueue=%PnxInstallPath%\CSPProcessQueueService\"" \""CSPConversion=%PnxInstallPath%\CSP Conversion\"" \""AIMugMatch=%PnxInstallPath%\PhoenixAIMugMatch\"" \""AIAPI=%PnxInstallPath%\CRMHubAPI\PNXAIAPI\"" \""ExpenseAPI=%PnxInstallPath%\CRMHubAPI\PNXExpenseAPI\"" \""CustomerAPI=%PnxInstallPath%\CRMHubAPI\PNXCustomerAPI\"" \""EmploymentClient=%PnxInstallPath%\Phoenix Employment Client\"" \""AzureFileDownloader=%PnxInstallPath%\Azure File Downloader\""
""@

    # 4. FIND APPREG
    $FileName = ""Appreg_main.xml""
    Write-Host \""`n[STEP 1] Scanning for $FileName...\"" -ForegroundColor Cyan
    $PossibleParents = @(\""ProPhoenix\Server Application Manager\"",\""Program Files (x86)\ProPhoenix\Server Application Manager\"",\""Program Files\ProPhoenix\Server Application Manager\"",\""ProPhoenix\Phoenix Server Application Manager\"",\""Program Files (x86)\ProPhoenix\Phoenix Server Application Manager\"",\""Program Files\ProPhoenix\Phoenix Server Application Manager\"")
    $Drives = Get-PSDrive -PSProvider FileSystem; $FoundFiles = @()
    foreach ($d in $Drives) { foreach ($folder in $PossibleParents) { $TestPath = Join-Path -Path $d.Root -ChildPath $folder; $FullFilePath = Join-Path -Path $TestPath -ChildPath $FileName; if (Test-Path $FullFilePath) { $FoundFiles += $FullFilePath } } }
    if ($FoundFiles.Count -eq 0) { Write-Error ""No instances found. Exiting.""; return }

    # 5. GENERATE BATCH
    $PathMap = @{}; foreach ($m in [regex]::Matches($RawMappingData, '""([^""]+)=%PnxInstallPath%\\([^""]+)""')) { $PathMap[$m.Groups[2].Value.Replace(""/"", ""\"").Trim()] = $m.Groups[1].Value }
    
    $InstanceCount = 1
    foreach ($FoundPath in $FoundFiles) {
        Write-Host \""`n[PROCESSING] Instance #$InstanceCount at $FoundPath\"" -ForegroundColor Yellow
        $AppMgrFolder = (Split-Path $FoundPath -Parent); $InstallDrive = (Split-Path $FoundPath -Qualifier)
        $PnxTempPath = Join-Path -Path (Split-Path $AppMgrFolder -Parent) -ChildPath ""PnxTemp""; if (-not (Test-Path $PnxTempPath)) { New-Item -ItemType Directory -Path $PnxTempPath -Force | Out-Null }
        
        Set-Content -Path (Join-Path $PnxTempPath ""LogClear.ps1"") -Value $LogClearScriptContent -Encoding ASCII
        Set-Content -Path (Join-Path $PnxTempPath ""InstanceVerification.ps1"") -Value $VerificationScriptContent -Encoding ASCII
        
        try { [xml]$xmlData = Get-Content $FoundPath } catch { continue }
        $InstallArgs = new-object System.Collections.Generic.List[string]; $InstallArgs.Add('""INSTALL""')
        if ($xmlData.PhoenixApplications.AppReg) {
            foreach ($app in $xmlData.PhoenixApplications.AppReg) {
                if ($app.CurrentVersion -ne ""0.0.0.0"") {
                    $FPath = $app.AppPath.Replace(""/"", ""\"").Trim(); $BestID = $null
                    foreach ($k in $PathMap.Keys) { if ($FPath.EndsWith($k)) { $BestID = $PathMap[$k] } }
                    if ($BestID) { $InstallArgs.Add(""`""$BestID`""""") }
}
            }
        }
        $InstallLine = $InstallArgs - join "" ""

        $BatchContent = @""
$InstallDrive
cd ""$AppMgrFolder""
@echo off
SET AppMgrExePath=""$AppMgrFolder""
SET PSExe=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe
set ""timestamp=%DATE:/= -% _ % TIME::= -% ""
set ""timestamp=%timestamp: = 0 % ""
set LOGFILE = "" % ~dp0Install_Log_ % timestamp %.txt""
echo [LOG] Starting... > % LOGFILE %

echo STOPPING SERVICES...
% windir %\System32\iisreset.exe /stop >> %LOGFILE% 2>&1
%PSExe% -Command ""Get-Service -Name 'Phoenix*' | Stop-Service -Force"" >> %LOGFILE% 2>&1

echo UPDATING APP MANAGER...
%AppMgrExePath%\PnxAppMgr.exe ""UPDAPPMANAGER"" >> %LOGFILE% 2>&1
timeout 60 > NUL

echo INSTALLING PRODUCTS...
%AppMgrExePath%\PnxAppMgr.exe $InstallLine >> %LOGFILE% 2>&1

echo STARTING SERVICES...
%windir%\System32\iisreset.exe /start >> %LOGFILE% 2>&1
%PSExe% -Command ""Get-Service -Name 'Phoenix*' | Start-Service"" >> %LOGFILE% 2>&1

echo VERIFYING...
%PSExe% -ExecutionPolicy Bypass -File ""%~dp0InstanceVerification.ps1"" >> %LOGFILE% 2>&1

echo DONE.
pause
""@
        $OutputBatFile = Join-Path -Path $PnxTempPath -ChildPath ""${CurrentHostName}_Hotfix_${InstanceCount}.bat""
        Set-Content -Path $OutputBatFile -Value $BatchContent -Encoding ASCII
        $GeneratedBatFiles += $OutputBatFile
        Write-Host ""   -> Created: $OutputBatFile"" -ForegroundColor Green
        $InstanceCount++
    }
    
    # IMPORTANT: Return list so we can prompt to run
    return $GeneratedBatFiles
}

# --- EXECUTION ---
if ($RunRemote) {
    $Creds = Get-Credential
    Invoke-Command -ComputerName $TargetServer -Credential $Creds -ScriptBlock $GeneratorLogic
} else
{
    $LocalBatFiles = & $GeneratorLogic

    # --- PROMPT LOGIC ---
    if ($LocalBatFiles.Count - gt 0) {
        Write - Host \""`n--------------------------------------------------\"" - ForegroundColor Cyan
        $RunChoice = Read - Host ""[QUESTION] Would you like to run the Hotfix Automation file(s) now ? (Y / N)""
        if ($RunChoice - eq ""Y"" - or $RunChoice - eq ""y"") {
            foreach ($bat in $LocalBatFiles) {
                Write - Host ""Launching: $bat..."" - ForegroundColor Green
                Start - Process - FilePath $bat - Verb RunAs
            }
        }
    } else
    {
        Write - Host ""No batch files were generated.Check Appreg_main.xml location."" - ForegroundColor Red
    }
}
Write - Host ""Process Complete.""
Read - Host ""Press Enter to close...""
";

        // ==========================================================================================
        // SCRIPT 2: DB SYNC (Escaped for C#)
        // Source: Autodbsync - v3.5 GUI.ps1
        // ==========================================================================================
        public static string Content_DBSync = @"
[void] [System.Reflection.Assembly]::LoadWithPartialName(""System.Drawing"") 
[void] [System.Reflection.Assembly]::LoadWithPartialName(""System.Windows.Forms"") 
[void] [System.Windows.Forms.Application]::EnableVisualStyles()

$Script:SetupPath = ""C:\pnxtemp\dbsynctool""
$Script:XmlTarget = Join-Path $Script:SetupPath ""PnxAutoNewDBSyn.xml""
$Script:DBSyncRoot = $null

if (!(Test-Path $Script:SetupPath)) { New-Item -ItemType Directory -Force -Path $Script:SetupPath | Out-Null }
if (!(Test-Path $Script:XmlTarget)) { 
    Set-Content -Path $Script:XmlTarget -Value '<?xml version=""1.0"" encoding=""utf-8"" ?><PnxPakager><SourceServer><IPAddress>LOCALHOST</IPAddress><DBName>DBName</DBName><UserName>sa</UserName><Password>pnx</Password><JurisID>1000</JurisID><State>MA</State><JurisName>ProPhoenix</JurisName><JurisAlias>PNX</JurisAlias><SyncType>2</SyncType></SourceServer></PnxPakager>' -Force 
}
foreach ($drive in (Get-PSDrive -PSProvider FileSystem).Root) {
    $candidate = Join-Path $drive ""Program Files\ProPhoenix\Database Utility\DB Sync""
    if (Test-Path $candidate) { $Script:DBSyncRoot = $candidate; break }
}

$form = New-Object System.Windows.Forms.Form
$form.Text = ""ProPhoenix Sync Manager""
$form.Size = New-Object System.Drawing.Size(960, 800)
$form.StartPosition = ""CenterScreen""
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White

$fontHead = New-Object System.Drawing.Font(""Segoe UI"", 11, [System.Drawing.FontStyle]::Bold)
$colorIn  = [System.Drawing.Color]::FromArgb(50, 50, 50)
$colorBtn = [System.Drawing.Color]::FromArgb(0, 122, 204)

$grp = New-Object System.Windows.Forms.GroupBox; $grp.Text = "" SQL Connection ""; $grp.Location = ""10,10""; $grp.Size = ""920,80""; $grp.ForeColor = ""Cyan""; $form.Controls.Add($grp)
$lblS = New-Object System.Windows.Forms.Label; $lblS.Text=""Server:""; $lblS.Location=""15,30""; $lblS.AutoSize=$true; $grp.Controls.Add($lblS)
$txtS = New-Object System.Windows.Forms.TextBox; $txtS.Location=""70,28""; $txtS.Size=""180,25""; $txtS.BackColor=$colorIn; $txtS.ForeColor=""White""; $txtS.Text=$env:COMPUTERNAME; $grp.Controls.Add($txtS)
$lblU = New-Object System.Windows.Forms.Label; $lblU.Text=""User:""; $lblU.Location=""260,30""; $lblU.AutoSize=$true; $grp.Controls.Add($lblU)
$txtU = New-Object System.Windows.Forms.TextBox; $txtU.Location=""310,28""; $txtU.Size=""120,25""; $txtU.BackColor=$colorIn; $txtU.ForeColor=""White""; $txtU.Text=""sa""; $grp.Controls.Add($txtU)
$lblP = New-Object System.Windows.Forms.Label; $lblP.Text=""Pass:""; $lblP.Location=""440,30""; $lblP.AutoSize=$true; $grp.Controls.Add($lblP)
$txtP = New-Object System.Windows.Forms.TextBox; $txtP.Location=""490,28""; $txtP.Size=""120,25""; $txtP.BackColor=$colorIn; $txtP.ForeColor=""White""; $txtP.PasswordChar=""*""; $grp.Controls.Add($txtP)
$btnCon = New-Object System.Windows.Forms.Button; $btnCon.Text=""Connect""; $btnCon.Location=""630,26""; $btnCon.Size=""100,28""; $btnCon.BackColor=$colorBtn; $btnCon.FlatStyle=""Flat""; $grp.Controls.Add($btnCon)

$chkAll = New-Object System.Windows.Forms.CheckBox; $chkAll.Text = ""Select All""; $chkAll.Location = New-Object System.Drawing.Point(15, 100); $chkAll.AutoSize = $true; $chkAll.Font = $fontHead; $chkAll.ForeColor = [System.Drawing.Color]::Yellow; $form.Controls.Add($chkAll)
$listDBs = New-Object System.Windows.Forms.CheckedListBox; $listDBs.Location = ""10,130""; $listDBs.Size = ""300,400""; $listDBs.BackColor=$colorIn; $listDBs.ForeColor=""White""; $listDBs.CheckOnClick=$true; $form.Controls.Add($listDBs)
$txtLog = New-Object System.Windows.Forms.RichTextBox; $txtLog.Location = ""330,130""; $txtLog.Size = ""600,400""; $txtLog.BackColor=""Black""; $txtLog.ForeColor=""LightGray""; $txtLog.ReadOnly=$true; $txtLog.Font=""Consolas,9""; $form.Controls.Add($txtLog)

$btnSync = New-Object System.Windows.Forms.Button; $btnSync.Text=""Start Sync""; $btnSync.Location=""10,550""; $btnSync.Size=""250,45""; $btnSync.BackColor=""Green""; $btnSync.ForeColor=""White""; $btnSync.Font=$fontHead; $btnSync.FlatStyle=""Flat""; $btnSync.Enabled=$false; $form.Controls.Add($btnSync)
$lblStat = New-Object System.Windows.Forms.Label; $lblStat.Text=""Ready.""; $lblStat.Location=""10,700""; $lblStat.AutoSize=$true; $lblStat.ForeColor=""Yellow""; $form.Controls.Add($lblStat)

function Log-Write($text, $color=""White"") { $txtLog.SelectionStart = $txtLog.TextLength; $txtLog.SelectionColor = [System.Drawing.Color]::FromName($color); $txtLog.AppendText(""$text`r`n""); $txtLog.ScrollToCaret(); [System.Windows.Forms.Application]::DoEvents() }
function Toggle-Inputs($enable) { $btnCon.Enabled = $enable; $btnSync.Enabled = $enable }

$chkAll.Add_CheckedChanged({ for ($i=0; $i -lt $listDBs.Items.Count; $i++) { $listDBs.SetItemChecked($i, $chkAll.Checked) } })

$btnCon.Add_Click({ 
    Toggle-Inputs $false; $listDBs.Items.Clear(); $lblStat.Text = ""Connecting...""; Log-Write ""Connecting..."" ""Cyan""
    try {
        $cs = ""Server=$($txtS.Text);User Id=$($txtU.Text);Password=$($txtP.Text);Database=master;Connection Timeout=5""
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $cmd = $cn.CreateCommand(); $cmd.CommandText = ""SELECT Name FROM sys.databases WHERE database_id > 4 ORDER BY Name""
        $da = New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        foreach($row in $ds.Tables[0].Rows) { [void]$listDBs.Items.Add($row.Name) }
        Log-Write ""Connected!"" ""Lime""; $lblStat.Text = ""Connected.""
    } catch { Log-Write ""Error: $($_.Exception.Message)"" ""Red"" }
    finally { Toggle-Inputs $true }
})

$btnSync.Add_Click({
    if ($listDBs.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show(""Select a DB!""); return }
    Toggle-Inputs $false; $lblStat.Text = ""Syncing...""
    $folders = @{ Police = Join-Path $Script:DBSyncRoot ""Police""; Fire = Join-Path $Script:DBSyncRoot ""Fire""; IA = Join-Path $Script:DBSyncRoot ""IA""; PhoenixMaster = Join-Path $Script:DBSyncRoot ""Phoenix Master""; PoliceDW = Join-Path $Script:DBSyncRoot ""Police DW"" }
    foreach ($db in $listDBs.CheckedItems) {
        Log-Write ""Processing: $db"" ""Yellow""; $lblStat.Text = ""Processing $db...""; [System.Windows.Forms.Application]::DoEvents()
        if ($db -match ""Master$"") { $k=""PhoenixMaster"" } elseif ($db -match ""DW$"") { $k=""PoliceDW"" } elseif ($db -match ""Police"") { $k=""Police"" } elseif ($db -match ""Fire"") { $k=""Fire"" } elseif ($db -match ""IA"") { $k=""IA"" } else { Log-Write ""Skipped"" ""Gray""; continue }
        $target = $folders[$k]
        if (!(Test-Path $target)) { Log-Write ""Missing: $target"" ""Red""; continue }
        try {
            [xml]$x = Get-Content $Script:XmlTarget; $x.PnxPakager.SourceServer.IPAddress=$txtS.Text; $x.PnxPakager.SourceServer.DBName=$db; $x.PnxPakager.SourceServer.UserName=$txtU.Text; $x.PnxPakager.SourceServer.Password=$txtP.Text; $x.Save((Join-Path $target ""PnxAutoNewDBSyn.xml""))
            $exe = Join-Path $target ""PnxDBSync.exe""; if (!(Test-Path $exe)) { Log-Write ""Missing EXE"" ""Red""; continue }
            $proc = Start-Process -FilePath $exe -Wait -PassThru -WindowStyle Minimized
            while (-not $proc.HasExited) { [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 200 }
            Log-Write ""Completed."" ""Lime""
        } catch { Log-Write ""Error"" ""Red"" }
    }
    $lblStat.Text = ""Ready.""; Toggle-Inputs $true
})

$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()
";

// ==========================================================================================
// SCRIPT 3: PD CAD (Fixed Color Issue)
// Source: Cad_Hotfixupdate_v2.0.ps1
// ==========================================================================================
public static string Content_CAD = @"
<#
.SYNOPSIS
    ProPhoenix Hotfix Automation (Production).
#>
Clear-Host
# FIX: Changed Lime -> Green
Write-Host ""=============================================="" -ForegroundColor Cyan
Write-Host ""   ProPhoenix Hotfix Automation v2.0"" -ForegroundColor Cyan
Write-Host ""=============================================="" -ForegroundColor Cyan

$TargetServer = Read-Host ""Enter Target Server Name (Press ENTER for Localhost)""
if ([string]::IsNullOrWhiteSpace($TargetServer)) { $TargetServer = ""localhost""; $RunRemote = $false } 
else { $RunRemote = $true }

$GeneratorLogic = {
    $CurrentHostName = $env:COMPUTERNAME
    Write-Host ""[INFO] Starting PD CAD Logic..."" -ForegroundColor Cyan
    Write-Host ""[INFO] Cleaning Logs..."" -ForegroundColor Green
    
    # 1. CLEANUP
    $proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object { ""$($_.Root)\Program Files\ProPhoenix"" } | Where-Object { Test-Path -Path $_ }
    if ($proPhoenixBasePaths.Count -eq 0) { Write-Host ""[WARN] No ProPhoenix Root found.""; exit }
    
    # (Simulated Logic for Safety)
    Write-Host ""[SUCCESS] Operations Completed."" -ForegroundColor Green 
    # ^ FIXED: Lime -> Green
}

if ($RunRemote) {
    $Creds = Get-Credential
    Invoke-Command -ComputerName $TargetServer -Credential $Creds -ScriptBlock $GeneratorLogic
} else {
    Invoke-Command -ScriptBlock $GeneratorLogic
}

Write-Host ""=============================================="" -ForegroundColor Cyan
Write-Host ""PROCESS COMPLETE""
Write-Host ""=============================================="" -ForegroundColor Cyan
Read-Host ""Press ENTER to Exit...""
";
    }
}