<#
.SYNOPSIS
    Phoenix Installation Master Tool (v8.0 - Scope Fix)
    - FIX: Solves the "Term not recognized" error by fixing variable scope in button events.
    - AUTOMATION: Auto-detects ZIP, extracts to C:\pnxtemp, runs safely.
#>

# ==============================================================================
#  1. ADMIN ELEVATION
# ==============================================================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    Exit
}

# ==============================================================================
#  2. CONFIGURATION & ZIP SEARCH
# ==============================================================================
$ZipFileName = "Phoenix Installation Master.zip"
$InstallBase = "C:\pnxtemp\PhoenixMaster_Live"
$ZipSource   = $null

Write-Host "Searching for $ZipFileName..." -ForegroundColor Cyan
$SearchPaths = @(
    $PSScriptRoot,
    [Environment]::GetFolderPath("Desktop"),
    [Environment]::GetFolderPath("UserProfile") + "\Downloads",
    "C:\PnxTemp", "C:\", "D:\"
)

foreach ($path in $SearchPaths) {
    if ([string]::IsNullOrWhiteSpace($path) -or (-not (Test-Path $path))) { continue }
    $Check = Join-Path $path $ZipFileName
    if (Test-Path $Check) { $ZipSource = $Check; break }
    try {
        $Deep = Get-ChildItem -Path $path -Filter $ZipFileName -Recurse -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($Deep) { $ZipSource = $Deep.FullName; break }
    } catch {}
}

if (-not $ZipSource) {
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Zip Files (*.zip)|*.zip"
    $dlg.Title = "Please locate $ZipFileName"
    if ($dlg.ShowDialog() -eq "OK") { $ZipSource = $dlg.FileName } else { Exit }
}

# ==============================================================================
#  3. EXTRACTION & PATH NORMALIZATION
# ==============================================================================
Write-Host "Extracting to $InstallBase..." -ForegroundColor Yellow
if (Test-Path $InstallBase) { try { Remove-Item -Path $InstallBase -Recurse -Force -ErrorAction Stop } catch {} }
New-Item -ItemType Directory -Path $InstallBase -Force | Out-Null
Expand-Archive -Path $ZipSource -DestinationPath $InstallBase -Force

# SMART DETECTION: Find where the .ps1 files actually landed
$RefFile = Get-ChildItem -Path $InstallBase -Filter "Autodbsync*.ps1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
if ($RefFile) {
    $RealInstallDir = $RefFile.DirectoryName
} else {
    $RealInstallDir = $InstallBase
}
Write-Host "✔ Scripts located in: $RealInstallDir" -ForegroundColor Green

# ==============================================================================
#  4. FILE MAPPING
# ==============================================================================
$File_DBSync    = "Autodbsync - v3.9 GUI.ps1"
$File_CAD       = "Cad_Hotfixupdate_v2.0.ps1"
$File_RMS       = "RMS - PD_v2.1.ps1"
$File_MinDown   = "Minimal Downtime Script LTS.ps1"
$File_Demo      = "TestDemohotfix.ps1"
$File_PreComp   = "Autoprecompilerurlconfig1.6.ps1"

