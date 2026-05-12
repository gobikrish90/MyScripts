<#
.SYNOPSIS
    Installation Hotfix Dashboard v9.0
    - FIX: Resolved "Unexpected token '}'" parser error by providing the full compiled script.
    - FEATURE: Auto-downloads ZIP (Blob -> GDrive -> GitHub), cleans old files, and extracts on startup.
    - CORE: ADSI Agency Telemetry, Glass Theme, Help Docs Dropdown, and right-aligned UI logic intact.
#>

# ==============================================================================
#  0. INSTANT BACKGROUND CONSOLE HIDE (Native App Mode)
# ==============================================================================
if ($host.Name -notmatch "ISE") {
    $hwnd = (Get-Process -Id $PID).MainWindowHandle
    try {
        $type = [Win32Functions.Win32ShowWindowAsync]
    } catch {
        $code = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
        $type = Add-Type -MemberDefinition $code -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru
    }
    if ($hwnd -ne [IntPtr]::Zero) { [void]$type::ShowWindow($hwnd, 0) }
}

Write-Host "[INIT] Booting Installation Hotfix Dashboard v9.0..." -ForegroundColor Cyan

# ==============================================================================
#  1. BULLETPROOF PATH DETECTION & ADMIN ENFORCEMENT
# ==============================================================================
$ScriptPath = $PSScriptRoot
if ([string]::IsNullOrEmpty($ScriptPath)) {
    if ($MyInvocation.MyCommand.Path) { $ScriptPath = Split-Path $MyInvocation.MyCommand.Path -ErrorAction SilentlyContinue } 
    else { $ScriptPath = $PWD.Path }
}
if ([string]::IsNullOrEmpty($ScriptPath)) { $ScriptPath = "C:\" }

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if ($host.Name -notmatch "ISE") { [void]$type::ShowWindow($hwnd, 5) } 
    Write-Host "[WARN] Administrative privileges required. Escalating..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    Exit
}

# ==============================================================================
#  2. GLOBAL ASSEMBLIES, THEME DEFINITIONS & HELPER FUNCTIONS
# ==============================================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

[System.Windows.Forms.Application]::EnableVisualStyles()

function Set-RoundedCorner($Control, $Radius) {
    if ($Control.Width -le 0 -or $Control.Height -le 0) { return }
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $Radius, $Radius, 180, 90)
    $path.AddArc($Control.Width - $Radius, 0, $Radius, $Radius, 270, 90)
    $path.AddArc($Control.Width - $Radius, $Control.Height - $Radius, $Radius, $Radius, 0, 90)
    $path.AddArc(0, $Control.Height - $Radius, $Radius, $Radius, 90, 90)
    $path.CloseFigure()
    $Control.Region = New-Object System.Drawing.Region($path)
}

function Add-GroupBorder($Panel, $Color) {
    $paintBlock = {
        param($sender, $e)
        $g = $e.Graphics
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $pen = New-Object System.Drawing.Pen($Color, 2) 
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $r = 15
        $w = $sender.Width - 3
        $h = $sender.Height - 3
        $path.AddArc(1, 1, $r, $r, 180, 90)
        $path.AddArc($w - $r, 1, $r, $r, 270, 90)
        $path.AddArc($w - $r, $h - $r, $r, $r, 0, 90)
        $path.AddArc(1, $h - $r, $r, $r, 90, 90)
        $path.CloseFigure()
        $g.DrawPath($pen, $path)
        $pen.Dispose()
        $path.Dispose()
    }.GetNewClosure() 
    $Panel.add_Paint($paintBlock)
}

# Dark Mode Palette
$colorSidebarBg  = [System.Drawing.Color]::FromArgb(255, 20, 20, 25)
$colorMainBg     = [System.Drawing.Color]::FromArgb(255, 28, 28, 35)
$colorCardBg     = [System.Drawing.Color]::FromArgb(255, 35, 35, 45)
$colorRowGlass   = [System.Drawing.Color]::FromArgb(130, 40, 40, 50) 
$colorCardHover  = [System.Drawing.Color]::FromArgb(255, 55, 55, 65)
$colorConsoleBg  = [System.Drawing.Color]::FromArgb(255, 13, 13, 13)
$colorTextWhite  = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
$colorTextMuted  = [System.Drawing.Color]::FromArgb(255, 160, 160, 170)
$colorTabActive  = [System.Drawing.Color]::FromArgb(255, 65, 65, 80)
$colorTabDeact   = [System.Drawing.Color]::FromArgb(255, 30, 30, 40)
$colorGroupBorder= [System.Drawing.Color]::FromArgb(255, 70, 75, 90)
$colorLblDash    = [System.Drawing.Color]::FromArgb(255, 230, 160, 60) 

# Group Themes
$colorLblGen  = [System.Drawing.Color]::FromArgb(255, 240, 100, 100)
$colorBtnGen  = [System.Drawing.Color]::FromArgb(255, 80, 35, 40)    
$colorLblDiag = [System.Drawing.Color]::FromArgb(255, 100, 200, 255)
$colorBtnDiag = [System.Drawing.Color]::FromArgb(255, 30, 70, 110)   
$colorLblSys  = [System.Drawing.Color]::FromArgb(255, 180, 130, 250)
$colorBtnSys  = [System.Drawing.Color]::FromArgb(255, 55, 35, 80)    
$termGreen = [System.Drawing.Color]::FromArgb(255, 46, 204, 113) 
$termCyan  = [System.Drawing.Color]::Cyan
$termGray  = [System.Drawing.Color]::Gray

# Fonts
$fontHeader    = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$fontSubHeader = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$fontMenuBold  = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontTerminal  = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
$fontCleanBold = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$fontCleanVal  = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)
$fontRowText   = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold) 
$script:Font_Copyright = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Regular)

# Core Logic Variables
$Url_GDrive   = "https://drive.google.com/uc?export=download&id=10RxuJaWwqR1S6lbkjL0-_AXddCwOARYI"
$Url_Blob     = "https://produpdates.blob.core.windows.net/web/Prerequisite%20Script%202026/Phoenix%20Installation%20Master.zip?sp=racw&st=2026-01-30T14:01:41Z&se=2032-03-30T22:16:41Z&spr=https&sv=2024-11-04&sr=b&sig=3vXVuby1lcDbQ%2BQQnVzxmmXJsyaRG2sgQwTH9SzPnh4%3D"
$ZipNamePattern = "Phoenix Installation Master*.zip"
$InstallBase    = "C:\pnxtemp\Phoenix Installation Master"
$script:CurrentToolPath = $InstallBase 
$script:ToolsLoaded = $false

# Watermarks
$logoPath = Join-Path -Path $ScriptPath -ChildPath "logo.png"
$global:fadedWatermark = $null
$global:splashWatermark = $null

if (Test-Path $logoPath) {
    try { 
        $origImg = [System.Drawing.Image]::FromFile($logoPath)
        $global:fadedWatermark = New-Object System.Drawing.Bitmap($origImg.Width, $origImg.Height)
        $g1 = [System.Drawing.Graphics]::FromImage($global:fadedWatermark)
        $matrix1 = New-Object System.Drawing.Imaging.ColorMatrix; $matrix1.Matrix33 = 0.15
        $attr1 = New-Object System.Drawing.Imaging.ImageAttributes
        $attr1.SetColorMatrix($matrix1, [System.Drawing.Imaging.ColorMatrixFlag]::Default, [System.Drawing.Imaging.ColorAdjustType]::Bitmap)
        $rect1 = New-Object System.Drawing.Rectangle(0, 0, $origImg.Width, $origImg.Height)
        $g1.DrawImage($origImg, $rect1, 0, 0, $origImg.Width, $origImg.Height, [System.Drawing.GraphicsUnit]::Pixel, $attr1)
        $g1.Dispose()

        $splashLogoSize = 460
        $global:splashWatermark = New-Object System.Drawing.Bitmap($splashLogoSize, $splashLogoSize)
        $g2 = [System.Drawing.Graphics]::FromImage($global:splashWatermark)
        $matrix2 = New-Object System.Drawing.Imaging.ColorMatrix; $matrix2.Matrix33 = 0.60
        $attr2 = New-Object System.Drawing.Imaging.ImageAttributes
        $attr2.SetColorMatrix($matrix2, [System.Drawing.Imaging.ColorMatrixFlag]::Default, [System.Drawing.Imaging.ColorAdjustType]::Bitmap)
        $rect2 = New-Object System.Drawing.Rectangle(0, 0, $splashLogoSize, $splashLogoSize)
        $g2.DrawImage($origImg, $rect2, 0, 0, $origImg.Width, $origImg.Height, [System.Drawing.GraphicsUnit]::Pixel, $attr2)
        $g2.Dispose()
    } catch {}
}

