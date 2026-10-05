
#Requires -Version 5.1

# ============================================================
# Windows 10 / Windows 11 Application Installer
# WinGet Bootstrapper
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

function Refresh-Path {

    $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [Environment]::GetEnvironmentVariable("Path", "User")

    $env:Path = ""

    if ($machinePath) {
        $env:Path += $machinePath
    }

    if ($userPath) {

        if ($env:Path) {
            $env:Path += ";"
        }

        $env:Path += $userPath
    }

    # WindowsApps
    $WindowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"

    if (Test-Path $WindowsApps) {

        if ($env:Path -notlike "*$WindowsApps*") {
            $env:Path += ";$WindowsApps"
        }
    }
}

function Get-WinGetPath {

    Refresh-Path

    # First try PATH
    $Command = Get-Command "winget.exe" -ErrorAction SilentlyContinue

    if ($Command) {
        return $Command.Source
    }

    # Check standard WindowsApps location
    $WindowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"

    $Winget = Join-Path $WindowsApps "winget.exe"

    if (Test-Path $Winget) {
        return $Winget
    }

    # Check WindowsApps package installation locations
    $PackageLocations = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps",
        "$env:ProgramFiles\WindowsApps"
    )

    foreach ($Location in $PackageLocations) {

        if (Test-Path $Location) {

            try {

                $Found = Get-ChildItem `
                    -Path $Location `
                    -Filter "winget.exe" `
                    -Recurse `
                    -ErrorAction SilentlyContinue |
                    Select-Object -First 1

                if ($Found) {
                    return $Found.FullName
                }
            }
            catch {
            }
        }
    }

    return $null
}

function Test-WinGet {

    $WingetPath = Get-WinGetPath

    if ($WingetPath) {
        return $true
    }

    return $false
}

function Install-WinGet {

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " WinGet Bootstrapper" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""

    # --------------------------------------------------------
    # Check if WinGet already exists
    # --------------------------------------------------------

    $ExistingWinGet = Get-WinGetPath

    if ($ExistingWinGet) {

        Write-Host "WinGet already installed." -ForegroundColor Green
        Write-Host "Location: $ExistingWinGet" -ForegroundColor Gray

        return $ExistingWinGet
    }

    Write-Host "WinGet not detected." -ForegroundColor Yellow
    Write-Host "Proceeding with installation..." -ForegroundColor Cyan
    Write-Host ""

    # --------------------------------------------------------
    # Administrator check
    # --------------------------------------------------------

    $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

    $IsAdmin = $CurrentPrincipal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if ($IsAdmin) {

        $InstallScope = "AllUsers"

        Write-Host "Administrator privileges detected." -ForegroundColor Green
        Write-Host "Installation scope: AllUsers" -ForegroundColor Green
    }
    else {

        $InstallScope = "CurrentUser"

        Write-Host "WARNING: Not running as Administrator." -ForegroundColor Yellow
        Write-Host "Installation scope: CurrentUser" -ForegroundColor Yellow
    }

    Write-Host ""

    try {

        # ----------------------------------------------------
        # NuGet
        # ----------------------------------------------------

        Write-Host "Installing / checking NuGet Package Provider..." -ForegroundColor Cyan

        Install-PackageProvider `
            -Name NuGet `
            -Force `
            -Confirm:$false `
            -ErrorAction Stop | Out-Null

        Write-Host "NuGet ready." -ForegroundColor Green

        # ----------------------------------------------------
        # Microsoft.WinGet.Client
        # ----------------------------------------------------

        Write-Host ""
        Write-Host "Installing Microsoft.WinGet.Client..." -ForegroundColor Cyan

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
        # Bootstrap WinGet
        # ----------------------------------------------------

        if ($IsAdmin) {

            Write-Host ""
            Write-Host "Bootstrapping WinGet..." -ForegroundColor Cyan

            Repair-WinGetPackageManager -AllUsers

            Write-Host "WinGet bootstrap completed." -ForegroundColor Green
        }
        else {

            Write-Host ""
            Write-Host "Skipping AllUsers WinGet repair because Administrator privileges are required." -ForegroundColor Yellow
        }

    }
    catch {

        Write-Host ""
        Write-Host "WinGet bootstrap error:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }

    # --------------------------------------------------------
    # Refresh PATH
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Refreshing environment..." -ForegroundColor Cyan

    Refresh-Path

    Start-Sleep -Seconds 5

    # --------------------------------------------------------
    # Locate WinGet
    # --------------------------------------------------------

    $WingetPath = Get-WinGetPath

    if ($WingetPath) {

        Write-Host ""
        Write-Host "WinGet detected successfully." -ForegroundColor Green
        Write-Host "Location: $WingetPath" -ForegroundColor Gray

        return $WingetPath
    }

    Write-Host ""
    Write-Host "WinGet was installed but could not be located automatically." -ForegroundColor Yellow

    return $null
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
# OS Information
# ============================================================

$OS = Get-CimInstance Win32_OperatingSystem

Write-Host "Operating System: $($OS.Caption)"
Write-Host "Version:          $($OS.Version)"
Write-Host ""

# ============================================================
# WinGet
# ============================================================

Write-Host "Checking for WinGet..." -ForegroundColor Cyan
Write-Host ""

$WingetPath = Get-WinGetPath

if (-not $WingetPath) {

    $WingetPath = Install-WinGet
}

# ------------------------------------------------------------
# Final WinGet check
# ------------------------------------------------------------

if (-not $WingetPath) {

    Refresh-Path

    Start-Sleep -Seconds 3

    $WingetPath = Get-WinGetPath
}

if (-not $WingetPath) {

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " ERROR: WinGet could not be located" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""

    Write-Host "WinGet bootstrap completed, but winget.exe is not accessible." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  - App Installer registration is still processing"
    Write-Host "  - Windows LTSC / Store-less installation"
    Write-Host "  - WinGet package installation failed"
    Write-Host ""

    Read-Host "Press Enter to exit"

    exit 1
}

# ============================================================
# Add WinGet directory to PATH
# ============================================================

$WingetDirectory = Split-Path $WingetPath -Parent

if ($env:Path -notlike "*$WingetDirectory*") {

    $env:Path += ";$WingetDirectory"
}

Write-Host ""
Write-Host "WinGet is available." -ForegroundColor Green
Write-Host "Path: $WingetPath" -ForegroundColor Gray

# ============================================================
# WinGet Version
# ============================================================

Write-Host ""

try {

    $WingetVersion = & $WingetPath --version

    Write-Host "WinGet version: $WingetVersion" -ForegroundColor Green
}
catch {

    Write-Host "Unable to determine WinGet version." -ForegroundColor Yellow
}

# ============================================================
# Update Sources
# ============================================================

Write-Host ""
Write-Host "Updating WinGet sources..." -ForegroundColor Cyan
Write-Host ""

try {

    & $WingetPath source update
}
catch {

    Write-Host "Unable to update WinGet sources." -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# Install Applications
# ============================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Installing Applications" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$Failed = @()

foreach ($App in $Apps) {

    Write-Host "============================================" -ForegroundColor DarkGray
    Write-Host "Installing: $App" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor DarkGray

    & $WingetPath install `
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

Write-Host ""
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

