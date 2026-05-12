Write-Host "========================================="
Write-Host "            SCRIPT STARTED               "
Write-Host "========================================="

# Get all available drives and search for ProPhoenix directories that contain "_Instances"
$proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object {
    "$($_.Root)\Program Files\ProPhoenix"
} | Where-Object { Test-Path -Path $_ }

Write-Host "\n[INFO] Searching for '_Instances' folders..."

# Get all instance folders dynamically
$instanceFolders = foreach ($basePath in $proPhoenixBasePaths) {
    Get-ChildItem -Path $basePath -Directory -Recurse | Where-Object {
        Test-Path -Path "$($_.FullName)\_Instances"
    }
}

if ($instanceFolders.Count -eq 0) {
    Write-Host "[WARNING] No '_Instances' folders found. Exiting..."
    exit
}

Write-Host "[INFO] Detecting environment types..."

# Find all environment types dynamically by scanning the '_Instances' folder
$environmentTypes = @()
foreach ($folder in $instanceFolders) {
    $envFolders = Get-ChildItem -Path "$($folder.FullName)\_Instances" -Directory | Select-Object -ExpandProperty Name
    $environmentTypes += $envFolders
}
$environmentTypes = $environmentTypes | Sort-Object -Unique

Write-Host "[SUCCESS] Found environments: $($environmentTypes -join ', ')\n"

Write-Host "========================================="
Write-Host "          PROCESSING LOG FILES           "
Write-Host "========================================="

foreach ($folder in $instanceFolders) {
    foreach ($environmentType in $environmentTypes) {
        $targetPath = "$($folder.FullName)\_Instances\$environmentType\PnxLog"
        $oldFolderPath = "$targetPath\old"

        if (Test-Path -Path $targetPath) {
            $filesToMove = Get-ChildItem -Path $targetPath -File | Where-Object { $_.FullName -notlike "$oldFolderPath*" }
            
            if ($filesToMove.Count -gt 0) {
                if (!(Test-Path -Path $oldFolderPath)) {
                    New-Item -ItemType Directory -Path $oldFolderPath | Out-Null
                }

                Get-ChildItem -Path $oldFolderPath -File | Remove-Item -Force

                foreach ($file in $filesToMove) {
                    Move-Item -Path $file.FullName -Destination $oldFolderPath
                }

                Write-Host "[SUCCESS] Logs processed for: $environmentType ($targetPath)"
            } else {
                Write-Host "[INFO] No log files in: $targetPath. Skipping..."
            }
        } else {
            Write-Host "[WARNING] Missing environment folder: $environmentType ($($folder.FullName)\_Instances)"
        }
    }
}

Write-Host "\n========================================="
Write-Host "            SCRIPT COMPLETED             "
Write-Host "========================================="