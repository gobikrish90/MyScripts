<#
.SYNOPSIS
    Installation Master Tool v8.42
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

Write-Host "[INIT] Booting Installation Master Tool v8.42..." -ForegroundColor Cyan

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
#  2. GLOBAL ASSEMBLIES, THEME DEFINITIONS & VARIABLES
# ==============================================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName PresentationFramework

[System.Windows.Forms.Application]::EnableVisualStyles()

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
$colorAccentRed  = [System.Drawing.Color]::FromArgb(255, 239, 68, 68)

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
$Url_Blob     = ""
$ZipNamePattern = "Phoenix Installation Master*.zip"
$InstallBase    = "C:\pnxtemp\Phoenix Installation Master"
$script:CurrentToolPath = $InstallBase 
$script:ToolsLoaded = $false
$global:AvailableScripts = @()

# Remote Execution Tracking Variables
$global:ActiveJobs = @()
$global:RemoteTargets = @() 
$global:ScheduledJobs = @()
$script:TargetCred = $null
$script:TargetUser = ""
$script:TargetPass = ""
$script:SavedCredsList = @()
$global:LogTabs = @{}
$global:LogBoxes = @{}
$global:PendingLivePrompts = @{}
$global:CurrentActiveTab = "ALL"
[datetime]$script:sessionStart = [datetime]::Now

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
# PASTE YOUR FULL 2000-LINE CUSTOM GUIDE TEXT HERE
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
#  4. ADVANCED TELEMETRY GATHERING
# ==========================================================================
$fqdn = "$env:COMPUTERNAME.$env:USERDNSDOMAIN"
$HostName = [System.Net.Dns]::GetHostName()
$IpAddress = "127.0.0.1"
try {
    $PrimaryAdapter = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" | Where-Object { $_.DefaultIPGateway -ne $null } | Select-Object -First 1
    if ($PrimaryAdapter) { $IpAddress = $PrimaryAdapter.IPAddress | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -First 1 }
} catch {}
$AgencyDomain = "Unknown"
try { if ($env:USERDOMAIN) { $AgencyDomain = $env:USERDOMAIN } } catch {}

# ==========================================================================
#  5. SPLASH SCREEN & PRELOADER
# ==========================================================================
$preloader = New-Object System.Windows.Forms.Form
$preloader.Size = New-Object System.Drawing.Size(350, 100)
$preloader.StartPosition = "CenterScreen"
$preloader.BackColor = $colorCardBg
$preloader.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None

function global:Set-RoundedCorner($Control, $Radius) {
    if ($Control.Width -le 0 -or $Control.Height -le 0) { return }
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $Radius, $Radius, 180, 90)
    $path.AddArc($Control.Width - $Radius, 0, $Radius, $Radius, 270, 90)
    $path.AddArc($Control.Width - $Radius, $Control.Height - $Radius, $Radius, $Radius, 0, 90)
    $path.AddArc(0, $Control.Height - $Radius, $Radius, $Radius, 90, 90)
    $path.CloseFigure()
    $Control.Region = New-Object System.Drawing.Region($path)
}
global:Set-RoundedCorner $preloader 15

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
#  6. GLOBAL HELPER FUNCTIONS
# ==========================================================================
function global:Enable-AdvancedDoubleBuffering($Control) {
    $flags = [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic
    $prop = $Control.GetType().GetProperty("DoubleBuffered", $flags)
    if ($prop) { $prop.SetValue($Control, $true, $null) }
}

function global:Ensure-LogDir {
    $LogDir = Join-Path $InstallBase "Logs"
    if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
    return $LogDir
}

function global:Add-LogTab($tabName) {
    if ($global:LogTabs.ContainsKey($tabName)) { return }
    
    $xPos = 0
    foreach ($ctrl in $script:pnlLogTabs.Controls) {
        if ($ctrl.Right -gt $xPos) { $xPos = $ctrl.Right }
    }
    $xPos += 5
    
    $isRemote = ($tabName -ne "ALL" -and $tabName -ne "LOCAL")
    
    # DYNAMIC WIDTH CALCULATION
    $charWidth = $tabName.Length * 8
    $tabWidth = [int][math]::Ceiling($charWidth)
    if ($isRemote) { $tabWidth += 55 } else { $tabWidth += 20 }
    if ($tabWidth -lt 80) { $tabWidth = 80 }
    
    $tabContainer = New-Object System.Windows.Forms.Panel
    $tabContainer.Size = New-Object System.Drawing.Size($tabWidth, 30)
    $tabContainer.Location = New-Object System.Drawing.Point($xPos, 2)
    $tabContainer.BackColor = [System.Drawing.Color]::FromArgb(255, 30, 30, 40)
    global:Set-RoundedCorner $tabContainer 8
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Name = "MainTabButton"
    $btn.Tag = $tabName 
    $btn.Location = New-Object System.Drawing.Point(0, 0)
    $btn.FlatStyle = "Flat"
    $btn.FlatAppearance.BorderSize = 0
    $btn.BackColor = [System.Drawing.Color]::Transparent
    $btn.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 160, 170)
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = "Hand"
    
    if ($isRemote) {
        $btn.Text = "  " + $tabName
        $btn.Size = New-Object System.Drawing.Size(($tabWidth - 30), 30)
        $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    } else {
        $btn.Text = $tabName
        $btn.Size = New-Object System.Drawing.Size($tabWidth, 30)
        $btn.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    }
    $tabContainer.Controls.Add($btn)
    
    if ($isRemote) {
        $btnClose = New-Object System.Windows.Forms.Button
        $btnClose.Name = "CloseTabButton"
        $btnClose.Text = "X"
        $btnClose.Tag = $tabName 
        $btnClose.Size = New-Object System.Drawing.Size(30, 30)
        $btnClose.Location = New-Object System.Drawing.Point(($tabWidth - 30), 0)
        $btnClose.FlatStyle = "Flat"
        $btnClose.FlatAppearance.BorderSize = 0
        $btnClose.BackColor = [System.Drawing.Color]::Transparent
        $btnClose.ForeColor = [System.Drawing.Color]::FromArgb(255, 239, 68, 68)
        $btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
        $btnClose.Cursor = "Hand"
        
        $btnClose.Add_Click({
            $targetName = $this.Tag
            $global:RemoteTargets = @($global:RemoteTargets | Where-Object { $_.HostName -ne $targetName })
            $script:pnlLogTabs.Controls.Remove($global:LogTabs[$targetName])
            $script:pnlLogContent.Controls.Remove($global:LogBoxes[$targetName])
            $global:LogTabs.Remove($targetName)
            $global:LogBoxes.Remove($targetName)
            
            $nx = 0
            $orderedKeys = @("ALL", "LOCAL") + ($global:LogTabs.Keys | Where-Object { $_ -ne "ALL" -and $_ -ne "LOCAL" } | Sort-Object)
            foreach ($key in $orderedKeys) {
                if ($global:LogTabs.ContainsKey($key)) {
                    $global:LogTabs[$key].Location = New-Object System.Drawing.Point($nx, 2)
                    $nx += $global:LogTabs[$key].Width + 5
                }
            }
            global:Switch-LogTab "ALL"
        })
        $tabContainer.Controls.Add($btnClose)
        $btnClose.BringToFront()
    }
    
    $rtb = New-Object System.Windows.Forms.RichTextBox
    $rtb.Dock = "Fill"
    $rtb.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13)
    $rtb.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $rtb.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
    $rtb.ReadOnly = $true
    $rtb.BorderStyle = "None"
    $rtb.Visible = $false
    
    $global:LogTabs[$tabName] = $tabContainer
    $global:LogBoxes[$tabName] = $rtb
    
    $script:pnlLogTabs.Controls.Add($tabContainer)
    $script:pnlLogContent.Controls.Add($rtb)
    
    $btn.Add_Click({ global:Switch-LogTab $this.Tag })
}

function global:Switch-LogTab($tabKey) {
    $global:CurrentActiveTab = $tabKey
    foreach ($key in $global:LogTabs.Keys) {
        if ($key -eq $tabKey) {
            $global:LogTabs[$key].BackColor = [System.Drawing.Color]::FromArgb(255, 65, 65, 80)
            if ($global:LogTabs[$key].Controls.ContainsKey("MainTabButton")) {
                $global:LogTabs[$key].Controls["MainTabButton"].ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
            }
            $global:LogBoxes[$key].Visible = $true
            $global:LogBoxes[$key].BringToFront()
        } else {
            $global:LogTabs[$key].BackColor = [System.Drawing.Color]::FromArgb(255, 30, 30, 40)
            if ($global:LogTabs[$key].Controls.ContainsKey("MainTabButton")) {
                $global:LogTabs[$key].Controls["MainTabButton"].ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 160, 170)
            }
            $global:LogBoxes[$key].Visible = $false
        }
    }
    
    if ($global:pnlLiveInput) {
        if ($global:PendingLivePrompts.ContainsKey($tabKey) -or ($tabKey -eq "ALL" -and $global:PendingLivePrompts.Count -gt 0)) {
            $global:pnlLiveInput.Visible = $true
        } else {
            $global:pnlLiveInput.Visible = $false
        }
    }
}

function global:Build-LogTabs {
    global:Add-LogTab "ALL"
    global:Add-LogTab "LOCAL"

    foreach ($t in $global:RemoteTargets) {
        global:Add-LogTab $t.HostName
    }
    
    $xPos = 0
    $orderedKeys = @("ALL", "LOCAL") + ($global:LogTabs.Keys | Where-Object { $_ -ne "ALL" -and $_ -ne "LOCAL" } | Sort-Object)
    foreach ($key in $orderedKeys) {
        if ($global:LogTabs.ContainsKey($key)) {
            $global:LogTabs[$key].Location = New-Object System.Drawing.Point($xPos, 2)
            $xPos += $global:LogTabs[$key].Width + 5
        }
    }
}

function global:Write-Terminal($msg, $colorName = "LightGray", $targetName = "ALL", $CleanMsg = $null) {
    try {
        $LogFile = Join-Path (global:Ensure-LogDir) "Deployment_Audit.log"
        $Timestamp = Get-Date -Format "HH:mm:ss.fff"
        
        $FullMsgAll = "[$Timestamp] [SYS] $msg"
        $targetText = if ($null -ne $CleanMsg) { $CleanMsg } else { $msg }
        $FullMsgTarget = "[$Timestamp] [SYS] $targetText"
        
        Add-Content -Path $LogFile -Value $FullMsgAll -ErrorAction SilentlyContinue
        
        if ($colorName -eq "Cyan" -or $colorName -eq "CyanAccent") { $mappedColor = [System.Drawing.Color]::Cyan }
        elseif ($colorName -eq "Lime" -or $colorName -eq "StatusGreen") { $mappedColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113) }
        elseif ($colorName -eq "Red" -or $colorName -eq "HeaderRed") { $mappedColor = [System.Drawing.Color]::FromArgb(255, 239, 68, 68) }
        elseif ($colorName -eq "Yellow") { $mappedColor = [System.Drawing.Color]::Yellow }
        else { $mappedColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240) }
        
        if ($global:LogBoxes -and $global:LogBoxes.ContainsKey("ALL")) {
            $rtbAll = $global:LogBoxes["ALL"]
            $rtbAll.SelectionStart = $rtbAll.TextLength
            $rtbAll.SelectionLength = 0
            $rtbAll.SelectionColor = $mappedColor
            $rtbAll.AppendText("$FullMsgAll`n")
            $rtbAll.ScrollToCaret()
        }
        
        if ($targetName -ne "ALL" -and $global:LogBoxes -and $global:LogBoxes.ContainsKey($targetName)) {
            $rtbTarget = $global:LogBoxes[$targetName]
            $rtbTarget.SelectionStart = $rtbTarget.TextLength
            $rtbTarget.SelectionLength = 0
            $rtbTarget.SelectionColor = $mappedColor
            $rtbTarget.AppendText("$FullMsgTarget`n")
            $rtbTarget.ScrollToCaret()
        }
        [System.Windows.Forms.Application]::DoEvents()
    } catch {}
}

function global:Update-Status($msg, $isError = $false) {
    if ($script:lblStatus) {
        $script:lblStatus.Text = "Status: $msg"
        if ($isError) { $script:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(255, 239, 68, 68) }
        else { $script:lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113) }
        $script:lblStatus.Refresh()
    }
}

function global:Set-FolderPermissions($path, $silent=$false) {
    if (-not $silent) { global:Write-Terminal "Applying advanced ACLs to Directory..." "Yellow" "LOCAL" }
    [System.Windows.Forms.Application]::DoEvents()
    try { 
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $aclArgs = "`"$path`" /grant `"Everyone:(OI)(CI)F`" `"IUSR:(OI)(CI)F`" `"NETWORK SERVICE:(OI)(CI)F`" `"${currentUser}:(OI)(CI)F`" /T /C /Q"
        Start-Process "icacls.exe" -ArgumentList $aclArgs -WindowStyle Hidden -Wait 
        if (-not $silent) { global:Write-Terminal "ACLs successfully applied." "Lime" "LOCAL" }
    } catch {
        if (-not $silent) { global:Write-Terminal "Failed to apply ACLs: $_" "Red" "LOCAL" }
    }
}

