<#
.SYNOPSIS
    Prophoenix Installation Dashboard (v4.4 - Installation Team)
   
#>

# ==============================================================================
#  1. SETUP & ADMIN CHECK
# ==============================================================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    Exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- CONFIGURATION ---
$Url_GDrive   = "https://drive.google.com/uc?export=download&id=1gkGTpjxZ-jx234REtjEitUZR2FuKdaWA"
$Url_Blob     = "https://prophoenix.blob.core.windows.net/your-link" 

$ZipNamePattern = "Phoenix Installation Master*.zip"
$InstallBase    = "C:\pnxtemp\Phoenix Installation Master"

$Global:CurrentToolPath = $InstallBase 
$Global:ToolsLoaded = $false

# --- SAFE FONTS ---
$Font_Head = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$Font_Sub  = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$Font_Norm = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)

$Col_Dark   = [System.Drawing.Color]::FromArgb(10, 25, 41)
$Col_Blue   = [System.Drawing.Color]::FromArgb(0, 120, 215)
$Col_Gray   = [System.Drawing.Color]::FromArgb(240, 242, 245)
$Col_White  = [System.Drawing.Color]::White
$Col_Green  = [System.Drawing.Color]::FromArgb(16, 124, 16)

# ==============================================================================
#  2. LOGGING FUNCTIONS
# ==============================================================================
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
        $Entry = "[$Timestamp] ACTION: $msg"
        Add-Content -Path $LogFile -Value $Entry -ErrorAction SilentlyContinue
    } catch {}
}

# ==============================================================================
#  3. MAIN FORM
# ==============================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Prophoenix Installation Dashboard v59.0"
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.StartPosition = "CenterScreen"
$form.BackColor = $Col_Gray

# --- SIDEBAR ---
$pnlSide = New-Object System.Windows.Forms.Panel; $pnlSide.Dock="Left"; $pnlSide.Width=260; $pnlSide.BackColor=$Col_Dark; $form.Controls.Add($pnlSide)

$lblBrand = New-Object System.Windows.Forms.Label; $lblBrand.Text="PROPHOENIX"; $lblBrand.Font=$Font_Head; $lblBrand.ForeColor=$Col_White; $lblBrand.Left=20; $lblBrand.Top=30; $lblBrand.AutoSize=$true; $pnlSide.Controls.Add($lblBrand)
$lblSub = New-Object System.Windows.Forms.Label; $lblSub.Text="INSTALLATION"; $lblSub.Font=$Font_Norm; $lblSub.ForeColor=[System.Drawing.Color]::Cyan; $lblSub.Left=22; $lblSub.Top=60; $lblSub.AutoSize=$true; $pnlSide.Controls.Add($lblSub)

# Buttons
$btnSearch = New-Object System.Windows.Forms.Button; $btnSearch.Text="  🔍  SEARCH MASTER"; $btnSearch.TextAlign="MiddleLeft"; $btnSearch.Font=$Font_Sub; $btnSearch.ForeColor=$Col_White; $btnSearch.BackColor=$Col_Blue; $btnSearch.FlatStyle="Flat"; $btnSearch.FlatAppearance.BorderSize=0; $btnSearch.Left=0; $btnSearch.Top=120; $btnSearch.Size=New-Object System.Drawing.Size(260, 50); $btnSearch.Cursor="Hand"; $pnlSide.Controls.Add($btnSearch)
$btnGD = New-Object System.Windows.Forms.Button; $btnGD.Text="  ☁  DOWNLOAD GDRIVE"; $btnGD.TextAlign="MiddleLeft"; $btnGD.Font=$Font_Sub; $btnGD.ForeColor=$Col_White; $btnGD.BackColor=[System.Drawing.Color]::DimGray; $btnGD.FlatStyle="Flat"; $btnGD.FlatAppearance.BorderSize=0; $btnGD.Left=0; $btnGD.Top=180; $btnGD.Size=New-Object System.Drawing.Size(260, 50); $btnGD.Cursor="Hand"; $pnlSide.Controls.Add($btnGD)
$btnAz = New-Object System.Windows.Forms.Button; $btnAz.Text="  ☁  DOWNLOAD AZURE"; $btnAz.TextAlign="MiddleLeft"; $btnAz.Font=$Font_Sub; $btnAz.ForeColor=$Col_White; $btnAz.BackColor=[System.Drawing.Color]::DimGray; $btnAz.FlatStyle="Flat"; $btnAz.FlatAppearance.BorderSize=0; $btnAz.Left=0; $btnAz.Top=240; $btnAz.Size=New-Object System.Drawing.Size(260, 50); $btnAz.Cursor="Hand"; $pnlSide.Controls.Add($btnAz)

