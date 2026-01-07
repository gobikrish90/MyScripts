# Configuration
$MinVersion = [version]"8.0.4"
$Exceptions = @("7.5", "7.0") # Keep 7.5 (and 7.0 to be safe)

# Registry Paths to search (64-bit and 32-bit)
$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

Write-Host "Scanning for .NET components older than $MinVersion..." -ForegroundColor Cyan
Write-Host "Excluding versions matching: $($Exceptions -join ', ')" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------"

foreach ($Path in $RegistryPaths) {
    $Keys = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue

    foreach ($Key in $Keys) {
        $DisplayName = $Key.GetValue("DisplayName")
        $DisplayVersion = $Key.GetValue("DisplayVersion")
        $UninstallString = $Key.GetValue("UninstallString")
        $PSChildName = $Key.PSChildName # Product Code (GUID)

        # Skip if no name
        if ([string]::IsNullOrWhiteSpace($DisplayName)) { continue }

        # Filter: We only care about .NET Core / .NET 5+ / Hosting Bundles
        # We ignore pure .NET Framework (4.x) to avoid breaking the OS
        if ($DisplayName -match "Microsoft .NET" -or $DisplayName -match "Windows Server Hosting") {
            
            # Refine Filter: Look for SDKs, Runtimes, or Hosting Bundles
            if ($DisplayName -match "SDK" -or $DisplayName -match "Hosting" -or $DisplayName -match "Runtime") {

                # Attempt to parse version
                if ($DisplayVersion) {
                    try {
                        # Clean version string (remove preview tags for comparison)
                        $CleanVerString = $DisplayVersion.Split('-')[0] 
                        $CurrentVer = [version]$CleanVerString

                        # CHECK: Is it older than 8.0.4?
                        if ($CurrentVer -lt $MinVersion) {
                            
                            # CHECK EXCEPTION: Does it match "7.5"?
                            $IsException = $false
                            foreach ($Ex in $Exceptions) {
                                if ($DisplayName -like "*$Ex*" -or $DisplayVersion -like "*$Ex*") {
                                    $IsException = $true
                                }
                            }

                            if ($IsException) {
                                Write-Host "SKIPPING (Exception): $DisplayName ($DisplayVersion)" -ForegroundColor Green
                            }
                            else {
                                Write-Host "UNINSTALLING: $DisplayName ($DisplayVersion)" -ForegroundColor Yellow
                                
                                # --- UNINSTALL LOGIC ---
                                if ($PSChildName -match '{[A-F0-9-]{36}}') {
                                    # MSI Uninstall
                                    $Args = "/x $PSChildName /qn /norestart"
                                    Start-Process "msiexec.exe" -ArgumentList $Args -Wait -NoNewWindow
                                }
                                elseif ($Key.GetValue("QuietUninstallString")) {
                                    # Quiet String Uninstall
                                    $QuietStr = $Key.GetValue("QuietUninstallString")
                                    # Simple parse for exe/args
                                    if ($QuietStr -match '^"([^"]+)"\s+(.*)$') {
                                        $Exe = $Matches[1]; $Args = $Matches[2]
                                    } else {
                                        $Exe = $QuietStr.Split(' ')[0]; $Args = $QuietStr.Substring($Exe.Length).Trim()
                                    }
                                    Start-Process $Exe -ArgumentList $Args -Wait -NoNewWindow
                                }
                                else {
                                    Write-Host "  -> No silent uninstaller found. Skipping." -ForegroundColor Red
                                }
                                Write-Host "  -> Done." -ForegroundColor DarkGray
                            }
                        }
                    }
                    catch {
                        # Version parse failed (rare), skip it to be safe
                    }
                }
            }
        }
    }
}

Write-Host "--------------------------------------------------------"
Write-Host "Scan and cleanup complete." -ForegroundColor Cyan