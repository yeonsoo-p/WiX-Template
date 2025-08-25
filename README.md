# WiX-Template

A PowerShell-based WiX installer generator for creating MSI packages.

## Overview

This project provides an automated PowerShell script that generates Windows Installer (MSI) packages using the WiX Toolset 6.0. The script handles version management, license conversion, and custom branding for your installer.

## Prerequisites

- **WiX Toolset 6.0** - Must be installed and available in your PATH
- **PowerShell 5.0+** - For running the build script
- **Windows OS** - Required for MSI generation

## Features

- **Automatic version detection** from `pyproject.toml`
- **License conversion** - Converts plain text LICENSE to RTF format
- **Custom branding** - Generates white banner and dialog images
- **Build artifact cleanup** - Removes previous build files automatically
- **Configurable parameters** - Customize product name and manufacturer

## Project Structure

```
WiX-Template/
├── Build-Installer.ps1    # Main build script
├── UserProcessor.wxs       # WiX source file (generated)
├── userprocessor.exe       # Application to package
├── username.csv           # Data file included in installer
├── pyproject.toml         # Python project configuration (version source)
├── LICENSE                # MIT License (converted to RTF)
├── .gitignore            # Git ignore rules
└── installer/            # Output directory for MSI
```

## Usage

### Basic Build

Run the PowerShell script to build the installer:

```powershell
.\Build-Installer.ps1
```

This will:
1. Read version from `pyproject.toml` (currently 0.1.0)
2. Generate `License.rtf` from LICENSE file
3. Create banner and dialog images
4. Build the MSI installer in the `installer/` directory

### Custom Parameters

You can override default values:

```powershell
.\Build-Installer.ps1 -Version "2.0.0" -Manufacturer "My Company" -ProductName "My App"
```

### Parameters

- `-Version` - Override version (default: reads from pyproject.toml)
- `-Manufacturer` - Company name (default: "Your Company")
- `-ProductName` - Product display name (default: "User Processor")

## Build Output

The script generates:
- `UserProcessor-{version}.msi` - The installer package
- `banner.bmp` - 493x58 installer banner image
- `dialog.bmp` - 493x312 installer dialog image
- `License.rtf` - RTF formatted license for installer

## Installation

After building, install the application:

```powershell
msiexec /i "installer\UserProcessor-0.1.0.msi"
```

To uninstall:

```powershell
msiexec /x "installer\UserProcessor-0.1.0.msi"
```

## Development

The build script automatically:
- Cleans previous build artifacts (.wixobj, .wixpdb, .cab, .msi)
- Validates required files exist
- Generates dynamic GUIDs for components
- Maintains a fixed UpgradeCode for version upgrades

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Troubleshooting

If you encounter "wix not found" errors:
1. Ensure WiX Toolset 6.0 is installed
2. Add WiX to your system PATH
3. Restart your terminal/PowerShell session

For build failures, check:
- All required files exist (userprocessor.exe, username.csv)
- PowerShell execution policy allows script execution
- WiX extensions are properly referenced