# WiX Template - MSI Installer Generator

A configurable WiX Toolset 6.0 template for creating professional Windows MSI installers with custom UI dialogs.

## Features

- ✅ Automatic version extraction from `pyproject.toml`
- ✅ Custom dialog for shortcut configuration (desktop & start menu)
- ✅ Installation to `C:\` by default (configurable)
- ✅ RTF license generation from plain text LICENSE
- ✅ Dynamic component GUID generation
- ✅ Clean build process with artifact management

## Prerequisites

- Windows OS
- PowerShell 5.0 or higher
- [WiX Toolset 6.0](https://wixtoolset.org/) installed and in PATH
- .NET Framework (for WiX)

## Quick Start

1. Clone this repository
2. Place your executable (e.g., `fileviewer.exe`) in the root directory
3. Run the build script:

```powershell
.\build_msi.ps1
```

The MSI installer will be created in the `installer/` directory.

## Configuration

### Basic Usage

The script automatically detects settings from `pyproject.toml`:

```powershell
.\build_msi.ps1
```

### Custom Parameters

```powershell
.\build_msi.ps1 `
    -ExecutableName "myapp.exe" `
    -Version "2.0.0" `
    -Manufacturer "My Company" `
    -ProductName "My Application" `
    -InstallFolderName "MyApp"
```

### Available Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-ExecutableName` | Main executable file | From `pyproject.toml` |
| `-Version` | Product version | From `pyproject.toml` or "1.0.0" |
| `-Manufacturer` | Company name | "Your Company" |
| `-ProductName` | Display name | Executable base name |
| `-InstallFolderName` | Install folder under C:\ | Executable base name |
| `-CsvFile` | Optional data file | "username.csv" |

## Project Structure

```
WiX-Template/
├── build_msi.ps1           # Main build script
├── fileviewer.exe          # Your application executable
├── pyproject.toml          # Python project configuration
├── LICENSE                 # Plain text license
├── License.rtf            # Generated RTF license
├── banner.bmp             # Generated installer banner
├── dialog.bmp             # Generated installer dialog image
├── fileviewer.wxs         # Generated WiX source file
└── installer/             # Output directory
    └── fileviewer-0.1.0.msi  # Generated installer
```

## Customization

### Installation Directory

By default, the installer uses `C:\[ProductName]` as the installation directory. This is configured in the build script using:

```xml
<StandardDirectory Id="TARGETDIR">
    <Directory Id="INSTALLFOLDER" Name="fileviewer" />
</StandardDirectory>
```

### Custom Dialog

The installer includes a custom dialog for shortcut configuration with checkboxes for:
- Desktop shortcut
- Start menu shortcut

This dialog appears between the installation directory selection and the ready-to-install confirmation.

### License File

The script automatically converts your plain text `LICENSE` file to RTF format required by WiX. Place your license text in the `LICENSE` file, and it will be converted during the build process.

## Testing

### Install
```powershell
msiexec /i "installer\fileviewer-0.1.0.msi"
```

### Uninstall
```powershell
msiexec /x "installer\fileviewer-0.1.0.msi"
```

### Silent Install
```powershell
msiexec /i "installer\fileviewer-0.1.0.msi" /quiet
```

## Troubleshooting

### Common Issues

1. **"WiX not found" error**
   - Ensure WiX Toolset 6.0 is installed
   - Add WiX to your system PATH

2. **"Windows Installer service failed to start"**
   - Restart the Windows Installer service
   - Check permissions

3. **Custom dialog not appearing**
   - Verify the Order attribute is set to "999" in navigation overrides
   - Check for duplicate control definitions

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- Built with [WiX Toolset 6.0](https://wixtoolset.org/)
- PowerShell automation for dynamic generation