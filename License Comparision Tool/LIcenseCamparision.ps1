Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms

# XAML for the clean, toggle-based futuristic dashboard
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="License Verification Dashboard" Height="750" Width="1000" Background="#0B132B" WindowStartupLocation="CenterScreen">
    <Window.Resources>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#1C2541"/>
            <Setter Property="Foreground" Value="#00E5FF"/>
            <Setter Property="BorderBrush" Value="#00E5FF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="FontWeight" Value="Bold"/>
            <Setter Property="FontSize" Value="14"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#00E5FF"/>
                    <Setter Property="Foreground" Value="#0B132B"/>
                </Trigger>
            </Style.Triggers>
        </Style>
        <Style TargetType="TextBox">
            <Setter Property="Background" Value="#050A1F"/>
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="BorderBrush" Value="#5BC0BE"/>
            <Setter Property="FontFamily" Value="Consolas"/>
            <Setter Property="Padding" Value="10"/>
            <Setter Property="AcceptsReturn" Value="True"/>
            <Setter Property="VerticalScrollBarVisibility" Value="Auto"/>
        </Style>
    </Window.Resources>
    
    <Grid Margin="30">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Button Name="btnOld" Grid.Row="0" Content="▼ OLD LICENSE DATA" Height="40" Margin="0,0,0,5"/>
        <TextBox Name="txtOld" Grid.Row="1" Height="150" Visibility="Collapsed" Margin="0,0,0,15" TextWrapping="Wrap" />

        <Button Name="btnNew" Grid.Row="2" Content="▼ NEW LICENSE DATA" Height="40" Margin="0,0,0,5"/>
        <TextBox Name="txtNew" Grid.Row="3" Height="150" Visibility="Collapsed" Margin="0,0,0,20" TextWrapping="Wrap"/>

        <Button Name="btnAnalyse" Grid.Row="4" Content="▶ EXECUTE SMART ANALYSE" Height="50" Background="#00E5FF" Foreground="#0B132B" FontSize="16" Margin="0,0,0,20"/>

        <GroupBox Grid.Row="5" Header="VERIFICATION RESULTS" Foreground="#5BC0BE" FontFamily="Consolas" BorderBrush="#1C2541">
            <RichTextBox Name="rtbResults" Background="#050A1F" BorderThickness="0" Padding="10" IsReadOnly="True" VerticalScrollBarVisibility="Auto">
                <FlowDocument>
                    <Paragraph FontFamily="Consolas" FontSize="14">
                        <Run Foreground="#555555" Text="Awaiting analysis..."/>
                    </Paragraph>
                </FlowDocument>
            </RichTextBox>
        </GroupBox>
    </Grid>
</Window>
"@

$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Map GUI Elements
$btnOld = $Window.FindName("btnOld")
$txtOld = $Window.FindName("txtOld")
$btnNew = $Window.FindName("btnNew")
$txtNew = $Window.FindName("txtNew")
$btnAnalyse = $Window.FindName("btnAnalyse")
$rtbResults = $Window.FindName("rtbResults")

# Toggle Old License TextBox
$btnOld.Add_Click({
    if ($txtOld.Visibility -eq 'Collapsed') {
        $txtOld.Visibility = 'Visible'
        $btnOld.Content = "▲ OLD LICENSE DATA"
    } else {
        $txtOld.Visibility = 'Collapsed'
        $btnOld.Content = "▼ OLD LICENSE DATA"
    }
})

# Toggle New License TextBox
$btnNew.Add_Click({
    if ($txtNew.Visibility -eq 'Collapsed') {
        $txtNew.Visibility = 'Visible'
        $btnNew.Content = "▲ NEW LICENSE DATA"
    } else {
        $txtNew.Visibility = 'Collapsed'
        $btnNew.Content = "▼ NEW LICENSE DATA"
    }
})

# Execute Analysis Logic (Upgraded for Set Matching)
$btnAnalyse.Add_Click({
    # Clear the main screen
    $rtbResults.Document.Blocks.Clear()
    $paragraph = New-Object System.Windows.Documents.Paragraph
    
    # Split text into arrays of lines, ignoring empty whitespace lines at the very end
    $oldText = $txtOld.Text -split "`r`n|`r|`n"
    $newText = $txtNew.Text -split "`r`n|`r|`n"
    
    $maxLines = [math]::Max($oldText.Count, $newText.Count)
    
    for ($i = 0; $i -lt $maxLines; $i++) {
        $lineOld = if ($i -lt $oldText.Count) { $oldText[$i] } else { $null }
        $lineNew = if ($i -lt $newText.Count) { $newText[$i] } else { $null }
        
        $isMatch = $false

        # Smart Check: Look for numbers inside < > brackets on BOTH lines
        if (($lineOld -match "<([\d, ]+)>") -and ($lineNew -match "<([\d, ]+)>")) {
            
            # Extract the raw numbers from between the brackets, clean up spaces, sort them, and put them back together
            $listOld = ($lineOld -replace '.*<|>.*','' -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Sort-Object) -join ','
            $listNew = ($lineNew -replace '.*<|>.*','' -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Sort-Object) -join ','
            
            # Extract the text BEFORE the brackets to ensure the rest of the line matches (e.g., "Package Juris = ")
            $prefixOld = $lineOld -replace "<.*",""
            $prefixNew = $lineNew -replace "<.*",""

            # If both the text before the brackets AND the sorted numbers match, it's a perfect match
            if (($listOld -eq $listNew) -and ($prefixOld -eq $prefixNew)) {
                $isMatch = $true
            }
        } 
        # Standard Check: Exact string match for lines without brackets
        elseif ($lineOld -eq $lineNew) {
            $isMatch = $true
        }

        # --- RENDER RESULTS TO MAIN SCREEN ---
        if ($isMatch) {
            # Render Unchanged (White) - using the original Old Line format
            $run = New-Object System.Windows.Documents.Run("$lineOld`r`n")
            $run.Foreground = "White"
            $paragraph.Inlines.Add($run)
        } else {
            # Render Old/Missing (Red with Strikethrough)
            if ($null -ne $lineOld -and $lineOld.Trim() -ne "") {
                $runOld = New-Object System.Windows.Documents.Run("$lineOld`r`n")
                $runOld.Foreground = "#FF4C4C"
                $runOld.TextDecorations = [System.Windows.TextDecorations]::Strikethrough
                $paragraph.Inlines.Add($runOld)
            }
            # Render New/Added (Neon Blue)
            if ($null -ne $lineNew -and $lineNew.Trim() -ne "") {
                $runNew = New-Object System.Windows.Documents.Run("$lineNew`r`n")
                $runNew.Foreground = "#00E5FF"
                $paragraph.Inlines.Add($runNew)
            }
        }
    }
    
    $rtbResults.Document.Blocks.Add($paragraph)
})

# Show the Dashboard
$Window.ShowDialog() | Out-Null