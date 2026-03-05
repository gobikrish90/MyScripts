<#
.SYNOPSIS
    Prophoenix Installation Dashboard (v4.7)
    - UI UPDATE: Changed header title to "Installation Dashboard".
    - CORE: Retains Deep Search, 2032 Blob URL, Auto-Unblock, and Logging.
#>

# ==============================================================================
#  1. SETUP & ADMIN CHECK
# ==============================================================================
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`"" -Verb RunAs
    Exit
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ==============================================================================
#  2. CRITICAL VARIABLES
# ==============================================================================

# --- COLORS ---
$Col_Blue   = [System.Drawing.Color]::FromArgb(0, 120, 215)
$Col_White  = [System.Drawing.Color]::White
$Col_Green  = [System.Drawing.Color]::FromArgb(16, 124, 16)
$Col_Red    = [System.Drawing.Color]::Red
$Col_Trans  = [System.Drawing.Color]::Transparent
$Col_GlassSide  = [System.Drawing.Color]::FromArgb(240, 10, 10, 10)   # Almost black sidebar
$Col_GlassMain  = [System.Drawing.Color]::FromArgb(180, 0, 0, 0)      # See-through black for tools

# --- FONTS ---
$Font_Head = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$Font_Sub  = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$Font_Norm = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Regular)

# --- PATH LOGIC ---
if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { $ScriptPath = $PWD.Path } else { $ScriptPath = $PSScriptRoot }

# --- CONFIGURATION ---
$Url_GDrive   = "https://drive.google.com/uc?export=download&id=10RxuJaWwqR1S6lbkjL0-_AXddCwOARYI"

# AZURE BLOB URL (Expires 2032)
$Url_Blob     = "https://produpdates.blob.core.windows.net/web/Prerequisite%20Script%202026/Phoenix%20Installation%20Master.zip?sp=racw&st=2026-01-30T14:01:41Z&se=2032-03-30T22:16:41Z&spr=https&sv=2024-11-04&sr=b&sig=3vXVuby1lcDbQ%2BQQnVzxmmXJsyaRG2sgQwTH9SzPnh4%3D"

$ZipNamePattern = "Phoenix Installation Master*.zip"
$InstallBase    = "C:\pnxtemp\Phoenix Installation Master"

$Global:CurrentToolPath = $InstallBase 
$Global:ToolsLoaded = $false

# ==============================================================================
#  3. LOGGING FUNCTIONS
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
        $User = $env:USERNAME
        $Entry = "[$Timestamp] [User: $User] $msg"
        Add-Content -Path $LogFile -Value $Entry -ErrorAction SilentlyContinue
    } catch {}
}

# ==============================================================================
#  4. MAIN FORM UI
# ==============================================================================
$form = New-Object System.Windows.Forms.Form
$form.Text = "Prophoenix Installation Dashboard v76.0"
$form.Size = New-Object System.Drawing.Size(1200, 800)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30) 

# --- BACKGROUND IMAGE ---
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
$lblSub = New-Object System.Windows.Forms.Label; $lblSub.Text="INSTALLATION"; $lblSub.Font=$Font_Norm; $lblSub.ForeColor=[System.Drawing.Color]::Cyan; $lblSub.Left=22; $lblSub.Top=60; $lblSub.AutoSize=$true; $lblSub.BackColor=$Col_Trans; $pnlSide.Controls.Add($lblSub)

# Buttons
$btnSearch = New-Object System.Windows.Forms.Button; $btnSearch.Text="  🔍  SEARCH MASTER"; $btnSearch.TextAlign="MiddleLeft"; $btnSearch.Font=$Font_Sub; $btnSearch.ForeColor=$Col_White; $btnSearch.BackColor=$Col_Blue; $btnSearch.FlatStyle="Flat"; $btnSearch.FlatAppearance.BorderSize=0; $btnSearch.Left=0; $btnSearch.Top=120; $btnSearch.Size=New-Object System.Drawing.Size(260, 50); $btnSearch.Cursor="Hand"; $pnlSide.Controls.Add($btnSearch)
$btnGD = New-Object System.Windows.Forms.Button; $btnGD.Text="  ☁  DOWNLOAD GDRIVE"; $btnGD.TextAlign="MiddleLeft"; $btnGD.Font=$Font_Sub; $btnGD.ForeColor=$Col_White; $btnGD.BackColor=[System.Drawing.Color]::DimGray; $btnGD.FlatStyle="Flat"; $btnGD.FlatAppearance.BorderSize=0; $btnGD.Left=0; $btnGD.Top=180; $btnGD.Size=New-Object System.Drawing.Size(260, 50); $btnGD.Cursor="Hand"; $pnlSide.Controls.Add($btnGD)
$btnAz = New-Object System.Windows.Forms.Button; $btnAz.Text="  ☁  DOWNLOAD AZ BLOB"; $btnAz.TextAlign="MiddleLeft"; $btnAz.Font=$Font_Sub; $btnAz.ForeColor=$Col_White; $btnAz.BackColor=[System.Drawing.Color]::DimGray; $btnAz.FlatStyle="Flat"; $btnAz.FlatAppearance.BorderSize=0; $btnAz.Left=0; $btnAz.Top=240; $btnAz.Size=New-Object System.Drawing.Size(260, 50); $btnAz.Cursor="Hand"; $pnlSide.Controls.Add($btnAz)

# --- HEADER ---
$pnlHead = New-Object System.Windows.Forms.Panel; $pnlHead.Dock="Top"; $pnlHead.Height=70; 
$pnlHead.BackColor=$Col_Trans; 
$form.Controls.Add($pnlHead)

# --- TITLE UPDATED HERE ---
$lblTitle = New-Object System.Windows.Forms.Label; $lblTitle.Text="Installation Dashboard"; $lblTitle.Font=$Font_Head; $lblTitle.Left=280; $lblTitle.Top=20; $lblTitle.AutoSize=$true; 
$lblTitle.ForeColor=$Col_White; 
$lblTitle.BackColor=$Col_Trans; 
$pnlHead.Controls.Add($lblTitle)
# --------------------------

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

# ==============================================================================
#  5. LOGIC
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

function Test-ZipValidity($ZipPath) {
    try {
        [System.IO.Compression.ZipFile]::OpenRead($ZipPath).Dispose()
        return $true
    } catch {
        return $false
    }
}

function Get-FriendlyName($fileName) {
    if ($fileName -match "Autodbsync" -or $fileName -match "DB Sync") { return "DB Sync Tool" }
    if ($fileName -match "RMS" -and $fileName -match "PD") { return "RMS Server PD" }
    if (($fileName -match "Cad" -and $fileName -match "Hotfix") -or ($fileName -match "CAD" -and $fileName -match "PD")) { return "CAD Server PD" }
    if ($fileName -match "Autodefined" -or ($fileName -match "Demo" -and $fileName -match "Test")) { return "Test/Demo Hotfix" }
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

# --- EVENTS ---
$btnSearch.Add_Click({ Search-Master })
$btnGD.Add_Click({ Start-Process $Url_GDrive })
$btnAz.Add_Click({ Start-Process $Url_Blob })

# --- RUN ---
$form.Add_Shown({ $form.Activate(); Search-Master })
[void] $form.ShowDialog()
# SIG # Begin signature block
# MIIdPAYJKoZIhvcNAQcCoIIdLTCCHSkCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA3sD758y16J1Gg
# 9Q0mL2qlwfsz9OqexHxLKMqgiSmOkqCCAy4wggMqMIICEqADAgECAhAX5J0M79VN
# gE0PPz0ijdWcMA0GCSqGSIb3DQEBCwUAMC0xKzApBgNVBAMMIlByb3Bob2VuaXgg
# SW50ZXJuYWwgU2NyaXB0IFNpZ25pbmcwHhcNMjYwMjA3MDMyMTQyWhcNMjcwMjA3
# MDM0MTQyWjAtMSswKQYDVQQDDCJQcm9waG9lbml4IEludGVybmFsIFNjcmlwdCBT
# aWduaW5nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAusmUZmvBvglA
# MEMbB4GXnUj2/2eie540mHKKSSP8UZcuxiu0Eb3IrUoCuOEdLvdmRKsoP30w3SGe
# 1RZ2l1Chr5W6RXBKiANemH2fpRCkNfHH+/v/DTwTRTyQqOssYFHzzfdRbsaD8Jvp
# +qgtmrQ6E3VuF0tNbLWtJBuOf2020Nr3lKyGzmJyCioCFD7cxqGhGEGHfvnHyRD3
# xnxKC3EoZd+W2N+evRu/86AGThYClv0qvhr9CvDggcIj8SfRsEU2ySYB882iZ4Dh
# DBJnjWj7CDodp7zhqLihl+2oEyGAK/uLT6G0/xiTu2BEJCN2CoILXa1BdERwvmDU
# slx5x4Ig/QIDAQABo0YwRDAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwHQYDVR0OBBYEFKUNid0ACDbOtVsDeNaGI4j/hoNvMA0GCSqGSIb3DQEB
# CwUAA4IBAQA4zhSvYuXxzBNYDZ+SdLLR2E2jcskWPgX31QdD1VGGFLjjjnL/Llfb
# sAmhERXADVADKVTCl0s5Imo0ZM2Y0wXK9Om/PwGRhiUGdMXp+kS9lhD0E9F2blQK
# JAwkr5a9J/qI4bt1CWRqRCWaBL/W4iN6DXB6U4aRCn774Z7Or9mQHoAkNHzsb3YA
# xYMNFobk8xlwWoM31MKKKOpHZOzmIoqovC5RzyBO8xMgJ7BtNYF8DvSQzxgqudf7
# JfIU2UgGauUtFvj+jfdRcV3fBlU/vRMw+clLIOBX+lZEBnOT3upEwXFKwL5O2e0o
# 1W0AV0aoZo7UTEbBvUerKwohEH444PgFMYIZZDCCGWACAQEwQTAtMSswKQYDVQQD
# DCJQcm9waG9lbml4IEludGVybmFsIFNjcmlwdCBTaWduaW5nAhAX5J0M79VNgE0P
# Pz0ijdWcMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDECMAAwGQYJKoZI
# hvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcC
# ARUwLwYJKoZIhvcNAQkEMSIEIEuIIpvtEhVSKeO+K+OKeFbpcKkYPLCFd4J/t5sf
# dsJCMA0GCSqGSIb3DQEBAQUABIIBAIIOID1KCV5/+zkTMjJATNO+lrorT2Q5W4Mr
# 59JuIDNk6uvz3XxUt8lRij7/GEym6T8UYf5Ww0ZmKu4n7qkzPJCIu7RzXQsFEHEo
# 25RMVbiZ5H883JU4zlXEI9emq52tdmpe4xw6PYpZSAdfFcATczFT/MWt8oiKoHHL
# T64+80lBVbFxk9YT7+q5LYP3u5mpaRw5R9sSRRPU7FlXcomOmCWqsDwy42dLGOj1
# papoybRUYiHiV/ShkZa350EiDWtBEnGdfur4n1KHFw3l7e0ssWhJ4mf7BQ8L15m1
# j0VylPogZ5kkvAmTWumwz0ZOthVclbP0wLLoP2onvm0suTMs8FOhghd2MIIXcgYK
# KwYBBAGCNwMDATGCF2IwghdeBgkqhkiG9w0BBwKgghdPMIIXSwIBAzEPMA0GCWCG
# SAFlAwQCAQUAMHcGCyqGSIb3DQEJEAEEoGgEZjBkAgEBBglghkgBhv1sBwEwMTAN
# BglghkgBZQMEAgEFAAQg+M631rTw8jiCvheYLjwz/QOgxsayRrna8iFsfXQ7ReAC
# EBU89tfxhjL/0T3yiIludwEYDzIwMjYwMjA3MDMzMzA4WqCCEzowggbtMIIE1aAD
# AgECAhAKgO8YS43xBYLRxHanlXRoMA0GCSqGSIb3DQEBCwUAMGkxCzAJBgNVBAYT
# AlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQg
# VHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTEw
# HhcNMjUwNjA0MDAwMDAwWhcNMzYwOTAzMjM1OTU5WjBjMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lDZXJ0IFNIQTI1
# NiBSU0E0MDk2IFRpbWVzdGFtcCBSZXNwb25kZXIgMjAyNSAxMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEA0EasLRLGntDqrmBWsytXum9R/4ZwCgHfyjfM
# GUIwYzKomd8U1nH7C8Dr0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k+87H9WPxNyFP
# JIDZHhAqlUPt281mHrBbZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9A72wzHpkBaMU
# Ng7MOLxI6E9RaUueHTQKWXymOtRwJXcrcTTPPT2V1D/+cFllESviH8YjoPFvZSjK
# s3SKO1QNUdFd2adw44wDcKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGHr7zou1znOM8o
# dbkqoK+lJ25LCHBSai25CFyD23DZgPfDrJJJK77epTwMP6eKA0kWa3osAe8fcpK4
# 0uhktzUd/Yk0xUvhDU6lvJukx7jphx40DQt82yepyekl4i0r8OEps/FNO4ahfvAk
# 12hE5FVs9HVVWcO5J4dVmVzix4A77p3awLbr89A90/nWGjXMGn7FQhmSlIUDy9Z2
# hSgctaepZTd0ILIUbWuhKuAeNIeWrzHKYueMJtItnj2Q+aTyLLKLM0MheP/9w6Ct
# juuVHJOVoIJ/DtpJRE7Ce7vMRHoRon4CWIvuiNN1Lk9Y+xZ66lazs2kKFSTnnkrT
# 3pXWETTJkhd76CIDBbTRofOsNyEhzZtCGmnQigpFHti58CSmvEyJcAlDVcKacJ+A
# 9/z7eacCAwEAAaOCAZUwggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0OBBYEFOQ7/PIx
# 7f391/ORcWMZUEPPYYzoMB8GA1UdIwQYMBaAFO9vU0rp5AZ8esrikFb2L9RJ7MtO
# MA4GA1UdDwEB/wQEAwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDCBlQYIKwYB
# BQUHAQEEgYgwgYUwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNv
# bTBdBggrBgEFBQcwAoZRaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3J0
# MF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYyMDI1Q0ExLmNy
# bDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZIhvcNAQEL
# BQADggIBAGUqrfEcJwS5rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVvhREafBYF0RkP
# 2AGr181o2YWPoSHz9iZEN/FPsLSTwVQWo2H62yGBvg7ouCODwrx6ULj6hYKqdT8w
# v2UV+Kbz/3ImZlJ7YXwBD9R0oU62PtgxOao872bOySCILdBghQ/ZLcdC8cbUUO75
# ZSpbh1oipOhcUT8lD8QAGB9lctZTTOJM3pHfKBAEcxQFoHlt2s9sXoxFizTeHihs
# QyfFg5fxUFEp7W42fNBVN4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqItH3CPFTG7aEQ
# JmmrJTV3Qhtfparz+BW60OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs7v9y69NBqycz
# 0BZwhB9WOfOu/CIJnzkQTwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E5UCSDag6+iX8
# MmB10nfldPF9SVD7weCC3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGnoa9F5AaAyBjF
# BtXVLcKtapnMG3VH3EmAp/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZyvgLfgyPehwJ
# VxwC+UpX2MSey2ueIu9THFVkT+um1vshETaWyQo8gmBto/m3acaP9QsuLj3FNwFl
# Txq25+T4QwX9xa6ILs84ZPvmpovq90K8eWyG2N01c4IhSOxqt81nMIIGtDCCBJyg
# AwIBAgIQDcesVwX/IZkuQEMiDDpJhjANBgkqhkiG9w0BAQsFADBiMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjUw
# NTA3MDAwMDAwWhcNMzgwMTE0MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEXMBUGA1UE
# ChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQg
# VGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMIICIjANBgkqhkiG
# 9w0BAQEFAAOCAg8AMIICCgKCAgEAtHgx0wqYQXK+PEbAHKx126NGaHS0URedTa2N
# DZS1mZaDLFTtQ2oRjzUXMmxCqvkbsDpz4aH+qbxeLho8I6jY3xL1IusLopuW2qft
# JYJaDNs1+JH7Z+QdSKWM06qchUP+AbdJgMQB3h2DZ0Mal5kYp77jYMVQXSZH++0t
# rj6Ao+xh/AS7sQRuQL37QXbDhAktVJMQbzIBHYJBYgzWIjk8eDrYhXDEpKk7RdoX
# 0M980EpLtlrNyHw0Xm+nt5pnYJU3Gmq6bNMI1I7Gb5IBZK4ivbVCiZv7PNBYqHEp
# NVWC2ZQ8BbfnFRQVESYOszFI2Wv82wnJRfN20VRS3hpLgIR4hjzL0hpoYGk81coW
# J+KdPvMvaB0WkE/2qHxJ0ucS638ZxqU14lDnki7CcoKCz6eum5A19WZQHkqUJfdk
# DjHkccpL6uoG8pbF0LJAQQZxst7VvwDDjAmSFTUms+wV/FbWBqi7fTJnjq3hj0Xb
# Qcd8hjj/q8d6ylgxCZSKi17yVp2NL+cnT6Toy+rN+nM8M7LnLqCrO2JP3oW//1sf
# uZDKiDEb1AQ8es9Xr/u6bDTnYCTKIsDq1BtmXUqEG1NqzJKS4kOmxkYp2WyODi7v
# QTCBZtVFJfVZ3j7OgWmnhFr4yUozZtqgPrHRVHhGNKlYzyjlroPxul+bgIspzOwb
# tmsgY1MCAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYE
# FO9vU0rp5AZ8esrikFb2L9RJ7MtOMB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/n
# upiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB3Bggr
# BgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNv
# bTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2Ny
# bDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0g
# BBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQAX
# zvsWgBz+Bz0RdnEwvb4LyLU0pn/N0IfFiBowf0/Dm1wGc/Do7oVMY2mhXZXjDNJQ
# a8j00DNqhCT3t+s8G0iP5kvN2n7Jd2E4/iEIUBO41P5F448rSYJ59Ib61eoalhnd
# 6ywFLerycvZTAz40y8S4F3/a+Z1jEMK/DMm/axFSgoR8n6c3nuZB9BfBwAQYK9FH
# aoq2e26MHvVY9gCDA/JYsq7pGdogP8HRtrYfctSLANEBfHU16r3J05qX3kId+ZOc
# zgj5kjatVB+NdADVZKON/gnZruMvNYY2o1f4MXRJDMdTSlOLh0HCn2cQLwQCqjFb
# qrXuvTPSegOOzr4EWj7PtspIHBldNE2K9i697cvaiIo2p61Ed2p8xMJb82Yosn0z
# 4y25xUbI7GIN/TpVfHIqQ6Ku/qjTY6hc3hsXMrS+U0yy+GWqAXam4ToWd2UQ1KYT
# 70kZjE4YtL8Pbzg0c1ugMZyZZd/BdHLiRu7hAWE6bTEm4XYRkA6Tl4KSFLFk43es
# aUeqGkH/wyW4N7OigizwJWeukcyIPbAvjSabnf7+Pu0VrFgoiovRDiyx3zEdmcif
# /sYQsfch28bZeUz2rtY/9TCA6TD8dC3JE3rYkrhLULy7Dc90G6e8BlqmyIjlgp2+
# VqsS9/wQD7yFylIz0scmbKvFoW2jNrbM1pD2T7m3XDCCBY0wggR1oAMCAQICEA6b
# GI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTELMAkGA1UEBhMCVVMxFTAT
# BgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEk
# MCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTIyMDgwMTAw
# MDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERp
# Z2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMY
# RGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE98orYWcLhKac9WKt2ms2u
# exuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZVXKv
# aJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7Ik/gh
# YZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7XeOt
# yU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgDEI3Y1DekLgV9iPWCPhCR
# cKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmkwuapoGfdpCe8
# oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0yt5LHucOY67m
# 1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQAzH0clcOP9yGyshG3u3/y
# 1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOkGLimdwHhD5QMIR2yVCkl
# iWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHFynIWIgnffEx1P2PsIV/E
# IFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gdLfXZqbId5RsCAwEAAaOC
# ATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFOzX44LScV1kTN8uZz/n
# upiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1UdDwEB
# /wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3Nw
# LmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDBFBgNVHR8EPjA8MDqg
# OKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURS
# b290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQwFAAOCAQEA
# cKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlUIu2kiHdtvRoU
# 9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/59PesMHqai7Je1M/RQ0Sb
# QyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1Rmpp
# VLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISfb8rbII01YBwCA8sgsKxY
# oA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhULSd+2DrZ8LaHlv1b0Vys
# GMNNn3O3AamfV6peKOK5lDGCA3wwggN4AgEBMH0waTELMAkGA1UEBhMCVVMxFzAV
# BgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVk
# IEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN
# 8QWC0cR2p5V0aDANBglghkgBZQMEAgEFAKCB0TAaBgkqhkiG9w0BCQMxDQYLKoZI
# hvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDIwNzAzMzMwOFowKwYLKoZIhvcN
# AQkQAgwxHDAaMBgwFgQU3WIwrIYKLTBr2jixaHlSMAf7QX4wLwYJKoZIhvcNAQkE
# MSIEIBadqtuBCfC+Gbrr1xX1klvgvhlXa7VnrQTRtf+ljyBdMDcGCyqGSIb3DQEJ
# EAIvMSgwJjAkMCIEIEqgP6Is11yExVyTj4KOZ2ucrsqzP+NtJpqjNPFGEQozMA0G
# CSqGSIb3DQEBAQUABIICAEqsl29O8VvhuYsh5W3e4k+Lp78IcDop/4d3P1VVa73V
# cmJzRUUzsuqsczBVViFQmCugupRvNuYJI/fNg3O1U1kL65jlzjqv1OhgQXal94Z9
# mXXEhngOrNaYvTGKhXXRiz47y0RP6ZWcuuGArTlHaJYigPiamz892ng2XpbKx0MG
# 8IUMPQ+W4iVcR+rusgWmIUu3L9NAjMPIZer0JF2v5aWcRqeeFEJAKXVjwaGbHXzJ
# bWShE8ED2NJ8+g2sYohQ9N3UnjdoGCbTeswupGDwic6zI/CLBGT7OtSWnCs83cnZ
# RmY9DcXYySS2oA/WGrpJWpvFinqrw8XFSQezKwZHG9fxNXRlc7XXiQux7tjWrjVV
# xi4TNaiF4fNo3XRKleus7j6n87cJ52xoCLDknVTPvpZhmM7Git46C0u11bPlFByF
# 5yzeWVDtD3dwP/XTcgr+vFRB+FqpmsQBgza85Qd1fMh+UQOwP94kveH1Xa2gaN3O
# pIcqzzHeR7ER6MNzKmOjEESs525PYQGMFhx6Cn7ojZ3WQ7SvR1uT9HXx81mcQyGG
# AyCzEGtZ1abqlAVebkdocaXXeWA/GjyQomnGO6XzS7VT1YNBaXBXOBd0bpjdBTEN
# OBL7pwIjJ0sL5SNoM3NzLpEtqt0pr29kEjsvmEo7W5q3DbT6Ry+dwCzj6yIUqiW5
# SIG # End signature block