# ==========================================================================
#  3. EMBEDDED STEP-BY-STEP GUIDE TEXT
# ==========================================================================
$script:GuideText = @"
================================================================================
                    PROPHOENIX INSTALLATION DASHBOARD GUIDE
================================================================================
Prepared by: Gobinath R, Installation Engineer
Date: March 04, 2026

1. OVERVIEW
--------------------------------------------------------------------------------
This document consolidates the ProPhoenix Installation Dashboard steps into an 
operational, step-by-step guide. It covers downloading the Installation Master 
Tool, loading the Master Zip, and executing DBSync, RMS PD Hotfix, CAD PD Hotfix, 
and Test/Demo Hotfix workflows.

2. PREREQUISITES
--------------------------------------------------------------------------------
* Windows administrator privileges on the target servers (Web/App/SQL).
* Ability to run .EXE/.BAT or PowerShell scripts (.PS1). 
* Network access to either Azure Blob storage or Google Drive (Blob URL 
  Permission only provided by the Cloud Team for the Public IP).
* Sufficient disk space to download/extract the Master Zip and perform backups.

3. DOWNLOAD AND PREPARE THE INSTALLATION MASTER TOOL
--------------------------------------------------------------------------------
1. Click the "Download Prerequisite" button in the dashboard to fetch the files.
2. Download the ZIP file to a local folder (e.g., C:\Downloads).
3. Open the download folder and extract the ZIP.
4. Identify the launchers (.EXE, .PS1, .BAT). Right-click -> Properties -> Unblock.

4. LAUNCH THE DASHBOARD & LOAD MASTER ZIP
--------------------------------------------------------------------------------
1. Run the dashboard. If prompted with "No Valid Zip Found", click OK.
2. Click "Search / Reload Master". The tool will scan directories for the payload.
3. Verify the status indicates "Master Loaded Successfully".

5. SCRIPTS AVAILABLE IN THE DASHBOARD
--------------------------------------------------------------------------------
* DB Sync Tool: Automated DB sync for Live/Test; utility install/uninstall.
* RMS Server PD: Production RMS hotfix with minimal downtime (~20 mins).
* CAD Server PD: CAD update (~10 mins) with auto client update.
* Test/Demo Hotfix: Automated update for non-production environments.
* Minimal Downtime (PS & Batch): Reduces service downtime for RMS updates.
* App Pool 32-bit False: Sets IIS App Pool 'Enable 32-Bit Apps' to False.
* Instance Verification: Ensures Base vs Instance DLL/file parity.
* Clients Auto Update: Opens client stages to trigger updates.
* SVR Session Clear: Clears CAD instance session files.
* SQL Memory Setting: Sets SQL Server max memory to 75% of RAM.

6. DBSYNC TOOL — RUN ON SQL SERVER
--------------------------------------------------------------------------------
1. Launch the DBSync Tool on the SQL Server.
2. Enter the Required Credentials for the SQL Server.
3. Uncheck 'Auto DB Sync' to manually select target databases if necessary.
4. Live Environment: Installs Utility and syncs Live, Training, and Master DBs.
5. Test Environment: Installs Utility and syncs Test and Phoenix Master DBs.

7. RMS PRODUCTION (PD) HOTFIX (~20 MINUTES)
--------------------------------------------------------------------------------
1. Run the 'Minimal Downtime (PS)' script first to prep AppReg_Main.
2. Launch 'RMS Server PD'. At the product list prompt, press Y to proceed.
3. The tool updates Application Manager and installs General Apps without stops.
4. Allow IIS and Phoenix services to stop for Webservice, StageClient, etc.
5. After installations, IIS restarts and Instance Update continues automatically.
6. Run 'Instance Verification' to validate Base vs Instance parity.

8. CAD PRODUCTION (PD) HOTFIX (~10 - 15 MINUTES)
--------------------------------------------------------------------------------
1. Launch 'CAD Server PD'. Press Y to proceed at the prompt.
2. Update App Manager and install General Applications (no service stops).
3. Proceed with Stage Clients installation (this WILL stop IIS/Services).
4. The script runs Instance Update, clears SVR Session, and Log Clear.
5. Press any key to start Clients Auto Update.

9. TEST/DEMO HOTFIX — NON-PRODUCTION
--------------------------------------------------------------------------------
1. Launch 'Test/Demo Hotfix'. Review updater settings and press Y.
2. The script updates App Manager and installs all applications automatically.
3. Instance Update and Verification run automatically.
4. Press any key when prompted to trigger Clients Auto Update.

10. POST-INSTALL CHECKS & VALIDATION
--------------------------------------------------------------------------------
* Confirm all services are Running (IIS sites/app pools; Phoenix services).
* Perform Pre-compiler: login and Verify the application Working.
* Review Instance Verification results for parity.
* Ensure IIS App Pool 'Enable 32-Bit Applications = False' where required.
* On SQL Server, verify Max Server Memory is approximately 75% of RAM.
* Run 'Log Cleaner' after collecting any necessary diagnostics.
================================================================================
"@

# ==========================================================================
#  4. ADVANCED TELEMETRY GATHERING & ADSI COMPANY QUERY
# ==========================================================================
$fqdn = "$env:COMPUTERNAME.$env:USERDNSDOMAIN"
$HostName = [System.Net.Dns]::GetHostName()
$IpAddress = "127.0.0.1"
try {
    $PrimaryAdapter = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" | Where-Object { $_.DefaultIPGateway -ne $null } | Select-Object -First 1
    if ($PrimaryAdapter) { $IpAddress = $PrimaryAdapter.IPAddress | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -First 1 }
} catch {}

$AgencyDomain = "Unknown"
try {
    $user = $env:USERNAME
    $searcher = [adsisearcher]"(samaccountname=$user)"
    $result = $searcher.FindOne()
    if ($result -and $result.Properties['company']) {
        $company = $result.Properties['company'][0]
        if (-not [string]::IsNullOrWhiteSpace($company)) {
            $AgencyDomain = $company
        }
    }
    if ($AgencyDomain -eq "Unknown" -and $env:USERDOMAIN) {
        $AgencyDomain = $env:USERDOMAIN
    }
} catch {
    if ($env:USERDOMAIN) { $AgencyDomain = $env:USERDOMAIN }
}

# TRUNCATE AGENCY NAME TO 2 WORDS IF >= 4 WORDS
if ($AgencyDomain -ne "Unknown") {
    $words = $AgencyDomain.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($words.Count -ge 4) {
        $AgencyDomain = $words[0] + " " + $words[1]
    }
}

# ==========================================================================
#  5. SPLASH SCREEN & PRELOADER
# ==========================================================================
$splash = New-Object System.Windows.Forms.Form
$splash.Size = New-Object System.Drawing.Size(450, 450)
$splash.StartPosition = "CenterScreen"
$splash.BackColor = $colorMainBg
$splash.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
Set-RoundedCorner $splash 20

if ($global:splashWatermark) {
    $splash.BackgroundImage = $global:splashWatermark
    $splash.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Center
}

$lblSplashTitle = New-Object System.Windows.Forms.Label
$lblSplashTitle.Text = "Installation Hotfix Dashboard"
$lblSplashTitle.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblSplashTitle.ForeColor = $colorTextWhite
$lblSplashTitle.AutoSize = $false
$lblSplashTitle.Size = New-Object System.Drawing.Size(450, 35)
$lblSplashTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblSplashTitle.Location = New-Object System.Drawing.Point(0, 30)
$lblSplashTitle.BackColor = [System.Drawing.Color]::Transparent
$splash.Controls.Add($lblSplashTitle)

$pnlSplashProgBg = New-Object System.Windows.Forms.Panel
$pnlSplashProgBg.Size = New-Object System.Drawing.Size(390, 25)
$pnlSplashProgBg.Location = New-Object System.Drawing.Point(30, 85)
$pnlSplashProgBg.BackColor = $colorCardBg
Set-RoundedCorner $pnlSplashProgBg 12
$splash.Controls.Add($pnlSplashProgBg)

