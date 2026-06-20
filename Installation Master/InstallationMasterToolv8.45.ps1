<#
.SYNOPSIS
    Installation Master Dashboard v8.45 (Enterprise Deep-Hunt Framework)
 #>

# ==============================================================================
#  0. INSTANT BACKGROUND CONSOLE HIDE
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

Write-Host "[INIT] Booting Enterprise Dashboard v12.0..." -ForegroundColor Cyan

# ==============================================================================
#  1. ADMIN ENFORCEMENT
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

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

[System.Windows.Forms.Application]::EnableVisualStyles()

# ==============================================================================
#  2. GLOBAL PALETTE & VARIABLES
# ==============================================================================
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

$colorLblGen  = [System.Drawing.Color]::FromArgb(255, 240, 100, 100)
$colorBtnGen  = [System.Drawing.Color]::FromArgb(255, 80, 35, 40)    
$colorLblDiag = [System.Drawing.Color]::FromArgb(255, 100, 200, 255)
$colorBtnDiag = [System.Drawing.Color]::FromArgb(255, 30, 70, 110)   
$colorLblSys  = [System.Drawing.Color]::FromArgb(255, 180, 130, 250)
$colorBtnSys  = [System.Drawing.Color]::FromArgb(255, 55, 35, 80)    
$termGreen    = [System.Drawing.Color]::FromArgb(255, 46, 204, 113) 
$termCyan     = [System.Drawing.Color]::Cyan

$fontHeader    = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$fontSubHeader = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
$fontMenuBold  = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$fontTerminal  = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
$fontCleanBold = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
$fontCleanVal  = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)
$fontRowText   = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold) 
$script:Font_Copyright = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Regular)

$Url_GDrive   = "https://drive.google.com/uc?export=download&id=10RxuJaWwqR1S6lbkjL0-_AXddCwOARYI"
$Url_Blob     = ""
$ZipNamePattern = "Phoenix Installation Master*.zip"
$InstallBase    = "C:\pnxtemp\Phoenix Installation Master"
$script:CurrentToolPath = $InstallBase 
$script:ToolsLoaded = $false
$global:AvailableScripts = @()

$global:ActiveJobs = @()
$global:RemoteTargets = @() 
$global:ScheduledJobs = @()
$script:SavedCredsList = @()
$script:SavedPipelineList = @()
$global:LogTabs = @{}
$global:LogBoxes = @{}
$global:PendingLivePrompts = @{}
$global:CurrentActiveTab = "ALL"
[datetime]$script:sessionStart = [datetime]::Now

$logoPath = Join-Path -Path $ScriptPath -ChildPath "logo.png"
$global:fadedWatermark = $null

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
    } catch {}
}

# ==========================================================================
# PASTE YOUR FULL 2000-LINE CUSTOM GUIDE TEXT HERE
# ==========================================================================
$script:GuideText = @"
ProPhoenix Installation Dashboard Guide
1. Run Dashboard
2. Select target scripts
3. Await output.
[... PASTE REMAINDER OF YOUR 2000-LINE MANUAL HERE ...]
"@

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
        if (-not [string]::IsNullOrWhiteSpace($company)) { $AgencyDomain = $company }
    }
    if ($AgencyDomain -eq "Unknown" -and $env:USERDOMAIN) { $AgencyDomain = $env:USERDOMAIN }
} catch {
    if ($env:USERDOMAIN) { $AgencyDomain = $env:USERDOMAIN }
}
if ($AgencyDomain -ne "Unknown") {
    $words = $AgencyDomain.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
    if ($words.Count -ge 4) { $AgencyDomain = $words[0] + " " + $words[1] }
}

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

function global:Add-GroupBorder($Panel, $Color) {
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
    foreach ($t in $global:RemoteTargets) { global:Add-LogTab $t.HostName }
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
    } catch {}
}

function global:Unblock-ExtractedFiles($path, $silent=$false) {
    if (-not $silent) { global:Write-Terminal "Unblocking script files..." "Yellow" "LOCAL" }
    [System.Windows.Forms.Application]::DoEvents()
    try { 
        Get-ChildItem -Path $path -Recurse -File | Unblock-File -ErrorAction SilentlyContinue 
        if (-not $silent) { global:Write-Terminal "Files successfully unblocked." "Lime" "LOCAL" }
    } catch {}
}

function global:Test-ZipValidity($ZipPath) { try { [System.IO.Compression.ZipFile]::OpenRead($ZipPath).Dispose(); return $true } catch { return $false } }

function global:Get-FriendlyName($fileName) {
    if ($fileName -match "32bitfalse") { return "App Pool Set False" }
    if ($fileName -match "SessionClear") { return "SVR Session Clear" }
    if ($fileName -match "SQLMemory") { return "SQL Memory Set" }
    if ($fileName -match "InstanceVerification") { return "Instance Update Verification" }
    if ($fileName -match "LaunchShortcuts") { return "Clients Auto Update" }
    if ($fileName -match "Autodbsync" -or $fileName -match "DB Utility Dashboard") { return "DB Sync Tool" }
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
        default { return 50 } 
    }
}

# ==============================================================================
#  ENTERPRISE DEEP-HUNT EXECUTION ENGINE
# ==============================================================================

