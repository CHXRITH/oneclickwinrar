# oneclickrar.ps1
# Dark-mode modern minimal GUI installer for WinRAR
# Usage: .\oneclickrar.ps1
# Made with ♥ by Charith Pramodya Senanayake
# Consolidated and fixed by AI

Set-StrictMode -Version Latest
[void][System.Reflection.Assembly]::LoadWithPartialName("PresentationFramework")
[void][System.Reflection.Assembly]::LoadWithPartialName("WindowsBase")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Xaml")
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

# -------------------------------
# Configuration / Defaults
# -------------------------------
$SCRIPT_VERSION = "0.7.0.701"
$DEFAULT_ARCH = "x64"
$DEFAULT_VER = "701"
$WINRAR_BASE_URL = "https://www.win-rar.com/fileadmin/winrar-versions"
$LOCAL_TMP = [System.IO.Path]::GetTempPath().TrimEnd('\')
$global:WORKING = $false

# Default rarreg content
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

# -------------------------------
# Helper functions
# -------------------------------
function Elevate-IfNeeded {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        } catch {
            [System.Windows.MessageBox]::Show("This installer requires administrator privileges.`nPlease re-run as Administrator.","Elevation required",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) > $null
        }
        Exit
    }
}

function Test-InternetConnection {
    try {
        $response = Invoke-WebRequest -Uri "http://www.google.com" -UseBasicParsing -TimeoutSec 5
        return $true
    } catch {
        return $false
    }
}

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
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText04)
    $RawXml = [xml] $Template.GetXml(); ($RawXml.toast.visual.binding.text | Where-Object { $_.id -eq "1" }).AppendChild($RawXml.CreateTextNode($ToastTitle)) | Out-Null; ($RawXml.toast.visual.binding.text | Where-Object { $_.id -eq "2" }).AppendChild($RawXml.CreateTextNode($ToastText)) | Out-Null; ($RawXml.toast.visual.binding.text | Where-Object { $_.id -eq "3" }).AppendChild($RawXml.CreateTextNode($ToastText2)) | Out-Null
    $XmlDocument = New-Object Windows.Data.Xml.Dom.XmlDocument; $XmlDocument.LoadXml($RawXml.OuterXml)
    if ($ActionButtonUrl) { $actionsElement = $XmlDocument.CreateElement("actions"); $actionElement = $XmlDocument.CreateElement("action"); $actionElement.SetAttribute("content", $ActionButtonText); $actionElement.SetAttribute("activationType", "protocol"); $actionElement.SetAttribute("arguments", $ActionButtonUrl); $actionsElement.AppendChild($actionElement) | Out-Null; $XmlDocument.DocumentElement.AppendChild($actionsElement) | Out-Null }
    if ($LongerDuration) { $XmlDocument.DocumentElement.SetAttribute("duration", "long") }
    $Toast = [Windows.UI.Notifications.ToastNotification]::new($XmlDocument); $Toast.Tag = "PowerShell"; $Toast.Group = "PowerShell"
    if (-not $LongerDuration) { $Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(1) }
    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId); $Notifier.Show($Toast)
}