function global:Unblock-ExtractedFiles($path, $silent=$false) {
    if (-not $silent) { global:Write-Terminal "Unblocking script files..." "Yellow" "LOCAL" }
    [System.Windows.Forms.Application]::DoEvents()
    try { 
        Get-ChildItem -Path $path -Recurse -File | Unblock-File -ErrorAction SilentlyContinue 
        if (-not $silent) { global:Write-Terminal "Files successfully unblocked." "Lime" "LOCAL" }
    } catch {
        if (-not $silent) { global:Write-Terminal "Failed to unblock files: $_" "Red" "LOCAL" }
    }
}

function global:Get-DownloadsPath {
    try {
        $path = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders")."{374DE290-123F-4565-9164-39C4925E467B}"
        if (Test-Path $path) { return $path }
    } catch {}
    $path = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
    if (Test-Path $path) { return $path }
    return $null
}

function global:Test-ZipValidity($ZipPath) { try { [System.IO.Compression.ZipFile]::OpenRead($ZipPath).Dispose(); return $true } catch { return $false } }

function global:Get-FriendlyName($fileName) {
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

function global:Get-SortOrder($friendlyName) {
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

# ==============================================================================
#  EXECUTION ENGINES (INTERCEPTOR AND SCHEDULER)
# ==============================================================================

function global:Execute-ScheduledJob($job) {
    global:Write-Terminal ">>> SCHEDULE TRIGGERED: $($job.FriendlyName)" "Cyan" "ALL"
    global:Update-Status "Running Scheduled Task..."
    
    $path = $job.ScriptPath
    $userInput = $job.UserInput 
    
    $escapedToolPath = [regex]::Escape($script:CurrentToolPath)
    $remotePath = $path -ireplace $escapedToolPath, "C:\PnxTemp\RemotePayload"
    $remoteWorkDir = Split-Path $remotePath -Parent

    foreach ($t in $job.Targets) {
        if ($global:LogTabs -and $global:LogTabs.ContainsKey($t.HostName)) {
            if ($global:LogTabs[$t.HostName].Controls.ContainsKey("MainTabButton")) {
                $global:LogTabs[$t.HostName].Controls["MainTabButton"].Text = "  $($t.HostName) (Running)"
                $global:LogTabs[$t.HostName].Controls["MainTabButton"].ForeColor = [System.Drawing.Color]::Cyan
            }
        }

        $taskName = "PnxDeploy_$(Get-Date -Format 'HHmmss')"
        $remoteLog = "C:\PnxTemp\RemotePayload\Scheduled_Live.log"
        $printLogDir = "C:\PnxTemp\RemotePayload\Printlog"
        $remoteLoadsDir = "C:\PnxTemp\RemotePayloads"
        $wrapperPath = "C:\PnxTemp\RemotePayload\wrapper_$taskName.bat"
        $ansPath = "C:\PnxTemp\RemotePayload\auto_ans_$taskName.txt"
        
        $inpsArray = $userInput -split ',' | ForEach-Object { $_.Trim() }
        $ansContent = ""
        foreach ($i in $inpsArray) { $ansContent += "$i`r`n" }
        $lastInp = if ($inpsArray.Count -gt 0) { $inpsArray[-1] } else { "Y" }
        for ($x=0; $x -lt 20; $x++) { $ansContent += "$lastInp`r`n" }

        $wContent = "@echo off`r`n"
        $wContent += "echo [SYS] Starting Native Scheduled Deployment... > `"$remoteLog`"`r`n"
        $wContent += "cd /d `"$remoteWorkDir`"`r`n"
        $wContent += "powershell.exe -NoProfile -ExecutionPolicy Bypass -Command `"& { & '$remotePath' *>&1 }`" < `"$ansPath`" >> `"$remoteLog`" 2>&1`r`n"
        $wContent += "echo [SYS] Checking for Generated Batch Files... >> `"$remoteLog`"`r`n"
        $wContent += "for /f `"tokens=*`" %%F in ('dir /b /o:-d /a:-d `"$remoteWorkDir\*.bat`" ^| findstr /v /i `"wrapper`"') do (`r`n"
        $wContent += "    echo [SYS] Found batch file: %%F >> `"$remoteLog`"`r`n"
        $wContent += "    cmd.exe /c `"`"$remoteWorkDir\%%F`"`" < `"$ansPath`" >> `"$remoteLog`" 2>&1`r`n"
        $wContent += ")`r`n"
        $wContent += "timeout /t 3 /nobreak >nul`r`n"
        $wContent += "echo [SYS] Scheduled Task Completed. >> `"$remoteLog`"`r`n"
        $wContent += "echo [SYS] Syncing Output Logs and Screenshots... >> `"$remoteLog`"`r`n"
        $wContent += "if not exist `"$remoteLoadsDir`" mkdir `"$remoteLoadsDir`"`r`n"
        $wContent += "if exist `"$printLogDir\*`" xcopy /E /I /Y `"$printLogDir\*`" `"$remoteLoadsDir\`" >> `"$remoteLog`" 2>&1`r`n"
        $wContent += "for /R `"$remoteWorkDir`" %%f in (*.png *.jpg) do copy /Y `"%%f`" `"$remoteLoadsDir\`" >> `"$remoteLog`" 2>&1`r`n"
        $wContent += "del `"$ansPath`" /Q >nul 2>&1`r`n"
        $wContent += "schtasks /delete /tn `"$taskName`" /f >> `"$remoteLog`" 2>&1"

        $sbCreate = {
            param($wPath, $wContent, $tName, $logPath, $aPath, $aContent)
            if (-not (Test-Path "C:\PnxTemp\RemotePayload")) { New-Item -ItemType Directory -Path "C:\PnxTemp\RemotePayload" -Force | Out-Null }
            Set-Content -Path $aPath -Value $aContent -Force
            Set-Content -Path $wPath -Value $wContent -Force
            $cmd = "cmd.exe /c `"$wPath`""
            schtasks /create /tn $tName /tr $cmd /sc once /st "23:59" /sd "12/31/2099" /ru SYSTEM /f | Out-Null
            schtasks /run /tn $tName | Out-Null
        }
        
        try {
            Invoke-Command -ComputerName $t.HostName -Credential $t.Credential -ScriptBlock $sbCreate -ArgumentList $wrapperPath, $wContent, $taskName, $remoteLog, $ansPath, $ansContent
            global:Write-Terminal "Task '$taskName' Initiated via Native Windows Task Scheduler." "Lime" $t.HostName
            
            $sbPoll = {
                param($logPath)
                $pos = 0
                for ($i=0; $i -lt 120; $i++) {
                    if (Test-Path $logPath) {
                        $lines = Get-Content $logPath -Encoding UTF8 -ErrorAction SilentlyContinue
                        if ($lines -is [array] -and $lines.Count -gt $pos) {
                            $lines[$pos..($lines.Count-1)] | ForEach-Object { Write-Output "SCHEDULER> $_" }
                            $pos = $lines.Count
                        } elseif ($lines -is [string] -and $pos -eq 0) {
                            Write-Output "SCHEDULER> $lines"
                            $pos = 1
                        }
                        if ($lines[-1] -match "Scheduled Task Completed") { break }
                    }
                    Start-Sleep -Seconds 5
                }
            }
            $pollJob = Invoke-Command -ComputerName $t.HostName -Credential $t.Credential -ScriptBlock $sbPoll -ArgumentList $remoteLog -AsJob
            $global:ActiveJobs += [PSCustomObject]@{ Name="Scheduled Polling"; Target=$t.HostName; Cred=$t.Credential; Job=$pollJob }
        } catch {
            global:Write-Terminal "SCHEDULER ERROR on $($t.HostName): $_" "Red" "ALL"
        }
    }
}

function global:Launch-RemoteBat($HostName, $Cred, $BatPath, $UserInput) {
    global:Write-Terminal ">> DASHBOARD INTERCEPT: Executing primary batch file..." "Yellow" $HostName
    $sb = {
        param($bPath, $uInput)
        $bDir = Split-Path $bPath -Parent
        Set-Location $bDir
        
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo.FileName = "cmd.exe"
        $proc.StartInfo.Arguments = "/c `"`"$bPath`"`" 2>&1"
        $proc.StartInfo.RedirectStandardOutput = $true
        $proc.StartInfo.RedirectStandardInput = $true
        $proc.StartInfo.RedirectStandardError = $false
        $proc.StartInfo.UseShellExecute = $false
        $proc.StartInfo.CreateNoWindow = $true
        $proc.Start() | Out-Null
        
        $signalFile = "C:\PnxTemp\input_signal.txt"
        if (Test-Path $signalFile) { Remove-Item $signalFile -Force }

        while (-not $proc.HasExited) {
            $lineBuffer = ""
            while ($proc.StandardOutput.Peek() -ne -1) {
                $ch = [char]$proc.StandardOutput.Read()
                $lineBuffer += $ch
                if ($ch -eq "`n") {
                    Write-Output $lineBuffer.TrimEnd("`r`n")
                    $lineBuffer = ""
                }
            }
            if ($lineBuffer) {
                Write-Output $lineBuffer
                if ($lineBuffer -match "(?i)(\[Y/N\]|\?|proceed|Enter option|press any key|:\s*$)") {
                    Write-Output "[DASHBOARD_LIVE_PROMPT]|$signalFile"
                    $timeout = 0
                    while (-not (Test-Path $signalFile) -and -not $proc.HasExited -and $timeout -lt 600) { Start-Sleep -Milliseconds 500; $timeout++ }
                    if (Test-Path $signalFile) {
                        $ans = (Get-Content $signalFile -Raw).Trim()
                        Remove-Item $signalFile -Force
                        $proc.StandardInput.WriteLine($ans)
                    } else { $proc.StandardInput.WriteLine("Y") }
                }
            }
            Start-Sleep -Milliseconds 50
        }
        while (-not $proc.StandardOutput.EndOfStream) { Write-Output $proc.StandardOutput.ReadLine() }

        Start-Sleep -Seconds 3 
        $printLogDir = Join-Path $bDir "Printlog"
        $remoteLoadsDir = "C:\PnxTemp\RemotePayloads"
        if (-not (Test-Path $remoteLoadsDir)) { New-Item -ItemType Directory -Path $remoteLoadsDir -Force | Out-Null }
        
        Get-ChildItem -Path $bDir -Filter "*.png" -Recurse -ErrorAction SilentlyContinue | Copy-Item -Destination $remoteLoadsDir -Force -ErrorAction SilentlyContinue
        Get-ChildItem -Path $bDir -Filter "*.jpg" -Recurse -ErrorAction SilentlyContinue | Copy-Item -Destination $remoteLoadsDir -Force -ErrorAction SilentlyContinue
        
        if (Test-Path $printLogDir) { Copy-Item -Path "$printLogDir\*" -Destination $remoteLoadsDir -Recurse -Force -ErrorAction SilentlyContinue }
        Write-Output ">> [SYS] Output sync complete: Screenshots and logs copied to RemotePayloads."
    }

    try {
        if ($global:LogTabs -and $global:LogTabs.ContainsKey($HostName)) {
            $global:LogTabs[$HostName].Controls[0].Text = "$HostName (Running)"
            $global:LogTabs[$HostName].Controls[0].ForeColor = [System.Drawing.Color]::Cyan
        }
        $job = Invoke-Command -ComputerName $HostName -Credential $Cred -ScriptBlock $sb -ArgumentList $BatPath, $UserInput -AsJob
        $global:ActiveJobs += [PSCustomObject]@{ Name = "Batch Execution"; Target = $HostName; Cred = $Cred; Job = $job }
    } catch {
        global:Write-Terminal "BATCH EXECUTION FAILED: $_" "Red" $HostName
    }
}

function global:Launch-File($path, $friendlyName) {
    if (-not (Test-Path $path) -and $global:RemoteTargets.Count -eq 0) { global:Write-Terminal "EXECUTION HALTED: File not found." "Red" "LOCAL" "EXECUTION HALTED: File not found."; return }
    $workDir = Split-Path -Path $path -Parent

    $userInput = "Y"

    # PRE-PROMPT COMPLETELY REMOVED: Execution now streams immediately without dialog
    global:Show-ExecutionLogs
    [System.Windows.Forms.Application]::DoEvents()

    if ($global:RemoteTargets.Count -gt 0) {
        global:Write-Terminal ">>> Queuing Asynchronous Remote Job on $($global:RemoteTargets.Count) server(s)..." "Cyan" "ALL" ">>> Queuing Asynchronous Remote Job on $($global:RemoteTargets.Count) server(s)..."
        global:Update-Status "Running Remote Job(s)..."

        $isLiveIntercept = ($friendlyName -eq "RMS Server Production" -or $friendlyName -eq "CAD Server Production")

        try {
            $remotePath = $path.Replace($script:CurrentToolPath, "C:\PnxTemp\RemotePayload")
            $remoteWorkDir = Split-Path $remotePath -Parent

            foreach ($t in $global:RemoteTargets) {
                
                if ($global:LogTabs -and $global:LogTabs.ContainsKey($t.HostName)) {
                    $global:LogTabs[$t.HostName].Text = "$($t.HostName) (Running)"
                    $global:LogTabs[$t.HostName].ForeColor = [System.Drawing.Color]::Cyan
                }

                $sb = {
                    param($rPath, $rDir, $uInput, $isLive)
                    Set-Location $rDir
                    $tmpFile = Join-Path $rDir "auto_answer.txt"
                    $inpsArray = $uInput -split ',' | ForEach-Object { $_.Trim() }
                    $content = ""
                    foreach ($i in $inpsArray) { $content += "$i`r`n" }
                    $lastInp = if ($inpsArray.Count -gt 0) { $inpsArray[-1] } else { "Y" }
                    for ($x=0; $x -lt 20; $x++) { $content += "$lastInp`r`n" }
                    Set-Content -Path $tmpFile -Value $content

                    if ($rPath -match "\.bat$") { 
                        cmd.exe /c "`"$rPath`" < `"$tmpFile`"" 2>&1 | ForEach-Object { Write-Output $_ }
                    } else { 
                        Get-Content $tmpFile | powershell.exe -ExecutionPolicy Bypass -File "`"$rPath`"" 2>&1 | ForEach-Object {
                            Write-Output $_
                            if ($_ -match "(?i)created at:\s*(.+?\.bat)") {
                                $batPath = $matches[1].Trim()
                                if ($batPath -match "(?i)Instance Update") {
                                    Write-Output ">> SKIPPING SECONDARY BATCH: $batPath"
                                } else {
                                    if ($isLive) {
                                        Write-Output "[DASHBOARD_LIVE_PROMPT]|$batPath"
                                    } else {
                                        Write-Output " "
                                        Write-Output ">> DASHBOARD INTERCEPT: Executing primary batch file ($batPath)..."
                                        $batDir = Split-Path $batPath -Parent
                                        Set-Location $batDir
                                        cmd.exe /c "`"$batPath`" < `"$tmpFile`"" 2>&1 | ForEach-Object { Write-Output "BATCH> $_" }
                                    }
                                }
                            }
                        }
                    }
                    Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
                }

                $job = Invoke-Command -ComputerName $t.HostName -Credential $t.Credential -ScriptBlock $sb -ArgumentList $remotePath, $remoteWorkDir, $userInput, $isLiveIntercept -AsJob
                $global:ActiveJobs += [PSCustomObject]@{
                    Name = $friendlyName
                    Target = $t.HostName
                    Cred = $t.Credential
                    Job = $job
                }
                global:Write-Terminal "Job Queued on $($t.HostName). Streaming live output..." "Lime" $t.HostName "Job Queued. Streaming live output..."
            }
        } catch {
            global:Write-Terminal "REMOTE EXECUTION QUEUE FAILED: $_" "Red" "ALL" "REMOTE EXECUTION QUEUE FAILED: $_"
            global:Update-Status "Remote Queue Failed." $true
        }
    } else {
        global:Switch-LogTab "LOCAL"
        global:Write-Terminal ">>> Launching Locally: $friendlyName" "White" "LOCAL" ">>> Launching Locally: $friendlyName"
        global:Update-Status "Script launched locally."
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
            global:Write-Terminal "Execution started successfully in external elevated window." "Lime" "LOCAL" "Execution started successfully in external elevated window."
        } catch { global:Write-Terminal "CRITICAL LAUNCH FAILURE: $_" "Red" "LOCAL" "CRITICAL LAUNCH FAILURE: $_"; global:Update-Status "Failed to launch script." $true }
    }
}

