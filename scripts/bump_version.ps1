# PowerShell Script to Bump Version in pubspec.yaml
# Usage: 
#   .\scripts\bump_version.ps1           # Bumps patch version by default (1.0.0 -> 1.0.1)
#   .\scripts\bump_version.ps1 -minor    # Bumps minor version (1.0.0 -> 1.1.0)
#   .\scripts\bump_version.ps1 -major    # Bumps major version (1.0.0 -> 2.0.0)
#   .\scripts\bump_version.ps1 -build    # Only bumps build number (1.0.0+1 -> 1.0.0+2)

param(
    [switch]$major,
    [switch]$minor,
    [switch]$patch,
    [switch]$build
)

$pubspecPath = "pubspec.yaml"

# Check if pubspec.yaml exists
if (-Not (Test-Path $pubspecPath)) {
    Write-Error "pubspec.yaml not found in current directory"
    exit 1
}

# Read the pubspec.yaml file
$content = Get-Content $pubspecPath -Raw

# Match the version line (e.g., version: 1.0.0+1)
if ($content -match "version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)") {
    $majorVersion = [int]$matches[1]
    $minorVersion = [int]$matches[2]
    $patchVersion = [int]$matches[3]
    $buildNumber = [int]$matches[4]
    
    Write-Host "Current version: $majorVersion.$minorVersion.$patchVersion+$buildNumber" -ForegroundColor Cyan
    
    # Determine which version to bump
    if ($major) {
        $majorVersion++
        $minorVersion = 0
        $patchVersion = 0
        $buildNumber++
        Write-Host "Bumping MAJOR version..." -ForegroundColor Yellow
    }
    elseif ($minor) {
        $minorVersion++
        $patchVersion = 0
        $buildNumber++
        Write-Host "Bumping MINOR version..." -ForegroundColor Yellow
    }
    elseif ($build) {
        $buildNumber++
        Write-Host "Bumping BUILD number only..." -ForegroundColor Yellow
    }
    else {
        # Default: bump patch
        $patchVersion++
        $buildNumber++
        Write-Host "Bumping PATCH version..." -ForegroundColor Yellow
    }
    
    $newVersion = "$majorVersion.$minorVersion.$patchVersion+$buildNumber"
    Write-Host "New version: $newVersion" -ForegroundColor Green
    
    # Replace the version in the content
    $newContent = $content -replace "version:\s*\d+\.\d+\.\d+\+\d+", "version: $newVersion"
    
    # Write back to file
    Set-Content -Path $pubspecPath -Value $newContent -NoNewline
    
    Write-Host "✓ Version updated successfully in pubspec.yaml" -ForegroundColor Green
}
else {
    Write-Error "Could not find version pattern in pubspec.yaml (expected format: version: 1.0.0+1)"
    exit 1
}
