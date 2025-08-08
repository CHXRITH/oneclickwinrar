# oneclickrar.ps1
# A script to install and license WinRAR
# Usage: .\oneclickrar.ps1 or oneclickrar_x64_701.ps1 for custom settings
# Made with ♥ by Charith Pramodya Senanayake
# Converted and modernized by AI

Set-StrictMode -Version Latest
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# -------------------------------
# Configuration / Defaults
# -------------------------------
$SCRIPT_VERSION = "0.7.0.701"
$DEFAULT_ARCH = "x64"
$DEFAULT_VER = "701"
$WINRAR_BASE_URL = "https://www.win-rar.com/fileadmin/winrar-versions"

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

# Paths
$winrar64 = "$env:ProgramFiles\WinRAR\WinRAR.exe"
$winrar32 = "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe"
$rarreg64 = "$env:ProgramFiles\WinRAR\rarreg.key"
$rarreg32 = "${env:ProgramFiles(x86)}\WinRAR\rarreg.key"
$keygen64 = (Join-Path $PSScriptRoot "bin\winrar-keygen\winrar-keygen-x64.exe")
$keygen32 = (Join-Path $PSScriptRoot "bin\winrar-keygen\winrar-keygen-x86.exe")

# -------------------------------
# Helper functions
# -------------------------------
function Elevate-IfNeeded {
    # Exit if already running as admin
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = "powershell.exe"
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
        $psi.Verb = "runas"
        try {
            [System.Diagnostics.Process]::Start($psi) | Out-Null
        } catch {
            Write-Host "This script requires administrator privileges. Please re-run as Administrator."
            Start-Sleep -Seconds 3
        }
        Exit
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
    return (Test-Path $winrar64 -PathType Leaf) -or (Test-Path $winrar32 -PathType Leaf)
}

function Test-WinRARLicense {
    return (Test-Path $rarreg64 -PathType Leaf) -or (Test-Path $rarreg32 -PathType Leaf)
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
    $scriptNamePart = $parts[-1]
    
    if ($scriptNamePart -eq $script_name_overwrite) {
        $data.OVERWRITE_LICENSE = $true
    }
    elseif ($scriptNamePart -ne $script_name) {
        New-Toast -LongerDuration -ActionButtonUrl "https://github.com/neuralpain/oneclickwinrar#customization" -ToastTitle "What script is this?" -ToastText "Script name is invalid. Check the script name for any typos and try again."; exit
    }
    
    $partsWithoutScriptName = $parts | Where-Object { $_ -ne $scriptNamePart }
    
    if ($partsWithoutScriptName.Count -gt 0) {
        if ($partsWithoutScriptName.Count -ge 2 -and ($partsWithoutScriptName[-2] -match 'x\d{2}')) {
            # This is a download configuration
            $data.CUSTOM_DOWNLOAD = $true
            $data.ARCH = $partsWithoutScriptName[-2]
            $data.RARVER = $partsWithoutScriptName[-1]
            $partsWithoutScriptName = $partsWithoutScriptName | Select-Object -SkipLast 2
        }
        
        if ($partsWithoutScriptName.Count -ge 2) {
            # This is a license configuration
            $data.CUSTOM_LICENSE = $true
            $data.LICENSEE = $partsWithoutScriptName[0]
            $data.LICENSE_TYPE = $partsWithoutScriptName[1]
        }
    }
    
    # Final validation
    if ($data.CUSTOM_DOWNLOAD) {
        if ($data.ARCH -ne "x64" -and $data.ARCH -ne "x32") {
            New-Toast -ToastTitle "Unable to process data" -ToastText "The WinRAR architecture is invalid." -ToastText2 "Only x64 and x32 are supported."; exit
        }
        if ($data.RARVER.Length -ne 3) {
            New-Toast -ToastTitle "Unable to process data" -ToastText "The WinRAR version is invalid." -ToastText2 "The version number must have 3 digits."; exit
        }
    }
    
    return $data
}