# ==========================================================================
#  7. CORE DASHBOARD MENUS & DIALOGS
# ==========================================================================

function global:Invoke-ZipEncryptDecrypt($Mode, $Value) {
    $ZipPath = Join-Path $script:CurrentToolPath "password decrypt.zip"
    $ExeName = "ConnEncryptDecrypt.exe"
    $TempExtractPath = Join-Path $env:TEMP ("ConnCrypto_" + [guid]::NewGuid().ToString("N"))
    
    try {
        if (!(Test-Path $ZipPath)) { return "ERROR: ZIP file not found at $ZipPath" }
        Expand-Archive -Path $ZipPath -DestinationPath $TempExtractPath -Force
        
        $dlls = Get-ChildItem $TempExtractPath -Filter *.dll -Recurse
        foreach ($dll in $dlls) { try { [System.Reflection.Assembly]::LoadFrom($dll.FullName) | Out-Null } catch {} }
        
        $exe = Get-ChildItem -Path $TempExtractPath -Filter $ExeName -Recurse -File | Select-Object -First 1
        if (!$exe) { return "ERROR: ConnEncryptDecrypt.exe not found inside ZIP" }
        
        $asm = [System.Reflection.Assembly]::LoadFrom($exe.FullName)
        $formType = $asm.GetTypes() | Where-Object { $_.BaseType -and $_.BaseType.FullName -eq "System.Windows.Forms.Form" } | Select-Object -First 1
        if (!$formType) { return "ERROR: WinForms Form not found inside assembly" }
        
        $form = [Activator]::CreateInstance($formType)
        $null = $form.Handle
        $form.CreateControl()

        function Get-AllControls($Parent) {
            $items = @()
            foreach ($c in $Parent.Controls) {
                $items += $c
                if ($c.Controls.Count -gt 0) { $items += Get-AllControls $c }
            }
            return $items
        }

        $allControls = Get-AllControls $form
        $textBoxes = $allControls | Where-Object { $_ -is [System.Windows.Forms.TextBox] } | Sort-Object Top
        
        $buttonLabel = if ($Mode -eq "encrypt") { "Do Encrypt" } else { "Do Decrypt" }
        $button = $allControls | Where-Object { $_ -is [System.Windows.Forms.Button] -and $_.Text -eq $buttonLabel } | Select-Object -First 1
        
        if (!$button) { return "ERROR: Button '$buttonLabel' not found" }

        $textBoxes[0].Text = $Value
        [System.Windows.Forms.Application]::DoEvents()
        
        $clickMethod = $button.GetType().GetMethod("OnClick", [System.Reflection.BindingFlags]"NonPublic,Instance")
        $clickMethod.Invoke($button, @([System.EventArgs]::Empty))
        Start-Sleep -Milliseconds 500
        [System.Windows.Forms.Application]::DoEvents()

        $result = $null
        foreach ($tb in $textBoxes) {
            if (![string]::IsNullOrWhiteSpace($tb.Text) -and $tb.Text -ne $Value) {
                $result = $tb.Text
                break
            }
        }

        $form.Dispose()
        Remove-Item $TempExtractPath -Recurse -Force -ErrorAction SilentlyContinue

        if ([string]::IsNullOrWhiteSpace($result)) { return "ERROR: No result returned from tool" }
        return $result.Trim()
    }
    catch {
        Remove-Item $TempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        return "ERROR: " + $_.Exception.Message
    }
}

function global:Show-PasswordEncryptor {
    if (-not $script:ToolsLoaded) {
        [System.Windows.Forms.MessageBox]::Show("Please load the master payload first.", "No Scripts Loaded", 0, 48)
        return
    }

    $peForm = New-Object System.Windows.Forms.Form
    $peForm.Text = "Phoenix Encrypt / Decrypt Tool"
    $peForm.Size = New-Object System.Drawing.Size(480, 420)
    $peForm.StartPosition = "CenterParent"
    $peForm.BackColor = [System.Drawing.Color]::FromArgb(255, 28, 28, 35)
    $peForm.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $peForm.FormBorderStyle = "FixedDialog"
    $peForm.MaximizeBox = $false

    $lblInput = New-Object System.Windows.Forms.Label
    $lblInput.Text = "INPUT (Plaintext or Encrypted String)"
    $lblInput.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblInput.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 200, 255)
    $lblInput.Location = New-Object System.Drawing.Point(25, 20)
    $lblInput.AutoSize = $true
    $peForm.Controls.Add($lblInput)

    $txtInput = New-Object System.Windows.Forms.TextBox
    $txtInput.Location = New-Object System.Drawing.Point(25, 45)
    $txtInput.Size = New-Object System.Drawing.Size(415, 30)
    $txtInput.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13)
    $txtInput.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $txtInput.Font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Regular)
    $txtInput.BorderStyle = "FixedSingle"
    $peForm.Controls.Add($txtInput)

    $btnEnc = New-Object System.Windows.Forms.Button
    $btnEnc.Text = "ENCRYPT"
    $btnEnc.Location = New-Object System.Drawing.Point(25, 95)
    $btnEnc.Size = New-Object System.Drawing.Size(200, 45)
    $btnEnc.BackColor = [System.Drawing.Color]::FromArgb(255, 30, 70, 110)
    $btnEnc.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $btnEnc.FlatStyle = "Flat"
    $btnEnc.FlatAppearance.BorderSize = 0
    $btnEnc.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnEnc.Cursor = "Hand"
    global:Set-RoundedCorner $btnEnc 8
    $btnEnc.Add_Click({
        $val = $txtInput.Text.Trim()
        if (-not $val) { return }
        $txtOutput.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 160, 170)
        $txtOutput.Text = "Processing background extraction..."
        [System.Windows.Forms.Application]::DoEvents()
        $res = global:Invoke-ZipEncryptDecrypt "encrypt" $val
        if ($res -match "^ERROR") { $txtOutput.ForeColor = [System.Drawing.Color]::FromArgb(255, 239, 68, 68) } else { $txtOutput.ForeColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113) }
        $txtOutput.Text = $res
    })
    $peForm.Controls.Add($btnEnc)

    $btnDec = New-Object System.Windows.Forms.Button
    $btnDec.Text = "DECRYPT"
    $btnDec.Location = New-Object System.Drawing.Point(240, 95)
    $btnDec.Size = New-Object System.Drawing.Size(200, 45)
    $btnDec.BackColor = [System.Drawing.Color]::FromArgb(255, 80, 35, 40)
    $btnDec.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $btnDec.FlatStyle = "Flat"
    $btnDec.FlatAppearance.BorderSize = 0
    $btnDec.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnDec.Cursor = "Hand"
    global:Set-RoundedCorner $btnDec 8
    $btnDec.Add_Click({
        $val = $txtInput.Text.Trim()
        if (-not $val) { return }
        $txtOutput.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 160, 170)
        $txtOutput.Text = "Processing background extraction..."
        [System.Windows.Forms.Application]::DoEvents()
        $res = global:Invoke-ZipEncryptDecrypt "decrypt" $val
        if ($res -match "^ERROR") { $txtOutput.ForeColor = [System.Drawing.Color]::FromArgb(255, 239, 68, 68) } else { $txtOutput.ForeColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113) }
        $txtOutput.Text = $res
    })
    $peForm.Controls.Add($btnDec)

    $lblOutput = New-Object System.Windows.Forms.Label
    $lblOutput.Text = "RESULT OUTPUT"
    $lblOutput.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $lblOutput.ForeColor = [System.Drawing.Color]::FromArgb(255, 100, 200, 255)
    $lblOutput.Location = New-Object System.Drawing.Point(25, 165)
    $lblOutput.AutoSize = $true
    $peForm.Controls.Add($lblOutput)

    $txtOutput = New-Object System.Windows.Forms.TextBox
    $txtOutput.Location = New-Object System.Drawing.Point(25, 190)
    $txtOutput.Size = New-Object System.Drawing.Size(415, 90)
    $txtOutput.Multiline = $true
    $txtOutput.ReadOnly = $true
    $txtOutput.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13)
    $txtOutput.ForeColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113)
    $txtOutput.Font = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Regular)
    $txtOutput.BorderStyle = "FixedSingle"
    $peForm.Controls.Add($txtOutput)

    $btnCopy = New-Object System.Windows.Forms.Button
    $btnCopy.Text = "COPY TO CLIPBOARD"
    $btnCopy.Location = New-Object System.Drawing.Point(25, 305)
    $btnCopy.Size = New-Object System.Drawing.Size(415, 45)
    $btnCopy.BackColor = [System.Drawing.Color]::FromArgb(255, 55, 35, 80)
    $btnCopy.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $btnCopy.FlatStyle = "Flat"
    $btnCopy.FlatAppearance.BorderSize = 0
    $btnCopy.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnCopy.Cursor = "Hand"
    global:Set-RoundedCorner $btnCopy 8
    $btnCopy.Add_Click({
        if (-not [string]::IsNullOrWhiteSpace($txtOutput.Text) -and $txtOutput.Text -notmatch "^Processing" -and $txtOutput.Text -notmatch "^ERROR") {
            [System.Windows.Forms.Clipboard]::SetText($txtOutput.Text)
            $btnCopy.Text = "COPIED!"
            $btnCopy.BackColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113)
            $btnCopy.ForeColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13)
            [System.Windows.Forms.Application]::DoEvents()
            Start-Sleep -Milliseconds 700
            $btnCopy.Text = "COPY TO CLIPBOARD"
            $btnCopy.BackColor = [System.Drawing.Color]::FromArgb(255, 55, 35, 80)
            $btnCopy.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
        }
    })
    $peForm.Controls.Add($btnCopy)

    [void]$peForm.ShowDialog()
}

