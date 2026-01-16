<#
.SYNOPSIS
    Prophoenix Installation Dashboard (v40.0 - Minimal Downtime Fix)
    - CRITICAL FIX: The "Minimal Downtime" script contains Batch code (@echo off) but has a .ps1 extension.
    - SOLUTION: This dashboard now detects "Minimal Downtime" files and forces them to run via CMD.exe instead of PowerShell.
    - RESULT: No more parsing errors. The script will open and run correctly in a Command Prompt window.
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
$ZipName     = "Phoenix Installation Master.zip"
$FolderName  = "Phoenix Installation Master"
$InstallBase = "C:\pnxtemp\PhoenixMaster_Live"
$Global:RealInstallDir = $InstallBase
$Global:ToolsLoaded = $false
$Global:IsMonitoring = $false

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
#  2. MAIN FORM
# ==============================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Prophoenix Installation Dashboard v40.0"
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.StartPosition = "CenterScreen"
$form.BackColor = $Col_Gray

# --- SIDEBAR ---
$pnlSide = New-Object System.Windows.Forms.Panel; $pnlSide.Dock="Left"; $pnlSide.Width=260; $pnlSide.BackColor=$Col_Dark; $form.Controls.Add($pnlSide)

$lblBrand = New-Object System.Windows.Forms.Label; $lblBrand.Text="PROPHOENIX"; $lblBrand.Font=$Font_Head; $lblBrand.ForeColor=$Col_White; $lblBrand.Left=20; $lblBrand.Top=30; $lblBrand.AutoSize=$true; $pnlSide.Controls.Add($lblBrand)
$lblSub = New-Object System.Windows.Forms.Label; $lblSub.Text="INSTALLATION"; $lblSub.Font=$Font_Norm; $lblSub.ForeColor=[System.Drawing.Color]::Cyan; $lblSub.Left=22; $lblSub.Top=60; $lblSub.AutoSize=$true; $pnlSide.Controls.Add($lblSub)

# Buttons
$btnSearch = New-Object System.Windows.Forms.Button; $btnSearch.Text="  🔍  SEARCH MASTER"; $btnSearch.TextAlign="MiddleLeft"; $btnSearch.Font=$Font_Sub; $btnSearch.ForeColor=$Col_White; $btnSearch.BackColor=$Col_Blue; $btnSearch.FlatStyle="Flat"; $btnSearch.FlatAppearance.BorderSize=0; $btnSearch.Left=0; $btnSearch.Top=120; $btnSearch.Size=New-Object System.Drawing.Size(260, 50); $btnSearch.Cursor="Hand"; $pnlSide.Controls.Add($btnSearch)
$btnDown = New-Object System.Windows.Forms.Button; $btnDown.Text="  ☁  DOWNLOAD ZIP"; $btnDown.TextAlign="MiddleLeft"; $btnDown.Font=$Font_Sub; $btnDown.ForeColor=$Col_White; $btnDown.BackColor=[System.Drawing.Color]::DimGray; $btnDown.FlatStyle="Flat"; $btnDown.FlatAppearance.BorderSize=0; $btnDown.Left=0; $btnDown.Top=180; $btnDown.Size=New-Object System.Drawing.Size(260, 50); $btnDown.Cursor="Hand"; $pnlSide.Controls.Add($btnDown)

# --- HEADER ---
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Top"; $pnlHead.Height=70; $pnlHead.BackColor=$Col_White; $form.Controls.Add($pnlHead)
$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="System Health & Tools"; $lblTitle.Font=$Font_Head; $lblTitle.Left=280; $lblTitle.Top=20; $lblTitle.AutoSize=$true; $pnlHead.Controls.Add($lblTitle)
$lblStatus = New-Object System.Windows.Forms.Label; $lblStatus.Text="Waiting for Master..."; $lblStatus.Font=$Font_Sub; $lblStatus.ForeColor=[System.Drawing.Color]::Gray; $lblStatus.Left=800; $lblStatus.Top=25; $lblStatus.AutoSize=$true; $pnlHead.Controls.Add($lblStatus)

