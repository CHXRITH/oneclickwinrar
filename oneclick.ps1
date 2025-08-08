# oneclickrar.ps1
# Dark-mode modern minimal GUI installer for WinRAR
# Usage: irm https://your-url/oneclickrar.ps1 | iex
# Made with ♥ by Charith Pramodya Senanayake

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
$INSTALLER_FILE = ""
$FETCHED = $false
$WORKING = $false

# Default rarreg content (your original default)
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
    # If not elevated, re-launch as admin (preserve args)
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        if ($args) { $argList += " " + ($args -join " ") }
        $psi.Arguments = $argList
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        } catch {
            [System.Windows.MessageBox]::Show("This installer requires administrator privileges.`nPlease re-run as Administrator.","Elevation required",[System.Windows.MessageBoxButton]::OK,[System.Windows.MessageBoxImage]::Warning) > $null
        }
        Exit
    }
}

function Test-Internet {
    try {
        $req = [System.Net.WebRequest]::Create("https://www.google.com")
        $req.Timeout = 5000
        $resp = $req.GetResponse()
        $resp.Close()
        return $true
    } catch { return $false }
}

function Get-LocalInstaller {
    # Look for winrar-x* in current working directory first
    $files = Get-ChildItem -Path (Get-Location) -Filter "winrar-*.exe" -ErrorAction SilentlyContinue
    if ($files) {
        $f = $files | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        return $f.FullName
    }
    return $null
}

function Compose-InstallerUrl {
    param($arch = $DEFAULT_ARCH, $ver = $DEFAULT_VER)
    $name = "winrar-$arch-$ver.exe"
    return "$WINRAR_BASE_URL/$name", $name
}

function Write-RarReg {
    param($dest)
    [IO.File]::WriteAllText($dest, $rarkey, [System.Text.Encoding]::UTF8)
}

# -------------------------------
# WPF UI (dark minimal)
# -------------------------------
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="oneclickrar" Height="260" Width="520" WindowStartupLocation="CenterScreen"
        ResizeMode="NoResize" WindowStyle="None" Background="#1E1E1E" >
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="62" />
            <RowDefinition Height="120" />
            <RowDefinition Height="50" />
            <RowDefinition Height="28" />
        </Grid.RowDefinitions>

        <!-- Header -->
        <StackPanel Orientation="Horizontal" Margin="18,12,18,6" Grid.Row="0">
            <Border Width="44" Height="44" CornerRadius="8" Background="#0DB7ED" VerticalAlignment="Center">
                <TextBlock Text="R" FontFamily="Segoe UI" FontWeight="Bold" FontSize="22" Foreground="White" HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <StackPanel Margin="12,0,0,0" VerticalAlignment="Center">
                <TextBlock x:Name="TitleText" Text="oneclickrar" Foreground="White" FontSize="16" FontFamily="Segoe UI Semibold"/>
                <TextBlock x:Name="SubText" Text="v$($SCRIPT_VERSION) — Dark minimal installer" Foreground="#B3B3B3" FontSize="11" Margin="0,2,0,0"/>
            </StackPanel>
            <!-- Close button -->
            <Button x:Name="CloseBtn" Width="30" Height="30" HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,0,4,0" Background="Transparent" BorderBrush="{x:Null}" Foreground="#B3B3B3" HorizontalContentAlignment="Center">
                <TextBlock Text="✕" FontSize="14"/>
            </Button>
        </StackPanel>

        <!-- Main content -->
        <StackPanel Grid.Row="1" Margin="18,0,18,0" VerticalAlignment="Center">
            <TextBlock x:Name="StatusText" Text="Ready to install WinRAR" Foreground="#E6E6E6" FontSize="13" Margin="0,4,0,8"/>
            <ProgressBar x:Name="MainProgress" Height="18" Minimum="0" Maximum="100" Value="0" />
            <StackPanel Orientation="Horizontal" Margin="0,8,0,0" HorizontalAlignment="Stretch" >
                <TextBlock x:Name="PercentText" Text="0%" Foreground="#B3B3B3" Width="50"/>
                <TextBlock x:Name="DetailText" Text="" Foreground="#9A9A9A" FontSize="11" VerticalAlignment="Center"/>
            </StackPanel>
        </StackPanel>

        <!-- Buttons -->
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Grid.Row="2" Margin="18,8,18,8">
            <Button x:Name="CancelBtn" Width="90" Height="32" Margin="0,0,8,0" Background="#2A2A2A" Foreground="#E6E6E6">Cancel</Button>
            <Button x:Name="InstallBtn" Width="120" Height="32" Background="#0DB7ED" Foreground="#0F1A1E">Install Now</Button>
        </StackPanel>

        <!-- Footer -->
        <TextBlock Grid.Row="3" Text="Made with ♥ by Charith Pramodya Senanayake" Foreground="#6F6F6F" FontSize="11" HorizontalAlignment="Center" VerticalAlignment="Center"/>
    </Grid>
