<#
.SYNOPSIS
    ProPhoenix Enterprise Deployment Dashboard (v127.1 - Pro-Tech Edition)
    - SYNTAX FIX: Removed giant try/catch wrappers to prevent parser cutoff errors.
    - UI OVERHAUL: Ultra-modern "Pro-Tech" dark theme with Neon Cyan and Electric Blue accents.
    - UI UPDATE: Script cards updated to "Data Nodes" with color-coded accent borders.
    - CORE: Retains Dual-Screen Tabs, Auto-Log Switching, Hybrid Launching, and Silent Permissions.
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

Write-Host "[INIT] Booting ProPhoenix Enterprise Command Center v127.1..." -ForegroundColor Cyan

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
#  2. GLOBAL ASSEMBLIES & THE NEW "PRO-TECH" THEME
# ==============================================================================
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-Color($name) {
    switch($name) {
        "BgMain"       { return [System.Drawing.Color]::FromArgb(10, 14, 23) }   # Deep Tech Navy/Black
        "SideBg"       { return [System.Drawing.Color]::FromArgb(5, 8, 14) }     # Obsidian Black
        "CardBg"       { return [System.Drawing.Color]::FromArgb(18, 26, 43) }   # Elevated Navy
        "CardHover"    { return [System.Drawing.Color]::FromArgb(28, 40, 65) }   # Light Navy Hover
        "BtnRun"       { return [System.Drawing.Color]::FromArgb(0, 120, 215) }  # Tech Blue
        "BtnRed"       { return [System.Drawing.Color]::FromArgb(180, 20, 40) }  # Cyber Red
        "BtnRedHover"  { return [System.Drawing.Color]::FromArgb(220, 30, 50) }
        "BtnBlue"      { return [System.Drawing.Color]::FromArgb(15, 60, 110) }
        "BtnBlueHover" { return [System.Drawing.Color]::FromArgb(0, 140, 255) }  # Electric Blue Hover
        "HeaderRed"    { return [System.Drawing.Color]::FromArgb(255, 60, 60) }
        "BrandRed"     { return [System.Drawing.Color]::FromArgb(255, 80, 0) }   # Neon Phoenix Orange
        "TextWhite"    { return [System.Drawing.Color]::FromArgb(230, 240, 255) }
        "TextGrey"     { return [System.Drawing.Color]::FromArgb(140, 150, 170) }
        "StatusGreen"  { return [System.Drawing.Color]::FromArgb(0, 255, 128) }  # Neon Hacker Green
        "Terminal"     { return [System.Drawing.Color]::FromArgb(0, 0, 0) }      # Pure Black
        "CyanAccent"   { return [System.Drawing.Color]::FromArgb(0, 229, 255) }  # Tron Cyan
        "Yellow"       { return [System.Drawing.Color]::FromArgb(255, 215, 0) }
        "Magenta"      { return [System.Drawing.Color]::Magenta }
        "LightGray"    { return [System.Drawing.Color]::LightGray }
        default        { return [System.Drawing.Color]::White }
    }
}

$script:Font_MainTitle = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$script:Font_Brand     = New-Object System.Drawing.Font("Georgia", 22, [System.Drawing.FontStyle]::Bold)
$script:Font_SubTitle  = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
$script:Font_SideHead  = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$script:Font_SideBtn   = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$script:Font_ItemText  = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold) 
$script:Font_RunBtn    = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$script:Font_Status    = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
$script:Font_Card_Lbl  = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Bold)
$script:Font_Card_Val  = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$script:Font_Term      = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)

$Url_GDrive   = "https://drive.google.com/uc?export=download&id=10RxuJaWwqR1S6lbkjL0-_AXddCwOARYI"
$Url_Blob     = "https://produpdates.blob.core.windows.net/web/Prerequisite%20Script%202026/Phoenix%20Installation%20Master.zip?sp=racw&st=2026-01-30T14:01:41Z&se=2032-03-30T22:16:41Z&spr=https&sv=2024-11-04&sr=b&sig=3vXVuby1lcDbQ%2BQQnVzxmmXJsyaRG2sgQwTH9SzPnh4%3D"
$ZipNamePattern = "Phoenix Installation Master*.zip"
$InstallBase    = "C:\pnxtemp\Phoenix Installation Master"
$script:CurrentToolPath = $InstallBase 
$script:ToolsLoaded = $false

# ==========================================================================
#  3. SYSADMIN LOGGING ENGINE & AUTO-TAB SWITCHER
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
            $script:TermConsole.SelectionColor = Get-Color $colorName
            $script:TermConsole.AppendText("$FullMsg`n")
            $script:TermConsole.ScrollToCaret()
            [System.Windows.Forms.Application]::DoEvents()
        }
    } catch {}
}

