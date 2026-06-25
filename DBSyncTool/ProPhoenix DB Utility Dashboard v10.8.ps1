#Requires -RunAsAdministrator

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Data

# =========================================
#  ProPhoenix DB Utility Dashboard V10.8
# =========================================

# --- AUTO-ELEVATE TO ADMINISTRATOR ---
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- GLOBAL SETTINGS ---
$Script:SetupPath = "C:\pnxtemp\dbsynctool"
$Script:CurrentDir = if ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { (Get-Location).Path }

$Script:SessionLogDir = Join-Path $Script:SetupPath "SessionLogs"
if (!(Test-Path $Script:SessionLogDir)) { New-Item -ItemType Directory -Force -Path $Script:SessionLogDir | Out-Null }
$Script:SessionLogFile = Join-Path $Script:SessionLogDir "StatusReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

$Script:XmlTarget = Join-Path $Script:SetupPath "PnxAutoNewDBSyn.xml"
$Script:CredFile  = Join-Path $Script:SetupPath "SavedCreds.xml"
$Script:OverrideFile = Join-Path $Script:SetupPath "DBOverrides.xml" # Memory for DB Overrides
$Script:DefaultBackup = "C:\RMS_Master_Backups"
if (!(Test-Path $Script:DefaultBackup)) { New-Item -ItemType Directory -Force -Path $Script:DefaultBackup | Out-Null }
$Script:FailedLogDir = Join-Path $Script:DefaultBackup "Failed_Sync_Logs"
if (!(Test-Path $Script:FailedLogDir)) { New-Item -ItemType Directory -Force -Path $Script:FailedLogDir | Out-Null }

$Script:LogoFile = Join-Path $Script:CurrentDir "logo.png"
if (-not (Test-Path $Script:LogoFile)) { $Script:LogoFile = Join-Path $Script:SetupPath "logo.png" }

$Script:BgImage = Join-Path $Script:CurrentDir "background.png"
if (-not (Test-Path $Script:BgImage)) { $Script:BgImage = Join-Path $Script:CurrentDir "background.jpg" }
if (-not (Test-Path $Script:BgImage)) { $Script:BgImage = Join-Path $Script:SetupPath "background.png" }
if (-not (Test-Path $Script:BgImage)) { $Script:BgImage = Join-Path $Script:SetupPath "background.jpg" }

$Script:TargetParams = @(13, 16, 22, 29, 36, 39, 40, 190, 203, 204, 205, 206, 207, 220, 221, 222, 231, 630, 1914, 2658)
$Script:TargetJobs = @("WDAAppDataExporter", "ReportWriterStaticDataExporter", "CADStaticDataExtractor", "Hot Sheet", "FireLiveDataExporter", "PhoenixBOTQAUploader", "KPICleaner", "FireRMSDataExporter")

if (!(Test-Path $Script:SetupPath)) { New-Item -ItemType Directory -Force -Path $Script:SetupPath | Out-Null }

# Load Override Memory
if (Test-Path $Script:OverrideFile) {
    try { $Script:OverrideMem = Import-Clixml $Script:OverrideFile } catch { $Script:OverrideMem = @{} }
} else {
    $Script:OverrideMem = @{}
}

# ======================================================================
#  WPF XAML DEFINITION (Premium System Fonts & Layout Corrections)
# ======================================================================
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="ProPhoenix DB Dashboard" Height="1000" Width="1400" 
        WindowStartupLocation="CenterScreen" Background="Transparent" WindowStyle="None" AllowsTransparency="True" 
        FontFamily="Segoe UI" TextOptions.TextFormattingMode="Display" TextOptions.TextRenderingMode="ClearType">
    
    <Window.Resources>
        <SolidColorBrush x:Key="BgDark" Color="#121214"/>
        <SolidColorBrush x:Key="BgPanel" Color="#1C1C1F"/>
        <SolidColorBrush x:Key="BgInput" Color="#2A2A2E"/>
        <SolidColorBrush x:Key="TextPrimary" Color="#FFFFFF"/> 
        <SolidColorBrush x:Key="TextMuted" Color="#B0B0B8"/>
        
        <SolidColorBrush x:Key="BtnPrimary" Color="#00629A"/>   
        <SolidColorBrush x:Key="BtnSuccess" Color="#1E7145"/>   
        <SolidColorBrush x:Key="BtnWarning" Color="#B85D19"/>   
        <SolidColorBrush x:Key="BtnDanger" Color="#A4262C"/>    
        <SolidColorBrush x:Key="BtnSecondary" Color="#3E3E42"/> 
        <SolidColorBrush x:Key="BtnPurple" Color="#5C2D91"/>    

        <Storyboard x:Key="OpenDrawer">
            <DoubleAnimation Storyboard.TargetName="SideDrawer" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" To="0" Duration="0:0:0.35">
                <DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseOut"/></DoubleAnimation.EasingFunction>
            </DoubleAnimation>
            <ObjectAnimationUsingKeyFrames Storyboard.TargetName="DrawerOverlay" Storyboard.TargetProperty="Visibility">
                <DiscreteObjectKeyFrame KeyTime="0:0:0" Value="{x:Static Visibility.Visible}"/>
            </ObjectAnimationUsingKeyFrames>
            <DoubleAnimation Storyboard.TargetName="DrawerOverlay" Storyboard.TargetProperty="Opacity" To="0.6" Duration="0:0:0.35"/>
        </Storyboard>
        
        <Storyboard x:Key="CloseDrawer">
            <DoubleAnimation Storyboard.TargetName="SideDrawer" Storyboard.TargetProperty="(UIElement.RenderTransform).(TranslateTransform.X)" To="-420" Duration="0:0:0.3">
                <DoubleAnimation.EasingFunction><CubicEase EasingMode="EaseIn"/></DoubleAnimation.EasingFunction>
            </DoubleAnimation>
            <DoubleAnimation Storyboard.TargetName="DrawerOverlay" Storyboard.TargetProperty="Opacity" To="0" Duration="0:0:0.3"/>
            <ObjectAnimationUsingKeyFrames Storyboard.TargetName="DrawerOverlay" Storyboard.TargetProperty="Visibility">
                <DiscreteObjectKeyFrame KeyTime="0:0:0.3" Value="{x:Static Visibility.Collapsed}"/>
            </ObjectAnimationUsingKeyFrames>
        </Storyboard>

        <Style TargetType="Button" x:Key="ModernBtn">
            <Setter Property="Foreground" Value="#FFFFFF"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="4">
                            <Grid>
                                <ContentPresenter x:Name="content" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                <Path x:Name="spinner" Width="18" Height="18" Visibility="Collapsed" RenderTransformOrigin="0.5,0.5" Data="M9,0 a9,9 0 1,1 -8.99,9" Stroke="White" StrokeThickness="2" StrokeDashArray="14,14">
                                    <Path.RenderTransform><RotateTransform x:Name="SpinnerRotation"/></Path.RenderTransform>
                                    <Path.Triggers>
                                        <EventTrigger RoutedEvent="FrameworkElement.Loaded">
                                            <BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="SpinnerRotation" Storyboard.TargetProperty="Angle" From="0" To="360" Duration="0:0:1" RepeatBehavior="Forever"/></Storyboard></BeginStoryboard>
                                        </EventTrigger>
                                    </Path.Triggers>
                                </Path>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="border" Property="Opacity" Value="0.85"/></Trigger>
                            <Trigger Property="IsPressed" Value="True"><Setter TargetName="border" Property="Opacity" Value="0.6"/></Trigger>
                            <Trigger Property="Tag" Value="Loading">
                                <Setter TargetName="content" Property="Visibility" Value="Collapsed"/>
                                <Setter TargetName="spinner" Property="Visibility" Value="Visible"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="TextBox" x:Key="ModernInput">
            <Setter Property="Background" Value="{StaticResource BgInput}"/>
            <Setter Property="Foreground" Value="{StaticResource TextPrimary}"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="10,0,10,0"/>
            <Setter Property="VerticalContentAlignment" Value="Center"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border Background="{TemplateBinding Background}" CornerRadius="4">
                            <Grid>
                                <TextBlock x:Name="watermark" Text="{TemplateBinding Tag}" Foreground="#777777" VerticalAlignment="Center" Margin="10,0,0,0" Visibility="Hidden" IsHitTestVisible="False"/>
                                <ScrollViewer x:Name="PART_ContentHost" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="Text" Value=""><Setter TargetName="watermark" Property="Visibility" Value="Visible"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="CheckBox" x:Key="ModernCheck">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                            <Border x:Name="box" Width="18" Height="18" Background="{StaticResource BgInput}" BorderBrush="#555" BorderThickness="1" CornerRadius="3" Margin="0,0,10,0">
                                <Path x:Name="check" Data="M3,9 L7,13 L14,4" Stroke="#00FF7F" StrokeThickness="2" Stretch="None" HorizontalAlignment="Center" VerticalAlignment="Center" Visibility="Collapsed"/>
                            </Border>
                            <ContentPresenter VerticalAlignment="Center"/>
                        </StackPanel>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="check" Property="Visibility" Value="Visible"/>
                                <Setter TargetName="box" Property="BorderBrush" Value="#00FF7F"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="box" Property="BorderBrush" Value="#00B4D8"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ToggleButton" x:Key="ModernToggle">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ToggleButton">
                        <Border x:Name="border" Background="{StaticResource BtnSecondary}" CornerRadius="4">
                            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                                <Ellipse x:Name="dot" Width="8" Height="8" Fill="#777777" Margin="0,0,8,0"/>
                                <ContentPresenter/>
                            </StackPanel>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="border" Property="Background" Value="{StaticResource BtnPrimary}"/>
                                <Setter TargetName="dot" Property="Fill" Value="#00FF7F"/>
                                <Setter TargetName="dot" Property="Effect"><Setter.Value><DropShadowEffect Color="#00FF7F" BlurRadius="8" ShadowDepth="0"/></Setter.Value></Setter>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <ControlTemplate x:Key="SolidComboToggle" TargetType="ToggleButton">
            <Border Background="{StaticResource BgInput}" CornerRadius="4">
                <TextBlock Text="▼" Foreground="{StaticResource TextMuted}" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,10,0" FontSize="10"/>
            </Border>
        </ControlTemplate>
        
        <Style TargetType="ComboBox" x:Key="SolidCombo">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBox">
                        <Grid>
                            <ToggleButton Template="{StaticResource SolidComboToggle}" IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"/>
                            <TextBlock x:Name="watermark" Text="{TemplateBinding Tag}" Foreground="#777777" Margin="10,0,25,0" VerticalAlignment="Center" IsHitTestVisible="False" Visibility="Collapsed"/>
                            <ContentPresenter Margin="10,0,25,0" VerticalAlignment="Center" IsHitTestVisible="False" Content="{TemplateBinding SelectionBoxItem}" ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"/>
                            <Popup IsOpen="{TemplateBinding IsDropDownOpen}" Placement="Bottom" AllowsTransparency="True">
                                <Border Background="{StaticResource BgPanel}" BorderThickness="1" BorderBrush="#333" CornerRadius="4" MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}">
                                    <ScrollViewer Margin="0,5"><ItemsPresenter/></ScrollViewer>
                                </Border>
                            </Popup>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="SelectedIndex" Value="-1"><Setter TargetName="watermark" Property="Visibility" Value="Visible"/></Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="ComboBoxItem">
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="ComboBoxItem">
                        <Border x:Name="Bd" Background="Transparent" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border>
                        <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Background" Value="{StaticResource BtnPrimary}"/></Trigger></ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid ClipToBounds="True">
        <Border Background="{StaticResource BgDark}" CornerRadius="8" BorderBrush="#333" BorderThickness="1" Margin="25">
            <Border.Effect><DropShadowEffect Color="Black" BlurRadius="25" Opacity="0.5" Direction="270" ShadowDepth="5"/></Border.Effect>
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="40"/>
                    <RowDefinition Height="90"/>
                    <RowDefinition Height="70"/>
                    <RowDefinition Height="130"/>
                    <RowDefinition Height="*"/> 
                    <RowDefinition Height="30"/>
                </Grid.RowDefinitions>

                <Image x:Name="imgBgLogo" Opacity="0.085" Stretch="Uniform" HorizontalAlignment="Center" VerticalAlignment="Center" Grid.RowSpan="6" IsHitTestVisible="False" Margin="60"/>

                <Grid x:Name="TitleBar" Grid.Row="0" Background="Transparent">
                    <TextBlock Text="Phoenix DB Sync Dashboard" Foreground="{StaticResource TextMuted}" VerticalAlignment="Center" Margin="20,0,0,0" FontSize="13"/>
                    <Button x:Name="btnClose" Content="✕" Width="40" Background="Transparent" Foreground="{StaticResource TextMuted}" HorizontalAlignment="Right" BorderThickness="0" FontSize="16" Cursor="Hand">
                        <Button.Style><Style TargetType="Button"><Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="White"/><Setter Property="Background" Value="#C42B1C"/></Trigger></Style.Triggers></Style></Button.Style>
                    </Button>
                </Grid>

                <Grid Grid.Row="1" Margin="20,0,20,0">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Image x:Name="imgSmallLogo" Width="48" Height="48" Margin="0,0,15,0" VerticalAlignment="Center" Stretch="Uniform"/>
                        <TextBlock Text="Phoenix DB Sync Dashboard" FontSize="30" Foreground="{StaticResource TextPrimary}" FontWeight="Bold" VerticalAlignment="Center"/>
                    </StackPanel>
                    
                    <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                        <TextBlock Text="Utility Path:" Foreground="{StaticResource TextMuted}" VerticalAlignment="Center" Margin="0,0,10,0"/>
                        <TextBox x:Name="txtPath" Width="300" Style="{StaticResource ModernInput}" Height="34" Margin="0,0,10,0" Tag="Path to DB Sync Folder..."/>
                        <Button x:Name="btnBrowse" Content="Browse" Width="80" Height="34" Background="{StaticResource BtnPrimary}" Style="{StaticResource ModernBtn}"/>
                        <StackPanel Margin="20,0,0,0" VerticalAlignment="Center">
                            <TextBlock x:Name="lblVer" Text="DB Ver: --" Foreground="{StaticResource TextMuted}" TextAlignment="Right"/>
                            <TextBlock x:Name="lblCBVer" Text="CB Ver: --" Foreground="{StaticResource TextMuted}" TextAlignment="Right" Margin="0,5,0,0"/>
                        </StackPanel>
                    </StackPanel>
                </Grid>

                <Grid Grid.Row="2" Margin="20,10,20,0">
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Button x:Name="btnOtherActivities" Content="Other Activities ≡" Width="160" Height="40" Background="{StaticResource BtnSecondary}" Style="{StaticResource ModernBtn}" Margin="0,0,12,0"/>
                        <Button x:Name="btnInstall" Content="Install Utility" Width="150" Height="40" Background="{StaticResource BtnSuccess}" Style="{StaticResource ModernBtn}" Margin="0,0,10,0"/>
                        <Button x:Name="btnUninstall" Content="Uninstall Utility" Width="150" Height="40" Background="{StaticResource BtnDanger}" Style="{StaticResource ModernBtn}" Margin="0,0,10,0"/>
                        <Button x:Name="btnSqlMem" Content="SQL Memory Mgmt" Width="160" Height="40" Background="{StaticResource BtnPurple}" Style="{StaticResource ModernBtn}"/>
                    </StackPanel>
                </Grid>

                <Border Grid.Row="3" Background="{StaticResource BgPanel}" CornerRadius="6" Margin="20,10,20,10" Padding="15">
    <StackPanel>
        <TextBlock Text="SQL CONNECTION CONFIGURATION" Foreground="#00B4D8" FontSize="12" FontWeight="Bold" Margin="0,0,0,10"/>
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <TextBox x:Name="txtS" Width="180" Height="34" Style="{StaticResource ModernInput}" Margin="0,0,10,0" Tag="Server IP / Hostname"/>
            <TextBox x:Name="txtU" Width="100" Height="34" Style="{StaticResource ModernInput}" Text="sa" Margin="0,0,10,0" Tag="Username"/>
            
            <Grid Width="170" Height="34" Margin="0,0,10,0">
                <PasswordBox x:Name="txtP" Background="{StaticResource BgInput}" Foreground="{StaticResource TextPrimary}" FontSize="14" BorderThickness="0" Padding="10,0,10,0" VerticalContentAlignment="Center"/>
                <TextBlock x:Name="lblPwdPlaceholder" Text="Password" Foreground="#777777" VerticalAlignment="Center" Margin="10,0,0,0" IsHitTestVisible="False"/>
            </Grid>

            <ComboBox x:Name="cmbEnv" Width="115" Height="34" Margin="0,0,10,0" SelectedIndex="-1" Style="{StaticResource SolidCombo}">
                <ComboBoxItem Content="LIVE"/>
                <ComboBoxItem Content="TEST"/>
                <ComboBoxItem Content="TEST WSQL"/>
                <ComboBoxItem Content="ALL"/>
                <ComboBoxItem Content="Manual Sync"/>
            </ComboBox>

            <ComboBox x:Name="cmbSyncType" Width="190" Height="34" Margin="0,0,15,0" SelectedIndex="-1" Style="{StaticResource SolidCombo}" Tag="Sync Mode...">
                <ComboBoxItem Content="1 - Make a database"/><ComboBoxItem Content="2 - Update/Upgrade"/><ComboBoxItem Content="3 - Batch Update"/>
            </ComboBox>

            <Rectangle Width="0" Fill="#444444" Margin="0,6,15,6" RadiusX="1" RadiusY="1"/>
            <ToggleButton x:Name="chkSave" Content="Save" Width="70" Height="34" Style="{StaticResource ModernToggle}" Margin="0,0,15,0" IsChecked="False"/>
            
            <Rectangle Width="0" Fill="#444444" Margin="0,6,15,6" RadiusX="1" RadiusY="1"/>
            <ToggleButton x:Name="chkAutoSync" Content="AutoSync " Width="100" Height="34" Style="{StaticResource ModernToggle}" Margin="0,0,15,0" IsChecked="False"/>
            
            <Button x:Name="btnSync" Content="START DB SYNC" Width="130" Height="34" Background="{StaticResource BtnPrimary}" Style="{StaticResource ModernBtn}" Margin="0,0,15,0"/>
            
            <Button x:Name="btnCon" Width="80" Height="34" Background="{StaticResource BtnDanger}" Style="{StaticResource ModernBtn}">
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                    <Path x:Name="SpinnerIcon" Width="16" Height="16" Margin="0,0,8,0" Visibility="Collapsed" RenderTransformOrigin="0.5,0.5" Data="M8,0 a8,8 0 1,1 -7.99,8" Stroke="White" StrokeThickness="2" StrokeDashArray="12,12">
                        <Path.RenderTransform><RotateTransform x:Name="SpinnerRotation"/></Path.RenderTransform>
                        <Path.Triggers>
                            <EventTrigger RoutedEvent="FrameworkElement.Loaded">
                                <BeginStoryboard><Storyboard><DoubleAnimation Storyboard.TargetName="SpinnerRotation" Storyboard.TargetProperty="Angle" From="0" To="360" Duration="0:0:1" RepeatBehavior="Forever"/></Storyboard></BeginStoryboard>
                            </EventTrigger>
                        </Path.Triggers>
                    </Path>
                    <TextBlock x:Name="btnConText" Text="CONNECT" VerticalAlignment="Center"/>
                </StackPanel>
            </Button>
        </StackPanel>
    </StackPanel>
