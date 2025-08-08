# oneclickrar.ps1
# A script to install and license WinRAR with a simple GUI suitable for irm|iex
# Made with ♥ by Charith Pramodya Senanayake
# Rewritten by AI for irm|iex compatibility

<#
    .SYNOPSIS
    Downloads, installs, and licenses WinRAR with a minimal graphical interface.
    This script is designed for execution via a one-liner like: irm <URL> | iex
#>

#region GUI Setup
# Create a minimal WPF window for progress updates
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
[void][System.Reflection.Assembly]::LoadWithPartialName('PresentationFramework')
[void][System.Reflection.Assembly]::LoadWithPartialName('WindowsBase')
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Xaml')

$script:winRARUI = [System.Windows.Window]::new()
$script:winRARUI.Title = "WinRAR One-Click Installer"
$script:winRARUI.Height = 150
$script:winRARUI.Width = 400
$script:winRARUI.WindowStartupLocation = 'CenterScreen'
$script:winRARUI.ResizeMode = 'NoResize'
$script:winRARUI.WindowStyle = 'None'
$script:winRARUI.AllowsTransparency = $true
$script:winRARUI.Background = [System.Windows.Media.Brushes]::Transparent

$grid = [System.Windows.Controls.Grid]::new()
$grid.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(255, 30, 30, 30))
$grid.Margin = [System.Windows.Thickness]::new(10)
$grid.CornerRadius = [System.Windows.CornerRadius]::new(8)

$stackPanel = [System.Windows.Controls.StackPanel]::new()
$stackPanel.Margin = [System.Windows.Thickness]::new(10)

$script:statusText = [System.Windows.Controls.TextBlock]::new()
$script:statusText.Text = "Initializing..."
$script:statusText.FontSize = 14
$script:statusText.Foreground = [System.Windows.Media.Brushes]::White
$script:statusText.HorizontalAlignment = 'Center'
$stackPanel.Children.Add($script:statusText)

$script:detailText = [System.Windows.Controls.TextBlock]::new()
$script:detailText.Text = ""
$script:detailText.FontSize = 12
$script:detailText.Opacity = 0.7
$script:detailText.Foreground = [System.Windows.Media.Brushes]::White
$script:detailText.HorizontalAlignment = 'Center'
$stackPanel.Children.Add($script:detailText)

$script:progressBar = [System.Windows.Controls.ProgressBar]::new()
$script:progressBar.Height = 10
$script:progressBar.Margin = [System.Windows.Thickness]::new(0, 10, 0, 0)
$script:progressBar.Foreground = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(255, 13, 183, 237))
$script:progressBar.Background = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.Color]::FromArgb(255, 46, 46, 46))
$script:progressBar.BorderBrush = [System.Windows.Media.Brushes]::Transparent
$stackPanel.Children.Add($script:progressBar)

$grid.Content = $stackPanel
$script:winRARUI.Content = $grid

# Dispatcher to update UI from a different thread if needed, or simply from the main thread
function Update-UI {
    param ($Status, $Detail = "", $Progress = -1)
    [System.Windows.Application]::Current.Dispatcher.Invoke([Action]{
        if ($null -ne $Status) { $script:statusText.Text = $Status }
        if ($null -ne $Detail) { $script:detailText.Text = $Detail }
        if ($Progress -ne -1)  { $script:progressBar.Value = $Progress }
    })
}

