# Build-Installer.ps1
# PowerShell script to create a WiX installer for executables

param(
    [string]$SourceDir = "dist\ipg_launcher",
    [string]$ExecutableName = "ipg_launcher.exe",
    [string]$Version = "2.1.3",
    [string]$Manufacturer = "IPG Automotive Korea Ltd.",
    [string]$ProductName = "IPG Launcher",
    [string]$InstallFolderName = "IPG Launcher"
)

$ErrorActionPreference = "Stop"

# Configuration
$ProjectRoot = $PSScriptRoot

# Read version from __version__.py if not provided
if (-not $Version) {
    $versionFile = Join-Path $ProjectRoot "__version__.py"
    if (Test-Path $versionFile) {
        $versionContent = Get-Content $versionFile -Raw
        if ($versionContent -match '__version__\s*=\s*"([^"]+)"') {
            $Version = $matches[1]
            Write-Host "Using version from __version__.py: $Version" -ForegroundColor Cyan
        }
        else {
            $Version = "1.0.0"
            Write-Host "Could not parse version from __version__.py, using default: $Version" -ForegroundColor Yellow
        }
    }
    else {
        # Fallback to pyproject.toml if __version__.py doesn't exist
        $pyprojectPath = Join-Path $ProjectRoot "pyproject.toml"
        if (Test-Path $pyprojectPath) {
            $pyprojectContent = Get-Content $pyprojectPath -Raw
            if ($pyprojectContent -match 'version\s*=\s*"([^"]+)"') {
                $Version = $matches[1]
                Write-Host "Using version from pyproject.toml: $Version" -ForegroundColor Cyan
            }
            else {
                $Version = "1.0.0"
                Write-Host "Could not parse version from pyproject.toml, using default: $Version" -ForegroundColor Yellow
            }
        }
        else {
            $Version = "1.0.0"
            Write-Host "Version file not found, using default: $Version" -ForegroundColor Yellow
        }
    }
}

# Derive defaults from executable name if not provided
$ExeBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ExecutableName)
if (-not $ProductName) {
    $ProductName = $ExeBaseName
}
if (-not $InstallFolderName) {
    $InstallFolderName = $ExeBaseName
}

# Set up paths
$SourcePath = Join-Path $ProjectRoot $SourceDir
$SourceFile = Join-Path $SourcePath $ExecutableName
$WxsFile = Join-Path $ProjectRoot "$ExeBaseName.wxs"
$OutputDir = Join-Path $ProjectRoot "installer"
$MsiName = "$ExeBaseName-$Version.msi"

Write-Host "WiX Installer Build Script" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Product: $ProductName" -ForegroundColor White
Write-Host "  Version: $Version" -ForegroundColor White
Write-Host "  Source: $SourcePath" -ForegroundColor White
Write-Host "  Install to: C:\$InstallFolderName" -ForegroundColor White
Write-Host ""

# Verify source directory and executable exist
if (-not (Test-Path $SourcePath)) {
    Write-Error "Source directory not found: $SourcePath"
    exit 1
}

if (-not (Test-Path $SourceFile)) {
    Write-Error "Executable not found: $SourceFile"
    exit 1
}

# Function to create a short, unique WiX ID using hash
function Get-WixId {
    param(
        [string]$Prefix,
        [string]$Value
    )
    
    # Always use hash for consistency and brevity
    $hash = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $hash.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Value))
    $hashString = [System.BitConverter]::ToString($hashBytes).Replace("-", "").Substring(0, 12)
    $hash.Dispose()
    
    # Return prefix + short hash (e.g., "Dir_A1B2C3D4E5F6")
    return "${Prefix}_${hashString}"
}

# Function to generate WiX directory structure
function Get-WixDirectoryStructure {
    param(
        [string]$Path,
        [string]$ParentId = "INSTALLFOLDER",
        [string]$RelativePath = ""
    )
    
    $dirs = @{}
    $items = Get-ChildItem -Path $Path -Directory
    
    foreach ($dir in $items) {
        $dirName = $dir.Name
        $fullPath = if ($RelativePath) { "$RelativePath\$dirName" } else { $dirName }
        $dirId = Get-WixId -Prefix "Dir" -Value $fullPath
        
        $newRelativePath = $fullPath
        $dirs[$dirId] = @{
            Name = $dirName
            ParentId = $ParentId
            Path = $dir.FullName
            RelativePath = $newRelativePath
        }
        
        # Recursively get subdirectories
        $subDirs = Get-WixDirectoryStructure -Path $dir.FullName -ParentId $dirId -RelativePath $newRelativePath
        foreach ($key in $subDirs.Keys) {
            $dirs[$key] = $subDirs[$key]
        }
    }
    
    return $dirs
}