$global:SplashProgressPercentage = 0
$pnlSplashProgBg.add_Paint({
    param($sender, $e)
    $g = $e.Graphics; $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $percent = $global:SplashProgressPercentage
    if ($percent -lt 0) { $percent = 0 }; if ($percent -gt 100) { $percent = 100 }
    $fillWidth = [int](($percent / 100) * $sender.Width)
    
    if ($fillWidth -gt 0) {
        $brushProgress = New-Object System.Drawing.SolidBrush($termGreen)
        $d = 25 
        if ($fillWidth -ge $d) {
            $path = New-Object System.Drawing.Drawing2D.GraphicsPath
            $path.AddArc(0, 0, $d, $d, 180, 90)
            $path.AddArc($fillWidth - $d, 0, $d, $d, 270, 90)
            $path.AddArc($fillWidth - $d, $sender.Height - $d, $d, $d, 0, 90)
            $path.AddArc(0, $sender.Height - $d, $d, $d, 90, 90)
            $path.CloseFigure()
            $g.FillPath($brushProgress, $path)
            $path.Dispose()
        } else {
            $g.FillRectangle($brushProgress, 0, 0, $fillWidth, $sender.Height)
        }
        $brushProgress.Dispose()
    }
})

$lblSplashLog = New-Object System.Windows.Forms.Label
$lblSplashLog.Size = New-Object System.Drawing.Size(370, 190)
$lblSplashLog.Location = New-Object System.Drawing.Point(40, 140)
$lblSplashLog.BackColor = [System.Drawing.Color]::Transparent
$lblSplashLog.ForeColor = $termCyan
$lblSplashLog.Font = $fontTerminal
$splash.Controls.Add($lblSplashLog)

$global:SplashLogLines = @()
function Log-Splash($msg, $pct) {
    $global:SplashLogLines += "> $msg"
    if ($global:SplashLogLines.Count -gt 11) { $global:SplashLogLines = $global:SplashLogLines[-11..-1] }
    $lblSplashLog.Text = $global:SplashLogLines -join "`r`n"
    $global:SplashProgressPercentage = $pct
    $pnlSplashProgBg.Invalidate(); $splash.Invalidate() 
    [System.Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 250 
}

$splash.Add_Shown({
    Log-Splash "Starting pre-requisite configuration..." 10
    Log-Splash "Verifying Security Policies..." 40
    Log-Splash "Configuring Dashboard Environment..." 80
    Log-Splash "Initialization complete. Launching UI..." 100
    Start-Sleep -Milliseconds 400 
    $splash.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $splash.Close()
})

if ($splash.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { exit }

$preloader = New-Object System.Windows.Forms.Form
$preloader.Size = New-Object System.Drawing.Size(350, 100)
$preloader.StartPosition = "CenterScreen"
$preloader.BackColor = $colorCardBg
$preloader.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
Set-RoundedCorner $preloader 15
Add-GroupBorder $preloader $termCyan

$lblPreTitle = New-Object System.Windows.Forms.Label
$lblPreTitle.Text = "Compiling Dashboard UI..."
$lblPreTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblPreTitle.ForeColor = $colorTextWhite
$lblPreTitle.AutoSize = $false
$lblPreTitle.Size = New-Object System.Drawing.Size(350, 30)
$lblPreTitle.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblPreTitle.Location = New-Object System.Drawing.Point(0, 25)
$preloader.Controls.Add($lblPreTitle)

$preloader.Show()
$preloader.Refresh()

# ==========================================================================
#  6. DASHBOARD CORE LOGIC & FUNCTIONS
# ==========================================================================
function Ensure-LogDir {
    $LogDir = Join-Path $InstallBase "Logs"
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    return $LogDir
}

function Write-Terminal($msg, $colorName = "LightGray") {
    try {
        $LogFile = Join-Path (Ensure-LogDir) "Deployment_Audit.log"
        $Timestamp = Get-Date -Format "HH:mm:ss.fff"
        $FullMsg = "[$Timestamp] [SYS] $msg"
        Add-Content -Path $LogFile -Value $FullMsg -ErrorAction SilentlyContinue
        
        if ($script:TermConsole) {
            $script:TermConsole.SelectionStart = $script:TermConsole.TextLength
            $script:TermConsole.SelectionLength = 0
            
            if ($colorName -eq "Cyan" -or $colorName -eq "CyanAccent") { $mappedColor = $termCyan }
            elseif ($colorName -eq "Lime" -or $colorName -eq "StatusGreen") { $mappedColor = $termGreen }
            elseif ($colorName -eq "Red" -or $colorName -eq "HeaderRed") { $mappedColor = $colorAccentRed }
            else { $mappedColor = $colorTextWhite }
            
            $script:TermConsole.SelectionColor = $mappedColor
            $script:TermConsole.AppendText("$FullMsg`n")
            $script:TermConsole.ScrollToCaret()
            [System.Windows.Forms.Application]::DoEvents()
        }
    } catch {}
}

function Update-Status($msg, $isError = $false) {
    if ($script:lblStatus) {
        $script:lblStatus.Text = "Status: $msg"
        if ($isError) { $script:lblStatus.ForeColor = $colorAccentRed }
        else { $script:lblStatus.ForeColor = $termGreen }
        $script:lblStatus.Refresh()
    }
}

function Show-ExecutionLogs {
    if ($null -ne $script:pnlConsole -and $null -ne $script:btnTabLogs) {
        $script:form.SuspendLayout()
        $script:pnlTools.Visible = $false
        $script:pnlConsole.Visible = $true
        
        $script:btnTabLogs.BackColor = $colorTabActive
        $script:btnTabLogs.ForeColor = $colorTextWhite
        $script:btnTabScripts.BackColor = $colorTabDeact
        $script:btnTabScripts.ForeColor = $colorTextMuted
        
        $script:form.ResumeLayout($true)
        if ($script:pnlToolsWrapper) { $script:pnlToolsWrapper.Invalidate($true) }
    }
}

function Show-DashboardGuide {
    $guideForm = New-Object System.Windows.Forms.Form
    $guideForm.Text = "ProPhoenix Installation Dashboard - Step-by-Step Guide"
    $guideForm.Size = New-Object System.Drawing.Size(900, 750)
    $guideForm.StartPosition = "CenterParent"
    
    $guideForm.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)
    $guideForm.ForeColor = [System.Drawing.Color]::Black

    $rtb = New-Object System.Windows.Forms.RichTextBox
    $rtb.Dock = "Fill"
    $rtb.BackColor = [System.Drawing.Color]::White 
    $rtb.ForeColor = [System.Drawing.Color]::FromArgb(30, 30, 30) 
    $rtb.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)
    $rtb.ReadOnly = $true
    $rtb.BorderStyle = "None"
    $rtb.Text = $script:GuideText
    
    $guideForm.Controls.Add($rtb)
    [void]$guideForm.ShowDialog()
}

function Show-HelpPrompt {
    if (-not $script:ToolsLoaded) {
        Update-Status "Master Directory not loaded." $true
        return
    }

    $prompt = New-Object System.Windows.Forms.Form
    $prompt.Text = "Select Task Documentation"
    $prompt.Size = New-Object System.Drawing.Size(440, 200)
    $prompt.StartPosition = "CenterParent"
    $prompt.BackColor = $colorCardBg
    $prompt.ForeColor = $colorTextWhite
    $prompt.FormBorderStyle = "FixedDialog"
    $prompt.MaximizeBox = $false
    $prompt.MinimizeBox = $false

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Select a task to view its documentation:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.AutoSize = $true
    $lbl.Font = $fontMenuBold
    $prompt.Controls.Add($lbl)

    $cmb = New-Object System.Windows.Forms.ComboBox
    $cmb.Location = New-Object System.Drawing.Point(20, 50)
    $cmb.Size = New-Object System.Drawing.Size(380, 30)
    $cmb.Font = $fontRowText
    $cmb.DropDownStyle = "DropDownList"
    $cmb.BackColor = $colorMainBg
    $cmb.ForeColor = $colorTextWhite
    $prompt.Controls.Add($cmb)

    $Files = Get-ChildItem -Path $script:CurrentToolPath -Include *.ps1, *.bat -Recurse -File | Where-Object { $_.Name -notmatch "Prophoenix_Dashboard" }
    $SortedList = $Files | Select-Object Name, FullName, @{Name="Friendly"; Expression={Get-FriendlyName $_.Name}}, @{Name="Rank"; Expression={Get-SortOrder (Get-FriendlyName $_.Name)}} | Sort-Object Rank, Friendly
    
    foreach ($item in $SortedList) {
        [void]$cmb.Items.Add($item.Friendly)
    }
    if ($cmb.Items.Count -gt 0) { $cmb.SelectedIndex = 0 }

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "Open Docs"
    $btnOk.Location = New-Object System.Drawing.Point(300, 100)
    $btnOk.Size = New-Object System.Drawing.Size(100, 35)
    $btnOk.BackColor = $colorBtnDiag
    $btnOk.ForeColor = $colorTextWhite
    $btnOk.FlatStyle = "Flat"
    $btnOk.FlatAppearance.BorderSize = 0
    $btnOk.Font = $fontCleanBold
    $btnOk.DialogResult = "OK"
    $prompt.Controls.Add($btnOk)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "Cancel"
    $btnCancel.Location = New-Object System.Drawing.Point(190, 100)
    $btnCancel.Size = New-Object System.Drawing.Size(100, 35)
    $btnCancel.BackColor = $colorBtnGen
    $btnCancel.ForeColor = $colorTextWhite
    $btnCancel.FlatStyle = "Flat"
    $btnCancel.FlatAppearance.BorderSize = 0
    $btnCancel.Font = $fontCleanBold
    $btnCancel.DialogResult = "Cancel"
    $prompt.Controls.Add($btnCancel)

    $prompt.AcceptButton = $btnOk
    $prompt.CancelButton = $btnCancel

    if ($prompt.ShowDialog() -eq "OK" -and $cmb.SelectedItem) {
        $selectedName = $cmb.SelectedItem.ToString()
        $selectedItem = $SortedList | Where-Object { $_.Friendly -eq $selectedName } | Select-Object -First 1
        
        if ($selectedItem) {
            $path = $selectedItem.FullName
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($path)
            $dir = Split-Path $path -Parent
            
            $helpFiles = Get-ChildItem -Path $dir -File | Where-Object { 
                ($_.BaseName -eq $baseName) -and ($_.Extension -match "\.(pdf|docx|doc|txt|rtf)$") 
            }
            
            if ($helpFiles) {
                Write-Terminal "Opening Documentation: $($helpFiles[0].Name)" "Cyan"
                Start-Process $helpFiles[0].FullName
            } else {
                $docsDir = Join-Path $dir "Docs"
                if (Test-Path $docsDir) {
                    $docs = Get-ChildItem -Path $docsDir -File | Where-Object { $_.Name -match $baseName }
                    if ($docs) {
                        Write-Terminal "Opening Documentation: $($docs[0].Name)" "Cyan"
                        Start-Process $docs[0].FullName
                        return
                    }
                }
                Show-ExecutionLogs
                Write-Terminal "No Help Document found for task: $baseName" "Yellow"
                Update-Status "Documentation file not found." $true
            }
        }
    }
}