function Update-Status($msg, $isError = $false) {
    if ($script:lblStatus) {
        $script:lblStatus.Text = "[ SYS.STATUS ] :: $msg"
        if ($isError) { $script:lblStatus.ForeColor = Get-Color "HeaderRed" }
        else { $script:lblStatus.ForeColor = Get-Color "StatusGreen" }
        $script:lblStatus.Refresh()
    }
}

function Show-ExecutionLogs {
    if ($null -ne $script:pnlConsole -and $null -ne $script:btnTabLogs) {
        $script:form.SuspendLayout()
        $script:pnlTools.Visible = $false
        $script:pnlConsole.Visible = $true
        
        $script:btnTabLogs.BackColor = Get-Color "CardBg"
        $script:btnTabLogs.ForeColor = Get-Color "CyanAccent"
        $script:btnTabLogs.FlatAppearance.BorderSize = 1
        $script:btnTabLogs.FlatAppearance.BorderColor = Get-Color "CyanAccent"
        
        $script:btnTabScripts.BackColor = Get-Color "BgMain"
        $script:btnTabScripts.ForeColor = Get-Color "TextGrey"
        $script:btnTabScripts.FlatAppearance.BorderSize = 0
        
        $script:form.ResumeLayout($true)
        if ($script:pnlToolsWrapper) { $script:pnlToolsWrapper.Invalidate($true) }
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
    Update-Status "Awaiting IP Handshake..."
    [System.Windows.Forms.Application]::DoEvents()
    
    try {
        $ip = Invoke-RestMethod -Uri 'https://api.ipify.org' -UseBasicParsing -TimeoutSec 5
        Write-Terminal "Public IP Resolved: $ip" "CyanAccent"
        Update-Status "Network Node Connected."
    } catch {
        Write-Terminal "Failed to reach external IP service." "HeaderRed"
        Update-Status "Network Node Offline." $true
    }
    $script:form.Cursor = [System.Windows.Forms.Cursors]::Default
}

function Run-PreFlightDiagnostics {
    Show-ExecutionLogs
    $script:form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    Update-Status "Executing Deep Diagnostics..."
    Write-Terminal "--- INITIATING PRE-FLIGHT ENVIRONMENT AUDIT ---" "CyanAccent"
    [System.Windows.Forms.Application]::DoEvents()

    try {
        $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
        $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
        if ($freeGB -lt 10) { Write-Terminal "C:\ Drive Space: $freeGB GB (WARNING: LOW STORAGE)" "HeaderRed" }
        else { Write-Terminal "C:\ Drive Space: $freeGB GB" "StatusGreen" }

        $iis = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
        if ($iis) { Write-Terminal "IIS Service (W3SVC): $($iis.Status)" "StatusGreen" } 
        else { Write-Terminal "IIS Service (W3SVC): Not Installed / Not Found" "Yellow" }

        $sql = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
        if ($sql) { Write-Terminal "SQL Service (MSSQLSERVER): $($sql.Status)" "StatusGreen" } 
        else { Write-Terminal "SQL Service (MSSQLSERVER): Not Installed / Not Found" "Yellow" }

        Write-Terminal "Local PS Execution Policy: $(Get-ExecutionPolicy)" "TextWhite"

        Write-Terminal "Testing SFTP (sftp.prophoenix.com:25544)..." "Yellow"
        $sftpRes = Test-NetConnection -ComputerName "sftp.prophoenix.com" -Port 25544 -InformationLevel Quiet -WarningAction SilentlyContinue
        if ($sftpRes) { Write-Terminal "SFTP Connection: SUCCESS (OPEN)" "StatusGreen" }
        else { Write-Terminal "SFTP Connection: FAILED (BLOCKED)" "HeaderRed" }

        Write-Terminal "Purging Browser Cache & Temp Files..." "Yellow"
        $CachePaths = @("$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*", "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*", "$env:TEMP\*", "$env:WINDIR\Temp\*")
        foreach ($path in $CachePaths) { try { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue } catch {} }
        Write-Terminal "Cache Purge Complete." "StatusGreen"

        Update-Status "Diagnostics Completed Successfully."
    } catch { 
        Write-Terminal "Diagnostic Error: $_" "HeaderRed" 
        Update-Status "Diagnostic Error encountered." $true
    }
    Write-Terminal "--- PRE-FLIGHT AUDIT COMPLETE ---" "CyanAccent"
    $script:form.Cursor = [System.Windows.Forms.Cursors]::Default
}

# ==========================================================================
#  5. EXACT SORT ORDER, FIXED NAMING & HYBRID LAUNCH LOGIC
# ==========================================================================
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
    if ($fileName -match "32bitfalse") { return "App Pool False" }
    if ($fileName -match "SessionClear") { return "SVR Session Clear" }
    if ($fileName -match "SQLMemory") { return "SQL Memory Set" }
    if ($fileName -match "InstanceVerification") { return "Instance Verification" }
    if ($fileName -match "LaunchShortcuts") { return "Clients Auto Update" }
    if ($fileName -match "Autodbsync" -or $fileName -match "DB Sync") { return "DB Sync Tool" }
    if ($fileName -match "RMS" -and $fileName -match "PD") { return "RMS Server PD" }
    if ($fileName -match "Cad_Hotfix" -or $fileName -match "CAD PD" -or ($fileName -match "CAD" -and $fileName -match "PD")) { return "CAD Server PD" }
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
        "RMS Server PD" { return 2 }
        "CAD Server PD" { return 3 }
        "Test/Demo Hotfix" { return 4 }
        "Minimal Downtime (PS)" { return 5 }
        "Minimal Downtime (Batch)" { return 6 }
        "Minimal Downtime Deployment" { return 7 }
        "Instance Verification" { return 8 }
        "Clients Auto Update" { return 9 }
        "Log Cleaner" { return 10 }
        "App Pool False" { return 11 }
        "SVR Session Clear" { return 12 }
        "SQL Memory Set" { return 13 }
        default { return 50 } 
    }
}