# Function to generate WiX components for files
function Get-WixFileComponents {
    param(
        [string]$Path,
        [string]$DirectoryId,
        [string]$SourceBase,
        [string]$RelativePath = ""
    )
    
    $components = @()
    $files = Get-ChildItem -Path $Path -File
    
    foreach ($file in $files) {
        # Skip the main executable in root as it's handled separately
        if ($DirectoryId -eq "INSTALLFOLDER" -and $file.Name -eq $ExecutableName) {
            continue
        }
        
        $fullPath = if ($RelativePath) { "$RelativePath\$($file.Name)" } else { $file.Name }
        $fileId = Get-WixId -Prefix "File" -Value $fullPath
        $componentId = Get-WixId -Prefix "Comp" -Value $fullPath
        
        $relativeSrc = if ($RelativePath) { "$RelativePath\$($file.Name)" } else { $file.Name }
        $sourcePath = "$SourceDir\$relativeSrc"
        
        $components += @{
            ComponentId = $componentId
            FileId = $fileId
            DirectoryId = $DirectoryId
            Source = $sourcePath
            FileName = $file.Name
        }
    }
    
    return $components
}

# Function to get all components from directory tree
function Get-AllWixComponents {
    param(
        [string]$RootPath,
        [hashtable]$Directories
    )
    
    $allComponents = @()
    
    # Get files from root
    $allComponents += Get-WixFileComponents -Path $RootPath -DirectoryId "INSTALLFOLDER" -SourceBase $SourceDir
    
    # Get files from each subdirectory
    foreach ($dirId in $Directories.Keys) {
        $dir = $Directories[$dirId]
        $allComponents += Get-WixFileComponents -Path $dir.Path -DirectoryId $dirId -SourceBase $SourceDir -RelativePath $dir.RelativePath
    }
    
    return $allComponents
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    Write-Host "Creating output directory: $OutputDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Generate a new GUID for the product (you should keep this consistent for upgrades)
$UpgradeGuid = "B7BA45D4-CA49-4F80-B7DF-F61E2730E149"

# Scan the source directory structure
Write-Host "Scanning source directory structure..." -ForegroundColor Yellow
$directories = Get-WixDirectoryStructure -Path $SourcePath
$fileComponents = Get-AllWixComponents -RootPath $SourcePath -Directories $directories

Write-Host "Found $($directories.Count) directories and $($fileComponents.Count) additional files" -ForegroundColor Green

# Create the WXS file content
$wxsContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs"
     xmlns:ui="http://wixtoolset.org/schemas/v4/wxs/ui">
    <Package Name="$ProductName" 
             Version="$Version" 
             Manufacturer="$Manufacturer"
             UpgradeCode="$UpgradeGuid"
             Scope="perMachine"
             Compressed="yes">
        
        <!-- Embed CAB file in MSI for standalone installer -->
        <MediaTemplate EmbedCab="yes" />
        <!-- Define the installation directory at C:\ -->
        <StandardDirectory Id="TARGETDIR">
            <Directory Id="INSTALLFOLDER" Name="$InstallFolderName">
$(
    # Generate directory structure with proper nesting
    $dirXml = ""
    
    # First, create a function to recursively generate directory XML
    function Get-DirectoryXml {
        param(
            [string]$ParentId,
            [hashtable]$AllDirs,
            [int]$IndentLevel
        )
        
        $xml = ""
        $indent = " " * $IndentLevel
        
        # Find all directories that are children of this parent
        foreach ($dirId in $AllDirs.Keys) {
            $dir = $AllDirs[$dirId]
            if ($dir.ParentId -eq $ParentId) {
                $xml += "$indent<Directory Id=`"$dirId`" Name=`"$($dir.Name)`">`n"
                # Recursively add children
                $xml += Get-DirectoryXml -ParentId $dirId -AllDirs $AllDirs -IndentLevel ($IndentLevel + 2)
                $xml += "$indent</Directory>`n"
            }
        }
        
        return $xml
    }
    
    # Generate the directory structure starting from INSTALLFOLDER
    $dirXml = Get-DirectoryXml -ParentId "INSTALLFOLDER" -AllDirs $directories -IndentLevel 16
    $dirXml.TrimEnd()
)
            </Directory>
        </StandardDirectory>

        <!-- Main feature -->
        <Feature Id="ProductFeature" Title="$ProductName" Level="1">
            <ComponentGroupRef Id="ProductComponents" />
            <ComponentGroupRef Id="InternalComponents" />
            <ComponentRef Id="StartMenuShortcut" />
            <ComponentRef Id="DesktopShortcut" />
        </Feature>

        <!-- Component group for main executable -->
        <ComponentGroup Id="ProductComponents" Directory="INSTALLFOLDER">
            <Component Id="MainExecutable" Guid="{$([guid]::NewGuid().ToString().ToUpper())}">
                <File Id="MainExe" Source="$SourceDir\$ExecutableName" KeyPath="yes" />
            </Component>
        </ComponentGroup>
        
        <!-- Component group for all other files -->
        <ComponentGroup Id="InternalComponents">
$(
    # Generate components for all files
    $componentXml = ""
    foreach ($comp in $fileComponents) {
        $componentXml += @"
            <Component Id="$($comp.ComponentId)" Directory="$($comp.DirectoryId)" Guid="{$([guid]::NewGuid().ToString().ToUpper())}">
                <File Id="$($comp.FileId)" Source="$($comp.Source)" KeyPath="yes" />
            </Component>

"@
    }
    $componentXml.TrimEnd()
)
        </ComponentGroup>

        <!-- Start Menu Shortcut (conditional) -->
        <StandardDirectory Id="ProgramMenuFolder">
            <Component Id="StartMenuShortcut" Guid="{$([guid]::NewGuid().ToString().ToUpper())}" Condition="INSTALLSTARTMENUSHORTCUT">
                <Shortcut Id="StartMenuShortcutId"
                          Name="$ProductName"
                          Target="[INSTALLFOLDER]$ExecutableName"
                          WorkingDirectory="INSTALLFOLDER" />
                <RemoveFolder Id="RemoveProgramMenuFolder" On="uninstall" />
                <RegistryValue Root="HKCU" 
                               Key="Software\$Manufacturer\$ProductName" 
                               Name="startMenuShortcut" 
                               Type="integer" 
                               Value="1" 
                               KeyPath="yes" />
            </Component>
        </StandardDirectory>

        <!-- Desktop Shortcut (conditional) -->
        <StandardDirectory Id="DesktopFolder">
            <Component Id="DesktopShortcut" Guid="{$([guid]::NewGuid().ToString().ToUpper())}" Condition="INSTALLDESKTOPSHORTCUT">
                <Shortcut Id="DesktopShortcutId"
                          Name="$ProductName"
                          Target="[INSTALLFOLDER]$ExecutableName"
                          WorkingDirectory="INSTALLFOLDER" />
                <RemoveFile Id="RemoveDesktopShortcut" Name="$ProductName.lnk" On="uninstall" />
                <RegistryValue Root="HKCU"
                               Key="Software\$Manufacturer\$ProductName"
                               Name="desktopShortcut"
                               Type="integer"
                               Value="1"
                               KeyPath="yes" />
            </Component>
        </StandardDirectory>

        <!-- Add/Remove Programs properties -->
        <Property Id="ARPHELPLINK" Value="https://www.example.com/support" />
        <Property Id="ARPURLINFOABOUT" Value="https://www.example.com" />
        
        <!-- Properties for shortcuts -->
        <Property Id="INSTALLDESKTOPSHORTCUT" Value="1" />
        <Property Id="INSTALLSTARTMENUSHORTCUT" Value="1" />
        
        <!-- UI Configuration -->
        <Property Id="WIXUI_INSTALLDIR" Value="INSTALLFOLDER" />
        
        <UI>
            <ui:WixUI Id="WixUI_InstallDir" />
            
            <!-- Custom Shortcuts Dialog - Injected between InstallDir and VerifyReady -->
            <Dialog Id="CustomShortcutsDlg" Width="370" Height="270" Title="Shortcuts">
                <Control Id="BannerBitmap" Type="Bitmap" X="0" Y="0" Width="370" Height="44" TabSkip="no" Text="!(loc.InstallDirDlgBannerBitmap)" />
                <Control Id="BannerLine" Type="Line" X="0" Y="44" Width="370" Height="0" />
                <Control Id="BottomLine" Type="Line" X="0" Y="234" Width="370" Height="0" />
                <Control Id="Title" Type="Text" X="15" Y="6" Width="200" Height="15" Transparent="yes" NoPrefix="yes" Text="{\WixUI_Font_Title}Shortcuts" />
                <Control Id="Description" Type="Text" X="25" Y="23" Width="280" Height="15" Transparent="yes" NoPrefix="yes" Text="Choose which shortcuts to create for [ProductName]" />
                
                <Control Id="DesktopShortcutCheckBox" Type="CheckBox" X="20" Y="100" Width="330" Height="17" 
                         Property="INSTALLDESKTOPSHORTCUT" CheckBoxValue="1" 
                         Text="Create a shortcut on the &amp;Desktop" />
                <Control Id="StartMenuShortcutCheckBox" Type="CheckBox" X="20" Y="130" Width="330" Height="17" 
                         Property="INSTALLSTARTMENUSHORTCUT" CheckBoxValue="1" 
                         Text="Create a shortcut in the &amp;Start Menu" />
                
                <Control Id="Back" Type="PushButton" X="180" Y="243" Width="56" Height="17" Text="!(loc.WixUIBack)" />
                <Control Id="Next" Type="PushButton" X="236" Y="243" Width="56" Height="17" Default="yes" Text="!(loc.WixUINext)" />
                <Control Id="Cancel" Type="PushButton" X="304" Y="243" Width="56" Height="17" Cancel="yes" Text="!(loc.WixUICancel)" />
            </Dialog>
            
            <!-- Override the navigation sequence - using high Order values to ensure override -->
            <!-- Navigate to our custom dialog - Order 999 to override all defaults -->
            <Publish Dialog="InstallDirDlg" Control="Next" Event="NewDialog" Value="CustomShortcutsDlg" Order="999" />
            
            <!-- Define navigation for our custom dialog -->
            <Publish Dialog="CustomShortcutsDlg" Control="Back" Event="NewDialog" Value="InstallDirDlg" Order="1" />
            <Publish Dialog="CustomShortcutsDlg" Control="Next" Event="NewDialog" Value="VerifyReadyDlg" Order="1" />
            <Publish Dialog="CustomShortcutsDlg" Control="Cancel" Event="SpawnDialog" Value="CancelDlg" Order="1" />
            
            <!-- Override VerifyReadyDlg Back to come from our custom dialog -->
            <Publish Dialog="VerifyReadyDlg" Control="Back" Event="NewDialog" Value="CustomShortcutsDlg" Order="999" />
        </UI>

        <!-- License file (optional) -->
        <WixVariable Id="WixUILicenseRtf" Value="License.rtf" />
        
        <!-- Custom banner and dialog images -->
        <WixVariable Id="WixUIBannerBmp" Value="banner.bmp" />
        <WixVariable Id="WixUIDialogBmp" Value="dialog.bmp" />

        <!-- Major upgrade handling -->
        <MajorUpgrade DowngradeErrorMessage="A newer version of [ProductName] is already installed." />

    </Package>
</Wix>
"@

# Write the WXS file
Write-Host "Generating WiX source file: $WxsFile" -ForegroundColor Green
$wxsContent | Out-File -FilePath $WxsFile -Encoding UTF8

$BannerBmp = Join-Path $ProjectRoot "banner.bmp"
$DialogBmp = Join-Path $ProjectRoot "dialog.bmp"

if (-not (Test-Path $BannerBmp)) {
    Write-Host "Creating banner image (493x58)..." -ForegroundColor Yellow
    Add-Type -AssemblyName System.Drawing
    $banner = New-Object System.Drawing.Bitmap(493, 58)
    $graphics = [System.Drawing.Graphics]::FromImage($banner)
    $graphics.Clear([System.Drawing.Color]::White)
    $graphics.Dispose()
    $banner.Save($BannerBmp, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $banner.Dispose()
}

if (-not (Test-Path $DialogBmp)) {
    Write-Host "Creating dialog image (493x312)..." -ForegroundColor Yellow
    Add-Type -AssemblyName System.Drawing
    $dialog = New-Object System.Drawing.Bitmap(493, 312)
    $graphics = [System.Drawing.Graphics]::FromImage($dialog)
    $graphics.Clear([System.Drawing.Color]::White)
    $graphics.Dispose()
    $dialog.Save($DialogBmp, [System.Drawing.Imaging.ImageFormat]::Bmp)
    $dialog.Dispose()
}

# Generate License.rtf from LICENSE file if it exists
$LicenseFile = Join-Path $ProjectRoot "License.rtf"
$PlainLicenseFile = Join-Path $ProjectRoot "LICENSE"

if (Test-Path $PlainLicenseFile) {
    Write-Host "Generating License.rtf from LICENSE file..." -ForegroundColor Yellow
    
    # Read the plain text license
    $licenseContent = Get-Content $PlainLicenseFile -Raw
    
    # Escape special RTF characters
    $licenseContent = $licenseContent -replace '\\', '\\'
    $licenseContent = $licenseContent -replace '\{', '\{'
    $licenseContent = $licenseContent -replace '\}', '\}'
    
    # Convert line breaks to RTF paragraphs
    $licenseContent = $licenseContent -replace "`r`n", '\par '
    $licenseContent = $licenseContent -replace "`n", '\par '
    
    # Create RTF document
    $rtfLicense = @"
{\rtf1\ansi\deff0 {\fonttbl{\f0\fnil\fcharset0 Arial;}}
\f0\fs20 $licenseContent\par
}
"@
    
    $rtfLicense | Out-File -FilePath $LicenseFile -Encoding ASCII
    Write-Host "License.rtf created from LICENSE file" -ForegroundColor Green
}
elseif (-not (Test-Path $LicenseFile)) {
    Write-Host "Creating default license file..." -ForegroundColor Yellow
    $rtfLicense = @"
{\rtf1\ansi\deff0 {\fonttbl{\f0\fnil\fcharset0 Arial;}}
\f0\fs24 SOFTWARE LICENSE AGREEMENT\par
\par
This software is provided "as is" without warranty of any kind.\par
\par
Copyright (c) $(Get-Date -Format yyyy) $Manufacturer\par
}
"@
    $rtfLicense | Out-File -FilePath $LicenseFile -Encoding ASCII
}

# Clean up artifacts from previous build
Write-Host ""
Write-Host "Cleaning up previous build artifacts..." -ForegroundColor Yellow
Remove-Item -Path "$ProjectRoot\*.wixobj" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$ProjectRoot\*.wixpdb" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$ProjectRoot\*.cab" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$OutputDir\*.wixobj" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$OutputDir\*.wixpdb" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$OutputDir\*.cab" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$OutputDir\*.msi" -Force -ErrorAction SilentlyContinue

# Build the installer
try {
    Write-Host ""
    Write-Host "Building WiX installer..." -ForegroundColor Green
    Write-Host "========================" -ForegroundColor Green
    
    # Compile the WXS file
    Write-Host "Compiling WiX source..." -ForegroundColor Cyan
    $wixBuildCmd = "wix build `"$WxsFile`" -ext WixToolset.UI.wixext -o `"$OutputDir\$MsiName`""
    
    Write-Host "Executing: $wixBuildCmd" -ForegroundColor Gray
    $buildOutput = Invoke-Expression $wixBuildCmd 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Build successful!" -ForegroundColor Green
        Write-Host "Installer created: $OutputDir\$MsiName" -ForegroundColor Green
        
        # Display installer information
        $msiPath = Join-Path $OutputDir $MsiName
        if (Test-Path $msiPath) {
            $fileInfo = Get-Item $msiPath
            Write-Host ""
            Write-Host "Installer Details:" -ForegroundColor Cyan
            Write-Host "  File: $($fileInfo.Name)" -ForegroundColor White
            Write-Host "  Size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor White
            Write-Host "  Created: $($fileInfo.CreationTime)" -ForegroundColor White
        }
    }
    else {
        Write-Host ""
        Write-Host "Build failed!" -ForegroundColor Red
        Write-Host "Build output:" -ForegroundColor Yellow
        Write-Host $buildOutput
        exit 1
    }
    
}
catch {
    Write-Host ""
    Write-Host "Error during build: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "To install the application, run:" -ForegroundColor Yellow
Write-Host "  msiexec /i `"$OutputDir\$MsiName`"" -ForegroundColor White
Write-Host ""
Write-Host "To uninstall, run:" -ForegroundColor Yellow
Write-Host "  msiexec /x `"$OutputDir\$MsiName`"" -ForegroundColor White