function global:Show-Scheduler {
    if ($global:AvailableScripts.Count -eq 0 -or $script:SavedCredsList.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("You must have scripts loaded and remote connections saved to use the Scheduler.", "Error", 0, 16)
        return
    }

    $schForm = New-Object System.Windows.Forms.Form
    $schForm.Text = "Deployment Scheduler"
    $schForm.Size = New-Object System.Drawing.Size(420, 620)
    $schForm.StartPosition = "CenterParent"
    $schForm.BackColor = [System.Drawing.Color]::FromArgb(255, 28, 28, 35)
    $schForm.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $schForm.FormBorderStyle = "FixedDialog"
    $schForm.MaximizeBox = $false
    $schForm.MinimizeBox = $false

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Schedule Deployment"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15); $lblTitle.AutoSize = $true; $lblTitle.ForeColor = [System.Drawing.Color]::Cyan
    $schForm.Controls.Add($lblTitle)

    $lblScript = New-Object System.Windows.Forms.Label
    $lblScript.Text = "1. Select Script to Run:"
    $lblScript.Location = New-Object System.Drawing.Point(20, 55); $lblScript.AutoSize = $true
    $schForm.Controls.Add($lblScript)

    $cmbScripts = New-Object System.Windows.Forms.ComboBox
    $cmbScripts.Location = New-Object System.Drawing.Point(20, 75); $cmbScripts.Size = New-Object System.Drawing.Size(360, 25)
    $cmbScripts.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13); $cmbScripts.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $cmbScripts.DropDownStyle = "DropDownList"
    foreach ($s in $global:AvailableScripts) { [void]$cmbScripts.Items.Add($s.Friendly) }
    if ($cmbScripts.Items.Count -gt 0) { $cmbScripts.SelectedIndex = 0 }
    $schForm.Controls.Add($cmbScripts)

    $lblTargets = New-Object System.Windows.Forms.Label
    $lblTargets.Text = "2. Select Target Servers:"
    $lblTargets.Location = New-Object System.Drawing.Point(20, 115); $lblTargets.AutoSize = $true
    $schForm.Controls.Add($lblTargets)

    $clbTargets = New-Object System.Windows.Forms.CheckedListBox
    $clbTargets.Location = New-Object System.Drawing.Point(20, 135); $clbTargets.Size = New-Object System.Drawing.Size(360, 100)
    $clbTargets.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13); $clbTargets.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $clbTargets.CheckOnClick = $true
    foreach ($c in $script:SavedCredsList) { [void]$clbTargets.Items.Add($c.HostName) }
    $schForm.Controls.Add($clbTargets)

    $lblInput = New-Object System.Windows.Forms.Label
    $lblInput.Text = "3. Script Inputs (Comma Separated):"
    $lblInput.Location = New-Object System.Drawing.Point(20, 245); $lblInput.AutoSize = $true
    $schForm.Controls.Add($lblInput)

    $txtInput = New-Object System.Windows.Forms.TextBox
    $txtInput.Location = New-Object System.Drawing.Point(20, 265); $txtInput.Size = New-Object System.Drawing.Size(360, 25)
    $txtInput.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13); $txtInput.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $txtInput.Text = "Y"
    $schForm.Controls.Add($txtInput)

    $lblTime = New-Object System.Windows.Forms.Label
    $lblTime.Text = "4. Select Date and Time:"
    $lblTime.Location = New-Object System.Drawing.Point(20, 300); $lblTime.AutoSize = $true
    $schForm.Controls.Add($lblTime)

    $dtp = New-Object System.Windows.Forms.DateTimePicker
    $dtp.Location = New-Object System.Drawing.Point(20, 320); $dtp.Size = New-Object System.Drawing.Size(360, 25)
    $dtp.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
    $dtp.CustomFormat = "MM/dd/yyyy hh:mm tt"
    $schForm.Controls.Add($dtp)

    $lblTZ = New-Object System.Windows.Forms.Label
    $lblTZ.Text = "5. Select Time Zone:"
    $lblTZ.Location = New-Object System.Drawing.Point(20, 360); $lblTZ.AutoSize = $true
    $schForm.Controls.Add($lblTZ)

    $cmbTZ = New-Object System.Windows.Forms.ComboBox
    $cmbTZ.Location = New-Object System.Drawing.Point(20, 380); $cmbTZ.Size = New-Object System.Drawing.Size(360, 25)
    $cmbTZ.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13); $cmbTZ.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $cmbTZ.DropDownStyle = "DropDownList"
    $cmbTZ.Items.Add("Local Time (Your PC)") | Out-Null
    $cmbTZ.Items.Add("IST (India Standard Time)") | Out-Null
    $cmbTZ.Items.Add("EST (Eastern Standard Time)") | Out-Null
    $cmbTZ.Items.Add("CST (Central Standard Time)") | Out-Null
    $cmbTZ.Items.Add("PST (Pacific Standard Time)") | Out-Null
    $cmbTZ.SelectedIndex = 0
    $schForm.Controls.Add($cmbTZ)

    $btnSch = New-Object System.Windows.Forms.Button
    $btnSch.Text = "Add to Schedule"
    $btnSch.Location = New-Object System.Drawing.Point(210, 430); $btnSch.Size = New-Object System.Drawing.Size(170, 40)
    $btnSch.BackColor = [System.Drawing.Color]::FromArgb(255, 30, 70, 110); $btnSch.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $btnSch.FlatStyle = "Flat"; $btnSch.FlatAppearance.BorderSize = 0; $btnSch.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    global:Set-RoundedCorner $btnSch 10
    
    $btnSch.Add_Click({
        if ($clbTargets.CheckedItems.Count -eq 0) { [System.Windows.Forms.MessageBox]::Show("Please select at least one server.", "Error", 0, 16); return }
        $unspecTime = [datetime]::SpecifyKind($dtp.Value, [DateTimeKind]::Unspecified)
        $targetTime = $unspecTime
        try {
            if ($cmbTZ.SelectedItem -eq "IST (India Standard Time)") { $targetTime = [System.TimeZoneInfo]::ConvertTime($unspecTime, [System.TimeZoneInfo]::FindSystemTimeZoneById("India Standard Time"), [System.TimeZoneInfo]::Local) } 
            elseif ($cmbTZ.SelectedItem -eq "EST (Eastern Standard Time)") { $targetTime = [System.TimeZoneInfo]::ConvertTime($unspecTime, [System.TimeZoneInfo]::FindSystemTimeZoneById("Eastern Standard Time"), [System.TimeZoneInfo]::Local) } 
            elseif ($cmbTZ.SelectedItem -eq "CST (Central Standard Time)") { $targetTime = [System.TimeZoneInfo]::ConvertTime($unspecTime, [System.TimeZoneInfo]::FindSystemTimeZoneById("Central Standard Time"), [System.TimeZoneInfo]::Local) } 
            elseif ($cmbTZ.SelectedItem -eq "PST (Pacific Standard Time)") { $targetTime = [System.TimeZoneInfo]::ConvertTime($unspecTime, [System.TimeZoneInfo]::FindSystemTimeZoneById("Pacific Standard Time"), [System.TimeZoneInfo]::Local) } 
            else { $targetTime = $dtp.Value }
        } catch { $targetTime = $dtp.Value }

        $selScript = $global:AvailableScripts | Where-Object { $_.Friendly -eq $cmbScripts.SelectedItem } | Select-Object -First 1
        $selTargets = @()
        foreach ($checked in $clbTargets.CheckedItems) {
            $match = $script:SavedCredsList | Where-Object { $_.HostName -eq $checked } | Select-Object -First 1
            if ($match) { $selTargets += $match }
        }

        $newJob = [PSCustomObject]@{ ScriptPath = $selScript.FullName; FriendlyName = $selScript.Friendly; Targets = $selTargets; RunTime = $targetTime; Status = "Pending"; UserInput = $txtInput.Text }
        $global:ScheduledJobs += $newJob
        
        global:Show-ExecutionLogs
        global:Write-Terminal ">>> SCHEDULED: $($selScript.Friendly) on $($selTargets.Count) server(s) for $($targetTime.ToString('MM/dd/yyyy hh:mm tt')) (Local Target)" "Cyan" "ALL"
        global:Update-Status "Job Scheduled."
        
        $global:RemoteTargets = $selTargets
        global:Build-LogTabs
        $schForm.Close()
    })
    $schForm.Controls.Add($btnSch)

    $btnCan = New-Object System.Windows.Forms.Button
    $btnCan.Text = "Cancel"
    $btnCan.Location = New-Object System.Drawing.Point(90, 430); $btnCan.Size = New-Object System.Drawing.Size(100, 40)
    $btnCan.BackColor = [System.Drawing.Color]::FromArgb(255, 80, 35, 40); $btnCan.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $btnCan.FlatStyle = "Flat"; $btnCan.FlatAppearance.BorderSize = 0; $btnCan.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    global:Set-RoundedCorner $btnCan 10
    $btnCan.Add_Click({ $schForm.Close() })
    $schForm.Controls.Add($btnCan)

    [void]$schForm.ShowDialog()
}

