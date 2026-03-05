# --- Configuration ---
$basePath = "D:\Program Files\ProPhoenix"
$sourcePath = "D:\PnxTemp\Manual DLL\01302026\2024R2-12-5-ConsolidatedFiles_(013026)\Consolidated Output"

# --- Rename Mapping Dictionary ---
$nameMapping = @{
    "Fire Response CAD Webservice" = "WDA App webservice"
    "PnxInspectionApi"             = "Phoenix Inspection API"
    "Device Notification Server"  = "Phoenix Device Notification"
}

# --- Initialization ---
Write-Host "[INFO] Starting Date-Modified Verification..." -ForegroundColor Cyan
if (-not (Test-Path $sourcePath)) {
    Write-Host "[ERROR] Source path not found: $sourcePath" -ForegroundColor Red
    return
}

$appsInSource = Get-ChildItem -Path $sourcePath -Directory
$totalVerified = 0; $completed = 0; $notCompleted = 0

foreach ($appFolder in $appsInSource) {
    $sourceName = $appFolder.Name
    $targetName = $sourceName
    $isRenamed = $false

    if ($nameMapping.ContainsKey($sourceName)) {
        $targetName = $nameMapping[$sourceName]
        $isRenamed = $true
    }

    $targetAppPath = Join-Path $basePath $targetName
    $totalVerified++

    # 1. Check if Application is Installed
    if (-not (Test-Path $targetAppPath)) {
        Write-Host "[FAIL] $sourceName → Live : " -NoNewline -ForegroundColor Red
        Write-Host "o Not Installed" -ForegroundColor Red
        $notCompleted++
        continue
    }

    # 2. Check if Source Folder is Empty
    $sourceFiles = Get-ChildItem -Path $appFolder.FullName -Recurse -File
    if ($sourceFiles.Count -eq 0) {
        Write-Host "[FAIL] $sourceName → Live : " -NoNewline -ForegroundColor Red
        Write-Host "o Empty" -ForegroundColor Red
        $notCompleted++
        continue
    }

    if ($isRenamed) { Write-Host "[WARN] Name Mismatched: '$sourceName' matched to '$targetName'" -ForegroundColor Yellow }

    # 3. Date & Integrity Verification
    $mismatchFound = $false
    
    foreach ($file in $sourceFiles) {
        $relativePath = $file.FullName.Substring($appFolder.FullName.Length + 1)
        $targetFile = Join-Path $targetAppPath $relativePath
        
        if (Test-Path $targetFile) {
            $sourceDate = (Get-Item $file.FullName).LastWriteTime
            $targetDate = (Get-Item $targetFile).LastWriteTime
            
            # Compare Date Modified
            # We allow a small 2-second buffer for file system variations
            if ([Math]::Abs(($sourceDate - $targetDate).TotalSeconds) -gt 2) {
                $mismatchFound = $true
                # Optional: Show which specific file has the wrong date
                # Write-Host "     -> Date Mismatch: $relativePath (Src: $sourceDate vs Live: $targetDate)" -ForegroundColor Gray
            }
        } else {
            $mismatchFound = $true
        }
    }

    # Final Display
    if (-not $mismatchFound) {
        Write-Host "[OK] $targetName → Live : " -NoNewline -ForegroundColor Green
        Write-Host "þ Completed" -ForegroundColor Green
        $completed++
    } else {
        Write-Host "[FAIL] $targetName → Live : " -NoNewline -ForegroundColor Red
        Write-Host "o Not Completed (Date Mismatch/Missing)" -ForegroundColor Red
        $notCompleted++
    }
}

Write-Host "`n[INFO] Verification Summary" -ForegroundColor Cyan
Write-Host "Total Apps Checked : $totalVerified"
Write-Host "Completed          : $completed" -ForegroundColor Green
Write-Host "Errors/Not Applied : $notCompleted" -ForegroundColor Red