# --- HEADER ---
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Top"; $pnlHead.Height=70; $pnlHead.BackColor=$Col_White; $form.Controls.Add($pnlHead)
$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="Installation Management"; $lblTitle.Font=$Font_Head; $lblTitle.Left=280; $lblTitle.Top=20; $lblTitle.AutoSize=$true; $pnlHead.Controls.Add($lblTitle)
$lblStatus = New-Object System.Windows.Forms.Label; $lblStatus.Text="Waiting for Search..."; $lblStatus.Font=$Font_Sub; $lblStatus.ForeColor=[System.Drawing.Color]::Gray; $lblStatus.Left=800; $lblStatus.Top=25; $lblStatus.AutoSize=$true; $pnlHead.Controls.Add($lblStatus)

# --- TOOLS PANEL (Expanded) ---
$pnlToolsWrapper = New-Object System.Windows.Forms.Panel
$pnlToolsWrapper.Left = 280
$pnlToolsWrapper.Top = 100 # Moved UP since Monitor panel is gone
$pnlToolsWrapper.Size = New-Object System.Drawing.Size(880, 640) # Made TALLER
$pnlToolsWrapper.BackColor = $Col_White
$form.Controls.Add($pnlToolsWrapper)

$lblToolsHeader = New-Object System.Windows.Forms.Label
$lblToolsHeader.Text = "Extracted Installation Tools"
$lblToolsHeader.Font = $Font_Sub
$lblToolsHeader.Left = 20
$lblToolsHeader.Top = 20
$lblToolsHeader.AutoSize = $true
$pnlToolsWrapper.Controls.Add($lblToolsHeader)

$pnlTools = New-Object System.Windows.Forms.Panel
$pnlTools.Left = 0
$pnlTools.Top = 60
$pnlTools.Size = New-Object System.Drawing.Size(880, 560) # Taller scroll area
$pnlTools.AutoScroll = $true
$pnlToolsWrapper.Controls.Add($pnlTools)

# ==============================================================================
#  4. LOGIC
# ==============================================================================

function Get-DownloadsPath {
    try {
        $path = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders")."{374DE290-123F-4565-9164-39C4925E467B}"
        if (Test-Path $path) { return $path }
    } catch {}
    $path = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
    if (Test-Path $path) { return $path }
    return $null
}

function Get-FriendlyName($fileName) {
    if ($fileName -match "Autodbsync") { return "DB Sync Tool" }
    if ($fileName -match "RMS - PD") { return "RMS Server PD" }
    if ($fileName -match "Cad_Hotfix") { return "CAD Server PD" }
    if ($fileName -match "Autodefined") { return "Test/Demo Hotfix" }
    if ($fileName -match "Minimal Downtime") { return "Minimal Downtime Deployment" }
    if ($fileName -match "Log Clearence") { return "Log Cleaner" }
    if ($fileName -match "Precompiler") { return "Precompiler Config" }
    if ($fileName -match "Hotfix Script") { return "Hotfix Batch Script" }
    if ($fileName -match "Certificate") { return "Certificate Mapping" }
    if ($fileName -match "IIS Config") { return "IIS Configuration" }
    return $fileName -replace ".ps1","" -replace ".bat","" -replace "_"," "
}

function Get-SortOrder($friendlyName) {
    switch ($friendlyName) {
        "DB Sync Tool" { return 1 }
        "RMS Server PD" { return 2 }
        "CAD Server PD" { return 3 }
        "Test/Demo Hotfix" { return 4 }
        "Minimal Downtime Deployment" { return 5 }
        default { return 99 }
    }
}

