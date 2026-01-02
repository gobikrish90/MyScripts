# Define the path to the notepad file
$inputFilePath = "D:\GEOMaps.txt"

# Read the contents of the notepad file
$inputFileContent = Get-Content $inputFilePath

# Extract SQL Server connection details from the input file
$server = ($inputFileContent | Select-String "Server:" | ForEach-Object { $_.Line.Split(':')[1].Trim() })
$database = ($inputFileContent | Select-String "Database:" | ForEach-Object { $_.Line.Split(':')[1].Trim() })
$saUser = ($inputFileContent | Select-String "SAUser:" | ForEach-Object { $_.Line.Split(':')[1].Trim() })
$saPassword = ($inputFileContent | Select-String "SAPassword:" | ForEach-Object { $_.Line.Split(':')[1].Trim() })

# Extract the ParamID and ParamValue pairs from the notepad file
$paramValues = @{}

# Loop through each line of the input file and extract ParamID and ParamValue
foreach ($line in $inputFileContent) {
    if ($line -match "^(\d+)\s*=\s*(.+)$") {
        $paramID = [int]$matches[1]
        $paramValue = $matches[2].Trim()
        $paramValues[$paramID] = $paramValue
    }
}

# Construct the update query for each ParamID with its respective ParamValue
$query = ""
foreach ($paramID in $paramValues.Keys) {
    $paramValue = $paramValues[$paramID]
    $query += "UPDATE Parameter SET ParamValue = '$paramValue' WHERE ParamID = $paramID;" + [System.Environment]::NewLine
}

# SQL Connection string
$connectionString = "Server=$server;Database=$database;User Id=$saUser;Password=$saPassword;"

# Create the SQLConnection object
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString

# Open the SQL connection
$connection.Open()

# Create the SQL command
$command = $connection.CreateCommand()
$command.CommandText = $query

# Execute the SQL query
try {
    $command.ExecuteNonQuery()
    Write-Host "Query executed successfully."
} catch {
    Write-Host "Error executing query: $_"
} finally {
    # Close the SQL connection
    $connection.Close()
}

# End of the script
