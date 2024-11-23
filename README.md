# OneclickRAR

> Original project by [@neuralpain](https://github.com/neuralpain/oneclickwinrar)

A PowerShell-based batch script that automatically downloads, installs, and licenses WinRAR in one click.

## Features

- 🚀 One-click installation of WinRAR
- 📝 Automatic licensing
- 🔄 Custom version selection
- 🎯 Architecture selection (x32/x64)
- 👤 Custom license name and type
- 🛡️ UAC elevation handling
- 🔔 Toast notifications for status updates

## Usage

### Basic Usage

1. Download `oneclickrar.cmd`
2. Double-click to run
3. Grant admin privileges when prompted

The script will automatically:
- Download the latest version of WinRAR (x64 by default)
- Install it silently
- Apply a default license

## Requirements

- Windows 10/11
- PowerShell 5.1 or later
- Internet connection
- Admin privileges

## How It Works

1. **UAC Elevation**: Checks and requests admin privileges if needed
2. **Internet Check**: Verifies internet connectivity
3. **Download**: Fetches WinRAR installer if not present
4. **Installation**: Silently installs WinRAR
5. **Licensing**: Applies license using either:
   - Built-in default license
   - Custom license generator
   - Existing rarreg.key file

## Credits

- Original project: [oneclickwinrar](https://github.com/neuralpain/oneclickwinrar) by [@neuralpain](https://github.com/neuralpain)
- Uses [winrar-keygen](https://github.com/BitCookies/winrar-keygen) by @BitCookies (MIT License)

*Note: This script is for educational purposes. Please ensure you comply with WinRAR's licensing terms.*

>Happy coding! 👾