</Window>
"@

# Parse XAML
$mgr = New-Object System.Xml.XmlDocument
$mgr.LoadXml($xaml)
$reader = (New-Object System.Xml.XmlNodeReader $mgr)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Controls
$StatusText = $window.FindName("StatusText")
$MainProgress = $window.FindName("MainProgress")
$PercentText = $window.FindName("PercentText")
$DetailText = $window.FindName("DetailText")
$InstallBtn = $window.FindName("InstallBtn")
$CancelBtn = $window.FindName("CancelBtn")
$CloseBtn = $window.FindName("CloseBtn")
$Window = $window

# Close behavior
$CloseBtn.Add_Click({
    if ($WORKING) {
        if ([System.Windows.MessageBox]::Show("An operation is running. Cancel and exit?","Confirm", "YesNo", "Warning") -ne "Yes") { return }
    }
    $Window.Close()
})

$CancelBtn.Add_Click({
    if ($WORKING) {
        $Window.Tag = "cancel"
        $StatusText.Text = "Cancelling..."
        $DetailText.Text = ""
    } else {
        $Window.Close()
    }
})

# Utility to update UI cleanly (Dispatcher)
function Set-UI {
    param($status = $null, $progress = $null, $percent = $null, $detail = $null)
    $action = {
        param($s,$p,$pc,$d)
        if ($s -ne $null) { $StatusText.Text = $s }
        if ($p -ne $null) { $MainProgress.Value = $p }
        if ($pc -ne $null) { $PercentText.Text = ("{0:N0}%" -f $pc) }
        if ($d -ne $null) { $DetailText.Text = $d }
    }
    $Window.Dispatcher.Invoke([action[object,object,object,object]]{ $action.Invoke($args) }, [object[]]@($status,$progress,$percent,$detail)) | Out-Null
}