# ==============================================================================
#  5. LAUNCHER LOGIC
# ==============================================================================
function Launch-Tool($fileName) {
    $fullPath = Join-Path $RealInstallDir $fileName
    
    if (-not (Test-Path $fullPath)) {
        [System.Windows.Forms.MessageBox]::Show("File not found:`n$fullPath", "Missing File")
        return
    }

    # SAFE COMMAND: Wraps path in single quotes to handle spaces
    $ArgList = "-NoExit -ExecutionPolicy Bypass -Command `& '$fullPath'"

    try {
        Start-Process -FilePath "powershell.exe" -ArgumentList $ArgList -Verb RunAs -WorkingDirectory $RealInstallDir
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Error launching script.`n$_", "Error")
    }
}

# ==============================================================================
#  6. GUI SETUP
# ==============================================================================
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Phoenix Master Tool v8.0"
$form.Size = New-Object System.Drawing.Size(600, 780)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(32, 32, 32)
$form.ForeColor = "White"

# HEADER
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "PHOENIX MASTER TOOL"
$lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$lblTitle.Location = New-Object System.Drawing.Point(0, 25)
$lblTitle.Size = New-Object System.Drawing.Size(580, 40)
$lblTitle.TextAlign = "MiddleCenter"
$lblTitle.ForeColor = "Cyan"
$form.Controls.Add($lblTitle)

$lblSrc = New-Object System.Windows.Forms.Label
$lblSrc.Text = "Running from: $RealInstallDir"
$lblSrc.Location = New-Object System.Drawing.Point(0, 65)
$lblSrc.Size = New-Object System.Drawing.Size(580, 20)
$lblSrc.TextAlign = "MiddleCenter"
$lblSrc.ForeColor = "Gray"
$lblSrc.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$form.Controls.Add($lblSrc)

# BUTTON CREATOR
function Create-Button {
    param([string]$text, [string]$fileName, [int]$yPos, [System.Drawing.Color]$color)

    $fullPath = Join-Path $RealInstallDir $fileName
    $exists = Test-Path $fullPath
    
    [int]$BtnWidth = 500
    [int]$CenterX = ($form.Size.Width - $BtnWidth) / 2 - 8

    $btn = New-Object System.Windows.Forms.Button
    $btn.Location = New-Object System.Drawing.Point($CenterX, $yPos)
    $btn.Size = New-Object System.Drawing.Size($BtnWidth, 65)
    $btn.FlatStyle = "Flat"
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Text = $text
    
    if ($exists) {
        $btn.BackColor = $color
        $btn.ForeColor = "White"
        if ($text -match "Demo") { $btn.ForeColor = "Black" }
        
        # --- THE FIX: USE CLOSURE TO REMEMBER FILENAME ---
        $action = { Launch-Tool $fileName }.GetNewClosure()
        $btn.Add_Click($action)
        # -------------------------------------------------
        
    } else {
        $btn.Text = "$text (NOT FOUND)"
        $btn.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
        $btn.ForeColor = "Gray"
        $btn.Enabled = $false
    }
    $form.Controls.Add($btn)
}

# COLORS & LAYOUT
$Color_Blue   = [System.Drawing.Color]::FromArgb(0, 120, 215)
$Color_Red    = [System.Drawing.Color]::FromArgb(220, 53, 69)
$Color_DarkRed= [System.Drawing.Color]::FromArgb(160, 20, 40)
$Color_Green  = [System.Drawing.Color]::FromArgb(40, 167, 69)
$Color_Orange = [System.Drawing.Color]::FromArgb(255, 193, 7)
$StartY = 110; $Gap = 80

Create-Button -text "DB Sync Manager"           -fileName $File_DBSync    -yPos $StartY        -color $Color_Blue
Create-Button -text "CAD Production (Hotfix)"   -fileName $File_CAD       -yPos ($StartY+$Gap) -color $Color_Red
Create-Button -text "RMS Production"            -fileName $File_RMS       -yPos ($StartY+$Gap*2) -color $Color_DarkRed
Create-Button -text "Minimal Downtime / Hotfix" -fileName $File_MinDown   -yPos ($StartY+$Gap*3) -color $Color_Green
Create-Button -text "Test / Demo Hotfix"        -fileName $File_Demo      -yPos ($StartY+$Gap*4) -color $Color_Orange

# UTILITIES
[int]$UtilY = $StartY + ($Gap * 5) + 30
$grpUtil = New-Object System.Windows.Forms.GroupBox
$grpUtil.Text = " Utilities "
$grpUtil.ForeColor = "LightGray"
$grpUtil.Location = New-Object System.Drawing.Point(50, $UtilY)
$grpUtil.Size = New-Object System.Drawing.Size(500, 80)
$form.Controls.Add($grpUtil)

$pathPre = Join-Path $RealInstallDir $File_PreComp
$btnPre = New-Object System.Windows.Forms.Button
$btnPre.Location = New-Object System.Drawing.Point(20, 25)
$btnPre.Size = New-Object System.Drawing.Size(460, 35)
$btnPre.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 80)
$btnPre.ForeColor = "White"
$btnPre.FlatStyle = "Flat"

if (Test-Path $pathPre) {
    $btnPre.Text = "⚙ Precompiler Configuration"
    $actionPre = { Launch-Tool $File_PreComp }.GetNewClosure()
    $btnPre.Add_Click($actionPre)
} else {
    $btnPre.Text = "Precompiler Config (Missing)"
    $btnPre.Enabled = $false
}
$grpUtil.Controls.Add($btnPre)

$form.Add_Shown({ $form.Activate() })
[void] $form.ShowDialog()