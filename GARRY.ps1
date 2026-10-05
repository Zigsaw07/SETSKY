```powershell
#Requires -Version 5.1

# ============================================================
# Windows 10 / Windows 11 Application Installer
# PowerShell 5.1 Compatible
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

# ============================================================
# Functions
# ============================================================

function Test-WinGet {
    return [bool](Get-Command "winget.exe" -ErrorAction SilentlyContinue)
}

function Refresh-Path {

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [Environment]::GetEnvironmentVariable("Path", "User")

    $env:Path = "$machinePath;$userPath"
}

function Install-WinGet {

    Write-Host ""
    Write-Host "=== WinGet Bootstrapper ===" -ForegroundColor Cyan
    Write-Host ""

    # --------------------------------------------------------
    # Check if WinGet already exists
    # --------------------------------------------------------

    try {

        if (Get-Command winget.exe -ErrorAction Stop) {

            Write-Host "WinGet already installed. Skipping bootstrap." -ForegroundColor Green
            return $true
        }
    }
    catch {

        Write-Host "WinGet not detected. Proceeding with installation..." -ForegroundColor Yellow
    }

    # --------------------------------------------------------
    # Check Administrator Rights
    # --------------------------------------------------------

    $IsAdmin = (
        [Security.Principal.WindowsPrincipal]
        [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if ($IsAdmin) {

        $InstallScope = "AllUsers"

        Write-Host "Administrator privileges detected." -ForegroundColor Green
        Write-Host "Installation scope: AllUsers"
    }
    else {

        $InstallScope = "CurrentUser"

        Write-Host "WARNING: Script is not running as Administrator." -ForegroundColor Yellow
        Write-Host "Installation scope: CurrentUser"
        Write-Host "Attempting user-scope installation..."
    }

    Write-Host ""

    try {

        # ----------------------------------------------------
        # Ensure NuGet
        # ----------------------------------------------------

        Write-Host "Ensuring NuGet Package Provider..." -ForegroundColor Cyan

        Install-PackageProvider `
            -Name NuGet `
            -Force `
            -Confirm:$false `
            -ErrorAction Stop | Out-Null

        Write-Host "NuGet Package Provider ready." -ForegroundColor Green

        # ----------------------------------------------------
        # Install Microsoft.WinGet.Client
        # ----------------------------------------------------

        Write-Host ""
        Write-Host "Installing Microsoft.WinGet.Client module ($InstallScope)..." -ForegroundColor Cyan

        Install-Module `
            -Name Microsoft.WinGet.Client `
            -Repository PSGallery `
            -Force `
            -Confirm:$false `
            -AllowClobber `
            -Scope $InstallScope `
            -ErrorAction Stop | Out-Null

        Write-Host "Microsoft.WinGet.Client installed." -ForegroundColor Green

        # ----------------------------------------------------
        # Bootstrap / Repair WinGet
        # ----------------------------------------------------

        if ($IsAdmin) {

            Write-Host ""
            Write-Host "Bootstrapping / Repairing WinGet (All Users)..." -ForegroundColor Cyan

            Repair-WinGetPackageManager -AllUsers

            Write-Host "WinGet bootstrap completed." -ForegroundColor Green
        }
        else {

            Write-Host ""
            Write-Host "Skipping Repair-WinGetPackageManager." -ForegroundColor Yellow
            Write-Host "Administrator privileges are required for the AllUsers repair."
            Write-Host "If App Installer is already present, WinGet may still be available."
        }

        # ----------------------------------------------------
        # Refresh PATH
        # ----------------------------------------------------

        Refresh-Path

        Start-Sleep -Seconds 3

        # ----------------------------------------------------
        # Final Validation
        # ----------------------------------------------------

        if (Test-WinGet) {

            Write-Host ""
            Write-Host "WinGet is now available." -ForegroundColor Green

            return $true
        }
        else {

            Write-Host ""
            Write-Host "WinGet not detected after installation attempt." -ForegroundColor Yellow
            Write-Host "This may be an LTSC / Store-less Windows system." -ForegroundColor Yellow

            return $false
        }
    }
    catch {

        Write-Host ""
        Write-Host "WinGet bootstrap failed." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow

        return $false
    }
}

# ============================================================
# Start
# ============================================================

Clear-Host

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Windows Application Installer" -ForegroundColor Cyan
Write-Host " Windows 10 / Windows 11" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Operating System Information
# ============================================================

$OS = Get-CimInstance Win32_OperatingSystem

Write-Host "Operating System: $($OS.Caption)"
Write-Host "Version:          $($OS.Version)"
Write-Host ""

# ============================================================
# Check / Install WinGet
# ============================================================

Write-Host "Checking for WinGet..." -ForegroundColor Cyan
Write-Host ""

if (-not (Test-WinGet)) {

    $WinGetInstalled = Install-WinGet

    if (-not $WinGetInstalled) {

        Write-Host ""
        Write-Host "============================================" -ForegroundColor Red
        Write-Host " ERROR: WinGet is unavailable" -ForegroundColor Red
        Write-Host "============================================" -ForegroundColor Red
        Write-Host ""

        Write-Host "The WinGet bootstrapper could not make WinGet available."
        Write-Host ""
        Write-Host "Possible causes:" -ForegroundColor Yellow
        Write-Host "  - Windows LTSC / Store-less installation"
        Write-Host "  - App Installer components are missing"
        Write-Host "  - Windows version does not support WinGet"
        Write-Host "  - Installation requires Administrator privileges"
        Write-Host ""

        Read-Host "Press Enter to exit"
        exit 1
    }
}
else {

    Write-Host "WinGet is already installed." -ForegroundColor Green
}

# ============================================================
# Refresh PATH
# ============================================================

Refresh-Path

Start-Sleep -Seconds 2

# ============================================================
# WinGet Information
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " WinGet Information" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

try {

    $WingetVersion = winget --version

    Write-Host "WinGet version: $WingetVersion" -ForegroundColor Green
}
catch {

    Write-Host "Unable to determine WinGet version." -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# Update WinGet Sources
# ============================================================

Write-Host "Updating WinGet sources..." -ForegroundColor Cyan

try {

    winget source update
}
catch {

    Write-Host "Unable to update WinGet sources." -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# Install Applications
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
# Installation Summary
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
```
