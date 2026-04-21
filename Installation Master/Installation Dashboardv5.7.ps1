<#
.SYNOPSIS
    ProPhoenix Enterprise Deployment Dashboard (v120.0)
    - UI UPDATE: Title and Subtitle updated to match brand messaging.
    - UI UPDATE: Added 'Refresh' button to tab bar for quick list updating.
    - UI UPDATE: Compressed list card spacing to fit 15+ scripts with ZERO scrolling.
    - LOGIC FIX: Replaced SFTP sidebar button with 'Check Public IP'.
    - LOGIC FIX: Merged SFTP testing directly into the 'Run Diagnostics' automated flow.
    - SYSTEM FIX: Deep C# injection completely hides the background PowerShell console on launch.
#>

# ==============================================================================
#  0. INSTANT BACKGROUND CONSOLE HIDE (Native App Mode)
# ==============================================================================
if ($host.Name -notmatch "ISE") {
    $code = '[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);'
    $type = Add-Type -MemberDefinition $code -Name "Win32ShowWindowAsync" -Namespace Win32Functions -PassThru
    $hwnd = (Get-Process -Id $PID).MainWindowHandle
    if ($hwnd -ne [IntPtr]::Zero) { $type::ShowWindow($hwnd, 0) }
}

Write-Host "[INIT] Booting ProPhoenix Enterprise Command Center v120.0..." -ForegroundColor Cyan

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
    if ($host.Name -notmatch "ISE") { $type::ShowWindow($hwnd, 5) } # Show window again to display prompt
    Write-Host "[WARN] Administrative privileges required. Escalating..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    Exit
}