function Set-FolderPermissions($path) {
    [System.Windows.Forms.Application]::DoEvents()
    try { 
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $aclArgs = "`"$path`" /grant `"Everyone:(OI)(CI)F`" `"IUSR:(OI)(CI)F`" `"NETWORK SERVICE:(OI)(CI)F`" `"${currentUser}:(OI)(CI)F`" /T /C /Q"
        Start-Process "icacls.exe" -ArgumentList $aclArgs -WindowStyle Hidden -Wait 
    } catch { Write-Terminal "Failed to apply ACLs: $_" "HeaderRed" }
}

function Unblock-ExtractedFiles($path) {
    [System.Windows.Forms.Application]::DoEvents()
    try { 
        Get-ChildItem -Path $path -Recurse -File | Unblock-File -ErrorAction SilentlyContinue 
    } catch {}
}

function Launch-File($path, $friendlyName) {
    if (-not (Test-Path $path)) { Write-Terminal "EXECUTION HALTED: File not found." "HeaderRed"; return }
    $workDir = Split-Path -Path $path -Parent
    Write-Terminal ">>> Launching Data Node: $friendlyName" "Magenta"
    Update-Status "Node Process Executing."

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
        Write-Terminal "Execution started successfully." "StatusGreen"
    } catch { Write-Terminal "CRITICAL LAUNCH FAILURE: $_" "HeaderRed"; Update-Status "Failed to launch node." $true }
}

