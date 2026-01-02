Write-Host "========================================="
Write-Host "   DLL BLOCK STATUS CHECK & UNBLOCK TOOL "
Write-Host "========================================="

# Prompt user for directory
$searchPath = Read-Host "Enter the folder path to scan for blocked DLL files"

# Validate path
if (-not (Test-Path $searchPath)) {
    Write-Host "ERROR: Path not found -> $searchPath" -ForegroundColor Red
    exit
}

Write-Host "`nScanning for blocked DLL files in:"
Write-Host $searchPath -ForegroundColor Cyan
Write-Host "-----------------------------------------"

# Get all DLLs recursively
$dllFiles = Get-ChildItem -Path $searchPath -Filter *.dll -Recurse -ErrorAction SilentlyContinue

if ($dllFiles.Count -eq 0) {
    Write-Host "No DLL files found in this directory." -ForegroundColor Yellow
    return
}

$blockedCount = 0
$unblockedCount = 0

foreach ($dll in $dllFiles) {

    $isBlocked = Get-Item -LiteralPath $dll.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue

    if ($isBlocked) {
        $blockedCount++

        Write-Host "`nBLOCKED  : $($dll.FullName)" -ForegroundColor Red

        try {
            Unblock-File -LiteralPath $dll.FullName
            Write-Host "UNBLOCKED: $($dll.Name)" -ForegroundColor Green
            $unblockedCount++
        }
        catch {
            Write-Host "FAILED   : Could not unblock -> $($dll.Name)" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n========================================="
Write-Host "               FINAL REPORT              "
Write-Host "========================================="
Write-Host "Total DLL Files Scanned : $($dllFiles.Count)"
Write-Host "Blocked DLLs Found     : $blockedCount"
Write-Host "Successfully Unblocked: $unblockedCount"
Write-Host "========================================="
