<# :# DO NOT REMOVE THIS LINE

:: oneclickrar.cmd
:: oneclickwinrar, version 0.7.0.701
:: Copyright (c) 2024, CHXRITH
:: Install and license WinRAR

@echo off
mode 44,8
title oneclickrar (v0.7.0.701)
:: uses PwshBatch.cmd <https://gist.github.com/neuralpain/4ca8a6c9aca4f0a1af2440f474e92d05>
setlocal EnableExtensions DisableDelayedExpansion
set ARGS=%*
if defined ARGS set ARGS=%ARGS:"=\"%
if defined ARGS set ARGS=%ARGS:'=''%

:: uses cmdUAC.cmd <https://gist.github.com/neuralpain/4bcc08065fe79e4597eb65ed707be90d>
fsutil dirty query %systemdrive% >nul
if %ERRORLEVEL% NEQ 0 (
  cls & echo.
  echo Please grant admin priviledges.
  echo Attempting to elevate...
  goto UAC_Prompt
) else ( goto :begin_script )

:UAC_Prompt
set n=%0 %*
set n=%n:"=" ^& Chr(34) ^& "%
echo Set objShell = CreateObject("Shell.Application")>"%tmp%\cmdUAC.vbs"
echo objShell.ShellExecute "cmd.exe", "/c start " ^& Chr(34) ^& "." ^& Chr(34) ^& " /d " ^& Chr(34) ^& "%CD%" ^& Chr(34) ^& " cmd /c %n%", "", "runas", ^1>>"%tmp%\cmdUAC.vbs"
cscript "%tmp%\cmdUAC.vbs" //Nologo
del "%tmp%\cmdUAC.vbs"
goto :eof

:begin_script
PowerShell -NoP -C ^"$CMD_NAME='%~n0';Invoke-Expression ('^& {' + (get-content -raw '%~f0') + '} %ARGS%')"
exit /b

# --- PS --- #>

<#
  .SYNOPSIS
  Downloads and installs WinRAR and generates a license for it.

  .DESCRIPTION
  oneclickrar.cmd is a combination of installrar.cmd and
  licenserar.cmd but there are some small modifications to
  that were made to allow the two scripts to work together
  as a single unit.

  .NOTES
  Yes, I wrote this description in PowerShell because its
  the main logic of the script. Bite me :)
#>

#region GLOBAL VARIABLES
$global:ProgressPreference = "SilentlyContinue"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Script Configuration
$script_name = "oneclickrar"
$script_name_overwrite = "oneclick-rar"
$winrar = "winrar-x\d{2}-\d{3}\w*\.exe"
$LATEST = 701

# Paths
$winrar64 = "$env:ProgramFiles\WinRAR\WinRAR.exe"
$winrar32 = "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe"
$rarreg64 = "$env:ProgramFiles\WinRAR\rarreg.key"
$rarreg32 = "${env:ProgramFiles(x86)}\WinRAR\rarreg.key"
$keygen64 = "./bin/winrar-keygen/winrar-keygen-x64.exe"
$keygen32 = "./bin/winrar-keygen/winrar-keygen-x86.exe"

# Script State
$Script:WINRAR_EXE = $null
$Script:FETCH_WINRAR = $false
$Script:OVERWRITE_LICENSE = $false
$Script:CUSTOM_LICENSE = $false
$Script:CUSTOM_DOWNLOAD = $false
$Script:LICENSEE = $null
$Script:LICENSE_TYPE = $null
$Script:ARCH = $null
$Script:RARVER = $null
$Script:TAGS = $null

# Default License Key
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
#endregion

