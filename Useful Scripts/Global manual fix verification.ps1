# --- Configuration ---
$basePath = "D:\Program Files\ProPhoenix"
# Update this path for each specific server deployment
$sourcePath = "D:\PnxTemp\manualdll\01302026\Extracted_160620\Consolidated Output"
 
# --- Initialization ---
Write-Host "[INFO] Starting Global Application Verification..." -ForegroundColor Cyan
Write-Host "[INFO] Scanning: $basePath" -ForegroundColor Yellow
 
if (-not (Test-Path $sourcePath)) {
    Write-Host "[ERROR] Source path not found: $sourcePath" -ForegroundColor Red
    return
}
 
# Get list of all applications provided in the Consolidated Output
$appsToVerify = Get-ChildItem -Path $sourcePath -Directory
$totalVerified = 0
$completed = 0
$notCompleted = 0
 
# --- Loop Through Every Application Folder ---
foreach ($appFolder in $appsToVerify) {
    $appName = $appFolder.Name
    $targetAppPath = Join-Path $basePath $appName
    # Check if this specific application is installed in the ProPhoenix directory
    if (Test-Path $targetAppPath) {
        $totalVerified++
        $mismatchFound = $false
        $errorList = @()
        # Deep-scan: Recurse through all sub-folders (Bin, Booking, Forms, State, etc.)
        $sourceFiles = Get-ChildItem -Path $appFolder.FullName -Recurse -File
        foreach ($file in $sourceFiles) {
            # Map the relative path from Source to Destination
            $relativePath = $file.FullName.Substring($appFolder.FullName.Length + 1)
            $targetFile = Join-Path $targetAppPath $relativePath
            if (Test-Path $targetFile) {
                # Compare Hash for exact match (DLLs, ASPX, JS, PNG, PDF, etc.)
                $sHash = (Get-FileHash $file.FullName -Algorithm SHA256).Hash
                $tHash = (Get-FileHash $targetFile -Algorithm SHA256).Hash
                if ($sHash -ne $tHash) {
                    $mismatchFound = $true
                    $errorList += "Mismatch: $relativePath"
                }
            } else {
                $mismatchFound = $true
                $errorList += "Missing: $relativePath"
            }
        }
 
        # --- Display Result ---
        if (-not $mismatchFound) {
            Write-Host "[OK] $appName → Live : " -NoNewline -ForegroundColor Green
            Write-Host "þ Completed" -ForegroundColor Green
            $completed++
        } else {
            Write-Host "[FAIL] $appName → Live : " -NoNewline -ForegroundColor Red
            Write-Host "o Not Completed" -ForegroundColor Red
            # Optional: Uncomment the line below to see exactly which files failed
            # $errorList | ForEach-Object { Write-Host "     -> $_" -ForegroundColor Gray }
            $notCompleted++
        }
    }
}
 
# --- Final Summary ---
Write-Host "`n[INFO] DLL & Asset verification completed." -ForegroundColor Cyan
Write-Host "---------------------------------------"
Write-Host "Total Apps Verified : $totalVerified"
Write-Host "Completed           : $completed" -ForegroundColor Green
Write-Host "Not Completed       : $notCompleted" -ForegroundColor Red
Write-Host "---------------------------------------"