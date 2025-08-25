# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a WiX Toolset 6.0 installer generator project that creates MSI packages for Windows applications. The main application being packaged is `fileviewer.exe`. The project provides a configurable PowerShell script that generates WiX source files and builds MSI installers with a custom UI dialog for shortcut configuration.

## Build Commands

### Building the Installer
```powershell
.\build_msi.ps1
```

This PowerShell script:
- Reads project name and version from `pyproject.toml` (defaults to fileviewer.exe and 0.1.0)
- Generates `License.rtf` from the plain text LICENSE file
- Creates white banner (493x58) and dialog (493x312) BMP images if they don't exist
- Cleans previous build artifacts (.wixobj, .wixpdb, .cab, .msi)
- Generates a WiX source file dynamically
- Builds the MSI installer in the `installer/` directory

### Build with Custom Parameters
```powershell
.\build_msi.ps1 -ExecutableName "myapp.exe" -Version "2.0.0" -Manufacturer "Company Name" -ProductName "Product Name" -InstallFolderName "MyApp"
```

Optional parameters:
- `-ExecutableName`: Main executable file (defaults to name from pyproject.toml)
- `-Version`: Product version (defaults to version from pyproject.toml)
- `-Manufacturer`: Company name for installer
- `-ProductName`: Display name for the product
- `-InstallFolderName`: Installation folder name under C:\
- `-CsvFile`: Optional data file to include

## Architecture

### Installation Directory
The installer is configured to install to `C:\[ProductName]` by default, not to Program Files. This is achieved by using `TARGETDIR` instead of `ProgramFiles6432Folder` in the WiX configuration.

### Custom Dialog Integration
The installer uses WixUI_InstallDir as the base UI and injects a custom dialog (`CustomShortcutsDlg`) between the installation directory selection and the ready-to-install dialog. Key implementation details:

- **Navigation Override**: Uses `Order="999"` on Publish elements to override the default WixUI_InstallDir navigation sequence
- **Checkbox Controls**: Custom dialog includes checkboxes for desktop and start menu shortcuts
- **Properties**: `INSTALLDESKTOPSHORTCUT` and `INSTALLSTARTMENUSHORTCUT` control shortcut creation

### Dialog Sequence
1. Welcome Dialog
2. License Agreement 
3. Installation Directory (editable path)
4. **Custom Shortcuts Dialog** (checkboxes for desktop/start menu shortcuts)
5. Ready to Install
6. Installation Progress
7. Exit Dialog

## Key Implementation Details

### WiX 6.0 Syntax Requirements
- No inner text in Publish elements (use attributes only)
- Conditions must be attributes, not inner text: `Condition="INSTALLDESKTOPSHORTCUT"`
- Proper namespace declarations: `xmlns:ui="http://wixtoolset.org/schemas/v4/wxs/ui"`

### Dynamic GUID Generation
Component GUIDs are generated dynamically for each build using PowerShell:
```powershell
Guid="{$([guid]::NewGuid().ToString().ToUpper())}"
```

### License File Conversion
The script automatically converts LICENSE to License.rtf:
- Escapes special RTF characters (\, {, })
- Converts line breaks to RTF paragraphs
- Creates properly formatted RTF document

## Testing Installation

```powershell
# Install
msiexec /i "installer\fileviewer-0.1.0.msi"

# Uninstall
msiexec /x "installer\fileviewer-0.1.0.msi"
```

## Important Notes

- WiX Toolset 6.0 must be installed and available in PATH
- The generated .wxs file should not be manually edited (it's regenerated each build)
- The UpgradeCode is dynamically generated per build - for production, this should be fixed
- Build artifacts in the installer/ directory are not tracked in git

## Troubleshooting Common Issues

### Dialog Navigation Issues
If the custom dialog is being skipped, ensure the Order attribute on Publish elements is high enough (e.g., Order="999") to override default navigation.

### Duplicate Control Errors
When modifying dialogs, ensure control navigation is defined either inside the Dialog element OR in external Publish elements, not both.

### Windows Installer Service Errors
If you get "Windows Installer service failed to start" errors, the service may need to be restarted or there may be a permissions issue.