function Start-Installation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$config
    )
    
    Write-Host "Checking current status..."
    $isInstalled = Test-WinRAR
    $isLicensed = Test-WinRARLicense
    $LOCAL_TMP = [System.IO.Path]::GetTempPath().TrimEnd('\')
    
    if ($isInstalled -and $isLicensed -and -not $config.OVERWRITE_LICENSE) {
        New-Toast -ToastTitle "WinRAR Status" -ToastText "WinRAR is already installed and licensed." -ToastText2 "No action needed."
        New-Toast -ToastTitle "Join Our Community!" -ToastText "Stay updated with Tech Articles" -ToastText2 "Join us on Telegram" -ActionButtonUrl "https://t.me/blogbychxrith" -LongerDuration
        exit
    }

    Write-Host "Checking internet connection..."
    if (-not (Test-InternetConnection)) {
        New-Toast -ToastTitle "No Internet Connection" -ToastText "Please check your internet connection and try again." -ToastText2 "Installation cancelled."
        exit
    }

    $installer = $null
    $downloadedFile = $null
    
    if (-not $isInstalled) {
        Write-Host "Looking for installer..."
        $localFiles = Get-ChildItem -Path $PSScriptRoot | Where-Object { $_.Name -match '^winrar-x' }
        
        if ($localFiles.Count -eq 0 -or $config.CUSTOM_DOWNLOAD) {
            Write-Host "No local installer found, downloading..."
            $arch = if ($config.CUSTOM_DOWNLOAD) { $config.ARCH } else { "x64" }
            $ver = if ($config.CUSTOM_DOWNLOAD) { $config.RARVER } else { $DEFAULT_VER }
            $filename = "winrar-$arch-$ver.exe"
            $url = "$WINRAR_BASE_URL/$filename"
            $destination = Join-Path $LOCAL_TMP $filename
            $downloadedFile = $destination

            Write-Host "Downloading WinRAR from $url to $destination"
            try {
                (Invoke-WebRequest -Uri $url -OutFile $destination -Headers @{"User-Agent"="PowerShell-Script"}).RawContent | Out-Null
            }
            catch {
                New-Toast -ToastTitle "Installation Error" -ToastText "Failed to download WinRAR: $($_.Exception.Message)" -ToastText2 "Please try again."
                exit 1
            }
            $installer = $destination
        } else {
            Write-Host "Found local installer..."
            $installer = ($localFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        }
        
        Write-Host "Installing WinRAR silently..."
        New-Toast -ToastTitle "Installing WinRAR" -ToastText "Installation in progress..." -ToastText2 "Please wait..."
        try {
            $p = Start-Process -FilePath $installer -ArgumentList "/S" -Wait -PassThru
            if ($p.ExitCode -ne 0) { throw "Installer returned non-zero exit code." }
            Start-Sleep -Seconds 2
            if (-not ((Test-Path $winrar64 -PathType Leaf) -or (Test-Path $winrar32 -PathType Leaf))) {
                throw "WinRAR executable not found after installation."
            }
            Write-Host "Installation successful."
        }
        catch {
            New-Toast -ToastTitle "Installation Error" -ToastText "Failed to install WinRAR: $($_.Exception.Message)" -ToastText2 "Please try again."
            exit 1
        }
        finally {
            if ($downloadedFile -ne $null) {
                Remove-Item $downloadedFile -Force -ErrorAction SilentlyContinue
            }
        }
    } else {
        Write-Host "WinRAR is already installed. Skipping installation."
    }

    if (-not $isLicensed -or $config.OVERWRITE_LICENSE) {
        Write-Host "Applying license..."
        New-Toast -ToastTitle "Licensing WinRAR" -ToastText "Applying license..." -ToastText2 "Please wait..."
        
        try {
            $rarreg = if (Test-Path $winrar64) { $rarreg64 } else { $rarreg32 }
            if (-not $rarreg) { throw "WinRAR executable not found." }
            
            if ($config.CUSTOM_LICENSE) {
                if (Test-Path $keygen64 -PathType Leaf -or Test-Path $keygen32 -PathType Leaf) {
                    $keygen = if (Test-Path $winrar64) { $keygen64 } else { $keygen32 }
                    & $keygen $config.LICENSEE $config.LICENSE_TYPE | Out-File -Encoding utf8 $rarreg
                }
                else {
                    throw "Missing keygen file for custom license. Place it in the 'bin' folder."
                }
            }
            elseif (Test-Path (Join-Path $PSScriptRoot "rarreg.key") -PathType Leaf) {
                Copy-Item -Path (Join-Path $PSScriptRoot "rarreg.key") -Destination $rarreg -Force
            }
            else {
                [IO.File]::WriteAllText($rarreg, $rarkey, [System.Text.Encoding]::UTF8)
            }
            Write-Host "License applied successfully."
        }
        catch {
            New-Toast -ToastTitle "Licensing Error" -ToastText "Failed to license WinRAR: $($_.Exception.Message)" -ToastText2 "Please try again."
            exit 1
        }
    } else {
        Write-Host "WinRAR is already licensed. Skipping licensing."
    }

    New-Toast -ToastTitle "WinRAR Setup Complete" -ToastText "WinRAR is now installed and licensed." -ToastText2 "Enjoy using WinRAR!"
    New-Toast -ToastTitle "Join Our Community!" -ToastText "Stay updated with Tech Articles" -ToastText2 "Join us on Telegram" -ActionButtonUrl "https://t.me/blogbychxrith" -LongerDuration
}

# -------------------------------
# Main execution
# -------------------------------
# Handle the case where $PSScriptRoot is not set (e.g. in some IDEs)
if (-not $PSScriptRoot) {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Variable -Name "PSScriptRoot" -Value $scriptDir
}

Elevate-IfNeeded
$installConfig = Get-WinRARData -scriptPath $PSCommandPath
Start-Installation -config $installConfig
