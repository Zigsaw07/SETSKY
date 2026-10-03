#Requires -Version 5.1

# ============================================================
# Windows 10 / Windows 11 Application Installer
# ============================================================

$ErrorActionPreference = "Continue"
$ProgressPreference = "SilentlyContinue"

$Apps = @(
    "Google.Chrome",
    "RARLab.WinRAR",
    "7zip.7zip",
    "Brave.Brave",
    "DucFabulous.UltraViewer",
    "MPC-BE.MPC-BE",
    "voidtools.Everything"
)

function Test-WinGet {
    return [bool](Get-Command "winget.exe" -ErrorAction SilentlyContinue)
}

function Refresh-Path {
    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [Environment]::GetEnvironmentVariable("Path", "User")

    $env:Path = "$machinePath;$userPath"
}

Clear-Host

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Windows Application Installer" -ForegroundColor Cyan
Write-Host " Windows 10 / Windows 11" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$OS = Get-CimInstance Win32_OperatingSystem

Write-Host "Operating System: $($OS.Caption)"
Write-Host "Version:          $($OS.Version)"
Write-Host ""

# ============================================================
# Check WinGet
# ============================================================

Write-Host "Checking for WinGet..." -ForegroundColor Cyan

if (-not (Test-WinGet)) {

    Write-Host "WinGet was not found." -ForegroundColor Yellow
    Write-Host "Attempting to repair/install WinGet..." -ForegroundColor Cyan
    Write-Host ""

    try {
        Write-Host "Installing NuGet package provider..." -ForegroundColor Cyan

        Install-PackageProvider `
            -Name NuGet `
            -Force `
            -ErrorAction Stop | Out-Null

        Write-Host "Installing Microsoft.WinGet.Client..." -ForegroundColor Cyan

        Install-Module `
            -Name Microsoft.WinGet.Client `
            -Repository PSGallery `
            -Force `
            -AllowClobber `
            -ErrorAction Stop | Out-Null

        Write-Host "Repairing WinGet..." -ForegroundColor Cyan

        Repair-WinGetPackageManager -AllUsers

        Write-Host "WinGet repair completed." -ForegroundColor Green
    }
    catch {
        Write-Host "Automatic WinGet repair failed." -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }

    # Refresh environment variables
    Refresh-Path

    Start-Sleep -Seconds 3

    # Check again
    if (-not (Test-WinGet)) {

        Write-Host ""
        Write-Host "WinGet is still unavailable." -ForegroundColor Yellow
        Write-Host "Opening Microsoft Store App Installer..." -ForegroundColor Cyan
        Write-Host ""

        try {
            Start-Process "ms-windows-store://pdp/?productid=9NBLGGH4NNS1"

            Write-Host "Install or update 'App Installer' from Microsoft Store."
            Write-Host ""

            Read-Host "Press Enter after installation is complete"

            Refresh-Path
            Start-Sleep -Seconds 3
        }
        catch {
            Write-Host "Could not open Microsoft Store." -ForegroundColor Red
        }
    }

    Refresh-Path

    if (-not (Test-WinGet)) {

        Write-Host ""
        Write-Host "ERROR: WinGet is still unavailable." -ForegroundColor Red
        Write-Host ""
        Write-Host "Install/update Microsoft App Installer and run this script again."
        Write-Host ""

        Read-Host "Press Enter to exit"
        exit 1
    }
}

# ============================================================
# WinGet information
# ============================================================

Write-Host ""
Write-Host "WinGet is available." -ForegroundColor Green

try {
    $WingetVersion = winget --version
    Write-Host "WinGet version: $WingetVersion" -ForegroundColor Green
}
catch {
    Write-Host "Unable to determine WinGet version." -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# Update WinGet sources
# ============================================================

Write-Host "Updating WinGet sources..." -ForegroundColor Cyan

winget source update

Write-Host ""

# ============================================================
# Install applications
# ============================================================

$Failed = @()

foreach ($App in $Apps) {

    Write-Host "============================================" -ForegroundColor DarkGray
    Write-Host "Installing: $App" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor DarkGray

    winget install `
        --id $App `
        --exact `
        --silent `
        --accept-package-agreements `
        --accept-source-agreements

    $ExitCode = $LASTEXITCODE

    if ($ExitCode -eq 0) {

        Write-Host "SUCCESS: $App" -ForegroundColor Green
    }
    else {

        Write-Host "FAILED: $App" -ForegroundColor Red
        Write-Host "Exit code: $ExitCode" -ForegroundColor Red

        $Failed += $App
    }

    Write-Host ""
}

# ============================================================
# Summary
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Installation Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if ($Failed.Count -eq 0) {

    Write-Host "All applications installed successfully." -ForegroundColor Green

}
else {

    Write-Host "The following applications failed:" -ForegroundColor Yellow
    Write-Host ""

    foreach ($App in $Failed) {
        Write-Host "  - $App" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "Run the script again to retry them." -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to exit"