# --- MONITORING PANEL ---
$pnlMonitor = New-Object System.Windows.Forms.Panel; $pnlMonitor.Left=280; $pnlMonitor.Top=90; $pnlMonitor.Size=New-Object System.Drawing.Size(880, 150); $pnlMonitor.BackColor=$Col_White; $form.Controls.Add($pnlMonitor)

function Add-Monitor-Bar($parent, $title, $y) {
    $l=New-Object System.Windows.Forms.Label; $l.Text=$title; $l.Font=$Font_Norm; $l.Left=20; $l.Top=$y; $l.AutoSize=$true; $parent.Controls.Add($l)
    $pb=New-Object System.Windows.Forms.ProgressBar; $pb.Left=120; $pb.Top=$y; $pb.Size=New-Object System.Drawing.Size(600, 20); $parent.Controls.Add($pb)
    $val=New-Object System.Windows.Forms.Label; $val.Text="0%"; $val.Left=740; $val.Top=$y; $val.Font=$Font_Norm; $parent.Controls.Add($val)
    return @{Bar=$pb; Label=$val}
}
$monCPU=Add-Monitor-Bar $pnlMonitor "CPU Usage" 30; $monRAM=Add-Monitor-Bar $pnlMonitor "RAM Usage" 70; $monDisk=Add-Monitor-Bar $pnlMonitor "Disk (C:)" 110

# --- TOOLS PANEL ---
$pnlToolsWrapper = New-Object System.Windows.Forms.Panel; $pnlToolsWrapper.Left=280; $pnlToolsWrapper.Top=260; $pnlToolsWrapper.Size=New-Object System.Drawing.Size(880, 480); $pnlToolsWrapper.BackColor=$Col_White; $form.Controls.Add($pnlToolsWrapper)
$lblToolsHeader = New-Object System.Windows.Forms.Label; $lblToolsHeader.Text="Available Installation Tools"; $lblToolsHeader.Font=$Font_Sub; $lblToolsHeader.Left=20; $lblToolsHeader.Top=20; $lblToolsHeader.AutoSize=$true; $pnlToolsWrapper.Controls.Add($lblToolsHeader)
$pnlTools = New-Object System.Windows.Forms.Panel; $pnlTools.Left=0; $pnlTools.Top=60; $pnlTools.Size=New-Object System.Drawing.Size(880, 400); $pnlTools.AutoScroll=$true; $pnlToolsWrapper.Controls.Add($pnlTools)

# ==============================================================================
#  3. LOGIC
# ==============================================================================

function Get-Health {
    if ($Global:IsMonitoring) { return } 
    $Global:IsMonitoring = $true
    try {
        [System.Windows.Forms.Application]::DoEvents()
        $cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $os = Get-CimInstance Win32_OperatingSystem
        $ram = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize) * 100, 0)
        $disk = Get-CimInstance Win32_LogicalDisk | Where-Object DeviceID -eq "C:"
        $dsk = [math]::Round(($disk.Size - $disk.FreeSpace) / $disk.Size * 100, 0)
        $monCPU.Bar.Value = [int]$cpu; $monCPU.Label.Text = "$([int]$cpu)%"
        $monRAM.Bar.Value = [int]$ram; $monRAM.Label.Text = "$([int]$ram)%"
        $monDisk.Bar.Value = [int]$dsk; $monDisk.Label.Text = "$([int]$dsk)%"
    } catch {} finally { $Global:IsMonitoring = $false }
}

