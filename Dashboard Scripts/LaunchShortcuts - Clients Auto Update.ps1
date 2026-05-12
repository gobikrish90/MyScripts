$DesktopPaths = @(
    [Environment]::GetFolderPath("Desktop"),
    [Environment]::GetFolderPath("CommonDesktopDirectory")
)
Write-Host "Searching Desktops for Stage/Client Shortcuts..."
$Found = 0
foreach ($path in $DesktopPaths) {
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Filter "*.lnk" | ForEach-Object {
            $n = $_.Name
            # EXCLUDE Application Manager
            if ($n -match "Manager") { return }
            
            # INCLUDE CAD Client, WDA, WDA V2
            if (($n -match "CAD" -and $n -match "Client") -or $n -match "WDA") {
                 Write-Host "   [LAUNCH] $n" -ForegroundColor Green; Start-Process -FilePath $_.FullName -Verb RunAs; $Found++
            }
        }
    }
}
if ($Found -eq 0) { Write-Host "   (No WDA/CAD shortcuts found)" -ForegroundColor DarkGray }