function global:Show-RemoteManager {
    if (-not $script:ToolsLoaded) {
        [System.Windows.Forms.MessageBox]::Show("Please load the master payload first.", "No Scripts Loaded", 0, 48)
        return
    }

    $remForm = New-Object System.Windows.Forms.Form
    $remForm.Text = "Remote Server Manager & Deployment Pipeline"
    $remForm.Size = New-Object System.Drawing.Size(460, 780)
    $remForm.StartPosition = "CenterParent"
    $remForm.BackColor = [System.Drawing.Color]::FromArgb(255, 28, 28, 35)
    $remForm.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $remForm.FormBorderStyle = "FixedDialog"
    $remForm.MaximizeBox = $false

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Standard Remote Connection"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.Location = New-Object System.Drawing.Point(20, 15); $lblTitle.AutoSize = $true; $lblTitle.ForeColor = [System.Drawing.Color]::Cyan
    $remForm.Controls.Add($lblTitle)

    $clbSaved = New-Object System.Windows.Forms.CheckedListBox
    $clbSaved.Location = New-Object System.Drawing.Point(20, 45); $clbSaved.Size = New-Object System.Drawing.Size(400, 80)
    $clbSaved.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13); $clbSaved.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $clbSaved.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular); $clbSaved.CheckOnClick = $true
    $remForm.Controls.Add($clbSaved)
    
    $credsFile = "C:\PnxTemp\RemoteCreds.xml"
    if (Test-Path $credsFile) {
        try {
            $script:SavedCredsList = @(Import-Clixml $credsFile)
            foreach ($c in $script:SavedCredsList) { [void]$clbSaved.Items.Add($c.HostName) }
        } catch {}
    }

    $btnPush = New-Object System.Windows.Forms.Button
    $btnPush.Text = "Standard Connect"
    $btnPush.Location = New-Object System.Drawing.Point(250, 135); $btnPush.Size = New-Object System.Drawing.Size(170, 35)
    $btnPush.BackColor = [System.Drawing.Color]::FromArgb(255, 30, 70, 110); $btnPush.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $btnPush.FlatStyle = "Flat"; $btnPush.FlatAppearance.BorderSize = 0; $btnPush.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    global:Set-RoundedCorner $btnPush 10
    $btnPush.Add_Click({
        $selectedTargets = @()
        foreach ($checked in $clbSaved.CheckedItems) {
            $match = $script:SavedCredsList | Where-Object { $_.HostName -eq $checked } | Select-Object -First 1
            if ($match) { $selectedTargets += $match }
        }
        if ($selectedTargets.Count -eq 0) { return }
        $global:RemoteTargets = $selectedTargets
        global:Build-LogTabs
        global:Update-Status "Standard Remote Mode Active."
        $remForm.Close()
    })
    $remForm.Controls.Add($btnPush)

    # --- PIPELINE GROUPING UI ---
    $lblPipeTitle = New-Object System.Windows.Forms.Label
    $lblPipeTitle.Text = "Orchestrated Pipeline (App + DB Sync)"
    $lblPipeTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblPipeTitle.Location = New-Object System.Drawing.Point(20, 200); $lblPipeTitle.AutoSize = $true; $lblPipeTitle.ForeColor = [System.Drawing.Color]::FromArgb(255, 230, 160, 60)
    $remForm.Controls.Add($lblPipeTitle)

    $lblApp = New-Object System.Windows.Forms.Label
    $lblApp.Text = "Application Server (Runs Test/Demo Hotfix):"
    $lblApp.Location = New-Object System.Drawing.Point(20, 235); $lblApp.AutoSize = $true
    $remForm.Controls.Add($lblApp)
    
    $cmbApp = New-Object System.Windows.Forms.ComboBox
    $cmbApp.Location = New-Object System.Drawing.Point(20, 255); $cmbApp.Size = New-Object System.Drawing.Size(400, 25)
    $cmbApp.DropDownStyle = "DropDownList"
    foreach ($c in $script:SavedCredsList) { [void]$cmbApp.Items.Add($c.HostName) }
    $remForm.Controls.Add($cmbApp)

    $lblDb = New-Object System.Windows.Forms.Label
    $lblDb.Text = "Database Server (Runs DB Sync Tool):"
    $lblDb.Location = New-Object System.Drawing.Point(20, 290); $lblDb.AutoSize = $true
    $remForm.Controls.Add($lblDb)

    $cmbDb = New-Object System.Windows.Forms.ComboBox
    $cmbDb.Location = New-Object System.Drawing.Point(20, 310); $cmbDb.Size = New-Object System.Drawing.Size(400, 25)
    $cmbDb.DropDownStyle = "DropDownList"
    foreach ($c in $script:SavedCredsList) { [void]$cmbDb.Items.Add($c.HostName) }
    $remForm.Controls.Add($cmbDb)

    $lblSqlInst = New-Object System.Windows.Forms.Label
    $lblSqlInst.Text = "SQL Instance Name:"
    $lblSqlInst.Location = New-Object System.Drawing.Point(20, 345); $lblSqlInst.AutoSize = $true
    $remForm.Controls.Add($lblSqlInst)

    $txtSqlInst = New-Object System.Windows.Forms.TextBox
    $txtSqlInst.Location = New-Object System.Drawing.Point(20, 365); $txtSqlInst.Size = New-Object System.Drawing.Size(190, 25)
    $txtSqlInst.Text = "MSSQLSERVER"
    $remForm.Controls.Add($txtSqlInst)

    $lblEnv = New-Object System.Windows.Forms.Label
    $lblEnv.Text = "Target Environment:"
    $lblEnv.Location = New-Object System.Drawing.Point(230, 345); $lblEnv.AutoSize = $true
    $remForm.Controls.Add($lblEnv)

    $cmbEnv = New-Object System.Windows.Forms.ComboBox
    $cmbEnv.Location = New-Object System.Drawing.Point(230, 365); $cmbEnv.Size = New-Object System.Drawing.Size(190, 25)
    $cmbEnv.DropDownStyle = "DropDownList"
    $cmbEnv.Items.Add("Live") | Out-Null
    $cmbEnv.Items.Add("Test") | Out-Null
    $cmbEnv.SelectedIndex = 1
    $remForm.Controls.Add($cmbEnv)

    $lblSqlUser = New-Object System.Windows.Forms.Label
    $lblSqlUser.Text = "SQL Username:"
    $lblSqlUser.Location = New-Object System.Drawing.Point(20, 400); $lblSqlUser.AutoSize = $true
    $remForm.Controls.Add($lblSqlUser)

    $txtSqlUser = New-Object System.Windows.Forms.TextBox
    $txtSqlUser.Location = New-Object System.Drawing.Point(20, 420); $txtSqlUser.Size = New-Object System.Drawing.Size(190, 25)
    $remForm.Controls.Add($txtSqlUser)

    $lblSqlPass = New-Object System.Windows.Forms.Label
    $lblSqlPass.Text = "SQL Password:"
    $lblSqlPass.Location = New-Object System.Drawing.Point(230, 400); $lblSqlPass.AutoSize = $true
    $remForm.Controls.Add($lblSqlPass)

    $txtSqlPass = New-Object System.Windows.Forms.TextBox
    $txtSqlPass.Location = New-Object System.Drawing.Point(230, 420); $txtSqlPass.Size = New-Object System.Drawing.Size(190, 25)
    $txtSqlPass.UseSystemPasswordChar = $true
    $remForm.Controls.Add($txtSqlPass)

    $btnPipeline = New-Object System.Windows.Forms.Button
    $btnPipeline.Text = "Start Pipeline Update"
    $btnPipeline.Location = New-Object System.Drawing.Point(20, 465); $btnPipeline.Size = New-Object System.Drawing.Size(400, 45)
    $btnPipeline.BackColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113); $btnPipeline.ForeColor = [System.Drawing.Color]::Black
    $btnPipeline.FlatStyle = "Flat"; $btnPipeline.FlatAppearance.BorderSize = 0; $btnPipeline.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    global:Set-RoundedCorner $btnPipeline 10
    
    $btnPipeline.Add_Click({
        if ($btnPipeline.Text -match "Initiating") { return } 
        
        if (-not $cmbApp.SelectedItem -or -not $cmbDb.SelectedItem) {
            [System.Windows.Forms.MessageBox]::Show("Please select an App and DB Server.", "Error", 0, 16); return
        }
        
        $btnPipeline.Enabled = $false
        $btnPipeline.Text = "Initiating Pipeline (Please Wait)..."
        [System.Windows.Forms.Application]::DoEvents()
        
        try {
            $appTarget = $script:SavedCredsList | Where-Object { $_.HostName -eq $cmbApp.SelectedItem } | Select-Object -First 1
            $dbTarget = $script:SavedCredsList | Where-Object { $_.HostName -eq $cmbDb.SelectedItem } | Select-Object -First 1
            $global:RemoteTargets = @($appTarget, $dbTarget)
            
            global:Build-LogTabs
            global:Show-ExecutionLogs
            
            $appScript = $global:AvailableScripts | Where-Object { $_.Friendly -match "Test/Demo Hotfix" } | Select-Object -First 1
            if ($appScript) {
                global:Write-Terminal "--- PIPELINE: Triggering Application Update ---" "Yellow" $appTarget.HostName
                $global:RemoteTargets = @($appTarget)
                global:Launch-File $appScript.FullName $appScript.Friendly
            }
            
            $dbScript = $global:AvailableScripts | Where-Object { $_.Friendly -match "DB Sync Tool" } | Select-Object -First 1
            if ($dbScript) {
                global:Write-Terminal "--- PIPELINE: Triggering Database Sync ---" "Yellow" $dbTarget.HostName
                $global:RemoteTargets = @($dbTarget)
                $sqlU = $txtSqlUser.Text; $sqlP = $txtSqlPass.Text; $sqlI = $txtSqlInst.Text
                $envTarget = $cmbEnv.SelectedItem
                $configPayload = "Environment=$envTarget`r`nSyncMode=3`r`nSave=True`r`nAutoUpdateDB=True`r`nSQLUser=$sqlU`r`nSQLPass=$sqlP`r`nSQLInstance=$sqlI"
                
                Invoke-Command -ComputerName $dbTarget.HostName -Credential $dbTarget.Credential -ScriptBlock {
                    param($config)
                    if (-not (Test-Path "C:\PnxTemp")) { New-Item -ItemType Directory -Path "C:\PnxTemp" -Force | Out-Null }
                    Set-Content -Path "C:\PnxTemp\DBSync_AutoConfig.ini" -Value $config -Force
                } -ArgumentList $configPayload
                
                global:Launch-File $dbScript.FullName $dbScript.Friendly
            }
            
            $global:RemoteTargets = @($appTarget, $dbTarget)
        } finally {
            $remForm.Close()
        }
    })
    $remForm.Controls.Add($btnPipeline)

    # --- ADD NEW SERVER UI ---
    $lblOr = New-Object System.Windows.Forms.Label
    $lblOr.Text = "--- AND / OR Add a New Connection ---"
    $lblOr.Location = New-Object System.Drawing.Point(20, 525); $lblOr.AutoSize = $true; $lblOr.ForeColor = [System.Drawing.Color]::FromArgb(255, 160, 160, 170)
    $remForm.Controls.Add($lblOr)

    $lblHost = New-Object System.Windows.Forms.Label
    $lblHost.Text = "Hostname or IP Address:"
    $lblHost.Location = New-Object System.Drawing.Point(20, 545); $lblHost.AutoSize = $true
    $remForm.Controls.Add($lblHost)

    $txtHost = New-Object System.Windows.Forms.TextBox
    $txtHost.Location = New-Object System.Drawing.Point(20, 565); $txtHost.Size = New-Object System.Drawing.Size(400, 25)
    $txtHost.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13); $txtHost.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $remForm.Controls.Add($txtHost)

    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = "Admin Username (e.g. Domain\Admin):"
    $lblUser.Location = New-Object System.Drawing.Point(20, 595); $lblUser.AutoSize = $true
    $remForm.Controls.Add($lblUser)

    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Location = New-Object System.Drawing.Point(20, 615); $txtUser.Size = New-Object System.Drawing.Size(190, 25)
    $txtUser.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13); $txtUser.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $remForm.Controls.Add($txtUser)

    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Text = "Password:"
    $lblPass.Location = New-Object System.Drawing.Point(230, 595); $lblPass.AutoSize = $true
    $remForm.Controls.Add($lblPass)

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Location = New-Object System.Drawing.Point(230, 615); $txtPass.Size = New-Object System.Drawing.Size(190, 25)
    $txtPass.UseSystemPasswordChar = $true; $txtPass.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13); $txtPass.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $remForm.Controls.Add($txtPass)

    $btnPushAdd = New-Object System.Windows.Forms.Button
    $btnPushAdd.Text = "Save & Connect New Server"
    $btnPushAdd.Location = New-Object System.Drawing.Point(20, 655); $btnPushAdd.Size = New-Object System.Drawing.Size(400, 35)
    $btnPushAdd.BackColor = [System.Drawing.Color]::FromArgb(255, 30, 70, 110); $btnPushAdd.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $btnPushAdd.FlatStyle = "Flat"; $btnPushAdd.FlatAppearance.BorderSize = 0; $btnPushAdd.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    global:Set-RoundedCorner $btnPushAdd 10
    $btnPushAdd.Add_Click({
        $h = $txtHost.Text.Trim(); $u = $txtUser.Text.Trim(); $p = $txtPass.Text
        if (-not $h -or -not $u -or -not $p) { [System.Windows.Forms.MessageBox]::Show("Please fill all fields for a new connection.", "Error", 0, 16); return }

        $secStr = ConvertTo-SecureString $p -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($u, $secStr)
        $newTarget = [PSCustomObject]@{ HostName = $h; Credential = $cred }
        
        $existing = $script:SavedCredsList | Where-Object { $_.HostName -eq $h } | Select-Object -First 1
        if ($existing) { $existing.Credential = $cred } else { $script:SavedCredsList = @($script:SavedCredsList) + $newTarget }
        $script:SavedCredsList | Export-Clixml -Path $credsFile -Force

        $global:RemoteTargets = @($newTarget)
        global:Build-LogTabs; global:Show-ExecutionLogs; $remForm.Close()
    })
    $remForm.Controls.Add($btnPushAdd)

    $btnDisconnect = New-Object System.Windows.Forms.Button
    $btnDisconnect.Text = "Revert to Local Execution"
    $btnDisconnect.Location = New-Object System.Drawing.Point(130, 705); $btnDisconnect.Size = New-Object System.Drawing.Size(200, 35)
    $btnDisconnect.BackColor = [System.Drawing.Color]::FromArgb(255, 80, 35, 40); $btnDisconnect.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
    $btnDisconnect.FlatStyle = "Flat"; $btnDisconnect.FlatAppearance.BorderSize = 0; global:Set-RoundedCorner $btnDisconnect 8
    $btnDisconnect.Add_Click({ $global:RemoteTargets = @(); global:Switch-LogTab "LOCAL"; $remForm.Close() })
    $remForm.Controls.Add($btnDisconnect)

    [void]$remForm.ShowDialog()
}

function global:Show-ExecutionLogs {
    if ($null -ne $script:pnlConsole -and $null -ne $script:btnTabLogs) {
        $script:form.SuspendLayout()
        $script:pnlTools.Visible = $false
        $script:pnlConsole.Visible = $true
        $script:pnlConsole.Dock = "Fill"
        $script:pnlConsole.BringToFront()
        
        $script:btnTabLogs.BackColor = $colorTabActive
        $script:btnTabLogs.ForeColor = $colorTextWhite
        $script:btnTabScripts.BackColor = $colorTabDeact
        $script:btnTabScripts.ForeColor = $colorTextMuted
        
        $script:form.ResumeLayout($true)
        if ($script:pnlToolsWrapper) { $script:pnlToolsWrapper.Invalidate($true) }
    }
}