#region UTILITY FUNCTIONS
function New-Toast {
    [CmdletBinding()]
    param (
        [String]$AppId = "oneclickwinrar",
        [String]$Url,
        [String]$ToastTitle,
        [String]$ToastText,
        [String]$ToastText2,
        [String]$Attribution,
        [String]$ActionButtonUrl,
        [String]$ActionButtonText = "Open documentation",
        [switch]$KeepAlive,
        [switch]$LongerDuration
    )
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText04)
    $RawXml = [xml] $Template.GetXml(); ($RawXml.toast.visual.binding.text | Where-Object { $_.id -eq "1" }).AppendChild($RawXml.CreateTextNode($ToastTitle)) | Out-Null; ($RawXml.toast.visual.binding.text | Where-Object { $_.id -eq "2" }).AppendChild($RawXml.CreateTextNode($ToastText)) | Out-Null; ($RawXml.toast.visual.binding.text | Where-Object { $_.id -eq "3" }).AppendChild($RawXml.CreateTextNode($ToastText2)) | Out-Null
    $XmlDocument = New-Object Windows.Data.Xml.Dom.XmlDocument; $XmlDocument.LoadXml($RawXml.OuterXml)
    if ($Url) { $XmlDocument.DocumentElement.SetAttribute("activationType", "protocol"); $XmlDocument.DocumentElement.SetAttribute("launch", $Url) }
    if ($Attribution) { $attrElement = $XmlDocument.CreateElement("text"); $attrElement.SetAttribute("placement", "attribution"); $attrElement.InnerText = $Attribution; $bindingElement = $XmlDocument.SelectSingleNode('//toast/visual/binding'); $bindingElement.AppendChild($attrElement) | Out-Null }
    if ($ActionButtonUrl) { $actionsElement = $XmlDocument.CreateElement("actions"); $actionElement = $XmlDocument.CreateElement("action"); $actionElement.SetAttribute("content", $ActionButtonText); $actionElement.SetAttribute("activationType", "protocol"); $actionElement.SetAttribute("arguments", $ActionButtonUrl); $actionsElement.AppendChild($actionElement) | Out-Null; $XmlDocument.DocumentElement.AppendChild($actionsElement) | Out-Null }
    if ($KeepAlive) { $XmlDocument.DocumentElement.SetAttribute("scenario", "incomingCall") } elseif ($LongerDuration) { $XmlDocument.DocumentElement.SetAttribute("duration", "long") }
    $Toast = [Windows.UI.Notifications.ToastNotification]::new($XmlDocument); $Toast.Tag = "PowerShell"; $Toast.Group = "PowerShell"
    if (-not($KeepAlive -or $LongerDuration)) { $Toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(1) }
    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($AppId); $Notifier.Show($Toast)
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
#endregion

#region INSTALLATION FUNCTIONS
function Get-Installer {
    $files = Get-ChildItem -Path $pwd | Where-Object { $_.Name -match '^winrar-x' }
    
    # If no installer found, download it
    if ($files.Count -eq 0) {
        $Script:FETCH_WINRAR = $true
        $arch = if ($Script:CUSTOM_DOWNLOAD) { $Script:ARCH } else { "x64" }
        $ver = if ($Script:CUSTOM_DOWNLOAD -and $Script:RARVER) { $Script:RARVER } else { $LATEST }
        
        $filename = "winrar-$arch-$ver.exe"
        $url = "https://www.win-rar.com/fileadmin/winrar-versions/$filename"
        
        Write-Host "Downloading WinRAR... " -NoNewline
        try {
            Invoke-WebRequest -Uri $url -OutFile $filename
            Write-Host "Done."
            $Script:WINRAR_EXE = Get-Item $filename
            return $Script:WINRAR_EXE
        }
        catch {
            Write-Host "Failed."
            throw "Failed to download WinRAR installer: $($_.Exception.Message)"
        }
    }
    
    # Check existing files
    if ($CUSTOM_DOWNLOAD) {
        $exe = "winrar-${Script:ARCH}-${Script:RARVER}${Script:TAGS}.exe"
        foreach ($file in $files) { 
            if ($file.Name -match $exe) { 
                $Script:WINRAR_EXE = $file
                return $file 
            }
        }
    }
    else {
        foreach ($file in $files) { 
            if ($file.Name -match $winrar) { 
                $Script:WINRAR_EXE = $file
                return $file 
            }
        }
    }
    
    throw "WinRAR installer not found"
}

function Invoke-Installer($file) {
    $x = if ($file -match "(?<version>\d{3})") { "{0:N2}" -f ($matches['version'] / 100) }
    Write-Host "Installing WinRAR v${x}... " -NoNewLine
    
    try {
        $installerPath = (Resolve-Path $file).Path
        $startInfo = New-Object System.Diagnostics.ProcessStartInfo
        $startInfo.FileName = $installerPath
        $startInfo.Arguments = "/S"
        $startInfo.UseShellExecute = $false
        $startInfo.RedirectStandardOutput = $true
        $startInfo.Verb = "runas"

        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $startInfo
        $process.Start() | Out-Null
        $process.WaitForExit()

        Start-Sleep -Seconds 5

        if (-not ((Test-Path $winrar64 -PathType Leaf) -or (Test-Path $winrar32 -PathType Leaf))) {
            throw "WinRAR executable not found after installation"
        }
        
        Write-Host "Done."
    }
    catch {
        Write-Host "Failed."
        New-Toast -ToastTitle "Installation Error" `
                 -ToastText "Failed to install WinRAR: $($_.Exception.Message)" `
                 -ToastText2 "Please ensure you're running as administrator and try again."
        exit 1
    }
    finally {
        if ($Script:FETCH_WINRAR) { 
            Remove-Item $Script:WINRAR_EXE -Force -ErrorAction SilentlyContinue
        }
    }
}
#endregion