function global:Launch-File($path, $friendlyName, $PipelineInputs="Y", $IsPipeline=$false) {
    if (-not (Test-Path $path) -and $global:RemoteTargets.Count -eq 0) { global:Write-Terminal "EXECUTION HALTED: File not found." "Red" "LOCAL"; return }
    $workDir = Split-Path -Path $path -Parent
    
    global:Show-ExecutionLogs
    [System.Windows.Forms.Application]::DoEvents()

    if ($global:RemoteTargets.Count -gt 0) {
        global:Write-Terminal ">>> Queuing Asynchronous Remote Job on $($global:RemoteTargets.Count) server(s)..." "Cyan" "ALL"
        global:Update-Status "Running Remote Job(s)..."

        try {
            $escapedToolPath = [regex]::Escape($script:CurrentToolPath)
            $remotePath = $path -ireplace $escapedToolPath, "C:\PnxTemp\RemotePayload"
            $remoteWorkDir = Split-Path $remotePath -Parent

            foreach ($t in $global:RemoteTargets) {
                if ($global:LogTabs -and $global:LogTabs.ContainsKey($t.HostName)) {
                    if ($global:LogTabs[$t.HostName].Controls.ContainsKey("MainTabButton")) {
                        $global:LogTabs[$t.HostName].Controls["MainTabButton"].Text = "  $($t.HostName) (Running)"
                        $global:LogTabs[$t.HostName].Controls["MainTabButton"].ForeColor = [System.Drawing.Color]::Cyan
                    }
                }

                $uncWorkDir = "\\$($t.HostName)\C$\PnxTemp\RemotePayload"
                global:Write-Terminal ">> Synchronizing payload to remote server..." "LightGray" $t.HostName
                if (-not (Test-Path $uncWorkDir)) { New-Item -ItemType Directory -Path $uncWorkDir -Force | Out-Null }
                Copy-Item -Path "$workDir\*" -Destination $uncWorkDir -Recurse -Force -ErrorAction SilentlyContinue
                
                $sb = {
                    param($rPath, $rDir, $uInput, $isPipe, $fName)
                    if (-not (Test-Path $rPath)) { Write-Output ">> CRITICAL ERROR: Remote script missing at $rPath"; return }
                    
                    Set-Location $rDir
                    $startTime = Get-Date
                    
                    # 1. Patch PS1 to prevent detached WinRM deadlocks and GUI Handle crashes
                    if ($rPath -match "\.ps1$") {
                        try {
                            $psRaw = Get-Content $rPath -Raw
                            $psRaw = $psRaw -replace '(?im)^\s*(Start-Process|Invoke-Item).*?\.bat.*$', 'Write-Output ">> [SYS] Detached bat launch blocked. Passing control to Deep Hunt."'
                            $psRaw = $psRaw -replace '(?im)^\s*\$graphics\.CopyFromScreen.*$', 'Write-Output ">> [SYS] Suppressed headless GUI screenshot command."'
                            Set-Content -Path $rPath -Value $psRaw -Force
                        } catch {}
                    }
                    
                    # 2. Setup Answer File
                    $tmpFile = Join-Path $rDir "auto_answer.txt"
                    $inpsArray = $uInput -split ',' | ForEach-Object { $_.Trim() }
                    $content = ""
                    foreach ($i in $inpsArray) { $content += "$i`r`n" }
                    for ($x=0; $x -lt 50; $x++) { $content += "Y`r`n" }
                    Set-Content -Path $tmpFile -Value $content

                    # 3. Native Execute and Stream
                    $proc = New-Object System.Diagnostics.Process
                    $proc.StartInfo.FileName = "cmd.exe"
                    if ($rPath -match "\.ps1$") {
                        $proc.StartInfo.Arguments = "/c `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$rPath`" < `"$tmpFile`" 2>&1`""
                    } else {
                        $proc.StartInfo.Arguments = "/c `"`"$rPath`"`" < `"$tmpFile`" 2>&1"
                    }
                    
                    $proc.StartInfo.RedirectStandardOutput = $true
                    $proc.StartInfo.RedirectStandardInput = $true
                    $proc.StartInfo.RedirectStandardError = $false
                    $proc.StartInfo.UseShellExecute = $false
                    $proc.StartInfo.CreateNoWindow = $true
                    $proc.Start() | Out-Null
                    
                    $signalFile = "C:\PnxTemp\input_signal.txt"
                    if (Test-Path $signalFile) { Remove-Item $signalFile -Force }

                    $lineBuffer = ""
                    $buffer = New-Object char[] 1
                    $task = $null

                    while (-not $proc.HasExited) {
                        if ($null -eq $task -or $task.IsCompleted) {
                            if ($null -ne $task) {
                                $readCount = $task.Result
                                if ($readCount -gt 0) {
                                    $ch = $buffer[0]
                                    $lineBuffer += $ch
                                    if ($ch -eq "`n") {
                                        Write-Output $lineBuffer.TrimEnd("`r`n")
                                        $lineBuffer = ""
                                    }
                                }
                            }
                            if (-not $proc.StandardOutput.EndOfStream) {
                                $task = $proc.StandardOutput.ReadAsync($buffer, 0, 1)
                            }
                        } else {
                            Start-Sleep -Milliseconds 50
                            if ($lineBuffer.Length -gt 0 -and $lineBuffer -match "(?i)(\[Y/N\]|\?|proceed|Enter option|press any key|:\s*$)") {
                                Write-Output $lineBuffer
                                if ($isPipe -or $fName -match "(?i)Test/Demo Hotfix|DB Sync Tool") {
                                    if ($lineBuffer -match "(?i)secondary|instance update|continue") {
                                        Write-Output ">> [SYS] Auto-skipping secondary prompt for Pipeline/Test..."
                                        $proc.StandardInput.WriteLine("N")
                                    } elseif ($lineBuffer -match "(?i)generate|product list") {
                                        Write-Output ">> [SYS] Auto-generating product list..."
                                        $proc.StandardInput.WriteLine("Y")
                                    } else {
                                        Write-Output ">> [SYS] Auto-proceeding prompt for Pipeline/Test..."
                                        $proc.StandardInput.WriteLine("Y")
                                    }
                                } else {
                                    Write-Output "[DASHBOARD_LIVE_PROMPT]|$signalFile"
                                    $waitLimit = 0
                                    while (-not (Test-Path $signalFile) -and -not $proc.HasExited -and $waitLimit -lt 1200) { Start-Sleep -Milliseconds 500; $waitLimit++ }
                                    if (Test-Path $signalFile) {
                                        $ans = (Get-Content $signalFile -Raw).Trim()
                                        Remove-Item $signalFile -Force
                                        $proc.StandardInput.WriteLine($ans)
                                    } else { $proc.StandardInput.WriteLine("Y") }
                                }
                                $lineBuffer = ""
                            }
                        }
                    }
                    if ($lineBuffer) { Write-Output $lineBuffer }
                    while (-not $proc.StandardOutput.EndOfStream) { Write-Output $proc.StandardOutput.ReadLine() }

                    Start-Sleep -Seconds 3 

                    # 4. DEEP SYSTEM HUNT: Find batch files generated ANYWHERE in PnxTemp
                    Write-Output ">> [SYS] Scanning remote environment for generated batch payloads..."
                    $searchPaths = @(
                        $rDir,
                        "C:\PnxTemp",
                        "C:\Program Files (x86)\ProPhoenix\PnxTemp",
                        "C:\Program Files\ProPhoenix\PnxTemp"
                    )
                    
                    $foundBats = @()
                    foreach ($sp in $searchPaths) {
                        if (Test-Path $sp) {
                            $foundBats += Get-ChildItem -Path $sp -Filter "*.bat" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.CreationTime -ge $startTime }
                        }
                    }
                    
                    if ($foundBats) {
                        $foundBats = $foundBats | Select-Object -Unique | Sort-Object CreationTime -Descending
                        foreach ($bat in $foundBats) {
                            if ($bat.Name -match "(?i)Update\(BS\)|Secondary|Instance") {
                                Write-Output ">> [SYS] STRICT BLOCK: Destroyed secondary batch file: $($bat.FullName)"
                                Remove-Item $bat.FullName -Force -ErrorAction SilentlyContinue
                            } else {
                                Write-Output ">> [SYS] DASHBOARD INTERCEPT: Auto-executing Primary Batch: $($bat.FullName)"
                                & cmd.exe /c "`"$($bat.FullName)`" < `"$tmpFile`" 2>&1" | ForEach-Object { Write-Output "BATCH> $_" }
                            }
                        }
                    }

                    Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue
                    
                    # 5. File Sync
                    $remoteLoadsDir = "C:\PnxTemp\RemotePayloads"
                    if (-not (Test-Path $remoteLoadsDir)) { New-Item -ItemType Directory -Path $remoteLoadsDir -Force | Out-Null }
                    Get-ChildItem -Path $rDir -Filter "*.png" -Recurse -ErrorAction SilentlyContinue | Copy-Item -Destination $remoteLoadsDir -Force -ErrorAction SilentlyContinue
                    Get-ChildItem -Path $rDir -Filter "*.jpg" -Recurse -ErrorAction SilentlyContinue | Copy-Item -Destination $remoteLoadsDir -Force -ErrorAction SilentlyContinue
                    if (Test-Path "$rDir\Printlog") { Copy-Item -Path "$rDir\Printlog\*" -Destination $remoteLoadsDir -Recurse -Force -ErrorAction SilentlyContinue }
                    
                    Write-Output ">> [SYS] Base script sync complete."
                }

                $job = Invoke-Command -ComputerName $t.HostName -Credential $t.Credential -ScriptBlock $sb -ArgumentList $remotePath, $remoteWorkDir, $PipelineInputs, $IsPipeline, $friendlyName -AsJob
                $global:ActiveJobs += [PSCustomObject]@{ Name = $friendlyName; Target = $t.HostName; Cred = $t.Credential; Job = $job }
            }
        } catch {
            global:Write-Terminal "REMOTE EXECUTION QUEUE FAILED: $_" "Red" "ALL"
            global:Update-Status "Remote Queue Failed." $true
        }
    } else {
        global:Switch-LogTab "LOCAL"
        global:Write-Terminal ">>> Launching Locally: $friendlyName" "White" "LOCAL"
        global:Update-Status "Script launched locally."
        try {
            if ($path -match "\.bat$") { Start-Process "cmd.exe" -ArgumentList "/c", "`"$path`"" -WorkingDirectory $workDir } 
            elseif ($path -match "Minimal Downtime") { Start-Process "powershell_ise.exe" -ArgumentList "-NoProfile", "-File", "`"$path`"" -WorkingDirectory $workDir } 
            else { Start-Process "powershell.exe" -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$path`"" -WorkingDirectory $workDir }
        } catch { global:Write-Terminal "CRITICAL LAUNCH FAILURE: $_" "Red" "LOCAL" }
    }
}

# ==========================================================================
#  PIPELINE ORCHESTRATOR ENGINE
# ==========================================================================
function global:Execute-Pipeline($appTarget, $dbTarget, $sqlU, $sqlP, $sqlI, $envTarget) {
    $global:RemoteTargets = @($appTarget, $dbTarget)
    global:Build-LogTabs
    global:Show-ExecutionLogs
    
    $appScript = $global:AvailableScripts | Where-Object { $_.Friendly -match "(?i)Test/Demo Hotfix" } | Select-Object -First 1

    if (-not $appScript) {
        global:Write-Terminal "CRITICAL PIPELINE ERROR: Missing 'Test/Demo Hotfix' script in payload." "Red" "ALL"
        return
    }

    # --- STAGE 1: INJECT AND EXECUTE CUSTOM DB SYNC ENGINE ---
    global:Write-Terminal "--- PIPELINE [STAGE 1]: Injecting Native DB Sync Engine ---" "Cyan" $dbTarget.HostName
    
    # Format the SQL Server String
    $sqlServerStr = if ($sqlI -eq "MSSQLSERVER" -or -not $sqlI) { $dbTarget.HostName } else { "$($dbTarget.HostName)\$sqlI" }
    
    # FIX: Using single-quotes (@' ... '@) for the outer string. The closing '@ MUST be flush left!
    $dbSyncCode = @'
param($Server, $User, $Pass, $Environment)
try {
    Write-Output ">> [SYS] ? INITIATING HOTFIX AUTO-SYNC ($Environment)..."

    $SyncRoot = $null
    $Paths = @("ProPhoenix\Server Application Manager\AppReg_Main.xml", "Program Files (x86)\ProPhoenix\Server Application Manager\AppReg_Main.xml", "Program Files\ProPhoenix\Server Application Manager\AppReg_Main.xml")
    foreach ($d in (Get-PSDrive -PSProvider FileSystem).Root) {
        foreach ($sub in $Paths) {
            $p = Join-Path $d $sub
            if (Test-Path $p -ErrorAction SilentlyContinue) {
                $xml = [xml](Get-Content $p)
                $app = $xml.PhoenixApplications.AppReg | Where-Object { $_.AppPath -like "*Database Utility*" -and $_.AppPath -notlike "*CodeBook*" }
                if ($app) { $SyncRoot = Join-Path $app.AppPath "DB Sync"; break }
            }
        }
        if ($SyncRoot) { break }
    }
    if (-not $SyncRoot) { throw "Could not locate ProPhoenix Database Utility path." }
    Write-Output ">> [SYS]   ? Found Utility: $SyncRoot"

    $cs = "Server=$Server;Database=master;User Id=$User;Password='$($Pass.Replace("'", "''"))';Connection Timeout=15"
    $cn = New-Object System.Data.SqlClient.SqlConnection($cs)
    $cn.Open()
    $da = New-Object System.Data.SqlClient.SqlDataAdapter("SELECT Name FROM sys.databases WHERE database_id>4 AND Name NOT IN ('master','model','msdb','tempdb','ReportServer') ORDER BY Name", $cn)
    $ds = New-Object System.Data.DataSet; $da.Fill($ds) | Out-Null
    
    $groupedDBs = @{}
    foreach ($row in $ds.Tables[0].Rows) {
        $db = $row.Name
        $IsTrain = ($db -match "Tr" -or $db -match "Train")
        $IsTest = ($db -match "Test" -and -not $IsTrain) 
        $IsMaster = ($db -match "Master")

        if ($Environment -eq "Live" -and $IsTest) { continue } 
        if ($Environment -eq "Test" -and -not $IsTest -and -not $IsMaster) { continue }

        $Folder = "None"
        if ($db -match "DW") { $Folder = "Police DW" } 
        elseif ($db -match "CSP") { $Folder = if($db -match "Fire") { "Fire CSP" } else { "Police CSP" } } 
        elseif ($db -match "Master") { $Folder = "Phoenix Master" } 
        elseif ($db -match "IA") { $Folder = "IA" } 
        elseif ($db -match "Fire") { $Folder = "Fire" } 
        elseif ($db -match "Police" -or $db -match "\d+$" -or $db -match "Demo$") { $Folder = "Police" }
        
        if ($Folder -ne "None") {
            if (-not $groupedDBs.ContainsKey($Folder)) { $groupedDBs[$Folder] = @() }
            $groupedDBs[$Folder] += $db
        }
    }

    $wshell = New-Object -ComObject wscript.shell
    $safeKeys = @()
    foreach ($k in $groupedDBs.Keys) { $safeKeys += $k }
    $sortedFolders = $safeKeys | Sort-Object { if ($_ -eq 'Phoenix Master') { 0 } else { 1 } }

    foreach ($F in $sortedFolders) {
        $dbList = $groupedDBs[$F] -join ";"
        $WD = Join-Path $SyncRoot $F
        $XmlPath = Join-Path $WD "PnxAutoNewDBSyn.xml"

        Write-Output ">> [SYS] ? Processing Group [$F]"
        Write-Output ">> [SYS]   Targets: $dbList"

        if (-not (Test-Path Join-Path $WD "PnxDBSync.exe")) { Write-Output ">> [SYS]    ! Skipped: Missing EXE in $WD"; continue }

        foreach ($D in $groupedDBs[$F]) {
            try {
                $killCmd = $cn.CreateCommand()
                $killCmd.CommandText = "IF DB_ID('$D') IS NOT NULL BEGIN DECLARE @k1 varchar(8000) = ''; SELECT @k1 = @k1 + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$D'); EXEC(@k1); END"
                $killCmd.ExecuteNonQuery() | Out-Null
                $tempDb = "${D}PnxDBSync"
                $killCmd.CommandText = "IF DB_ID('$tempDb') IS NOT NULL BEGIN DECLARE @k2 varchar(8000) = ''; SELECT @k2 = @k2 + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$tempDb'); EXEC(@k2); EXEC('ALTER DATABASE [$tempDb] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$tempDb];'); END"
                $killCmd.ExecuteNonQuery() | Out-Null
            } catch {}
        }
        Start-Sleep -Seconds 2

        if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }

        # FIX: Converted nested XML block to a standard string
        $XmlString = "<?xml version=`"1.0`" encoding=`"utf-8`" ?>`r`n<PnxPakager>`r`n    <SourceServer>`r`n        <IPAddress>$Server</IPAddress>`r`n        <DBName>$dbList</DBName>`r`n        <UserName>$User</UserName>`r`n        <Password>$Pass</Password>`r`n        <JurisID>1000</JurisID>`r`n        <State>MA</State>`r`n        <JurisName>ProPhoenix</JurisName>`r`n        <JurisAlias>PNX</JurisAlias>`r`n        <SyncType>3</SyncType>`r`n    </SourceServer>`r`n</PnxPakager>"
        
        [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))

        $SyncProc = Start-Process (Join-Path $WD "PnxDBSync.exe") -WorkingDirectory $WD -WindowStyle Normal -PassThru
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $promptHandled = $false
        
        while (-not $SyncProc.HasExited) {
            Start-Sleep -Milliseconds 250
            if (-not $promptHandled -and $stopwatch.Elapsed.TotalSeconds -gt 3 -and $stopwatch.Elapsed.TotalSeconds -lt 20) {
                try { if ($wshell.AppActivate($SyncProc.Id)) { Start-Sleep -Milliseconds 100; $wshell.SendKeys("Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("%Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("{ENTER}"); $promptHandled = $true; Write-Output ">> [SYS]    > Auto-Answered Upgrade Prompt." } } catch {}
            }
        }
        $stopwatch.Stop()
        
        if ($SyncProc.ExitCode -eq 0) { Write-Output ">> [SYS]    ? Batch Sync Completed Successfully" } 
        else { Write-Output ">> [SYS]    ? Batch Sync Process Failed! (Exit Code: $($SyncProc.ExitCode))" }

        if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
    }
    $cn.Close()
    Write-Output ">> [SYS] ? AUTO-SYNC PIPELINE COMPLETE."
} catch {
    Write-Output ">> [SYS] ? CRITICAL ERROR: $($_.Exception.Message)"
}
'@

    # Write this script natively into the local temp folder and execute it using the Dashboard's Live Log Infrastructure
    if (-not (Test-Path "C:\PnxTemp")) { New-Item -ItemType Directory -Path "C:\PnxTemp" -Force | Out-Null }
    
    $dbGenPath = "C:\PnxTemp\Auto_DB_Sync_Injected.ps1"
    Set-Content -Path $dbGenPath -Value $dbSyncCode -Force
    
    $dbWrapper = "C:\PnxTemp\Run_DB_Sync.bat"
    $batCode = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$dbGenPath`" `"$sqlServerStr`" `"$sqlU`" `"$sqlP`" `"$envTarget`""
    Set-Content -Path $dbWrapper -Value $batCode -Force

    global:Write-Terminal ">> Launching Injected DB Sync Tool (Live Stream Armed)..." "Yellow" $dbTarget.HostName
    $global:RemoteTargets = @($dbTarget)
    
    # Push using Launch-File to capture the exact live stream output back to the specific Tab
    global:Launch-File $dbWrapper "Auto DB Sync Tool" "Y" $true

    # --- STAGE 2: APP HOTFIX ---
    global:Write-Terminal "--- PIPELINE [STAGE 2]: Injecting App Server Configuration ---" "Cyan" $appTarget.HostName
    Invoke-Command -ComputerName $appTarget.HostName -Credential $appTarget.Credential -ScriptBlock {
        if (-not (Test-Path "C:\PnxTemp")) { New-Item -ItemType Directory -Path "C:\PnxTemp" -Force | Out-Null }
        Set-Content -Path "C:\PnxTemp\Pipeline_Active.flag" -Value "True" -Force
        
        # INJECT THE OVERRIDE FLAGS: Explicitly forces generation of product list and suppresses secondary update
        Set-Content -Path "C:\PnxTemp\Hotfix_AutoConfig.ini" -Value "GenerateProductList=True`r`nSkipSecondary=True`r`nAutoProceed=True" -Force
    } -ErrorAction SilentlyContinue

    global:Write-Terminal ">> Launching Test/Demo Hotfix (Live Stream Armed)..." "Yellow" $appTarget.HostName
    $global:RemoteTargets = @($appTarget)
    global:Launch-File $appScript.FullName $appScript.Friendly "Y,Y,Y" $true

    $global:RemoteTargets = @($appTarget, $dbTarget)
    global:Write-Terminal "--- PIPELINE ORCHESTRATION DISPATCHED ---" "Lime" "ALL"
}

# ==========================================================================
#  7. CORE DASHBOARD MENUS & DIALOGS
# ==========================================================================
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
        $SearchLocations = @()
        foreach ($drive in [System.IO.DriveInfo]::GetDrives() | Where-Object {$_.DriveType -eq 'Fixed'}) {
            $SearchLocations += @{ Path = $drive.RootDirectory.FullName; Recurse = $true }
        }

        foreach ($loc in $SearchLocations) {
            $dir = $loc.Path
            if ($dir -and (Test-Path $dir)) {
                global:Write-Terminal "Scanning System Drive: $dir..." "LightGray" "ALL"
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

function global:Show-LicenseVerification {
    $licForm = New-Object System.Windows.Forms.Form
    $licForm.Text = "License Verification Dashboard"
    $licForm.Size = New-Object System.Drawing.Size(1000, 750)
    $licForm.StartPosition = "CenterParent"
    $licForm.BackColor = [System.Drawing.Color]::FromArgb(255, 11, 19, 43)
    $licForm.ForeColor = [System.Drawing.Color]::White
    $licForm.FormBorderStyle = "FixedDialog"
    $licForm.MaximizeBox = $false

    $btnOld = New-Object System.Windows.Forms.Button
    $btnOld.Text = "? OLD LICENSE DATA"
    $btnOld.Location = New-Object System.Drawing.Point(30, 30); $btnOld.Size = New-Object System.Drawing.Size(920, 40)
    $btnOld.BackColor = [System.Drawing.Color]::FromArgb(255, 28, 37, 65); $btnOld.ForeColor = [System.Drawing.Color]::FromArgb(255, 0, 229, 255)
    $btnOld.FlatStyle = "Flat"; $btnOld.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
    $licForm.Controls.Add($btnOld)

    $txtOld = New-Object System.Windows.Forms.TextBox
    $txtOld.Location = New-Object System.Drawing.Point(30, 75); $txtOld.Size = New-Object System.Drawing.Size(920, 150)
    $txtOld.Multiline = $true; $txtOld.ScrollBars = "Vertical"
    $txtOld.BackColor = [System.Drawing.Color]::FromArgb(255, 5, 10, 31); $txtOld.ForeColor = [System.Drawing.Color]::White
    $txtOld.Font = New-Object System.Drawing.Font("Consolas", 10); $txtOld.Visible = $false
    $licForm.Controls.Add($txtOld)

    $btnNew = New-Object System.Windows.Forms.Button
    $btnNew.Text = "? NEW LICENSE DATA"
    $btnNew.Location = New-Object System.Drawing.Point(30, 235); $btnNew.Size = New-Object System.Drawing.Size(920, 40)
    $btnNew.BackColor = [System.Drawing.Color]::FromArgb(255, 28, 37, 65); $btnNew.ForeColor = [System.Drawing.Color]::FromArgb(255, 0, 229, 255)
    $btnNew.FlatStyle = "Flat"; $btnNew.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
    $licForm.Controls.Add($btnNew)

    $txtNew = New-Object System.Windows.Forms.TextBox
    $txtNew.Location = New-Object System.Drawing.Point(30, 280); $txtNew.Size = New-Object System.Drawing.Size(920, 150)
    $txtNew.Multiline = $true; $txtNew.ScrollBars = "Vertical"
    $txtNew.BackColor = [System.Drawing.Color]::FromArgb(255, 5, 10, 31); $txtNew.ForeColor = [System.Drawing.Color]::White
    $txtNew.Font = New-Object System.Drawing.Font("Consolas", 10); $txtNew.Visible = $false
    $licForm.Controls.Add($txtNew)

    $btnAnalyse = New-Object System.Windows.Forms.Button
    $btnAnalyse.Text = "? EXECUTE SMART ANALYSE"
    $btnAnalyse.Location = New-Object System.Drawing.Point(30, 440); $btnAnalyse.Size = New-Object System.Drawing.Size(920, 50)
    $btnAnalyse.BackColor = [System.Drawing.Color]::FromArgb(255, 0, 229, 255); $btnAnalyse.ForeColor = [System.Drawing.Color]::FromArgb(255, 11, 19, 43)
    $btnAnalyse.FlatStyle = "Flat"; $btnAnalyse.Font = New-Object System.Drawing.Font("Consolas", 14, [System.Drawing.FontStyle]::Bold)
    $licForm.Controls.Add($btnAnalyse)

    $lblRes = New-Object System.Windows.Forms.Label
    $lblRes.Text = "VERIFICATION RESULTS"
    $lblRes.Location = New-Object System.Drawing.Point(30, 500); $lblRes.AutoSize = $true
    $lblRes.ForeColor = [System.Drawing.Color]::FromArgb(255, 91, 192, 190); $lblRes.Font = New-Object System.Drawing.Font("Consolas", 12, [System.Drawing.FontStyle]::Bold)
    $licForm.Controls.Add($lblRes)

    $rtbResults = New-Object System.Windows.Forms.RichTextBox
    $rtbResults.Location = New-Object System.Drawing.Point(30, 525); $rtbResults.Size = New-Object System.Drawing.Size(920, 160)
    $rtbResults.BackColor = [System.Drawing.Color]::FromArgb(255, 5, 10, 31); $rtbResults.ForeColor = [System.Drawing.Color]::White
    $rtbResults.Font = New-Object System.Drawing.Font("Consolas", 11); $rtbResults.ReadOnly = $true
    $licForm.Controls.Add($rtbResults)

    $btnOld.Add_Click({
        if ($txtOld.Visible) { $txtOld.Visible = $false; $btnOld.Text = "? OLD LICENSE DATA"; $btnNew.Top = 85; $txtNew.Top = 130; $btnAnalyse.Top = 290; $lblRes.Top = 350; $rtbResults.Top = 375; $rtbResults.Height = 310 }
        else { $txtOld.Visible = $true; $btnOld.Text = "? OLD LICENSE DATA"; $btnNew.Top = 235; $txtNew.Top = 280; $btnAnalyse.Top = 440; $lblRes.Top = 500; $rtbResults.Top = 525; $rtbResults.Height = 160 }
    })
    $btnNew.Add_Click({
        if ($txtNew.Visible) { $txtNew.Visible = $false; $btnNew.Text = "? NEW LICENSE DATA" }
        else { $txtNew.Visible = $true; $btnNew.Text = "? NEW LICENSE DATA" }
    })

    $btnAnalyse.Add_Click({
        $rtbResults.Clear()
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
                $rtbResults.SelectionColor = [System.Drawing.Color]::White
                $rtbResults.AppendText("$lineOld`n")
            } else {
                if ($null -ne $lineOld -and $lineOld.Trim() -ne "") {
                    $rtbResults.SelectionColor = [System.Drawing.Color]::FromArgb(255, 255, 76, 76)
                    $rtbResults.SelectionFont = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Strikeout)
                    $rtbResults.AppendText("$lineOld`n")
                    $rtbResults.SelectionFont = New-Object System.Drawing.Font("Consolas", 11, [System.Drawing.FontStyle]::Regular)
                }
                if ($null -ne $lineNew -and $lineNew.Trim() -ne "") {
                    $rtbResults.SelectionColor = [System.Drawing.Color]::FromArgb(255, 0, 229, 255)
                    $rtbResults.AppendText("$lineNew`n")
                }
            }
        }
    })
    [void]$licForm.ShowDialog()
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

function global:Show-RemoteManager {
    if (-not $script:ToolsLoaded) {
        [System.Windows.Forms.MessageBox]::Show("Please load the master payload first.", "No Scripts Loaded", 0, 48)
        return
    }

    $rmForm = New-Object System.Windows.Forms.Form
    $rmForm.Text = "Advanced Remote Orchestrator"
    $rmForm.Size = New-Object System.Drawing.Size(600, 720)
    $rmForm.StartPosition = "CenterParent"
    $rmForm.BackColor = $colorMainBg
    $rmForm.ForeColor = $colorTextWhite
    $rmForm.FormBorderStyle = "FixedDialog"
    $rmForm.MaximizeBox = $false

    $pnlNav = New-Object System.Windows.Forms.Panel
    $pnlNav.Size = New-Object System.Drawing.Size(600, 45)
    $pnlNav.Location = New-Object System.Drawing.Point(0, 0)
    $pnlNav.BackColor = $colorSidebarBg
    $rmForm.Controls.Add($pnlNav)

    $btnTabStd = New-Object System.Windows.Forms.Button
    $btnTabStd.Text = "STANDARD CONNECT"
    $btnTabStd.Size = New-Object System.Drawing.Size(290, 45)
    $btnTabStd.Location = New-Object System.Drawing.Point(0, 0)
    $btnTabStd.FlatStyle = "Flat"
    $btnTabStd.FlatAppearance.BorderSize = 0
    $btnTabStd.BackColor = $colorTabActive
    $btnTabStd.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnTabStd.Cursor = "Hand"
    $pnlNav.Controls.Add($btnTabStd)

    $btnTabPipe = New-Object System.Windows.Forms.Button
    $btnTabPipe.Text = "PIPELINE ORCHESTRATOR"
    $btnTabPipe.Size = New-Object System.Drawing.Size(290, 45)
    $btnTabPipe.Location = New-Object System.Drawing.Point(290, 0)
    $btnTabPipe.FlatStyle = "Flat"
    $btnTabPipe.FlatAppearance.BorderSize = 0
    $btnTabPipe.BackColor = $colorTabDeact
    $btnTabPipe.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnTabPipe.Cursor = "Hand"
    $pnlNav.Controls.Add($btnTabPipe)

    $pnlStd = New-Object System.Windows.Forms.Panel
    $pnlStd.Size = New-Object System.Drawing.Size(560, 620)
    $pnlStd.Location = New-Object System.Drawing.Point(10, 55)
    $pnlStd.Visible = $true
    $rmForm.Controls.Add($pnlStd)

    $pnlPipe = New-Object System.Windows.Forms.Panel
    $pnlPipe.Size = New-Object System.Drawing.Size(560, 620)
    $pnlPipe.Location = New-Object System.Drawing.Point(10, 55)
    $pnlPipe.Visible = $false
    $rmForm.Controls.Add($pnlPipe)

    $btnTabStd.Add_Click({
        $pnlStd.Visible = $true; $pnlPipe.Visible = $false
        $btnTabStd.BackColor = $colorTabActive; $btnTabPipe.BackColor = $colorTabDeact
    })
    $btnTabPipe.Add_Click({
        $pnlStd.Visible = $false; $pnlPipe.Visible = $true
        $btnTabStd.BackColor = $colorTabDeact; $btnTabPipe.BackColor = $colorTabActive
    })

    $credsFile = "C:\PnxTemp\RemoteCreds.xml"
    $script:SavedCredsList = @()
    if (Test-Path $credsFile) {
        try {
            $rawCreds = @(Import-Clixml $credsFile)
            foreach ($c in $rawCreds) {
                if (-not $c.PSObject.Properties.Match('Agency').Count) { $c | Add-Member -NotePropertyName Agency -NotePropertyValue "General" }
                if (-not $c.PSObject.Properties.Match('Nickname').Count) { $c | Add-Member -NotePropertyName Nickname -NotePropertyValue $c.HostName }
                $script:SavedCredsList += $c
            }
        } catch {}
    }

    $lblFilter = New-Object System.Windows.Forms.Label
    $lblFilter.Text = "Filter by Agency:"
    $lblFilter.Location = New-Object System.Drawing.Point(10, 10); $lblFilter.AutoSize = $true; $lblFilter.ForeColor = $termCyan
    $pnlStd.Controls.Add($lblFilter)

    $cmbAgencyFilter = New-Object System.Windows.Forms.ComboBox
    $cmbAgencyFilter.Location = New-Object System.Drawing.Point(10, 30); $cmbAgencyFilter.Size = New-Object System.Drawing.Size(540, 25)
    $cmbAgencyFilter.DropDownStyle = "DropDownList"
    $cmbAgencyFilter.BackColor = $colorConsoleBg; $cmbAgencyFilter.ForeColor = $colorTextWhite
    $pnlStd.Controls.Add($cmbAgencyFilter)

    $agencies = $script:SavedCredsList | Select-Object -ExpandProperty Agency -Unique | Sort-Object
    foreach ($a in $agencies) { [void]$cmbAgencyFilter.Items.Add($a) }

    $clbSaved = New-Object System.Windows.Forms.CheckedListBox
    $clbSaved.Location = New-Object System.Drawing.Point(10, 65); $clbSaved.Size = New-Object System.Drawing.Size(540, 120)
    $clbSaved.BackColor = $colorConsoleBg; $clbSaved.ForeColor = $colorTextWhite
    $clbSaved.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular); $clbSaved.CheckOnClick = $true
    $pnlStd.Controls.Add($clbSaved)

    $cmbAgencyFilter.Add_SelectedIndexChanged({
        $clbSaved.Items.Clear()
        $filtered = $script:SavedCredsList | Where-Object { $_.Agency -eq $cmbAgencyFilter.SelectedItem } | Sort-Object Nickname
        foreach ($f in $filtered) { [void]$clbSaved.Items.Add($f.Nickname) }
    })
    if ($cmbAgencyFilter.Items.Count -gt 0) { $cmbAgencyFilter.SelectedIndex = 0 }

    $btnPushStd = New-Object System.Windows.Forms.Button
    $btnPushStd.Text = "CONNECT CHECKED SERVERS"
    $btnPushStd.Location = New-Object System.Drawing.Point(10, 195); $btnPushStd.Size = New-Object System.Drawing.Size(540, 40)
    $btnPushStd.BackColor = $colorBtnDiag; $btnPushStd.ForeColor = $colorTextWhite
    $btnPushStd.FlatStyle = "Flat"; $btnPushStd.FlatAppearance.BorderSize = 0; $btnPushStd.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    global:Set-RoundedCorner $btnPushStd 8
    $btnPushStd.Add_Click({
        $selectedTargets = @()
        foreach ($checked in $clbSaved.CheckedItems) {
            $match = $script:SavedCredsList | Where-Object { $_.Nickname -eq $checked -and $_.Agency -eq $cmbAgencyFilter.SelectedItem } | Select-Object -First 1
            if ($match) { $selectedTargets += $match }
        }
        if ($selectedTargets.Count -eq 0) { return }
        $global:RemoteTargets = $selectedTargets
        global:Build-LogTabs; global:Update-Status "Standard Remote Mode Active."; $rmForm.Close()
    })
    $pnlStd.Controls.Add($btnPushStd)

    $lblOr = New-Object System.Windows.Forms.Label
    $lblOr.Text = "--- Add a New Connection ---"
    $lblOr.Location = New-Object System.Drawing.Point(10, 255); $lblOr.AutoSize = $true; $lblOr.ForeColor = $colorTextMuted
    $pnlStd.Controls.Add($lblOr)

    $lblNewAgency = New-Object System.Windows.Forms.Label
    $lblNewAgency.Text = "Agency Name:"
    $lblNewAgency.Location = New-Object System.Drawing.Point(10, 280); $lblNewAgency.AutoSize = $true
    $pnlStd.Controls.Add($lblNewAgency)

    $cmbNewAgency = New-Object System.Windows.Forms.ComboBox
    $cmbNewAgency.Location = New-Object System.Drawing.Point(10, 300); $cmbNewAgency.Size = New-Object System.Drawing.Size(260, 25)
    $cmbNewAgency.DropDownStyle = "DropDown"
    $cmbNewAgency.BackColor = $colorConsoleBg; $cmbNewAgency.ForeColor = $colorTextWhite
    foreach ($a in $agencies) { [void]$cmbNewAgency.Items.Add($a) }
    $pnlStd.Controls.Add($cmbNewAgency)

    $lblNewNick = New-Object System.Windows.Forms.Label
    $lblNewNick.Text = "Server Nickname:"
    $lblNewNick.Location = New-Object System.Drawing.Point(290, 280); $lblNewNick.AutoSize = $true
    $pnlStd.Controls.Add($lblNewNick)

    $txtNewNick = New-Object System.Windows.Forms.TextBox
    $txtNewNick.Location = New-Object System.Drawing.Point(290, 300); $txtNewNick.Size = New-Object System.Drawing.Size(260, 25)
    $txtNewNick.BackColor = $colorConsoleBg; $txtNewNick.ForeColor = $colorTextWhite
    $pnlStd.Controls.Add($txtNewNick)

    $lblHost = New-Object System.Windows.Forms.Label
    $lblHost.Text = "Hostname or IP Address:"
    $lblHost.Location = New-Object System.Drawing.Point(10, 330); $lblHost.AutoSize = $true
    $pnlStd.Controls.Add($lblHost)

    $txtHost = New-Object System.Windows.Forms.TextBox
    $txtHost.Location = New-Object System.Drawing.Point(10, 350); $txtHost.Size = New-Object System.Drawing.Size(540, 25)
    $txtHost.BackColor = $colorConsoleBg; $txtHost.ForeColor = $colorTextWhite
    $pnlStd.Controls.Add($txtHost)

    $lblUser = New-Object System.Windows.Forms.Label
    $lblUser.Text = "Admin Username (e.g. Domain\Admin):"
    $lblUser.Location = New-Object System.Drawing.Point(10, 380); $lblUser.AutoSize = $true
    $pnlStd.Controls.Add($lblUser)

    $txtUser = New-Object System.Windows.Forms.TextBox
    $txtUser.Location = New-Object System.Drawing.Point(10, 400); $txtUser.Size = New-Object System.Drawing.Size(260, 25)
    $txtUser.BackColor = $colorConsoleBg; $txtUser.ForeColor = $colorTextWhite
    $pnlStd.Controls.Add($txtUser)

    $lblPass = New-Object System.Windows.Forms.Label
    $lblPass.Text = "Password:"
    $lblPass.Location = New-Object System.Drawing.Point(290, 380); $lblPass.AutoSize = $true
    $pnlStd.Controls.Add($lblPass)

    $txtPass = New-Object System.Windows.Forms.TextBox
    $txtPass.Location = New-Object System.Drawing.Point(290, 400); $txtPass.Size = New-Object System.Drawing.Size(260, 25)
    $txtPass.UseSystemPasswordChar = $true; $txtPass.BackColor = $colorConsoleBg; $txtPass.ForeColor = $colorTextWhite
    $pnlStd.Controls.Add($txtPass)

    $btnSaveConn = New-Object System.Windows.Forms.Button
    $btnSaveConn.Text = "SAVE & CONNECT NEW SERVER"
    $btnSaveConn.Location = New-Object System.Drawing.Point(10, 445); $btnSaveConn.Size = New-Object System.Drawing.Size(540, 40)
    $btnSaveConn.BackColor = [System.Drawing.Color]::FromArgb(255, 30, 70, 110); $btnSaveConn.ForeColor = $colorTextWhite
    $btnSaveConn.FlatStyle = "Flat"; $btnSaveConn.FlatAppearance.BorderSize = 0; $btnSaveConn.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    global:Set-RoundedCorner $btnSaveConn 8
    $btnSaveConn.Add_Click({
        $a = if ($cmbNewAgency.Text) { $cmbNewAgency.Text.Trim() } else { "General" }
        $h = $txtHost.Text.Trim(); $u = $txtUser.Text.Trim(); $p = $txtPass.Text; $nk = $txtNewNick.Text.Trim()
        if (-not $h -or -not $u -or -not $p) { [System.Windows.Forms.MessageBox]::Show("Hostname, User, and Pass are required.", "Error", 0, 16); return }
        if (-not $nk) { $nk = $h }

        $secStr = ConvertTo-SecureString $p -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($u, $secStr)
        $newTarget = [PSCustomObject]@{ Agency = $a; Nickname = $nk; HostName = $h; Credential = $cred }
        
        $existing = $script:SavedCredsList | Where-Object { $_.HostName -eq $h -and $_.Agency -eq $a } | Select-Object -First 1
        if ($existing) { $existing.Credential = $cred; $existing.Nickname = $nk } else { $script:SavedCredsList = @($script:SavedCredsList) + $newTarget }
        $script:SavedCredsList | Export-Clixml -Path $credsFile -Force

        $global:RemoteTargets = @($newTarget)
        global:Build-LogTabs; global:Show-ExecutionLogs; $rmForm.Close()
    })
    $pnlStd.Controls.Add($btnSaveConn)

    $btnDisconnect = New-Object System.Windows.Forms.Button
    $btnDisconnect.Text = "REVERT TO LOCAL EXECUTION"
    $btnDisconnect.Location = New-Object System.Drawing.Point(10, 505); $btnDisconnect.Size = New-Object System.Drawing.Size(540, 40)
    $btnDisconnect.BackColor = $colorBtnGen; $btnDisconnect.ForeColor = $colorTextWhite
    $btnDisconnect.FlatStyle = "Flat"; $btnDisconnect.FlatAppearance.BorderSize = 0; $btnDisconnect.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    global:Set-RoundedCorner $btnDisconnect 8
    $btnDisconnect.Add_Click({ $global:RemoteTargets = @(); global:Switch-LogTab "LOCAL"; $rmForm.Close() })
    $pnlStd.Controls.Add($btnDisconnect)

    # ==============================
    # PANEL 2: PIPELINE MANAGER
    # ==============================
    $lblPipeTitle = New-Object System.Windows.Forms.Label
    $lblPipeTitle.Text = "Orchestrated Pipeline (App + DB Sync)"
    $lblPipeTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblPipeTitle.Location = New-Object System.Drawing.Point(10, 10); $lblPipeTitle.AutoSize = $true; $lblPipeTitle.ForeColor = $colorLblDash
    $pnlPipe.Controls.Add($lblPipeTitle)

    $pipeFile = "C:\PnxTemp\PipelineCreds.xml"
    if (Test-Path $pipeFile) { try { $script:SavedPipelineList = @(Import-Clixml $pipeFile) } catch {} }

    $lblPipeProfiles = New-Object System.Windows.Forms.Label
    $lblPipeProfiles.Text = "Load Saved Pipeline Profile:"
    $lblPipeProfiles.Location = New-Object System.Drawing.Point(10, 50); $lblPipeProfiles.AutoSize = $true
    $pnlPipe.Controls.Add($lblPipeProfiles)

    $cmbPipeProfiles = New-Object System.Windows.Forms.ComboBox
    $cmbPipeProfiles.Location = New-Object System.Drawing.Point(10, 70); $cmbPipeProfiles.Size = New-Object System.Drawing.Size(540, 25)
    $cmbPipeProfiles.DropDownStyle = "DropDownList"
    $cmbPipeProfiles.BackColor = $colorConsoleBg; $cmbPipeProfiles.ForeColor = $colorTextWhite
    foreach ($p in $script:SavedPipelineList) { [void]$cmbPipeProfiles.Items.Add($p.Nickname) }
    $pnlPipe.Controls.Add($cmbPipeProfiles)

    $lblPipeNick = New-Object System.Windows.Forms.Label
    $lblPipeNick.Text = "Profile Nickname (for saving):"
    $lblPipeNick.Location = New-Object System.Drawing.Point(10, 115); $lblPipeNick.AutoSize = $true
    $pnlPipe.Controls.Add($lblPipeNick)

    $txtPipeNick = New-Object System.Windows.Forms.TextBox
    $txtPipeNick.Location = New-Object System.Drawing.Point(10, 135); $txtPipeNick.Size = New-Object System.Drawing.Size(540, 25)
    $txtPipeNick.BackColor = $colorConsoleBg; $txtPipeNick.ForeColor = $colorTextWhite
    $pnlPipe.Controls.Add($txtPipeNick)

    $lblApp = New-Object System.Windows.Forms.Label
    $lblApp.Text = "Application Server (Runs Hotfix):"
    $lblApp.Location = New-Object System.Drawing.Point(10, 175); $lblApp.AutoSize = $true
    $pnlPipe.Controls.Add($lblApp)
    
    $cmbApp = New-Object System.Windows.Forms.ComboBox
    $cmbApp.Location = New-Object System.Drawing.Point(10, 195); $cmbApp.Size = New-Object System.Drawing.Size(260, 25)
    $cmbApp.BackColor = $colorConsoleBg; $cmbApp.ForeColor = $colorTextWhite
    foreach ($c in $script:SavedCredsList) { [void]$cmbApp.Items.Add("$($c.Nickname) - $($c.HostName)") }
    $pnlPipe.Controls.Add($cmbApp)

    $lblDb = New-Object System.Windows.Forms.Label
    $lblDb.Text = "Database Server (Runs DB Sync):"
    $lblDb.Location = New-Object System.Drawing.Point(290, 175); $lblDb.AutoSize = $true
    $pnlPipe.Controls.Add($lblDb)

    $cmbDb = New-Object System.Windows.Forms.ComboBox
    $cmbDb.Location = New-Object System.Drawing.Point(290, 195); $cmbDb.Size = New-Object System.Drawing.Size(260, 25)
    $cmbDb.BackColor = $colorConsoleBg; $cmbDb.ForeColor = $colorTextWhite
    foreach ($c in $script:SavedCredsList) { [void]$cmbDb.Items.Add("$($c.Nickname) - $($c.HostName)") }
    $pnlPipe.Controls.Add($cmbDb)

    $lblSqlInst = New-Object System.Windows.Forms.Label
    $lblSqlInst.Text = "SQL Instance Name:"
    $lblSqlInst.Location = New-Object System.Drawing.Point(10, 235); $lblSqlInst.AutoSize = $true
    $pnlPipe.Controls.Add($lblSqlInst)

    $txtSqlInst = New-Object System.Windows.Forms.TextBox
    $txtSqlInst.Location = New-Object System.Drawing.Point(10, 255); $txtSqlInst.Size = New-Object System.Drawing.Size(260, 25)
    $txtSqlInst.Text = "MSSQLSERVER"
    $txtSqlInst.BackColor = $colorConsoleBg; $txtSqlInst.ForeColor = $colorTextWhite
    $pnlPipe.Controls.Add($txtSqlInst)

    $lblEnv = New-Object System.Windows.Forms.Label
    $lblEnv.Text = "Target Environment:"
    $lblEnv.Location = New-Object System.Drawing.Point(290, 235); $lblEnv.AutoSize = $true
    $pnlPipe.Controls.Add($lblEnv)

    $cmbEnv = New-Object System.Windows.Forms.ComboBox
    $cmbEnv.Location = New-Object System.Drawing.Point(290, 255); $cmbEnv.Size = New-Object System.Drawing.Size(260, 25)
    $cmbEnv.DropDownStyle = "DropDownList"
    $cmbEnv.BackColor = $colorConsoleBg; $cmbEnv.ForeColor = $colorTextWhite
    $cmbEnv.Items.Add("Live") | Out-Null
    $cmbEnv.Items.Add("Test") | Out-Null
    $cmbEnv.SelectedIndex = 1
    $pnlPipe.Controls.Add($cmbEnv)

    $lblSqlUser = New-Object System.Windows.Forms.Label
    $lblSqlUser.Text = "SQL Username:"
    $lblSqlUser.Location = New-Object System.Drawing.Point(10, 295); $lblSqlUser.AutoSize = $true
    $pnlPipe.Controls.Add($lblSqlUser)

    $txtSqlUser = New-Object System.Windows.Forms.TextBox
    $txtSqlUser.Location = New-Object System.Drawing.Point(10, 315); $txtSqlUser.Size = New-Object System.Drawing.Size(260, 25)
    $txtSqlUser.BackColor = $colorConsoleBg; $txtSqlUser.ForeColor = $colorTextWhite
    $pnlPipe.Controls.Add($txtSqlUser)

    $lblSqlPass = New-Object System.Windows.Forms.Label
    $lblSqlPass.Text = "SQL Password:"
    $lblSqlPass.Location = New-Object System.Drawing.Point(290, 295); $lblSqlPass.AutoSize = $true
    $pnlPipe.Controls.Add($lblSqlPass)

    $txtSqlPass = New-Object System.Windows.Forms.TextBox
    $txtSqlPass.Location = New-Object System.Drawing.Point(290, 315); $txtSqlPass.Size = New-Object System.Drawing.Size(260, 25)
    $txtSqlPass.UseSystemPasswordChar = $true; $txtSqlPass.BackColor = $colorConsoleBg; $txtSqlPass.ForeColor = $colorTextWhite
    $pnlPipe.Controls.Add($txtSqlPass)

    $cmbPipeProfiles.Add_SelectedIndexChanged({
        $sel = $script:SavedPipelineList | Where-Object { $_.Nickname -eq $cmbPipeProfiles.SelectedItem } | Select-Object -First 1
        if ($sel) {
            $txtPipeNick.Text = $sel.Nickname
            $cmbApp.Text = $sel.App
            $cmbDb.Text = $sel.Db
            $txtSqlInst.Text = $sel.Instance
            $cmbEnv.SelectedItem = $sel.Environment
            $txtSqlUser.Text = $sel.User
            $txtSqlPass.Text = $sel.Pass
        }
    })

    $btnSavePipe = New-Object System.Windows.Forms.Button
    $btnSavePipe.Text = "SAVE PIPELINE PROFILE"
    $btnSavePipe.Location = New-Object System.Drawing.Point(10, 370); $btnSavePipe.Size = New-Object System.Drawing.Size(540, 35)
    $btnSavePipe.BackColor = $colorBtnSys; $btnSavePipe.ForeColor = $colorTextWhite
    $btnSavePipe.FlatStyle = "Flat"; $btnSavePipe.FlatAppearance.BorderSize = 0; $btnSavePipe.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    global:Set-RoundedCorner $btnSavePipe 8
    $btnSavePipe.Add_Click({
        $nk = $txtPipeNick.Text.Trim(); $ap = $cmbApp.Text.Trim(); $db = $cmbDb.Text.Trim()
        if (-not $nk -or -not $ap -or -not $db) { [System.Windows.Forms.MessageBox]::Show("Nickname, App, and DB fields required.", "Error", 0, 16); return }
        $newPipe = [PSCustomObject]@{ Nickname=$nk; App=$ap; Db=$db; Instance=$txtSqlInst.Text.Trim(); Environment=$cmbEnv.SelectedItem; User=$txtSqlUser.Text.Trim(); Pass=$txtSqlPass.Text }
        $existing = $script:SavedPipelineList | Where-Object { $_.Nickname -eq $nk } | Select-Object -First 1
        if ($existing) { 
            $existing.App=$newPipe.App; $existing.Db=$newPipe.Db; $existing.Instance=$newPipe.Instance; $existing.Environment=$newPipe.Environment; $existing.User=$newPipe.User; $existing.Pass=$newPipe.Pass
        } else {
            $script:SavedPipelineList = @($script:SavedPipelineList) + $newPipe
            [void]$cmbPipeProfiles.Items.Add($nk)
        }
        $script:SavedPipelineList | Export-Clixml -Path $pipeFile -Force
        [System.Windows.Forms.MessageBox]::Show("Pipeline profile saved successfully.", "Success", 0, 64) | Out-Null
    })
    $pnlPipe.Controls.Add($btnSavePipe)

    $btnRunPipe = New-Object System.Windows.Forms.Button
    $btnRunPipe.Text = "EXECUTE PIPELINE"
    $btnRunPipe.Location = New-Object System.Drawing.Point(10, 415); $btnRunPipe.Size = New-Object System.Drawing.Size(540, 45)
    $btnRunPipe.BackColor = $termGreen; $btnRunPipe.ForeColor = [System.Drawing.Color]::Black
    $btnRunPipe.FlatStyle = "Flat"; $btnRunPipe.FlatAppearance.BorderSize = 0; $btnRunPipe.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    global:Set-RoundedCorner $btnRunPipe 10
    
    $btnRunPipe.Add_Click({
        if ($btnRunPipe.Text -match "Initiating") { return } 
        if (-not $cmbApp.Text -or -not $cmbDb.Text) { [System.Windows.Forms.MessageBox]::Show("Please specify an App and DB Server.", "Error", 0, 16); return }
        
        $btnRunPipe.Enabled = $false; $btnRunPipe.Text = "Initiating Pipeline (Please Wait)..."
        [System.Windows.Forms.Application]::DoEvents()
        
        try {
            $appRawHost = ($cmbApp.Text -split ' - ')[-1].Trim()
            $dbRawHost = ($cmbDb.Text -split ' - ')[-1].Trim()

            $appTarget = $script:SavedCredsList | Where-Object { $_.HostName -eq $appRawHost } | Select-Object -First 1
            $dbTarget = $script:SavedCredsList | Where-Object { $_.HostName -eq $dbRawHost } | Select-Object -First 1
            
            if (-not $appTarget -or -not $dbTarget) {
                [System.Windows.Forms.MessageBox]::Show("Servers must exist in Standard tab to supply credentials.", "Error", 0, 16) | Out-Null
                return
            }

            global:Execute-Pipeline $appTarget $dbTarget $txtSqlUser.Text $txtSqlPass.Text $txtSqlInst.Text $cmbEnv.SelectedItem
        } finally { $rmForm.Close() }
    })
    $pnlPipe.Controls.Add($btnRunPipe)

    $btnExitPipe = New-Object System.Windows.Forms.Button
    $btnExitPipe.Text = "EXIT PIPELINE"
    $btnExitPipe.Location = New-Object System.Drawing.Point(10, 475); $btnExitPipe.Size = New-Object System.Drawing.Size(540, 30)
    $btnExitPipe.BackColor = $colorBtnGen; $btnExitPipe.ForeColor = $colorTextWhite
    $btnExitPipe.FlatStyle = "Flat"; $btnExitPipe.FlatAppearance.BorderSize = 0; $btnExitPipe.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    global:Set-RoundedCorner $btnExitPipe 8
    $btnExitPipe.Add_Click({ $rmForm.Close() })
    $pnlPipe.Controls.Add($btnExitPipe)

    [void]$rmForm.ShowDialog()
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

function global:Show-HelpPrompt {
    if (-not $script:ToolsLoaded) { global:Update-Status "Master Directory not loaded." $true; return }
    $helpForm = New-Object System.Windows.Forms.Form
    $helpForm.Text = "ProPhoenix Documentation Library"
    $helpForm.Size = New-Object System.Drawing.Size(950, 650)
    $helpForm.StartPosition = "CenterParent"
    $helpForm.BackColor = $colorMainBg; $helpForm.ForeColor = $colorTextWhite
    $helpForm.FormBorderStyle = "FixedDialog"; $helpForm.MaximizeBox = $false

    $tvDocs = New-Object System.Windows.Forms.TreeView
    $tvDocs.Location = New-Object System.Drawing.Point(20, 80); $tvDocs.Size = New-Object System.Drawing.Size(300, 460)
    $tvDocs.BackColor = $colorCardBg; $tvDocs.ForeColor = $colorTextWhite
    $tvDocs.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    $helpForm.Controls.Add($tvDocs)

    $rtbViewer = New-Object System.Windows.Forms.RichTextBox
    $rtbViewer.Location = New-Object System.Drawing.Point(335, 80); $rtbViewer.Size = New-Object System.Drawing.Size(575, 460)
    $rtbViewer.BackColor = $colorConsoleBg; $rtbViewer.ForeColor = $colorTextWhite
    $rtbViewer.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Regular)
    $rtbViewer.ReadOnly = $true; $rtbViewer.BorderStyle = "None"
    $helpForm.Controls.Add($rtbViewer)

    $internalRoot = New-Object System.Windows.Forms.TreeNode("Phoenix Master Documentation")
    $internalRoot.NodeFont = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $internalRoot.ForeColor = $colorLblDash
    $tvDocs.Nodes.Add($internalRoot)

    $sections = $script:GuideText -split '(?m)^(?=\d+\.\s)'
    foreach ($sec in $sections) {
        if ($sec.Trim() -match "^(\d+\.\s+.*?)\r?\n") {
            $node = New-Object System.Windows.Forms.TreeNode($matches[1].Trim())
            $node.Tag = "INTERNAL_SECTION_CONTENT|" + $sec.Trim()
            $internalRoot.Nodes.Add($node)
        }
    }
    $internalRoot.ExpandAll()
    $tvDocs.Add_AfterSelect({
        if ($tvDocs.SelectedNode.Tag -match "^INTERNAL_SECTION_CONTENT\|(.*)") { $rtbViewer.Text = $matches[1] }
    })
    if ($internalRoot.Nodes.Count -gt 0) { $tvDocs.SelectedNode = $internalRoot.Nodes[0] }

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "Close Viewer"; $btnClose.Location = New-Object System.Drawing.Point(760, 560); $btnClose.Size = New-Object System.Drawing.Size(150, 40)
    $btnClose.BackColor = $colorBtnGen; $btnClose.ForeColor = $colorTextWhite; $btnClose.FlatStyle = "Flat"
    $btnClose.Add_Click({ $helpForm.Close() })
    $helpForm.Controls.Add($btnClose)

    [void]$helpForm.ShowDialog()
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

function Add-SidebarButton($Panel, $Text, $Top, $BgColor, [scriptblock]$Action) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text; $btn.Font = $fontMenuBold; $btn.BackColor = $BgColor
    $btn.ForeColor = $colorTextWhite; $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btn.FlatAppearance.BorderSize = 0
    $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(0, 255, 255, 255)
    $btn.Size = New-Object System.Drawing.Size(220, 40) 
    $btn.Location = New-Object System.Drawing.Point(10, $Top); $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Add_GotFocus({
        param($sender, $e)
        if ($null -ne $sender.Parent) { $sender.Parent.Focus() }
    })
    global:Set-RoundedCorner $btn 10
    $btn.Add_Click($Action)
    $Panel.Controls.Add($btn)
}

