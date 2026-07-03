# Script to download wintun.dll for ShadowGate TUN plugin
# Wintun is the TUN driver for Windows, created by WireGuard team
# License: Public domain / GPLv2

$WintunUrl = "https://www.wintun.net/builds/wintun-0.14.1.zip"
$ZipPath = "$PSScriptRoot\wintun.zip"
$ExtractPath = "$PSScriptRoot\bin"
$DllPath = "$ExtractPath\wintun.dll"

# Create bin directory if it doesn't exist
if (-not (Test-Path $ExtractPath)) {
    New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
}

# Check if wintun.dll already exists
if (Test-Path $DllPath) {
    Write-Host "wintun.dll already exists at $DllPath"
    exit 0
}

Write-Host "Downloading wintun.dll from $WintunUrl..."

try {
    # Download the zip
    Invoke-WebRequest -Uri $WintunUrl -OutFile $ZipPath -UseBasicParsing
    
    # Extract only amd64/wintun.dll
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    
    $entry = $zip.Entries | Where-Object { $_.FullName -eq "wintun/bin/amd64/wintun.dll" }
    if ($entry) {
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $DllPath, $true)
        Write-Host "wintun.dll extracted to $DllPath"
    } else {
        Write-Host "ERROR: wintun.dll not found in archive"
        exit 1
    }
    
    $zip.Dispose()
    
    # Clean up zip
    Remove-Item $ZipPath -Force
    
    Write-Host "wintun.dll downloaded successfully!"
} catch {
    Write-Host "ERROR: Failed to download wintun.dll: $_"
    Write-Host ""
    Write-Host "Please download manually from: https://www.wintun.net/"
    Write-Host "Extract wintun/bin/amd64/wintun.dll to: $DllPath"
    exit 1
}