function global:Show-DashboardGuide {
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

function global:Show-HelpPrompt {
    if (-not $script:ToolsLoaded) {
        global:Update-Status "Master Directory not loaded." $true
        return
    }

    $helpForm = New-Object System.Windows.Forms.Form
    $helpForm.Text = "ProPhoenix Documentation Library"
    $helpForm.Size = New-Object System.Drawing.Size(950, 650)
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
    $lblSub.Text = "Browse categorized internal chapters."
    $lblSub.Font = $fontSubHeader
    $lblSub.Location = New-Object System.Drawing.Point(22, 45)
    $lblSub.AutoSize = $true
    $lblSub.ForeColor = $colorTextMuted
    $helpForm.Controls.Add($lblSub)

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

    $rtbViewer = New-Object System.Windows.Forms.RichTextBox
    $rtbViewer.Location = New-Object System.Drawing.Point(335, 80)
    $rtbViewer.Size = New-Object System.Drawing.Size(575, 460)
    $rtbViewer.BackColor = $colorConsoleBg
    $rtbViewer.ForeColor = $colorTextWhite
    $rtbViewer.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)
    $rtbViewer.ReadOnly = $true
    $rtbViewer.BorderStyle = "None"
    $helpForm.Controls.Add($rtbViewer)

    $internalRoot = New-Object System.Windows.Forms.TreeNode("Phoenix Master Documentation")
    $internalRoot.NodeFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $internalRoot.ForeColor = $colorLblDash
    $tvDocs.Nodes.Add($internalRoot)

    $sections = $script:GuideText -split '(?m)^(?=\d+\.\s)'
    foreach ($sec in $sections) {
        if ($sec.Trim() -match "^(\d+\.\s+.*?)\r?\n") {
            $title = $matches[1].Trim()
            $content = $sec.Trim()
            $node = New-Object System.Windows.Forms.TreeNode($title)
            $node.Tag = "INTERNAL_SECTION_CONTENT|" + $content
            $node.ForeColor = $colorTextWhite
            $internalRoot.Nodes.Add($node)
        } elseif ($sec.Trim() -ne "") {
            $node = New-Object System.Windows.Forms.TreeNode("Introduction")
            $node.Tag = "INTERNAL_SECTION_CONTENT|" + $sec.Trim()
            $node.ForeColor = $colorTextWhite
            $internalRoot.Nodes.Add($node)
        }
    }

    $internalRoot.ExpandAll()

    $tvDocs.Add_AfterSelect({
        $selected = $tvDocs.SelectedNode
        if ($selected.Tag -match "^INTERNAL_SECTION_CONTENT\|(.*)") {
            $rtbViewer.Text = $matches[1]
        } else {
            $rtbViewer.Text = "`n`n   Please select a specific chapter from the left."
        }
    })

    if ($internalRoot.Nodes.Count -gt 0) { $tvDocs.SelectedNode = $internalRoot.Nodes[0] }

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close Viewer"
    $btnClose.Location = New-Object System.Drawing.Point(760, 560)
    $btnClose.Size = New-Object System.Drawing.Size(150, 40)
    $btnClose.BackColor = $colorBtnGen
    $btnClose.ForeColor = $colorTextWhite
    $btnClose.FlatStyle = "Flat"
    $btnClose.FlatAppearance.BorderSize = 0
    $btnClose.Font = $fontMenuBold
    $btnClose.Cursor = "Hand"
    global:Set-RoundedCorner $btnClose 10
    $btnClose.Add_Click({ $helpForm.Close() })
    $helpForm.Controls.Add($btnClose)

    [void]$helpForm.ShowDialog()
}

function global:Show-LicenseVerification {
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

            <Button Name="btnOld" Grid.Row="0" Content="? OLD LICENSE DATA" Height="40" Margin="0,0,0,5"/>
            <TextBox Name="txtOld" Grid.Row="1" Height="150" Visibility="Collapsed" Margin="0,0,0,15" TextWrapping="Wrap" />

            <Button Name="btnNew" Grid.Row="2" Content="? NEW LICENSE DATA" Height="40" Margin="0,0,0,5"/>
            <TextBox Name="txtNew" Grid.Row="3" Height="150" Visibility="Collapsed" Margin="0,0,0,20" TextWrapping="Wrap"/>

            <Button Name="btnAnalyse" Grid.Row="4" Content="? EXECUTE SMART ANALYSE" Height="50" Background="#00E5FF" Foreground="#0B132B" FontSize="16" Margin="0,0,0,20"/>

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

    $btnOld = $Window.FindName("btnOld")
    $txtOld = $Window.FindName("txtOld")
    $btnNew = $Window.FindName("btnNew")
    $txtNew = $Window.FindName("txtNew")
    $btnAnalyse = $Window.FindName("btnAnalyse")
    $rtbResults = $Window.FindName("rtbResults")

    $btnOld.Add_Click({
        if ($txtOld.Visibility -eq 'Collapsed') {
            $txtOld.Visibility = 'Visible'; $btnOld.Content = "? OLD LICENSE DATA"
        } else {
            $txtOld.Visibility = 'Collapsed'; $btnOld.Content = "? OLD LICENSE DATA"
        }
    })

    $btnNew.Add_Click({
        if ($txtNew.Visibility -eq 'Collapsed') {
            $txtNew.Visibility = 'Visible'; $btnNew.Content = "? NEW LICENSE DATA"
        } else {
            $txtNew.Visibility = 'Collapsed'; $btnNew.Content = "? NEW LICENSE DATA"
        }
    })

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

                if (($listOld -eq $listNew) -and ($prefixOld -eq $prefixNew)) { $isMatch = $true }
            } 
            elseif ($lineOld -eq $lineNew) { $isMatch = $true }

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

    $Window.ShowDialog() | Out-Null
}

function global:Refresh-List {
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

    global:Set-FolderPermissions $script:CurrentToolPath $true
    global:Unblock-ExtractedFiles $script:CurrentToolPath $true

    # COMPLIANCE: Strictly ignore folders/files matching Hub or Gateway
    $Files = Get-ChildItem -Path $script:CurrentToolPath -Include *.ps1, *.bat -Recurse -File | Where-Object { $_.Name -notmatch "Prophoenix_Dashboard" -and $_.FullName -notmatch "(?i)Hub|Gateway" }
    $SortedList = $Files | Select-Object Name, FullName, @{Name="Friendly"; Expression={global:Get-FriendlyName $_.Name}}, @{Name="Rank"; Expression={global:Get-SortOrder (global:Get-FriendlyName $_.Name)}} | Sort-Object Rank, Friendly
    
    $global:AvailableScripts = $SortedList

    foreach ($item in $SortedList) {
        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size(890, 36) 
        $card.Location = New-Object System.Drawing.Point(15, $Y)
        $card.BackColor = $colorRowGlass
        $card.Cursor = "Hand"
        global:Set-RoundedCorner $card 8
        
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
        global:Set-RoundedCorner $b 5
        
        $b.Add_MouseEnter({ $this.BackColor = $colorTabActive; $this.ForeColor = $colorTextWhite }.GetNewClosure())
        $b.Add_MouseLeave({ $this.BackColor = $colorMainBg; $this.ForeColor = $colorTextWhite }.GetNewClosure())

        $path = $item.FullName; $name = $item.Friendly
        $action = { global:Launch-File $path $name }.GetNewClosure()
        $b.Add_Click($action)
        $card.Controls.Add($b)
        
        $script:pnlTools.Controls.Add($card)
        $Y += 40 
    }
}

function global:Search-Master {
    global:Show-ExecutionLogs
    $script:form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    global:Update-Status "Scanning for Master..."
    global:Write-Terminal "======================================================" "White" "ALL"
    global:Write-Terminal "INITIATING DEEP ENVIRONMENT SEARCH" "Cyan" "ALL"
    
    try {
        $FoundZip = $null
        
        # COMPLIANCE: Prioritize all local environment drives automatically
        $SearchLocations = @()
        foreach ($drive in [System.IO.DriveInfo]::GetDrives() | Where-Object {$_.DriveType -eq 'Fixed'}) {
            $SearchLocations += @{ Path = $drive.RootDirectory.FullName; Recurse = $true }
        }

        foreach ($loc in $SearchLocations) {
            $dir = $loc.Path
            if ($dir -and (Test-Path $dir)) {
                global:Write-Terminal "Scanning System Drive: $dir..." "LightGray" "ALL"
                # Deep search increased to Depth 5 for strict compliance
                $zips = Get-ChildItem -Path $dir -Filter $ZipNamePattern -File -Recurse -Depth 5 -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "(?i)Hub|Gateway" } | Sort-Object LastWriteTime -Descending

                foreach ($zip in $zips) {
                    if (global:Test-ZipValidity $zip.FullName) {
                        $FoundZip = $zip.FullName
                        global:Write-Terminal "VERIFIED: Master Payload Found at $($zip.FullName)" "Lime" "ALL"
                        break
                    }
                }
                if ($FoundZip) { break }
            }
        }

        if (-not $FoundZip) {
            global:Update-Status "Master zip not found automatically." $true
            $dlg = New-Object System.Windows.Forms.OpenFileDialog
            $dlg.Filter = "Zip Files (*.zip)|*.zip"; $dlg.Title = "Locate Phoenix Master Zip"
            if ($dlg.ShowDialog() -eq "OK") {
                if (global:Test-ZipValidity $dlg.FileName) { $FoundZip = $dlg.FileName } 
                else { global:Update-Status "Manual file corrupt." $true; return }
            } else { global:Update-Status "Ready."; return }
        }

        if ($FoundZip) {
            [System.Windows.Forms.Application]::DoEvents()
            global:Write-Terminal "Staging payload for secure extraction..." "White" "ALL"

            if (Test-Path "C:\PnxTemp\MasterTemp.zip") { Remove-Item "C:\PnxTemp\MasterTemp.zip" -Force -ErrorAction SilentlyContinue }
            if (-not (Test-Path "C:\PnxTemp")) { New-Item -ItemType Directory -Path "C:\PnxTemp" -Force | Out-Null }
            
            $LocalZip = "C:\PnxTemp\MasterTemp.zip"
            try { Copy-Item -Path $FoundZip -Destination $LocalZip -Force } catch {}
            try { 
                Expand-Archive -Path $LocalZip -DestinationPath $InstallBase -Force 
                Remove-Item -Path $LocalZip -Force -ErrorAction SilentlyContinue
                global:Write-Terminal "Extraction 100% complete and archive deleted." "Lime" "ALL"
            } catch { global:Update-Status "Extraction Error." $true; return }
            
            $script:CurrentToolPath = $InstallBase
            $Nested = Join-Path $InstallBase "Phoenix Installation Master"
            if (Test-Path $Nested) { $script:CurrentToolPath = $Nested }

            global:Set-FolderPermissions $script:CurrentToolPath $false
            global:Unblock-ExtractedFiles $script:CurrentToolPath $false

            $script:ToolsLoaded = $true
            global:Refresh-List
            global:Update-Status "Master Loaded Successfully."
            global:Write-Terminal "Dashboard Armed and Operational." "Lime" "ALL"
        }
    } finally {
        $script:form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

function global:Run-PreFlightDiagnostics {
    global:Show-ExecutionLogs
    $script:form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    global:Update-Status "Running System Diagnostics..."
    global:Write-Terminal "--- INITIATING PRE-FLIGHT ENVIRONMENT AUDIT ---" "Cyan" "ALL"
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        if ($freeGB -lt 10) { global:Write-Terminal "C:\ Drive Space: $freeGB GB (WARNING: LOW STORAGE)" "Red" "ALL" }
        else { global:Write-Terminal "C:\ Drive Space: $freeGB GB" "Lime" "ALL" }

        $iis = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
        if ($iis) { global:Write-Terminal "IIS Service (W3SVC): $($iis.Status)" "Lime" "ALL" } 
        else { global:Write-Terminal "IIS Service (W3SVC): Not Installed / Not Found" "Yellow" "ALL" }

        $sql = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
        if ($sql) { global:Write-Terminal "SQL Service (MSSQLSERVER): $($sql.Status)" "Lime" "ALL" } 
        else { global:Write-Terminal "SQL Service (MSSQLSERVER): Not Installed / Not Found" "Yellow" "ALL" }

        global:Write-Terminal "Local PS Execution Policy: $(Get-ExecutionPolicy)" "White" "ALL"

        global:Write-Terminal "Testing SFTP (sftp.prophoenix.com:25544)..." "Yellow" "ALL"
        $sftpRes = Test-NetConnection -ComputerName "sftp.prophoenix.com" -Port 25544 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($sftpRes) { global:Write-Terminal "SFTP Connection: SUCCESS (OPEN)" "Lime" "ALL" }
        else { global:Write-Terminal "SFTP Connection: FAILED (BLOCKED)" "Red" "ALL" }

        global:Write-Terminal "Purging Browser Cache & Temp Files..." "Yellow" "ALL"
        $CachePaths = @("$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*", "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*", "$env:TEMP\*", "$env:WINDIR\Temp\*")
        foreach ($path in $CachePaths) { try { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue } catch {} }
        global:Write-Terminal "Cache Purge Complete." "Lime" "ALL"

        global:Update-Status "Diagnostics Completed Successfully."
    } catch { 
        global:Write-Terminal "Diagnostic Error: $_" "Red" "ALL"
        global:Update-Status "Diagnostic Error encountered." $true
    }
    global:Write-Terminal "--- PRE-FLIGHT AUDIT COMPLETE ---" "Cyan" "ALL"
    $script:form.Cursor = [System.Windows.Forms.Cursors]::Default
}

function global:Check-PublicIP {
    global:Show-ExecutionLogs
    $script:form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    global:Update-Status "Checking Public IP..."
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $ip = Invoke-RestMethod -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 5
        global:Write-Terminal "Public IP Resolved: $ip" "Cyan" "ALL"
        global:Update-Status "Public IP Retrieved Successfully."
    } catch {
        global:Write-Terminal "Failed to reach external IP service." "Red" "ALL"
        global:Update-Status "Public IP Check Failed." $true
    }
    $script:form.Cursor = [System.Windows.Forms.Cursors]::Default
}