#region CONFIGURATION PARSING
function Get-WinRARData {
    $_data = [regex]::matches($CMD_NAME, '[^_]+')
    
    # Download, and overwrite
    # oneclick-rar.cmd
    # oneclickrar___x64_700.cmd
    $SCRIPT_NAME_LOCATION_LEFT = $_data[0]
    
    # License, download, and overwrite
    # John Doe_License___oneclickrar.cmd
    # John Doe_License___oneclickrar___x64_700.cmd
    $SCRIPT_NAME_LOCATION_MIDDLE_RIGHT = $_data[2]

    # I don't like nested switch statements but it's
    # best suited for the purpose below

    # VERIFY SCRIPT NAME
    switch ($SCRIPT_NAME_LOCATION_LEFT.Value) {
        $script_name {
            $SCRIPT_NAME_LOCATION_MIDDLE_RIGHT = $null
            break
        }
        # CHECK FOR OVERWRITE SWITCH
        $script_name_overwrite {
            $Script:OVERWRITE_LICENSE = $true
            $SCRIPT_NAME_LOCATION_MIDDLE_RIGHT = $null
            break
        }
        default {
            switch ($SCRIPT_NAME_LOCATION_MIDDLE_RIGHT.Value) {
                $script_name {
                    $SCRIPT_NAME_LOCATION_LEFT = $null
                    break
                }
                # CHECK FOR OVERWRITE SWITCH
                $script_name_overwrite {
                    $Script:OVERWRITE_LICENSE = $true
                    $SCRIPT_NAME_LOCATION_LEFT = $null
                    break
                }
                default {
                    New-Toast -LongerDuration -ActionButtonUrl "https://github.com/neuralpain/oneclickwinrar#customization" -ToastTitle "What script is this?" -ToastText "Script name is invalid. Check the script name for any typos and try again."; exit
                }
            }
        }
    }

    <#
        VERIFY CONFIGURATION BOUNDS
    #>

    # GET DOWNLOAD-ONLY DATA
    if ($_data.Count -gt 1 -and $_data.Count -le 4 -and $null -ne $SCRIPT_NAME_LOCATION_LEFT) {
        $Script:CUSTOM_DOWNLOAD = $true
        # `$_data[0]` is the script name # 1
        $Script:ARCH = $_data[1].Value # 2
        $Script:RARVER = $_data[2].Value # 3 # not required for download
        $Script:TAGS = $_data[3].Value # 4 # not required for download
    }
    # GET LICENSE-ONLY DATA
    elseif ($_data.Count -gt 1 -and $_data.Count -eq 3 -and $null -ne $SCRIPT_NAME_LOCATION_MIDDLE_RIGHT) {
        $Script:CUSTOM_LICENSE = $true
        $Script:LICENSEE = $_data[0].Value # 1
        $Script:LICENSE_TYPE = $_data[1].Value # 2
        # `$_data[2]` is the script name # 3
    }
    # GET DOWNLOAD AND LICENSE DATA
    elseif ($_data.Count -ge 4 -and $_data.Count -le 6 -and $null -ne $SCRIPT_NAME_LOCATION_MIDDLE_RIGHT) {
        $Script:CUSTOM_LICENSE = $true
        $Script:CUSTOM_DOWNLOAD = $true
        $Script:LICENSEE = $_data[0].Value # 1
        $Script:LICENSE_TYPE = $_data[1].Value # 2
        # `$_data[2]` is the script name # 3
        $Script:ARCH = $_data[3].Value # 4
        $Script:RARVER = $_data[4].Value # 5 # not required for download
        $Script:TAGS = $_data[5].Value # 6 # not required for download
    }
    elseif ($_data.Count -ne 1) {
        New-Toast -ActionButtonUrl "https://github.com/neuralpain/oneclickwinrar#customization" -ToastTitle "Unable to process data" -ToastText "WinRAR data is invalid." -ToastText2 "Check your configuration for any errors or typos and try again."; exit
    }

    # VERIFY DOWNLOAD DATA
    if ($Script:CUSTOM_DOWNLOAD) {
        if ($Script:ARCH -ne "x64" -and $Script:ARCH -ne "x32") {
            New-Toast -ToastTitle "Unable to process data" -ToastText "The WinRAR architecture is invalid." -ToastText2 "Only x64 and x32 are supported."; exit
        }
        if ($Script:RARVER.Length -gt 0 -and $Script:RARVER.Length -ne 3) {
            New-Toast -ToastTitle "Unable to process data" -ToastText "The WinRAR version is invalid." -ToastText2 "The version number must have 3 digits."; exit
        }
        if ($null -eq $Script:RARVER) {
            $Script:RARVER = $LATEST
        }
    }
}
#endregion