# -------------------------------
# Core install workflow (runs in background thread)
# -------------------------------
$worker = {
    param($winrarArch,$winrarVer)

    try {
        $global:WORKING = $true
        Set-UI -status "Checking privileges..." -progress 0 -percent 0 -detail ""

        # Elevation must have been handled before launching UI; double-check
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Set-UI -status "Requesting administrator privileges..." -detail "Re-launching as administrator"
            Start-Sleep -Milliseconds 400
            Elevate-IfNeeded
            return
        }

        Set-UI -status "Checking internet connection..." -detail ""
        if (-not (Test-Internet)) {
            Set-UI -status "No internet connection" -detail "Please check your network and try again."
            $global:WORKING = $false
            return
        }

        # Look for local installer first
        $local = Get-LocalInstaller
        if ($local) {
            $INSTALLER_FILE = $local
            Set-UI -status "Found local installer" -progress 5 -percent 5 -detail (Split-Path $local -Leaf)
        } else {
            # Download
            $tuple = Compose-InstallerUrl -arch $winrarArch -ver $winrarVer
            $url = $tuple[0]; $name = $tuple[1]
            $dest = Join-Path $LOCAL_TMP $name
            Set-UI -status "Downloading WinRAR..." -detail $name -progress 3 -percent 3
            $wc = New-Object System.Net.WebClient
            $lastReceived = 0; $lastTime = [DateTime]::UtcNow

            $wc.DownloadProgressChanged += {
                param($s,$e)
                $pct = [math]::Round($e.ProgressPercentage,0)
                $kb = [math]::Round($e.BytesReceived/1024,1)
                $totalkb = if ($e.TotalBytesToReceive -gt 0) { [math]::Round($e.TotalBytesToReceive/1024,1) } else { 0 }
                $now = [DateTime]::UtcNow
                $dt = ($now - $lastTime).TotalSeconds
                if ($dt -gt 0) {
                    $speed = ($e.BytesReceived - $lastReceived)/$dt
                    $lastReceived = $e.BytesReceived
                    $lastTime = $now
                } else { $speed = 0 }
                $speedStr = ""
                if ($speed -gt 1024) { $speedStr = "{0:N1} MB/s" -f ($speed/1024/1024) } else { $speedStr = "{0:N1} KB/s" -f ($speed/1024) }
                Set-UI -status "Downloading WinRAR..." -progress $pct -percent $pct -detail ("{0} / {1} — {2}" -f ($kb.ToString() + " KB"), ($totalkb.ToString() + " KB"), $speedStr)
                if ($Window.Tag -eq "cancel") { $wc.CancelAsync() }
            }

            $wc.DownloadFileCompleted += {
                param($s,$e)
                if ($e.Cancelled) {
                    Set-UI -status "Download cancelled" -detail ""
                    $global:WORKING = $false
                } elseif ($e.Error) {
                    Set-UI -status "Download failed" -detail $e.Error.Message
                    $global:WORKING = $false
                } else {
                    Set-UI -status "Download complete" -progress 100 -percent 100 -detail $dest
                }
            }

            try {
                $FETCHED = $true
                $INSTALLER_FILE = $dest
                $wc.DownloadFileAsync([uri]$url, $dest)
                # Wait for completion
                while ($wc.IsBusy) {
                    Start-Sleep -Milliseconds 200
                    if ($Window.Tag -eq "cancel") {
                        $wc.CancelAsync()
                        Start-Sleep -Milliseconds 200
                        break
                    }
                }
                if (-not (Test-Path $INSTALLER_FILE)) {
                    throw "Installer not found after download."
                }
            } catch {
                throw $_
            } finally {
                $wc.Dispose()
            }
        }

        if ($Window.Tag -eq "cancel") { $global:WORKING = $false; return }

        # Install silently
        Set-UI -status "Installing WinRAR..." -progress 0 -percent 0 -detail "Running silent installer"
        try {
            $si = New-Object System.Diagnostics.ProcessStartInfo
            $si.FileName = $INSTALLER_FILE
            $si.Arguments = "/S"
            $si.UseShellExecute = $false
            $si.CreateNoWindow = $true
            $p = [System.Diagnostics.Process]::Start($si)
            while (-not $p.HasExited) {
                Start-Sleep -Milliseconds 400
                # animate progress bar while installing
                $val = $MainProgress.Value
                $val = ($val + 2) % 95
                Set-UI -progress $val -percent $val -status "Installing WinRAR..." -detail "Please wait"
                if ($Window.Tag -eq "cancel") {
                    try { $p.Kill() } catch {}
                    Set-UI -status "Installation cancelled" -detail ""
                    $global:WORKING = $false
                    return
                }
            }
            Start-Sleep -Milliseconds 600
            Set-UI -status "Installation finished" -progress 95 -percent 95 -detail ""
        } catch {
            throw "Installation failed: $($_.Exception.Message)"
        }

        # Apply license
        Set-UI -status "Applying license..." -progress 96 -percent 96 -detail ""
        try {
            $winrar64 = "$env:ProgramFiles\WinRAR\WinRAR.exe"
            $winrar32 = "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe"
            $rarreg64 = "$env:ProgramFiles\WinRAR\rarreg.key"
            $rarreg32 = "${env:ProgramFiles(x86)}\WinRAR\rarreg.key"

            $targetRarReg = $null
            if (Test-Path $winrar64) { $targetRarReg = $rarreg64 } elseif (Test-Path $winrar32) { $targetRarReg = $rarreg32 } else {
                throw "WinRAR executable not found after installation."
            }

            # if rarreg.key present in cwd, use it; else write default
            if (Test-Path (Join-Path (Get-Location) "rarreg.key")) {
                Copy-Item -Path (Join-Path (Get-Location) "rarreg.key") -Destination $targetRarReg -Force
            } else {
                Write-RarReg -dest $targetRarReg
            }

            Set-UI -status "License applied" -progress 100 -percent 100 -detail ""
            Start-Sleep -Milliseconds 600
            Set-UI -status "WinRAR setup complete ✔" -progress 100 -percent 100 -detail "Enjoy using WinRAR!"
        } catch {
            throw "Licensing failed: $($_.Exception.Message)"
        }

    } catch {
        $msg = $_.Exception.Message
        if (-not $msg) { $msg = $_.ToString() }
        Set-UI -status "Error" -detail $msg -progress 0 -percent 0
    } finally {
        $global:WORKING = $false
    }
}

# -------------------------------
# Button actions
# -------------------------------
$InstallBtn.Add_Click({
    if ($global:WORKING) { return }
    $Window.Tag = ""  # reset cancel
    # parse optional commandline args from filename (preserve original Get-WinRARData behavior? minimal here)
    $arch = $DEFAULT_ARCH; $ver = $DEFAULT_VER
    # Start background job using runspace to keep UI responsive
    $scriptBlock = $worker
    $ps = [powershell]::Create()
    $ps.AddScript($scriptBlock).AddArgument($arch).AddArgument($ver) | Out-Null
    $async = $ps.BeginInvoke()
    # monitor job completion in a task
    Start-Job -ScriptBlock {
        Param($psInstance,$asyncResult)
        while(-not $psInstance.EndInvoke($asyncResult)) { Start-Sleep -Milliseconds 300 }
    } -ArgumentList $ps,$async | Out-Null
})

# Show window
$Window.ShowDialog() | Out-Null
