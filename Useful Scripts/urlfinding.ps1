# Import the IIS WebAdministration module
Import-Module WebAdministration

# Create a list to hold the results
$results = @()

# Define the STRICT path endings we are looking for.
# The script will only list an app if its folder path ENDS with one of these.
$targetEnvironments = @{
    "Police RMS"  = "\ProPhoenix\Police RMS"
    "Fire RMS"    = "\ProPhoenix\Fire RMS"
    "Phoenix IA"  = "\ProPhoenix\PhoenixIA"
}

# Get all IIS Websites
$sites = Get-Website

foreach ($site in $sites) {
    # Get bindings for this site
    $bindings = $site.bindings.Collection

    foreach ($binding in $bindings) {
        # Parse binding info
        $protocol = $binding.protocol
        $info = $binding.bindingInformation -split ":"
        $ip = $info[0]
        $port = $info[1]
        $hostHeader = $info[2]

        # FILTER 1: Skip if the port is NOT 443
        if ($port -ne "443") { continue }

        # Determine hostname
        if ($ip -eq "*" -and [string]::IsNullOrEmpty($hostHeader)) {
            $hostname = "localhost"
        } elseif ([string]::IsNullOrEmpty($hostHeader)) {
            $hostname = $ip 
        } else {
            $hostname = $hostHeader
        }

        # URL Construction
        $cleanBaseUrl = "{0}://{1}" -f $protocol, $hostname

        # Helper function for STRICT matching
        function Get-StrictEnvironmentName ($path) {
            # Remove trailing slash for consistent matching
            $cleanPath = $path.TrimEnd('\')
            
            foreach ($key in $targetEnvironments.Keys) {
                $targetEnding = $targetEnvironments[$key]
                # Check if the path ends exactly with the target string (e.g. ends with "\ProPhoenix\PhoenixIA")
                if ($cleanPath.EndsWith($targetEnding, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $key
                }
            }
            return $null
        }

        # --- CHECK 1: Is the ROOT SITE itself one of the environments? ---
        $rootEnv = Get-StrictEnvironmentName -path $site.physicalPath
        if ($rootEnv) {
            $results += [PSCustomObject]@{
                Environment    = $rootEnv
                CleanURL       = "$cleanBaseUrl/"
                LocalDirectory = $site.physicalPath
            }
        }

        # --- CHECK 2: Check SUB-APPLICATIONS ---
        $applications = Get-WebApplication -Site $site.name
        
        foreach ($app in $applications) {
            $appPath = $app.PhysicalPath
            
            # STRICT FILTER: Only returns true if the folder path matches exactly
            $appEnv = Get-StrictEnvironmentName -path $appPath
            
            if ($appEnv) {
                $urlPath = $app.Path
                $cleanAppUrl = "{0}{1}" -f $cleanBaseUrl, $urlPath
                
                $results += [PSCustomObject]@{
                    Environment    = $appEnv
                    CleanURL       = $cleanAppUrl
                    LocalDirectory = $appPath
                }
            }
        }
    }
}

# Output the results
$results | Format-Table Environment, CleanURL, LocalDirectory -AutoSize