</Border>

                <Grid Grid.Row="4" Margin="20,0,20,20">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="5.5*"/>
                        <ColumnDefinition Width="3.5*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0" Background="{StaticResource BgPanel}" CornerRadius="6" Margin="0,0,10,0" Padding="15">
                        <Grid>
                            <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                            <Grid Grid.Row="0" Margin="0,0,0,10">
                                <TextBlock Text="ACTIVITY LOG" Foreground="#00FF7F" FontSize="12" FontWeight="Bold" VerticalAlignment="Center"/>
                                <Button x:Name="btnClear" Content="Clear Log" HorizontalAlignment="Right" Width="90" Height="28" Background="{StaticResource BtnSecondary}" Style="{StaticResource ModernBtn}"/>
                            </Grid>
                            <RichTextBox x:Name="txtLog" Grid.Row="1" Background="#0C0C0E" Foreground="#E0E0E0" FontFamily="Consolas" FontSize="14" BorderThickness="0" IsReadOnly="True" VerticalScrollBarVisibility="Auto">
                                <FlowDocument x:Name="logDoc" PagePadding="10"/>
                            </RichTextBox>
                        </Grid>
                    </Border>

                    <Border Grid.Column="1" Background="{StaticResource BgPanel}" CornerRadius="6" Margin="10,0,0,0" Padding="15">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>
        
        <Grid Grid.Row="0" Margin="0,0,0,10">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
                <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="0" Text="DB List" Foreground="#00B4D8" FontSize="12" FontWeight="Bold" VerticalAlignment="Center"/>
            <Button x:Name="btnVer" Grid.Column="1" Content="DB Version" Width="80" Height="28" Background="{StaticResource BtnSecondary}" Style="{StaticResource ModernBtn}" Margin="0,0,8,0"/>
            <Button x:Name="btnRefresh" Grid.Column="2" Content="↻ Refresh" Width="80" Height="28" Background="{StaticResource BtnSecondary}" Style="{StaticResource ModernBtn}" Margin="0,0,8,0"/>
            <CheckBox x:Name="chkAll" Grid.Column="3" Content="Select All" Width="90" Height="28" Style="{StaticResource ModernToggle}"/>
        </Grid>

        <Grid Grid.Row="1" Margin="0,5,0,10" Background="#2A2A2E">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="45"/>
                <ColumnDefinition Width="130"/>
                <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <TextBlock Grid.Column="1" Text="TYPE" Foreground="#D0D0D0" FontWeight="Bold" FontSize="12" VerticalAlignment="Center" Margin="0,4"/>
            <TextBlock Grid.Column="2" Text="DATABASE NAME" Foreground="#D0D0D0" FontWeight="Bold" FontSize="12" VerticalAlignment="Center" Margin="0,4"/>
        </Grid>

        <ListBox x:Name="listDBs" Grid.Row="2" Background="{StaticResource BgInput}" Foreground="{StaticResource TextPrimary}" BorderThickness="0" ScrollViewer.HorizontalScrollBarVisibility="Disabled">
            <ListBox.ItemTemplate>
                <DataTemplate>
                    <Grid Height="28" Margin="0,2">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="45"/>
                            <ColumnDefinition Width="130"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <CheckBox Grid.Column="0" IsChecked="{Binding IsChecked, Mode=TwoWay}" VerticalAlignment="Center" HorizontalAlignment="Center" Style="{StaticResource ModernCheck}"/>
                        <TextBlock Grid.Column="1" Text="{Binding Type}" VerticalAlignment="Center" Foreground="{Binding Color}" FontSize="13"/>
                        <TextBlock Grid.Column="2" Text="{Binding DBName}" VerticalAlignment="Center" Foreground="White" FontSize="13"/>
                    </Grid>
                </DataTemplate>
            </ListBox.ItemTemplate>
        </ListBox>
    </Grid>
</Border>
                </Grid>

                <Border Grid.Row="5" Background="{StaticResource BgPanel}" CornerRadius="0,0,8,8">
                    <TextBlock x:Name="lblStat" Text="Ready." Foreground="{StaticResource TextMuted}" VerticalAlignment="Center" Margin="20,0,0,0" FontSize="12"/>
                </Border>
            </Grid>
        </Border>

        <Border x:Name="DrawerOverlay" Background="Black" Opacity="0" Visibility="Collapsed" Panel.ZIndex="10"/>

        <Border x:Name="SideDrawer" Width="350" HorizontalAlignment="Left" Background="{StaticResource BgPanel}" BorderThickness="0,0,1,0" Panel.ZIndex="20" Margin="25" CornerRadius="8,0,0,8">
            <Border.Effect><DropShadowEffect Color="Black" BlurRadius="25" Opacity="0.8" Direction="0" ShadowDepth="10"/></Border.Effect>
            <Border.RenderTransform><TranslateTransform X="-420"/></Border.RenderTransform>
            <Grid>
                <Grid.RowDefinitions><RowDefinition Height="60"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                <TextBlock Text="OTHER ACTIVITIES" Foreground="#00B4D8" FontSize="16" FontWeight="Bold" VerticalAlignment="Center" Margin="25,0,0,0"/>
                <Button x:Name="btnCloseDrawer" Content="✕" Width="40" Height="40" Background="Transparent" Foreground="{StaticResource TextMuted}" HorizontalAlignment="Right" BorderThickness="0" FontSize="18" Cursor="Hand" Margin="0,0,10,0">
                    <Button.Style><Style TargetType="Button"><Style.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter Property="Foreground" Value="White"/><Setter Property="Background" Value="#C42B1C"/></Trigger></Style.Triggers></Style></Button.Style>
                </Button>
                
                <ScrollViewer Grid.Row="1" Margin="20,10,20,20" VerticalScrollBarVisibility="Auto">
                    <StackPanel>
                        <Button x:Name="btnCopyDB" Content="LIVE TO TRAIN/TEST" Height="45" Background="{StaticResource BtnPrimary}" Style="{StaticResource ModernBtn}" Margin="0,0,0,12"/>
                        <Button x:Name="btnOverrideCat" Content="OVERRIDE DB CATEGORY" Height="45" Background="{StaticResource BtnPrimary}" Style="{StaticResource ModernBtn}" Margin="0,0,0,12"/>
                        <Button x:Name="btnBackup" Content="BACKUP JOBS &amp; PARAMS" Height="45" Background="{StaticResource BtnPrimary}" Style="{StaticResource ModernBtn}" Margin="0,0,0,12"/>
                        <Button x:Name="btnRestore" Content="RESTORE JOBS &amp; PARAMS" Height="45" Background="{StaticResource BtnPrimary}" Style="{StaticResource ModernBtn}" Margin="0,0,0,12"/>
                        <Button x:Name="btnCreateDB" Content="CREATE NEW DB" Height="45" Background="{StaticResource BtnPrimary}" Style="{StaticResource ModernBtn}" Margin="0,0,0,12"/>
                        <Button x:Name="btnDeleteDB" Content="DELETE DATABASE" Height="45" Background="{StaticResource BtnPrimary}" Style="{StaticResource ModernBtn}" Margin="0,0,0,12"/>
                        <Button x:Name="btnCodebook" Content="SYNC CODEBOOK (FIRE)" Height="45" Background="{StaticResource BtnPrimary}" Style="{StaticResource ModernBtn}" Margin="0,0,0,12"/>
                        <Button x:Name="btnBackupDB" Content="BACKUP DB (SQL)" Height="45" Background="{StaticResource BtnPrimary}" Style="{StaticResource ModernBtn}" Margin="0,0,0,12"/>
                        <Button x:Name="btnRestoreDB" Content="RESTORE DB (SQL)" Height="45" Background="{StaticResource BtnPrimary}" Style="{StaticResource ModernBtn}" Margin="0,0,0,12"/>
                    </StackPanel>
                </ScrollViewer>
            </Grid>
        </Border>
    </Grid>
</Window>
"@

# Instantiate & Parse Document Model
$reader = (New-Object System.Xml.XmlNodeReader ([xml]$xaml))
$Script:form = [Windows.Markup.XamlReader]::Load($reader)

# Map Elements to Automation Global Context Variables
$Script:txtPath = $Script:form.FindName("txtPath")
$Script:btnBrowse = $Script:form.FindName("btnBrowse")
$Script:lblVer = $Script:form.FindName("lblVer")
$Script:lblCBVer = $Script:form.FindName("lblCBVer")
$Script:btnCreateDB = $Script:form.FindName("btnCreateDB")
$Script:btnInstall = $Script:form.FindName("btnInstall")
$Script:btnUninstall = $Script:form.FindName("btnUninstall")
$Script:btnSqlMem = $Script:form.FindName("btnSqlMem")
$Script:txtS = $Script:form.FindName("txtS")
$Script:txtU = $Script:form.FindName("txtU")
$Script:txtP = $Script:form.FindName("txtP")
$Script:cmbEnv = $Script:form.FindName("cmbEnv")
$Script:cmbSyncType = $Script:form.FindName("cmbSyncType")
$Script:chkAutoSync = $Script:form.FindName("chkAutoSync")
$Script:chkSave = $Script:form.FindName("chkSave")
$Script:btnCon = $Script:form.FindName("btnCon")
$Script:SpinnerIcon = $Script:form.FindName("SpinnerIcon")
$Script:btnConText = $Script:form.FindName("btnConText")
$Script:lblPwdPlaceholder = $Script:form.FindName("lblPwdPlaceholder")
$Script:listDBs = $Script:form.FindName("listDBs")
$Script:chkAll = $Script:form.FindName("chkAll")
$Script:btnRefresh = $Script:form.FindName("btnRefresh")
$Script:txtLog = $Script:form.FindName("txtLog")
$Script:logDoc = $Script:form.FindName("logDoc")
$Script:btnClear = $Script:form.FindName("btnClear")
$Script:btnOtherActivities = $Script:form.FindName("btnOtherActivities")
$Script:btnCloseDrawer = $Script:form.FindName("btnCloseDrawer")
$Script:DrawerOverlay = $Script:form.FindName("DrawerOverlay")
$Script:SideDrawer = $Script:form.FindName("SideDrawer")
$Script:btnSync = $Script:form.FindName("btnSync")
$Script:btnCopyDB = $Script:form.FindName("btnCopyDB")
$Script:btnBackup = $Script:form.FindName("btnBackup")
$Script:btnRestore = $Script:form.FindName("btnRestore")
$Script:btnCodebook = $Script:form.FindName("btnCodebook")
$Script:btnBackupDB = $Script:form.FindName("btnBackupDB")
$Script:btnDeleteDB = $Script:form.FindName("btnDeleteDB")
$Script:btnVer = $Script:form.FindName("btnVer")
$Script:btnOverrideCat = $Script:form.FindName("btnOverrideCat")
$Script:btnRestoreDB = $Script:form.FindName("btnRestoreDB")
$Script:lblStat = $Script:form.FindName("lblStat")
$TitleBar = $Script:form.FindName("TitleBar")
$btnClose = $Script:form.FindName("btnClose")
$Script:imgSmallLogo = $Script:form.FindName("imgSmallLogo")
$Script:imgBgLogo = $Script:form.FindName("imgBgLogo")

$Script:btnRefresh.Add_Click({
    $Script:btnRefresh.Tag = "Loading"
    $Script:btnRefresh.IsEnabled = $false
    [System.Windows.Forms.Application]::DoEvents() # Force UI update

    try {
        $Script:listDBs.Items.Clear()

        $server = $Script:txtS.Text
        $user = $Script:txtU.Text
        $pass = $Script:txtP.Password

        if ([string]::IsNullOrWhiteSpace($server)) {
            throw "Please enter a Server IP or Hostname."
        }

        # Setup ultra-fast ADO.NET Connection String
        $connString = "Server=$server;Database=master;User Id=$user;Password=$pass;Connect Timeout=5;TrustServerCertificate=True;"
        
        # Fallback to Windows Authentication if password field is empty
        if ([string]::IsNullOrWhiteSpace($pass)) {
            $connString = "Server=$server;Database=master;Integrated Security=True;Connect Timeout=5;TrustServerCertificate=True;"
        }

        $conn = New-Object System.Data.SqlClient.SqlConnection($connString)
        $conn.Open()

        # Query only non-system databases from sys.databases
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT name FROM sys.databases WHERE database_id > 4 ORDER BY name"
        $reader = $cmd.ExecuteReader()

        # Read and populate the UI list
        while ($reader.Read()) {
            $dbName = $reader["name"].ToString()
            
            # Determine DB Type and Color
            $type = "OTHER"
            $color = "#B0B0B8" # Default Muted Gray

            if ($dbName -match "PhoenixMaster\d*") { 
                $type = "PHOENIXMASTER"
                $color = "#00B4D8" # Blue
            }

            elseif ($dbName -match "Police\d*") { 
                $type = "POLICE"
                $color = "#00B4D8" # Blue
            }
            elseif ($dbName -match "Fire\d*") { 
                $type = "FIRE"
                $color = "#00B4D8" # Blue
            }
            elseif ($dbName -match "IA\d*") { 
                $type = "IA"
                $color = "#00B4D8" # Blue
            }
            elseif ($dbName -match "Demo") { 
                $type = "DEMO"
                $color = "#00B4D8" # Blue
            }

            # Create the object matching your XAML binding
            $dbObj = [PSCustomObject]@{
                IsChecked = $false
                Type      = $type
                Color     = $color
                DBName    = $dbName
            }
            
            $Script:listDBs.Items.Add($dbObj) | Out-Null
        }

        $reader.Close()
        $conn.Close()
        
        $Script:lblStat.Text = "Successfully retrieved databases."
    }
    catch {
        $Script:lblStat.Text = "Connection Error. Check credentials and server IP."
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "SQL Connection Error", 0, 16)
    }
    finally {
        $Script:btnRefresh.Tag = $null
        $Script:btnRefresh.IsEnabled = $true
    }
})

