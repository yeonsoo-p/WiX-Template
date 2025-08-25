# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a WiX Toolset 6.0 installer generator project that creates MSI packages for Windows applications. The main application being packaged is `userprocessor.exe` with accompanying data files.

## Build Commands

### Building the Installer
```powershell
.\Build-Installer.ps1
```

This PowerShell script:
- Reads version from `pyproject.toml` (currently 0.1.0)
- Generates `License.rtf` from the plain text LICENSE file
- Creates white banner (493x58) and dialog (493x312) BMP images
- Cleans previous build artifacts (.wixobj, .wixpdb, .cab, .msi)
- Builds the MSI installer in the `installer/` directory

### Build with Custom Parameters
```powershell
.\Build-Installer.ps1 -Version "2.0.0" -Manufacturer "Company Name" -ProductName "Product Name"
```

## Architecture

### Core Components

1. **Build-Installer.ps1**: Main PowerShell script that orchestrates the entire build process
   - Dynamically generates WiX source file (UserProcessor.wxs)
   - Creates required image assets (banner.bmp, dialog.bmp)
   - Converts LICENSE to RTF format for installer
   - Invokes WiX toolchain with proper extensions

2. **WiX Configuration**: The script generates a WiX v6 source file with:
   - UI extension for installer dialogs (`-ext WixToolset.UI.wixext`)
   - Fixed UpgradeCode for version management
   - Dynamic component GUIDs for each build
   - Includes both exe and CSV files in installation

3. **Version Management**: Version is automatically extracted from `pyproject.toml` using regex pattern matching. The script falls back to "1.0.0" if version cannot be parsed.

## Key Implementation Details

- **WiX 6.0 Compatibility**: Uses proper namespace declarations (`xmlns:ui`) and extension references
- **Artifact Cleanup**: Always removes previous build artifacts before new builds to prevent conflicts
- **License Conversion**: Automatically converts plain text LICENSE to RTF with proper escaping of special characters
- **Image Generation**: Uses System.Drawing to programmatically create white BMP images for installer UI

## Important Notes

- WiX Toolset 6.0 must be installed and available in PATH
- The script generates UserProcessor.wxs dynamically - manual edits will be overwritten
- The UpgradeCode in Build-Installer.ps1 should remain consistent across versions for proper upgrade handling
- All build artifacts are ignored by git (see .gitignore)

## Testing Installation

After building:
```powershell
# Install
msiexec /i "installer\UserProcessor-0.1.0.msi"

# Uninstall
msiexec /x "installer\UserProcessor-0.1.0.msi"
```