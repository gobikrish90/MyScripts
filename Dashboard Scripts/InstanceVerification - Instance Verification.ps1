# -----------------------------------------------
# DLL Verification Script for ProPhoenix Applications
# -----------------------------------------------
Write-Host "[INFO] Starting DLL verification..." -ForegroundColor Cyan

$prophoenixPaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    $driveRoot = "$($_.Root)Program Files\ProPhoenix"
    if (Test-Path $driveRoot) { $driveRoot }
}

if (-not $prophoenixPaths) {
    Write-Host "[ERROR] No ProPhoenix installation found." -ForegroundColor Red
    exit
}

Write-Host "`n[INFO] Found base paths:" -ForegroundColor Cyan
$prophoenixPaths | ForEach-Object { Write-Host " - $_" }

$excludedFolders = @("Finger Print Client","ID Scanner","Phoenix WDA V2","Police RMS","PoliceRMS","Print Server","WDA")
$completedCount = 0
$notCompletedCount = 0
$totalChecked = 0

foreach ($basePath in $prophoenixPaths) {
    Write-Host "`n[INFO] Scanning applications in: $basePath" -ForegroundColor Yellow
    $appFolders = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue | Where-Object { $excludedFolders -notcontains $_.Name }

    foreach ($app in $appFolders) {
        $instancesPath = Join-Path $app.FullName "_Instances"
        if (Test-Path $instancesPath) {
            $instanceEnvs = Get-ChildItem -Path $instancesPath -Directory -ErrorAction SilentlyContinue
            foreach ($env in $instanceEnvs) {
                $baseDlls = Get-ChildItem -Path $app.FullName -Filter *.dll -File -ErrorAction SilentlyContinue
                $instanceDlls = Get-ChildItem -Path $env.FullName -Filter *.dll -File -ErrorAction SilentlyContinue
                $status = "Completed"

                foreach ($dll in $baseDlls) {
                    $match = $instanceDlls | Where-Object { $_.Name -eq $dll.Name }
                    if ($match) {
                        if (($match.LastWriteTime -lt $dll.LastWriteTime) -or ($match.Length -ne $dll.Length)) {
                            $status = "Not Completed"; break
                        }
                    } else {
                        $status = "Not Completed"; break
                    }
                }

                $totalChecked++
                if ($status -eq "Completed") {
                    $completedCount++
                    Write-Host ("[OK] " + $app.Name + " -> " + $env.Name + " : Completed") -ForegroundColor Green
                } else {
                    $notCompletedCount++
                    Write-Host ("[WARN] " + $app.Name + " -> " + $env.Name + " : Not Completed") -ForegroundColor Red
                }
            }
        }
    }
}

Write-Host "`n[INFO] DLL verification completed." -ForegroundColor Cyan
Write-Host ("--------------------------------------")
Write-Host ("Total Verified : " + $totalChecked)
Write-Host ("Completed      : " + $completedCount) -ForegroundColor Green
Write-Host ("Not Completed  : " + $notCompletedCount) -ForegroundColor Red
Write-Host ("--------------------------------------")