$Script:txtS.Text = $env:COMPUTERNAME

# ======================================================================
#  WPF CORE INTERFACE EVENT BINDINGS
# ======================================================================
$TitleBar.Add_MouseLeftButtonDown({ $Script:form.DragMove() })
$btnClose.Add_Click({ $Script:form.Close() })
$Script:form.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Enter') { $Script:form.Close() } })

$Script:txtP.Add_PasswordChanged({
    if ($Script:txtP.Password.Length -gt 0) { $Script:lblPwdPlaceholder.Visibility = "Hidden" } 
    else { $Script:lblPwdPlaceholder.Visibility = "Visible" }
})

$Script:btnOtherActivities.Add_Click({ $Script:form.FindResource("OpenDrawer").Begin() })
$Script:btnCloseDrawer.Add_Click({ $Script:form.FindResource("CloseDrawer").Begin() })
$Script:DrawerOverlay.Add_MouseLeftButtonDown({ $Script:form.FindResource("CloseDrawer").Begin() })

$Script:chkAll.Add_Click({
    $state = $Script:chkAll.IsChecked
    foreach ($item in $Script:listDBs.Items) { $item.IsChecked = $state }
    $Script:listDBs.Items.Refresh()
})

$Script:btnClear.Add_Click({ $Script:logDoc.Blocks.Clear() })

# --- TASK LOCKING MECHANISM ---
$Script:IsTaskRunning = $false
$Script:CurrentTaskName = ""

function Check-TaskLock($TaskName) {
    if ($Script:IsTaskRunning) {
        [System.Windows.Forms.MessageBox]::Show("Already ($Script:CurrentTaskName) in progress so keeps wait until it completes.", "Task in Progress", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        return $false
    }
    $Script:IsTaskRunning = $true
    $Script:CurrentTaskName = $TaskName
    return $true
}

function Release-TaskLock {
    $Script:IsTaskRunning = $false
    $Script:CurrentTaskName = ""
}

$Script:btnBrowse.Add_Click({
    if (-not (Check-TaskLock "Browse Directory")) { return }
    try {
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
        $fbd.Description = "Select the ProPhoenix DB Sync Utility Installation Folder"
        if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $Script:txtPath.Text = $fbd.SelectedPath
            $Script:DBSyncRoot = $fbd.SelectedPath
            Log "  ✔ Utility Path manually assigned to: $($fbd.SelectedPath)" "Lime"
        }
    } finally { Release-TaskLock }
})

# ------------------------------------------------------------
# CORE WPF HELPERS & BACKEND LOGIC
# ------------------------------------------------------------
function Show-LoginScreen {
    $global:LoginResult = $false
    $loginXaml = @"
    <Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
            xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
            Title="Connect" Height="680" Width="420" WindowStartupLocation="CenterScreen"
            WindowStyle="None" Background="Transparent" FontFamily="Segoe UI" AllowsTransparency="True">
        <Window.Resources>
            <ControlTemplate x:Key="DarkComboToggle" TargetType="ToggleButton">
                <Border Background="#0A2A4A" BorderBrush="#004A70" BorderThickness="1">
                    <TextBlock Text="▼" Foreground="#A0C0D0" HorizontalAlignment="Right" VerticalAlignment="Center" Margin="0,0,10,0" FontSize="10"/>
                </Border>
            </ControlTemplate>
            <Style TargetType="ComboBox" x:Key="DarkCombo">
                <Setter Property="Foreground" Value="White"/>
                <Setter Property="FontSize" Value="14"/>
                <Setter Property="Height" Value="38"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="ComboBox">
                            <Grid>
                                <ToggleButton Template="{StaticResource DarkComboToggle}" IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}"/>
                                <ContentPresenter Margin="10,0,25,0" VerticalAlignment="Center" IsHitTestVisible="False" Content="{TemplateBinding SelectionBoxItem}"/>
                                <Popup IsOpen="{TemplateBinding IsDropDownOpen}" Placement="Bottom" AllowsTransparency="True" PopupAnimation="None">
                                    <Border Background="#001829" BorderThickness="1" BorderBrush="#004A70" MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}">
                                        <ScrollViewer MaxHeight="200"><ItemsPresenter/></ScrollViewer>
                                    </Border>
                                </Popup>
                            </Grid>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style TargetType="ComboBoxItem">
                <Setter Property="Foreground" Value="White"/>
                <Setter Property="Padding" Value="10,8"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="ComboBoxItem">
                            <Border x:Name="Bd" Background="Transparent" Padding="{TemplateBinding Padding}"><ContentPresenter/></Border>
                            <ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="Bd" Property="Background" Value="#00629A"/></Trigger></ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
            <Style TargetType="Button" x:Key="WinBtn">
                <Setter Property="Background" Value="Transparent"/>
                <Setter Property="Foreground" Value="#A0C0D0"/>
                <Setter Property="Template">
                    <Setter.Value>
                        <ControlTemplate TargetType="Button">
                            <Border Background="{TemplateBinding Background}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                            <ControlTemplate.Triggers>
                                <Trigger Property="IsMouseOver" Value="True"><Setter Property="Background" Value="#1A3A5A"/><Setter Property="Foreground" Value="White"/></Trigger>
                            </ControlTemplate.Triggers>
                        </ControlTemplate>
                    </Setter.Value>
                </Setter>
            </Style>
        </Window.Resources>
        
        <Border Background="#001829" CornerRadius="10" Margin="15">
            <Border.Effect>
                <DropShadowEffect Color="#00B4D8" BlurRadius="20" ShadowDepth="0" Opacity="0.4"/>
            </Border.Effect>
            <Grid>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,5,10,0" Panel.ZIndex="10">
                    <Button x:Name="btnMin_log" Content="—" Width="35" Height="25" FontSize="14" Cursor="Hand" Style="{StaticResource WinBtn}"/>
                    <Button x:Name="btnClose_log" Content="✕" Width="35" Height="25" FontSize="14" Cursor="Hand">
                        <Button.Style>
                            <Style TargetType="Button" BasedOn="{StaticResource WinBtn}">
                                <Style.Triggers>
                                    <Trigger Property="IsMouseOver" Value="True">
                                        <Setter Property="Background" Value="#E81123"/>
                                        <Setter Property="Foreground" Value="White"/>
                                    </Trigger>
                                </Style.Triggers>
                            </Style>
                        </Button.Style>
                    </Button>
                </StackPanel>

                <Grid Margin="30,20,30,20">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="Auto"/> <RowDefinition Height="*"/>    <RowDefinition Height="Auto"/> </Grid.RowDefinitions>
                    
                    <Image x:Name="imgLogo" Grid.Row="0" Height="65" Stretch="Uniform" Margin="0,10,0,15"/>
                    <TextBlock Grid.Row="1" Text="Phoenix DB Sync Dashboard" Foreground="#E0E0E0" FontSize="22" FontWeight="Bold" HorizontalAlignment="Center" Margin="0,0,0,25"/>

                    <TextBlock Grid.Row="2" Text="Instance / Server Name" Foreground="#A0C0D0" FontSize="13" Margin="0,0,0,5"/>
                    <TextBox x:Name="txtS_log" Grid.Row="3" Height="38" Background="#0A2A4A" Foreground="White" BorderBrush="#004A70" BorderThickness="1" Margin="0,0,0,15" Padding="8,0" VerticalContentAlignment="Center" FontSize="14"/>

                    <TextBlock Grid.Row="4" Text="User Name" Foreground="#A0C0D0" FontSize="13" Margin="0,0,0,5"/>
                    <TextBox x:Name="txtU_log" Grid.Row="5" Height="38" Background="#0A2A4A" Foreground="White" BorderBrush="#004A70" BorderThickness="1" Margin="0,0,0,15" Padding="8,0" VerticalContentAlignment="Center" FontSize="14" Text="sa"/>

                    <TextBlock Grid.Row="6" Text="Password" Foreground="#A0C0D0" FontSize="13" Margin="0,0,0,5"/>
                    <PasswordBox x:Name="txtP_log" Grid.Row="7" Height="38" Background="#0A2A4A" Foreground="White" BorderBrush="#004A70" BorderThickness="1" Margin="0,0,0,15" Padding="8,0" VerticalContentAlignment="Center" FontSize="14"/>

                    <TextBlock Grid.Row="8" Text="Select Environment" Foreground="#A0C0D0" FontSize="13" Margin="0,0,0,5"/>
                    <ComboBox x:Name="cmbE_log" Grid.Row="9" Margin="0,0,0,15" Style="{StaticResource DarkCombo}" SelectedIndex="0">
                        <ComboBoxItem Content="LIVE"/>
                        <ComboBoxItem Content="TEST"/>
                        <ComboBoxItem Content="TEST WPNX"/>
                        <ComboBoxItem Content="ALL"/>
                        <ComboBoxItem Content="Manual Sync"/>
                    </ComboBox>

                    <CheckBox x:Name="chkSave_log" Grid.Row="10" Content="Save Credentials" Foreground="#A0C0D0" FontSize="13" Margin="0,0,0,25" IsChecked="True"/>

                    <Grid Grid.Row="11" VerticalAlignment="Top">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="10"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        
                        <Button x:Name="btnLog" Grid.Column="0" Content="Connect" Height="42" FontWeight="Bold" FontSize="15" Cursor="Hand">
                            <Button.Style>
                                <Style TargetType="Button">
                                    <Setter Property="Background" Value="#00B4D8"/>
                                    <Setter Property="Foreground" Value="#001829"/>
                                    <Setter Property="Template">
                                        <Setter.Value>
                                            <ControlTemplate TargetType="Button">
                                                <Border Background="{TemplateBinding Background}" CornerRadius="21">
                                                    <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                                                </Border>
                                                <ControlTemplate.Triggers>
                                                    <Trigger Property="IsMouseOver" Value="True">
                                                        <Setter Property="Background" Value="#5CE1E6"/>
                                                    </Trigger>
                                                    <Trigger Property="IsPressed" Value="True">
                                                        <Setter Property="Background" Value="#007799"/>
                                                        <Setter Property="Foreground" Value="#FFFFFF"/>
                                                    </Trigger>
                                                </ControlTemplate.Triggers>
                                            </ControlTemplate>
                                        </Setter.Value>
                                    </Setter>
                                </Style>
                            </Button.Style>
                        </Button>
                        
                        <Button x:Name="btnExit" Grid.Column="2" Content="Reset" Height="42" Background="#081015" Foreground="White" FontWeight="Bold" FontSize="15" BorderThickness="0" Cursor="Hand">
                            <Button.Resources><Style TargetType="Border"><Setter Property="CornerRadius" Value="21"/></Style></Button.Resources>
                        </Button>
                    </Grid>
                    
                    <TextBlock Grid.Row="13" Foreground="#406080" FontSize="11" TextAlignment="Center" Margin="0,20,0,0">
                        <Run Text="© 2026 ProPhoenix Corporation, All Rights Reserved"/>
                        <LineBreak/>
                        <Run Text="Phoenix DB Sync Dashboard [ V10.8 ]"/>
                    </TextBlock>
                </Grid>
            </Grid>
        </Border>
    </Window>
"@
    $reader = (New-Object System.Xml.XmlNodeReader ([xml]$loginXaml))
    $logForm = [Windows.Markup.XamlReader]::Load($reader)

    $btnLog = $logForm.FindName("btnLog")
    $btnExit = $logForm.FindName("btnExit")
    $btnMin_log = $logForm.FindName("btnMin_log")
    $btnClose_log = $logForm.FindName("btnClose_log")
    $txtS_log = $logForm.FindName("txtS_log")
    $txtU_log = $logForm.FindName("txtU_log")
    $txtP_log = $logForm.FindName("txtP_log")
    $cmbE_log = $logForm.FindName("cmbE_log")
    $chkSave_log = $logForm.FindName("chkSave_log")
    $imgLogo = $logForm.FindName("imgLogo")

    Load-Image -Element $imgLogo -Path $Script:LogoFile

    # Window Controls functionality
    $btnMin_log.Add_Click({ $logForm.WindowState = [System.Windows.WindowState]::Minimized })
    $btnClose_log.Add_Click({ $logForm.Close() })
    
    # Allow moving the window by dragging the background
    $logForm.Add_MouseLeftButtonDown({
        param($sender, $e)
        if ($e.ButtonState -eq [System.Windows.Input.MouseButtonState]::Pressed) {
            try { $logForm.DragMove() } catch {}
        }
    })

    # Pre-populate login fields from saved configuration
    Load-Creds | Out-Null
    if (-not [string]::IsNullOrWhiteSpace($global:LoadedServer)) { $txtS_log.Text = $global:LoadedServer } else { $txtS_log.Text = $env:COMPUTERNAME }
    if (-not [string]::IsNullOrWhiteSpace($global:LoadedUser)) { $txtU_log.Text = $global:LoadedUser } else { $txtU_log.Text = "sa" }
    if (-not [string]::IsNullOrWhiteSpace($global:LoadedPass)) { $txtP_log.Password = $global:LoadedPass }
    if (-not [string]::IsNullOrWhiteSpace($global:LoadedEnv)) { $cmbE_log.Text = $global:LoadedEnv }
    if ($global:LoadedSave) { $chkSave_log.IsChecked = $true } else { $chkSave_log.IsChecked = $false }

    $btnLog.Add_Click({
        $Script:txtS.Text = $txtS_log.Text
        $Script:txtU.Text = $txtU_log.Text
        
        try { $Script:txtP.Password = $txtP_log.Password } catch { $Script:txtP.Text = $txtP_log.Password }
        try { $Script:cmbEnv.Text = $cmbE_log.Text } catch { $Script:cmbEnv.SelectedItem = $cmbE_log.Text }
        
        $isSaveChecked = if ($chkSave_log.IsChecked -eq $true) { $true } else { $false }
        try { $Script:chkSave.IsChecked = $isSaveChecked } catch { $Script:chkSave.Checked = $isSaveChecked }

        # If Manual Sync is selected, ensure Auto DB Sync is forced off
        if ($cmbE_log.Text -eq "Manual Sync") {
            try { $Script:chkAutoSync.IsChecked = $false } catch { $Script:chkAutoSync.Checked = $false }
            try { $Script:cmbEnv.Text = "ALL" } catch {}
        } else {
            try { $Script:chkAutoSync.IsChecked = $true } catch { $Script:chkAutoSync.Checked = $true }
        }
        
        $global:LoginResult = $true
        $logForm.Close()
    })
    
    $btnExit.Add_Click({ 
        $txtS_log.Text = $env:COMPUTERNAME
        $txtU_log.Text = "sa"
        $txtP_log.Password = ""
        $cmbE_log.SelectedIndex = 0
        $chkSave_log.IsChecked = $false
    })

    $logForm.ShowDialog() | Out-Null
    return $global:LoginResult
}

function DoEvents {
    $frame = New-Object System.Windows.Threading.DispatcherFrame
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [Action] { $frame.Continue = $false }
    ) | Out-Null
    [System.Windows.Threading.Dispatcher]::PushFrame($frame)
}

function Log($msg, $color="White") { 
    $mappedColor = switch ($color) {
        "Lime" { "#00FF00" }
        "Cyan" { "#00B4D8" }
        "Red" { "#FA8072" }
        "Yellow" { "#FFD700" }
        "Orange" { "#FF8C00" }
        "Gray" { "#A9A9A9" }
        "DarkGray" { "#888888" }
        "White" { "#CCCCCC" }
        "IndianRed" { "#CD5C5C" }
        Default { $color }
    }
    $ts = "[$(Get-Date -Format 'HH:mm:ss')] "
    $p = New-Object System.Windows.Documents.Paragraph
    $p.Margin = New-Object System.Windows.Thickness(0)
    
    $rTime = New-Object System.Windows.Documents.Run($ts)
    $rTime.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#888888")
    
    $rMsg = New-Object System.Windows.Documents.Run($msg)
    $rMsg.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($mappedColor)
    
    [void]$p.Inlines.Add($rTime)
    [void]$p.Inlines.Add($rMsg)
    [void]$Script:logDoc.Blocks.Add($p)
    $Script:txtLog.ScrollToEnd()
    DoEvents
    
    try { Add-Content -Path $Script:SessionLogFile -Value "$ts $msg" } catch {}
}