function Enable-AdvancedDoubleBuffering($Control) {
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
    $prop = $Control.GetType().GetProperty("DoubleBuffered", $flags)
    if ($prop) { $prop.SetValue($Control, $true, $null) }
    $method = $Control.GetType().GetMethod("SetStyle", $flags)
    if ($method) {
        $styles = [System.Windows.Forms.ControlStyles]::OptimizedDoubleBuffer -bor
                  [System.Windows.Forms.ControlStyles]::AllPaintingInWmPaint -bor
                  [System.Windows.Forms.ControlStyles]::UserPaint -bor
                  [System.Windows.Forms.ControlStyles]::SupportsTransparentBackColor
        $method.Invoke($Control, @($styles, $true))
    }
}

$script:DashboardSessionStart = Get-Date
function Update-TelemetryDisplay {
    try {
        if ($script:lblSessionTimeVal) {
            $TimeSpan = (Get-Date) - $script:DashboardSessionStart
            $script:lblSessionTimeVal.Text = "{0:hh\:mm\:ss}" -f $TimeSpan
        }
    } catch {}
}

# ==========================================================================
#  4. ADVANCED DIAGNOSTICS & PUBLIC IP 
# ==========================================================================
function Check-PublicIP {
    Show-ExecutionLogs
    $script:form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    Update-Status "Checking Public IP..."
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $ip = Invoke-RestMethod -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 5
        Write-Terminal "Public IP Resolved: $ip" "Cyan"
        Update-Status "Public IP Retrieved Successfully."
    } catch {
        Write-Terminal "Failed to reach external IP service." "Red"
        Update-Status "Public IP Check Failed." $true
    }
    $script:form.Cursor = [System.Windows.Forms.Cursors]::Default
}

function Request-BlobAccess {
    Show-ExecutionLogs
    $script:form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    Update-Status "Preparing Access Request Email..."
    Write-Terminal "--- INITIATING EMAIL REQUEST ---" "Cyan"
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $ip = Invoke-RestMethod -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 5
        Write-Terminal "Public IP Resolved: $ip" "Cyan"
        $machineName = $env:COMPUTERNAME
        
        $to = "ITSupport@prophoenix.com"
        $subject = "SFTP enable"
        $body = "HI Team,%0D%0A%0D%0AKindly enable the Public IP to access SFTP/Blob in $machineName Machine.%0D%0A%0D%0ARefer the below details and do the needful.%0D%0A%0D%0AMy IP Address is: $ip"
        
        Start-Process "mailto:$to`?subject=$subject&body=$body"
        
        Write-Terminal "Email client launched." "Lime"
        Update-Status "Email draft created."
    } catch {
        Write-Terminal "Failed to reach external IP service for email draft." "Red"
        Update-Status "IP Check Failed. Cannot draft email." $true
    }
    $script:form.Cursor = [System.Windows.Forms.Cursors]::Default
}

function Run-PreFlightDiagnostics {
    Show-ExecutionLogs
    $script:form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    Update-Status "Running System Diagnostics..."
    Write-Terminal "--- INITIATING PRE-FLIGHT ENVIRONMENT AUDIT ---" "Cyan"
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        if ($freeGB -lt 10) { Write-Terminal "C:\ Drive Space: $freeGB GB (WARNING: LOW STORAGE)" "Red" }
        else { Write-Terminal "C:\ Drive Space: $freeGB GB" "Lime" }

        $iis = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
        if ($iis) { Write-Terminal "IIS Service (W3SVC): $($iis.Status)" "Lime" } 
        else { Write-Terminal "IIS Service (W3SVC): Not Installed / Not Found" "Yellow" }

        $sql = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
        if ($sql) { Write-Terminal "SQL Service (MSSQLSERVER): $($sql.Status)" "Lime" } 
        else { Write-Terminal "SQL Service (MSSQLSERVER): Not Installed / Not Found" "Yellow" }

        Write-Terminal "Local PS Execution Policy: $(Get-ExecutionPolicy)" "White"

        Write-Terminal "Testing SFTP (sftp.prophoenix.com:25544)..." "Yellow"
        $sftpRes = Test-NetConnection -ComputerName "sftp.prophoenix.com" -Port 25544 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($sftpRes) { Write-Terminal "SFTP Connection: SUCCESS (OPEN)" "Lime" }
        else { Write-Terminal "SFTP Connection: FAILED (BLOCKED)" "Red" }

        Write-Terminal "Purging Browser Cache & Temp Files..." "Yellow"
        $CachePaths = @("$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*", "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*", "$env:TEMP\*", "$env:WINDIR\Temp\*")
        foreach ($path in $CachePaths) { try { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue } catch {} }
        Write-Terminal "Cache Purge Complete." "Lime"

        Update-Status "Diagnostics Completed Successfully."
    } catch { 
        Write-Terminal "Diagnostic Error: $_" "Red" 
        Update-Status "Diagnostic Error encountered." $true
    }
    Write-Terminal "--- PRE-FLIGHT AUDIT COMPLETE ---" "Cyan"
    $script:form.Cursor = [System.Windows.Forms.Cursors]::Default
}

function Get-DownloadsPath {
    try {
        $path = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders")."{374DE290-123F-4565-9164-39C4925E467B}"
        if (Test-Path $path) { return $path }
    } catch {}
    $path = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
    if (Test-Path $path) { return $path }
    return $null
}

function Test-ZipValidity($ZipPath) { try { [System.IO.Compression.ZipFile]::OpenRead($ZipPath).Dispose(); return $true } catch { return $false } }

function Get-FriendlyName($fileName) {
    if ($fileName -match "32bitfalse") { return "App Pool Set False" }
    if ($fileName -match "SessionClear") { return "SVR Session Clear" }
    if ($fileName -match "SQLMemory") { return "SQL Memory Set" }
    if ($fileName -match "InstanceVerification") { return "Instance Update Verification" }
    if ($fileName -match "LaunchShortcuts") { return "Clients Auto Update" }
    if ($fileName -match "Autodbsync" -or $fileName -match "DB Sync") { return "DB Sync Tool" }
    if ($fileName -match "RMS" -and $fileName -match "PD") { return "RMS Server Production" }
    if ($fileName -match "Cad_Hotfix" -or $fileName -match "CAD PD" -or ($fileName -match "CAD" -and $fileName -match "PD")) { return "CAD Server Production" }
    if ($fileName -match "Autodefined" -or $fileName -match "Test-DemoHotfix" -or ($fileName -match "Demo" -and $fileName -match "Test")) { return "Test/Demo Hotfix" }
    if ($fileName -match "Minimal Downtime" -and $fileName -match "PS") { return "Minimal Downtime (PS)" }
    if ($fileName -match "Minimal Downtime" -and $fileName -match "Bat") { return "Minimal Downtime (Batch)" }
    if ($fileName -match "Minimal Downtime") { return "Minimal Downtime Deployment" }
    if ($fileName -match "Log Clearence" -or $fileName -match "Logcleaner") { return "Log Cleaner" }
    $clean = $fileName -replace "\.ps1$","" -replace "\.bat$","" -replace "_", " " -replace "-v\d+\.\d+", "" -replace "v\d+\.\d+", "" -replace "\s+", " "
    return $clean.Trim()
}