# The installer will run in a separate runspace so the UI thread doesn't freeze
$script:ps = [PowerShell]::Create().AddScript({
    # The actual installation logic goes here
    param($UIUpdateCallback, $UILogger)

    # region UI_PROXIES
    # These functions allow the child runspace to communicate back to the main UI thread
    function Update-Gui {
        param ($Status, $Detail = "", $Progress = -1)
        $UIUpdateCallback.DynamicInvoke($Status, $Detail, $Progress)
    }

    function Log-Message {
        param($Message)
        $UILogger.DynamicInvoke($Message)
    }
    #endregion

    #region UTILITY_FUNCTIONS
    function New-Toast {
        param (
            [String]$AppId = "oneclickwinrar",
            [String]$ToastTitle,
            [String]$ToastText,
            [String]$ToastText2,
            [String]$ActionButtonUrl,
            [String]$ActionButtonText = "Join Now",
            [switch]$LongerDuration
        )
        try {
            [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
            $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText04)
            $RawXml = [xml] $Template.GetXml()
            ($RawXml.toast.visual.binding.text | Where-Object { $_.id -eq "1" }).AppendChild($RawXml.CreateTextNode($ToastTitle)) | Out-Null
            ($RawXml.toast.visual.binding.text | Where-Object { $_.id -eq "2" }).AppendChild($RawXml.CreateTextNode($ToastText)) | Out-Null
            ($RawXml.toast.visual.binding.text | Where-Object { $_.id -eq "3" }).AppendChild($RawXml.CreateTextNode($ToastText2)) | Out-Null
            $XmlDocument = New-Object Windows.Data.Xml.Dom.XmlDocument
            $XmlDocument.LoadXml($RawXml.OuterXml)
            if ($ActionButtonUrl) {
                $actionsElement = $XmlDocument.CreateElement("actions")
                $actionElement = $XmlDocument.CreateElement("action")
                $actionElement.SetAttribute("content", $ActionButtonText)
                $actionElement.SetAttribute("activationType", "protocol")
                $actionElement.SetAttribute("arguments", $ActionButtonUrl)
                $actionsElement.AppendChild($actionElement) | Out-Null
                $XmlDocument.DocumentElement.AppendChild($actionsElement) | Out-Null
            }
            if ($LongerDuration) {
                $XmlDocument.DocumentElement.SetAttribute("duration", "long")
            }
            $Toast = [Windows.UI.Notifications.ToastNotification]::new($XmlDocument)
            $Toast.Tag = "PowerShell"
            $Toast.Group = "PowerShell"
            if (-not $LongerDuration) {
                $Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(1)
            }
            $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId)
            $Notifier.Show($Toast)
        } catch {
            Log-Message "Failed to show toast notification: $($_.Exception.Message)"
        }
    }

    function Test-InternetConnection {
        try {
            $response = Invoke-WebRequest -Uri "http://www.google.com" -UseBasicParsing -TimeoutSec 5
            return $true
        }
        catch {
            return $false
        }
    }

    function Test-WinRAR {
        return (Test-Path "$env:ProgramFiles\WinRAR\WinRAR.exe" -PathType Leaf) -or (Test-Path "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe" -PathType Leaf)
    }

    function Test-WinRARLicense {
        return (Test-Path "$env:ProgramFiles\WinRAR\rarreg.key" -PathType Leaf) -or (Test-Path "${env:ProgramFiles(x86)}\WinRAR\rarreg.key" -PathType Leaf)
    }
    #endregion

    #region INSTALLATION_LOGIC
    $rarkey = @"
RAR registration data
Everyone
General Public License
UID=119fdd47b4dbe9a41555
6412212250155514920287d3b1cc8d9e41dfd22b78aaace2ba4386
9152c1ac6639addbb73c60800b745269020dd21becbc46390d7cee
cce48183d6d73d5e42e4605ab530f6edf8629596821ca042db83dd
68035141fb21e5da4dcaf7bf57494e5455608abc8a9916ffd8e23d
0a68ab79088aa7d5d5c2a0add4c9b3c27255740277f6edf8629596
821ca04340a7c91e88b14ba087e0bfb04b57824193d842e660c419
b8af4562cb13609a2ca469bf36fb8da2eda6f5e978bf1205660302
"@
    
    try {
        Update-Gui -Status "Checking status..." -Progress 0
        $isInstalled = Test-WinRAR
        $isLicensed = Test-WinRARLicense

        if ($isInstalled -and $isLicensed) {
            Update-Gui -Status "WinRAR is already installed and licensed." -Progress 100
            New-Toast -ToastTitle "WinRAR Status" -ToastText "WinRAR is already installed and licensed." -ToastText2 "No action needed."
            Start-Sleep -Seconds 2
            return
        }

        Update-Gui -Status "Checking internet connection..." -Progress 10
        if (-not (Test-InternetConnection)) {
            throw "No Internet Connection"
        }

        Update-Gui -Status "Downloading WinRAR..." -Progress 20
        $winrarUrl = "https://www.win-rar.com/fileadmin/winrar-versions/winrar-x64-701.exe"
        $downloadPath = "$env:TEMP\winrar-installer.exe"
        Invoke-WebRequest -Uri $winrarUrl -OutFile $downloadPath -TimeoutSec 300
        Update-Gui -Status "Download complete." -Progress 50

        Update-Gui -Status "Installing WinRAR..." -Progress 60
        Start-Process -FilePath $downloadPath -ArgumentList "/S" -Wait -PassThru
        Start-Sleep -Seconds 5
        Update-Gui -Status "Installation complete." -Progress 80
        
        Update-Gui -Status "Applying license..." -Progress 90
        $rarregPath = if (Test-Path "$env:ProgramFiles\WinRAR") { "$env:ProgramFiles\WinRAR\rarreg.key" } else { "${env:ProgramFiles(x86)}\WinRAR\rarreg.key" }
        [IO.File]::WriteAllText($rarregPath, $rarkey, [System.Text.Encoding]::UTF8)
        Update-Gui -Status "License applied." -Progress 95

        Update-Gui -Status "Installation complete!" -Progress 100
        New-Toast -ToastTitle "WinRAR Setup Complete" -ToastText "WinRAR is now installed and licensed." -ToastText2 "Enjoy using WinRAR!"
        
        Start-Sleep -Seconds 2
        
    } catch {
        Update-Gui -Status "Error occurred!" -Detail $_.Exception.Message -Progress 0
        New-Toast -ToastTitle "Installation Error" -ToastText "Failed to install WinRAR." -ToastText2 "Error: $($_.Exception.Message)"
        Start-Sleep -Seconds 5
    } finally {
        # Clean up
        if (Test-Path "$env:TEMP\winrar-installer.exe") {
            Remove-Item "$env:TEMP\winrar-installer.exe" -Force -ErrorAction SilentlyContinue
        }
        # Close the UI when done
        [System.Windows.Application]::Current.Shutdown()
    }
})

# Create a runspace for the installer logic to prevent the UI from freezing
$runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
$runspace.Open()
$script:ps.Runspace = $runspace

# Pass a callback function from the main thread to the installer runspace to update the UI
$uiCallback = [Action[string, string, int]]{ param($status, $detail, $progress) { Update-UI $status $detail $progress } }
$logCallback = [Action[string]]{ param($message) { Write-Host $message } }
$script:ps.AddArgument($uiCallback).AddArgument($logCallback)

# Start the installer asynchronously
$asyncResult = $script:ps.BeginInvoke()

# The main UI loop
$app = [System.Windows.Application]::new()
$app.ShutdownMode = 'OnLastWindowClose'
$app.Run($script:winRARUI)

# Clean up the runspace after the UI is closed
$script:ps.EndInvoke($asyncResult) | Out-Null
$script:ps.Dispose()
$runspace.Close()
$runspace.Dispose()
