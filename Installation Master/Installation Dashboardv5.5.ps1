<#
.SYNOPSIS
    ProPhoenix Installation Dashboard (v5.5)
    - BUG FIX: Resolved PowerShell Parser Error around `$currentUser:` in icacls arguments.
    - SECURITY: Advanced ACL permission injection for Everyone, IUSR, NETWORK SERVICE, and Local User.
    - CORE: Retains Cache Purging, Zero-Scroll Watermark, Telemetry Cards, and SysAdmin Terminal.
#>

Write-Host "[INIT] Booting ProPhoenix Enterprise Command Center v113.0..." -ForegroundColor Cyan

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

    # --- ENTERPRISE THEME COLORS ---
    $Col_BgDark       = [System.Drawing.Color]::FromArgb(22, 22, 24)
    $Col_SideDark     = [System.Drawing.Color]::FromArgb(14, 14, 16)
    $Col_PanelGlass   = [System.Drawing.Color]::FromArgb(30, 30, 33)
    $Col_CardBg       = [System.Drawing.Color]::FromArgb(25, 25, 28) 
    $Col_PhxOrange    = [System.Drawing.Color]::FromArgb(244, 162, 97)
    $Col_PhxRed       = [System.Drawing.Color]::FromArgb(230, 57, 70)
    $Col_BtnIdle      = [System.Drawing.Color]::FromArgb(40, 40, 43)
    $Col_Terminal     = [System.Drawing.Color]::FromArgb(10, 10, 12)
    $Col_White        = [System.Drawing.Color]::White
    $Col_GreyishWhite = [System.Drawing.Color]::FromArgb(170, 170, 170)
    $Col_Green        = [System.Drawing.Color]::FromArgb(46, 204, 113)
    $Col_Cyan         = [System.Drawing.Color]::FromArgb(0, 255, 255)
    $Col_GoldToggle   = [System.Drawing.Color]::FromArgb(255, 193, 7)

    # --- FONTS ---
    $Font_Title    = New-Object System.Drawing.Font("Segoe UI Black", 16, [System.Drawing.FontStyle]::Bold)
    $Font_Head     = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $Font_Sub      = New-Object System.Drawing.Font("Segoe UI Semibold", 9, [System.Drawing.FontStyle]::Bold)
    $Font_Code     = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
    $Font_Term     = New-Object System.Drawing.Font("Consolas", 8, [System.Drawing.FontStyle]::Regular)
    $Font_Card_Lbl = New-Object System.Drawing.Font("Segoe UI Semibold", 9, [System.Drawing.FontStyle]::Bold)
    $Font_Card_Val = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
    $Font_SideBtn  = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $Font_ListBtn  = New-Object System.Drawing.Font("Segoe UI Semibold", 8, [System.Drawing.FontStyle]::Bold)

    # --- SYSTEM CONFIGURATION ---
    $Url_GDrive   = "https://drive.google.com/uc?export=download&id=10RxuJaWwqR1S6lbkjL0-_AXddCwOARYI"
    $Url_Blob     = "https://produpdates.blob.core.windows.net/web/Prerequisite%20Script%202026/Phoenix%20Installation%20Master.zip?sp=racw&st=2026-01-30T14:01:41Z&se=2032-03-30T22:16:41Z&spr=https&sv=2024-11-04&sr=b&sig=3vXVuby1lcDbQ%2BQQnVzxmmXJsyaRG2sgQwTH9SzPnh4%3D"
    $ZipNamePattern = "Phoenix Installation Master*.zip"
    $InstallBase    = "C:\pnxtemp\Phoenix Installation Master"
    $Global:CurrentToolPath = $InstallBase 
    $Global:ToolsLoaded = $false

    # ==========================================================================
    #  3. SYSADMIN LOGGING ENGINE
    # ==========================================================================
    function Ensure-LogDir {
        $LogDir = Join-Path $InstallBase "Logs"
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        return $LogDir
    }

    function Write-Terminal($msg, $color = "LightGray") {
        try {
            $LogFile = Join-Path (Ensure-LogDir) "Deployment_Audit.log"
            $Timestamp = Get-Date -Format "HH:mm:ss.fff"
            $FullMsg = "[$Timestamp] [SYS] $msg"
            Add-Content -Path $LogFile -Value $FullMsg -ErrorAction SilentlyContinue
            
            if ($Global:TermConsole) {
                $Global:TermConsole.SelectionStart = $Global:TermConsole.TextLength
                $Global:TermConsole.SelectionLength = 0
                $Global:TermConsole.SelectionColor = [System.Drawing.Color]::FromName($color)
                $Global:TermConsole.AppendText("$FullMsg`n")
                $Global:TermConsole.ScrollToCaret()
                [System.Windows.Forms.Application]::DoEvents()
            }
        } catch {}
    }

    # ==========================================================================
    #  4. ADVANCED MEMORY HACKS (UI TEARING FIX) & DIAGNOSTICS
    # ==========================================================================
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

    $Global:DashboardSessionStart = Get-Date

    function Update-TelemetryDisplay {
        try {
            if ($Global:lblSessionTimeVal) {
                $TimeSpan = (Get-Date) - $Global:DashboardSessionStart
                $Global:lblSessionTimeVal.Text = "{0:hh\:mm\:ss}" -f $TimeSpan
            }
        } catch {}
    }

    function Run-PreFlightDiagnostics {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        if (-not $pnlConsole.Visible -and $Global:btnToggleLog) { $Global:btnToggleLog.PerformClick() }
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

            # 5. Browser Cache & Temp File Purge
            Write-Terminal "Purging Browser Cache (Chrome/Edge) & System Temp Files..." "Yellow"
            $CachePaths = @(
                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*",
                "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\*",
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*",
                "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\*",
                "$env:TEMP\*",
                "$env:WINDIR\Temp\*"
            )
            foreach ($path in $CachePaths) {
                try { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue } catch {}
            }
            Write-Terminal "Cache Purge Complete. Environment optimized for deployment." "Lime"

        } catch { Write-Terminal "Diagnostic Error: $_" "Red" }
        Write-Terminal "--- PRE-FLIGHT AUDIT COMPLETE ---" "Cyan"
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }

    function Test-SftpConnection {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        if (-not $pnlConsole.Visible -and $Global:btnToggleLog) { $Global:btnToggleLog.PerformClick() }
        Write-Terminal "--- INITIATING SFTP CONNECTION TEST ---" "Cyan"
        Write-Terminal "Target: sftp.prophoenix.com | Port: 25544" "Yellow"
        [System.Windows.Forms.Application]::DoEvents()

        try {
            $result = Test-NetConnection -ComputerName "sftp.prophoenix.com" -Port 25544 -InformationLevel Detailed -WarningAction SilentlyContinue
            if ($result.TcpTestSucceeded) {
                Write-Terminal "STATUS: CONNECTED (TCP Port 25544 is OPEN)" "Lime"
                Write-Terminal "Resolved IP: $($result.RemoteAddress)" "LightGray"
            } else { Write-Terminal "STATUS: FAILED (TCP Port 25544 is CLOSED or BLOCKED)" "Red" }
        } catch { Write-Terminal "ERROR: Connection test failed to execute." "Red" } 
        finally { $form.Cursor = [System.Windows.Forms.Cursors]::Default; Write-Terminal "SFTP Test Completed." "Cyan" }
    }

    # ==========================================================================
    #  5. CLASSIC CORE LOGIC & ADVANCED PERMISSIONS
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

    function Test-ZipValidity($ZipPath) {
        try { [System.IO.Compression.ZipFile]::OpenRead($ZipPath).Dispose(); return $true } catch { return $false }
    }

    function Get-FriendlyName($fileName) {
        if ($fileName -match "App Pool False") { return "App Pool 32-bit False" }
        if ($fileName -match "Hotfix Script" -and $fileName -match "Bat") { return "Minimal Downtime (Batch)" }
        if ($fileName -match "InstanceVerification") { return "Instance Verification" }
        if ($fileName -match "LaunchShortcuts") { return "Clients Auto Update" }
        if ($fileName -match "SVR Session" -or $fileName -match "VR Session") { return "SVR Session Clear" }
        if ($fileName -match "SQL Memory") { return "SQL Memory Set" }
        if ($fileName -match "Autodbsync" -or $fileName -match "DB Sync") { return "DB Sync Tool" }
        if ($fileName -match "RMS" -and $fileName -match "PD") { return "RMS Server PD" }
        if ($fileName -match "Cad_Hotfix" -or $fileName -match "CAD PD" -or ($fileName -match "CAD" -and $fileName -match "PD")) { return "CAD Server PD" }
        if ($fileName -match "Autodefined" -or $fileName -match "Test-DemoHotfix" -or ($fileName -match "Demo" -and $fileName -match "Test")) { return "Test/Demo Hotfix" }
        if ($fileName -match "Minimal Downtime" -and $fileName -match "PS") { return "Minimal Downtime (PS)" }
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
            "App Pool 32-bit False" { return 8 }
            "Instance Verification" { return 9 }
            "Clients Auto Update" { return 10 }
            "SVR Session Clear" { return 11 }
            "SQL Memory Set" { return 12 }
            "Log Cleaner" { return 13 }
            default { return 99 }
        }
    }

    # --- ADVANCED FOLDER PERMISSIONS: FIX FOR PARSER ERROR ---
    function Set-FolderPermissions($path) {
        Write-Terminal "Applying advanced ACLs (Everyone, IUSR, Network Service, Local User)..." "Yellow"
        try { 
            $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            # CRITICAL FIX: Wrapped $currentUser in {} so PowerShell parses the colon correctly
            $aclArgs = "`"$path`" /grant `"Everyone:(OI)(CI)F`" `"IUSR:(OI)(CI)F`" `"NETWORK SERVICE:(OI)(CI)F`" `"${currentUser}:(OI)(CI)F`" /T /C /Q"
            Start-Process "icacls.exe" -ArgumentList $aclArgs -WindowStyle Hidden -Wait 
            Write-Terminal "Directory permissions locked and loaded." "Lime"
        } catch { Write-Terminal "Warning during ACL assignment: $_" "Red" }
    }

    function Unblock-ExtractedFiles($path) {
        Write-Terminal "Unblocking downloaded payloads..." "Yellow"
        try { Get-ChildItem -Path $path -Recurse -File | Unblock-File -ErrorAction SilentlyContinue; Write-Terminal "Files Unblocked Successfully." "Lime" } 
        catch { Write-Terminal "Warning during Unblock: $_" "Red" }
    }

    function Launch-File($path, $friendlyName) {
        if (-not (Test-Path $path)) { Write-Terminal "EXECUTION HALTED: File not found -> $path" "Red"; return }
        $workDir = Split-Path -Path $path -Parent
        Write-Terminal ">>> Launching: $friendlyName" "Magenta"

        try {
            if ($path -match "\.bat$") { Start-Process "cmd.exe" -ArgumentList "/c `"$path`" & pause" -Verb RunAs -WorkingDirectory $workDir } 
            elseif ($path -match "Minimal Downtime") { Start-Process "powershell_ise.exe" -ArgumentList "-NoProfile -File `"$path`"" -Verb RunAs -WorkingDirectory $workDir } 
            else { Start-Process "powershell.exe" -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$path`"" -Verb RunAs -WorkingDirectory $workDir }
            Write-Terminal "Execution started successfully." "Lime"
        } catch { Write-Terminal "CRITICAL LAUNCH FAILURE: $_" "Red" }
    }

    function Refresh-List {
        $pnlTools.Controls.Clear()
        [int]$Y = 10
        
        if (-not $Global:ToolsLoaded) {
            $lbl = New-Object System.Windows.Forms.Label; $lbl.Text="No Scripts Detected. Please click 'Search / Reload Master'."; $lbl.AutoSize=$true; $lbl.Left=20; $lbl.Top=20; $lbl.Font=$Font_Sub; 
            $lbl.BackColor=[System.Drawing.Color]::Transparent; $lbl.ForeColor=$Col_PhxOrange; $pnlTools.Controls.Add($lbl)
            return
        }

        $Files = Get-ChildItem -Path $Global:CurrentToolPath -Include *.ps1, *.bat -Recurse -File | Where-Object { $_.Name -notmatch "Prophoenix_Dashboard" }
        $SortedList = $Files | Select-Object Name, FullName, @{Name="Friendly"; Expression={Get-FriendlyName $_.Name}}, @{Name="Rank"; Expression={Get-SortOrder (Get-FriendlyName $_.Name)}} | Sort-Object Rank, Friendly

        foreach ($item in $SortedList) {
            $l = New-Object System.Windows.Forms.Label; $l.Text=$item.Friendly; $l.Font=$Font_Sub; $l.Left=20; $l.Top=$Y+4; $l.Width=500; 
            $l.BackColor=[System.Drawing.Color]::Transparent; $l.ForeColor=$Col_White; $pnlTools.Controls.Add($l)
            
            $b = New-Object System.Windows.Forms.Button; $b.Text="LAUNCH"; $b.Left=680; $b.Top=$Y; $b.Size=New-Object System.Drawing.Size(100, 24); 
            $b.BackColor=$Col_BtnIdle; $b.ForeColor=$Col_White; $b.FlatStyle="Flat"; $b.FlatAppearance.BorderSize=0; $b.Font=$Font_ListBtn; $b.Cursor="Hand"
            
            $b.Add_MouseEnter({ $this.BackColor = $Col_PhxOrange; $this.ForeColor = $Col_BgDark }.GetNewClosure())
            $b.Add_MouseLeave({ $this.BackColor = $Col_BtnIdle;  $this.ForeColor = $Col_White }.GetNewClosure())

            $path = $item.FullName; $name = $item.Friendly
            $action = { Launch-File $path $name }.GetNewClosure()
            $b.Add_Click($action); $pnlTools.Controls.Add($b)
            
            $sep = New-Object System.Windows.Forms.Label; $sep.Width=760; $sep.Height=1; $sep.Left=20; $sep.Top=$Y+28; $sep.BackColor=[System.Drawing.Color]::FromArgb(40, 255, 255, 255); $pnlTools.Controls.Add($sep)

            $Y += 32
        }
        if ($Global:btnToggleLog) { $Global:btnToggleLog.BringToFront() }
    }

    function Search-Master {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        if (-not $pnlConsole.Visible -and $Global:btnToggleLog) { $Global:btnToggleLog.PerformClick() }
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
                        Write-Terminal "Validating Found Zip: $($zip.Name)" "Yellow"
                        if (Test-ZipValidity $zip.FullName) {
                            $FoundZip = $zip.FullName
                            Write-Terminal "VERIFIED: $FoundZip" "Lime"
                            break
                        } else { Write-Terminal "SKIPPED: Corrupted - $($zip.Name)" "Red" }
                    }
                    if ($FoundZip) { break }
                }
            }

            if (-not $FoundZip) {
                Write-Terminal "Automated scan failed. Switching to manual." "Yellow"
                $dlg = New-Object System.Windows.Forms.OpenFileDialog
                $dlg.Filter = "Zip Files (*.zip)|*.zip"; $dlg.Title = "Locate Phoenix Master Zip"
                if ($dlg.ShowDialog() -eq "OK") {
                    if (Test-ZipValidity $dlg.FileName) { $FoundZip = $dlg.FileName; Write-Terminal "Manual Assignment Validated." "Lime" } 
                    else { Write-Terminal "ERROR: Manual assignment corrupt." "Red"; return }
                } else { Write-Terminal "Search Aborted." "Red"; return }
            }

            if ($FoundZip) {
                [System.Windows.Forms.Application]::DoEvents()
                Write-Terminal "Staging payload for secure extraction..." "White"

                if (Test-Path "C:\PnxTemp\MasterTemp.zip") { Remove-Item "C:\PnxTemp\MasterTemp.zip" -Force -ErrorAction SilentlyContinue }
                if (-not (Test-Path "C:\PnxTemp")) { New-Item -ItemType Directory -Path "C:\PnxTemp" -Force | Out-Null }
                
                $LocalZip = "C:\PnxTemp\MasterTemp.zip"
                try { Copy-Item -Path $FoundZip -Destination $LocalZip -Force; Write-Terminal "Payload staged at C:\PnxTemp." "LightGray" } catch {}
                try { 
                    Expand-Archive -Path $LocalZip -DestinationPath $InstallBase -Force 
                    Write-Terminal "Extraction 100% complete." "Lime"
                } catch { Write-Terminal "FATAL EXTRACTION ERROR: $_" "Red"; return }
                
                # --- APPLY ADVANCED PERMISSIONS ---
                Set-FolderPermissions $InstallBase
                Unblock-ExtractedFiles $InstallBase
                
                Remove-Item $LocalZip -Force -ErrorAction SilentlyContinue

                $Global:CurrentToolPath = $InstallBase
                $Nested = Join-Path $InstallBase "Phoenix Installation Master"
                if (Test-Path $Nested) { $Global:CurrentToolPath = $Nested }

                $Global:ToolsLoaded = $true
                Refresh-List
                Write-Terminal "Dashboard Armed and Operational." "Lime"
            }
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
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
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "ProPhoenix Installation Dashboard (v5.5)"
    $form.Size = New-Object System.Drawing.Size(1250, 850)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = $Col_BgDark
    Enable-AdvancedDoubleBuffering $form

    $LogoPath = $null
    try {
        $PossibleLogo = Join-Path -Path $ScriptPath -ChildPath "Logo.png" -ErrorAction SilentlyContinue
        if ($null -ne $PossibleLogo -and (Test-Path $PossibleLogo)) { $LogoPath = $PossibleLogo }
    } catch {}

    # --- LEFT SIDEBAR ---
    $pnlSide = New-Object System.Windows.Forms.Panel; $pnlSide.Dock="Left"; $pnlSide.Width=280; $pnlSide.BackColor=$Col_SideDark; $form.Controls.Add($pnlSide)

    $LogoBoxLeft = New-Object System.Windows.Forms.PictureBox
    $LogoBoxLeft.Size = New-Object System.Drawing.Size(280, 90) 
    $LogoBoxLeft.Location = New-Object System.Drawing.Point(0, 25)
    $LogoBoxLeft.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $LogoBoxLeft.BackColor = [System.Drawing.Color]::Transparent
    if ($LogoPath) { $LogoBoxLeft.Image = [System.Drawing.Image]::FromFile($LogoPath) }
    $pnlSide.Controls.Add($LogoBoxLeft)

    $lblBrand = New-Object System.Windows.Forms.Label
    $lblBrand.Text = "INSTALLATION"
    $lblBrand.Font = $Font_Title
    $lblBrand.ForeColor = $Col_White
    $lblBrand.AutoSize = $false
    $lblBrand.Width = 280
    $lblBrand.TextAlign = "MiddleCenter"
    $lblBrand.Left = 0
    $lblBrand.Top = 120
    $lblBrand.BackColor = [System.Drawing.Color]::Transparent
    $pnlSide.Controls.Add($lblBrand)

    $lblSub = New-Object System.Windows.Forms.Label
    $lblSub.Text = "DASHBOARD"
    $lblSub.Font = $Font_Sub
    $lblSub.ForeColor = $Col_PhxOrange
    $lblSub.AutoSize = $false
    $lblSub.Width = 280
    $lblSub.TextAlign = "MiddleCenter"
    $lblSub.Left = 0
    $lblSub.Top = 155
    $lblSub.BackColor = [System.Drawing.Color]::Transparent
    $pnlSide.Controls.Add($lblSub)

    function Add-SidebarButton($Text, $Top, $Action, $HoverColor) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $Text; $btn.TextAlign="MiddleLeft"; $btn.Padding=New-Object System.Windows.Forms.Padding(25, 0, 0, 0)
        $btn.Font=$Font_SideBtn; $btn.ForeColor=$Col_White; $btn.BackColor=$Col_BtnIdle
        $btn.FlatStyle="Flat"; $btn.FlatAppearance.BorderSize=0; $btn.Left=0; $btn.Top=$Top; $btn.Size=New-Object System.Drawing.Size(280, 45); $btn.Cursor="Hand"
        $btn.Add_MouseEnter({ $this.BackColor = $HoverColor; $this.ForeColor = $Col_BgDark }.GetNewClosure())
        $btn.Add_MouseLeave({ $this.BackColor = $Col_BtnIdle; $this.ForeColor = $Col_White }.GetNewClosure())
        $btn.Add_Click($Action)
        $pnlSide.Controls.Add($btn)
    }

    Add-SidebarButton "🔍  SEARCH / RELOAD MASTER" 210 { Search-Master } $Col_PhxOrange    
    Add-SidebarButton "☁   DOWNLOAD AZURE BLOB" 260 { Start-Process $Url_Blob } $Col_White
    Add-SidebarButton "☁   DOWNLOAD GOOGLE DRIVE" 310 { Start-Process $Url_GDrive } $Col_White
    Add-SidebarButton "📂  OPEN SYSTEM LOGS" 360 { if(Test-Path (Ensure-LogDir)){ Invoke-Item (Ensure-LogDir) } } $Col_Green
    Add-SidebarButton "📡  TEST SFTP CONNECTION" 410 { Test-SftpConnection } $Col_PhxOrange
    Add-SidebarButton "⚙️  RUN SYSTEM DIAGNOSTICS" 460 { Run-PreFlightDiagnostics } $Col_Cyan

    # --- TOP HEADER ---
    $pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Top"; $pnlHead.Height=80; $pnlHead.BackColor=[System.Drawing.Color]::Transparent; $form.Controls.Add($pnlHead)
    $lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="HOTFIX UPDATE DASHBOARD"; $lblTitle.Font=$Font_Title; $lblTitle.Left=300; $lblTitle.Top=25; $lblTitle.AutoSize=$true; $lblTitle.ForeColor=$Col_White; $lblTitle.BackColor=[System.Drawing.Color]::Transparent; $pnlHead.Controls.Add($lblTitle)

    # --- TELEMETRY CARDS ---
    $pnlTelemetryWrapper = New-Object System.Windows.Forms.Panel
    $pnlTelemetryWrapper.Width = 420; $pnlTelemetryWrapper.Height = 70; $pnlTelemetryWrapper.Top = 15; $pnlTelemetryWrapper.Left = 800; $pnlTelemetryWrapper.BackColor = [System.Drawing.Color]::Transparent
    $pnlHead.Controls.Add($pnlTelemetryWrapper)

    $pnlCardLeft = New-Object System.Windows.Forms.Panel; $pnlCardLeft.Width = 200; $pnlCardLeft.Height = 55; $pnlCardLeft.BackColor = $Col_CardBg; $pnlTelemetryWrapper.Controls.Add($pnlCardLeft)
    $lblSystemStatus = New-Object System.Windows.Forms.Label; $lblSystemStatus.Text="SYSTEM STATUS"; $lblSystemStatus.Font=$Font_Card_Lbl; $lblSystemStatus.ForeColor=$Col_GreyishWhite; $lblSystemStatus.Left=10; $lblSystemStatus.Top=8; $lblSystemStatus.AutoSize=$true; $pnlCardLeft.Controls.Add($lblSystemStatus)
    $Global:lblSystemStatusVal = New-Object System.Windows.Forms.Label; $Global:lblSystemStatusVal.Text="ONLINE"; $Global:lblSystemStatusVal.Font=$Font_Card_Val; $Global:lblSystemStatusVal.ForeColor=$Col_Green; $Global:lblSystemStatusVal.Left=120; $Global:lblSystemStatusVal.Top=7; $Global:lblSystemStatusVal.AutoSize=$true; $pnlCardLeft.Controls.Add($Global:lblSystemStatusVal)
    $lblSessionTime = New-Object System.Windows.Forms.Label; $lblSessionTime.Text="SESSION TIME"; $lblSessionTime.Font=$Font_Card_Lbl; $lblSessionTime.ForeColor=$Col_GreyishWhite; $lblSessionTime.Left=10; $lblSessionTime.Top=30; $lblSessionTime.AutoSize=$true; $pnlCardLeft.Controls.Add($lblSessionTime)
    $Global:lblSessionTimeVal = New-Object System.Windows.Forms.Label; $Global:lblSessionTimeVal.Text="00:00:00"; $Global:lblSessionTimeVal.Font=$Font_Card_Val; $Global:lblSessionTimeVal.ForeColor=$Col_Cyan; $Global:lblSessionTimeVal.Left=120; $Global:lblSessionTimeVal.Top=29; $Global:lblSessionTimeVal.AutoSize=$true; $pnlCardLeft.Controls.Add($Global:lblSessionTimeVal)

    $pnlCardRight = New-Object System.Windows.Forms.Panel; $pnlCardRight.Width = 200; $pnlCardRight.Height = 55; $pnlCardRight.Left = 210; $pnlCardRight.BackColor = $Col_CardBg; $pnlTelemetryWrapper.Controls.Add($pnlCardRight)
    $lblHostname = New-Object System.Windows.Forms.Label; $lblHostname.Text="HOSTNAME"; $lblHostname.Font=$Font_Card_Lbl; $lblHostname.ForeColor=$Col_GreyishWhite; $lblHostname.Left=10; $lblHostname.Top=8; $lblHostname.AutoSize=$true; $pnlCardRight.Controls.Add($lblHostname)
    $lblHostnameVal = New-Object System.Windows.Forms.Label; $lblHostnameVal.Text=$HostName; $lblHostnameVal.Font=$Font_Card_Val; $lblHostnameVal.ForeColor=$Col_White; $lblHostnameVal.Left=95; $lblHostnameVal.Top=7; $lblHostnameVal.AutoSize=$true; $pnlCardRight.Controls.Add($lblHostnameVal)
    $lblIpAddress = New-Object System.Windows.Forms.Label; $lblIpAddress.Text="IP ADDRESS"; $lblIpAddress.Font=$Font_Card_Lbl; $lblIpAddress.ForeColor=$Col_GreyishWhite; $lblIpAddress.Left=10; $lblIpAddress.Top=30; $lblIpAddress.AutoSize=$true; $pnlCardRight.Controls.Add($lblIpAddress)
    $lblIpAddressVal = New-Object System.Windows.Forms.Label; $lblIpAddressVal.Text=$IpAddress; $lblIpAddressVal.Font=$Font_Card_Val; $lblIpAddressVal.ForeColor=$Col_Cyan; $lblIpAddressVal.Left=95; $lblIpAddressVal.Top=29; $lblIpAddressVal.AutoSize=$true; $pnlCardRight.Controls.Add($lblIpAddressVal)

    $Global:TelemetryTimer = New-Object System.Windows.Forms.Timer; $Global:TelemetryTimer.Interval = 1000; 
    $Global:TelemetryTimer.Add_Tick({ Update-TelemetryDisplay })

    # --- TERMINAL STDOUT CONSOLE ---
    $pnlConsole = New-Object System.Windows.Forms.Panel; $pnlConsole.Dock="Bottom"; $pnlConsole.Height=180; $pnlConsole.BackColor=$Col_SideDark; $pnlConsole.Padding = New-Object System.Windows.Forms.Padding(280, 0, 0, 0); $form.Controls.Add($pnlConsole)
    $Global:TermConsole = New-Object System.Windows.Forms.RichTextBox
    $Global:TermConsole.Dock="Fill"; $Global:TermConsole.BackColor=$Col_Terminal; $Global:TermConsole.ForeColor=$Col_White; $Global:TermConsole.Font=$Font_Term; $Global:TermConsole.ReadOnly=$true; $Global:TermConsole.BorderStyle="None"
    $pnlConsole.Controls.Add($Global:TermConsole)

    # --- TOOLS PANEL WRAPPER (WITH MASSIVE CENTER LOGO WATERMARK) ---
    $pnlToolsWrapper = New-Object System.Windows.Forms.Panel; $pnlToolsWrapper.Left=300; $pnlToolsWrapper.Top=90; $pnlToolsWrapper.Size=New-Object System.Drawing.Size(910, 500); $pnlToolsWrapper.BackColor=$Col_PanelGlass; $form.Controls.Add($pnlToolsWrapper)
    Enable-AdvancedDoubleBuffering $pnlToolsWrapper

    if ($LogoPath) {
        $pnlToolsWrapper.BackgroundImage = [System.Drawing.Image]::FromFile($LogoPath)
        $pnlToolsWrapper.BackgroundImageLayout = [System.Windows.Forms.ImageLayout]::Zoom
    }

    $lblToolsHeader = New-Object System.Windows.Forms.Label; $lblToolsHeader.Text="Master Loaded Successfully"; $lblToolsHeader.Font=$Font_Head; $lblToolsHeader.Left=20; $lblToolsHeader.Top=10; $lblToolsHeader.AutoSize=$true; $lblToolsHeader.ForeColor=$Col_PhxOrange; $lblToolsHeader.BackColor=[System.Drawing.Color]::Transparent; $pnlToolsWrapper.Controls.Add($lblToolsHeader)

    $pnlTools = New-Object System.Windows.Forms.Panel; $pnlTools.Left=0; $pnlTools.Top=45; $pnlTools.Size=New-Object System.Drawing.Size(910, 455); 
    $pnlTools.AutoScroll=$false; 
    $pnlTools.BackColor=[System.Drawing.Color]::Transparent; $pnlToolsWrapper.Controls.Add($pnlTools)
    Enable-AdvancedDoubleBuffering $pnlTools

    # ==========================================================================
    #  TEARING FIX: LOG TOGGLE BAR LOGIC
    # ==========================================================================
    $pnlLogToggleBar = New-Object System.Windows.Forms.Panel
    $pnlLogToggleBar.Width = 100; $pnlLogToggleBar.Height = 25; 
    $pnlLogToggleBar.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
    $pnlLogToggleBar.Location = New-Object System.Drawing.Point(800, 465)
    $pnlLogToggleBar.BackColor = [System.Drawing.Color]::Transparent
    $pnlToolsWrapper.Controls.Add($pnlLogToggleBar)

    $Global:btnToggleLog = New-Object System.Windows.Forms.Button
    $Global:btnToggleLog.Text = "▼ HIDE LOGS"
    $Global:btnToggleLog.Dock = "Fill" 
    $Global:btnToggleLog.BackColor = $Col_GoldToggle
    $Global:btnToggleLog.ForeColor = $Col_Terminal
    $Global:btnToggleLog.Font = $Font_SideBtn
    $Global:btnToggleLog.FlatStyle = "Flat"
    $Global:btnToggleLog.FlatAppearance.BorderSize = 0
    $Global:btnToggleLog.Cursor = "Hand"
    
    $Global:btnToggleLog.Add_Click({
        $form.SuspendLayout()
        $pnlToolsWrapper.SuspendLayout()
        
        if ($pnlConsole.Visible) {
            $pnlConsole.Visible = $false
            $pnlToolsWrapper.Height += 180
            $Global:btnToggleLog.Text = "▲ VIEW LOGS"
        } else {
            $pnlConsole.Visible = $true
            $pnlToolsWrapper.Height -= 180
            $Global:btnToggleLog.Text = "▼ HIDE LOGS"
        }
        
        $pnlToolsWrapper.ResumeLayout()
        $form.ResumeLayout($true)
        
        $pnlToolsWrapper.Invalidate($true)
        $pnlToolsWrapper.Update()
        $pnlTools.Invalidate($true)
        $pnlTools.Update()
    })
    
    $pnlLogToggleBar.Controls.Add($Global:btnToggleLog)
    $pnlLogToggleBar.BringToFront() 

    # --- EXECUTE ---
    $form.Add_Shown({ 
        $form.Activate()
        $Global:TelemetryTimer.Start()
        Search-Master 
    })
    [void] $form.ShowDialog()

} catch {
    Write-Host "CRITICAL ERROR: UI Failed to Load." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Yellow
    Read-Host "Press ENTER to exit..."
}