function Get-SortOrder($friendlyName) {
    switch ($friendlyName) {
        "DB Sync Tool" { return 1 }
        "RMS Server Production" { return 2 }
        "CAD Server Production" { return 3 }
        "Test/Demo Hotfix" { return 4 }
        "Minimal Downtime (PS)" { return 5 }
        "Minimal Downtime (Batch)" { return 6 }
        "Minimal Downtime Deployment" { return 7 }
        "Instance Verification" { return 8 }
        "Clients Auto Update" { return 9 }
        "Log Cleaner" { return 10 }
        "App Pool Set False" { return 11 }
        "SVR Session Clear" { return 12 }
        "SQL Memory Set" { return 13 }
        default { return 50 } 
    }
}

function Set-FolderPermissions($path, $silent=$false) {
    if (-not $silent) { Write-Terminal "Applying advanced ACLs to Directory..." "Yellow" }
    [System.Windows.Forms.Application]::DoEvents()
    try { 
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $aclArgs = "`"$path`" /grant `"Everyone:(OI)(CI)F`" `"IUSR:(OI)(CI)F`" `"NETWORK SERVICE:(OI)(CI)F`" `"${currentUser}:(OI)(CI)F`" /T /C /Q"
        Start-Process "icacls.exe" -ArgumentList $aclArgs -WindowStyle Hidden -Wait 
        if (-not $silent) { Write-Terminal "ACLs successfully applied." "Lime" }
    } catch {
        if (-not $silent) { Write-Terminal "Failed to apply ACLs: $_" "Red" }
    }
}

function Unblock-ExtractedFiles($path, $silent=$false) {
    if (-not $silent) { Write-Terminal "Unblocking script files..." "Yellow" }
    [System.Windows.Forms.Application]::DoEvents()
    try { 
        Get-ChildItem -Path $path -Recurse -File | Unblock-File -ErrorAction SilentlyContinue 
        if (-not $silent) { Write-Terminal "Files successfully unblocked." "Lime" }
    } catch {
        if (-not $silent) { Write-Terminal "Failed to unblock files: $_" "Red" }
    }
}