function Get-WinRARData {
    param($scriptPath)
    # ... (same as previous)
    $script_name = "oneclickrar"
    $script_name_overwrite = "oneclick-rar"
    $LATEST = 701
    $cmdName = Split-Path $scriptPath -Leaf
    $data = [PSCustomObject]@{
        OVERWRITE_LICENSE = $false
        CUSTOM_DOWNLOAD = $false
        CUSTOM_LICENSE = $false
        ARCH = $DEFAULT_ARCH
        RARVER = $LATEST
        LICENSEE = $null
        LICENSE_TYPE = $null
    }
    $matches = [regex]::Matches($cmdName, '[^_]+')
    
    if ($matches.Count -eq 0) {
        return $data
    }
    
    $parts = $matches | Select-Object -ExpandProperty Value
    $scriptNamePart = $parts[-1].Split('.')[0]
    
    if ($scriptNamePart -eq $script_name_overwrite) {
        $data.OVERWRITE_LICENSE = $true
    }
    elseif ($scriptNamePart -ne $script_name) {
        return $null # Invalid script name
    }
    
    $partsWithoutScriptName = $parts | Where-Object { $_ -ne $scriptNamePart }
    if ($partsWithoutScriptName.Count -gt 0) {
        # Check for download config at the end
        if ($partsWithoutScriptName.Count -ge 2 -and ($partsWithoutScriptName[-2] -match 'x\d{2}')) {
            $data.CUSTOM_DOWNLOAD = $true
            $data.ARCH = $partsWithoutScriptName[-2]
            $data.RARVER = $partsWithoutScriptName[-1].Split('.')[0]
            $partsWithoutScriptName = $partsWithoutScriptName | Select-Object -SkipLast 2
        }
        
        # Check for license config at the start
        if ($partsWithoutScriptName.Count -ge 2) {
            $data.CUSTOM_LICENSE = $true
            $data.LICENSEE = $partsWithoutScriptName[0]
            $data.LICENSE_TYPE = $partsWithoutScriptName[1]
        }
    }
    
    # Final validation
    if ($data.CUSTOM_DOWNLOAD) {
        if ($data.ARCH -ne "x64" -and $data.ARCH -ne "x32") { return $null }
        if ($data.RARVER.Length -ne 3) { return $null }
    }
    
    return $data
}
#endregion

# -------------------------------
# WPF UI (dark minimal)
# -------------------------------
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="oneclickrar" Height="300" Width="500"
        WindowStartupLocation="CenterScreen"
        Background="#1E1E1E" Foreground="White"
        FontFamily="Segoe UI" ResizeMode="NoResize" WindowStyle="None">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <TextBlock Text="WinRAR One-Click Installer" FontSize="20" FontWeight="Bold" 
                   Grid.Row="0" HorizontalAlignment="Center" Margin="0,0,0,10"/>

        <StackPanel Grid.Row="1" VerticalAlignment="Center">
            <ProgressBar x:Name="MainProgress" Height="20" Width="400" Value="0"
                         Background="#2E2E2E" Foreground="#0DB7ED" BorderBrush="#2E2E2E"/>
            <TextBlock x:Name="PercentText" Text="0%" FontSize="14" 
                       HorizontalAlignment="Center" Margin="0,8,0,0"/>
            <TextBlock x:Name="StatusText" Text="Waiting to start..." FontSize="12" 
                       Opacity="0.8" HorizontalAlignment="Center" Margin="0,4,0,0"/>
            <TextBlock x:Name="DetailText" Text="" FontSize="10" 
                       Opacity="0.6" HorizontalAlignment="Center" Margin="0,4,0,0"/>
        </StackPanel>

        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10,0,0" Grid.Row="2">
            <Button x:Name="InstallBtn" Content="Install" Width="100" Margin="5"
                    Background="#0DB7ED" Foreground="White" BorderBrush="#0DB7ED"
                    FontWeight="Bold"/>
            <Button x:Name="CancelBtn" Content="Cancel" Width="100" Margin="5"
                    Background="#555" Foreground="White" BorderBrush="#555"/>
        </StackPanel>

        <TextBlock Text="Made with ♥ by Charith Pramodya Senanayake" 
                   FontSize="10" Opacity="0.6" HorizontalAlignment="Center" 
                   Grid.Row="3" Margin="0,10,0,0"/>
    </Grid>
</Window>
"@

# Load XAML
$reader = [System.Xml.XmlReader]::Create((New-Object System.IO.StringReader $xaml))
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$MainProgress = $Window.FindName("MainProgress")
$PercentText  = $Window.FindName("PercentText")
$StatusText   = $Window.FindName("StatusText")
$DetailText   = $Window.FindName("DetailText")
$InstallBtn   = $Window.FindName("InstallBtn")
$CancelBtn    = $Window.FindName("CancelBtn")

function Set-UI {
    param($status, $detail, $progress, $percent)
    $Window.Dispatcher.Invoke([action]{
        if ($progress -ne $null) { $MainProgress.Value = $progress }
        if ($percent -ne $null)  { $PercentText.Text = "$percent%" }
        if ($status -ne $null)   { $StatusText.Text = $status }
        if ($detail -ne $null)   { $DetailText.Text = $detail }
    })
}

