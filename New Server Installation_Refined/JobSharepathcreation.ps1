Clear-Host
#Requires -RunAsAdministrator

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  ProPhoenix Folder & Share Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. Fetch the Base Path Automatically
$baseFolder = "Program Files\ProPhoenix"
$basePath = ""

foreach ($drive in (Get-PSDrive -PSProvider FileSystem)) {
    $testPath = Join-Path -Path $drive.Root -ChildPath $baseFolder
    if (Test-Path $testPath) {
        $basePath = $testPath
        break
    }
}

if ([string]::IsNullOrEmpty($basePath)) {
    $basePath = "$($env:SystemDrive)\$baseFolder"
    Write-Host "ProPhoenix base path not found. Defaulting to: $basePath" -ForegroundColor Yellow
} else {
    Write-Host "Found Base Path: $basePath" -ForegroundColor Green
}

# 2. Fetch ALL Instance Folders
$cadInstances = @()
$pnxInstances = @()

$cadInstancePath = Join-Path $basePath "CAD Server\_Instances"
if (Test-Path $cadInstancePath) {
    $cadInstances = (Get-ChildItem -Path $cadInstancePath -Directory).Name
}
if ($cadInstances.Count -eq 0) { $cadInstances = @("Live") } 

$pnxInstancePath = Join-Path $basePath "PnxFolderWatcher\_instance"
if (Test-Path $pnxInstancePath) {
    $pnxInstances = (Get-ChildItem -Path $pnxInstancePath -Directory).Name
}
if ($pnxInstances.Count -eq 0) { $pnxInstances = @("Test") } 

Write-Host "----------------------------------------"
Write-Host "Detected CAD Server Instances: $($cadInstances -join ', ')" -ForegroundColor Cyan
Write-Host "Detected PnxFolderWatcher Instances: $($pnxInstances -join ', ')" -ForegroundColor Cyan
Write-Host "----------------------------------------"

# 3. Build the list of folders to create dynamically
$foldersToCreate = @(
    "Custom",
    "Attachment",
    "Attachment\Job",
    "Watch",
    "ScreenDocs",
    "Police RMS\Records\Hotsheet",
    "FTP\CAD Data\KPI Data",
    "FTP\WDA Data\KPI Data"
)

# Add CAD Server Bolo folder for EVERY instance found
foreach ($cadInst in $cadInstances) {
    $foldersToCreate += "CAD Server\_Instances\$cadInst\Bolo"
}

# Add PnxFolderWatcher folders for EVERY instance found
foreach ($pnxInst in $pnxInstances) {
    $foldersToCreate += "PnxFolderWatcher\_instance\$pnxInst\Rpt"
    $foldersToCreate += "PnxFolderWatcher\_instance\$pnxInst\Rpt\GettxtFile"
    $foldersToCreate += "PnxFolderWatcher\_instance\$pnxInst\Rpt\ProcessedRpt"
    $foldersToCreate += "PnxFolderWatcher\_instance\$pnxInst\Rpt\ErrorRpt"
}

Write-Host "`nCreating Directories..." -ForegroundColor Cyan
foreach ($folder in $foldersToCreate) {
    $fullPath = Join-Path $basePath $folder
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-Host " [Created] $fullPath"
    } else {
        Write-Host " [Exists]  $fullPath" -ForegroundColor DarkGray
    }
}

# 4. Create Shared Folders (Share Permissions set to Full Control, Change, Read via -FullAccess)
$hostName = $env:COMPUTERNAME
$finalSharePaths = @() # Array to store the final list for copy-pasting

$sharesToCreate = @{
    "Custom" = "Custom"
    "Job" = "Attachment\Job"
    "Hotsheet" = "Police RMS\Records\Hotsheet"
    "WDA App webservice" = "WDA App webservice" 
    "Phoenix Report Writer API" = "Phoenix Report Writer API"
    "Fire WebService" = "Fire WebService"
    "ftp" = "FTP" 
}

# Handle Bolo Shares: 'Live' gets "Bolo", others get "Bolo1", "Bolo2", etc.
$boloCounter = 1
foreach ($cadInst in $cadInstances) {
    if ($cadInst -eq "Live") { 
        $shareName = "Bolo"
    } else {
        $shareName = "Bolo$boloCounter"
        $boloCounter++
    }
    
    $sharesToCreate[$shareName] = "CAD Server\_Instances\$cadInst\Bolo"
}

Write-Host "`nConfiguring Shared Folders for Server: \\$hostName" -ForegroundColor Cyan
Write-Host "----------------------------------------"

foreach ($shareName in $sharesToCreate.Keys) {
    $relativePath = $sharesToCreate[$shareName]
    $targetFolderPath = Join-Path $basePath $relativePath

    if (Test-Path $targetFolderPath) {
        $existingShare = Get-SmbShare -Name $shareName -ErrorAction SilentlyContinue
        
        if (-not $existingShare) {
            New-SmbShare -Name $shareName -Path $targetFolderPath -FullAccess "Everyone" | Out-Null
            Write-Host " [Success] Created Share: \\$hostName\$shareName -> $targetFolderPath" -ForegroundColor Green
        } else {
            Write-Host " [Skipped] Share '\\$hostName\$shareName' already exists." -ForegroundColor Yellow
        }

        # Add to the final results list
        if ($shareName -eq "ftp") {
            $finalSharePaths += "\\$hostName\ftp\CAD Data\KPI Data"
            $finalSharePaths += "\\$hostName\ftp\WDA Data\KPI Data"
        } else {
            $finalSharePaths += "\\$hostName\$shareName"
        }

    } else {
        Write-Host " [Missing Notification] Cannot create share '\\$hostName\$shareName'. The physical folder '$targetFolderPath' is missing." -ForegroundColor Red
    }
}

# 5. Apply NTFS Security Permissions to the ProPhoenix Base Folder
Write-Host "`nConfiguring NTFS Permissions on Base Folder..." -ForegroundColor Cyan
Write-Host "----------------------------------------"

try {
    if (-not (Test-Path $basePath)) {
        New-Item -ItemType Directory -Path $basePath -Force | Out-Null
    }

    $acl = Get-Acl $basePath
    
    $inheritanceFlag = [System.Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [System.Security.AccessControl.InheritanceFlags]::ObjectInherit
    $propagationFlag = [System.Security.AccessControl.PropagationFlags]::None
    
    $accountsToAdd = @("NETWORK SERVICE", "IUSR")
    
    foreach ($account in $accountsToAdd) {
        $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($account, "FullControl", $inheritanceFlag, $propagationFlag, "Allow")
        $acl.AddAccessRule($accessRule)
        Write-Host " [Applied] Full Control granted to: $account" -ForegroundColor Green
    }
    
    Set-Acl -Path $basePath -AclObject $acl
    Write-Host " [Success] Folder permissions updated successfully." -ForegroundColor Green
    
} catch {
    Write-Host " [Error] Failed to set NTFS permissions. Please ensure you are running as Administrator." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# 6. Final Clean Output for Copy-Pasting
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  Final Shared Paths (Ready to Copy)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

foreach ($path in $finalSharePaths) {
    Write-Host $path
}

Write-Host "`nScript Execution Completed." -ForegroundColor Green