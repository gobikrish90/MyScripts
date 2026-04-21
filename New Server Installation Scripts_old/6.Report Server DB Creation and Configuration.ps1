<#
# Add Your Server name
# Your server and instance
# Your sa Password
# Add the version 
#For :
1 - Below 2019 version enter : v15
2 - 2019-22 version enter : v16
#>

  # ---------------------------------------------Establish a connection to the database server using sa credentials-----------------------------------------
   $serverName = "NJ-RWB-SVR-01\PHOENIX" # Your server and instance
   $saUser = "sa" # Your SQLUser name 
   $saPassword = "Pnx@#Pleasant14" # Your sa Password
   $version = "v16"

function Get-ConfigSet() {
    return Get-WmiObject –namespace "root\Microsoft\SqlServer\ReportServer\RS_SSRS\$version\Admin" `
        -class MSReportServer_ConfigurationSetting -ComputerName $env:COMPUTERNAME
}

# Allow importing of sqlps module
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Force

# Retrieve the current configuration
$configset = Get-ConfigSet

$configset

If (! $configset.IsInitialized) {
    # Get the ReportServer and ReportServerTempDB creation script
    [string]$dbscript = $configset.GenerateDatabaseCreationScript("ReportServer", 1033, $false).Script

    # Output the creation script for debugging
    Write-Host "Database Creation Script:"
    Write-Host $dbscript

    # Split the script into individual commands, removing 'GO' statements
    $commands = $dbscript -split '\bGO\b'

    # Import the SQL Server PowerShell module
    Import-Module sqlps -DisableNameChecking | Out-Null


    # Create the connection
    $connectionString = "Server=$serverName;Database=master;User ID=$saUser;Password=$saPassword;"
    $conn = New-Object System.Data.SqlClient.SqlConnection($connectionString)

    try {
        $conn.Open()
        Write-Host "Successfully connected to SQL Server as 'sa'."

        # Create a command object to execute each command
        $cmd = $conn.CreateCommand()

        # Execute each command individually
        foreach ($command in $commands) {
            $command = $command.Trim()
            if (-not [string]::IsNullOrEmpty($command)) {
                try {
                    $cmd.CommandText = $command
                    $cmd.ExecuteNonQuery()
                } catch {
                    Write-Host "Failed to execute command."
                    Write-Host "Command: $command"
                    Write-Host "Error Message: $_.Exception.Message"
                }
            }
        }

        Write-Host "Database 'ReportServer' created successfully."

        # Now, retrieve the database object
        $smoConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection($conn)
        $smo = New-Object Microsoft.SqlServer.Management.Smo.Server -ArgumentList $smoConnection
        $db = $smo.Databases["ReportServer"]

        # Set permissions for the databases
        if ($db -ne $null) {
            $dbscript = $configset.GenerateDatabaseRightsScript($configset.WindowsServiceIdentityConfigured, "ReportServer", $false, $true).Script
            Write-Host "Generating and executing permission script for the 'ReportServer' database."
            # Execute the permission script on the database
	    Write-Host "Executing permission script on the database."
            $db.ExecuteNonQuery($dbscript)
        } else {
            Write-Host "Failed to retrieve the 'ReportServer' database object."
        }

        # Set the database connection info using sa credentials
        $configset.SetDatabaseConnection("$serverName", "ReportServer", 2, $saUser, $saPassword)

        $configset.SetVirtualDirectory("ReportServerWebService", "ReportServer", 1033)
        $configset.ReserveURL("ReportServerWebService", "http://+:80", 1033)

        # For SSRS 2020 (v16)
        $configset.SetVirtualDirectory("ReportServerWebService", "ReportServer", 1033)
        $configset.ReserveURL("ReportServerWebService", "http://+:80", 1033)

        $configset.SetVirtualDirectory("ReportServerWebApp", "Reports", 1033)
        $configset.ReserveURL("ReportServerWebApp", "http://+:80", 1033)

        # Initialize Report Server
        $configset.InitializeReportServer($configset.InstallationID)

        # Re-start services?
        $configset.SetServiceState($false, $false, $false)
        Restart-Service $configset.ServiceName
        $configset.SetServiceState($true, $true, $true)

        # Update the current configuration
        $configset = Get-ConfigSet

        # Output to screen
        $configset.IsReportManagerEnabled
        $configset.IsInitialized
        $configset.IsWebServiceEnabled
        $configset.IsWindowsServiceEnabled
        $configset.ListReportServersInDatabase()
        $configset.ListReservedUrls()

        $inst = Get-WmiObject –namespace "root\Microsoft\SqlServer\ReportServer\RS_SSRS\$version" `
            -class MSReportServer_Instance -ComputerName $env:COMPUTERNAME

        $inst.GetReportServerUrls()
    } catch {
        Write-Host "Failed to execute command."
        Write-Host "Error Message: $_.Exception.Message"
    } finally {
        $conn.Close() # Ensure the connection is closed
    }
}

# Define the path to the rsreportserver.config file
$configFilePath = "C:\Program Files\Microsoft SQL Server Reporting Services\SSRS\ReportServer\rsreportserver.config"

# Load the XML configuration file
[xml]$configXml = Get-Content -Path $configFilePath

# Define the XPath to the AuthenticationTypes node
$authTypesNode = $configXml.SelectSingleNode("//AuthenticationTypes")

# Check if the node exists and contains RSWindowsNTLM
if ($authTypesNode -ne $null) {
    # Check if RSWindowsNegotiate already exists
    $existingNegotiateNode = $authTypesNode.SelectSingleNode("RSWindowsNegotiate")
    
    # If RSWindowsNegotiate does not exist, add it
    if ($existingNegotiateNode -eq $null) {
        # Create a new RSWindowsNegotiate element and append it
        $newAuthNode = $configXml.CreateElement("RSWindowsNegotiate")
        $authTypesNode.AppendChild($newAuthNode)

        # Save the modified XML back to the config file
        $configXml.Save($configFilePath)

        # Output the change that was made
        Write-Host "Added <RSWindowsNegotiate/> to the AuthenticationTypes section."
    } else {
        Write-Host "<RSWindowsNegotiate/> already exists in the AuthenticationTypes section."
    }
} else {
    Write-Host "AuthenticationTypes section not found in the configuration file."
}

# Restart the SSRS service (ensure the service name is correct for your environment)
$ssrsServiceName = "SQL Server Reporting Services"
Restart-Service -Name $ssrsServiceName -Force

# Print the status of SSRS service restart
Write-Host "SSRS service has been restarted."