Add-SidebarButton $pnlGroupGen "Search / Reload Master" 40 $colorBtnGen { global:Search-Master }
Add-SidebarButton $pnlGroupGen "Download Prerequisite" 85 $colorBtnGen { Start-Process $Url_Blob; Start-Process $Url_GDrive }

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
Add-SidebarButton $pnlGroupDiag "Check Public IP" 85 $colorBtnDiag { try{ $ip = Invoke-RestMethod 'https://api.ipify.org'; global:Write-Terminal "Public IP Resolved: $ip" "Cyan" "ALL" }catch{} }
Add-SidebarButton $pnlGroupDiag "Run Diagnostics" 130 $colorBtnDiag { global:Write-Terminal "--- INITIATING SYSTEM AUDIT ---" "Cyan" "ALL" }

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

$contentPanel = New-Object System.Windows.Forms.Panel
$contentPanel.Location = New-Object System.Drawing.Point(260, 0)
$contentPanel.Size = New-Object System.Drawing.Size(980, 900)
$contentPanel.BackColor = $colorMainBg
$script:form.Controls.Add($contentPanel)

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
  Dashboard Version 12.0 (Enterprise Deep-Hunt Engine)
  Created by Installation Team
  
  CURRENT US TIME ZONES:
  EST: $estTime   |   CST: $cstTime   |   PST: $pstTime
  ========================================================================

  TECHNICAL MODULES & WORKFLOW:
  ------------------------------------------------------------------------
  [1] Core UI Engine: Built entirely in PowerShell using native WinForms.
      Implements double-buffering and region-clipping for the Glass Theme.

  [2] Execution Module: Utilizes advanced Runspace-based synchronization 
      to explicitly intercept GUI bugs and flawlessly execute detached 
      payloads over WinRM connections.

  [3] Telemetry & ADSI Module: Actively queries Active Directory (ADSI)
      to dynamically resolve and map the local Hostname.

  [4] Pipeline Orchestrator: Drives automated DB Config generation 
      and Hotfix installations iteratively in parallel.
  ========================================================================