function Refresh-List {
    $script:pnlTools.Controls.Clear()
    [int]$Y = 5
    
    if (-not $script:ToolsLoaded) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text="[ NO DATABANKS DETECTED ] Please click 'Search / Reload Master'."
        $lbl.AutoSize=$true
        $lbl.Left=10; $lbl.Top=10
        $lbl.Font=$script:Font_ItemText
        $lbl.BackColor=[System.Drawing.Color]::Transparent
        $lbl.ForeColor=Get-Color "TextGrey"
        $script:pnlTools.Controls.Add($lbl)
        return
    }

    Set-FolderPermissions $script:CurrentToolPath
    Unblock-ExtractedFiles $script:CurrentToolPath

    $Files = Get-ChildItem -Path $script:CurrentToolPath -Include *.ps1, *.bat -Recurse -File | Where-Object { $_.Name -notmatch "Prophoenix_Dashboard" }
    $SortedList = $Files | Select-Object Name, FullName, @{Name="Friendly"; Expression={Get-FriendlyName $_.Name}}, @{Name="Rank"; Expression={Get-SortOrder (Get-FriendlyName $_.Name)}} | Sort-Object Rank, Friendly
    
    foreach ($item in $SortedList) {
        # --- PRO-TECH DATA NODE CARD ---
        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size(860, 36)
        $card.Location = New-Object System.Drawing.Point(5, $Y)
        $card.BackColor = Get-Color "CardBg"
        $card.Cursor = "Hand"
        
        # Hover glow effect
        $card.Add_MouseEnter({ $this.BackColor = Get-Color "CardHover" }.GetNewClosure())
        $card.Add_MouseLeave({ $this.BackColor = Get-Color "CardBg" }.GetNewClosure())

        # Neon left border accent
        $accent = New-Object System.Windows.Forms.Panel
        $accent.Width = 3
        $accent.Dock = "Left"
        $accent.BackColor = Get-Color "CyanAccent"
        $card.Controls.Add($accent)

        $l = New-Object System.Windows.Forms.Label
        $l.Text = $item.Friendly 
        $l.Font = $script:Font_ItemText
        $l.Left = 15; $l.Top = 8; $l.Width = 650
        $l.BackColor = [System.Drawing.Color]::Transparent
        $l.ForeColor = Get-Color "TextWhite"
        $l.Add_MouseEnter({ $card.BackColor = Get-Color "CardHover" }.GetNewClosure())
        $l.Add_MouseLeave({ $card.BackColor = Get-Color "CardBg" }.GetNewClosure())
        $card.Controls.Add($l)
        
        $b = New-Object System.Windows.Forms.Button
        $b.Text = "EXECUTE"
        $b.Left = 750; $b.Top = 4
        $b.Size = New-Object System.Drawing.Size(90, 28) 
        $b.BackColor = Get-Color "BtnRun"
        $b.ForeColor = Get-Color "TextWhite"
        $b.FlatStyle = "Flat"
        $b.FlatAppearance.BorderSize = 0
        $b.Font = $script:Font_RunBtn
        $b.Cursor = "Hand"
        
        $b.Add_MouseEnter({ $this.BackColor = Get-Color "CyanAccent"; $this.ForeColor = Get-Color "Terminal" }.GetNewClosure())
        $b.Add_MouseLeave({ $this.BackColor = Get-Color "BtnRun"; $this.ForeColor = Get-Color "TextWhite" }.GetNewClosure())

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
    Update-Status "Scanning Root Directories..."
    Write-Terminal "======================================================" "TextWhite"
    Write-Terminal "INITIATING DEEP ENVIRONMENT SEARCH" "CyanAccent"
    
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
                Write-Terminal "Scanning Directory: $dir" "TextGrey"
                $zips = if ($loc.Recurse) { Get-ChildItem -Path $dir -Filter $ZipNamePattern -File -Recurse -Depth 3 -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending } 
                        else { Get-ChildItem -Path $dir -Filter $ZipNamePattern -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending }

                foreach ($zip in $zips) {
                    if (Test-ZipValidity $zip.FullName) {
                        $FoundZip = $zip.FullName
                        Write-Terminal "VERIFIED VALID ARCHIVE: $FoundZip" "StatusGreen"
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
                else { Update-Status "Manual archive is corrupt." $true; return }
            } else { Update-Status "Awaiting Input."; return }
        }

        if ($FoundZip) {
            [System.Windows.Forms.Application]::DoEvents()
            Write-Terminal "Staging payload for secure extraction..." "TextWhite"

            if (Test-Path "C:\PnxTemp\MasterTemp.zip") { Remove-Item "C:\PnxTemp\MasterTemp.zip" -Force -ErrorAction SilentlyContinue }
            if (-not (Test-Path "C:\PnxTemp")) { New-Item -ItemType Directory -Path "C:\PnxTemp" -Force | Out-Null }
            
            $LocalZip = "C:\PnxTemp\MasterTemp.zip"
            try { Copy-Item -Path $FoundZip -Destination $LocalZip -Force } catch {}
            try { 
                Expand-Archive -Path $LocalZip -DestinationPath $InstallBase -Force 
                Write-Terminal "Extraction 100% complete." "StatusGreen"
            } catch { Update-Status "Extraction Fatal Error." $true; return }
            
            $script:CurrentToolPath = $InstallBase
            $Nested = Join-Path $InstallBase "Phoenix Installation Master"
            if (Test-Path $Nested) { $script:CurrentToolPath = $Nested }

            Set-FolderPermissions $script:CurrentToolPath
            Unblock-ExtractedFiles $script:CurrentToolPath

            $script:ToolsLoaded = $true
            Refresh-List
            Update-Status "Master Loaded Successfully."
            Write-Terminal "System Armed and Operational." "CyanAccent"
        }
    } finally {
        $script:form.Cursor = [System.Windows.Forms.Cursors]::Default
    }
}

# ==========================================================================
#  6. ADVANCED TELEMETRY GATHERING
# ==========================================================================
$HostName = [System.Net.Dns]::GetHostName()
$IpAddress = "127.0.0.1"
try {
    $PrimaryAdapter = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" | Where-Object { $_.DefaultIPGateway -ne $null } | Select-Object -First 1
    if ($PrimaryAdapter) { $IpAddress = $PrimaryAdapter.IPAddress | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -First 1 }
} catch {}

# ==========================================================================
#  7. ULTIMATE PRO-TECH UI BUILD
# ==========================================================================
$script:form = New-Object System.Windows.Forms.Form
$script:form.Text = "ProPhoenix Installation Dashboard v127.1"
$script:form.Size = New-Object System.Drawing.Size(1200, 850)
$script:form.StartPosition = "CenterScreen"
$script:form.BackColor = Get-Color "BgMain"
Enable-AdvancedDoubleBuffering $script:form

$LogoPath = Join-Path -Path $ScriptPath -ChildPath "Logo.png" -ErrorAction SilentlyContinue

# --- LEFT SIDEBAR (Dark Obsidian) ---
$script:pnlSide = New-Object System.Windows.Forms.Panel; $script:pnlSide.Dock="Left"; $script:pnlSide.Width=240; $script:pnlSide.BackColor=Get-Color "SideBg"
$script:pnlSideBorder = New-Object System.Windows.Forms.Panel; $script:pnlSideBorder.Dock="Right"; $script:pnlSideBorder.Width=1; $script:pnlSideBorder.BackColor=Get-Color "CardBg"
$script:pnlSide.Controls.Add($script:pnlSideBorder)
$script:form.Controls.Add($script:pnlSide)