# ==============================================================================
#  8. ULTIMATE THEMED UI BUILD
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
$pnlGroupGen.Size = New-Object System.Drawing.Size(240, 140) 
$pnlGroupGen.Location = New-Object System.Drawing.Point(10, 250)
global:Set-RoundedCorner $pnlGroupGen 15
global:Add-GroupBorder $pnlGroupGen $colorGroupBorder
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
    $btn.FlatAppearance.BorderSize = 0
    $btn.FlatAppearance.BorderColor = $BgColor # FIXED WHITE BORDER DISTURBANCE
    $btn.Size = New-Object System.Drawing.Size(220, 40) 
    $btn.Location = New-Object System.Drawing.Point(10, $Top); $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Add_GotFocus({ $btn.Parent.Focus() }) # Removes outline on click
    global:Set-RoundedCorner $btn 10
    $btn.Add_Click($Action)
    $Panel.Controls.Add($btn)
}

Add-SidebarButton $pnlGroupGen "Search / Reload Master" 40 $colorBtnGen { global:Search-Master }
Add-SidebarButton $pnlGroupGen "Download Prerequisite" 85 $colorBtnGen { Start-Process $Url_Blob; Start-Process $Url_GDrive }

# Sidebar Group 2: Diagnostics
$pnlGroupDiag = New-Object System.Windows.Forms.Panel
$pnlGroupDiag.Size = New-Object System.Drawing.Size(240, 185)
$pnlGroupDiag.Location = New-Object System.Drawing.Point(10, 410)
global:Set-RoundedCorner $pnlGroupDiag 15
global:Add-GroupBorder $pnlGroupDiag $colorGroupBorder
$sidebar.Controls.Add($pnlGroupDiag)

$lblDiag = New-Object System.Windows.Forms.Label
$lblDiag.Text = "Diagnostics"
$lblDiag.Font = $fontMenuBold; $lblDiag.ForeColor = $colorLblDiag
$lblDiag.AutoSize = $false; $lblDiag.Size = New-Object System.Drawing.Size(240, 20)
$lblDiag.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter; $lblDiag.Location = New-Object System.Drawing.Point(0, 10)
$pnlGroupDiag.Controls.Add($lblDiag)

Add-SidebarButton $pnlGroupDiag "Open System Logs" 40 $colorBtnDiag { if(Test-Path (global:Ensure-LogDir)){ Invoke-Item (global:Ensure-LogDir) } }
Add-SidebarButton $pnlGroupDiag "Check Public IP" 85 $colorBtnDiag { global:Check-PublicIP }
Add-SidebarButton $pnlGroupDiag "Run Diagnostics" 130 $colorBtnDiag { global:Run-PreFlightDiagnostics }

# Sidebar Group 3: System
$pnlGroupSys = New-Object System.Windows.Forms.Panel
$pnlGroupSys.Size = New-Object System.Drawing.Size(240, 275) 
$pnlGroupSys.Location = New-Object System.Drawing.Point(10, 615)
global:Set-RoundedCorner $pnlGroupSys 15
global:Add-GroupBorder $pnlGroupSys $colorGroupBorder
$sidebar.Controls.Add($pnlGroupSys)

$lblSystem = New-Object System.Windows.Forms.Label
$lblSystem.Text = "System"
$lblSystem.Font = $fontMenuBold; $lblSystem.ForeColor = $colorLblSys 
$lblSystem.AutoSize = $false; $lblSystem.Size = New-Object System.Drawing.Size(240, 20)
$lblSystem.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter; $lblSystem.Location = New-Object System.Drawing.Point(0, 10)
$pnlGroupSys.Controls.Add($lblSystem)

Add-SidebarButton $pnlGroupSys "License Verification" 40 $colorBtnSys { global:Show-LicenseVerification }
Add-SidebarButton $pnlGroupSys "Password Encryptor" 85 $colorBtnSys { global:Show-PasswordEncryptor }
Add-SidebarButton $pnlGroupSys "Remote Server Manager" 130 $colorBtnSys { global:Show-RemoteManager }
Add-SidebarButton $pnlGroupSys "Schedule Deployment" 175 ([System.Drawing.Color]::FromArgb(255, 60, 40, 100)) { global:Show-Scheduler }
Add-SidebarButton $pnlGroupSys "Exit Dashboard" 220 $colorBtnSys { $script:form.Close() }

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
global:Set-RoundedCorner $pnlTimerBadge 8
$contentPanel.Controls.Add($pnlTimerBadge)

$lblStatusTitle = New-Object System.Windows.Forms.Label
$lblStatusTitle.Text = "SYSTEM STATUS"
$lblStatusTitle.Font = $fontCleanBold; $lblStatusTitle.ForeColor = $colorTextMuted
$lblStatusTitle.AutoSize = $true; $lblStatusTitle.Location = New-Object System.Drawing.Point(15, 15)
$pnlTimerBadge.Controls.Add($lblStatusTitle)

$script:lblStatusVal = New-Object System.Windows.Forms.Label
$script:lblStatusVal.Text = "ONLINE"
$script:lblStatusVal.Font = $fontCleanVal; $script:lblStatusVal.ForeColor = $termGreen
$script:lblStatusVal.AutoSize = $true; $script:lblStatusVal.Location = New-Object System.Drawing.Point(120, 13)
$pnlTimerBadge.Controls.Add($script:lblStatusVal)

$lblUptimeTitle = New-Object System.Windows.Forms.Label
$lblUptimeTitle.Text = "SESSION TIME"
$lblUptimeTitle.Font = $fontCleanBold; $lblUptimeTitle.ForeColor = $colorTextMuted
$lblUptimeTitle.AutoSize = $true; $lblUptimeTitle.Location = New-Object System.Drawing.Point(15, 45)
$pnlTimerBadge.Controls.Add($lblUptimeTitle)

$script:lblSessionTimeVal = New-Object System.Windows.Forms.Label
$script:lblSessionTimeVal.Text = "00:00:00"
$script:lblSessionTimeVal.Font = $fontCleanVal; $script:lblSessionTimeVal.ForeColor = $termCyan
$script:lblSessionTimeVal.AutoSize = $true; $script:lblSessionTimeVal.Location = New-Object System.Drawing.Point(120, 43)
$pnlTimerBadge.Controls.Add($script:lblSessionTimeVal)

# HOST BADGE
$pnlHostBadge = New-Object System.Windows.Forms.Panel
$pnlHostBadge.Size = New-Object System.Drawing.Size(325, 80)
$pnlHostBadge.Location = New-Object System.Drawing.Point(625, 25)
$pnlHostBadge.BackColor = $colorCardBg
global:Set-RoundedCorner $pnlHostBadge 8
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

# --- BULLETPROOF "i" INFO BUTTON ---
$btnInfo = New-Object System.Windows.Forms.Button
$btnInfo.Text = "i"
$btnInfo.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$btnInfo.Size = New-Object System.Drawing.Size(30, 30)
$btnInfo.Location = New-Object System.Drawing.Point(280, 25) 
$btnInfo.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$btnInfo.BackColor = $colorBtnDiag
$btnInfo.ForeColor = $colorTextWhite
$btnInfo.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnInfo.FlatAppearance.BorderSize = 1
$btnInfo.FlatAppearance.BorderColor = $colorGroupBorder
$btnInfo.Cursor = [System.Windows.Forms.Cursors]::Hand

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
  Dashboard Version 8.42
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
$pnlHostBadge.Controls.Add($btnInfo)
$btnInfo.BringToFront()

# --- TAB CONTAINER ---
$tabContainer = New-Object System.Windows.Forms.Panel
$tabContainer.Size = New-Object System.Drawing.Size(920, 40)
$tabContainer.Location = New-Object System.Drawing.Point(30, 125)
$tabContainer.BackColor = $colorTabDeact
global:Set-RoundedCorner $tabContainer 20
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
$btnHelpDocs.Add_Click({ global:Show-HelpPrompt })
$tabContainer.Controls.Add($btnHelpDocs)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "? Refresh"
$btnRefresh.Size = New-Object System.Drawing.Size(200, 40)
$btnRefresh.Location = New-Object System.Drawing.Point(720, 0)
$btnRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnRefresh.FlatAppearance.BorderSize = 1 
$btnRefresh.FlatAppearance.BorderColor = $colorGroupBorder
$btnRefresh.BackColor = $colorTabDeact
$btnRefresh.ForeColor = $colorTextMuted; $btnRefresh.Font = $fontMenuBold
$btnRefresh.Cursor = [System.Windows.Forms.Cursors]::Hand
$btnRefresh.Add_Click({ global:Refresh-List; global:Update-Status "List Refreshed Successfully." })
$tabContainer.Controls.Add($btnRefresh)

$script:lblStatus = New-Object System.Windows.Forms.Label
$script:lblStatus.Text = "Status: Initializing..."
$script:lblStatus.Font = $fontSubHeader; $script:lblStatus.ForeColor = $colorAccentRed
$script:lblStatus.AutoSize = $true; $script:lblStatus.Location = New-Object System.Drawing.Point(33, 175)
$contentPanel.Controls.Add($script:lblStatus)

# --- VIEWS SETUP & DYNAMIC TABS ---
$script:pnlToolsWrapper = New-Object System.Windows.Forms.Panel
$script:pnlToolsWrapper.Location = New-Object System.Drawing.Point(30, 200)
$script:pnlToolsWrapper.Size = New-Object System.Drawing.Size(920, 630)
$script:pnlToolsWrapper.BackColor = [System.Drawing.Color]::Transparent
$contentPanel.Controls.Add($script:pnlToolsWrapper)
global:Enable-AdvancedDoubleBuffering $script:pnlToolsWrapper

$script:pnlTools = New-Object System.Windows.Forms.Panel
$script:pnlTools.Dock = "Fill"
$script:pnlTools.AutoScroll = $true
$script:pnlTools.BackColor = [System.Drawing.Color]::Transparent
$script:pnlToolsWrapper.Controls.Add($script:pnlTools)
global:Enable-AdvancedDoubleBuffering $script:pnlTools

$script:pnlConsole = New-Object System.Windows.Forms.Panel
$script:pnlConsole.Dock = "Fill"
$script:pnlConsole.BackColor = $colorConsoleBg
$script:pnlConsole.Padding = New-Object System.Windows.Forms.Padding(15) 
$script:pnlConsole.Visible = $false
$script:pnlToolsWrapper.Controls.Add($script:pnlConsole)

# The new Log Tab System
$script:pnlLogTabs = New-Object System.Windows.Forms.Panel
$script:pnlLogTabs.Dock = "Top"
$script:pnlLogTabs.Height = 35
$script:pnlConsole.Controls.Add($script:pnlLogTabs)

$script:pnlLogContent = New-Object System.Windows.Forms.Panel
$script:pnlLogContent.Dock = "Fill"
$script:pnlLogContent.Padding = New-Object System.Windows.Forms.Padding(0, 10, 0, 0)
if ($global:fadedWatermark) { 
    $script:pnlLogContent.BackgroundImage = $global:fadedWatermark
    $script:pnlLogContent.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Center
}
$script:pnlConsole.Controls.Add($script:pnlLogContent)

# Live Input Bar (Embedded in Log Content)
$global:pnlLiveInput = New-Object System.Windows.Forms.Panel
$global:pnlLiveInput.Dock = "Bottom"
$global:pnlLiveInput.Height = 45
$global:pnlLiveInput.BackColor = [System.Drawing.Color]::FromArgb(255, 40, 40, 50)
$global:pnlLiveInput.Visible = $false
$script:pnlConsole.Controls.Add($global:pnlLiveInput)

$lblLiveHint = New-Object System.Windows.Forms.Label
$lblLiveHint.Text = "LIVE SCRIPT INPUT:"
$lblLiveHint.ForeColor = $colorTextWhite
$lblLiveHint.Font = $fontCleanBold
$lblLiveHint.Location = New-Object System.Drawing.Point(10, 15)
$lblLiveHint.AutoSize = $true
$global:pnlLiveInput.Controls.Add($lblLiveHint)

$global:txtLiveInput = New-Object System.Windows.Forms.TextBox
$global:txtLiveInput.Location = New-Object System.Drawing.Point(140, 10)
$global:txtLiveInput.Size = New-Object System.Drawing.Size(600, 25)
$global:txtLiveInput.BackColor = [System.Drawing.Color]::FromArgb(255, 13, 13, 13)
$global:txtLiveInput.ForeColor = [System.Drawing.Color]::FromArgb(255, 240, 240, 240)
$global:txtLiveInput.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)
$global:pnlLiveInput.Controls.Add($global:txtLiveInput)

