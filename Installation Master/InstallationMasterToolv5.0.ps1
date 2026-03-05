<#
.SYNOPSIS
    Installation Dashboard (v88.0 - UI Text Update)
    - UI UPDATE: Changed headers to "Installation Dashboard", "Hotfix Update Dashboard", "Ready", etc.
    - CORE: Retains Hardened UI, Try/Finally cursor locks, and exact file naming.
#>

Write-Host "Initializing Installation Dashboard v88.0..." -ForegroundColor DarkYellow

# ==============================================================================
#  1. ROBUST PATH DETECTION & ADMIN CHECK
# ==============================================================================
try {
    if ($PSScriptRoot) { $ScriptPath = $PSScriptRoot } 
    else { $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition }
    if ([string]::IsNullOrWhiteSpace($ScriptPath)) { $ScriptPath = $PWD.Path }
} catch { $ScriptPath = $PWD.Path }

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    Exit
}

# ==============================================================================
#  2. GLOBAL WRAPPER & CORE ASSEMBLIES
# ==============================================================================
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # ==========================================================================
    #  3. STATIC CONFIGURATION
    # ==========================================================================
    
    # --- FONTS ---
    $Font_Title = New-Object System.Drawing.Font("Segoe UI Black", 16, [System.Drawing.FontStyle]::Bold)
    $Font_Head  = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $Font_Sub   = New-Object System.Drawing.Font("Segoe UI Semibold", 10, [System.Drawing.FontStyle]::Bold)
    $Font_Norm  = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)
    $Font_Console = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)

    # --- CORE URLS & PATHS ---
    $Url_GDrive   = "https://drive.google.com/uc?export=download&id=10RxuJaWwqR1S6lbkjL0-_AXddCwOARYI"
    $Url_Blob     = "https://produpdates.blob.core.windows.net/web/Prerequisite%20Script%202026/Phoenix%20Installation%20Master.zip?sp=racw&st=2026-01-30T14:01:41Z&se=2032-03-30T22:16:41Z&spr=https&sv=2024-11-04&sr=b&sig=3vXVuby1lcDbQ%2BQQnVzxmmXJsyaRG2sgQwTH9SzPnh4%3D"
    $ZipNamePattern = "Phoenix Installation Master*.zip"
    $InstallBase    = "C:\pnxtemp\Phoenix Installation Master"
    
    $Global:CurrentToolPath = $InstallBase 
    $Global:ToolsLoaded = $false

    # ==========================================================================
    #  4. ADVANCED LOGGING & UI FUNCTIONS
    # ==========================================================================
    function Ensure-LogDir {
        $LogDir = Join-Path $InstallBase "Logs"
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        return $LogDir
    }

    function Write-GlobalLog($msg, $color = "LightGray") {
        try {
            $LogDir = Ensure-LogDir
            $LogFile = Join-Path $LogDir "Dashboard_Master_Log.txt"
            $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $FullMsg = "[$Timestamp] $msg"
            Add-Content -Path $LogFile -Value $FullMsg -ErrorAction SilentlyContinue
            
            if ($Global:LiveConsole) {
                $Global:LiveConsole.SelectionStart = $Global:LiveConsole.TextLength
                $Global:LiveConsole.SelectionLength = 0
                $Global:LiveConsole.SelectionColor = [System.Drawing.Color]::FromName($color)
                $Global:LiveConsole.AppendText("$FullMsg`n")
                $Global:LiveConsole.ScrollToCaret()
                [System.Windows.Forms.Application]::DoEvents()
            }
        } catch {}
    }

    function Write-ScriptLog($ScriptFriendlyName, $msg) {
        try {
            $LogDir = Ensure-LogDir
            $SafeName = $ScriptFriendlyName -replace '[\\/:*?"<>|]', ''
            $LogFile = Join-Path $LogDir "$SafeName.log"
            $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $User = $env:USERNAME
            Add-Content -Path $LogFile -Value "[$Timestamp] [User: $User] $msg" -ErrorAction SilentlyContinue
        } catch {}
    }

    # ==========================================================================
    #  5. CORE LOGIC (NAMING & SORTING)
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
        try { [System.IO.Compression.ZipFile]::OpenRead($ZipPath).Dispose(); return $true } 
        catch { return $false }
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

        # Fallback Cleanup
        $cleanName = $fileName -replace "\.ps1$","" -replace "\.bat$","" 
        $cleanName = $cleanName -replace "_", " " -replace "-v\d+\.\d+", "" -replace "v\d+\.\d+", "" -replace "\s+", " "
        return $cleanName.Trim()
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

    function Set-FolderPermissions($path) {
        try { Start-Process "icacls.exe" -ArgumentList "`"$path`" /grant Everyone:(OI)(CI)F /T /C /Q" -WindowStyle Hidden -Wait } catch {}
    }

    function Unblock-ExtractedFiles($path) {
        Write-GlobalLog "Unblocking all script files securely..." "Yellow"
        try { Get-ChildItem -Path $path -Recurse -File | Unblock-File -ErrorAction SilentlyContinue; Write-GlobalLog "Files Unblocked Successfully." "Lime" } 
        catch { Write-GlobalLog "Warning: Failed to unblock some files. $_" "Red" }
    }

    function Launch-File($path, $friendlyName) {
        if (-not (Test-Path $path)) { 
            Write-GlobalLog "ERROR: Launch failed - File not found: $path" "Red"; return 
        }
        $workDir = Split-Path -Path $path -Parent
        Write-GlobalLog ">>> Launching Isolated Process: $friendlyName" "Cyan"
        Write-ScriptLog $friendlyName "Script Launched."

        try {
            if ($path -match "\.bat$") { Start-Process "cmd.exe" -ArgumentList "/c `"$path`" & pause" -Verb RunAs -WorkingDirectory $workDir } 
            elseif ($path -match "Minimal Downtime") { Start-Process "powershell_ise.exe" -ArgumentList "-NoProfile -File `"$path`"" -Verb RunAs -WorkingDirectory $workDir } 
            else { Start-Process "powershell.exe" -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$path`"" -Verb RunAs -WorkingDirectory $workDir }
            Write-ScriptLog $friendlyName "Execution started successfully."
        } catch {
            Write-GlobalLog "CRITICAL ERROR: Launch exception for ${friendlyName}: $_" "Red"
            Write-ScriptLog $friendlyName "LAUNCH FAILED: $_"
        }
    }

    function Refresh-List {
        $pnlTools.Controls.Clear()
        [int]$Y = 15
        
        if (-not $Global:ToolsLoaded) {
            $lbl = New-Object System.Windows.Forms.Label; $lbl.Text="No Scripts Detected. Please click 'Search Master'."; $lbl.AutoSize=$true; $lbl.Left=20; $lbl.Top=20; $lbl.Font=$Font_Norm; 
            $lbl.BackColor=[System.Drawing.Color]::Transparent; $lbl.ForeColor=[System.Drawing.Color]::FromArgb(244, 162, 97); $pnlTools.Controls.Add($lbl)
            return
        }

        $Files = Get-ChildItem -Path $Global:CurrentToolPath -Include *.ps1, *.bat -Recurse -File | Where-Object { $_.Name -notmatch "Prophoenix_Dashboard" }
        $SortedList = $Files | Select-Object Name, FullName, @{Name="Friendly"; Expression={Get-FriendlyName $_.Name}}, @{Name="Rank"; Expression={Get-SortOrder (Get-FriendlyName $_.Name)}} | Sort-Object Rank, Friendly

        foreach ($item in $SortedList) {
            $l = New-Object System.Windows.Forms.Label; $l.Text=$item.Friendly; $l.Font=$Font_Sub; $l.Left=20; $l.Top=$Y+7; $l.Width=500; 
            $l.BackColor=[System.Drawing.Color]::Transparent; $l.ForeColor=[System.Drawing.Color]::White; $pnlTools.Controls.Add($l)
            
            $b = New-Object System.Windows.Forms.Button; $b.Text="LAUNCH"; $b.Left=580; $b.Top=$Y; $b.Size=New-Object System.Drawing.Size(120, 35); 
            $b.BackColor=[System.Drawing.Color]::FromArgb(45, 45, 48); $b.ForeColor=[System.Drawing.Color]::White; $b.FlatStyle="Flat"; $b.FlatAppearance.BorderSize=0; $b.Font=$Font_Sub; $b.Cursor="Hand"
            
            $b.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb(230, 57, 70); $this.ForeColor = [System.Drawing.Color]::White })
            $b.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48);  $this.ForeColor = [System.Drawing.Color]::White })

            $path = $item.FullName; $name = $item.Friendly
            $action = { Launch-File $path $name }.GetNewClosure()
            $b.Add_Click($action); $pnlTools.Controls.Add($b)
            
            $sep = New-Object System.Windows.Forms.Label; $sep.Width=680; $sep.Height=1; $sep.Left=20; $sep.Top=$Y+45; $sep.BackColor=[System.Drawing.Color]::FromArgb(50, 255, 255, 255); $pnlTools.Controls.Add($sep)

            $Y += 60
        }
    }

    function Search-Master {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.Text = "SEARCHING..."; $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(244, 162, 97)
        Write-GlobalLog "========================================" "White"
        Write-GlobalLog "INITIATING DEEP ENVIRONMENT SEARCH" "Cyan"
        
        try {
            $FoundZip = $null
            $SearchLocations = @(
                @{ Path = Get-DownloadsPath; Recurse = $true },
                @{ Path = [Environment]::GetFolderPath("Desktop"); Recurse = $true },
                @{ Path = [Environment]::GetFolderPath("MyDocuments"); Recurse = $true },
                @{ Path = $ScriptPath; Recurse = $true },
                @{ Path = "D:\"; Recurse = $false }, 
                @{ Path = "C:\PnxTemp"; Recurse = $true }
            )

            foreach ($loc in $SearchLocations) {
                $dir = $loc.Path
                if ($dir -and (Test-Path $dir)) {
                    Write-GlobalLog "Scanning Directory: $dir" "LightGray"
                    $zips = if ($loc.Recurse) { Get-ChildItem -Path $dir -Filter $ZipNamePattern -File -Recurse -Depth 3 -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending } 
                            else { Get-ChildItem -Path $dir -Filter $ZipNamePattern -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending }

                    foreach ($zip in $zips) {
                        Write-GlobalLog "Validating Found Zip: $($zip.Name)" "Yellow"
                        if (Test-ZipValidity $zip.FullName) {
                            $FoundZip = $zip.FullName
                            Write-GlobalLog "VERIFIED: $FoundZip" "Lime"
                            break
                        } else { Write-GlobalLog "SKIPPED: Zip Corrupted - $($zip.Name)" "Red" }
                    }
                    if ($FoundZip) { break }
                }
            }

            if (-not $FoundZip) {
                Write-GlobalLog "Automated deep search yielded no valid results. Switching to manual." "Red"
                $dlg = New-Object System.Windows.Forms.OpenFileDialog
                $dlg.Filter = "Zip Files (*.zip)|*.zip"; $dlg.Title = "Locate Phoenix Master Zip"
                if ($dlg.ShowDialog() -eq "OK") {
                    if (Test-ZipValidity $dlg.FileName) { $FoundZip = $dlg.FileName; Write-GlobalLog "Manual Override Valid: $FoundZip" "Lime" } 
                    else { $lblStatus.Text = "CORRUPT SELECTION"; $lblStatus.ForeColor = [System.Drawing.Color]::Red; return }
                } else { $lblStatus.Text = "ABORTED"; $lblStatus.ForeColor = [System.Drawing.Color]::Red; return }
            }

            if ($FoundZip) {
                $lblStatus.Text = "EXTRACTING..."; $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(244, 162, 97)
                [System.Windows.Forms.Application]::DoEvents()
                Write-GlobalLog "Preparing Secure Extraction Environment..." "White"

                if (Test-Path "C:\PnxTemp\MasterTemp.zip") { Remove-Item "C:\PnxTemp\MasterTemp.zip" -Force -ErrorAction SilentlyContinue }
                if (-not (Test-Path "C:\PnxTemp")) { New-Item -ItemType Directory -Path "C:\PnxTemp" -Force | Out-Null }
                
                $LocalZip = "C:\PnxTemp\MasterTemp.zip"
                try { Copy-Item -Path $FoundZip -Destination $LocalZip -Force; Write-GlobalLog "Payload transferred to staging." "LightGray" } catch {}
                try { 
                    Expand-Archive -Path $LocalZip -DestinationPath $InstallBase -Force 
                    Write-GlobalLog "Extraction 100% Complete." "Lime"
                } catch { Write-GlobalLog "FATAL EXTRACTION ERROR: $_" "Red"; return }
                
                Set-FolderPermissions $InstallBase
                Unblock-ExtractedFiles $InstallBase
                Remove-Item $LocalZip -Force -ErrorAction SilentlyContinue

                $Global:CurrentToolPath = $InstallBase
                $Nested = Join-Path $InstallBase "Phoenix Installation Master"
                if (Test-Path $Nested) { $Global:CurrentToolPath = $Nested }

                $Global:ToolsLoaded = $true
                Refresh-List
                
                # --- UPDATED SUCCESS STATUS ---
                $lblStatus.Text = "READY"
                $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(16, 124, 16)
                Write-GlobalLog "Dashboard Fully Armed and Operational." "Cyan"
            }
        } finally {
            $form.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    }

    # ==========================================================================
    #  6. ULTIMATE UI BUILD
    # ==========================================================================
    $form = New-Object System.Windows.Forms.Form
    
    # --- UPDATED WINDOW TITLE ---
    $form.Text = "Installation Dashboard | Ultimate v5.0"
    $form.Size = New-Object System.Drawing.Size(1250, 850)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(26, 26, 29)

    try {
        $BgImages = Get-ChildItem -Path $ScriptPath -Include *.jpg, *.png, *.jpeg -File
        if ($BgImages) { $form.BackgroundImage = [System.Drawing.Image]::FromFile($BgImages[0].FullName); $form.BackgroundImageLayout = "Stretch" }
    } catch {}

    # --- LEFT SIDEBAR ---
    $pnlSide = New-Object System.Windows.Forms.Panel; $pnlSide.Dock="Left"; $pnlSide.Width=280; $pnlSide.BackColor=[System.Drawing.Color]::FromArgb(245, 15, 15, 15); $form.Controls.Add($pnlSide)

    # --- UPDATED SIDEBAR LABELS ---
    $lblBrand = New-Object System.Windows.Forms.Label; $lblBrand.Text="INSTALLATION"; $lblBrand.Font=$Font_Title; $lblBrand.ForeColor=[System.Drawing.Color]::White; $lblBrand.Left=20; $lblBrand.Top=30; $lblBrand.AutoSize=$true; $lblBrand.BackColor=[System.Drawing.Color]::Transparent; $pnlSide.Controls.Add($lblBrand)
    $lblSub = New-Object System.Windows.Forms.Label; $lblSub.Text="DASHBOARD"; $lblSub.Font=$Font_Sub; $lblSub.ForeColor=[System.Drawing.Color]::FromArgb(244, 162, 97); $lblSub.Left=22; $lblSub.Top=65; $lblSub.AutoSize=$true; $lblSub.BackColor=[System.Drawing.Color]::Transparent; $pnlSide.Controls.Add($lblSub)

    function Add-SidebarButton($Text, $Top, $Action, $R, $G, $B) {
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text = $Text; $btn.TextAlign="MiddleLeft"; $btn.Font=$Font_Sub; $btn.ForeColor=[System.Drawing.Color]::White; $btn.BackColor=[System.Drawing.Color]::FromArgb(45, 45, 48)
        $btn.FlatStyle="Flat"; $btn.FlatAppearance.BorderSize=0; $btn.Left=0; $btn.Top=$Top; $btn.Size=New-Object System.Drawing.Size(280, 55); $btn.Cursor="Hand"
        
        $btn.Add_MouseEnter({ $this.BackColor = [System.Drawing.Color]::FromArgb($R, $G, $B) })
        $btn.Add_MouseLeave({ $this.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 48) })
        $btn.Add_Click($Action)
        $pnlSide.Controls.Add($btn)
    }

    Add-SidebarButton "  🔍  SEARCH / RELOAD MASTER" 140 { Search-Master } 230 57 70     # Fire Red
    Add-SidebarButton "  ☁  DOWNLOAD AZURE BLOB" 200 { Start-Process $Url_Blob } 0 120 215 # Blue
    Add-SidebarButton "  ☁  DOWNLOAD GOOGLE DRIVE" 260 { Start-Process $Url_GDrive } 0 120 215 # Blue
    Add-SidebarButton "  📂  OPEN SYSTEM LOGS" 320 { if(Test-Path (Ensure-LogDir)){ Invoke-Item (Ensure-LogDir) } } 16 124 16 # Green

    # --- TOP HEADER ---
    $pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Top"; $pnlHead.Height=80; $pnlHead.BackColor=[System.Drawing.Color]::Transparent; $form.Controls.Add($pnlHead)

    # --- UPDATED MAIN HEADER TITLE ---
    $lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="HOTFIX UPDATE DASHBOARD"; $lblTitle.Font=$Font_Title; $lblTitle.Left=300; $lblTitle.Top=25; $lblTitle.AutoSize=$true; $lblTitle.ForeColor=[System.Drawing.Color]::White; $lblTitle.BackColor=[System.Drawing.Color]::Transparent; $pnlHead.Controls.Add($lblTitle)
    
    $lblStatus = New-Object System.Windows.Forms.Label; $lblStatus.Text="IDLE"; $lblStatus.Font=$Font_Head; $lblStatus.ForeColor=[System.Drawing.Color]::White; $lblStatus.Left=950; $lblStatus.Top=30; $lblStatus.AutoSize=$true; $lblStatus.BackColor=[System.Drawing.Color]::Transparent; $pnlHead.Controls.Add($lblStatus)

    # --- ADVANCED: LIVE UI CONSOLE ---
    $pnlConsole = New-Object System.Windows.Forms.Panel; $pnlConsole.Dock="Bottom"; $pnlConsole.Height=150; $pnlConsole.BackColor=[System.Drawing.Color]::FromArgb(245, 15, 15, 15); $pnlConsole.Padding = New-Object System.Windows.Forms.Padding(280, 0, 0, 0); $form.Controls.Add($pnlConsole)
    
    $Global:LiveConsole = New-Object System.Windows.Forms.RichTextBox
    $Global:LiveConsole.Dock="Fill"; $Global:LiveConsole.BackColor=[System.Drawing.Color]::FromArgb(15,15,15); $Global:LiveConsole.ForeColor=[System.Drawing.Color]::White; $Global:LiveConsole.Font=$Font_Console; $Global:LiveConsole.ReadOnly=$true; $Global:LiveConsole.BorderStyle="None"
    $pnlConsole.Controls.Add($Global:LiveConsole)

    # --- TOOLS PANEL ---
    $pnlToolsWrapper = New-Object System.Windows.Forms.Panel; $pnlToolsWrapper.Left=300; $pnlToolsWrapper.Top=90; $pnlToolsWrapper.Size=New-Object System.Drawing.Size(910, 500); $pnlToolsWrapper.BackColor=[System.Drawing.Color]::FromArgb(200, 10, 10, 10); $form.Controls.Add($pnlToolsWrapper)

    # --- UPDATED LIST HEADER ---
    $lblToolsHeader = New-Object System.Windows.Forms.Label; $lblToolsHeader.Text="Loaded"; $lblToolsHeader.Font=$Font_Sub; $lblToolsHeader.Left=20; $lblToolsHeader.Top=15; $lblToolsHeader.AutoSize=$true; $lblToolsHeader.ForeColor=[System.Drawing.Color]::FromArgb(244, 162, 97); $lblToolsHeader.BackColor=[System.Drawing.Color]::Transparent; $pnlToolsWrapper.Controls.Add($lblToolsHeader)

    $pnlTools = New-Object System.Windows.Forms.Panel; $pnlTools.Left=0; $pnlTools.Top=50; $pnlTools.Size=New-Object System.Drawing.Size(910, 440); $pnlTools.AutoScroll=$true; $pnlTools.BackColor=[System.Drawing.Color]::Transparent; $pnlToolsWrapper.Controls.Add($pnlTools)

    # --- EXECUTE ---
    $form.Add_Shown({ $form.Activate(); Search-Master })
    [void] $form.ShowDialog()

} catch {
    # --- FATAL CRASH CATCHER ---
    Write-Host "CRITICAL ERROR: UI Failed to Load." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Yellow
    Read-Host "Press ENTER to exit..."
}