function Load-Image {
    param($Element, $Path)
    if ([string]::IsNullOrWhiteSpace($Path) -or !(Test-Path $Path)) { return }
    try {
        $uri = New-Object System.Uri("file:///$($Path -replace '\\','/')")
        $bitmap = New-Object System.Windows.Media.Imaging.BitmapImage
        $bitmap.BeginInit()
        $bitmap.UriSource = $uri
        $bitmap.CacheOption = [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad
        $bitmap.EndInit()
        $Element.Source = $bitmap
    } catch {}
}

function Add-DBToList {
    param([string]$dbName, [string]$dbKey, [string]$type, [bool]$check)
    $mappedColor = switch ($type) {
        "Other" { "#FFD700" }
        "Phoenix Master" { "#00B4D8" }
        Default { "#00B4D8" }
    }
    $item = [PSCustomObject]@{
        Key       = $dbKey
        DBName    = $dbName
        Type      = $type
        Color     = $mappedColor
        IsChecked = $check
    }
    [void]$Script:listDBs.Items.Add($item)
}

function Get-CheckedDBs {
    $checkedItems = @()
    foreach ($item in $Script:listDBs.Items) {
        if ($item.IsChecked -eq $true) { $checkedItems += $item }
    }
    
    # Force PowerShell to keep it as an array if there is exactly 1 item 
    # so that the .Count property works perfectly in your button logic.
    if ($checkedItems.Count -eq 1) { return ,$checkedItems }
    
    return $checkedItems
}

function Toggle($s) { 
    # Suppressing UI disable logic to preserve the active "Task in progress" notifications per user request.
}

function Show-InputBox { 
    param($T, $P, $D) 
    $f = New-Object System.Windows.Forms.Form; $f.Text = $T; $f.Size = New-Object System.Drawing.Size(350, 150); $f.StartPosition = "CenterParent"
    $f.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30); $f.ForeColor = [System.Drawing.Color]::White
    $l = New-Object System.Windows.Forms.Label; $l.Text = $P; $l.Location = "10,10"; $l.AutoSize = $true; $f.Controls.Add($l)
    $t = New-Object System.Windows.Forms.TextBox; $t.Text = $D; $t.Location = "10,35"; $t.Width = 310; $f.Controls.Add($t)
    $b = New-Object System.Windows.Forms.Button; $b.Text = "OK"; $b.DialogResult = "OK"; $b.Location = "120,70"; $f.Controls.Add($b); $f.AcceptButton = $b
    if($f.ShowDialog() -eq "OK"){ return $t.Text } return $null 
}

function Show-JurisSelector { 
    param($T, $P, $Options) 
    $f = New-Object System.Windows.Forms.Form; $f.Text = $T; $f.Size = New-Object System.Drawing.Size(350, 150); $f.StartPosition = "CenterParent"
    $f.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30); $f.ForeColor = [System.Drawing.Color]::White
    $l = New-Object System.Windows.Forms.Label; $l.Text = $P; $l.Location = "10,10"; $l.AutoSize = $true; $f.Controls.Add($l)
    $cb = New-Object System.Windows.Forms.ComboBox; $cb.Location = "10,35"; $cb.Width = 310; $cb.DropDownStyle = "DropDownList"
    foreach($o in $Options){ [void]$cb.Items.Add($o) }
    if($cb.Items.Count -gt 0){ $cb.SelectedIndex = 0 }
    $f.Controls.Add($cb)
    $b = New-Object System.Windows.Forms.Button; $b.Text = "OK"; $b.DialogResult = [System.Windows.Forms.DialogResult]::OK ; $b.Location = "120,70"; $f.Controls.Add($b); $f.AcceptButton = $b
    if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){ return $cb.Text } return $null 
}

function Get-DBJurisIDs {
    param($DBName)
    $jList = @()
    try {
        $CS="Server=$($Script:txtS.Text);Database=$DBName;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Connection Timeout=5"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
        $cmd = $CN.CreateCommand(); $cmd.CommandText = "SELECT DISTINCT JurisID FROM Juris WITH(NOLOCK) ORDER BY JurisID"
        $rdr = $cmd.ExecuteReader(); while($rdr.Read()){ $jList += $rdr.GetValue(0).ToString() }; $rdr.Close(); $CN.Close()
    } catch { Log "  ⚠ Could not fetch JurisIDs from $DBName." "Orange" }
    if ($jList.Count -eq 0) { $jList += "1000" } 
    return $jList
}

function Save-Creds {
    $isSaved = $false
    try { if ($Script:chkSave.IsChecked -eq $true) { $isSaved = $true } } catch {}
    try { if ($Script:chkSave.Checked -eq $true) { $isSaved = $true } } catch {}

    if ($isSaved) {
        try {
            $passStr = if ($Script:txtP.Password) { $Script:txtP.Password } else { $Script:txtP.Text }
            $pw = $passStr | ConvertTo-SecureString -AsPlainText -Force
            $envStr = if ($Script:cmbEnv.Text) { $Script:cmbEnv.Text } else { $Script:cmbEnv.SelectedItem }
            
            [PSCustomObject]@{ 
                Server   = $Script:txtS.Text
                User     = $Script:txtU.Text
                Password = $pw 
                Env      = $envStr
                Save     = $true
            } | Export-Clixml -Path $Script:CredFile -Force
        } catch { Log "❌ Credential Save Error: $($_.Exception.Message)" "Red" }
    } else { 
        if (Test-Path $Script:CredFile) { Remove-Item $Script:CredFile -Force -ErrorAction SilentlyContinue } 
    }
}

function Load-Creds {
    if (Test-Path $Script:CredFile) {
        try {
            $c = Import-Clixml $Script:CredFile
            $global:LoadedServer = $c.Server
            $global:LoadedUser = $c.User
            $global:LoadedPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($c.Password))
            $global:LoadedEnv = $c.Env
            $global:LoadedSave = $c.Save
            return $true
        } catch {}
    }
    return $false
}

function Show-SyncErrorAlert {
    param($DBName, $LogLines)
    $errForm = New-Object System.Windows.Forms.Form
    $errForm.Text = "🚨 SYNC FAILURE MONITOR : $DBName"
    $errForm.Size = New-Object System.Drawing.Size(700, 450)
    $errForm.StartPosition = "CenterScreen"
    $errForm.BackColor = [System.Drawing.Color]::FromArgb(30, 10, 10)
    $errForm.ForeColor = [System.Drawing.Color]::WhiteSmoke
    $errForm.TopMost = $true

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "CRITICAL ERROR DETECTED ON: $DBName"
    $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::Salmon
    $lblTitle.Dock = "Top"
    $lblTitle.TextAlign = "MiddleCenter"
    $lblTitle.Height = 40
    $errForm.Controls.Add($lblTitle)

    $txtErr = New-Object System.Windows.Forms.RichTextBox
    $txtErr.Dock = "Fill"
    $txtErr.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
    $txtErr.ForeColor = [System.Drawing.Color]::LightCoral
    $txtErr.Font = New-Object System.Drawing.Font("Consolas", 10)
    $txtErr.ReadOnly = $true
    $txtErr.Text = ($LogLines -join "`r`n")
    $errForm.Controls.Add($txtErr)

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "ACKNOWLEDGE ERROR"
    $btnOk.Dock = "Bottom"
    $btnOk.Height = 45
    $btnOk.BackColor = [System.Drawing.Color]::Crimson
    $btnOk.ForeColor = [System.Drawing.Color]::White
    $btnOk.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $btnOk.FlatStyle = "Flat"
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $errForm.Controls.Add($btnOk)
    
    [void]$errForm.ShowDialog()
}

function Get-SyncErrorDetails {
    param($WorkDir)
    try {
        $logDirs = @($WorkDir, "$WorkDir\Logs", "$WorkDir\Log")
        $latestLog = Get-ChildItem -Path $logDirs -File -Include DBToolLog*.txt, sync_*.txt, *.log, *.txt -Exclude "PnxAutoNewDBSyn.xml" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1

        if ($latestLog -and ($latestLog.LastWriteTime -ge (Get-Date).AddMinutes(-5))) {
            return Get-Content $latestLog.FullName -Tail 25 -ErrorAction SilentlyContinue
        }
        return @("No recent crash logs found in $WorkDir.", "Please check Windows Event Viewer or SQL Logs.")
    } catch { return @("Error parsing log directory.") }
}

function Scan-Server {
    param($Target)
    $TargetClean = $Target -replace "\\",""
    $Script:IsRemote = -not ($TargetClean -match "localhost|127\.0\.0\.1|\." -or $env:COMPUTERNAME -match "^$TargetClean$" -or $TargetClean -match "^$env:COMPUTERNAME$")
    
    $FoundPath = $null
    $Result = [PSCustomObject]@{ Valid=$false; Version="Not Found"; Path=$null; InstallPath=$null; CBValid=$false; CBVersion="Not Found"; CBInstallPath=$null }

    $CommonPaths = @(
        "ProPhoenix\Server Application Manager\AppReg_Main.xml",
        "Program Files (x86)\ProPhoenix\Server Application Manager\AppReg_Main.xml",
        "Program Files\ProPhoenix\Server Application Manager\AppReg_Main.xml"
    )

    if ($Script:IsRemote) {
        foreach ($drive in @("C$","D$","E$")) {
            foreach ($sub in $CommonPaths) {
                $p = "\\$TargetClean\$drive\$sub"
                if (Test-Path $p -ErrorAction SilentlyContinue) { $FoundPath = $p; break }
            }
            if ($FoundPath) { break }
        }
    } else {
        foreach ($d in (Get-PSDrive -PSProvider FileSystem).Root) {
            foreach ($sub in $CommonPaths) {
                $p = Join-Path $d $sub
                if (Test-Path $p -ErrorAction SilentlyContinue) { $FoundPath = $p; break }
            }
            if ($FoundPath) { break }
        }
    }

    if ($FoundPath) {
        $Result.Path = $FoundPath
        try {
            [xml]$x = Get-Content $FoundPath -ErrorAction Stop
            if ($x.PhoenixApplications.AppReg) {
                foreach ($app in $x.PhoenixApplications.AppReg) {
                    if ($app.AppPath -like "*Database Utility*" -and $app.AppPath -notlike "*CodeBook*" -and $app.AppPath -notlike "*CRM*" -and $app.AppPath -notmatch "(?i)Hub|Gateway") {
                        $v = if ($app.CurrentVersion) { $app.CurrentVersion } else { $app.Version }
                        $Result.Version = if ([string]::IsNullOrWhiteSpace($v)) { "0.0.0.0" } else { $v }
                        $Result.InstallPath = $app.AppPath; $Result.Valid = $true
                    }
                    if ($app.AppPath -like "*CodeBook*" -and $app.AppPath -notmatch "(?i)Hub|Gateway") {
                        $v = if ($app.CurrentVersion) { $app.CurrentVersion } else { $app.Version }
                        $Result.CBVersion = if ([string]::IsNullOrWhiteSpace($v)) { "0.0.0.0" } else { $v }
                        $Result.CBInstallPath = $app.AppPath; $Result.CBValid = $true
                    }
                }
            }
        } catch { $Result.Err = "Read Error" }
    }

    if ($Result.Valid) {
        $Script:DBSyncRoot = Join-Path $Result.InstallPath "DB Sync"
        $Script:txtPath.Text = $Script:DBSyncRoot
        $Script:lblVer.Text = "DB Ver: $($Result.Version)"; $Script:lblVer.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00FF00")
        Log "  ✔ Found Main Utility: $($Result.Version)" "Lime"
        $Script:AppMgrPath = Join-Path (Split-Path $Result.Path -Parent) "PnxAppMgr.exe"
    } else { 
        $Script:lblVer.Text = "DB Ver: Not Found"; $Script:lblVer.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#D13438")
        $Script:DBSyncRoot = $null
        if ($Script:IsRemote) { Log "  ⚠ Could not auto-detect remote path. Please click 'Browse'." "Orange" }
    }

    if ($Result.CBValid) {
        $Script:CodebookRoot = Join-Path $Result.CBInstallPath "DB Sync"
        Log "  ✔ Found Codebook Utility: $($Result.CBVersion)" "Lime"
        $Script:lblCBVer.Text = "CB Ver: $($Result.CBVersion)"; $Script:lblCBVer.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#00FF00")
    } else {
        $Script:CodebookRoot = $null
        $Script:lblCBVer.Text = "CB Ver: Not Found"; $Script:lblCBVer.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString("#D13438")
    }
}

$CleanAndKill = {
    param($dbTarget, $killMainDbSessions)
    try {
        $killCS = "Server=$($Script:txtS.Text);Database=master;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Connection Timeout=15"
        $killCN = New-Object System.Data.SqlClient.SqlConnection($killCS); $killCN.Open()
        $killCmd = $killCN.CreateCommand()
        
        if ($killMainDbSessions) {
            $killCmd.CommandText = "IF DB_ID('$dbTarget') IS NOT NULL BEGIN DECLARE @k1 varchar(8000) = ''; SELECT @k1 = @k1 + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$dbTarget'); EXEC(@k1); END"
            $killCmd.ExecuteNonQuery() | Out-Null
        }
        
        $tempDbName = "$dbTarget" + "PnxDBSync"
        $killCmd.CommandText = "IF DB_ID('$tempDbName') IS NOT NULL BEGIN DECLARE @k2 varchar(8000) = ''; SELECT @k2 = @k2 + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$tempDbName'); EXEC(@k2); EXEC('ALTER DATABASE [$tempDbName] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$tempDbName];'); END"
        $killCmd.ExecuteNonQuery() | Out-Null
        $killCN.Close()
    } catch {}
}