function Add-SideHeader($Text, $Top, $ColorName) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "[ $Text ]"
    $lbl.Font = $script:Font_SideHead; $lbl.ForeColor = Get-Color $ColorName
    $lbl.AutoSize = $false; $lbl.Width = 240; $lbl.TextAlign = "MiddleCenter"; $lbl.Left = 0; $lbl.Top = $Top;
    $script:pnlSide.Controls.Add($lbl)
}

function Add-SidePillButton($Text, $Top, $BgColorName, $HoverColorName, $Action) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text; $btn.Font = $script:Font_SideBtn; $btn.ForeColor = Get-Color "TextWhite"; $btn.BackColor = Get-Color $BgColorName
    $btn.FlatStyle = "Flat"; $btn.FlatAppearance.BorderSize = 0; $btn.Cursor = "Hand"
    $btn.Size = New-Object System.Drawing.Size(200, 35)
    $btn.Left = 20; $btn.Top = $Top 
    $btn.Add_MouseEnter({ $this.BackColor = Get-Color $HoverColorName }.GetNewClosure())
    $btn.Add_MouseLeave({ $this.BackColor = Get-Color $BgColorName }.GetNewClosure())
    $btn.Add_Click($Action)
    $script:pnlSide.Controls.Add($btn)
}

Add-SideHeader "SYS_GENERAL" 30 "HeaderRed"
Add-SidePillButton "Search / Reload Master" 60 "BtnRed" "BtnRedHover" { Search-Master }
Add-SidePillButton "Download Azure Blob" 105 "BtnBlue" "BtnBlueHover" { Start-Process $Url_Blob }
Add-SidePillButton "Download Google Drive" 150 "BtnBlue" "BtnBlueHover" { Start-Process $Url_GDrive }

Add-SideHeader "SYS_DIAGNOSTICS" 210 "CyanAccent"
Add-SidePillButton "Open System Logs" 240 "BtnBlue" "BtnBlueHover" { if(Test-Path (Ensure-LogDir)){ Invoke-Item (Ensure-LogDir) } }
Add-SidePillButton "Check Public IP" 285 "BtnBlue" "BtnBlueHover" { Check-PublicIP }
Add-SidePillButton "Run Diagnostics" 330 "BtnBlue" "BtnBlueHover" { Run-PreFlightDiagnostics }

Add-SideHeader "SYS_CONTROL" 700 "TextGrey"
Add-SidePillButton "Exit Dashboard" 730 "BtnRed" "BtnRedHover" { $script:form.Close() }

# --- TOP MAIN HEADER AREA ---
$script:pnlHead = New-Object System.Windows.Forms.Panel; $script:pnlHead.Dock="Top"; $script:pnlHead.Height=120; $script:pnlHead.BackColor=[System.Drawing.Color]::Transparent; $script:form.Controls.Add($script:pnlHead)

# DYNAMIC BRAND LOGO RENDERER: PROPH [Logo] ENIX 
$pnlBrandFlow = New-Object System.Windows.Forms.FlowLayoutPanel
$pnlBrandFlow.Left = 260; $pnlBrandFlow.Top = 25; $pnlBrandFlow.Width = 800; $pnlBrandFlow.Height = 45
$pnlBrandFlow.BackColor = [System.Drawing.Color]::Transparent; $pnlBrandFlow.WrapContents = $false
$script:pnlHead.Controls.Add($pnlBrandFlow)

$lblProPh = New-Object System.Windows.Forms.Label; $lblProPh.Text = "PROPH"; $lblProPh.Font = $script:Font_Brand; $lblProPh.ForeColor = Get-Color "BrandRed"
$lblProPh.AutoSize = $true; $lblProPh.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 0); $pnlBrandFlow.Controls.Add($lblProPh)

$picInline = New-Object System.Windows.Forms.PictureBox; $picInline.Size = New-Object System.Drawing.Size(32, 32); $picInline.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
$picInline.Margin = New-Object System.Windows.Forms.Padding(-2, 4, -2, 0) 
if ($null -ne $LogoPath -and (Test-Path $LogoPath)) { $picInline.Image = [System.Drawing.Image]::FromFile($LogoPath) }
$pnlBrandFlow.Controls.Add($picInline)

$lblEnix = New-Object System.Windows.Forms.Label; $lblEnix.Text = "ENIX"; $lblEnix.Font = $script:Font_Brand; $lblEnix.ForeColor = Get-Color "BrandRed"
$lblEnix.AutoSize = $true; $lblEnix.Margin = New-Object System.Windows.Forms.Padding(0, 0, 15, 0); $pnlBrandFlow.Controls.Add($lblEnix)

