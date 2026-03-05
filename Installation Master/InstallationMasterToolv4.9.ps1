<#
.SYNOPSIS
    Prophoenix Installation Dashboard (v4.9)
    - NAMING: Updated logic to cover ALL scripts (App Pool, SQL, Shortcuts, etc.).
    - CLEANUP: Automatically removes version numbers (v4.3) and underscores from names.
    - CORE: Retains Bulletproof Path, Deep Search, Logs, and Auto-Unblock.
#>

# --- IMMEDIATE STARTUP MESSAGE ---
Write-Host "Initializing Dashboard v81.0..." -ForegroundColor Cyan

# ==============================================================================
#  1. ROBUST PATH DETECTION
# ==============================================================================
try {
    if ($PSScriptRoot) {
        $ScriptPath = $PSScriptRoot
    } else {
        $ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    }
    if ([string]::IsNullOrWhiteSpace($ScriptPath)) { $ScriptPath = $PWD.Path }
    Write-Host "Working Directory: $ScriptPath" -ForegroundColor Gray
} catch {
    $ScriptPath = $PWD.Path
}

# ==============================================================================
#  2. ADMIN CHECK
# ==============================================================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Requesting Admin Rights..." -ForegroundColor Yellow
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    Exit
}

# ==============================================================================
#  3. GLOBAL ERROR WRAPPER
# ==============================================================================
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # ==========================================================================
    #  4. CONFIGURATION
    # ==========================================================================
    
    # --- COLORS ---
    $Col_Blue   = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $Col_White  = [System.Drawing.Color]::White
    $Col_Green  = [System.Drawing.Color]::FromArgb(16, 124, 16)
    $Col_Red    = [System.Drawing.Color]::Red
    $Col_Trans  = [System.Drawing.Color]::Transparent
    $Col_GlassSide  = [System.Drawing.Color]::FromArgb(240, 10, 10, 10)
    $Col_GlassMain  = [System.Drawing.Color]::FromArgb(180, 0, 0, 0)

    # --- FONTS ---
    $Font_Head = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
    $Font_Sub  = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $Font_Norm = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)

    # --- URLS ---
    $Url_GDrive   = "https://drive.google.com/uc?export=download&id=1ISrKUNI3-cL0BvSM5Fnkn5G2NQOUiIs8"
    $Url_Blob     = "https://produpdates.blob.core.windows.net/web/Prerequisite%20Script%202026/Phoenix%20Installation%20Master.zip?sp=racw&st=2026-03-03T14:27:14Z&se=2031-03-03T22:42:14Z&spr=https&sv=2024-11-04&sr=b&sig=%2By%2F%2FqzRyKGWAb0Jo5zuqTbG0LD%2BbS%2BMyJqgqsbFxy%2Bw%3D"

    $ZipNamePattern = "Phoenix Installation Master*.zip"
    $InstallBase    = "C:\pnxtemp\Phoenix Installation Master"
    
    $Global:CurrentToolPath = $InstallBase 
    $Global:ToolsLoaded = $false

    # ==========================================================================
    #  5. FUNCTIONS
    # ==========================================================================
    function Ensure-LogDir {
        $LogDir = Join-Path $InstallBase "Logs"
        if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
        return $LogDir
    }

    function Write-GlobalLog($msg) {
        try {
            $LogDir = Ensure-LogDir
            $LogFile = Join-Path $LogDir "Dashboard_Master_Log.txt"
            $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Add-Content -Path $LogFile -Value "[$Timestamp] $msg" -ErrorAction SilentlyContinue
        } catch {}
    }

    function Write-ScriptLog($ScriptFriendlyName, $msg) {
        try {
            $LogDir = Ensure-LogDir
            $SafeName = $ScriptFriendlyName -replace '[\\/:*?"<>|]', ''
            $LogFile = Join-Path $LogDir "$SafeName.log"
            $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $User = $env:USERNAME
            $Entry = "[$Timestamp] [User: $User] $msg"
            Add-Content -Path $LogFile -Value $Entry -ErrorAction SilentlyContinue
        } catch {}
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

    function Test-ZipValidity($ZipPath) {
        try {
            [System.IO.Compression.ZipFile]::OpenRead($ZipPath).Dispose()
            return $true
        } catch {
            return $false
        }
    }

    # --- ENHANCED NAMING LOGIC ---
    function Get-FriendlyName($fileName) {
        # 1. SPECIFIC MATCHES (Preferred Names)
        if ($fileName -match "App Pool False") { return "App Pool 32-bit False" }
        if ($fileName -match "Hotfix Script" -and $fileName -match "Bat") { return "Minimal Downtime (Batch)" }
        if ($fileName -match "InstanceVerification") { return "Instance Verification" }
        if ($fileName -match "LaunchShortcuts") { return "Clients Auto Update" }
        if ($fileName -match "SVR Session" -or $fileName -match "VR Session") { return "SVR Session Clear" }
        if ($fileName -match "SQL Memory") { return "SQL Memory Set" }
        if ($fileName -match "Autodbsync" -or $fileName -match "DB Sync") { return "DB Sync Tool" }
        if ($fileName -match "RMS" -and $fileName -match "PD") { return "RMS Server PD" }
        if (($fileName -match "Cad" -and $fileName -match "Hotfix") -or ($fileName -match "CAD" -and $fileName -match "PD")) { return "CAD Server PD" }
        if ($fileName -match "Autodefined" -or ($fileName -match "Demo" -and $fileName -match "Test")) { return "Test/Demo Hotfix" }
        if ($fileName -match "Minimal Downtime" -and $fileName -match "PS") { return "Minimal Downtime (PS)" }
        if ($fileName -match "Minimal Downtime") { return "Minimal Downtime Deployment" }
        if ($fileName -match "Log Clearence" -or $fileName -match "Logcleaner") { return "Log Cleaner" }
        if ($fileName -match "Precompiler") { return "Precompiler Config" }
        if ($fileName -match "Certificate") { return "Certificate Mapping" }
        if ($fileName -match "IIS Config") { return "IIS Configuration" }

        # 2. AUTO-CLEANUP (Fall-back for everything else)
        # Removes: Extensions (.ps1), Underscores (_), Version numbers (v4.3, -v5.8)
        $cleanName = $fileName -replace "\.ps1$","" -replace "\.bat$","" 
        $cleanName = $cleanName -replace "_", " " 
        $cleanName = $cleanName -replace "-v\d+\.\d+", ""  # Remove -v5.8
        $cleanName = $cleanName -replace "v\d+\.\d+", ""   # Remove v4.4
        $cleanName = $cleanName -replace "\s+", " "        # Fix double spaces
        
        return $cleanName.Trim()
    }

    function Get-SortOrder($friendlyName) {
        # PRIORITY LIST
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
            default { return 99 } # Alphabetical after priority items
        }
    }

    function Set-FolderPermissions($path) {
        try {
            $args = "`"$path`" /grant Everyone:(OI)(CI)F /T /C /Q"
            Start-Process "icacls.exe" -ArgumentList $args -WindowStyle Hidden -Wait
        } catch {}
    }

    function Unblock-ExtractedFiles($path) {
        Write-GlobalLog "Unblocking all files in: $path"
        try {
            Get-ChildItem -Path $path -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
            Write-GlobalLog "Files Unblocked Successfully."
        } catch {
            Write-GlobalLog "Warning: Failed to unblock some files. $_"
        }
    }

    function Patch-Scripts($rootPath) {
        Write-GlobalLog "Patching scripts in $rootPath..."
        $FixFiles = Get-ChildItem -Path $rootPath -Recurse -Filter "*DB Sync*.ps1"
        foreach ($file in $FixFiles) {
            try {
                $content = Get-Content $file.FullName -Raw
                if ($content -match "Alignment\s*=") {
                    Write-GlobalLog "FIXED: Alignment bug in $($file.Name)"
                    $newContent = $content -replace '(\$flowAction\.Alignment\s*=\s*"Center")', '# $1 (Fixed by Dashboard)'
                    Set-Content -Path $file.FullName -Value $newContent -Force
                }
            } catch {}
        }
    }

    function Launch-File($path, $friendlyName) {
        if (-not (Test-Path $path)) { 
            [System.Windows.Forms.MessageBox]::Show("File not found!", "Error")
            Write-GlobalLog "ERROR: Launch failed - File not found: $path"
            return 
        }
        
        $workDir = Split-Path -Path $path -Parent
        Write-GlobalLog "Launching: $friendlyName"
        Write-ScriptLog $friendlyName "Script Launched."

        try {
            if ($path -match "\.bat$") {
                Start-Process "cmd.exe" -ArgumentList "/c `"$path`" & pause" -Verb RunAs -WorkingDirectory $workDir
            } elseif ($path -match "Minimal Downtime") {
                 Start-Process "powershell_ise.exe" -ArgumentList "-NoProfile -File `"$path`"" -Verb RunAs -WorkingDirectory $workDir
            } else {
                Start-Process "powershell.exe" -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$path`"" -Verb RunAs -WorkingDirectory $workDir
            }
            Write-ScriptLog $friendlyName "Execution started successfully."
        } catch {
            Write-GlobalLog "CRITICAL ERROR: Launch exception for ${friendlyName}: $_"
            Write-ScriptLog $friendlyName "LAUNCH FAILED: $_"
            [System.Windows.Forms.MessageBox]::Show("Error launching file: $_", "Error")
        }
    }

    function Refresh-List {
        $pnlTools.Controls.Clear()
        [int]$Y = 10
        
        if (-not $Global:ToolsLoaded) {
            $lbl = New-Object System.Windows.Forms.Label; $lbl.Text="No Zip Extracted. Click 'Search Master'."; $lbl.AutoSize=$true; $lbl.Left=20; $lbl.Top=20; 
            $lbl.BackColor=$Col_Trans; $lbl.ForeColor=$Col_White; 
            $pnlTools.Controls.Add($lbl)
            return
        }

        $Files = Get-ChildItem -Path $Global:CurrentToolPath -Include *.ps1, *.bat -Recurse -File | Where-Object { $_.Name -notmatch "Prophoenix_Dashboard" }
        $SortedList = $Files | Select-Object Name, FullName, @{Name="Friendly"; Expression={Get-FriendlyName $_.Name}}, @{Name="Rank"; Expression={Get-SortOrder (Get-FriendlyName $_.Name)}} | Sort-Object Rank, Friendly

        foreach ($item in $SortedList) {
            $l = New-Object System.Windows.Forms.Label; $l.Text=$item.Friendly; $l.Font=$Font_Norm; $l.Left=20; $l.Top=$Y+5; $l.Width=500; 
            $l.BackColor=$Col_Trans; 
            $l.ForeColor=$Col_White; 
            $pnlTools.Controls.Add($l)
            
            $b = New-Object System.Windows.Forms.Button; $b.Text="Launch"; $b.Left=600; $b.Top=$Y; $b.Size=New-Object System.Drawing.Size(100, 35); $b.BackColor=$Col_Blue; $b.ForeColor=$Col_White; $b.FlatStyle="Flat"; $b.FlatAppearance.BorderSize=0
            $path = $item.FullName; $name = $item.Friendly
            $action = { Launch-File $path $name }.GetNewClosure()
            $b.Add_Click($action); $pnlTools.Controls.Add($b)
            $Y += 50
        }
    }

    function Search-Master {
        $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $lblStatus.Text = "Searching..."
        [System.Windows.Forms.Application]::DoEvents()
        Write-GlobalLog "--- Starting Deep Search for Master Zip ---"

        $FoundZip = $null
        $RealDownloads = Get-DownloadsPath
        
        $SearchLocations = @(
            @{ Path = $RealDownloads; Recurse = $true },
            @{ Path = [Environment]::GetFolderPath("Desktop"); Recurse = $true },
            @{ Path = [Environment]::GetFolderPath("MyDocuments"); Recurse = $true },
            @{ Path = $ScriptPath; Recurse = $true },
            @{ Path = "D:\"; Recurse = $false }, 
            @{ Path = "C:\PnxTemp"; Recurse = $true }
        )

        foreach ($loc in $SearchLocations) {
            $dir = $loc.Path
            if ($dir -and (Test-Path $dir)) {
                Write-GlobalLog "Scanning: $dir (Recursive: $($loc.Recurse))"
                
                if ($loc.Recurse) {
                    $zips = Get-ChildItem -Path $dir -Filter $ZipNamePattern -File -Recurse -Depth 3 -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
                } else {
                    $zips = Get-ChildItem -Path $dir -Filter $ZipNamePattern -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
                }

                foreach ($zip in $zips) {
                    Write-GlobalLog "Testing Zip: $($zip.FullName)"
                    if (Test-ZipValidity $zip.FullName) {
                        $FoundZip = $zip.FullName
                        Write-GlobalLog "VALID ZIP FOUND: $FoundZip"
                        break
                    } else {
                        Write-GlobalLog "INVALID/CORRUPT ZIP SKIPPED: $($zip.FullName)"
                    }
                }
                if ($FoundZip) { break }
            }
        }

        if (-not $FoundZip) {
            $msg = "No VALID Zip found.`nPlease select 'Phoenix Installation Master.zip' manually."
            [System.Windows.Forms.MessageBox]::Show($msg, "Search Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            
            $dlg = New-Object System.Windows.Forms.OpenFileDialog
            $dlg.Filter = "Zip Files (*.zip)|*.zip"
            if ($dlg.ShowDialog() -eq "OK") {
                if (Test-ZipValidity $dlg.FileName) {
                    $FoundZip = $dlg.FileName
                    Write-GlobalLog "Manual Selection (Valid): $FoundZip"
                } else {
                    [System.Windows.Forms.MessageBox]::Show("The selected file is also corrupt. Please download again.", "Error")
                    $lblStatus.Text = "Selection Corrupt"
                    $lblStatus.ForeColor = $Col_Red
                    $form.Cursor = [System.Windows.Forms.Cursors]::Default
                    return
                }
            } else {
                $lblStatus.Text = "Cancelled"
                $lblStatus.ForeColor = $Col_Red
                $form.Cursor = [System.Windows.Forms.Cursors]::Default
                return
            }
        }

        if ($FoundZip) {
            $lblStatus.Text = "Extracting..."
            [System.Windows.Forms.Application]::DoEvents()

            if (Test-Path "C:\PnxTemp\MasterTemp.zip") { Remove-Item "C:\PnxTemp\MasterTemp.zip" -Force -ErrorAction SilentlyContinue }
            if (-not (Test-Path "C:\PnxTemp")) { New-Item -ItemType Directory -Path "C:\PnxTemp" -Force | Out-Null }
            
            $LocalZip = "C:\PnxTemp\MasterTemp.zip"
            try { 
                Copy-Item -Path $FoundZip -Destination $LocalZip -Force 
                Write-GlobalLog "Copied to temp: $LocalZip"
            } 
            catch { 
                Write-GlobalLog "COPY FAILED: $_"
                [System.Windows.Forms.MessageBox]::Show("Copy Failed. Error: $_", "Copy Error"); $form.Cursor = [System.Windows.Forms.Cursors]::Default; return 
            }

            try { 
                Expand-Archive -Path $LocalZip -DestinationPath $InstallBase -Force 
                Write-GlobalLog "Extracted successfully to $InstallBase"
            } 
            catch { 
                Write-GlobalLog "EXTRACTION FAILED: $_"
                [System.Windows.Forms.MessageBox]::Show("Extraction Failed: $_", "Error"); $form.Cursor = [System.Windows.Forms.Cursors]::Default; return 
            }
            
            Set-FolderPermissions $InstallBase
            Unblock-ExtractedFiles $InstallBase
            Patch-Scripts $InstallBase
            Remove-Item $LocalZip -Force -ErrorAction SilentlyContinue

            $Global:CurrentToolPath = $InstallBase
            $Nested = Join-Path $InstallBase "Phoenix Installation Master"
            if (Test-Path $Nested) { $Global:CurrentToolPath = $Nested }

            $Global:ToolsLoaded = $true
            Refresh-List
            $lblStatus.Text = "Master Loaded"
            $lblStatus.ForeColor = $Col_Green
            Write-GlobalLog "Master Loaded Successfully"
            [System.Windows.Forms.MessageBox]::Show("Master Loaded Successfully!", "Success")
        }
        $form.Cursor = [System.Windows.Forms.Cursors]::Default
    }

    # ==========================================================================
    #  6. BUILD UI
    # ==========================================================================
    
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Prophoenix Installation Dashboard (v4.9)"
    $form.Size = New-Object System.Drawing.Size(1200, 800)
    $form.StartPosition = "CenterScreen"
    $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30) 

    # --- SMART BACKGROUND IMAGE DETECTION ---
    try {
        $BgImages = Get-ChildItem -Path $ScriptPath -Include *.jpg, *.png, *.jpeg -File
        if ($BgImages) {
            $BgImage = $BgImages[0].FullName
            $form.BackgroundImage = [System.Drawing.Image]::FromFile($BgImage)
            $form.BackgroundImageLayout = "Stretch"
        }
    } catch {}

    # --- SIDEBAR ---
    $pnlSide = New-Object System.Windows.Forms.Panel; $pnlSide.Dock="Left"; $pnlSide.Width=260; 
    $pnlSide.BackColor=$Col_GlassSide; 
    $form.Controls.Add($pnlSide)

    $lblBrand = New-Object System.Windows.Forms.Label; $lblBrand.Text="PROPHOENIX"; $lblBrand.Font=$Font_Head; $lblBrand.ForeColor=$Col_White; $lblBrand.Left=20; $lblBrand.Top=30; $lblBrand.AutoSize=$true; $lblBrand.BackColor=$Col_Trans; $pnlSide.Controls.Add($lblBrand)
    $lblSub = New-Object System.Windows.Forms.Label; $lblSub.Text="DASHBOARD"; $lblSub.Font=$Font_Norm; $lblSub.ForeColor=[System.Drawing.Color]::Cyan; $lblSub.Left=22; $lblSub.Top=60; $lblSub.AutoSize=$true; $lblSub.BackColor=$Col_Trans; $pnlSide.Controls.Add($lblSub)

    # Buttons
    $btnSearch = New-Object System.Windows.Forms.Button; $btnSearch.Text="  🔍  SEARCH MASTER"; $btnSearch.TextAlign="MiddleLeft"; $btnSearch.Font=$Font_Sub; $btnSearch.ForeColor=$Col_White; $btnSearch.BackColor=$Col_Blue; $btnSearch.FlatStyle="Flat"; $btnSearch.FlatAppearance.BorderSize=0; $btnSearch.Left=0; $btnSearch.Top=120; $btnSearch.Size=New-Object System.Drawing.Size(260, 50); $btnSearch.Cursor="Hand"; $pnlSide.Controls.Add($btnSearch)
    $btnGD = New-Object System.Windows.Forms.Button; $btnGD.Text="  ☁  DOWNLOAD GDRIVE"; $btnGD.TextAlign="MiddleLeft"; $btnGD.Font=$Font_Sub; $btnGD.ForeColor=$Col_White; $btnGD.BackColor=[System.Drawing.Color]::DimGray; $btnGD.FlatStyle="Flat"; $btnGD.FlatAppearance.BorderSize=0; $btnGD.Left=0; $btnGD.Top=180; $btnGD.Size=New-Object System.Drawing.Size(260, 50); $btnGD.Cursor="Hand"; $pnlSide.Controls.Add($btnGD)
    $btnAz = New-Object System.Windows.Forms.Button; $btnAz.Text="  ☁  DOWNLOAD AZ BLOB"; $btnAz.TextAlign="MiddleLeft"; $btnAz.Font=$Font_Sub; $btnAz.ForeColor=$Col_White; $btnAz.BackColor=[System.Drawing.Color]::DimGray; $btnAz.FlatStyle="Flat"; $btnAz.FlatAppearance.BorderSize=0; $btnAz.Left=0; $btnAz.Top=240; $btnAz.Size=New-Object System.Drawing.Size(260, 50); $btnAz.Cursor="Hand"; $pnlSide.Controls.Add($btnAz)

    # --- HEADER ---
    $pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Top"; $pnlHead.Height=70; 
    $pnlHead.BackColor=$Col_Trans; 
    $form.Controls.Add($pnlHead)

    $lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="Installation Dashboard"; $lblTitle.Font=$Font_Head; $lblTitle.Left=280; $lblTitle.Top=20; $lblTitle.AutoSize=$true; 
    $lblTitle.ForeColor=$Col_White; 
    $lblTitle.BackColor=$Col_Trans; 
    $pnlHead.Controls.Add($lblTitle)

    $lblStatus = New-Object System.Windows.Forms.Label; $lblStatus.Text="Waiting for Search..."; $lblStatus.Font=$Font_Sub; $lblStatus.ForeColor=[System.Drawing.Color]::LightGray; $lblStatus.Left=800; $lblStatus.Top=25; $lblStatus.AutoSize=$true; $lblStatus.BackColor=$Col_Trans; $pnlHead.Controls.Add($lblStatus)

    # --- TOOLS PANEL ---
    $pnlToolsWrapper = New-Object System.Windows.Forms.Panel; $pnlToolsWrapper.Left=280; $pnlToolsWrapper.Top=100; $pnlToolsWrapper.Size=New-Object System.Drawing.Size(880, 640); 
    $pnlToolsWrapper.BackColor=$Col_GlassMain; 
    $form.Controls.Add($pnlToolsWrapper)

    $lblToolsHeader = New-Object System.Windows.Forms.Label; $lblToolsHeader.Text="Extracted Installation Tools"; $lblToolsHeader.Font=$Font_Sub; $lblToolsHeader.Left=20; $lblToolsHeader.Top=20; $lblToolsHeader.AutoSize=$true; 
    $lblToolsHeader.ForeColor=$Col_White; 
    $lblToolsHeader.BackColor=$Col_Trans; 
    $pnlToolsWrapper.Controls.Add($lblToolsHeader)

    $pnlTools = New-Object System.Windows.Forms.Panel; $pnlTools.Left=0; $pnlTools.Top=60; $pnlTools.Size=New-Object System.Drawing.Size(880, 560); $pnlTools.AutoScroll=$true; 
    $pnlTools.BackColor = $Col_Trans 
    $pnlToolsWrapper.Controls.Add($pnlTools)

    # --- EVENTS ---
    $btnSearch.Add_Click({ Search-Master })
    $btnGD.Add_Click({ Start-Process $Url_GDrive })
    $btnAz.Add_Click({ Start-Process $Url_Blob })

    # --- RUN ---
    $form.Add_Shown({ $form.Activate(); Search-Master })
    [void] $form.ShowDialog()

} catch {
    # --- CRASH HANDLER ---
    Write-Host "CRITICAL ERROR: The script encountered a fatal crash." -ForegroundColor Red
    Write-Host "Error Details: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "At Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press ENTER to exit..."
    Read-Host
}

# --- EXIT PAUSE ---
Write-Host "Dashboard Execution Finished." -ForegroundColor Cyan
Write-Host "Press ENTER to close this window..."
Read-Host