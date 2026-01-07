# Tableau Cleanup Agent - Windows Installer
# Copies skill files to user's Claude skills folder

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  Tableau Cleanup Agent - Install" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host ""

# Paths
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceDir = Join-Path $scriptDir "claude-skill"
$destDir = Join-Path $env:USERPROFILE ".claude\skills\tableau-cleanup"

# Check source exists
if (-not (Test-Path $sourceDir)) {
    Write-Host "  ERROR: claude-skill/ folder not found" -ForegroundColor Red
    Write-Host "  Make sure you're running from the project root" -ForegroundColor Yellow
    exit 1
}

# Create destination
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Write-Host "  Created: $destDir" -ForegroundColor Green
}

# Copy files
Write-Host "  Copying skill files..." -ForegroundColor White
Copy-Item -Path "$sourceDir\*" -Destination $destDir -Recurse -Force

Write-Host ""
Write-Host "  SUCCESS! Skill installed to:" -ForegroundColor Green
Write-Host "  $destDir" -ForegroundColor Gray
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run 'tableau-setup' to configure watch folders" -ForegroundColor White
Write-Host "  2. Run 'tableau-clean' to clean workbooks" -ForegroundColor White
Write-Host ""
Write-Host "  See README.md for full documentation" -ForegroundColor Gray
Write-Host ""