$lblDashTitle = New-Object System.Windows.Forms.Label; $lblDashTitle.Text = "INSTALLATION DASHBOARD"; $lblDashTitle.Font = $script:Font_MainTitle; $lblDashTitle.ForeColor = Get-Color "TextWhite"
$lblDashTitle.AutoSize = $true; $lblDashTitle.Margin = New-Object System.Windows.Forms.Padding(0, 6, 0, 0); $pnlBrandFlow.Controls.Add($lblDashTitle)

$lblSubTitle = New-Object System.Windows.Forms.Label; $lblSubTitle.Text="// EMPOWERING PUBLIC SAFETY THROUGH INNOVATION // EXTRACT AND EXECUTE SEAMLESSLY //"; $lblSubTitle.Font=$script:Font_SubTitle; $lblSubTitle.Left=265; $lblSubTitle.Top=70; $lblSubTitle.AutoSize=$true; $lblSubTitle.ForeColor=Get-Color "CyanAccent"; $script:pnlHead.Controls.Add($lblSubTitle)

# --- TELEMETRY CARDS (Tech Style) ---
$pnlTelemetryWrapper = New-Object System.Windows.Forms.Panel; $pnlTelemetryWrapper.Width = 420; $pnlTelemetryWrapper.Height = 60; $pnlTelemetryWrapper.Top = 30; $pnlTelemetryWrapper.Left = 740; $pnlTelemetryWrapper.BackColor = [System.Drawing.Color]::Transparent; $script:pnlHead.Controls.Add($pnlTelemetryWrapper)

$pnlCardLeft = New-Object System.Windows.Forms.Panel; $pnlCardLeft.Width = 190; $pnlCardLeft.Height = 55; $pnlCardLeft.BackColor = Get-Color "CardBg"; $pnlTelemetryWrapper.Controls.Add($pnlCardLeft)
$pnlCardLeftAccent = New-Object System.Windows.Forms.Panel; $pnlCardLeftAccent.Width = 2; $pnlCardLeftAccent.Dock = "Left"; $pnlCardLeftAccent.BackColor = Get-Color "StatusGreen"; $pnlCardLeft.Controls.Add($pnlCardLeftAccent)
$lblSystemStatus = New-Object System.Windows.Forms.Label; $lblSystemStatus.Text="NODE_STATUS"; $lblSystemStatus.Font=$script:Font_Card_Lbl; $lblSystemStatus.ForeColor=Get-Color "TextGrey"; $lblSystemStatus.Left=10; $lblSystemStatus.Top=8; $lblSystemStatus.AutoSize=$true; $pnlCardLeft.Controls.Add($lblSystemStatus)
$script:lblSystemStatusVal = New-Object System.Windows.Forms.Label; $script:lblSystemStatusVal.Text="ONLINE"; $script:lblSystemStatusVal.Font=$script:Font_Card_Val; $script:lblSystemStatusVal.ForeColor=Get-Color "StatusGreen"; $script:lblSystemStatusVal.Left=100; $script:lblSystemStatusVal.Top=7; $script:lblSystemStatusVal.AutoSize=$true; $pnlCardLeft.Controls.Add($script:lblSystemStatusVal)
$lblSessionTime = New-Object System.Windows.Forms.Label; $lblSessionTime.Text="UPTIME"; $lblSessionTime.Font=$script:Font_Card_Lbl; $lblSessionTime.ForeColor=Get-Color "TextGrey"; $lblSessionTime.Left=10; $lblSessionTime.Top=30; $lblSessionTime.AutoSize=$true; $pnlCardLeft.Controls.Add($lblSessionTime)
$script:lblSessionTimeVal = New-Object System.Windows.Forms.Label; $script:lblSessionTimeVal.Text="00:00:00"; $script:lblSessionTimeVal.Font=$script:Font_Card_Val; $script:lblSessionTimeVal.ForeColor=Get-Color "CyanAccent"; $script:lblSessionTimeVal.Left=100; $script:lblSessionTimeVal.Top=29; $script:lblSessionTimeVal.AutoSize=$true; $pnlCardLeft.Controls.Add($script:lblSessionTimeVal)