# -------------------------------
# Core install workflow (runs in background runspace)
# -------------------------------
$worker = {
    param($workerData)
    
    # Extract data from the PSCustomObject
    $arch = $workerData.ARCH
    $ver = $workerData.RARVER
    $WINRAR_BASE_URL = $workerData.WINRAR_BASE_URL
    $LOCAL_TMP = $workerData.LOCAL_TMP
    $rarkey = $workerData.rarkey
    $licensee = $workerData.LICENSEE
    $licenseType = $workerData.LICENSE_TYPE
    $customLicense = $workerData.CUSTOM_LICENSE
    $customDownload = $workerData.CUSTOM_DOWNLOAD
    $overwriteLicense = $workerData.OVERWRITE_LICENSE
    $scriptRoot = $workerData.PSScriptRoot
    
    # Re-define helper functions needed in this runspace
    function Test-InternetConnection {
        try { $null = Invoke-WebRequest -Uri "http://www.google.com" -UseBasicParsing -TimeoutSec 5; return $true } catch { return $false }
    }
    function Compose-InstallerUrl {
        param($arch, $ver)
        $name = "winrar-$arch-$ver.exe"
        return "$WINRAR_BASE_URL/$name"
    }
    function Write-RarReg {
        param($dest, $key)
        [IO.File]::WriteAllText($dest, $key, [System.Text.Encoding]::UTF8)
    }

    $progressCallback = $workerData.progressCallback
    $completionCallback = $workerData.completionCallback
    $cancelFlag = $workerData.cancelFlag
    
    # Helper to update UI from this thread
    $UpdateUI = {
        param($status, $detail, $progress, $percent)
        $progressCallback.DynamicInvoke($status, $detail, $progress, $percent)
    }

    $INSTALLER_FILE = ""
    $winrar64 = "$env:ProgramFiles\WinRAR\WinRAR.exe"
    $winrar32 = "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe"
    $rarreg64 = "$env:ProgramFiles\WinRAR\rarreg.key"
    $rarreg32 = "${env:ProgramFiles(x86)}\WinRAR\rarreg.key"
    $keygen64 = (Join-Path $scriptRoot "bin\winrar-keygen\winrar-keygen-x64.exe")
    $keygen32 = (Join-Path $scriptRoot "bin\winrar-keygen\winrar-keygen-x86.exe")

    try {
        $UpdateUI.Invoke("Checking current WinRAR status...", "", 0, 0)
        $isInstalled = (Test-Path $winrar64 -PathType Leaf) -or (Test-Path $winrar32 -PathType Leaf)
        $isLicensed = (Test-Path $rarreg64 -PathType Leaf) -or (Test-Path $rarreg32 -PathType Leaf)

        if ($isInstalled -and $isLicensed -and -not $overwriteLicense) {
            $UpdateUI.Invoke("WinRAR is already installed.", "No action needed.", 100, 100)
            Start-Sleep -Seconds 2
            $completionCallback.DynamicInvoke("success", "no-action")
            return
        }

        $UpdateUI.Invoke("Checking internet connection...", "", 0, 0)
        if (-not (Test-InternetConnection)) {
            $UpdateUI.Invoke("No internet connection ❌", "Please check your network and try again.", 0, 0)
            Start-Sleep -Seconds 3
            $completionCallback.DynamicInvoke("error")
            return
        }
        
        # INSTALLATION LOGIC
        if (-not $isInstalled) {
            $UpdateUI.Invoke("Looking for installer...", "", 5, 5)
            
            $local = Get-ChildItem -Path $scriptRoot | Where-Object { $_.Name -match '^winrar-x' }
            if ($local.Count -gt 0 -and -not $customDownload) {
                $INSTALLER_FILE = ($local | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
                $UpdateUI.Invoke("Found local installer", (Split-Path $INSTALLER_FILE -Leaf), 10, 10)
            } else {
                $archToDownload = if ($customDownload) { $arch } else { "x64" }
                $verToDownload = if ($customDownload) { $ver } else { $DEFAULT_VER }
                $url = Compose-InstallerUrl -arch $archToDownload -ver $verToDownload
                $name = "winrar-$archToDownload-$verToDownload.exe"
                $dest = Join-Path $LOCAL_TMP $name
                $UpdateUI.Invoke("Downloading WinRAR...", $name, 10, 10)
                
                $wc = New-Object System.Net.WebClient
                $lastReceived = 0; $lastTime = [DateTime]::UtcNow
                $wc.DownloadProgressChanged += {
                    param($s,$e)
                    $pct = [math]::Round($e.ProgressPercentage,0)
                    $kb = [math]::Round($e.BytesReceived/1024,1)
                    $totalkb = if ($e.TotalBytesToReceive -gt 0) { [math]::Round($e.TotalBytesToReceive/1024,1) } else { 0 }
                    $now = [DateTime]::UtcNow; $dt = ($now - $lastTime).TotalSeconds
                    $speed = 0
                    if ($dt -gt 0) { $speed = ($e.BytesReceived - $lastReceived)/$dt; $lastReceived = $e.BytesReceived; $lastTime = $now }
                    $speedStr = if ($speed -gt 1024*1024) { "{0:N1} MB/s" -f ($speed/1024/1024) } elseif ($speed -gt 1024) { "{0:N1} KB/s" -f ($speed/1024) } else { "0 KB/s" }
                    $UpdateUI.Invoke("Downloading WinRAR...", ("{0} KB / {1} KB — {2}" -f $kb, $totalkb, $speedStr), $pct, $pct)
                    if ($cancelFlag.Value) { $wc.CancelAsync() }
                }

                $INSTALLER_FILE = $dest; $wc.DownloadFileAsync([uri]$url, $dest)
                while ($wc.IsBusy) { Start-Sleep -Milliseconds 200; if ($cancelFlag.Value) { $wc.CancelAsync(); break } }
                $wc.Dispose()
                if ($cancelFlag.Value -or -not (Test-Path $INSTALLER_FILE)) { throw "Download cancelled or failed." }
            }
            
            $UpdateUI.Invoke("Installing WinRAR...", "Running silent installer", 55, 55)
            $p = Start-Process -FilePath $INSTALLER_FILE -ArgumentList "/S" -Wait -PassThru
            
            if ($p.ExitCode -ne 0) { throw "Installer returned non-zero exit code." }
            Start-Sleep -Seconds 2
            if (-not ((Test-Path $winrar64 -PathType Leaf) -or (Test-Path $winrar32 -PathType Leaf))) { throw "WinRAR executable not found after installation." }
        } else {
            $UpdateUI.Invoke("WinRAR is already installed.", "Skipping installation.", 55, 55)
        }
        
        if ($cancelFlag.Value) { throw "Installation cancelled." }

        # LICENSING LOGIC
        if (-not $isLicensed -or $overwriteLicense) {
            $UpdateUI.Invoke("Applying license...", "", 80, 80)
            $rarreg = if (Test-Path $winrar64) { $rarreg64 } else { $rarreg32 }
            if (-not $rarreg) { throw "WinRAR executable not found after installation." }

            if ($customLicense) {
                if (Test-Path $keygen64 -PathType Leaf -or Test-Path $keygen32 -PathType Leaf) {
                    $keygen = if (Test-Path $winrar64) { $keygen64 } else { $keygen32 }
                    & $keygen $licensee $licenseType | Out-File -Encoding utf8 $rarreg
                } else {
                    throw "Missing keygen file for custom license. Place it in the 'bin' folder."
                }
            } elseif (Test-Path (Join-Path $scriptRoot "rarreg.key") -PathType Leaf) {
                Copy-Item -Path (Join-Path $scriptRoot "rarreg.key") -Destination $rarreg -Force
            } else {
                Write-RarReg -dest $rarreg -key $rarkey
            }
            $UpdateUI.Invoke("License applied", "", 100, 100)
        } else {
            $UpdateUI.Invoke("WinRAR is already licensed.", "Skipping license step.", 100, 100)
        }
    } catch {
        $msg = if ($_.Exception.Message) { $_.Exception.Message } else { $_.ToString() }
        $UpdateUI.Invoke("Error", $msg, 0, 0)
        Start-Sleep -Seconds 5
        $completionCallback.DynamicInvoke("error", $msg)
        return
    }
    $completionCallback.DynamicInvoke("success", "")
}

# -------------------------------
# Button actions and main logic
# -------------------------------
$ps = $null
$asyncResult = $null
$cancelFlag = [System.Threading.Tasks.Shared.AsyncBoolean]::new()

$Window.Add_Closing({
    if ($global:WORKING) {
        $cancelFlag.Value = $true
    }
    if ($ps) {
        $ps.Stop()
        $ps.Dispose()
    }
})

$InstallBtn.Add_Click({
    if ($global:WORKING) { return }
    $global:WORKING = $true
    
    $InstallBtn.IsEnabled = $false
    $CancelBtn.IsEnabled = $true
    
    Elevate-IfNeeded
    
    $installData = Get-WinRARData -scriptPath $PSCommandPath
    if (-not $installData) {
        $global:WORKING = $false
        [System.Windows.MessageBox]::Show("Invalid script name for custom configuration. Check the documentation for naming conventions.","Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) > $null
        $Window.Close()
        return
    }

    $progressCallback = [Action[string,string,int,int]]{
        param($status, $detail, $progress, $percent)
        $Window.Dispatcher.Invoke([Action]{
            if ($progress -ne $null) { $MainProgress.Value = $progress }
            if ($percent -ne $null)  { $PercentText.Text = "$percent%" }
            if ($status -ne $null)   { $StatusText.Text = $status }
            if ($detail -ne $null)   { $DetailText.Text = $detail }
        })
    }
    
    $completionCallback = [Action[string,string]]{
        param($status, $errorMsg)
        $Window.Dispatcher.Invoke([Action]{
            $global:WORKING = $false
            $InstallBtn.IsEnabled = $true
            $CancelBtn.IsEnabled = $false
            
            if ($status -eq "success") {
                if ($errorMsg -ne "no-action") {
                    New-Toast -ToastTitle "WinRAR Setup Complete" -ToastText "WinRAR is now installed and licensed." -ToastText2 "Enjoy using WinRAR!"
                } else {
                    New-Toast -ToastTitle "WinRAR Status" -ToastText "WinRAR is already installed and licensed." -ToastText2 "No action needed."
                }
                
                New-Toast -ToastTitle "Join Our Community!" -ToastText "Stay updated with Tech Articles" -ToastText2 "Join us on Telegram" -ActionButtonUrl "https://t.me/blogbychxrith" -LongerDuration
            } else {
                [System.Windows.MessageBox]::Show("Installation failed: $errorMsg","Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error) > $null
            }
            $Window.Close()
        })
    }
    
    $installData.Add("progressCallback", $progressCallback)
    $installData.Add("completionCallback", $completionCallback)
    $installData.Add("cancelFlag", $cancelFlag)
    $installData.Add("PSScriptRoot", $PSScriptRoot)
    $installData.Add("WINRAR_BASE_URL", $WINRAR_BASE_URL)
    $installData.Add("LOCAL_TMP", $LOCAL_TMP)
    $installData.Add("rarkey", $rarkey)

    $runspace = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $runspace.Open()

    $ps = [powershell]::Create().AddScript($worker).AddArgument($installData)
    $ps.Runspace = $runspace
    $asyncResult = $ps.BeginInvoke()
})

$CancelBtn.Add_Click({
    if ($global:WORKING) {
        $cancelFlag.Value = $true
        Set-UI -status "Cancelling..." -detail ""
        $InstallBtn.IsEnabled = $false
        $CancelBtn.IsEnabled = $false
    }
})

# Handle the case where $PSScriptRoot is not set
if (-not $PSScriptRoot) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Variable -Name "PSScriptRoot" -Value $scriptDir -Scope Global
}

Elevate-IfNeeded
$CancelBtn.IsEnabled = $false
$Window.ShowDialog() | Out-Null
