Write-Host "Cleaning CAD Server Session Data..."
$proPhoenixBasePaths = Get-PSDrive -PSProvider FileSystem | ForEach-Object { 
    "$($_.Root)Program Files (x86)\ProPhoenix", "$($_.Root)Program Files\ProPhoenix" 
} | Where-Object { Test-Path -Path $_ }

foreach ($basePath in $proPhoenixBasePaths) {
    $cadServerPath = Join-Path -Path $basePath -ChildPath "CAD Server\_Instances"
    if (Test-Path $cadServerPath) {
        $cadInstances = Get-ChildItem -Path $cadServerPath -Directory -ErrorAction SilentlyContinue
        foreach ($inst in $cadInstances) {
            $sessionDataPath = Join-Path -Path $inst.FullName -ChildPath "SvrSessionData"
            if (Test-Path $sessionDataPath) {
                Write-Host "   Target: $($inst.Name)"
                $delCount = 0
                Get-ChildItem -Path $sessionDataPath -File -ErrorAction SilentlyContinue | ForEach-Object { 
                    try { 
                        Remove-Item -Path $_.FullName -Force -ErrorAction Stop 
                        $delCount++
                    } catch { 
                        Write-Host "      [LOCKED] $($_.Name)" -ForegroundColor Gray 
                    }
                }
                if ($delCount -gt 0) { Write-Host "      Removed $delCount session files." -ForegroundColor DarkGray }
            }
        }
    }
}
Write-Host "Session Cleanup Complete."