#region MAIN INSTALLATION PROCESS
function Start-Installation {
    # Check current status
    $isInstalled = Test-WinRAR
    $isLicensed = Test-WinRARLicense

    if ($isInstalled -and $isLicensed) {
        New-Toast -ToastTitle "WinRAR Status" -ToastText "WinRAR is already installed and licensed." -ToastText2 "No action needed."
        
        New-Toast -ToastTitle "Join Our Community!" `
                  -ToastText "Stay updated with Tech Articles" `
                  -ToastText2 "Join us on Telegram" `
                  -ActionButtonUrl "https://t.me/blogbychxrith" `
                  -ActionButtonText "Join Now" `
                  -LongerDuration
        exit
    }

    # Verify internet connection
    if (-not (Test-InternetConnection)) {
        New-Toast -ToastTitle "No Internet Connection" -ToastText "Please check your internet connection and try again." -ToastText2 "Installation cancelled."
        exit
    }

    # Install if needed
    if (-not $isInstalled) {
        try {
            New-Toast -ToastTitle "Downloading WinRAR" -ToastText "Download in progress..." -ToastText2 "Please wait..."
            $installer = Get-Installer
            if ($null -eq $Script:WINRAR_EXE) {
                throw "WinRAR installer not found"
            }
            New-Toast -ToastTitle "Installing WinRAR" -ToastText "Installation in progress..." -ToastText2 "Please wait..."
            Invoke-Installer $Script:WINRAR_EXE
        }
        catch {
            New-Toast -ToastTitle "Installation Error" -ToastText "Failed to install WinRAR: $($_.Exception.Message)" -ToastText2 "Please try again."
            exit
        }
    }

    # License if needed
    if (-not $isLicensed -or $Script:OVERWRITE_LICENSE) {
        try {
            # Check if already licensed and not forcing overwrite
            if ($isLicensed -and -not $Script:OVERWRITE_LICENSE) {
                New-Toast -ToastTitle "WinRAR Status" `
                         -ToastText "WinRAR is already licensed." `
                         -ToastText2 "No licensing action needed."
                return
            }

            New-Toast -ToastTitle "Licensing WinRAR" -ToastText "Applying license..." -ToastText2 "Please wait..."
            
            # Determine correct path based on architecture
            $rarreg = if (Test-Path $winrar64) { $rarreg64 } else { $rarreg32 }
            
            if ($Script:CUSTOM_LICENSE) {
                $keygen = if (Test-Path $winrar64) { $keygen64 } else { $keygen32 }
                if (Test-Path $keygen -PathType Leaf) {
                    & $keygen "$($Script:LICENSEE)" "$($Script:LICENSE_TYPE)" | Out-File -Encoding utf8 $rarreg
                }
                else {
                    throw "Missing keygen file"
                }
            }
            else {
                if (Test-Path "rarreg.key" -PathType Leaf) {
                    Copy-Item -Path "rarreg.key" -Destination $rarreg -Force
                }
                else {
                    [IO.File]::WriteAllLines($rarreg, $rarkey)
                }
            }
        }
        catch {
            New-Toast -ToastTitle "Licensing Error" -ToastText "Failed to license WinRAR: $($_.Exception.Message)" -ToastText2 "Please try again."
            exit
        }
    }

    # Final success notifications
    New-Toast -ToastTitle "WinRAR Setup Complete" `
              -ToastText "WinRAR is now installed and licensed." `
              -ToastText2 "Enjoy using WinRAR!"

    New-Toast -ToastTitle "Join Our Community!" `
              -ToastText "Stay updated with Tech Articles" `
              -ToastText2 "Join us on Telegram" `
              -ActionButtonUrl "https://t.me/blogbychxrith" `
              -ActionButtonText "Join Now" `
              -LongerDuration
}
#endregion

# Initialize and start installation
if ($CMD_NAME -ne $script_name) { Get-WinRARData }
Start-Installation