$pnlCardRight = New-Object System.Windows.Forms.Panel; $pnlCardRight.Width = 220; $pnlCardRight.Height = 55; $pnlCardRight.Left = 200; $pnlCardRight.BackColor = Get-Color "CardBg"; $pnlTelemetryWrapper.Controls.Add($pnlCardRight)
$pnlCardRightAccent = New-Object System.Windows.Forms.Panel; $pnlCardRightAccent.Width = 2; $pnlCardRightAccent.Dock = "Left"; $pnlCardRightAccent.BackColor = Get-Color "CyanAccent"; $pnlCardRight.Controls.Add($pnlCardRightAccent)
$lblHostname = New-Object System.Windows.Forms.Label; $lblHostname.Text="HOST_ID"; $lblHostname.Font=$script:Font_Card_Lbl; $lblHostname.ForeColor=Get-Color "TextGrey"; $lblHostname.Left=10; $lblHostname.Top=8; $lblHostname.AutoSize=$true; $pnlCardRight.Controls.Add($lblHostname)
$lblHostnameVal = New-Object System.Windows.Forms.Label; $lblHostnameVal.Text=$HostName; $lblHostnameVal.Font=$script:Font_Card_Val; $lblHostnameVal.ForeColor=Get-Color "TextWhite"; $lblHostnameVal.Left=75; $lblHostnameVal.Top=7; $lblHostnameVal.AutoSize=$true; $pnlCardRight.Controls.Add($lblHostnameVal)
$lblIpAddress = New-Object System.Windows.Forms.Label; $lblIpAddress.Text="NET_IPv4"; $lblIpAddress.Font=$script:Font_Card_Lbl; $lblIpAddress.ForeColor=Get-Color "TextGrey"; $lblIpAddress.Left=10; $lblIpAddress.Top=30; $lblIpAddress.AutoSize=$true; $pnlCardRight.Controls.Add($lblIpAddress)
$lblIpAddressVal = New-Object System.Windows.Forms.Label; $lblIpAddressVal.Text=$IpAddress; $lblIpAddressVal.Font=$script:Font_Card_Val; $lblIpAddressVal.ForeColor=Get-Color "CyanAccent"; $lblIpAddressVal.Left=75; $lblIpAddressVal.Top=29; $lblIpAddressVal.AutoSize=$true; $pnlCardRight.Controls.Add($lblIpAddressVal)

$script:TelemetryTimer = New-Object System.Windows.Forms.Timer; $script:TelemetryTimer.Interval = 1000; 
$script:TelemetryTimer.Add_Tick({ Update-TelemetryDisplay })

# --- TAB BAR & STATUS LABEL (DUAL SCREEN TABS) ---
$script:pnlTabs = New-Object System.Windows.Forms.Panel; $script:pnlTabs.Top=120; $script:pnlTabs.Left=260; $script:pnlTabs.Width=900; $script:pnlTabs.Height=40; $script:pnlTabs.BackColor=[System.Drawing.Color]::Transparent; $script:form.Controls.Add($script:pnlTabs)

$script:btnTabScripts = New-Object System.Windows.Forms.Button; $script:btnTabScripts.Text="AVAILABLE SCRIPTS"; $script:btnTabScripts.Font=$script:Font_SideHead; $script:btnTabScripts.Size=New-Object System.Drawing.Size(360, 40); $script:btnTabScripts.Left=0; $script:btnTabScripts.BackColor=Get-Color "CardBg"; $script:btnTabScripts.ForeColor=Get-Color "CyanAccent"; $script:btnTabScripts.FlatStyle="Flat"; $script:btnTabScripts.FlatAppearance.BorderSize=1; $script:btnTabScripts.FlatAppearance.BorderColor=Get-Color "CyanAccent"; $script:btnTabScripts.Cursor="Hand"; $script:pnlTabs.Controls.Add($script:btnTabScripts)

$script:btnTabLogs = New-Object System.Windows.Forms.Button; $script:btnTabLogs.Text="EXECUTION LOGS"; $script:btnTabLogs.Font=$script:Font_SideHead; $script:btnTabLogs.Size=New-Object System.Drawing.Size(360, 40); $script:btnTabLogs.Left=370; $script:btnTabLogs.BackColor=Get-Color "BgMain"; $script:btnTabLogs.ForeColor=Get-Color "TextGrey"; $script:btnTabLogs.FlatStyle="Flat"; $script:btnTabLogs.FlatAppearance.BorderSize=0; $script:btnTabLogs.Cursor="Hand"; $script:pnlTabs.Controls.Add($script:btnTabLogs)

$script:btnRefresh = New-Object System.Windows.Forms.Button
$script:btnRefresh.Text = "↻ REFRESH"
$script:btnRefresh.Font = $script:Font_SideHead
$script:btnRefresh.Size = New-Object System.Drawing.Size(120, 40)
$script:btnRefresh.Left = 750
$script:btnRefresh.BackColor = Get-Color "BtnBlue"
$script:btnRefresh.ForeColor = Get-Color "TextWhite"
$script:btnRefresh.FlatStyle = "Flat"
$script:btnRefresh.FlatAppearance.BorderSize = 0
$script:btnRefresh.Cursor = "Hand"
$script:btnRefresh.Add_MouseEnter({ $this.BackColor = Get-Color "BtnBlueHover" }.GetNewClosure())
$script:btnRefresh.Add_MouseLeave({ $this.BackColor = Get-Color "BtnBlue" }.GetNewClosure())
$script:btnRefresh.Add_Click({ Refresh-List; Update-Status "List Refreshed Successfully." })
$script:pnlTabs.Controls.Add($script:btnRefresh)