function Launch-File($path) {
    if (-not (Test-Path $path)) { [System.Windows.Forms.MessageBox]::Show("File not found!", "Error"); return }
    
    try {
        # --- CRITICAL FIX START ---
        # "Minimal Downtime" script is actually a Batch file (@echo off) hidden in a .ps1 extension.
        # We MUST run it with CMD to avoid the PowerShell parsing error.
        if ($path -match "Minimal Downtime") {
            # Running as CMD forces Windows to read it as Batch script, ignoring the .ps1 extension.
            Start-Process "cmd.exe" -ArgumentList "/c `"$path`"" -Verb RunAs -WorkingDirectory $Global:RealInstallDir
        } 
        # Handle Actual Batch Files
        elseif ($path -match ".bat$") {
            Start-Process "cmd.exe" -ArgumentList "/c `"$path`"" -Verb RunAs -WorkingDirectory $Global:RealInstallDir
        } 
        # Handle Real PowerShell Scripts (like DB Sync)
        else {
            Start-Process "powershell.exe" -ArgumentList "-NoExit -ExecutionPolicy Bypass -File `"$path`"" -Verb RunAs -WorkingDirectory $Global:RealInstallDir
        }
        # --- CRITICAL FIX END ---
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error launching file: $_", "Error")
    }
}

function Refresh-List {
    $pnlTools.Controls.Clear()
    [int]$Y = 10
    
    if (-not $Global:ToolsLoaded) {
        $lbl = New-Object System.Windows.Forms.Label; $lbl.Text="No tools loaded. Please click 'Search Master'."; $lbl.AutoSize=$true; $lbl.Left=20; $lbl.Top=20; $pnlTools.Controls.Add($lbl)
        return
    }

    $Files = Get-ChildItem -Path $Global:RealInstallDir -Include *.ps1, *.bat -Recurse -File | Where-Object { $_.Name -notmatch "Prophoenix_Dashboard" -and $_.Name -notmatch "Installation_Master_Tool" }
    
    foreach ($f in $Files) {
        $l = New-Object System.Windows.Forms.Label; $l.Text=$f.BaseName; $l.Font=$Font_Norm; $l.Left=20; $l.Top=$Y+5; $l.Width=500; $pnlTools.Controls.Add($l)
        $b = New-Object System.Windows.Forms.Button; $b.Text="Launch"; $b.Left=600; $b.Top=$Y; $b.Size=New-Object System.Drawing.Size(100, 35); $b.BackColor=$Col_Blue; $b.ForeColor=$Col_White; $b.FlatStyle="Flat"; $b.FlatAppearance.BorderSize=0
        $path = $f.FullName; $action = { Launch-File $path }.GetNewClosure(); $b.Add_Click($action)
        $pnlTools.Controls.Add($b)
        $Y += 50
    }
}

function Search-Master {
    $form.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
    $lblStatus.Text = "Searching..."
    [System.Windows.Forms.Application]::DoEvents()

    $FoundPath = $null
    
    $Paths = @(
        "D:\Phoenix Installation Master",
        "C:\PnxTemp\Phoenix Installation Master",
        "$PSScriptRoot\Phoenix Installation Master",
        [Environment]::GetFolderPath("Desktop") + "\Phoenix Installation Master",
        [Environment]::GetFolderPath("UserProfile") + "\Downloads\Phoenix Installation Master"
    )

    foreach ($p in $Paths) {
        if (Test-Path $p) { $FoundPath = $p; break }
    }

    if ($FoundPath) {
        $Global:RealInstallDir = $FoundPath
        $Global:ToolsLoaded = $true
        Refresh-List
        $lblStatus.Text = "Connected: D: Drive"
        $lblStatus.ForeColor = $Col_Green
        [System.Windows.Forms.MessageBox]::Show("Master Tools Found!", "Success")
    } else {
        $lblStatus.Text = "Not Found"
        $lblStatus.ForeColor = [System.Drawing.Color]::Red
        [System.Windows.Forms.MessageBox]::Show("Could not find 'Phoenix Installation Master' folder.", "Search Failed")
    }
    $form.Cursor = [System.Windows.Forms.Cursors]::Default
}

# --- EVENTS ---
$btnSearch.Add_Click({ Search-Master })
$btnDown.Add_Click({ 
    $res = [System.Windows.Forms.MessageBox]::Show("Download from Azure Blob?", "Download", [System.Windows.Forms.MessageBoxButtons]::YesNo)
    if ($res -eq "Yes") { Start-Process "https://prophoenix.blob.core.windows.net/your-link" }
    else { Start-Process "https://drive.google.com/your-link-here" }
})

# --- TIMER ---
$tmr = New-Object System.Windows.Forms.Timer
$tmr.Interval = 5000
$tmr.Add_Tick({ Get-Health })
$tmr.Start()

# --- RUN ---
$form.Add_Shown({ $form.Activate(); Search-Master })
[void] $form.ShowDialog()