"@
    $infoForm.Controls.Add($infoRtb)
    [void]$infoForm.ShowDialog()
})
$pnlHostBadge.Controls.Add($btnInfo)
$btnInfo.BringToFront()

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
#  WINRM ASYNC TIMERS & POLLING
# ==============================================================================
$global:JobTimer = New-Object System.Windows.Forms.Timer
$global:JobTimer.Interval = 500 
$global:JobTimer.Add_Tick({
    $global:JobTimer.Stop()
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
                            } else {
                                global:Write-Terminal "[$($aj.Target)] $res" "Cyan" $aj.Target $res
                            }
                        }
                    }
                    if ($aj.Job.State -in 'Completed','Failed','Stopped') {
                        global:Write-Terminal "[$($aj.Target)] Execution completed." "Lime" $aj.Target
                        if ($global:LogTabs -and $global:LogTabs.ContainsKey($aj.Target)) {
                            if ($global:LogTabs[$aj.Target].Controls.ContainsKey("MainTabButton")) {
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
                }
            }
            $global:ActiveJobs = $remainingJobs
        }
    } finally {
        $global:JobTimer.Start()
    }
})

$global:ScheduleTimer = New-Object System.Windows.Forms.Timer
$global:ScheduleTimer.Interval = 5000 
$global:ScheduleTimer.Add_Tick({
    try {
        foreach ($job in $global:ScheduledJobs) {
            if ($job.Status -eq "Pending" -and [datetime]::Now -ge $job.RunTime) {
                $job.Status = "Triggered"
                global:Write-Terminal ">>> SCHEDULE TRIGGERED: $($job.FriendlyName)" "Cyan" "ALL"
                $global:RemoteTargets = $job.Targets
                global:Launch-File $job.ScriptPath $job.FriendlyName $job.UserInput $false
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

$lblCopyright = New-Object System.Windows.Forms.Label
$lblCopyright.Text = "© 2026, ProPhoenix Corporation, All Rights Reserved"
$lblCopyright.Font = $script:Font_Copyright
$lblCopyright.ForeColor = $colorTextMuted
$lblCopyright.Location = New-Object System.Drawing.Point(0, 850)
$lblCopyright.Size = New-Object System.Drawing.Size(980, 30)
$lblCopyright.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$lblCopyright.BackColor = [System.Drawing.Color]::Transparent
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
            $Url_GDrive = "https://drive.google.com/uc?export=download&id=10RxuJaWwqR1S6lbkjL0-_AXddCwOARYI"
            $DownloadUrls = @($Url_GitHub, $Url_GDrive)
            $TempDir = "C:\PnxTemp"
            
            if (Test-Path $InstallBase) {
                global:Write-Terminal "Old payload detected. Removing old scripts..." "Yellow" "ALL"
                Remove-Item -Path $InstallBase -Recurse -Force -ErrorAction SilentlyContinue
            }
            if (-not (Test-Path $TempDir)) { New-Item -ItemType Directory -Path $TempDir -Force | Out-Null }
            
            $TempZip = Join-Path $TempDir "PhoenixInstallationMaster_$(Get-Random).zip"
            if (Test-Path $TempZip) { Remove-Item $TempZip -Force -ErrorAction SilentlyContinue }
            
            global:Write-Terminal "Downloading latest payload..." "White" "ALL"
            global:Update-Status "Downloading latest scripts..."
            [System.Windows.Forms.Application]::DoEvents()
            
            try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
            $downloadSuccess = $false
            
            foreach ($url in $DownloadUrls) {
                if ([string]::IsNullOrWhiteSpace($url)) { continue }
                global:Write-Terminal "Attempting secure connection to: $url" "LightGray" "ALL"
                [System.Windows.Forms.Application]::DoEvents()

                try {
                    Import-Module BitsTransfer -ErrorAction SilentlyContinue
                    Start-BitsTransfer -Source $url -Destination $TempZip -ErrorAction Stop
                    if (Test-Path $TempZip) {
                        if ((Get-Item $TempZip).Length -gt 50KB) { $downloadSuccess = $true; break }
                    }
                } catch {}

                if (-not $downloadSuccess) {
                    try {
                        $wc = New-Object System.Net.WebClient
                        $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
                        $wc.DownloadFile($url, $TempZip)
                        $wc.Dispose()
                        if (Test-Path $TempZip) {
                            if ((Get-Item $TempZip).Length -gt 50KB) { $downloadSuccess = $true; break }
                        }
                    } catch {}
                }

                if (-not $downloadSuccess) {
                    try {
                        Invoke-WebRequest -Uri $url -OutFile $TempZip -UseBasicParsing -TimeoutSec 120 -ErrorAction Stop
                        if (Test-Path $TempZip) {
                            if ((Get-Item $TempZip).Length -gt 50KB) { $downloadSuccess = $true; break }
                        }
                    } catch {}
                }
                
                if (-not $downloadSuccess -and (Test-Path $TempZip)) {
                    Remove-Item $TempZip -Force -ErrorAction SilentlyContinue
                }
            }
            
            if (-not $downloadSuccess) {
                global:Write-Terminal "All automatic download engines blocked by network firewall." "Red" "ALL"
                global:Update-Status "Download Blocked. Running deep local search..." $true
                try { global:Search-Master } catch { global:Write-Terminal "Local Search Engine Failed: $_" "Red" "ALL" }
                return
            }
            
            global:Write-Terminal "Payload secured. Extracting architecture..." "White" "ALL"
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
} else { 
    Write-Host "CRITICAL ERROR: Form not initialized. Review script brackets." -ForegroundColor Red
    pause 
}