$script:lblStatus = New-Object System.Windows.Forms.Label; $script:lblStatus.Text="[ SYS.STATUS ] :: Ready."; $script:lblStatus.Font=$script:Font_Status; $script:lblStatus.Left=260; $script:lblStatus.Top=170; $script:lblStatus.AutoSize=$true; $script:lblStatus.ForeColor=Get-Color "StatusGreen"; $script:form.Controls.Add($script:lblStatus)

# --- MAIN TOOLS AREA (HOLDS BOTH LIST AND CONSOLE) ---
$script:pnlToolsWrapper = New-Object System.Windows.Forms.Panel; $script:pnlToolsWrapper.Left=260; $script:pnlToolsWrapper.Top=200; $script:pnlToolsWrapper.Size=New-Object System.Drawing.Size(910, 600); $script:pnlToolsWrapper.BackColor=[System.Drawing.Color]::Transparent; $script:form.Controls.Add($script:pnlToolsWrapper)
Enable-AdvancedDoubleBuffering $script:pnlToolsWrapper

if ($null -ne $LogoPath -and (Test-Path $LogoPath)) {
    $script:pnlToolsWrapper.BackgroundImage = [System.Drawing.Image]::FromFile($LogoPath)
    $script:pnlToolsWrapper.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Zoom
}

# 1. The Script List Panel (With Dark Transparent Overlay for Watermark)
$script:pnlTools = New-Object System.Windows.Forms.Panel; $script:pnlTools.Dock="Fill"
$script:pnlTools.AutoScroll=$false; 
$script:pnlTools.BackColor=[System.Drawing.Color]::FromArgb(210, 10, 14, 23); 
$script:pnlToolsWrapper.Controls.Add($script:pnlTools)
Enable-AdvancedDoubleBuffering $script:pnlTools

# 2. The Execution Logs Panel (Hidden by default)
$script:pnlConsole = New-Object System.Windows.Forms.Panel; $script:pnlConsole.Dock="Fill"; $script:pnlConsole.BackColor=Get-Color "Terminal"; $script:pnlConsole.Visible=$false
$consoleBorder = New-Object System.Windows.Forms.Panel; $consoleBorder.Dock="Fill"; $consoleBorder.Padding=New-Object System.Windows.Forms.Padding(2); $consoleBorder.BackColor=Get-Color "CardBg"
$script:pnlConsole.Controls.Add($consoleBorder)

$script:TermConsole = New-Object System.Windows.Forms.RichTextBox
$script:TermConsole.Dock="Fill"; $script:TermConsole.BackColor=Get-Color "Terminal"; $script:TermConsole.ForeColor=Get-Color "TextWhite"; $script:TermConsole.Font=$script:Font_Term; $script:TermConsole.ReadOnly=$true; $script:TermConsole.BorderStyle="None"
$consoleBorder.Controls.Add($script:TermConsole)
$script:pnlToolsWrapper.Controls.Add($script:pnlConsole)

# --- DUAL SCREEN TAB CLICK EVENTS ---
$script:btnTabScripts.Add_Click({
    $script:form.SuspendLayout()
    $script:pnlConsole.Visible = $false
    $script:pnlTools.Visible = $true
    $script:btnTabScripts.BackColor = Get-Color "CardBg"
    $script:btnTabScripts.ForeColor = Get-Color "CyanAccent"
    $script:btnTabScripts.FlatAppearance.BorderSize = 1
    $script:btnTabScripts.FlatAppearance.BorderColor = Get-Color "CyanAccent"
    $script:btnTabLogs.BackColor = Get-Color "BgMain"
    $script:btnTabLogs.ForeColor = Get-Color "TextGrey"
    $script:btnTabLogs.FlatAppearance.BorderSize = 0
    $script:form.ResumeLayout($true)
    $script:pnlToolsWrapper.Invalidate($true)
})

$script:btnTabLogs.Add_Click({
    Show-ExecutionLogs
})

# --- EXECUTE ON STARTUP (SILENT PERMISSIONS) ---
$script:form.Add_Shown({ 
    $script:form.Activate()
    $script:TelemetryTimer.Start()
    
    if (Test-Path $InstallBase) {
        Update-Status "Verifying System Security..."
        Write-Terminal "Payload detected at startup. Verifying System Security..." "CyanAccent"
        [System.Windows.Forms.Application]::DoEvents()
        
        $script:CurrentToolPath = $InstallBase
        $Nested = Join-Path $InstallBase "Phoenix Installation Master"
        if (Test-Path $Nested) { $script:CurrentToolPath = $Nested }
        
        Set-FolderPermissions $script:CurrentToolPath
        Unblock-ExtractedFiles $script:CurrentToolPath
        
        $script:ToolsLoaded = $true
        Refresh-List
        Update-Status "Master Loaded Successfully."
        Write-Terminal "Dashboard Armed and Operational." "StatusGreen"
    } else {
        Search-Master 
    }
})
[void] $script:form.ShowDialog()