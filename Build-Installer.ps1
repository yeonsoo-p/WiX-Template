# Build-Installer.ps1
# PowerShell script to create a WiX installer for userprocessor.exe

param(
    [string]$Version,
    [string]$Manufacturer = "Your Company",
    [string]$ProductName = "User Processor"
)

$ErrorActionPreference = "Stop"

# Configuration
$ProjectRoot = $PSScriptRoot

# Read version from pyproject.toml if not provided
if (-not $Version) {
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
        Write-Host "pyproject.toml not found, using default version: $Version" -ForegroundColor Yellow
    }
}
$SourceFile = Join-Path $ProjectRoot "userprocessor.exe"
$WxsFile = Join-Path $ProjectRoot "UserProcessor.wxs"
$OutputDir = Join-Path $ProjectRoot "installer"
$MsiName = "UserProcessor-$Version.msi"

Write-Host "WiX Installer Build Script" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

# Verify source file exists
if (-not (Test-Path $SourceFile)) {
    Write-Error "Source file not found: $SourceFile"
    exit 1
}

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputDir)) {
    Write-Host "Creating output directory: $OutputDir" -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Generate a new GUID for the product (you should keep this consistent for upgrades)
$UpgradeGuid = [guid]::NewGuid().ToString().ToUpper()

# Create the WXS file content
$wxsContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://wixtoolset.org/schemas/v4/wxs"
     xmlns:ui="http://wixtoolset.org/schemas/v4/wxs/ui">
    <Package Name="$ProductName" 
             Version="$Version" 
             Manufacturer="$Manufacturer"
             UpgradeCode="$UpgradeGuid"
             Scope="perMachine">
        
        <!-- Define the installation directory -->
        <StandardDirectory Id="ProgramFiles6432Folder">
            <Directory Id="INSTALLFOLDER" Name="UserProcessor" />
        </StandardDirectory>

        <!-- Main feature -->
        <Feature Id="ProductFeature" Title="$ProductName">
            <ComponentGroupRef Id="ProductComponents" />
            <ComponentRef Id="ApplicationShortcut" />
        </Feature>

        <!-- Component group for files -->
        <ComponentGroup Id="ProductComponents" Directory="INSTALLFOLDER">
            <Component Id="MainExecutable" Guid="{$([guid]::NewGuid().ToString().ToUpper())}">
                <File Id="UserProcessorExe" Source="userprocessor.exe" KeyPath="yes">
                    <Shortcut Id="startmenuShortcut" 
                              Directory="ProgramMenuFolder" 
                              Name="$ProductName"
                              WorkingDirectory="INSTALLFOLDER"
                              Icon="exe"
                              IconIndex="0"
                              Advertise="yes" />
                </File>
            </Component>
            
            <!-- Add CSV file as optional component -->
            <Component Id="CsvFile" Guid="{$([guid]::NewGuid().ToString().ToUpper())}">
                <File Id="UsernameCsv" Source="username.csv" KeyPath="yes" />
            </Component>
        </ComponentGroup>

        <!-- Start Menu Shortcut -->
        <StandardDirectory Id="ProgramMenuFolder">
            <Component Id="ApplicationShortcut" Guid="{$([guid]::NewGuid().ToString().ToUpper())}">
                <RemoveFolder Id="RemoveProgramMenuFolder" On="uninstall" />
                <RegistryValue Root="HKCU" 
                               Key="Software\$Manufacturer\$ProductName" 
                               Name="installed" 
                               Type="integer" 
                               Value="1" 
                               KeyPath="yes" />
            </Component>
        </StandardDirectory>

        <!-- Icon definition -->
        <Icon Id="exe" SourceFile="userprocessor.exe" />

        <!-- Add/Remove Programs properties -->
        <Property Id="ARPPRODUCTICON" Value="exe" />
        <Property Id="ARPHELPLINK" Value="https://www.example.com/support" />
        <Property Id="ARPURLINFOABOUT" Value="https://www.example.com" />

        <!-- UI Configuration -->
        <UI>
            <ui:WixUI Id="WixUI_InstallDir" />
            <Property Id="WIXUI_INSTALLDIR" Value="INSTALLFOLDER" />
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

# Create banner and dialog images if they don't exist
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