function Launch-File($path, $friendlyName) {
    if (-not (Test-Path $path)) { Write-Terminal "EXECUTION HALTED: File not found." "Red"; return }
    $workDir = Split-Path -Path $path -Parent
    Write-Terminal ">>> Launching: $friendlyName" "White"
    Update-Status "Script launched successfully."

    try {
        if ($path -match "\.bat$") { 
            Start-Process "cmd.exe" -ArgumentList "/c `"$path`" & pause" -Verb RunAs -WorkingDirectory $workDir 
        } 
        elseif ($path -match "Minimal Downtime") { 
            Start-Process "powershell_ise.exe" -ArgumentList "-NoProfile -File `"$path`"" -Verb RunAs -WorkingDirectory $workDir 
        } 
        else { 
            Start-Process "powershell.exe" -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$path`"" -Verb RunAs -WorkingDirectory $workDir 
        }
        Write-Terminal "Execution started successfully." "Lime"
    } catch { Write-Terminal "CRITICAL LAUNCH FAILURE: $_" "Red"; Update-Status "Failed to launch script." $true }
}

function Refresh-List {
    $script:pnlTools.Controls.Clear()
    [int]$Y = 10 
    
    if (-not $script:ToolsLoaded) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text="No Scripts Detected. Please click 'Search / Reload Master'."
        $lbl.AutoSize=$true
        $lbl.Left=15; $lbl.Top=15
        $lbl.Font=$fontRowText
        $lbl.BackColor=[System.Drawing.Color]::Transparent
        $lbl.ForeColor=$colorTextMuted
        $script:pnlTools.Controls.Add($lbl)
        return
    }

    Set-FolderPermissions $script:CurrentToolPath $true
    Unblock-ExtractedFiles $script:CurrentToolPath $true

    $Files = Get-ChildItem -Path $script:CurrentToolPath -Include *.ps1, *.bat -Recurse -File | Where-Object { $_.Name -notmatch "Prophoenix_Dashboard" }
    $SortedList = $Files | Select-Object Name, FullName, @{Name="Friendly"; Expression={Get-FriendlyName $_.Name}}, @{Name="Rank"; Expression={Get-SortOrder (Get-FriendlyName $_.Name)}} | Sort-Object Rank, Friendly
    
    foreach ($item in $SortedList) {
        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size(890, 36) 
        $card.Location = New-Object System.Drawing.Point(15, $Y)
        $card.BackColor = $colorRowGlass
        $card.Cursor = "Hand"
        Set-RoundedCorner $card 8
        
        $card.Add_MouseEnter({ $this.BackColor = $colorCardHover }.GetNewClosure())
        $card.Add_MouseLeave({ $this.BackColor = $colorRowGlass }.GetNewClosure())

        $l = New-Object System.Windows.Forms.Label
        $l.Text = $item.Friendly 
        $l.Font = $fontRowText
        $l.Left = 20; $l.Top = 7; $l.Width = 700 
        $l.BackColor = [System.Drawing.Color]::Transparent
        $l.ForeColor = $colorTextWhite
        $l.Add_MouseEnter({ $card.BackColor = $colorCardHover }.GetNewClosure())
        $l.Add_MouseLeave({ $card.BackColor = $colorRowGlass }.GetNewClosure())
        $card.Controls.Add($l)
        
        $b = New-Object System.Windows.Forms.Button
        $b.Text = "LAUNCH"
        $b.Left = 780; $b.Top = 4
        $b.Size = New-Object System.Drawing.Size(90, 28) 
        $b.BackColor = $colorMainBg
        $b.ForeColor = $colorTextWhite
        $b.FlatStyle = "Flat"
        $b.FlatAppearance.BorderSize = 1
        $b.FlatAppearance.BorderColor = $colorGroupBorder
        $b.Font = $fontCleanBold
        $b.Cursor = "Hand"
        Set-RoundedCorner $b 5
        
        $b.Add_MouseEnter({ $this.BackColor = $colorTabActive; $this.ForeColor = $colorTextWhite }.GetNewClosure())
        $b.Add_MouseLeave({ $this.BackColor = $colorMainBg; $this.ForeColor = $colorTextWhite }.GetNewClosure())

        $path = $item.FullName; $name = $item.Friendly
        $action = { Launch-File $path $name }.GetNewClosure()
        $b.Add_Click($action)
        $card.Controls.Add($b)
        
        $script:pnlTools.Controls.Add($card)
        $Y += 40 
    }
}

function Search-Master {
    Show-ExecutionLogs
    $script:form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    Update-Status "Scanning for Master..."
    Write-Terminal "======================================================" "White"
    Write-Terminal "INITIATING DEEP ENVIRONMENT SEARCH" "Cyan"
    
    try {
        $FoundZip = $null
        $SearchLocations = @(
            @{ Path = Get-DownloadsPath; Recurse = $true },
            @{ Path = [Environment]::GetFolderPath("Desktop"); Recurse = $true },
            @{ Path = $ScriptPath; Recurse = $true },
            @{ Path = "C:\PnxTemp"; Recurse = $true }
        )

        foreach ($loc in $SearchLocations) {
            $dir = $loc.Path
            if ($dir -and (Test-Path $dir)) {
                Write-Terminal "Scanning Directory: $dir" "LightGray"
                $zips = if ($loc.Recurse) { Get-ChildItem -Path $dir -Filter $ZipNamePattern -File -Recurse -Depth 3 -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending } 
                        else { Get-ChildItem -Path $dir -Filter $ZipNamePattern -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending }

                foreach ($zip in $zips) {
                    if (Test-ZipValidity $zip.FullName) {
                        $FoundZip = $zip.FullName
                        Write-Terminal "VERIFIED: $FoundZip" "Lime"
                        break
                    }
                }
                if ($FoundZip) { break }
            }
        }

        if (-not $FoundZip) {
            Update-Status "Master zip not found automatically." $true
            $dlg = New-Object System.Windows.Forms.OpenFileDialog
            $dlg.Filter = "Zip Files (*.zip)|*.zip"; $dlg.Title = "Locate Phoenix Master Zip"
            if ($dlg.ShowDialog() -eq "OK") {
                if (Test-ZipValidity $dlg.FileName) { $FoundZip = $dlg.FileName } 
                else { Update-Status "Manual file corrupt." $true; return }
            } else { Update-Status "Ready."; return }
        }

        if ($FoundZip) {
            [System.Windows.Forms.Application]::DoEvents()
            Write-Terminal "Staging payload for secure extraction..." "White"

            if (Test-Path "C:\PnxTemp\MasterTemp.zip") { Remove-Item "C:\PnxTemp\MasterTemp.zip" -Force -ErrorAction SilentlyContinue }
            if (-not (Test-Path "C:\PnxTemp")) { New-Item -ItemType Directory -Path "C:\PnxTemp" -Force | Out-Null }
            
            $LocalZip = "C:\PnxTemp\MasterTemp.zip"
            try { Copy-Item -Path $FoundZip -Destination $LocalZip -Force } catch {}
            try { 
                Expand-Archive -Path $LocalZip -DestinationPath $InstallBase -Force 
                Write-Terminal "Extraction 100% complete." "Lime"
            } catch { Update-Status "Extraction Error." $true; return }
            
            $script:CurrentToolPath = $InstallBase
            $Nested = Join-Path $InstallBase "Phoenix Installation Master"
            if (Test-Path $Nested) { $script:CurrentToolPath = $Nested }

            Set-FolderPermissions $script:CurrentToolPath $false
            Unblock-ExtractedFiles $script:CurrentToolPath $false

            $script:ToolsLoaded = $true
            Refresh-List
            Update-Status "Master Loaded Successfully."
            Write-Terminal "Dashboard Armed and Operational." "Lime"
        }
    } finally {
        $script:form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

# ==========================================================================
#  7. ULTIMATE THEMED UI BUILD
# ==========================================================================
$script:form = New-Object System.Windows.Forms.Form
$script:form.Text = "Phoenix Dashboard"
$script:form.ClientSize = New-Object System.Drawing.Size(1240, 900)
$script:form.StartPosition = "CenterScreen"
$script:form.BackColor = $colorMainBg
$script:form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
$script:form.MaximizeBox = $false

# --- SIDEBAR ---
$sidebar = New-Object System.Windows.Forms.Panel
$sidebar.Size = New-Object System.Drawing.Size(260, 900)
$sidebar.BackColor = $colorSidebarBg
$script:form.Controls.Add($sidebar)

$picLogo = New-Object System.Windows.Forms.PictureBox
$picLogo.Size = New-Object System.Drawing.Size(150, 150)
$picLogo.Location = New-Object System.Drawing.Point(55, 15)
$picLogo.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom 
if (Test-Path $logoPath) { $picLogo.Image = [System.Drawing.Image]::FromFile($logoPath) }
$sidebar.Controls.Add($picLogo)

$lblTitle1 = New-Object System.Windows.Forms.Label
$lblTitle1.Text = "INSTALLATION"
$lblTitle1.Font = $fontHeader
$lblTitle1.ForeColor = $colorTextWhite
$lblTitle1.AutoSize = $false
$lblTitle1.Size = New-Object System.Drawing.Size(260, 30)
$lblTitle1.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblTitle1.Location = New-Object System.Drawing.Point(0, 180)
$sidebar.Controls.Add($lblTitle1)

$lblTitle2 = New-Object System.Windows.Forms.Label
$lblTitle2.Text = "DASHBOARD"
$lblTitle2.Font = $fontMenuBold
$lblTitle2.ForeColor = $colorLblDash 
$lblTitle2.AutoSize = $false
$lblTitle2.Size = New-Object System.Drawing.Size(260, 20)
$lblTitle2.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblTitle2.Location = New-Object System.Drawing.Point(0, 210)
$sidebar.Controls.Add($lblTitle2)

# Sidebar Group 1: General
$pnlGroupGen = New-Object System.Windows.Forms.Panel
$pnlGroupGen.Size = New-Object System.Drawing.Size(240, 185) 
$pnlGroupGen.Location = New-Object System.Drawing.Point(10, 250)
Set-RoundedCorner $pnlGroupGen 15
Add-GroupBorder $pnlGroupGen $colorGroupBorder
$sidebar.Controls.Add($pnlGroupGen)

$lblGeneral = New-Object System.Windows.Forms.Label
$lblGeneral.Text = "General"
$lblGeneral.Font = $fontMenuBold; $lblGeneral.ForeColor = $colorLblGen 
$lblGeneral.AutoSize = $false; $lblGeneral.Size = New-Object System.Drawing.Size(240, 20)
$lblGeneral.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter; $lblGeneral.Location = New-Object System.Drawing.Point(0, 10) 
$pnlGroupGen.Controls.Add($lblGeneral)

function Add-SidebarButton($Panel, $Text, $Top, $BgColor, $Action) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text; $btn.Font = $fontMenuBold; $btn.BackColor = $BgColor
    $btn.ForeColor = $colorTextWhite; $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0; $btn.Size = New-Object System.Drawing.Size(220, 40) 
    $btn.Location = New-Object System.Drawing.Point(10, $Top); $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    Set-RoundedCorner $btn 10
    $btn.Add_Click($Action)
    $Panel.Controls.Add($btn)
}

Add-SidebarButton $pnlGroupGen "Search / Reload Master" 40 $colorBtnGen { Search-Master }
Add-SidebarButton $pnlGroupGen "Download Prerequisite" 85 $colorBtnGen { Start-Process $Url_Blob; Start-Process $Url_GDrive }
Add-SidebarButton $pnlGroupGen "Request Blob Access" 130 $colorBtnGen { Request-BlobAccess }

# Sidebar Group 2: Diagnostics
$pnlGroupDiag = New-Object System.Windows.Forms.Panel
$pnlGroupDiag.Size = New-Object System.Drawing.Size(240, 185)
$pnlGroupDiag.Location = New-Object System.Drawing.Point(10, 455)
Set-RoundedCorner $pnlGroupDiag 15
Add-GroupBorder $pnlGroupDiag $colorGroupBorder
$sidebar.Controls.Add($pnlGroupDiag)

$lblDiag = New-Object System.Windows.Forms.Label
$lblDiag.Text = "Diagnostics"
$lblDiag.Font = $fontMenuBold; $lblDiag.ForeColor = $colorLblDiag
$lblDiag.AutoSize = $false; $lblDiag.Size = New-Object System.Drawing.Size(240, 20)
$lblDiag.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter; $lblDiag.Location = New-Object System.Drawing.Point(0, 10)
$pnlGroupDiag.Controls.Add($lblDiag)

Add-SidebarButton $pnlGroupDiag "Open System Logs" 40 $colorBtnDiag { if(Test-Path (Ensure-LogDir)){ Invoke-Item (Ensure-LogDir) } }
Add-SidebarButton $pnlGroupDiag "Check Public IP" 85 $colorBtnDiag { Check-PublicIP }
Add-SidebarButton $pnlGroupDiag "Run Diagnostics" 130 $colorBtnDiag { Run-PreFlightDiagnostics }

# Sidebar Group 3: System
$pnlGroupSys = New-Object System.Windows.Forms.Panel
$pnlGroupSys.Size = New-Object System.Drawing.Size(240, 95)
$pnlGroupSys.Location = New-Object System.Drawing.Point(10, 660)
Set-RoundedCorner $pnlGroupSys 15
Add-GroupBorder $pnlGroupSys $colorGroupBorder
$sidebar.Controls.Add($pnlGroupSys)

$lblSystem = New-Object System.Windows.Forms.Label
$lblSystem.Text = "System"
$lblSystem.Font = $fontMenuBold; $lblSystem.ForeColor = $colorLblSys 
$lblSystem.AutoSize = $false; $lblSystem.Size = New-Object System.Drawing.Size(240, 20)
$lblSystem.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter; $lblSystem.Location = New-Object System.Drawing.Point(0, 10)
$pnlGroupSys.Controls.Add($lblSystem)

Add-SidebarButton $pnlGroupSys "Exit Dashboard" 40 $colorBtnSys { $script:form.Close() }

# --- CONTENT PANEL ---
$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Location = New-Object System.Drawing.Point(260, 0)
$contentPanel.Size = New-Object System.Drawing.Size(980, 900)
$contentPanel.BackColor = $colorMainBg
$script:form.Controls.Add($contentPanel)

# Header Text
$lblHeaderTitle = New-Object System.Windows.Forms.Label
$lblHeaderTitle.Text = "Phoenix Dashboard"
$lblHeaderTitle.Font = $fontHeader; $lblHeaderTitle.ForeColor = $colorTextWhite
$lblHeaderTitle.AutoSize = $true; $lblHeaderTitle.Location = New-Object System.Drawing.Point(30, 25)
$contentPanel.Controls.Add($lblHeaderTitle)

$lblHeaderSub = New-Object System.Windows.Forms.Label
$lblHeaderSub.Text = "Empowering Public Safety Through Innovation"
$lblHeaderSub.Font = $fontSubHeader; $lblHeaderSub.ForeColor = $colorTextMuted
$lblHeaderSub.AutoSize = $true; $lblHeaderSub.Location = New-Object System.Drawing.Point(33, 60)
$contentPanel.Controls.Add($lblHeaderSub)

# Telemetry Badges (Mapped from the ADSI logic + Timer)
$pnlTimerBadge = New-Object System.Windows.Forms.Panel
$pnlTimerBadge.Size = New-Object System.Drawing.Size(210, 80)
$pnlTimerBadge.Location = New-Object System.Drawing.Point(400, 25)
$pnlTimerBadge.BackColor = $colorCardBg
Set-RoundedCorner $pnlTimerBadge 8
$contentPanel.Controls.Add($pnlTimerBadge)

$lblStatusTitle = New-Object System.Windows.Forms.Label
$lblStatusTitle.Text = "SYSTEM STATUS"
$lblStatusTitle.Font = $fontCleanBold; $lblStatusTitle.ForeColor = $colorTextMuted
$lblStatusTitle.AutoSize = $true; $lblStatusTitle.Location = New-Object System.Drawing.Point(15, 15)
$pnlTimerBadge.Controls.Add($lblStatusTitle)

$lblStatusVal = New-Object System.Windows.Forms.Label
$lblStatusVal.Text = "ONLINE"
$lblStatusVal.Font = $fontCleanVal; $lblStatusVal.ForeColor = $termGreen
$lblStatusVal.AutoSize = $true; $lblStatusVal.Location = New-Object System.Drawing.Point(120, 13)
$pnlTimerBadge.Controls.Add($lblStatusVal)

$lblUptimeTitle = New-Object System.Windows.Forms.Label
$lblUptimeTitle.Text = "SESSION TIME"
$lblUptimeTitle.Font = $fontCleanBold; $lblUptimeTitle.ForeColor = $colorTextMuted
$lblUptimeTitle.AutoSize = $true; $lblUptimeTitle.Location = New-Object System.Drawing.Point(15, 45)
$pnlTimerBadge.Controls.Add($lblUptimeTitle)

$lblUptimeVal = New-Object System.Windows.Forms.Label
$lblUptimeVal.Text = "00:00:00"
$lblUptimeVal.Font = $fontCleanVal; $lblUptimeVal.ForeColor = $termCyan
$lblUptimeVal.AutoSize = $true; $lblUptimeVal.Location = New-Object System.Drawing.Point(120, 43)
$pnlTimerBadge.Controls.Add($lblUptimeVal)

$global:sessionStart = Get-Date
$uiTimer = New-Object System.Windows.Forms.Timer; $uiTimer.Interval = 1000 
$uiTimer.Add_Tick({
    $ts = (Get-Date) - $global:sessionStart
    $lblUptimeVal.Text = "{0:00}:{1:00}:{2:00}" -f $ts.Hours, $ts.Minutes, $ts.Seconds
})
$uiTimer.Start()

$pnlHostBadge = New-Object System.Windows.Forms.Panel
$pnlHostBadge.Size = New-Object System.Drawing.Size(320, 80)
$pnlHostBadge.Location = New-Object System.Drawing.Point(625, 25)
$pnlHostBadge.BackColor = $colorCardBg
Set-RoundedCorner $pnlHostBadge 8
$contentPanel.Controls.Add($pnlHostBadge)

$lblHostNameLabel = New-Object System.Windows.Forms.Label
$lblHostNameLabel.Text = "HOSTNAME"
$lblHostNameLabel.Font = $fontCleanBold; $lblHostNameLabel.ForeColor = $colorTextMuted
$lblHostNameLabel.AutoSize = $true; $lblHostNameLabel.Location = New-Object System.Drawing.Point(15, 9)
$pnlHostBadge.Controls.Add($lblHostNameLabel)

$lblHostNameVal = New-Object System.Windows.Forms.Label
$lblHostNameVal.Text = $HostName
$lblHostNameVal.Font = $fontCleanVal; $lblHostNameVal.ForeColor = $colorTextWhite
$lblHostNameVal.AutoSize = $true; $lblHostNameVal.Location = New-Object System.Drawing.Point(100, 7)
$pnlHostBadge.Controls.Add($lblHostNameVal)

$lblIpLabel = New-Object System.Windows.Forms.Label
$lblIpLabel.Text = "IP ADDRESS"
$lblIpLabel.Font = $fontCleanBold; $lblIpLabel.ForeColor = $colorTextMuted
$lblIpLabel.AutoSize = $true; $lblIpLabel.Location = New-Object System.Drawing.Point(15, 30)
$pnlHostBadge.Controls.Add($lblIpLabel)

$lblIpVal = New-Object System.Windows.Forms.Label
$lblIpVal.Text = $IpAddress
$lblIpVal.Font = $fontCleanVal; $lblIpVal.ForeColor = $termCyan
$lblIpVal.AutoSize = $true; $lblIpVal.Location = New-Object System.Drawing.Point(100, 28)
$pnlHostBadge.Controls.Add($lblIpVal)

$lblAgencyLabel = New-Object System.Windows.Forms.Label
$lblAgencyLabel.Text = "AGENCY"
$lblAgencyLabel.Font = $fontCleanBold; $lblAgencyLabel.ForeColor = $colorTextMuted
$lblAgencyLabel.AutoSize = $true; $lblAgencyLabel.Location = New-Object System.Drawing.Point(15, 51)
$pnlHostBadge.Controls.Add($lblAgencyLabel)

$lblAgencyVal = New-Object System.Windows.Forms.Label
$lblAgencyVal.Text = $AgencyDomain
$lblAgencyVal.Font = $fontCleanVal; $lblAgencyVal.ForeColor = $termCyan
$lblAgencyVal.AutoSize = $true; $lblAgencyVal.Location = New-Object System.Drawing.Point(100, 49)
$pnlHostBadge.Controls.Add($lblAgencyVal)

# --- TAB CONTAINER ---
$tabContainer = New-Object System.Windows.Forms.Panel
$tabContainer.Size = New-Object System.Drawing.Size(920, 40)
$tabContainer.Location = New-Object System.Drawing.Point(30, 125)
$tabContainer.BackColor = $colorTabDeact
Set-RoundedCorner $tabContainer 20
$contentPanel.Controls.Add($tabContainer)

$script:btnTabScripts = New-Object System.Windows.Forms.Button
$script:btnTabScripts.Text = "Available Scripts"
$script:btnTabScripts.Size = New-Object System.Drawing.Size(260, 40)
$script:btnTabScripts.Location = New-Object System.Drawing.Point(0, 0)
$script:btnTabScripts.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$script:btnTabScripts.FlatAppearance.BorderSize = 1 
$script:btnTabScripts.FlatAppearance.BorderColor = $colorGroupBorder
$script:btnTabScripts.BackColor = $colorTabActive
$script:btnTabScripts.ForeColor = $colorTextWhite; $script:btnTabScripts.Font = $fontMenuBold
$script:btnTabScripts.Cursor = [System.Windows.Forms.Cursors]::Hand
$tabContainer.Controls.Add($script:btnTabScripts)

$script:btnTabLogs = New-Object System.Windows.Forms.Button
$script:btnTabLogs.Text = "Execution Logs"
$script:btnTabLogs.Size = New-Object System.Drawing.Size(260, 40)
$script:btnTabLogs.Location = New-Object System.Drawing.Point(260, 0)
$script:btnTabLogs.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$script:btnTabLogs.FlatAppearance.BorderSize = 1 
$script:btnTabLogs.FlatAppearance.BorderColor = $colorGroupBorder
$script:btnTabLogs.BackColor = $colorTabDeact
$script:btnTabLogs.ForeColor = $colorTextMuted; $script:btnTabLogs.Font = $fontMenuBold
$script:btnTabLogs.Cursor = [System.Windows.Forms.Cursors]::Hand
$tabContainer.Controls.Add($script:btnTabLogs)

$btnHelpDocs = New-Object System.Windows.Forms.Button
$btnHelpDocs.Text = "? Dashboard Guide"
$btnHelpDocs.Size = New-Object System.Drawing.Size(200, 40)
$btnHelpDocs.Location = New-Object System.Drawing.Point(520, 0)
$btnHelpDocs.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnHelpDocs.FlatAppearance.BorderSize = 1 
$btnHelpDocs.FlatAppearance.BorderColor = $colorGroupBorder
$btnHelpDocs.BackColor = $colorTabDeact
$btnHelpDocs.ForeColor = $colorTextMuted; $btnHelpDocs.Font = $fontMenuBold
$btnHelpDocs.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnHelpDocs.Add_Click({ Show-DashboardGuide })
$tabContainer.Controls.Add($btnHelpDocs)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "↻ Refresh"
$btnRefresh.Size = New-Object System.Drawing.Size(200, 40)
$btnRefresh.Location = New-Object System.Drawing.Point(720, 0)
$btnRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRefresh.FlatAppearance.BorderSize = 1 
$btnRefresh.FlatAppearance.BorderColor = $colorGroupBorder
$btnRefresh.BackColor = $colorTabDeact
$btnRefresh.ForeColor = $colorTextMuted; $btnRefresh.Font = $fontMenuBold
$btnRefresh.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnRefresh.Add_Click({ Refresh-List; Update-Status "List Refreshed Successfully." })
$tabContainer.Controls.Add($btnRefresh)

$script:lblStatus = New-Object System.Windows.Forms.Label
$script:lblStatus.Text = "Status: Initializing..."
$script:lblStatus.Font = $fontSubHeader; $script:lblStatus.ForeColor = $colorAccentRed
$script:lblStatus.AutoSize = $true; $script:lblStatus.Location = New-Object System.Drawing.Point(33, 175)
$contentPanel.Controls.Add($script:lblStatus)

# --- VIEWS SETUP ---
$script:pnlToolsWrapper = New-Object System.Windows.Forms.Panel
$script:pnlToolsWrapper.Location = New-Object System.Drawing.Point(30, 200)
$script:pnlToolsWrapper.Size = New-Object System.Drawing.Size(920, 640)
$script:pnlToolsWrapper.BackColor = [System.Drawing.Color]::Transparent
if ($global:fadedWatermark) {
    $script:pnlToolsWrapper.BackgroundImage = $global:fadedWatermark
    $script:pnlToolsWrapper.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Center
}
$contentPanel.Controls.Add($script:pnlToolsWrapper)
Enable-AdvancedDoubleBuffering $script:pnlToolsWrapper

$script:pnlTools = New-Object System.Windows.Forms.Panel
$script:pnlTools.Dock = "Fill"
$script:pnlTools.AutoScroll = $false
$script:pnlTools.BackColor = [System.Drawing.Color]::Transparent
$script:pnlToolsWrapper.Controls.Add($script:pnlTools)
Enable-AdvancedDoubleBuffering $script:pnlTools

# FULLY FIXED EXECUTION LOGS WINDOW
$script:pnlConsole = New-Object System.Windows.Forms.Panel
$script:pnlConsole.Dock = "Fill"
$script:pnlConsole.BackColor = $colorConsoleBg
$script:pnlConsole.Padding = New-Object System.Windows.Forms.Padding(15) 
$script:pnlConsole.Visible = $false
$script:pnlToolsWrapper.Controls.Add($script:pnlConsole)

$script:TermConsole = New-Object System.Windows.Forms.RichTextBox
$script:TermConsole.Dock = [System.Windows.Forms.DockStyle]::Fill 
$script:TermConsole.BackColor = $colorConsoleBg
$script:TermConsole.ForeColor = $colorTextWhite
$script:TermConsole.Font = $fontTerminal
$script:TermConsole.ReadOnly = $true
$script:TermConsole.BorderStyle = "None"
$script:pnlConsole.Controls.Add($script:TermConsole)

# --- COPYRIGHT WATERMARK (MOVED TO MAIN DASHBOARD BOTTOM CENTER) ---
$lblCopyright = New-Object System.Windows.Forms.Label
$lblCopyright.Text = "© 2026, ProPhoenix Corporation, All Rights Reserved"
$lblCopyright.Font = $script:Font_Copyright
$lblCopyright.ForeColor = $colorTextMuted
$lblCopyright.Dock = "Bottom"
$lblCopyright.Height = 40
$lblCopyright.TextAlign = "MiddleCenter"
$contentPanel.Controls.Add($lblCopyright)

# --- DUAL SCREEN TAB CLICK EVENTS ---
$script:btnTabScripts.Add_Click({
    $script:form.SuspendLayout()
    $script:pnlConsole.Visible = $false
    $script:pnlTools.Visible = $true
    $script:btnTabScripts.BackColor = $colorTabActive
    $script:btnTabScripts.ForeColor = $colorTextWhite
    $script:btnTabLogs.BackColor = $colorTabDeact
    $script:btnTabLogs.ForeColor = $colorTextMuted
    $script:form.ResumeLayout($true)
    $script:pnlToolsWrapper.Invalidate($true)
})

$script:btnTabLogs.Add_Click({
    Show-ExecutionLogs
})

# --- EXECUTE ON STARTUP (AUTO-DOWNLOAD, CLEANUP & EXTRACT) ---
$script:form.Add_Shown({ 
    $script:form.Activate()
    $uiTimer.Start()
    
    Write-Terminal "Initializing startup sequence..." "Cyan"
    [System.Windows.Forms.Application]::DoEvents()
    
    # ---------------------------------------------------------
    # ADD YOUR GITHUB REPO ZIP URL HERE:
    $Url_GitHub = "https://github.com/YourUsername/YourRepo/archive/refs/heads/main.zip"
    # ---------------------------------------------------------
    
    $DownloadUrls = @($Url_Blob, $Url_GDrive, $Url_GitHub)
    $TempDir = "C:\PnxTemp"
    
    # 1. Clean up old extracted scripts to ensure a fresh environment
    if (Test-Path $InstallBase) {
        Write-Terminal "Old payload detected. Removing old scripts..." "Yellow"
        Remove-Item -Path $InstallBase -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir -Force | Out-Null }
    
    # Generate a unique zip name (e.g., matching 1, 2, 3...) to prevent file lock errors
    $uniqueId = Get-Random -Minimum 1000 -Maximum 9999
    $TempZip = Join-Path $TempDir "Phoenix Installation Master_$uniqueId.zip"
    
    # 2. Download the new zip automatically with fallback logic
    Write-Terminal "Downloading latest payload..." "White"
    Update-Status "Downloading latest scripts..."
    [System.Windows.Forms.Application]::DoEvents()
    
    $downloadSuccess = $false
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    foreach ($url in $DownloadUrls) {
        if ([string]::IsNullOrWhiteSpace($url)) { continue }
        try {
            Write-Terminal "Attempting download from source..." "LightGray"
            Invoke-WebRequest -Uri $url -OutFile $TempZip -UseBasicParsing -TimeoutSec 15
            $downloadSuccess = $true
            Write-Terminal "Download completed successfully." "Lime"
            break
        } catch {
            Write-Terminal "Source failed, trying next..." "Yellow"
        }
    }
    
    if (-not $downloadSuccess) {
        Write-Terminal "All automatic download sources failed." "Red"
        Update-Status "Download Failed. Attempting local search..." $true
        # Fallback to local search if offline or blocked
        Search-Master
        return
    }
    
    # 3. Extract the new zip
    Write-Terminal "Extracting new payload ($TempZip)..." "White"
    Update-Status "Extracting scripts..."
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        Expand-Archive -Path $TempZip -DestinationPath $InstallBase -Force
        # Clean up the zip file after successful extraction
        Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue
        Write-Terminal "Extraction 100% complete." "Lime"
    } catch {
        Write-Terminal "Extraction failed: $_" "Red"
        Update-Status "Extraction Error." $true
        return
    }

    # 4. Set paths, unblock files, and apply ACL permissions
    $script:CurrentToolPath = $InstallBase
    
    # Find the actual extracted folder if nested (handles GitHub's '-main' folder suffix)
    $NestedDir = Get-ChildItem -Path $InstallBase -Directory | Where-Object { $_.Name -match "Phoenix Installation Master" -or $_.Name -match "main" } | Select-Object -First 1
    if ($NestedDir) { $script:CurrentToolPath = $NestedDir.FullName }
    
    Set-FolderPermissions $script:CurrentToolPath $false
    Unblock-ExtractedFiles $script:CurrentToolPath $false
    
    $script:ToolsLoaded = $true
    Refresh-List
    Update-Status "Master Loaded Successfully."
    Write-Terminal "Dashboard Armed and Operational." "Lime"
})

# Launch final app
$preloader.Close()
$preloader.Dispose()
[void]$script:form.ShowDialog()