function Set-FolderPermissions($path) {
    Write-GlobalLog "Setting permissions for $path"
    try {
        $args = "`"$path`" /grant Everyone:(OI)(CI)F /T /C /Q"
        Start-Process "icacls.exe" -ArgumentList $args -WindowStyle Hidden -Wait
    } catch {}
    
    try {
        $acl = Get-Acl $path
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($rule)
        Set-Acl -Path $path -AclObject $acl
    } catch {}
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
    Write-GlobalLog "Launching: $friendlyName ($path)"
    Write-ScriptLog $friendlyName "Launched successfully."

    try {
        if ($path -match "\.bat$") {
            Start-Process "cmd.exe" -ArgumentList "/c `"$path`" & pause" -Verb RunAs -WorkingDirectory $workDir
        } elseif ($path -match "Minimal Downtime") {
             Start-Process "powershell_ise.exe" -ArgumentList "-NoProfile -File `"$path`"" -Verb RunAs -WorkingDirectory $workDir
        } else {
            Start-Process "powershell.exe" -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$path`"" -Verb RunAs -WorkingDirectory $workDir
        }
    } catch {
        Write-GlobalLog "CRITICAL ERROR: Launch exception: $_"
        Write-ScriptLog $friendlyName "LAUNCH FAILED: $_"
        [System.Windows.Forms.MessageBox]::Show("Error launching file: $_", "Error")
    }
}

function Refresh-List {
    $pnlTools.Controls.Clear()
    [int]$Y = 10
    
    if (-not $Global:ToolsLoaded) {
        $lbl = New-Object System.Windows.Forms.Label; $lbl.Text="No Zip Extracted. Click 'Search Master'."; $lbl.AutoSize=$true; $lbl.Left=20; $lbl.Top=20; $pnlTools.Controls.Add($lbl)
        return
    }

    $Files = Get-ChildItem -Path $Global:CurrentToolPath -Include *.ps1, *.bat -Recurse -File | Where-Object { $_.Name -notmatch "Prophoenix_Dashboard" }
    $SortedList = $Files | Select-Object Name, FullName, @{Name="Friendly"; Expression={Get-FriendlyName $_.Name}}, @{Name="Rank"; Expression={Get-SortOrder (Get-FriendlyName $_.Name)}} | Sort-Object Rank, Friendly

    foreach ($item in $SortedList) {
        $l = New-Object System.Windows.Forms.Label; $l.Text=$item.Friendly; $l.Font=$Font_Norm; $l.Left=20; $l.Top=$Y+5; $l.Width=500; $pnlTools.Controls.Add($l)
        $b = New-Object System.Windows.Forms.Button; $b.Text="Launch"; $b.Left=600; $b.Top=$Y; $b.Size=New-Object System.Drawing.Size(100, 35); $b.BackColor=$Col_Blue; $b.ForeColor=$Col_White; $b.FlatStyle="Flat"; $b.FlatAppearance.BorderSize=0
        
        $path = $item.FullName
        $name = $item.Friendly
        $action = { Launch-File $path $name }.GetNewClosure()
        
        $b.Add_Click($action)
        $pnlTools.Controls.Add($b)
        $Y += 50
    }
}

function Search-Master {
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $lblStatus.Text = "Searching..."
    [System.Windows.Forms.Application]::DoEvents()
    Write-GlobalLog "--- Starting Search for Master Zip ---"

    $FoundZip = $null
    $RealDownloads = Get-DownloadsPath
    
    $SearchDirs = @(
        $RealDownloads,
        [Environment]::GetFolderPath("Desktop"),
        "D:\",
        "C:\PnxTemp",
        $PSScriptRoot
    )

    foreach ($dir in $SearchDirs) {
        if ($dir -and (Test-Path $dir)) {
            Write-GlobalLog "Scanning: $dir"
            $zips = Get-ChildItem -Path $dir -Filter $ZipNamePattern -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
            if ($zips) { 
                $FoundZip = $zips[0].FullName
                Write-GlobalLog "FOUND: $FoundZip"
                break 
            }
        }
    }

    if ($FoundZip) {
        $lblStatus.Text = "Extracting..."
        [System.Windows.Forms.Application]::DoEvents()

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
    } else {
        $lblStatus.Text = "Not Found"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        Write-GlobalLog "Search Failed. Zip not found."
        $msg = "Master Not Found.`n`nChecked Folders:`n" + ($SearchDirs -join "`n")
        [System.Windows.Forms.MessageBox]::Show($msg, "Search Failed")
    }
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
}

# --- EVENTS ---
$btnSearch.Add_Click({ Search-Master })
$btnGD.Add_Click({ Start-Process $Url_GDrive })
$btnAz.Add_Click({ Start-Process $Url_Blob })

# --- RUN ---
$form.Add_Shown({ $form.Activate(); Search-Master })
[void] $form.ShowDialog()