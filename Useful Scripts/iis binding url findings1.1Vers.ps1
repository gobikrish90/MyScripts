# Import the IIS WebAdministration module
Import-Module WebAdministration

# Create a list to hold the results
$results = @()

# Get all IIS Websites
$sites = Get-Website

foreach ($site in $sites) {
    # Get bindings for this site (http/https, port, host header)
    $bindings = $site.bindings.Collection

    foreach ($binding in $bindings) {
        # Build the base URL parts
        $protocol = $binding.protocol
        $info = $binding.bindingInformation -split ":"
        $ip = $info[0]
        $port = $info[1]
        $hostHeader = $info[2]

        # Determine hostname
        if ($ip -eq "*" -and [string]::IsNullOrEmpty($hostHeader)) {
            $hostname = "localhost"
        } elseif ([string]::IsNullOrEmpty($hostHeader)) {
            $hostname = $ip 
        } else {
            $hostname = $hostHeader
        }

        # FIX: Use the -f format operator to avoid parsing errors
        $baseUrl = "{0}://{1}:{2}" -f $protocol, $hostname, $port

        # 1. Add the Root Site URL
        $results += [PSCustomObject]@{
            SiteName    = $site.name
            AppName     = "Root"
            AppPath     = "/"
            FullURL     = "$baseUrl/"
            BindingInfo = $binding.bindingInformation
        }

        # 2. Get all Applications inside this site
        $applications = Get-WebApplication -Site $site.name
        
        foreach ($app in $applications) {
            # Construct app URL safely
            $appPath = $app.Path
            $fullAppUrl = "{0}{1}" -f $baseUrl, $appPath
            
            $results += [PSCustomObject]@{
                SiteName    = $site.name
                AppName     = $app.Name
                AppPath     = $appPath
                FullURL     = $fullAppUrl
                BindingInfo = $binding.bindingInformation
            }
        }
    }
}

# Output the results in a table
$results | Format-Table -AutoSize