# ==============================================================================
#  2. GLOBAL ASSEMBLIES & THEME DEFINITIONS
# ==============================================================================
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    function Get-Color($name) {
        switch($name) {
            "BgMain"       { return [System.Drawing.Color]::FromArgb(24, 25, 32) }
            "SideBg"       { return [System.Drawing.Color]::FromArgb(15, 15, 20) }
            "CardBg"       { return [System.Drawing.Color]::FromArgb(35, 35, 45) }
            "CardHover"    { return [System.Drawing.Color]::FromArgb(45, 45, 55) }
            "BtnRun"       { return [System.Drawing.Color]::FromArgb(55, 55, 65) }
            "BtnRed"       { return [System.Drawing.Color]::FromArgb(85, 25, 30) }
            "BtnRedHover"  { return [System.Drawing.Color]::FromArgb(115, 35, 40) }
            "BtnBlue"      { return [System.Drawing.Color]::FromArgb(15, 60, 110) }
            "BtnBlueHover" { return [System.Drawing.Color]::FromArgb(25, 80, 140) }
            "HeaderRed"    { return [System.Drawing.Color]::FromArgb(220, 70, 70) }
            "TextWhite"    { return [System.Drawing.Color]::FromArgb(240, 240, 240) }
            "TextGrey"     { return [System.Drawing.Color]::FromArgb(160, 160, 170) }
            "StatusGreen"  { return [System.Drawing.Color]::FromArgb(60, 200, 100) }
            "Terminal"     { return [System.Drawing.Color]::FromArgb(10, 10, 14) }
            "PhxOrange"    { return [System.Drawing.Color]::FromArgb(244, 162, 97) }
            "Cyan"         { return [System.Drawing.Color]::Cyan }
            "Lime"         { return [System.Drawing.Color]::Lime }
            "Red"          { return [System.Drawing.Color]::Red }
            "Yellow"       { return [System.Drawing.Color]::Yellow }
            "Magenta"      { return [System.Drawing.Color]::Magenta }
            "LightGray"    { return [System.Drawing.Color]::LightGray }
            default        { return [System.Drawing.Color]::White }
        }
    }

    $script:Font_MainTitle = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
    $script:Font_SubTitle  = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    $script:Font_SideHead  = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $script:Font_SideBtn   = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $script:Font_ItemText  = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold) # Reduced slightly to fit more
    $script:Font_RunBtn    = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $script:Font_Status    = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
    $script:Font_Card_Lbl  = New-Object System.Drawing.Font("Segoe UI", 8, [System.Drawing.FontStyle]::Bold)
    $script:Font_Card_Val  = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Bold)
    $script:Font_Term      = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Regular)

    $Url_GDrive   = "https://drive.google.com/uc?export=download&id=10RxuJaWwqR1S6lbkjL0-_AXddCwOARYI"
    $Url_Blob     = "https://produpdates.blob.core.windows.net/web/Prerequisite%20Script%202026/Phoenix%20Installation%20Master.zip?sp=racw&st=2026-01-30T14:01:41Z&se=2032-03-30T22:16:41Z&spr=https&sv=2024-11-04&sr=b&sig=3vXVuby1lcDbQ%2BQQnVzxmmXJsyaRG2sgQwTH9SzPnh4%3D"
    $ZipNamePattern = "Phoenix Installation Master*.zip"
    $InstallBase    = "C:\pnxtemp\Phoenix Installation Master"
    $script:CurrentToolPath = $InstallBase 
    $script:ToolsLoaded = $false

    # ==========================================================================
    #  3. SYSADMIN LOGGING ENGINE & LIVE STATUS UPDATER
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
            $script:lblStatus.Text = "Status: $msg"
            if ($isError) { $script:lblStatus.ForeColor = Get-Color "HeaderRed" }
            else { $script:lblStatus.ForeColor = Get-Color "StatusGreen" }
            $script:lblStatus.Refresh()
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
    #  4. ADVANCED DIAGNOSTICS & PUBLIC IP (MERGED SFTP)
    # ==========================================================================
    function Check-PublicIP {
        $script:form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        Update-Status "Checking Public IP..."
        if (-not $script:pnlConsole.Visible -and $script:btnToggleLog) { $script:btnToggleLog.PerformClick() }
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

    function Run-PreFlightDiagnostics {
        $script:form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        Update-Status "Running System Diagnostics..."
        if (-not $script:pnlConsole.Visible -and $script:btnToggleLog) { $script:btnToggleLog.PerformClick() }
        Write-Terminal "--- INITIATING PRE-FLIGHT ENVIRONMENT AUDIT ---" "Cyan"
        [System.Windows.Forms.Application]::DoEvents()

        try {
            # 1. Drive Check
            $disk = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
            $freeGB = [math]::Round($disk.FreeSpace / 1GB, 2)
            if ($freeGB -lt 10) { Write-Terminal "C:\ Drive Space: $freeGB GB (WARNING: LOW STORAGE)" "Red" }
            else { Write-Terminal "C:\ Drive Space: $freeGB GB" "Lime" }

            # 2. IIS Check
            $iis = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
            if ($iis) { Write-Terminal "IIS Service (W3SVC): $($iis.Status)" "Lime" } 
            else { Write-Terminal "IIS Service (W3SVC): Not Installed / Not Found" "Yellow" }

            # 3. SQL Check
            $sql = Get-Service -Name MSSQLSERVER -ErrorAction SilentlyContinue
            if ($sql) { Write-Terminal "SQL Service (MSSQLSERVER): $($sql.Status)" "Lime" } 
            else { Write-Terminal "SQL Service (MSSQLSERVER): Not Installed / Not Found" "Yellow" }

            # 4. Exec Policy Check
            Write-Terminal "Local PS Execution Policy: $(Get-ExecutionPolicy)" "White"

            # 5. SFTP Check (MERGED AS REQUESTED)
            Write-Terminal "Testing SFTP (sftp.prophoenix.com:25544)..." "Yellow"
            $sftpRes = Test-NetConnection -ComputerName "sftp.prophoenix.com" -Port 25544 -InformationLevel Quiet -WarningAction SilentlyContinue
            if ($sftpRes) { Write-Terminal "SFTP Connection: SUCCESS (OPEN)" "Lime" }
            else { Write-Terminal "SFTP Connection: FAILED (BLOCKED)" "Red" }

            # 6. Browser Cache Purge
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

    # ==========================================================================
    #  5. EXACT SORT ORDER, FIXED NAMING & LAUNCH LOGIC
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

        # Catch all for future scripts (like Instance Update Script)
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
            default { return 50 } # Places new scripts below standard ones
        }
    }

    function Set-FolderPermissions($path) {
        Write-Terminal "Applying advanced ACLs to Directory..." "Yellow"
        try { 
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            $aclArgs = "`"$path`" /grant `"Everyone:(OI)(CI)F`" `"IUSR:(OI)(CI)F`" `"NETWORK SERVICE:(OI)(CI)F`" `"${currentUser}:(OI)(CI)F`" /T /C /Q"
            Start-Process "icacls.exe" -ArgumentList $aclArgs -WindowStyle Hidden -Wait 
            Write-Terminal "ACLs successfully applied." "Lime"
        } catch { Write-Terminal "Failed to apply ACLs: $_" "Red" }
    }

    function Unblock-ExtractedFiles($path) {
        Write-Terminal "Unblocking script files..." "Yellow"
        try { 
            Get-ChildItem -Path $path -Recurse -File | Unblock-File -ErrorAction SilentlyContinue 
            Write-Terminal "Files successfully unblocked." "Lime"
        } catch {}
    }

    function Launch-File($path, $friendlyName) {
        if (-not (Test-Path $path)) { Write-Terminal "EXECUTION HALTED: File not found." "Red"; return }
        $workDir = Split-Path -Path $path -Parent
        Write-Terminal ">>> Launching: $friendlyName" "Magenta"
        Update-Status "Script launched successfully."

        try {
            if ($path -match "\.bat$") { 
                Start-Process "cmd.exe" -ArgumentList "/c `"$path`" & pause" -Verb RunAs -WorkingDirectory $workDir 
            } else { 
                Start-Process "powershell_ise.exe" -ArgumentList "-File `"$path`"" -Verb RunAs -WorkingDirectory $workDir 
            }
            Write-Terminal "Execution started." "Lime"
        } catch { Write-Terminal "CRITICAL LAUNCH FAILURE: $_" "Red"; Update-Status "Failed to launch script." $true }
    }

    function Refresh-List {
        $script:pnlTools.Controls.Clear()
        [int]$Y = 5
        
        if (-not $script:ToolsLoaded) {
            $lbl = New-Object System.Windows.Forms.Label
            $lbl.Text="No Scripts Detected. Please click 'Search / Reload Master'."
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
            # --- COMPRESSED ROW DESIGN TO FIT 15+ ITEMS W/O SCROLLING ---
            $card = New-Object System.Windows.Forms.Panel
            $card.Size = New-Object System.Drawing.Size(860, 26) # Shrunk height
            $card.Location = New-Object System.Drawing.Point(5, $Y)
            $card.BackColor = Get-Color "CardBg"
            $card.Cursor = "Hand"
            
            $card.Add_MouseEnter({ $this.BackColor = Get-Color "CardHover" }.GetNewClosure())
            $card.Add_MouseLeave({ $this.BackColor = Get-Color "CardBg" }.GetNewClosure())

            $l = New-Object System.Windows.Forms.Label
            $l.Text = $item.Friendly 
            $l.Font = $script:Font_ItemText
            $l.Left = 15; $l.Top = 4; $l.Width = 650
            $l.BackColor = [System.Drawing.Color]::Transparent
            $l.ForeColor = Get-Color "TextWhite"
            $l.Add_MouseEnter({ $card.BackColor = Get-Color "CardHover" }.GetNewClosure())
            $l.Add_MouseLeave({ $card.BackColor = Get-Color "CardBg" }.GetNewClosure())
            $card.Controls.Add($l)
            
            $b = New-Object System.Windows.Forms.Button
            $b.Text = "LAUNCH"
            $b.Left = 750; $b.Top = 2
            $b.Size = New-Object System.Drawing.Size(90, 22) # Shrunk button
            $b.BackColor = Get-Color "BtnRun"
            $b.ForeColor = Get-Color "TextWhite"
            $b.FlatStyle = "Flat"
            $b.FlatAppearance.BorderSize = 0
            $b.Font = $script:Font_RunBtn
            $b.Cursor = "Hand"
            
            $b.Add_MouseEnter({ $this.BackColor = Get-Color "PhxOrange"; $this.ForeColor = Get-Color "BgMain" }.GetNewClosure())
            $b.Add_MouseLeave({ $this.BackColor = Get-Color "BtnRun"; $this.ForeColor = Get-Color "TextWhite" }.GetNewClosure())

            $path = $item.FullName; $name = $item.Friendly
            $action = { Launch-File $path $name }.GetNewClosure()
            $b.Add_Click($action)
            $card.Controls.Add($b)
            
            $script:pnlTools.Controls.Add($card)
            $Y += 28 # Small increment allows exactly 15 scripts
        }
        if ($Global:btnToggleLog) { $Global:btnToggleLog.BringToFront() }
    }

    function Search-Master {
        $script:form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        Update-Status "Scanning for Master..."
        if (-not $script:pnlConsole.Visible -and $script:btnToggleLog) { $script:btnToggleLog.PerformClick() }
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
    #  6. ADVANCED TELEMETRY GATHERING
    # ==========================================================================
    $HostName = [System.Net.Dns]::GetHostName()
    $IpAddress = "127.0.0.1"
    try {
        $PrimaryAdapter = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'" | Where-Object { $_.DefaultIPGateway -ne $null } | Select-Object -First 1
        if ($PrimaryAdapter) { $IpAddress = $PrimaryAdapter.IPAddress | Where-Object { $_ -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$' } | Select-Object -First 1 }
    } catch {}

    # ==========================================================================
    #  7. ULTIMATE UI BUILD
    # ==========================================================================
    $script:form = New-Object System.Windows.Forms.Form
    $script:form.Text = "ProPhoenix Installation Dashboard"
    $script:form.Size = New-Object System.Drawing.Size(1200, 850)
    $script:form.StartPosition = "CenterScreen"
    $script:form.BackColor = Get-Color "BgMain"
    Enable-AdvancedDoubleBuffering $script:form

    $LogoPath = Join-Path -Path $ScriptPath -ChildPath "Logo.png" -ErrorAction SilentlyContinue

    # --- LEFT SIDEBAR ---
    $script:pnlSide = New-Object System.Windows.Forms.Panel; $script:pnlSide.Dock="Left"; $script:pnlSide.Width=240; $script:pnlSide.BackColor=Get-Color "SideBg"; $script:form.Controls.Add($script:pnlSide)

    $LogoBoxLeft = New-Object System.Windows.Forms.PictureBox
    $LogoBoxLeft.Size = New-Object System.Drawing.Size(240, 80) 
    $LogoBoxLeft.Location = New-Object System.Drawing.Point(0, 20)
    $LogoBoxLeft.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    if ($null -ne $LogoPath -and (Test-Path $LogoPath)) { $LogoBoxLeft.Image = [System.Drawing.Image]::FromFile($LogoPath) }
    $script:pnlSide.Controls.Add($LogoBoxLeft)

    $lblBrand = New-Object System.Windows.Forms.Label
    $lblBrand.Text = "INSTALLATION"
    $lblBrand.Font = $script:Font_Title
    $lblBrand.ForeColor = Get-Color "TextWhite"
    $lblBrand.AutoSize = $false; $lblBrand.Width = 240; $lblBrand.TextAlign = "MiddleCenter"; $lblBrand.Left = 0; $lblBrand.Top = 100;
    $script:pnlSide.Controls.Add($lblBrand)

    $lblSub = New-Object System.Windows.Forms.Label
    $lblSub.Text = "DASHBOARD"
    $lblSub.Font = $script:Font_SideBtn
    $lblSub.ForeColor = Get-Color "PhxOrange"
    $lblSub.AutoSize = $false; $lblSub.Width = 240; $lblSub.TextAlign = "MiddleCenter"; $lblSub.Left = 0; $lblSub.Top = 135;
    $script:pnlSide.Controls.Add($lblSub)

    function Add-SideHeader($Text, $Top, $ColorName) {
        $lbl = New-Object System.Windows.Forms.Label
        $lbl.Text = $Text; $lbl.Font = $script:Font_SideHead; $lbl.ForeColor = Get-Color $ColorName
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

    # RESTORED SIDEBAR BUTTONS
    Add-SideHeader "General" 180 "HeaderRed"
    Add-SidePillButton "Search / Reload Master" 210 "BtnRed" "BtnRedHover" { Search-Master }
    Add-SidePillButton "Download Azure Blob" 255 "BtnBlue" "BtnBlueHover" { Start-Process $Url_Blob }
    Add-SidePillButton "Download Google Drive" 300 "BtnBlue" "BtnBlueHover" { Start-Process $Url_GDrive }

    Add-SideHeader "Diagnostics" 360 "TextWhite"
    Add-SidePillButton "Open System Logs" 390 "BtnBlue" "BtnBlueHover" { if(Test-Path (Ensure-LogDir)){ Invoke-Item (Ensure-LogDir) } }
    Add-SidePillButton "Check Public IP" 435 "BtnBlue" "BtnBlueHover" { Check-PublicIP }
    Add-SidePillButton "Run Diagnostics" 480 "BtnBlue" "BtnBlueHover" { Run-PreFlightDiagnostics }

    Add-SideHeader "System" 700 "TextWhite"
    Add-SidePillButton "Exit Dashboard" 730 "BtnRed" "BtnRedHover" { $script:form.Close() }

    # --- TOP MAIN HEADER AREA ---
    $script:pnlHead = New-Object System.Windows.Forms.Panel; $script:pnlHead.Dock="Top"; $script:pnlHead.Height=120; $script:pnlHead.BackColor=[System.Drawing.Color]::Transparent; $script:form.Controls.Add($script:pnlHead)
    
    $lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="ProPhoenix Installation Dashboard"; $lblTitle.Font=$script:Font_MainTitle; $lblTitle.Left=260; $lblTitle.Top=30; $lblTitle.AutoSize=$true; $lblTitle.ForeColor=Get-Color "TextWhite"; $script:pnlHead.Controls.Add($lblTitle)
    $lblSubTitle = New-Object System.Windows.Forms.Label; $lblSubTitle.Text="Empowering Public Safety Through Innovation"; $lblSubTitle.Font=$script:Font_SubTitle; $lblSubTitle.Left=265; $lblSubTitle.Top=65; $lblSubTitle.AutoSize=$true; $lblSubTitle.ForeColor=Get-Color "TextGrey"; $script:pnlHead.Controls.Add($lblSubTitle)

    # --- TELEMETRY CARDS ---
    $pnlTelemetryWrapper = New-Object System.Windows.Forms.Panel; $pnlTelemetryWrapper.Width = 420; $pnlTelemetryWrapper.Height = 60; $pnlTelemetryWrapper.Top = 30; $pnlTelemetryWrapper.Left = 740; $pnlTelemetryWrapper.BackColor = [System.Drawing.Color]::Transparent; $script:pnlHead.Controls.Add($pnlTelemetryWrapper)

    $pnlCardLeft = New-Object System.Windows.Forms.Panel; $pnlCardLeft.Width = 190; $pnlCardLeft.Height = 55; $pnlCardLeft.BackColor = Get-Color "CardBg"; $pnlTelemetryWrapper.Controls.Add($pnlCardLeft)
    $lblSystemStatus = New-Object System.Windows.Forms.Label; $lblSystemStatus.Text="SYSTEM STATUS"; $lblSystemStatus.Font=$script:Font_Card_Lbl; $lblSystemStatus.ForeColor=Get-Color "TextGrey"; $lblSystemStatus.Left=10; $lblSystemStatus.Top=8; $lblSystemStatus.AutoSize=$true; $pnlCardLeft.Controls.Add($lblSystemStatus)
    $script:lblSystemStatusVal = New-Object System.Windows.Forms.Label; $script:lblSystemStatusVal.Text="ONLINE"; $script:lblSystemStatusVal.Font=$script:Font_Card_Val; $script:lblSystemStatusVal.ForeColor=Get-Color "StatusGreen"; $script:lblSystemStatusVal.Left=110; $script:lblSystemStatusVal.Top=7; $script:lblSystemStatusVal.AutoSize=$true; $pnlCardLeft.Controls.Add($script:lblSystemStatusVal)
    $lblSessionTime = New-Object System.Windows.Forms.Label; $lblSessionTime.Text="SESSION TIME"; $lblSessionTime.Font=$script:Font_Card_Lbl; $lblSessionTime.ForeColor=Get-Color "TextGrey"; $lblSessionTime.Left=10; $lblSessionTime.Top=30; $lblSessionTime.AutoSize=$true; $pnlCardLeft.Controls.Add($lblSessionTime)
    $script:lblSessionTimeVal = New-Object System.Windows.Forms.Label; $script:lblSessionTimeVal.Text="00:00:00"; $script:lblSessionTimeVal.Font=$script:Font_Card_Val; $script:lblSessionTimeVal.ForeColor=Get-Color "Cyan"; $script:lblSessionTimeVal.Left=110; $script:lblSessionTimeVal.Top=29; $script:lblSessionTimeVal.AutoSize=$true; $pnlCardLeft.Controls.Add($script:lblSessionTimeVal)

    $pnlCardRight = New-Object System.Windows.Forms.Panel; $pnlCardRight.Width = 220; $pnlCardRight.Height = 55; $pnlCardRight.Left = 200; $pnlCardRight.BackColor = Get-Color "CardBg"; $pnlTelemetryWrapper.Controls.Add($pnlCardRight)
    $lblHostname = New-Object System.Windows.Forms.Label; $lblHostname.Text="HOSTNAME"; $lblHostname.Font=$script:Font_Card_Lbl; $lblHostname.ForeColor=Get-Color "TextGrey"; $lblHostname.Left=10; $lblHostname.Top=8; $lblHostname.AutoSize=$true; $pnlCardRight.Controls.Add($lblHostname)
    $lblHostnameVal = New-Object System.Windows.Forms.Label; $lblHostnameVal.Text=$HostName; $lblHostnameVal.Font=$script:Font_Card_Val; $lblHostnameVal.ForeColor=Get-Color "TextWhite"; $lblHostnameVal.Left=85; $lblHostnameVal.Top=7; $lblHostnameVal.AutoSize=$true; $pnlCardRight.Controls.Add($lblHostnameVal)
    $lblIpAddress = New-Object System.Windows.Forms.Label; $lblIpAddress.Text="IP ADDRESS"; $lblIpAddress.Font=$script:Font_Card_Lbl; $lblIpAddress.ForeColor=Get-Color "TextGrey"; $lblIpAddress.Left=10; $lblIpAddress.Top=30; $lblIpAddress.AutoSize=$true; $pnlCardRight.Controls.Add($lblIpAddress)
    $lblIpAddressVal = New-Object System.Windows.Forms.Label; $lblIpAddressVal.Text=$IpAddress; $lblIpAddressVal.Font=$script:Font_Card_Val; $lblIpAddressVal.ForeColor=Get-Color "Cyan"; $lblIpAddressVal.Left=85; $lblIpAddressVal.Top=29; $lblIpAddressVal.AutoSize=$true; $pnlCardRight.Controls.Add($lblIpAddressVal)

    $script:TelemetryTimer = New-Object System.Windows.Forms.Timer; $script:TelemetryTimer.Interval = 1000; 
    $script:TelemetryTimer.Add_Tick({ Update-TelemetryDisplay })

    # --- TAB BAR & STATUS LABEL (WITH REFRESH BUTTON) ---
    $script:pnlTabs = New-Object System.Windows.Forms.Panel; $script:pnlTabs.Top=120; $script:pnlTabs.Left=260; $script:pnlTabs.Width=900; $script:pnlTabs.Height=40; $script:pnlTabs.BackColor=[System.Drawing.Color]::Transparent; $script:form.Controls.Add($script:pnlTabs)
    
    $script:btnTabScripts = New-Object System.Windows.Forms.Button; $script:btnTabScripts.Text="Available Scripts"; $script:btnTabScripts.Font=$script:Font_SideHead; $script:btnTabScripts.Size=New-Object System.Drawing.Size(430, 40); $script:btnTabScripts.Left=0; $script:btnTabScripts.BackColor=Get-Color "CardBg"; $script:btnTabScripts.ForeColor=Get-Color "TextWhite"; $script:btnTabScripts.FlatStyle="Flat"; $script:btnTabScripts.FlatAppearance.BorderSize=1; $script:btnTabScripts.FlatAppearance.BorderColor=Get-Color "TextWhite"; $script:pnlTabs.Controls.Add($script:btnTabScripts)
    
    # Shrunk Logs Tab to fit Refresh Button
    $script:btnTabLogs = New-Object System.Windows.Forms.Button; $script:btnTabLogs.Text="Execution Logs"; $script:btnTabLogs.Font=$script:Font_SideHead; $script:btnTabLogs.Size=New-Object System.Drawing.Size(330, 40); $script:btnTabLogs.Left=440; $script:btnTabLogs.BackColor=Get-Color "BgMain"; $script:btnTabLogs.ForeColor=Get-Color "TextGrey"; $script:btnTabLogs.FlatStyle="Flat"; $script:btnTabLogs.FlatAppearance.BorderSize=0; $script:pnlTabs.Controls.Add($script:btnTabLogs)

    # ADDED REFRESH BUTTON
    $script:btnRefresh = New-Object System.Windows.Forms.Button
    $script:btnRefresh.Text = "↻ Refresh"
    $script:btnRefresh.Font = $script:Font_SideHead
    $script:btnRefresh.Size = New-Object System.Drawing.Size(120, 40)
    $script:btnRefresh.Left = 780
    $script:btnRefresh.BackColor = Get-Color "BtnBlue"
    $script:btnRefresh.ForeColor = Get-Color "TextWhite"
    $script:btnRefresh.FlatStyle = "Flat"
    $script:btnRefresh.FlatAppearance.BorderSize = 0
    $script:btnRefresh.Cursor = "Hand"
    $script:btnRefresh.Add_MouseEnter({ $this.BackColor = Get-Color "BtnBlueHover" }.GetNewClosure())
    $script:btnRefresh.Add_MouseLeave({ $this.BackColor = Get-Color "BtnBlue" }.GetNewClosure())
    $script:btnRefresh.Add_Click({ Refresh-List; Update-Status "List Refreshed Successfully." })
    $script:pnlTabs.Controls.Add($script:btnRefresh)

    $script:lblStatus = New-Object System.Windows.Forms.Label; $script:lblStatus.Text="Status: Ready."; $script:lblStatus.Font=$script:Font_Status; $script:lblStatus.Left=260; $script:lblStatus.Top=170; $script:lblStatus.AutoSize=$true; $script:lblStatus.ForeColor=Get-Color "StatusGreen"; $script:form.Controls.Add($script:lblStatus)

    # --- TERMINAL STDOUT CONSOLE ---
    $script:pnlConsole = New-Object System.Windows.Forms.Panel; $script:pnlConsole.Dock="Bottom"; $script:pnlConsole.Height=220; $script:pnlConsole.BackColor=Get-Color "Terminal"; $script:pnlConsole.Padding = New-Object System.Windows.Forms.Padding(260, 0, 0, 0); $script:pnlConsole.Visible=$false; $script:form.Controls.Add($script:pnlConsole)
    $script:TermConsole = New-Object System.Windows.Forms.RichTextBox
    $script:TermConsole.Dock="Fill"; $script:TermConsole.BackColor=Get-Color "Terminal"; $script:TermConsole.ForeColor=Get-Color "TextWhite"; $script:TermConsole.Font=$script:Font_Term; $script:TermConsole.ReadOnly=$true; $script:TermConsole.BorderStyle="None"
    $script:pnlConsole.Controls.Add($script:TermConsole)

    # --- MAIN TOOLS AREA (WITH FADED CENTER WATERMARK) ---
    $script:pnlToolsWrapper = New-Object System.Windows.Forms.Panel; $script:pnlToolsWrapper.Left=260; $script:pnlToolsWrapper.Top=200; $script:pnlToolsWrapper.Size=New-Object System.Drawing.Size(910, 600); $script:pnlToolsWrapper.BackColor=[System.Drawing.Color]::Transparent; $script:form.Controls.Add($script:pnlToolsWrapper)
    Enable-AdvancedDoubleBuffering $script:pnlToolsWrapper

    if ($null -ne $LogoPath -and (Test-Path $LogoPath)) {
        $script:pnlToolsWrapper.BackgroundImage = [System.Drawing.Image]::FromFile($LogoPath)
        $script:pnlToolsWrapper.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Zoom
    }

    $script:pnlTools = New-Object System.Windows.Forms.Panel; $script:pnlTools.Left=0; $script:pnlTools.Top=0; $script:pnlTools.Size=New-Object System.Drawing.Size(910, 600); 
    $script:pnlTools.AutoScroll=$false; 
    $script:pnlTools.BackColor=[System.Drawing.Color]::FromArgb(180, 24, 25, 32); 
    $script:pnlToolsWrapper.Controls.Add($script:pnlTools)
    Enable-AdvancedDoubleBuffering $script:pnlTools

    # --- MINIMALIST UP ARROW TOGGLE (BOTTOM RIGHT) ---
    $script:btnToggleLog = New-Object System.Windows.Forms.Button
    $script:btnToggleLog.Text = "▲"
    $script:btnToggleLog.Size = New-Object System.Drawing.Size(40, 40)
    $script:btnToggleLog.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $script:btnToggleLog.Location = New-Object System.Drawing.Point(850, 550)
    $script:btnToggleLog.BackColor = Get-Color "BtnRun"
    $script:btnToggleLog.ForeColor = Get-Color "TextWhite"
    $script:btnToggleLog.Font = $script:Font_SideHead
    $script:btnToggleLog.FlatStyle = "Flat"
    $script:btnToggleLog.FlatAppearance.BorderSize = 0
    $script:btnToggleLog.Cursor = "Hand"
    $script:pnlToolsWrapper.Controls.Add($script:btnToggleLog)
    $script:btnToggleLog.BringToFront()

    $ToggleAction = {
        $script:form.SuspendLayout()
        if ($script:pnlConsole.Visible) {
            $script:pnlConsole.Visible = $false
            $script:btnTabScripts.BackColor = Get-Color "CardBg"; $script:btnTabScripts.ForeColor = Get-Color "TextWhite"; $script:btnTabScripts.FlatAppearance.BorderSize=1
            $script:btnTabLogs.BackColor = Get-Color "BgMain"; $script:btnTabLogs.ForeColor = Get-Color "TextGrey"; $script:btnTabLogs.FlatAppearance.BorderSize=0
            $script:btnToggleLog.Text = "▲"
        } else {
            $script:pnlConsole.Visible = $true
            $script:btnTabScripts.BackColor = Get-Color "BgMain"; $script:btnTabScripts.ForeColor = Get-Color "TextGrey"; $script:btnTabScripts.FlatAppearance.BorderSize=0
            $script:btnTabLogs.BackColor = Get-Color "CardBg"; $script:btnTabLogs.ForeColor = Get-Color "TextWhite"; $script:btnTabLogs.FlatAppearance.BorderSize=1
            $script:btnToggleLog.Text = "▼"
        }
        $script:form.ResumeLayout($true)
        $script:pnlToolsWrapper.Invalidate($true)
    }
    $script:btnToggleLog.Add_Click($ToggleAction)
    $script:btnTabLogs.Add_Click($ToggleAction)
    $script:btnTabScripts.Add_Click($ToggleAction)

    # --- EXECUTE ---
    $script:form.Add_Shown({ 
        $script:form.Activate()
        $script:TelemetryTimer.Start()
        
        if (Test-Path $InstallBase) {
            Write-Terminal "Payload detected at startup. Booting list logic..." "Cyan"
            $script:CurrentToolPath = $InstallBase
            $Nested = Join-Path $InstallBase "Phoenix Installation Master"
            if (Test-Path $Nested) { $script:CurrentToolPath = $Nested }
            $script:ToolsLoaded = $true
            Refresh-List
            Update-Status "Master Loaded Successfully."
        } else {
            Search-Master 
        }
    })
    [void] $script:form.ShowDialog()

} catch {
    # If a critical error occurs, force the hidden console window back open so you can read the error message.
    if ($host.Name -notmatch "ISE") { $type::ShowWindow($hwnd, 5) }
    Write-Host "CRITICAL ERROR: UI Failed to Load." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Yellow
    Read-Host "Press ENTER to exit..."
}