# --- SYNC PIPELINES ---
function Execute-CodebookSync {
    param($RawItems)
    try {
        if(-not $Script:CodebookRoot -or -not (Test-Path $Script:CodebookRoot)) {
            [System.Windows.Forms.MessageBox]::Show("Codebook Utility is not installed or detected on this server.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null; return
        }

        $fireTargets = @()
        foreach($i in $RawItems) { if ($Script:TargetMap[$i.Key].Folder -match "Fire") { $fireTargets += $Script:TargetMap[$i.Key].DB } }
        
        if ($fireTargets.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("No Fire databases selected! Codebook sync only applies to Fire DBs.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return
        }

        Log "▶ INITIATING CODEBOOK SYNC (FIRE ONLY)..." "Red"
        
        $cbExePath = Get-ChildItem -Path $Script:CodebookRoot -Filter "PnxDBSync.exe" -Recurse | Select-Object -First 1
        if (-not $cbExePath) { Log "   ❌ Could not find PnxDBSync.exe inside Codebook folder." "Red"; return }
        
        $cbWd = $cbExePath.DirectoryName
        $XmlPath = Join-Path $cbWd "PnxAutoNewDBSyn.xml"
        $syncMode = $Script:cmbSyncType.Text.Substring(0,1)
        $isMulti = ($Script:cmbSyncType.Text -match "Multiple")
        $wshell = New-Object -ComObject wscript.shell

        if ($isMulti) {
            $dbList = $fireTargets -join ";"
            Log "  > Grouping Fire DBs for Codebook: $dbList" "White"
            foreach($D in $fireTargets) { & $CleanAndKill $D $true }
            Start-Sleep -Seconds 2

            if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
            
            $XmlString = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
    <SourceServer>
        <IPAddress>$($Script:txtS.Text)</IPAddress> 
        <DBName>$dbList</DBName>
        <UserName>$($Script:txtU.Text)</UserName> 
        <Password>$($Script:txtP.Password)</Password> 
        <JurisID>1000</JurisID>
        <State>MA</State>
        <JurisName>ProPhoenix</JurisName>
        <JurisAlias>PNX</JurisAlias>
        <SyncType>3</SyncType>
    </SourceServer>
</PnxPakager>
"@
            [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))
            
            $SyncProc = Start-Process $cbExePath.FullName -WorkingDirectory $cbWd -WindowStyle Normal -PassThru
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            $promptHandled = $false
            
            while (-not $SyncProc.HasExited) {
                DoEvents; Start-Sleep -Milliseconds 250
                if (-not $promptHandled -and $stopwatch.Elapsed.TotalSeconds -gt 3 -and $stopwatch.Elapsed.TotalSeconds -lt 20) {
                    try { if ($wshell.AppActivate($SyncProc.Id)) { Start-Sleep -Milliseconds 100; $wshell.SendKeys("Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("%Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("{ENTER}"); $promptHandled = $true; Log "   > Auto-Answered Codebook Prompt." "DarkGray" } } catch {}
                }
            }
            $stopwatch.Stop()
            if ($SyncProc.ExitCode -eq 0) { Log "   ✔ Codebook Batch Sync Completed" "Lime" } 
            else { 
                Log "   ❌ Codebook Batch Process Failed! (Exit Code: $($SyncProc.ExitCode))" "Red"
                Show-SyncErrorAlert -DBName "CODEBOOK BATCH" -LogLines (Get-SyncErrorDetails -WorkDir $cbWd)
            }
            if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
            foreach($D in $fireTargets) { & $CleanAndKill $D $true }
        } 
        else {
            foreach ($D in $fireTargets) {
                Log "  > Syncing Codebook for: $D" "White"
                $killMain = if ($syncMode -eq "1") { $false } else { $true }
                & $CleanAndKill $D $killMain
                Start-Sleep -Seconds 2
                
                if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
                $XmlString = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
    <SourceServer>
        <IPAddress>$($Script:txtS.Text)</IPAddress> 
        <DBName>$D</DBName>
        <UserName>$($Script:txtU.Text)</UserName> 
        <Password>$($Script:txtP.Password)</Password> 
        <JurisID>1000</JurisID>
        <State>MA</State>
        <JurisName>ProPhoenix</JurisName>
        <JurisAlias>PNX</JurisAlias>
        <SyncType>$syncMode</SyncType>
    </SourceServer>
</PnxPakager>
"@
                [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))
                
                $SyncProc = Start-Process $cbExePath.FullName -WorkingDirectory $cbWd -WindowStyle Normal -PassThru
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $promptHandled = $false
                
                while (-not $SyncProc.HasExited) {
                    DoEvents; Start-Sleep -Milliseconds 250
                    if (-not $promptHandled -and $stopwatch.Elapsed.TotalSeconds -gt 3 -and $stopwatch.Elapsed.TotalSeconds -lt 20) {
                        try { if ($wshell.AppActivate($SyncProc.Id)) { Start-Sleep -Milliseconds 100; $wshell.SendKeys("Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("%Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("{ENTER}"); $promptHandled = $true; Log "   > Auto-Answered Codebook Prompt." "DarkGray" } } catch {}
                    }
                }
                $stopwatch.Stop()
                if ($SyncProc.ExitCode -eq 0) { Log "   ✔ Codebook Sync Completed for $D" "Lime" } 
                else { 
                    Log "   ❌ Codebook Sync Failed for $D (Exit Code: $($SyncProc.ExitCode))" "Red"
                    Show-SyncErrorAlert -DBName "CODEBOOK: $D" -LogLines (Get-SyncErrorDetails -WorkDir $cbWd)
                }
                if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
                & $CleanAndKill $D $killMain
            }
        }
    } catch { Log "❌ Codebook Error: $($_.Exception.Message)" "Red" }
}

function Execute-DBSync {
    param($RawItems)
    try {
        if ($RawItems.Count -eq 0) { return }
        
        $safeItems = @()
        foreach ($i in $RawItems) { $safeItems += $i.Key }
        
        $FailedDBs = @()
        $syncMode = $Script:cmbSyncType.Text.Substring(0,1)
        $isMulti = ($Script:cmbSyncType.Text -match "Multiple")
        $wshell = New-Object -ComObject wscript.shell

        if ($isMulti) {
            Log "▶ BATCH SYNC INITIATED (SyncType 3)" "Cyan"
            $groupedDBs = @{}
            foreach ($i in $safeItems) {
                $I = $Script:TargetMap[$i]; $D = $I.DB; $F = $I.Folder
                if ($F -eq "None") { Log "   ! Skipped $($D): No Utility Folder Mapped" "Orange"; continue }
                if (-not $groupedDBs.ContainsKey($F)) { $groupedDBs[$F] = @() }
                $groupedDBs[$F] += $D
            }

            $safeKeys = @()
            foreach ($k in $groupedDBs.Keys) { $safeKeys += $k }
            $sortedFolders = $safeKeys | Sort-Object { if ($_ -eq 'Phoenix Master') { 0 } else { 1 } }

            foreach ($F in $sortedFolders) {
                $dbList = $groupedDBs[$F] -join ";"
                $WD = "$($Script:DBSyncRoot)\$F"
                $XmlPath = "$WD\PnxAutoNewDBSyn.xml"

                Log "▶ Processing Group [$F]" "Yellow"; DoEvents
                Log "  Targets: $dbList" "White"

                if (!(Test-Path "$WD\PnxDBSync.exe")) { Log "   ! Skipped: Missing EXE in $WD" "Orange"; continue }

                foreach ($D in $groupedDBs[$F]) { & $CleanAndKill $D $true }
                Start-Sleep -Seconds 2

                if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }

                $XmlString = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
    <SourceServer>
        <IPAddress>$($Script:txtS.Text)</IPAddress> 
        <DBName>$dbList</DBName>
        <UserName>$($Script:txtU.Text)</UserName> 
        <Password>$($Script:txtP.Password)</Password> 
        <JurisID>1000</JurisID>
        <State>MA</State>
        <JurisName>ProPhoenix</JurisName>
        <JurisAlias>PNX</JurisAlias>
        <SyncType>3</SyncType>
    </SourceServer>
</PnxPakager>
"@
                [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))

                $SyncProc = Start-Process "$WD\PnxDBSync.exe" -WorkingDirectory $WD -WindowStyle Normal -PassThru
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $promptHandled = $false
                
                while (-not $SyncProc.HasExited) {
                    DoEvents; Start-Sleep -Milliseconds 250
                    if (-not $promptHandled -and $stopwatch.Elapsed.TotalSeconds -gt 3 -and $stopwatch.Elapsed.TotalSeconds -lt 20) {
                        try { if ($wshell.AppActivate($SyncProc.Id)) { Start-Sleep -Milliseconds 100; $wshell.SendKeys("Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("%Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("{ENTER}"); $promptHandled = $true; Log "   > Auto-Answered Upgrade Prompt." "DarkGray" } } catch {}
                    }
                }
                $stopwatch.Stop()
                
                if ($SyncProc.ExitCode -eq 0) { Log "   ✔ Batch Sync Completed Successfully" "Lime" } 
                else {
                    $FailedDBs += "Group: $F ($dbList)"
                    Log "   ❌ Batch Sync Process Failed! (Exit Code: $($SyncProc.ExitCode))" "Red"
                    Show-SyncErrorAlert -DBName "BATCH GROUP: $F" -LogLines (Get-SyncErrorDetails -WorkDir $WD)
                }

                if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
                foreach ($D in $groupedDBs[$F]) { & $CleanAndKill $D $true }
            }
        } 
        else {
            $sortedItems = $safeItems | Sort-Object { if ($Script:TargetMap[$_].Folder -eq 'Phoenix Master') { 0 } else { 1 } }
            foreach ($i in $sortedItems) {
                $I = $Script:TargetMap[$i]; $D = $I.DB; $F = $I.Folder
                $XmlPath = "$($Script:DBSyncRoot)\$F\PnxAutoNewDBSyn.xml"

                Log "▶ EXECUTING SYNC: $($D) (SyncType $syncMode)" "Cyan"; DoEvents
                
                try {
                    if ($F -eq "None") { Log "   ! Skipped $($D): No Utility Folder Mapped" "Orange"; continue }
                    $WD = "$($Script:DBSyncRoot)\$F"
                    if (!(Test-Path "$WD\PnxDBSync.exe")) { Log "   ! Skipped: Missing EXE in $WD" "Orange"; continue }

                    $killMain = if ($syncMode -eq "1") { $false } else { $true }
                    & $CleanAndKill $D $killMain
                    Start-Sleep -Seconds 2 

                    if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }

                    $XmlString = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
    <SourceServer>
        <IPAddress>$($Script:txtS.Text)</IPAddress> 
        <DBName>$D</DBName>
        <UserName>$($Script:txtU.Text)</UserName> 
        <Password>$($Script:txtP.Password)</Password> 
        <JurisID>1000</JurisID>
        <State>MA</State>
        <JurisName>ProPhoenix</JurisName>
        <JurisAlias>PNX</JurisAlias>
        <SyncType>$syncMode</SyncType>
    </SourceServer>
</PnxPakager>
"@
                    [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))

                    $SyncProc = Start-Process "$WD\PnxDBSync.exe" -WorkingDirectory $WD -WindowStyle Normal -PassThru
                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    $promptHandled = $false

                    while (-not $SyncProc.HasExited) {
                        DoEvents; Start-Sleep -Milliseconds 250
                        if (-not $promptHandled -and $stopwatch.Elapsed.TotalSeconds -gt 3 -and $stopwatch.Elapsed.TotalSeconds -lt 20) {
                            try { if ($wshell.AppActivate($SyncProc.Id)) { Start-Sleep -Milliseconds 100; $wshell.SendKeys("Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("%Y"); Start-Sleep -Milliseconds 50; $wshell.SendKeys("{ENTER}"); $promptHandled = $true; Log "   > Auto-Answered Upgrade Prompt." "DarkGray" } } catch {}
                        }
                    }
                    $stopwatch.Stop()
                    
                    if ($SyncProc.ExitCode -eq 0) {
                        if ($syncMode -eq "1") { Log "   ✔ Sync Completed Successfully (Note: Make DB skips existing DBs)" "Lime" } 
                        else { Log "   ✔ Sync Completed Successfully" "Lime" }
                    } else {
                        $FailedDBs += $D
                        Log "   ❌ Sync Process Failed! (Exit Code: $($SyncProc.ExitCode))" "Red"
                        Show-SyncErrorAlert -DBName $D -LogLines (Get-SyncErrorDetails -WorkDir $WD)
                    }
                } catch { 
                    Log "   ❌ Exception during execution: $($_.Exception.Message)" "Red" 
                    $FailedDBs += $D
                } finally {
                    if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
                    & $CleanAndKill $D $killMain
                }
            }
        }

        if ($FailedDBs.Count -gt 0) {
            $msg = "The following databases encountered hard crashes during sync:`n`n" + ($FailedDBs -join "`n")
            [System.Windows.Forms.MessageBox]::Show($msg, "Sync Completed with Errors", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        } else { Log "✔ All databases processed successfully." "Lime" }
    } catch { Log "❌ CRITICAL PIPELINE ERROR: $($_.Exception.Message)" "Red" }
}

# --- ACTIONS BINDINGS ---
$Script:btnOverrideCat.Add_Click({
    if (-not (Check-TaskLock "Override DB Category")) { return }
    try {
        $checkedItems = Get-CheckedDBs
        if ($checkedItems.Count -eq 0) { 
            [System.Windows.Forms.MessageBox]::Show("Select Database(s) to Override!", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return 
        }
        $opts = @("Police", "Fire", "IA", "Police DW", "Phoenix Master", "Police CSP", "Fire CSP", "Other")
        $newType = Show-JurisSelector -T "Override Category" -P "Select Target DB Type/Category:" -Options $opts
        if ($newType) {
            foreach ($item in $Script:listDBs.Items) {
                if ($item.IsChecked) {
                    $item.Type = $newType
                    $item.Color = if ($newType -eq "Other") { "#FFD700" } elseif ($newType -eq "Phoenix Master") { "#00B4D8" } else { "#00B4D8" }
                    $Key = $item.Key
                    $Folder = if ($newType -eq "Other") { "None" } else { $newType }
                    
                    $Script:TargetMap[$Key].Folder = $Folder
                    $Script:OverrideMem[$item.DBName] = $newType # Save to Override Memory Array
                    
                    Log "  ✔ DB Category Overridden: $($item.DBName) -> $newType" "Cyan"
                }
            }
            # Save overrides to disk
            $Script:OverrideMem | Export-Clixml -Path $Script:OverrideFile -Force
            $Script:listDBs.Items.Refresh()
        }
    } catch { Log "❌ Override Error: $($_.Exception.Message)" "Red" } finally { Release-TaskLock }
})

$Script:btnCon.Add_Click({
    if (-not (Check-TaskLock "Connecting to Server")) { return }
    try {
        Toggle $false; $Script:listDBs.Items.Clear(); $Script:TargetMap=@{}
        Log "▶ INITIALIZING CONNECTION..." "Cyan"
        
        $cs = "Server=$($Script:txtS.Text);User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Database=master;Connection Timeout=5"
        $cn = New-Object System.Data.SqlClient.SqlConnection($cs); $cn.Open()
        $da = New-Object System.Data.SqlClient.SqlDataAdapter("SELECT Name FROM sys.databases WHERE database_id>4 AND Name NOT IN ('master','model','msdb','tempdb','ReportServer') ORDER BY Name", $cn)
        $ds = New-Object System.Data.DataSet; $da.Fill($ds)|Out-Null; $cn.Close()
        Log "  ✔ SQL Server Connected Successfully." "Lime"; $Script:lblStat.Text = "Connected to $($Script:txtS.Text)"; Save-Creds; Scan-Server $Script:txtS.Text 

        $Script:AutoCodebook = $false
        $hasAppMgr = $false
        if (-not [string]::IsNullOrWhiteSpace($Script:AppMgrPath)) { if (Test-Path $Script:AppMgrPath) { $hasAppMgr = $true } }

        if ($Script:chkAutoSync.IsChecked -and $hasAppMgr) {
            $ans = [System.Windows.Forms.MessageBox]::Show("Auto Update DB is checked.`n`nDo you also need to INSTALL and SYNC the Codebook Utility?", "Codebook Integration Pipeline", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) { $Script:AutoCodebook = $true }

            Log "  > Auto-Uninstalling utilities..." "Yellow"; DoEvents
            $Dir = Split-Path $Script:AppMgrPath -Parent
            $bat1 = "@echo off`ncd /d `"$Dir`"`n`"$($Script:AppMgrPath)`" UNINSTALL `"DBUtility`"`n"
            if ($Script:AutoCodebook) { $bat1 += "`"$($Script:AppMgrPath)`" UNINSTALL `"DatabaseUtilityCodebook`"`n" }
            Set-Content (Join-Path $env:TEMP "PnxAction.bat") $bat1
            $pBat1 = Start-Process (Join-Path $env:TEMP "PnxAction.bat") -WindowStyle Hidden -PassThru
            while (-not $pBat1.HasExited) { DoEvents; Start-Sleep -Milliseconds 250 }
            
            Start-Sleep -Seconds 2; DoEvents
            Log "  > Auto-Installing utilities..." "Yellow"; DoEvents
            
            $bat2 = "@echo off`ncd /d `"$Dir`"`n`"$($Script:AppMgrPath)`" INSTALL `"DBUtility`"`n"
            if ($Script:AutoCodebook) { $bat2 += "`"$($Script:AppMgrPath)`" INSTALL `"DatabaseUtilityCodebook`"`n" }
            Set-Content (Join-Path $env:TEMP "PnxAction.bat") $bat2
            $pBat2 = Start-Process (Join-Path $env:TEMP "PnxAction.bat") -WindowStyle Hidden -PassThru
            while (-not $pBat2.HasExited) { DoEvents; Start-Sleep -Milliseconds 250 }
            
            Log "  > Waiting for file extraction..." "DarkGray"; DoEvents
            $waitCounter = 0
            while ($waitCounter -lt 30) {
                Start-Sleep -Seconds 2
                if (Test-Path "$($Script:DBSyncRoot)\Phoenix Master\PnxDBSync.exe") { break }
                if (Test-Path "$($Script:DBSyncRoot)\Police\PnxDBSync.exe") { break }
                $waitCounter++
                DoEvents
            }
            if ($waitCounter -ge 30) { Log "   ! Warning: Extraction timed out." "Orange" } 
            else { Start-Sleep -Seconds 5; Log "  ✔ AppMgr Refreshed & Utility Verified." "Lime" }
            Scan-Server $Script:txtS.Text 
        }

        $EnvMode = $Script:cmbEnv.Text

        # [AUTO-MAPPING] SYNC TYPE
        if ($EnvMode -eq "LIVE" -or $EnvMode -eq "ALL") {
            $Script:cmbSyncType.Text = "3 - Batch Update"
        } elseif ($EnvMode -eq "TEST" -or $EnvMode -eq "TEST WSQL") {
            $Script:cmbSyncType.Text = "2 - Update/Upgrade"
        }
        # If Manual Sync, we don't force a SyncType.

        foreach ($row in $ds.Tables[0].Rows) {
            $db = $row.Name; $Folder = $null; $Tag = ""; $Type = ""
            
            $IsTrain = ($db -match "Tr" -or $db -match "Train")
            $IsTest = ($db -match "Test" -and -not $IsTrain) 
            $IsMaster = ($db -match "Master")
            $IsLive = (-not $IsTrain -and -not $IsTest -and -not $IsMaster)

            # [AUTO-MAPPING] STRICT ENVIRONMENT SCOPE
            if ($EnvMode -eq "LIVE") { 
                if ($IsTest) { continue } 
            } 
            elseif ($EnvMode -eq "TEST") { 
                if (-not $IsTest) { continue }
                if ($IsMaster) { continue }
            }
            elseif ($EnvMode -eq "TEST WSQL") {
                if (-not $IsTest -and -not $IsMaster) { continue }
            }
            # 'ALL' or 'Manual Sync' skips filtering and permits everything through

            $dbClean = $db -replace '(?i)Demo$','' -replace '\d+$',''

          if ($dbClean -match "DW") { $Type = "Police DW"; $Folder = "Police DW" }
            elseif ($dbClean -match "CSP") { 
                if($dbClean -match "Fire") { $Type = "Fire CSP"; $Folder = "Fire CSP" } else{ $Type = "Police CSP"; $Folder = "Police CSP" } 
            }
            elseif ($dbClean -match "Master") { $Type = "Phoenix Master"; $Folder = "Phoenix Master" }
            elseif ($dbClean -match "IA" -or $dbClean -match "InternalAffairs") { $Type = "IA"; $Folder = "IA" }
            elseif ($dbClean -match "Fire") { $Type = "Fire"; $Folder = "Fire" }
            elseif ($dbClean -match "Police") { $Type = "Police"; $Folder = "Police" }
            else { $Type = "Other"; $Folder = "None" }

            # --- APPLY MEMORY OVERRIDE ---
            if ($Script:OverrideMem.ContainsKey($db)) {
                $Type = $Script:OverrideMem[$db]
                $Folder = if ($Type -eq "Other") { "None" } else { $Type }
            }

            $Cat = if ($IsTest) { "TEST" } elseif ($IsTrain) { "LIVE" } else { "LIVE" }

            if ($Script:DBSyncRoot -and (-not $Script:IsRemote) -and $Folder -ne "None") {
                $P1 = Join-Path $Script:DBSyncRoot $Folder; if (!(Test-Path $P1)) { $Folder = $Folder.Replace(" ", "") } 
            }

            $Key = "[$Cat - $Type] $db"
            $Script:TargetMap[$Key] = @{ DB=$db; Folder=$Folder }

            Add-DBToList -dbName $db -dbKey $Key -type $Type -check $Script:chkAutoSync.IsChecked
        }

        if($Script:listDBs.Items.Count -gt 0){ Log "  + Listed & Grouped $($Script:listDBs.Items.Count) Databases" "Cyan" }

        if ($Script:chkAutoSync.IsChecked) {
            $checkedItems = Get-CheckedDBs
            if ($Script:AutoCodebook) {
                Log "▶ AUTO-UPDATE PIPELINE: CODEBOOK FIRST" "Yellow"; DoEvents
                Execute-CodebookSync $checkedItems
            }
            Log "▶ AUTO-UPDATE PIPELINE: MAIN UTILITY" "Yellow"; DoEvents
            Execute-DBSync $checkedItems
        }
    } 
    catch { Log "❌ Error: $($_.Exception.Message)" "Red" } 
    finally { Release-TaskLock; Toggle $true }
})

$Script:btnSync.Add_Click({ 
    if (-not (Check-TaskLock "Database Sync")) { return }
    try {
        $checkedItems = Get-CheckedDBs
        if($checkedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database(s) to Sync!", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
        Toggle $false; Execute-DBSync $checkedItems; 
    } catch { Log "❌ Error: $($_.Exception.Message)" "Red" } finally { Release-TaskLock; Toggle $true } 
})

$Script:btnCodebook.Add_Click({
    if (-not (Check-TaskLock "Codebook Sync")) { return }
    try { Toggle $false; Execute-CodebookSync (Get-CheckedDBs); } 
    catch { Log "❌ Error: $($_.Exception.Message)" "Red" } finally { Release-TaskLock; Toggle $true } 
})

$Script:btnVer.Add_Click({ 
    if (-not (Check-TaskLock "Version Check")) { return }
    try {
        $checkedItems = Get-CheckedDBs
        if($checkedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database(s) first!", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
        Toggle $false; Log "▶ CHECKING VERSIONS..." "Cyan"; Scan-Server $Script:txtS.Text; 
        $cn=New-Object System.Data.SqlClient.SqlConnection("Server=$($Script:txtS.Text);User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Database=master"); $cn.Open(); 
        foreach($i in $checkedItems){ $D=$Script:TargetMap[$i.Key].DB; $cmd=$cn.CreateCommand(); $cmd.CommandText="SELECT Version FROM [$D].dbo.KPIDBVersion"; try{ $v=$cmd.ExecuteScalar(); Log "  $D : $v" "White" }catch{Log "  $D : Error" "Red"} }; 
        $cn.Close() 
    } catch {} finally { Release-TaskLock; Toggle $true } 
})

$RunAppMgr = { param($Mode)
    if (-not (Check-TaskLock "$Mode Utility")) { return }
    try {
        $hasAppMgr = $false
        if (-not [string]::IsNullOrWhiteSpace($Script:AppMgrPath)) { if (Test-Path $Script:AppMgrPath) { $hasAppMgr = $true } }
        if (-not $hasAppMgr) {
            if (-not [string]::IsNullOrWhiteSpace($Script:txtPath.Text) -and (Test-Path $Script:txtPath.Text)) { $Script:AppMgrPath = Join-Path (Split-Path $Script:txtPath.Text -Parent) "PnxAppMgr.exe" }
            if (-not [string]::IsNullOrWhiteSpace($Script:AppMgrPath) -and (Test-Path $Script:AppMgrPath)) { $hasAppMgr = $true }
            if (-not $hasAppMgr) {
                [System.Windows.Forms.MessageBox]::Show("Please locate PnxAppMgr.exe", "Notice", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
                $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Filter="PnxAppMgr.exe|PnxAppMgr.exe"; 
                if($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){$Script:AppMgrPath=$f.FileName}else{return}
            }
        }
        $Bat = Join-Path $env:TEMP "PnxAction.bat"; $Dir = Split-Path $Script:AppMgrPath -Parent; $BatContent = "@echo off`ncd /d `"$Dir`"`n"
        if ($Mode -eq "INSTALL") {
            $BatContent += "`"$($Script:AppMgrPath)`" INSTALL `"DBUtility`"`n"
            $ans = [System.Windows.Forms.MessageBox]::Show("Do you also want to install the Codebook Utility?", "Install Codebook?", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) { $BatContent += "`"$($Script:AppMgrPath)`" INSTALL `"DatabaseUtilityCodebook`"`n" }
        } elseif ($Mode -eq "UNINSTALL") {
            $BatContent += "`"$($Script:AppMgrPath)`" UNINSTALL `"DBUtility`"`n"
            $ans = [System.Windows.Forms.MessageBox]::Show("Do you also want to uninstall the Codebook Utility?", "Uninstall Codebook?", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($ans -eq [System.Windows.Forms.DialogResult]::Yes) { $BatContent += "`"$($Script:AppMgrPath)`" UNINSTALL `"DatabaseUtilityCodebook`"`n" }
        }
        $BatContent += "pause"; Set-Content $Bat $BatContent; 
        $pBat = Start-Process $Bat -Verb RunAs -PassThru
        while (-not $pBat.HasExited) { DoEvents; Start-Sleep -Milliseconds 250 }
    } finally { Release-TaskLock }
}

$Script:btnCreateDB.Add_Click({ 
    if (-not (Check-TaskLock "Create New DB")) { return }
    try {
        if (-not $Script:DBSyncRoot) { 
            [System.Windows.Forms.MessageBox]::Show("Please select a valid Utility Path first.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
            return 
        }
        
        $d = Show-NewDBDialog
        if (-not $d) { return } 

        Toggle $false
        Log "▶ CREATING NEW DATABASE: $($d.DB)..." "Cyan"
        
        $Folder = $d.Cat
        $TargetDir = Join-Path $Script:DBSyncRoot $Folder
        if (!(Test-Path $TargetDir)) {
            $Folder = $Folder.Replace(" ", "")
            $TargetDir = Join-Path $Script:DBSyncRoot $Folder
        }

        if (!(Test-Path "$TargetDir\PnxDBSync.exe")) {
            Log "  ❌ Missing Executable: Cannot find PnxDBSync.exe in $Folder" "Red"
            return
        }

        $XmlPath = "$TargetDir\PnxAutoNewDBSyn.xml"
        if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }

        $XmlString = @"
<?xml version="1.0" encoding="utf-8" ?>
<PnxPakager>
    <SourceServer>
        <IPAddress>$($Script:txtS.Text)</IPAddress> 
        <DBName>$($d.DB)</DBName>
        <UserName>$($Script:txtU.Text)</UserName> 
        <Password>$($Script:txtP.Password)</Password> 
        <JurisID>$($d.JID)</JurisID>
        <State>$($d.St)</State>
        <JurisName>$($d.Nm)</JurisName>
        <JurisAlias>$($d.Al)</JurisAlias>
        <SyncType>1</SyncType>
    </SourceServer>
</PnxPakager>
"@
        [System.IO.File]::WriteAllText($XmlPath, $XmlString, (New-Object System.Text.UTF8Encoding($false)))

        Log "  > Executing PnxDBSync.exe..." "DarkGray"
        $SyncProc = Start-Process "$TargetDir\PnxDBSync.exe" -WorkingDirectory $TargetDir -WindowStyle Normal -PassThru
        
        while (-not $SyncProc.HasExited) { DoEvents; Start-Sleep -Milliseconds 250 }
        
        if ($SyncProc.ExitCode -eq 0 -or $null -eq $SyncProc.ExitCode) {
            Log "  ✔ Database Created Successfully." "Lime"
        } else {
            Log "  ❌ Process failed with exit code: $($SyncProc.ExitCode)" "Red"
        }

        if (Test-Path $XmlPath) { Remove-Item $XmlPath -Force -ErrorAction SilentlyContinue }
        $Script:btnCon.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))) 
    } 
    catch { 
        Log "  ❌ Creation Error: $($_.Exception.Message)" "Red" 
    } 
    finally { 
        Release-TaskLock
        Toggle $true 
    } 
})

$Script:btnInstall.Add_Click({ & $RunAppMgr "INSTALL" })
$Script:btnUninstall.Add_Click({ & $RunAppMgr "UNINSTALL" })

# NATIVE DB BACKUP / RESTORE
$Script:btnBackupDB.Add_Click({
    if (-not (Check-TaskLock "SQL Database Backup")) { return }
    try {
        $checkedItems = Get-CheckedDBs
        if($checkedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database(s) to Backup!", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.Description = "Select Backup Destination Folder"; $fbd.SelectedPath = $Script:DefaultBackup
        if($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){ return }
        $TargetDirBase = $fbd.SelectedPath

        Toggle $false; Log "▶ STARTING NATIVE SQL DATABASE BACKUP..." "Cyan"
        
        $CS="Server=$($Script:txtS.Text);Database=master;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Connection Timeout=30"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS)
        $CN.FireInfoMessageEventOnUserErrors = $true
        $CN.add_InfoMessage({ param($sender, $e) if ($e.Message -match "percent processed" -or $e.Message -match "processed.") { Log "   > $($e.Message)" "DarkGray" } })
        $CN.Open()

        $Cmd=$CN.CreateCommand(); $Cmd.CommandTimeout = 0

        foreach ($item in $checkedItems) {
            $DB = $Script:TargetMap[$item.Key].DB
            $BakFile = Join-Path $TargetDirBase "$DB`_ManualBackup_$(Get-Date -Format 'yyyyMMdd_HHmm').bak"
            Log "  > Backing up $DB to $BakFile..." "White"; DoEvents
            
            $Cmd.CommandText="BACKUP DATABASE [$DB] TO DISK='$BakFile' WITH INIT, COMPRESSION, STATS=10"
            try {
                $Cmd.ExecuteNonQuery()|Out-Null
                $BkpInfo = Get-Item $BakFile; $NewSize = [math]::Round($BkpInfo.Length / 1MB, 2)
                Log "  ✔ Backup Complete ($NewSize MB)" "Lime"
            } catch { Log "  ❌ Backup Failed: $($_.Exception.Message)" "Red" }
        }
        $CN.Close(); Log "✔ All Backups Finished." "Cyan"
    } 
    catch { Log "  ❌ Error: $($_.Exception.Message)" "Red" } 
    finally { Release-TaskLock; Toggle $true }
})

$Script:btnRestoreDB.Add_Click({
    if (-not (Check-TaskLock "SQL Database Restore")) { return }
    try {
        $checkedItems = Get-CheckedDBs
        if($checkedItems.Count -ne 1){ [System.Windows.Forms.MessageBox]::Show("Select exactly ONE database to restore into.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return }
        $TargetDB = $Script:TargetMap[$checkedItems[0].Key].DB

        $f = New-Object System.Windows.Forms.OpenFileDialog
        $f.Filter = "SQL Backup Files (*.bak)|*.bak"
        $f.Title = "Select .BAK File to Restore into $TargetDB"
        $f.InitialDirectory = $Script:DefaultBackup
        if ($f.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $BakFile = $f.FileName

        $ans = [System.Windows.Forms.MessageBox]::Show("CRITICAL WARNING:`n`nYou are about to overwrite the existing database [$TargetDB] with:`n$BakFile`n`nAre you absolutely sure?", "Confirm RESTORE", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Error)
        if($ans -ne [System.Windows.Forms.DialogResult]::Yes){ return }

        Toggle $false; Log "▶ INITIATING NATIVE SQL DATABASE RESTORE OVER [$TargetDB]..." "Red"
        
        $CS="Server=$($Script:txtS.Text);Database=master;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Connection Timeout=30"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS)
        $CN.FireInfoMessageEventOnUserErrors = $true
        $CN.add_InfoMessage({ param($sender, $e) if ($e.Message -match "percent processed" -or $e.Message -match "processed.") { Log "   > $($e.Message)" "DarkGray" } })
        $CN.Open()
        
        $Cmd=$CN.CreateCommand(); $Cmd.CommandTimeout = 0

        Log "  > Dropping user sessions on $TargetDB..." "Orange"; DoEvents
        try { 
            $CmdDrop = New-Object System.Data.SqlClient.SqlCommand("IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$TargetDB') BEGIN DECLARE @kill varchar(8000) = ''; SELECT @kill = @kill + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$TargetDB'); EXEC(@kill); ALTER DATABASE [$TargetDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; END", $CN)
            $CmdDrop.CommandTimeout = 0
            $CmdDrop.ExecuteNonQuery()|Out-Null 
        } catch { Log "   > Notice: Could not force Single User" "DarkGray" }

        Log "  > Analyzing Backup File..." "White"; DoEvents
        $Cmd.CommandText="RESTORE FILELISTONLY FROM DISK='$BakFile'"; $Rdr=$Cmd.ExecuteReader(); $Files=@(); while($Rdr.Read()){$Files+=@{L=$Rdr["LogicalName"];P=$Rdr["PhysicalName"];T=$Rdr["Type"]}}; $Rdr.Close()
        
        $MoveStr = ""; foreach($f in $Files){ 
            $Ext=[System.IO.Path]::GetExtension($f.P); $Dir=[System.IO.Path]::GetDirectoryName($f.P)
            $NewName = "$TargetDB"; if ($f.T -eq "L") { $NewName += "_log" }; $NewName += $Ext
            $NewPath = Join-Path $Dir $NewName
            $MoveStr += "MOVE '$($f.L)' TO '$NewPath', " 
        }

        Log "  > Restoring $TargetDB (WITH LIVE PROGRESS)..." "White"; DoEvents
        $Cmd.CommandText="RESTORE DATABASE [$TargetDB] FROM DISK='$BakFile' WITH RECOVERY, REPLACE, STATS=10, $($MoveStr.TrimEnd(', '))"
        $Cmd.ExecuteNonQuery()|Out-Null
        
        $Cmd.CommandText = "ALTER DATABASE [$TargetDB] SET MULTI_USER"; $Cmd.ExecuteNonQuery()|Out-Null
        $CN.Close()
        Log "  ✔ Restore Complete." "Lime"
        $Script:btnCon.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    } 
    catch { Log "  ❌ Error: $($_.Exception.Message)" "Red" } 
    finally { Release-TaskLock; Toggle $true }
})

$Script:btnDeleteDB.Add_Click({
    if (-not (Check-TaskLock "Delete Database")) { return }
    try {
        $checkedItems = Get-CheckedDBs
        if($checkedItems.Count -eq 0){ [System.Windows.Forms.MessageBox]::Show("Select Database to Delete!", "Warning", "OK", "Warning"); return }
        $Targets = @(); foreach($i in $checkedItems){ $Targets += $Script:TargetMap[$i.Key].DB }
        $Names = $Targets -join ", "
        if([System.Windows.Forms.MessageBox]::Show("DELETE DATABASE(S): $Names`n`nThis will PERMANENTLY REMOVE the database and files (.mdf/.ldf).`n`nAre you absolutely sure?", "CRITICAL WARNING", "YesNo", "Error") -ne "Yes"){ return }
        if([System.Windows.Forms.MessageBox]::Show("Double Check: Delete $Names?", "Final Confirmation", "YesNo", "Error") -ne "Yes"){ return }
        Toggle $false; Log "Deleting Databases..." "Red"
        
        $CS="Server=$($Script:txtS.Text);Database=master;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Connection Timeout=30"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
        foreach($DB in $Targets){
            Log "Dropping $DB..." "Orange"; DoEvents
            
            $KillCmd = New-Object System.Data.SqlClient.SqlCommand("IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$DB') BEGIN DECLARE @kill varchar(8000) = ''; SELECT @kill = @kill + 'kill ' + CONVERT(varchar(5), session_id) + ';' FROM sys.dm_exec_sessions WHERE database_id = db_id('$DB'); EXEC(@kill); END", $CN)
            try { $KillCmd.ExecuteNonQuery()|Out-Null } catch {}

            $Cmd=$CN.CreateCommand(); $Cmd.CommandTimeout = 0
            $Cmd.CommandText = "IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$DB') BEGIN ALTER DATABASE [$DB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$DB]; END"
            $Cmd.ExecuteNonQuery()|Out-Null
            Log "   ✔ Deleted $DB" "Red"
        }
        $CN.Close(); $Script:btnCon.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    } catch { Log "❌ Error: $($_.Exception.Message)" "Red" } finally { Release-TaskLock; Toggle $true }
})

# ENTERPRISE CONFIG
function Apply-EnterpriseConfig {
    param($TargetDB, $SourceFile, $TargetJuris)
    $Content = Get-Content $SourceFile
    $restoreParams = @{}; $restoreJobs = @(); $currentMode = "NONE"; $currentJob = $null

    foreach ($line in $Content) {
        $l = $line.Trim()
        if ($l -eq "" -or $l.StartsWith("#")) { continue }
        if ($l.ToUpper() -eq "[PARAMETERS]") { $currentMode = "PARAMS"; continue }
        if ($l -match "^\[JOB:(.+)\]$") { 
            $currentMode = "JOB"
            if ($currentJob -ne $null) { $restoreJobs += $currentJob }
            $currentJob = @{ Name = $Matches[1]; Type = $null; Params = @(); Notifies = @() }
            continue 
        }
        if ($currentMode -eq "PARAMS") {
            $parts = $l -split "=", 2; if ($parts.Count -eq 2) { $restoreParams[$parts[0].Trim()] = $parts[1].Trim() }
        } elseif ($currentMode -eq "JOB" -and $currentJob -ne $null) {
            $parts = $l -split "=", 2
            if ($parts.Count -eq 2) {
                $k = $parts[0].Trim(); $v = $parts[1].Trim()
                if ($k -eq "JobType") { $currentJob.Type = $v }
                elseif ($k -match "^Param:(.+)$") { $currentJob.Params += @{ Name = $Matches[1]; Value = $v } }
                elseif ($k -eq "NotifyPath") { $currentJob.Notifies += $v }
            }
        }
    }
    if ($currentJob -ne $null) { $restoreJobs += $currentJob }

    try {
        $CS="Server=$($Script:txtS.Text);Database=$TargetDB;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Connection Timeout=15"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
        
        $pUpdated = 0; $pInserted = 0; $pSkipped = 0
        foreach ($paramID in $restoreParams.Keys) {
            $paramVal = $restoreParams[$paramID].Replace("'", "''")
            $upsertQuery = @"
            SET NOCOUNT ON;
            DECLARE @tID INT = $paramID; 
            DECLARE @tVal NVARCHAR(MAX) = '$paramVal'; 
            DECLARE @sysJurisID INT = $TargetJuris;
            IF EXISTS (SELECT 1 FROM Parameter WHERE CAST(ParamID AS INT) = @tID AND JurisID = @sysJurisID)
            BEGIN
                UPDATE Parameter SET ParamValue = @tVal WHERE CAST(ParamID AS INT) = @tID AND JurisID = @sysJurisID; 
                SELECT 'Updated' AS Action;
            END
            ELSE BEGIN
                IF OBJECT_ID('dbo.ParameterName', 'U') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ParameterName WHERE CAST(ParamID AS INT) = @tID)
                BEGIN SELECT 'Skipped_FK' AS Action; END
                ELSE BEGIN
                    DECLARE @nextSLNo BIGINT; 
                    SELECT @nextSLNo = ISNULL(MAX(CAST(SLNo AS BIGINT)), 0) + 1 FROM Parameter WITH (UPDLOCK, HOLDLOCK);
                    INSERT INTO Parameter (SLNo, ParamID, ParamValue, JurisID) VALUES (@nextSLNo, @tID, @tVal, @sysJurisID); 
                    SELECT 'Inserted' AS Action;
                END
            END
"@
            $cmd = $CN.CreateCommand(); $cmd.CommandText = $upsertQuery
            try { 
                $res = $cmd.ExecuteScalar()
                if ($res -eq 'Updated') { $pUpdated++ } elseif ($res -eq 'Inserted') { $pInserted++ } elseif ($res -eq 'Skipped_FK') { $pSkipped++ } 
            } catch { }
        }
        Log "   ✔ Params: $pUpdated Updated | $pInserted Inserted | $pSkipped Skipped" "Lime"

        $jRestored = 0
        foreach ($job in $restoreJobs) {
            $jName = $job.Name.Replace("'", "''")
            $jType = if ([string]::IsNullOrWhiteSpace($job.Type)) { "JobType" } else { "'$($job.Type.Replace("'", "''"))'" }
            $jobQuery = "DECLARE @jID BIGINT; SELECT TOP 1 @jID = JobID FROM KPIjobs WHERE JobName = '$jName'; IF @jID IS NOT NULL BEGIN UPDATE KPIjobs SET IsInactive = 0, StartDttm = GETDATE(), EndDttm = '2099-12-31', NextExDttm = GETDATE(), JobType = $jType WHERE JobID = @jID; DELETE FROM KPIjobsparam WHERE JobID = @jID; DELETE FROM KPIJobsNotify WHERE JobID = @jID; SELECT @jID AS FoundJobID; END"
            $cmd = $CN.CreateCommand(); $cmd.CommandText = $jobQuery; $returnedJobID = $cmd.ExecuteScalar()

            if ($returnedJobID) {
                if ($job.Params) { foreach ($jp in $job.Params) { $pName = $jp.Name.Replace("'", "''"); $pVal = $jp.Value.Replace("'", "''"); $cmd.CommandText = "INSERT INTO KPIjobsparam(JobID, SeqNo, ParamName, ParamValue) VALUES ($returnedJobID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIjobsparam WHERE JobID = $returnedJobID), '$pName', '$pVal')"; $cmd.ExecuteNonQuery() | Out-Null } }
                if ($job.Notifies) { foreach ($folder in $job.Notifies) { $fSafe = $folder.Replace("'", "''"); $cmd.CommandText = "INSERT INTO KPIJobsNotify SELECT $returnedJobID, (SELECT ISNULL(MAX(SeqNo),0)+1 FROM KPIJobsNotify WHERE JobID = j.JobID), NULL, NULL, '$fSafe', 1, NULL, NULL, NULL, NULL FROM KPIJobs j WHERE JobID = $returnedJobID"; $cmd.ExecuteNonQuery() | Out-Null } }
                $jRestored++
            }
        }
        Log "   ✔ Jobs: $jRestored Configured Successfully" "Lime"; $CN.Close()
    } catch { Log "   ❌ Config Apply Failed: $($_.Exception.Message)" "Red" }
}

function Show-CopyDialog {
    $d = New-Object System.Windows.Forms.Form; $d.Text = "Select Copy Type"; $d.Size = New-Object System.Drawing.Size(300, 150); $d.StartPosition = "CenterParent"
    $d.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30); $d.ForeColor = [System.Drawing.Color]::White
    $l = New-Object System.Windows.Forms.Label; $l.Text = "Select Target Type:"; $l.Location = "20,20"; $l.AutoSize = $true; $d.Controls.Add($l)
    $cb = New-Object System.Windows.Forms.ComboBox; $cb.Items.AddRange(@("Train (Tr)", "Test (Test)")); $cb.SelectedIndex = 0; $cb.Location = "20,50"; $cb.Width = 240; $d.Controls.Add($cb)
    $b = New-Object System.Windows.Forms.Button; $b.Text = "PROCEED"; $b.DialogResult = [System.Windows.Forms.DialogResult]::OK; $b.Location = "80,80"; $d.Controls.Add($b); $d.AcceptButton = $b
    if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $cb.SelectedItem } return $null
}

$Script:btnCopyDB.Add_Click({
    if (-not (Check-TaskLock "Live to Train/Test Copy")) { return }
    try {
        $checkedItems = Get-CheckedDBs
        if($checkedItems.Count -ne 1){ 
            [System.Windows.Forms.MessageBox]::Show("Select exactly ONE source database.", "Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null; return 
        }
        $SourceDB = $Script:TargetMap[$checkedItems[0].Key].DB
        $TypeSel = Show-CopyDialog; if($null -eq $TypeSel){ return }
        $Tag = if($TypeSel -match "Train"){"Tr"}else{"Test"}
        $DefName = if($SourceDB -match "^Phoenix") { $SourceDB.Replace("Phoenix", "Phoenix$Tag") } else { "$($SourceDB)_$Tag" }
        $TargetDB = Show-InputBox "Target Name" "Confirm Target Database Name:" $DefName
        if ([string]::IsNullOrWhiteSpace($TargetDB)) { return }

        $CS="Server=$($Script:txtS.Text);Database=master;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Connection Timeout=30"
        $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open()
        $Cmd=$CN.CreateCommand(); $Cmd.CommandTimeout = 0
        $Cmd.CommandText = "SELECT ISNULL(DB_ID('$TargetDB'), 0)"; $targetId = $Cmd.ExecuteScalar()

        if ([int]$targetId -gt 0) {
            $ansBkp = [System.Windows.Forms.MessageBox]::Show("Target database [$TargetDB] already exists.`n`nBackup existing Params/Jobs before overwriting?", "Pre-Overwrite Backup", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($ansBkp.Equals([System.Windows.Forms.DialogResult]::Yes)) {
                $availableJuris = Get-DBJurisIDs -DBName $TargetDB
                $selJ = Show-JurisSelector "Source JurisID" "Select JurisID to backup from [$TargetDB]:" $availableJuris
                if (![string]::IsNullOrWhiteSpace($selJ)) {
                    $fbdBkp = New-Object System.Windows.Forms.FolderBrowserDialog; $fbdBkp.SelectedPath = $Script:DefaultBackup
                    if($fbdBkp.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
                        Log "▶ BACKING UP EXISTING [$TargetDB]: JURIS $selJ..." "Cyan"
                        $TS=Get-Date -Format "yyyyMMdd_HHmm"
                        $BackupLines = @("# ProPhoenix Database Configuration Backup", "# Database: $TargetDB (PRE-OVERWRITE)", "# Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", "")
                        $CNTarget=New-Object System.Data.SqlClient.SqlConnection("Server=$($Script:txtS.Text);Database=$TargetDB;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Connection Timeout=15"); $CNTarget.Open(); $cmdTarget = $CNTarget.CreateCommand()
                        $cmdTarget.CommandText = "SET NOCOUNT ON; SELECT ParamID, CAST(ParamValue AS NVARCHAR(MAX)) FROM Parameter WHERE ParamID IN ($($Script:TargetParams -join ',')) AND JurisID=$selJ"; $reader = $cmdTarget.ExecuteReader(); $BackupLines += "[PARAMETERS]"
                        while ($reader.Read()) { $pVal = if ($reader.IsDBNull(1)) { "" } else { $reader.GetString(1) }; $BackupLines += "$($reader.GetValue(0))=$pVal" }
                        $reader.Close(); Log "   + Exported Parameters" "Lime"; $BackupLines += ""
                        
                        $cmdTarget.CommandText = "SELECT JobID, JobName, JobType FROM KPIjobs WHERE JobName IN ('$($Script:TargetJobs -join "','")')"
                        $jobReader = $cmdTarget.ExecuteReader(); $tempJobs = @(); while ($jobReader.Read()) { $tempJobs += @{ ID = $jobReader.GetValue(0); Name = $jobReader.GetString(1); Type = if ($jobReader.IsDBNull(2)) { "" } else { $jobReader.GetString(2) } } }; $jobReader.Close()
                        
                        foreach ($job in $tempJobs) { 
                            $BackupLines += "[JOB:$($job.Name)]"; if ($job.Type -ne "") { $BackupLines += "JobType=$($job.Type)" }
                            $cmdTarget.CommandText = "SELECT ParamName, ParamValue FROM KPIjobsparam WHERE JobID = $($job.ID)"; $pReader = $cmdTarget.ExecuteReader(); 
                            while ($pReader.Read()) { $jpName = if ($pReader.IsDBNull(0)) { "" } else { $pReader.GetString(0) }; $jpVal = if ($pReader.IsDBNull(1)) { "" } else { $pReader.GetString(1) }; $BackupLines += "Param:$jpName=$jpVal" }
                            $pReader.Close(); 
                            $cmdTarget.CommandText = "SELECT * FROM KPIJobsNotify WHERE JobID = $($job.ID)"; $nReader = $cmdTarget.ExecuteReader()
                            while ($nReader.Read()) { if (!($nReader.IsDBNull(4))) { $BackupLines += "NotifyPath=$($nReader.GetString(4))" } }; $nReader.Close(); $BackupLines += "" 
                        }
                        [IO.File]::WriteAllLines((Join-Path $fbdBkp.SelectedPath "$($TargetDB)_PreCopyBackup_$TS.txt"), $BackupLines, [System.Text.Encoding]::UTF8); $CNTarget.Close(); Log "  ✔ Pre-Overwrite Backup Saved." "Lime"
                    }
                }
            }
            if ([System.Windows.Forms.MessageBox]::Show("Confirm: DROP and REPLACE [$TargetDB]?", "Final Warning", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Error) -ne [System.Windows.Forms.DialogResult]::Yes) { $CN.Close(); return }
        }

        $ansRest = [System.Windows.Forms.MessageBox]::Show("Apply a configuration backup (.txt) to [$TargetDB] after copy?", "Apply Config?", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        $ConfigFilePath = $null; $TargetJurisID = "1000"
        if ($ansRest.Equals([System.Windows.Forms.DialogResult]::Yes)) {
            $f = New-Object System.Windows.Forms.OpenFileDialog; $f.Filter = "Text Backup (*.txt)|*.txt"; $f.InitialDirectory = $Script:DefaultBackup
            if ($f.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { 
                $ConfigFilePath = $f.FileName 
                $TargetJurisID = Show-InputBox "Target JurisID" "Enter Target JurisID for restoring params into [$TargetDB]:" "1000"
                if ([string]::IsNullOrWhiteSpace($TargetJurisID)) { $CN.Close(); return }
            }
        }

        Toggle $false
        $CN.FireInfoMessageEventOnUserErrors = $true
        $CN.add_InfoMessage({ param($sender, $e) if ($e.Message -match "percent processed" -or $e.Message -match "processed.") { Log "   > $($e.Message)" "DarkGray" } })
        $Cmd.CommandText="SELECT ISNULL(CAST(SUM(size)*8/1024 AS VARCHAR), 'Unknown') FROM sys.master_files WHERE database_id=DB_ID('$SourceDB')"
        $SizeMB = $Cmd.ExecuteScalar().ToString()
        if([System.Windows.Forms.MessageBox]::Show("Proceed with Source Backup? ($SizeMB MB)", "Confirm Copy", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question) -ne [System.Windows.Forms.DialogResult]::Yes){ $CN.Close(); return }
        
        $fbdSource = New-Object System.Windows.Forms.FolderBrowserDialog; $fbdSource.SelectedPath = $Script:DefaultBackup
        if($fbdSource.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){ $CN.Close(); return }
        
        $BakFile = Join-Path $fbdSource.SelectedPath "$SourceDB`_Copy.bak"
        Log "▶ COPYING: $SourceDB -> $TargetDB..." "Cyan"
        
        Log "  > Backing up Source..."; DoEvents
        $Cmd.CommandText="BACKUP DATABASE [$SourceDB] TO DISK='$BakFile' WITH COPY_ONLY, INIT, FORMAT, COMPRESSION, STATS=10"
        $Cmd.ExecuteNonQuery()|Out-Null

        Log "  > Overwriting Target..."; DoEvents
        try { 
            $CmdKill = New-Object System.Data.SqlClient.SqlCommand("IF EXISTS(SELECT 1 FROM sys.databases WHERE name='$TargetDB') BEGIN ALTER DATABASE [$TargetDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; END", $CN)
            $CmdKill.ExecuteNonQuery()|Out-Null 
        } catch { }

        $Cmd.CommandText="RESTORE FILELISTONLY FROM DISK='$BakFile'"; $Rdr=$Cmd.ExecuteReader(); $Files=@(); while($Rdr.Read()){$Files+=@{L=$Rdr["LogicalName"];P=$Rdr["PhysicalName"];T=$Rdr["Type"]}}; $Rdr.Close()
        $MoveStr = ""; foreach($f in $Files){ $Ext=[System.IO.Path]::GetExtension($f.P); $Dir=[System.IO.Path]::GetDirectoryName($f.P); $NewName = "$TargetDB"; if ($f.T -eq "L") { $NewName += "_log" }; $NewName += $Ext; $MoveStr += "MOVE '$($f.L)' TO '$(Join-Path $Dir $NewName)', " }
        
        $Cmd.CommandText="RESTORE DATABASE [$TargetDB] FROM DISK='$BakFile' WITH RECOVERY, REPLACE, STATS=10, $($MoveStr.TrimEnd(', '))"
        $Cmd.ExecuteNonQuery()|Out-Null
        $Cmd.CommandText = "ALTER DATABASE [$TargetDB] SET MULTI_USER"; $Cmd.ExecuteNonQuery()|Out-Null
        Log "  ✔ Database Overwrite Complete." "Lime"

        if (![string]::IsNullOrEmpty($ConfigFilePath)) {
            Log "▶ APPLYING CONFIG: Juris $TargetJurisID..." "Yellow"
            Apply-EnterpriseConfig -TargetDB $TargetDB -SourceFile $ConfigFilePath -TargetJuris $TargetJurisID
        }
        $CN.Close(); Log "✔ Process Finished for [$TargetDB]." "Lime"; $Script:btnCon.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    } catch { Log "❌ Failed: $($_.Exception.Message)" "Red" } finally { Release-TaskLock; Toggle $true }
})

$Script:btnBackup.Add_Click({
    if (-not (Check-TaskLock "Backup Jobs & Params")) { return }
    try {
        $checkedItems = Get-CheckedDBs
        if($checkedItems.Count -eq 0){ return }
        $FirstDB = $Script:TargetMap[$checkedItems[0].Key].DB
        $availableJuris = Get-DBJurisIDs -DBName $FirstDB

        $inputJuris = Show-JurisSelector -T "Source JurisID" -P "Select or Enter JurisID for Backup (DB: $FirstDB):" -Options $availableJuris
        if ([string]::IsNullOrWhiteSpace($inputJuris) -or -not ($inputJuris -match '^\d+$')) { return }
        
        $fbd = New-Object System.Windows.Forms.FolderBrowserDialog; $fbd.SelectedPath = $Script:DefaultBackup
        if($fbd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){ return }
        
        Toggle $false; Log "▶ BACKING UP JURIS $inputJuris..."; $TS=Get-Date -Format "yyyyMMdd_HHmm"
        
        foreach ($item in $checkedItems) {
            $DB = $Script:TargetMap[$item.Key].DB; Log "  > Backing up Config for $DB..."; 
            $BackupLines = @("# ProPhoenix Database Configuration Backup", "# Database: $DB", "# Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", "")
            $CS="Server=$($Script:txtS.Text);Database=$DB;User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Connection Timeout=15"
            $CN=New-Object System.Data.SqlClient.SqlConnection($CS); $CN.Open(); $cmd = $CN.CreateCommand()
            $cmd.CommandText = "SET NOCOUNT ON; SELECT ParamID, CAST(ParamValue AS NVARCHAR(MAX)) AS ParamValue FROM Parameter WHERE ParamID IN ($($Script:TargetParams -join ',')) AND JurisID=$inputJuris"
            $reader = $cmd.ExecuteReader(); $BackupLines += "[PARAMETERS]"; $paramCount = 0; 
            while ($reader.Read()) { 
                $v1 = $reader.GetValue(1); $pVal = if ($v1 -is [System.DBNull] -or $null -eq $v1) { "" } else { $v1.ToString() }
                $BackupLines += "$($reader.GetValue(0))=$pVal"; $paramCount++ 
            }
            $reader.Close(); Log "   + Exported $paramCount Parameters"; $BackupLines += ""
            
            $cmd.CommandText = "SELECT JobID, JobName, JobType FROM KPIjobs WHERE JobName IN ('$($Script:TargetJobs -join "','")')"
            $jobReader = $cmd.ExecuteReader(); $tempJobs = @(); 
            while ($jobReader.Read()) { 
                $v1 = $jobReader.GetValue(1); $jName = if ($v1 -is [System.DBNull]) { "Unknown" } else { $v1.ToString() }
                $v2 = $jobReader.GetValue(2); $jType = if ($v2 -is [System.DBNull]) { "" } else { $v2.ToString() }
                $tempJobs += @{ ID = $jobReader.GetValue(0); Name = $jName; Type = $jType } 
            }
            $jobReader.Close()
            
            foreach ($job in $tempJobs) { 
                $BackupLines += "[JOB:$($job.Name)]"; if ($job.Type -ne "") { $BackupLines += "JobType=$($job.Type)" }
                $cmd.CommandText = "SELECT ParamName, ParamValue FROM KPIjobsparam WHERE JobID = $($job.ID)"; $pReader = $cmd.ExecuteReader(); 
                while ($pReader.Read()) { 
                    $v0 = $pReader.GetValue(0); $jpName = if ($v0 -is [System.DBNull]) { "" } else { $v0.ToString() }
                    $v1 = $pReader.GetValue(1); $jpVal = if ($v1 -is [System.DBNull]) { "" } else { $v1.ToString() }
                    $BackupLines += "Param:$jpName=$jpVal" 
                }
                $pReader.Close()
                $cmd.CommandText = "SELECT * FROM KPIJobsNotify WHERE JobID = $($job.ID)"; $nReader = $cmd.ExecuteReader(); 
                while ($nReader.Read()) { 
                    $v4 = $nReader.GetValue(4); if ($v4 -isnot [System.DBNull] -and $null -ne $v4) { $BackupLines += "NotifyPath=$($v4.ToString())" } 
                }
                $nReader.Close(); $BackupLines += "" 
            }
            Log "   + Exported $($tempJobs.Count) KPI Jobs"
            [IO.File]::WriteAllLines((Join-Path $fbd.SelectedPath "$($DB)_ConfigBackup_$TS.txt"), $BackupLines, [System.Text.Encoding]::UTF8)
            $CN.Close()
        }
        Log "✔ Backup Complete." "Cyan"
    } catch { Log "❌ Failed: $($_.Exception.Message)" "Red" } finally { Release-TaskLock; Toggle $true }
})

$Script:btnRestore.Add_Click({
    if (-not (Check-TaskLock "Restore Jobs & Params")) { return }
    try {
        $checkedItems = Get-CheckedDBs
        if($checkedItems.Count -eq 0){ return }
        $FirstDB = $Script:TargetMap[$checkedItems[0].Key].DB
        $availableJuris = Get-DBJurisIDs -DBName $FirstDB
        
        $inputJuris = Show-JurisSelector -T "Target JurisID" -P "Select or Enter Target JurisID (DB: $FirstDB):" -Options $availableJuris
        if ([string]::IsNullOrWhiteSpace($inputJuris) -or -not ($inputJuris -match '^\d+$')) { return }
        
        $f=New-Object System.Windows.Forms.OpenFileDialog; $f.Filter="Text Backup (*.txt)|*.txt"; $f.InitialDirectory=$Script:DefaultBackup
        if($f.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK){return}; $SourceFile=$f.FileName
        if([System.Windows.Forms.MessageBox]::Show("RESTORE to Juris $inputJuris?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning) -ne [System.Windows.Forms.DialogResult]::Yes){ return }
        
        Toggle $false; Log "▶ RESTORING TO JURIS $inputJuris..." "Orange"
        foreach ($item in $checkedItems) { 
            $DB=$Script:TargetMap[$item.Key].DB; Log "  > Target: $DB"; 
            Apply-EnterpriseConfig -TargetDB $DB -SourceFile $SourceFile -TargetJuris $inputJuris 
        }
        Log "✔ Restore Process Complete." "Cyan"
    } catch { Log "❌ Error: $($_.Exception.Message)" "Red" } finally { Release-TaskLock; Toggle $true }
})

$Script:btnSqlMem.Add_Click({
    if (-not (Check-TaskLock "SQL Memory Configuration")) { return }
    try {
        Toggle $false; Log "▶ INITIATING SQL MEMORY CONFIGURATION (75% RULE)" "Cyan"; Log "  Connecting to $($Script:txtS.Text)..." "Gray"
        DoEvents
        $MinMemoryMB = 1024
        $cs = "Server=$($Script:txtS.Text);User Id=$($Script:txtU.Text);Password=$($Script:txtP.Password);Database=master;Connection Timeout=15"
        $conn = New-Object System.Data.SqlClient.SqlConnection($cs); $conn.Open()

        $checkQuery = @"
        SELECT 
            (SELECT physical_memory_kb / 1024 FROM sys.dm_os_sys_info) AS TotalRAM_MB,
            (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'min server memory (MB)') AS CurrentMin,
            (SELECT CAST(value_in_use AS INT) FROM sys.configurations WHERE name = 'max server memory (MB)') AS CurrentMax
"@
        $cmd = $conn.CreateCommand(); $cmd.CommandText = $checkQuery
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($cmd); $dt = New-Object System.Data.DataTable; $adapter.Fill($dt) | Out-Null
        if ($dt.Rows.Count -eq 0) { throw "Could not read memory info from SQL." }

        $totalRamMB = [math]::Round($dt.Rows[0]["TotalRAM_MB"]); $currentMin = $dt.Rows[0]["CurrentMin"]; $currentMax = $dt.Rows[0]["CurrentMax"]
        $newMaxMB = [math]::Round($totalRamMB * 0.75); if ($newMaxMB -lt $MinMemoryMB) { $newMaxMB = $MinMemoryMB }

        Log "  [ANALYSIS] Total Server RAM : $totalRamMB MB" "White"
        Log "  [SETTING]  Min Memory (MB)  : $currentMin ➔ $MinMemoryMB" "Yellow"
        Log "  [SETTING]  Max Memory (MB)  : $currentMax ➔ $newMaxMB" "Yellow"

        if ($currentMin -eq $MinMemoryMB -and $currentMax -eq $newMaxMB) { Log "  ✔ SKIPPED: Memory values are already optimal." "Lime" }
        else {
            Log "  [ACTION]   Updating SQL Server Configuration..." "Cyan"; DoEvents
            $updateQuery = "EXEC sys.sp_configure N'show advanced options', N'1'; RECONFIGURE WITH OVERRIDE; EXEC sys.sp_configure N'min server memory (MB)', $MinMemoryMB; EXEC sys.sp_configure N'max server memory (MB)', $newMaxMB; RECONFIGURE WITH OVERRIDE;"
            $cmd.CommandText = $updateQuery; $cmd.ExecuteNonQuery() | Out-Null
            Log "  ✔ SUCCESS: Memory successfully clamped to 75% ($newMaxMB MB)." "Lime"
        }
        $conn.Close()
    } catch { Log "  ❌ [ERROR] Failed to configure SQL RAM: $($_.Exception.Message)" "Red" } finally { Release-TaskLock; Toggle $true }
})

function Show-NewDBDialog { $dbForm=New-Object System.Windows.Forms.Form;$dbForm.Text="Create DB";$dbForm.Size="400,380";$dbForm.StartPosition="CenterParent";$dbForm.BackColor=[System.Drawing.Color]::FromArgb(30,30,30);$dbForm.ForeColor=[System.Drawing.Color]::White;$lblC=New-Object System.Windows.Forms.Label;$lblC.Text="Category:";$lblC.Location="20,30";$dbForm.Controls.Add($lblC);$cmbCat=New-Object System.Windows.Forms.ComboBox;$cmbCat.Items.AddRange(@("Police","Fire","Phoenix Master","IA","Police CSP","Fire CSP"));$cmbCat.SelectedIndex=0;$cmbCat.Location="120,27";$cmbCat.Width=240;$dbForm.Controls.Add($cmbCat);function Add-Field($lbl,$y,$def){$l=New-Object System.Windows.Forms.Label;$l.Text=$lbl;$l.Location="20,$y";$dbForm.Controls.Add($l);$t=New-Object System.Windows.Forms.TextBox;$t.Text=$def;$t.Location="120,$($y-3)";$t.Width=240;$dbForm.Controls.Add($t);return $t};$inDB=Add-Field "Database" 70 "PhoenixPolice";$inJID=Add-Field "JurisID" 110 "1000";$inSt=Add-Field "State" 150 "MA";$inN=Add-Field "Name" 190 "ProPhoenix";$inA=Add-Field "Alias" 230 "PNX";$btn=New-Object System.Windows.Forms.Button;$btn.Text="CREATE";$btn.DialogResult=[System.Windows.Forms.DialogResult]::OK;$btn.Location="120,280";$btn.ForeColor=[System.Drawing.Color]::Black;$dbForm.Controls.Add($btn);$dbForm.AcceptButton=$btn;if($dbForm.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){return @{DB=$inDB.Text;JID=$inJID.Text;St=$inSt.Text;Nm=$inN.Text;Al=$inA.Text;Cat=$cmbCat.SelectedItem}} return $null }

# ======================================================================
#  APPLICATION STARTUP SEQUENCE
# ======================================================================

# 1. Load credentials into global memory
Load-Creds | Out-Null

# 2. Block the dashboard completely; force the Connect screen to resolve
$loginSuccess = Show-LoginScreen

# 3. If the user closes the Connect screen without connecting, terminate
if (-not $loginSuccess) {
    exit
}

# 4. If connected successfully, load the dashboard components and sync
$Script:form.Add_Loaded({
    Load-Image -Element $Script:imgSmallLogo -Path $Script:LogoFile
    Load-Image -Element $Script:imgBgLogo -Path $Script:BgImage
    Log "Dashboard UI loaded successfully." "Lime"

    # Force a connection execution on load
    [System.Windows.Forms.Application]::DoEvents()
    
    # Safely trigger Connect depending on WPF vs WinForms backend
    try {
        $Script:btnCon.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    } catch {
        $Script:btnCon.PerformClick()
    }
})

# Display the main dashboard
[void]$Script:form.ShowDialog()