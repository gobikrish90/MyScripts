<#
.SYNOPSIS
    Installation Master Tool v7.2
    - FEATURE: Replaced Help Docs dropdown with a dynamic TreeView Documentation Explorer (Categorized by folders).
    - BUGFIX: Fixed the invisible 'i' button by strictly enforcing System.Drawing.Point coordinates.
    - SECURITY: Retains Full Control (F) ACLs and editable scripts.
    - CORE: Auto-Download/Cleanup, O365 Deep Link, Timezondd-Type -AssemblyNamee Clocks, and ADSI Telemetry retained.
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

Write-Host "[INIT] Booting Installation Master Tool v7.2..." -ForegroundColor Cyan

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
Add-Type -AssemblyName PresentationFramework

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

    $helpForm = New-Object System.Windows.Forms.Form
    $helpForm.Text = "ProPhoenix Documentation Library"
    $helpForm.Size = New-Object System.Drawing.Size(950, 650) # Expanded for Split-Pane View
    $helpForm.StartPosition = "CenterParent"
    $helpForm.BackColor = $colorMainBg
    $helpForm.ForeColor = $colorTextWhite
    $helpForm.FormBorderStyle = "FixedDialog"
    $helpForm.MaximizeBox = $false
    $helpForm.MinimizeBox = $false

    $lblHeader = New-Object System.Windows.Forms.Label
    $lblHeader.Text = "Documentation Explorer"
    $lblHeader.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $lblHeader.Location = New-Object System.Drawing.Point(20, 15)
    $lblHeader.AutoSize = $true
    $lblHeader.ForeColor = $termCyan
    $helpForm.Controls.Add($lblHeader)

    $lblSub = New-Object System.Windows.Forms.Label
    $lblSub.Text = "Browse categories on the left. Content displays on the right."
    $lblSub.Font = $fontSubHeader
    $lblSub.Location = New-Object System.Drawing.Point(22, 45)
    $lblSub.AutoSize = $true
    $lblSub.ForeColor = $colorTextMuted
    $helpForm.Controls.Add($lblSub)

    # --- TREEVIEW (LEFT PANE) ---
    $tvDocs = New-Object System.Windows.Forms.TreeView
    $tvDocs.Location = New-Object System.Drawing.Point(20, 80)
    $tvDocs.Size = New-Object System.Drawing.Size(300, 460)
    $tvDocs.BackColor = $colorCardBg
    $tvDocs.ForeColor = $colorTextWhite
    $tvDocs.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    $tvDocs.BorderStyle = "FixedSingle"
    $tvDocs.Indent = 15
    $tvDocs.ShowLines = $true
    $helpForm.Controls.Add($tvDocs)

    # --- RICH TEXT VIEWER (RIGHT PANE) ---
    $rtbViewer = New-Object System.Windows.Forms.RichTextBox
    $rtbViewer.Location = New-Object System.Drawing.Point(335, 80)
    $rtbViewer.Size = New-Object System.Drawing.Size(575, 460)
    $rtbViewer.BackColor = $colorConsoleBg
    $rtbViewer.ForeColor = $colorTextWhite
    $rtbViewer.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)
    $rtbViewer.ReadOnly = $true
    $rtbViewer.BorderStyle = "None"
    $helpForm.Controls.Add($rtbViewer)

    # 1. Internal Guide Node (Displays the built-in Dashboard Guide)
    $internalRoot = New-Object System.Windows.Forms.TreeNode("Dashboard Internal Guides")
    $internalRoot.NodeFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $internalRoot.ForeColor = $colorLblDash
    
    $guideNode = New-Object System.Windows.Forms.TreeNode("ProPhoenix Step-by-Step Guide")
    $guideNode.Tag = "INTERNAL_GUIDE"
    $guideNode.ForeColor = $colorTextWhite
    $internalRoot.Nodes.Add($guideNode)
    $tvDocs.Nodes.Add($internalRoot)

    # 2. External Documents Node (Scans for PDFs, DOCX inside extracted ZIP)
    $extRoot = New-Object System.Windows.Forms.TreeNode("External Documentation")
    $extRoot.NodeFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $extRoot.ForeColor = $termCyan
    $tvDocs.Nodes.Add($extRoot)

    $docFiles = Get-ChildItem -Path $script:CurrentToolPath -Include *.pdf, *.chm, *.docx, *.doc, *.txt, *.rtf -Recurse -File | Sort-Object DirectoryName, Name

    if ($docFiles.Count -gt 0) {
        $groupedDocs = $docFiles | Group-Object { $_.Directory.Name }
        foreach ($group in $groupedDocs) {
            $catName = if ($group.Name -eq (Split-Path $script:CurrentToolPath -Leaf)) { "General Documents" } else { $group.Name }
            $folderNode = New-Object System.Windows.Forms.TreeNode($catName)
            $folderNode.ForeColor = $colorLblDiag
            
            foreach ($file in $group.Group) {
                $fileNode = New-Object System.Windows.Forms.TreeNode($file.Name)
                $fileNode.Tag = $file.FullName 
                $fileNode.ForeColor = $colorTextWhite
                $folderNode.Nodes.Add($fileNode)
            }
            $extRoot.Nodes.Add($folderNode)
        }
    } else {
        $emptyNode = New-Object System.Windows.Forms.TreeNode("No external PDFs or Docs found in payload.")
        $emptyNode.ForeColor = $colorTextMuted
        $extRoot.Nodes.Add($emptyNode)
    }

    $internalRoot.ExpandAll()
    $extRoot.Expand()

    # --- SELECTION LOGIC ---
    $tvDocs.Add_AfterSelect({
        $selected = $tvDocs.SelectedNode
        if ($selected.Tag -eq "INTERNAL_GUIDE") {
            $rtbViewer.Text = $script:GuideText
        } elseif ($selected.Tag -and (Test-Path $selected.Tag)) {
            $ext = [System.IO.Path]::GetExtension($selected.Tag).ToLower()
            if ($ext -eq ".txt") {
                $rtbViewer.Text = Get-Content $selected.Tag -Raw
            } else {
                $rtbViewer.Text = "`n`n   EXTERNAL FILE SELECTED`n   ======================`n`n   Name: $($selected.Text)`n   Type: $($ext.ToUpper())`n`n   This file format is an external document.`n   Click the 'Open External File' button below to launch it."
            }
        } else {
            $rtbViewer.Text = "`n`n   Please select a specific document from the left."
        }
    })

    # Select the built-in guide by default
    $tvDocs.SelectedNode = $guideNode

    # --- BUTTONS ---
    $btnOpen = New-Object System.Windows.Forms.Button
    $btnOpen.Text = "Open External File"
    $btnOpen.Location = New-Object System.Drawing.Point(760, 560)
    $btnOpen.Size = New-Object System.Drawing.Size(150, 40)
    $btnOpen.BackColor = $colorBtnDiag
    $btnOpen.ForeColor = $colorTextWhite
    $btnOpen.FlatStyle = "Flat"
    $btnOpen.FlatAppearance.BorderSize = 0
    $btnOpen.Font = $fontMenuBold
    $btnOpen.Cursor = "Hand"
    Set-RoundedCorner $btnOpen 10

    $btnOpen.Add_Click({
        $selected = $tvDocs.SelectedNode
        if ($selected -and $selected.Tag -ne "INTERNAL_GUIDE" -and $selected.Tag) {
            Write-Terminal "Opening Documentation: $($selected.Text)" "Cyan"
            Start-Process $selected.Tag
        } elseif ($selected.Tag -eq "INTERNAL_GUIDE") {
            [System.Windows.Forms.MessageBox]::Show("This is an internal text guide and is already displayed in the viewer pane.", "Internal Guide", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        } else {
            [System.Windows.Forms.MessageBox]::Show("Please select a specific external document to open.", "Select Document", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })
    $helpForm.Controls.Add($btnOpen)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close"
    $btnClose.Location = New-Object System.Drawing.Point(645, 560)
    $btnClose.Size = New-Object System.Drawing.Size(100, 40)
    $btnClose.BackColor = $colorBtnGen
    $btnClose.ForeColor = $colorTextWhite
    $btnClose.FlatStyle = "Flat"
    $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.Font = $fontMenuBold
    $btnClose.Cursor = "Hand"
    Set-RoundedCorner $btnClose 10
    $btnClose.Add_Click({ $helpForm.Close() })
    $helpForm.Controls.Add($btnClose)

    [void]$helpForm.ShowDialog()
}

function Show-LicenseVerification {
    # XAML for the clean, toggle-based futuristic dashboard
    [xml]$xaml = @"
    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
            Title="License Verification Dashboard" Height="750" Width="1000" Background="#0B132B" WindowStartupLocation="CenterScreen">
        <Window.Resources>
            <Style TargetType="Button">
                <Setter Property="Background" Value="#1C2541"/>
                <Setter Property="Foreground" Value="#00E5FF"/>
                <Setter Property="BorderBrush" Value="#00E5FF"/>
                <Setter Property="BorderThickness" Value="1"/>
                <Setter Property="FontFamily" Value="Consolas"/>
                <Setter Property="FontWeight" Value="Bold"/>
                <Setter Property="FontSize" Value="14"/>
                <Style.Triggers>
                    <Trigger Property="IsMouseOver" Value="True">
                        <Setter Property="Background" Value="#00E5FF"/>
                        <Setter Property="Foreground" Value="#0B132B"/>
                    </Trigger>
                </Style.Triggers>
            </Style>
            <Style TargetType="TextBox">
                <Setter Property="Background" Value="#050A1F"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
                <Setter Property="BorderBrush" Value="#5BC0BE"/>
                <Setter Property="FontFamily" Value="Consolas"/>
                <Setter Property="Padding" Value="10"/>
                <Setter Property="AcceptsReturn" Value="True"/>
                <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
            </Style>
        </Window.Resources>
        
        <Grid Margin="30">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <Button Name="btnOld" Grid.Row="0" Content="▼ OLD LICENSE DATA" Height="40" Margin="0,0,0,5"/>
            <TextBox Name="txtOld" Grid.Row="1" Height="150" Visibility="Collapsed" Margin="0,0,0,15" TextWrapping="Wrap" />

            <Button Name="btnNew" Grid.Row="2" Content="▼ NEW LICENSE DATA" Height="40" Margin="0,0,0,5"/>
            <TextBox Name="txtNew" Grid.Row="3" Height="150" Visibility="Collapsed" Margin="0,0,0,20" TextWrapping="Wrap"/>

            <Button Name="btnAnalyse" Grid.Row="4" Content="▶ EXECUTE SMART ANALYSE" Height="50" Background="#00E5FF" Foreground="#0B132B" FontSize="16" Margin="0,0,0,20"/>

            <GroupBox Grid.Row="5" Header="VERIFICATION RESULTS" Foreground="#5BC0BE" FontFamily="Consolas" BorderBrush="#1C2541">
                <RichTextBox Name="rtbResults" Background="#050A1F" BorderThickness="0" Padding="10" IsReadOnly="True" VerticalScrollBarVisibility="Auto">
                    <FlowDocument>
                        <Paragraph FontFamily="Consolas" FontSize="14">
                            <Run Foreground="#555555" Text="Awaiting analysis..."/>
                        </Paragraph>
                    </FlowDocument>
                </RichTextBox>
            </GroupBox>
        </Grid>
    </Window>
"@

    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $Window = [Windows.Markup.XamlReader]::Load($reader)

    # Map GUI Elements
    $btnOld = $Window.FindName("btnOld")
    $txtOld = $Window.FindName("txtOld")
    $btnNew = $Window.FindName("btnNew")
    $txtNew = $Window.FindName("txtNew")
    $btnAnalyse = $Window.FindName("btnAnalyse")
    $rtbResults = $Window.FindName("rtbResults")

    # Toggle Old License TextBox
    $btnOld.Add_Click({
        if ($txtOld.Visibility -eq 'Collapsed') {
            $txtOld.Visibility = 'Visible'
            $btnOld.Content = "▲ OLD LICENSE DATA"
        } else {
            $txtOld.Visibility = 'Collapsed'
            $btnOld.Content = "▼ OLD LICENSE DATA"
        }
    })

    # Toggle New License TextBox
    $btnNew.Add_Click({
        if ($txtNew.Visibility -eq 'Collapsed') {
            $txtNew.Visibility = 'Visible'
            $btnNew.Content = "▲ NEW LICENSE DATA"
        } else {
            $txtNew.Visibility = 'Collapsed'
            $btnNew.Content = "▼ NEW LICENSE DATA"
        }
    })

    # Execute Analysis Logic
    $btnAnalyse.Add_Click({
        $rtbResults.Document.Blocks.Clear()
        $paragraph = New-Object System.Windows.Documents.Paragraph
        
        $oldText = $txtOld.Text -split "`r`n|`r|`n"
        $newText = $txtNew.Text -split "`r`n|`r|`n"
        $maxLines = [math]::Max($oldText.Count, $newText.Count)
        
        for ($i = 0; $i -lt $maxLines; $i++) {
            $lineOld = if ($i -lt $oldText.Count) { $oldText[$i] } else { $null }
            $lineNew = if ($i -lt $newText.Count) { $newText[$i] } else { $null }
            $isMatch = $false

            if (($lineOld -match "<([\d, ]+)>") -and ($lineNew -match "<([\d, ]+)>")) {
                $listOld = ($lineOld -replace '.*<|>.*','' -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Sort-Object) -join ','
                $listNew = ($lineNew -replace '.*<|>.*','' -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Sort-Object) -join ','
                $prefixOld = $lineOld -replace "<.*",""
                $prefixNew = $lineNew -replace "<.*",""

                if (($listOld -eq $listNew) -and ($prefixOld -eq $prefixNew)) {
                    $isMatch = $true
                }
            } 
            elseif ($lineOld -eq $lineNew) {
                $isMatch = $true
            }

            if ($isMatch) {
                $run = New-Object System.Windows.Documents.Run("$lineOld`r`n")
                $run.Foreground = "White"
                $paragraph.Inlines.Add($run)
            } else {
                if ($null -ne $lineOld -and $lineOld.Trim() -ne "") {
                    $runOld = New-Object System.Windows.Documents.Run("$lineOld`r`n")
                    $runOld.Foreground = "#FF4C4C"
                    $runOld.TextDecorations = [System.Windows.TextDecorations]::Strikethrough
                    $paragraph.Inlines.Add($runOld)
                }
                if ($null -ne $lineNew -and $lineNew.Trim() -ne "") {
                    $runNew = New-Object System.Windows.Documents.Run("$lineNew`r`n")
                    $runNew.Foreground = "#00E5FF"
                    $paragraph.Inlines.Add($runNew)
                }
            }
        }
        $rtbResults.Document.Blocks.Add($paragraph)
    })

    # Show the Dashboard
    $Window.ShowDialog() | Out-Null
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
    Update-Status "Preparing Office 365 Request..."
    Write-Terminal "--- INITIATING O365 EMAIL REQUEST ---" "Cyan"
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $ip = Invoke-RestMethod -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 5
        Write-Terminal "Public IP Resolved: $ip" "Cyan"
        
        $to = "Cloudsupport@prophoenix.com"
        $cc = "Installation@prophoenix.com,itsupport@prophoenix.com,it@prophoenix.com"
        $subject = "Blob enable"
        
        $body = "HI Team,%0D%0A%0D%0AKindly enable this IP Address for Blob Url access to proceed with the application installation and configuration process.%0D%0A%0D%0AIP Address: $ip"
        
        $owaUrl = "https://outlook.office.com/mail/deeplink/compose?to=$to&cc=$cc&subject=$subject&body=$body"
        
        Start-Process $owaUrl
        
        Write-Terminal "Browser launched. Awaiting O365 login..." "Lime"
        Update-Status "Office 365 draft created."
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
                Remove-Item -Path $LocalZip -Force -ErrorAction SilentlyContinue
                Write-Terminal "Extraction 100% complete and archive deleted." "Lime"
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
$pnlGroupGen.Size = New-Object System.Drawing.Size(240, 230) # Height increased to fit 4 buttons
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
Add-SidebarButton $pnlGroupGen "License Verification" 175 $colorBtnGen { Show-LicenseVerification }

# Sidebar Group 2: Diagnostics
$pnlGroupDiag = New-Object System.Windows.Forms.Panel
$pnlGroupDiag.Size = New-Object System.Drawing.Size(240, 185)
$pnlGroupDiag.Location = New-Object System.Drawing.Point(10, 500) # Shifted down 45px
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
$pnlGroupSys.Location = New-Object System.Drawing.Point(10, 705) # Shifted down 45px
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

# Telemetry Badges
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

$pnlHostBadge = New-Object System.Windows.Forms.Panel
$pnlHostBadge.Size = New-Object System.Drawing.Size(540, 80)
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

# --- NEW: "i" INFO BUTTON & DASHBOARD ABOUT PANEL ---
$btnInfo = New-Object System.Windows.Forms.Button
$btnInfo.Text = "i"
$btnInfo.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$btnInfo.Size = New-Object System.Drawing.Size(30, 30)

# Hard-coded absolute position inside the 320px wide $pnlHostBadge
$btnInfo.Location = New-Object System.Drawing.Point(280, 10) 

$btnInfo.BackColor = $colorBtnDiag
$btnInfo.ForeColor = $colorTextWhite
$btnInfo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnInfo.FlatAppearance.BorderSize = 0
$btnInfo.Cursor = [System.Windows.Forms.Cursors]::Hand
Set-RoundedCorner $btnInfo 15

$btnInfo.Add_Click({
    $infoForm = New-Object System.Windows.Forms.Form
    $infoForm.Text = "About Dashboard"
    $infoForm.Size = New-Object System.Drawing.Size(650, 460)
    $infoForm.StartPosition = "CenterParent"
    $infoForm.BackColor = $colorMainBg
    $infoForm.ForeColor = $colorTextWhite
    $infoForm.FormBorderStyle = "FixedDialog"
    $infoForm.MaximizeBox = $false
    $infoForm.MinimizeBox = $false

    $infoRtb = New-Object System.Windows.Forms.RichTextBox
    $infoRtb.Dock = "Fill"
    $infoRtb.BackColor = $colorCardBg
    $infoRtb.ForeColor = $colorTextWhite
    $infoRtb.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)
    $infoRtb.ReadOnly = $true
    $infoRtb.BorderStyle = "None"
    
    $utcNow = [System.DateTime]::UtcNow
    $estTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($utcNow, [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time")).ToString("hh:mm tt")
    $cstTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($utcNow, [System.TimeZoneInfo]::FindSystemTimeZoneById("Central Standard Time")).ToString("hh:mm tt")
    $pstTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($utcNow, [System.TimeZoneInfo]::FindSystemTimeZoneById("Pacific Standard Time")).ToString("hh:mm tt")
    
    $infoRtb.Text = @"

  PROPHOENIX INSTALLATION DASHBOARD
  ========================================================================
  Dashboard Version 7.2
  Created by Installation Team
  
  CURRENT US TIME ZONES:
  EST: $estTime   |   CST: $cstTime   |   PST: $pstTime
  ========================================================================

  TECHNICAL MODULES & WORKFLOW:
  ------------------------------------------------------------------------
  [1] Core UI Engine: Built entirely in PowerShell using native WinForms.
      Implements double-buffering and region-clipping for the Glass Theme 
      and rounded corners without external dependencies.

  [2] Execution Module: A Hybrid Launcher automatically determines if a 
      script requires standard CMD, PowerShell, or the ISE, executing it 
      with forced Administrative permissions and Execution Policy bypass.

  [3] Telemetry & ADSI Module: Actively queries Active Directory (ADSI)
      to dynamically resolve and map the local Hostname to its registered 
      Company/Agency Domain.

  [4] Diagnostics Module: Uses REST API wrappers (ipify) and TCP Net 
      Connections to validate public-facing IPs and SFTP Port bindings.

  [5] Cloud Sync Module: Automates deployment updates via secure URL 
      downloads (Blob/GitHub), gracefully unblocks payloads, and maps 
      required inherited ACL permissions (IUSR/Network Service) natively.
  ========================================================================
"@
    $infoForm.Controls.Add($infoRtb)
    [void]$infoForm.ShowDialog()
})

# THE CRITICAL MISSING LINES THAT FORCE THE BUTTON TO DRAW ON SCREEN:
$pnlHostBadge.Controls.Add($btnInfo)
$script:form.ResumeLayout()
$btnInfo.BringToFront()

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
$btnHelpDocs.Text = "Help Docs"
$btnHelpDocs.Size = New-Object System.Drawing.Size(200, 40)
$btnHelpDocs.Location = New-Object System.Drawing.Point(520, 0)
$btnHelpDocs.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnHelpDocs.FlatAppearance.BorderSize = 1 
$btnHelpDocs.FlatAppearance.BorderColor = $colorGroupBorder
$btnHelpDocs.BackColor = $colorTabDeact
$btnHelpDocs.ForeColor = $colorTextMuted; $btnHelpDocs.Font = $fontMenuBold
$btnHelpDocs.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnHelpDocs.Add_Click({ Show-HelpPrompt })
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

# --- COPYRIGHT WATERMARK ---
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
    
    if (Test-Path $InstallBase) {
        Write-Terminal "Old payload detected. Removing old scripts..." "Yellow"
        Remove-Item -Path $InstallBase -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir -Force | Out-Null }
    
    $uniqueId = Get-Random -Minimum 1000 -Maximum 9999
    $TempZip = Join-Path $TempDir "Phoenix Installation Master_$uniqueId.zip"
    
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
        Search-Master
        return
    }
    
    Write-Terminal "Extracting new payload ($TempZip)..." "White"
    Update-Status "Extracting scripts..."
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        Expand-Archive -Path $TempZip -DestinationPath $InstallBase -Force
        # AUTO-DELETE ZIP AFTER EXTRACTION
        Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue
        Write-Terminal "Extraction 100% complete and archive deleted." "Lime"
    } catch {
        Write-Terminal "Extraction failed: $_" "Red"
        Update-Status "Extraction Error." $true
        return
    }

    $script:CurrentToolPath = $InstallBase
    
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