$global:btnSendLive = New-Object System.Windows.Forms.Button
$global:btnSendLive.Text = "SEND"
$global:btnSendLive.Location = New-Object System.Drawing.Point(755, 8)
$global:btnSendLive.Size = New-Object System.Drawing.Size(100, 30)
$global:btnSendLive.BackColor = $colorBtnDiag
$global:btnSendLive.ForeColor = $colorTextWhite
$global:btnSendLive.FlatStyle = "Flat"
$global:btnSendLive.FlatAppearance.BorderSize = 0
$global:btnSendLive.Font = $fontCleanBold
$global:btnSendLive.Cursor = "Hand"
global:Set-RoundedCorner $global:btnSendLive 5
$global:pnlLiveInput.Controls.Add($global:btnSendLive)

$script:pnlLogContent.BringToFront()
global:Build-LogTabs

# ==============================================================================
#  ASYNC TIMERS & POLLING
# ==============================================================================
$global:JobTimer = New-Object System.Windows.Forms.Timer
$global:JobTimer.Interval = 500 
$global:JobTimer.Add_Tick({
    try {
        if ($global:ActiveJobs.Count -gt 0) {
            $remainingJobs = @()
            foreach ($aj in $global:ActiveJobs) {
                if ($null -ne $aj.Job) {
                    $results = Receive-Job -Job $aj.Job -ErrorAction SilentlyContinue
                    if ($results) {
                        foreach ($res in $results) {
                            if ($res -match "^\[DASHBOARD_LIVE_PROMPT\]\|(.+)$") {
                                $batPath = $matches[1]
                                $global:PendingLivePrompts[$aj.Target] = @{ BatPath=$batPath; Cred=$aj.Cred }
                                global:Write-Terminal ">> SCRIPT PAUSED: Waiting for Live Input..." "Yellow" $aj.Target
                                if ($global:CurrentActiveTab -eq $aj.Target -or $global:CurrentActiveTab -eq "ALL") {
                                    $global:pnlLiveInput.Visible = $true
                                }
                            } elseif ($res -match "^\[BATCH_DETECTED\]\|(.+)$") {
                                $bat = $matches[1]
                                # FIX: Strictly skips secondary files during testing/pipelines
                                if ($bat -match "(?i)Instance Update|Secondary") {
                                    global:Write-Terminal ">> Skipping secondary batch file: $bat" "Yellow" $aj.Target
                                } else {
                                    global:Write-Terminal ">> Auto-executing primary batch: $bat" "Yellow" $aj.Target
                                    global:Launch-RemoteBat $aj.Target $aj.Cred $bat "Y" $aj.Name
                                }
                            } else {
                                global:Write-Terminal "[$($aj.Target)] $res" "Cyan" $aj.Target $res
                            }
                        }
                    }
                    if ($aj.Job.State -in 'Completed','Failed','Stopped') {
                        global:Write-Terminal "[$($aj.Target)] Execution completed." "Lime" $aj.Target
                        if ($global:LogTabs -and $global:LogTabs.ContainsKey($aj.Target)) {
                            if ($global:LogTabs[$aj.Target].Controls.ContainsKey("MainTabButton")) {
                                # FIX: Only change color or a small checkmark so we never overwrite the Close 'X' button text bounds
                                $global:LogTabs[$aj.Target].Controls["MainTabButton"].Text = "  $($aj.Target) ?"
                                $global:LogTabs[$aj.Target].Controls["MainTabButton"].ForeColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113)
                                if ($global:LogTabs[$aj.Target].Controls.ContainsKey("CloseTabButton")) {
                                    $global:LogTabs[$aj.Target].Controls["CloseTabButton"].BringToFront()
                                }
                            }
                        }
                        Remove-Job -Job $aj.Job -Force -ErrorAction SilentlyContinue
                    } else {
                        $remainingJobs += $aj
                    }
                } elseif ($null -ne $aj.LogPath) {
                    if (Test-Path $aj.LogPath) {
                        try {
                            $fs = [System.IO.File]::Open($aj.LogPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                            $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
                            $sr.BaseStream.Seek($aj.Position, [System.IO.SeekOrigin]::Begin) | Out-Null
                            while (($line = $sr.ReadLine()) -ne $null) {
                                global:Write-Terminal "SCHEDULER> $line" "Cyan" $aj.Target
                                if ($line -match "Scheduled Task Completed") { $aj.Status = "Completed" }
                            }
                            $aj.Position = $sr.BaseStream.Position
                            $sr.Close()
                            $fs.Close()
                        } catch {}
                    }
                    if ($aj.Status -eq "Completed") {
                        global:Write-Terminal "[$($aj.Target)] Scheduled Execution completed." "Lime" $aj.Target
                        if ($global:LogTabs -and $global:LogTabs.ContainsKey($aj.Target)) {
                            if ($global:LogTabs[$aj.Target].Controls.ContainsKey("MainTabButton")) {
                                $global:LogTabs[$aj.Target].Controls["MainTabButton"].Text = "  $($aj.Target) ?"
                                $global:LogTabs[$aj.Target].Controls["MainTabButton"].ForeColor = [System.Drawing.Color]::FromArgb(255, 46, 204, 113)
                                if ($global:LogTabs[$aj.Target].Controls.ContainsKey("CloseTabButton")) {
                                    $global:LogTabs[$aj.Target].Controls["CloseTabButton"].BringToFront()
                                }
                            }
                        }
                    } else {
                        $remainingJobs += $aj
                    }
                }
            }
            $global:ActiveJobs = $remainingJobs
        }
    } catch {}
})

$global:ScheduleTimer = New-Object System.Windows.Forms.Timer
$global:ScheduleTimer.Interval = 5000 
$global:ScheduleTimer.Add_Tick({
    try {
        foreach ($job in $global:ScheduledJobs) {
            if ($job.Status -eq "Pending" -and [datetime]::Now -ge $job.RunTime) {
                $job.Status = "Triggered"
                global:Execute-ScheduledJob $job
            }
        }
    } catch {}
})

$uiTimer = New-Object System.Windows.Forms.Timer 
$uiTimer.Interval = 1000 
$uiTimer.Add_Tick({
    try {
        if ($null -eq $script:sessionStart) { $script:sessionStart = [datetime]::Now }
        $ts = [datetime]::Now - $script:sessionStart
        if ($script:lblSessionTimeVal) {
            $script:lblSessionTimeVal.Text = "{0:00}:{1:00}:{2:00}" -f $ts.Hours, $ts.Minutes, $ts.Seconds
        }
    } catch {}
})

# --- COPYRIGHT WATERMARK FIX FOR EXE ---
$lblCopyright = New-Object System.Windows.Forms.Label
$lblCopyright.Text = "© 2026, ProPhoenix Corporation, All Rights Reserved"
$lblCopyright.Font = $script:Font_Copyright
$lblCopyright.ForeColor = $colorTextMuted
$lblCopyright.Location = New-Object System.Drawing.Point(0, 850)
$lblCopyright.Size = New-Object System.Drawing.Size(980, 30)
$lblCopyright.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblCopyright.BackColor = [System.Drawing.Color]::Transparent
$lblCopyright.Image = $null 
$contentPanel.Controls.Add($lblCopyright)
$lblCopyright.BringToFront()

# ==============================================================================
#  FINAL STARTUP TRIGGERS (ABSOLUTE BOTTOM)
# ==============================================================================
if ($null -ne $global:btnSendLive) {
    $global:btnSendLive.Add_Click({
        $inputStr = if ($global:txtLiveInput.Text) { $global:txtLiveInput.Text } else { "Y" }
        $global:txtLiveInput.Text = ""; $global:pnlLiveInput.Visible = $false
        $activeTarget = $global:CurrentActiveTab
        if ($activeTarget -ne "ALL" -and $global:PendingLivePrompts.ContainsKey($activeTarget)) {
            $sig = $global:PendingLivePrompts[$activeTarget].BatPath
            Invoke-Command -ComputerName $activeTarget -Credential $global:PendingLivePrompts[$activeTarget].Cred -ScriptBlock {
                param($path, $text)
                Set-Content -Path $path -Value $text -Force
            } -ArgumentList $sig, $inputStr -AsJob | Out-Null
            $global:PendingLivePrompts.Remove($activeTarget)
        } elseif ($activeTarget -eq "ALL") {
            foreach ($key in $global:PendingLivePrompts.Keys) {
                $sig = $global:PendingLivePrompts[$key].BatPath
                Invoke-Command -ComputerName $key -Credential $global:PendingLivePrompts[$key].Cred -ScriptBlock {
                    param($path, $text)
                    Set-Content -Path $path -Value $text -Force
                } -ArgumentList $sig, $inputStr -AsJob | Out-Null
            }
            $global:PendingLivePrompts.Clear()
        }
    })
}

if ($null -ne $script:btnTabScripts) {
    $script:btnTabScripts.Add_Click({
        $script:form.SuspendLayout()
        $script:pnlConsole.Visible = $false
        $script:pnlTools.Visible = $true
        $script:btnTabScripts.BackColor = $colorTabActive; $script:btnTabScripts.ForeColor = $colorTextWhite
        $script:btnTabLogs.BackColor = $colorTabDeact; $script:btnTabLogs.ForeColor = $colorTextMuted
        $script:form.ResumeLayout($true)
        $script:pnlToolsWrapper.Invalidate($true)
    })
}

if ($null -ne $script:btnTabLogs) {
    $script:btnTabLogs.Add_Click({ global:Show-ExecutionLogs })
}

if ($null -ne $script:form) {
    $script:form.Add_Shown({ 
        try {
            $script:form.Activate()
            global:Write-Terminal "Initializing startup sequence..." "Cyan" "ALL"
            [System.Windows.Forms.Application]::DoEvents()
            
            $Url_GitHub = "https://github.com/gobikrish90/MyScripts/raw/main/Phoenix%20Installation%20Master.zip"
            $DownloadUrls = @($Url_Blob, $Url_GDrive, $Url_GitHub)
            $TempDir = "C:\PnxTemp"
            
            if (Test-Path $InstallBase) {
                global:Write-Terminal "Old payload detected. Removing old scripts..." "Yellow" "ALL"
                Remove-Item -Path $InstallBase -Recurse -Force -ErrorAction SilentlyContinue
            }
            if (-not (Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir -Force | Out-Null }
            
            $uniqueId = Get-Random -Minimum 1000 -Maximum 9999
            $TempZip = Join-Path $TempDir "Phoenix Installation Master_$uniqueId.zip"
            
            global:Write-Terminal "Downloading latest payload..." "White" "ALL"
            global:Update-Status "Downloading latest scripts..."
            [System.Windows.Forms.Application]::DoEvents()
            
            $downloadSuccess = $false
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            
            foreach ($url in $DownloadUrls) {
                if ([string]::IsNullOrWhiteSpace($url)) { continue }
                try {
                    global:Write-Terminal "Attempting download from secure source..." "LightGray" "ALL"
                    Invoke-WebRequest -Uri $url -OutFile $TempZip -UseBasicParsing -TimeoutSec 15
                    $downloadSuccess = $true
                    global:Write-Terminal "Download completed successfully." "Lime" "ALL"
                    break
                } catch {
                    global:Write-Terminal "Source failed, trying next availability zone..." "Yellow" "ALL"
                }
            }
            
            if (-not $downloadSuccess) {
                global:Write-Terminal "All automatic download sources failed." "Red" "ALL"
                global:Update-Status "Download Failed. Attempting local search..." $true
                global:Search-Master
                return
            }
            
            global:Write-Terminal "Extracting new payload..." "White" "ALL"
            global:Update-Status "Extracting scripts..."
            [System.Windows.Forms.Application]::DoEvents()
            
            try {
                Expand-Archive -Path $TempZip -DestinationPath $InstallBase -Force
                Remove-Item -Path $TempZip -Force -ErrorAction SilentlyContinue
                global:Write-Terminal "Extraction 100% complete and archive deleted." "Lime" "ALL"
            } catch {
                global:Write-Terminal "Extraction failed: $_" "Red" "ALL"
                global:Update-Status "Extraction Error." $true
                return
            }

            $script:CurrentToolPath = $InstallBase
            $NestedDir = Get-ChildItem -Path $InstallBase -Directory | Where-Object { $_.Name -match "Phoenix Installation Master" -or $_.Name -match "main" } | Select-Object -First 1
            if ($NestedDir) { $script:CurrentToolPath = $NestedDir.FullName }
            
            global:Set-FolderPermissions $script:CurrentToolPath $false
            global:Unblock-ExtractedFiles $script:CurrentToolPath $false
            
            $script:ToolsLoaded = $true
            global:Refresh-List
            global:Update-Status "Master Loaded Successfully."
            global:Write-Terminal "Dashboard Armed and Operational." "Lime" "ALL"
            
            if ($null -ne $global:JobTimer) { $global:JobTimer.Start() }
            if ($null -ne $global:ScheduleTimer) { $global:ScheduleTimer.Start() }
            if ($null -ne $uiTimer) { $uiTimer.Start() }
        } catch {
            global:Write-Terminal "FATAL STARTUP ERROR: $_" "Red" "ALL"
            global:Update-Status "Startup Failed." $true
        }
    })

    if ($null -ne $preloader) { $preloader.Close(); $preloader.Dispose() }
    [void]$script:form.ShowDialog()
} else { Write-Host "CRITICAL ERROR: Form not initialized. Review script brackets." -ForegroundColor Red; pause }
