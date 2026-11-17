#Requires -Version 5.1

# ============================================================
# Windows 10 / Windows 11 Application Installer
# WinGet Bootstrapper - Fixed Version
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
        $env:Path = $machinePath
    }

    if ($userPath) {
        if ($env:Path) {
            $env:Path += ";"
        }
        $env:Path += $userPath
    }

    $WindowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"

    if (Test-Path $WindowsApps) {
        if ($env:Path -notlike "*$WindowsApps*") {
            $env:Path += ";$WindowsApps"
        }
    }
}

function Get-WinGetPath {

    Refresh-Path

    # Check normal PATH resolution
    $Command = Get-Command "winget.exe" -ErrorAction SilentlyContinue

    if ($Command) {
        return $Command.Source
    }

    # Check WindowsApps alias directory
    $WindowsApps = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
    $Winget = Join-Path $WindowsApps "winget.exe"

    if (Test-Path $Winget) {
        return $Winget
    }

    # Check App Installer package installation directory
    $PackagePath = "$env:ProgramFiles\WindowsApps"

    if (Test-Path $PackagePath) {
        try {
            $Found = Get-ChildItem `
                -Path $PackagePath `
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

    return $null
}

function Test-WindowsVersion {

    $OS = Get-CimInstance Win32_OperatingSystem

    Write-Host "Operating System: $($OS.Caption)"
    Write-Host "Version:          $($OS.Version)"
    Write-Host "Build:            $($OS.BuildNumber)"
    Write-Host ""

    # WinGet requires Windows 10 build 17763 / version 1809 or later.
    if ([int]$OS.BuildNumber -lt 17763) {

        Write-Host "ERROR: This Windows version is too old for WinGet." -ForegroundColor Red
        Write-Host "WinGet requires Windows 10 build 17763 (version 1809) or newer." -ForegroundColor Yellow

        return $false
    }

    return $true
}

function Register-AppInstaller {

    Write-Host ""
    Write-Host "Checking Microsoft App Installer registration..." -ForegroundColor Cyan

    try {

        # Microsoft recommends this registration command when WinGet
        # is installed but has not been registered for the current user.
        Add-AppxPackage `
            -RegisterByFamilyName `
            -MainPackage "Microsoft.DesktopAppInstaller_8wekyb3d8bbwe" `
            -ErrorAction Stop

        Write-Host "App Installer registration requested successfully." -ForegroundColor Green
        return $true
    }
    catch {

        Write-Host "App Installer registration was not completed:" -ForegroundColor Yellow
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        return $false
    }
}

function Install-WinGet {

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " WinGet Bootstrapper" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""

    # --------------------------------------------------------
    # Check existing WinGet
    # --------------------------------------------------------

    $ExistingWinGet = Get-WinGetPath

    if ($ExistingWinGet) {

        Write-Host "WinGet already installed." -ForegroundColor Green
        Write-Host "Location: $ExistingWinGet" -ForegroundColor Gray

        return $ExistingWinGet
    }

    Write-Host "WinGet not detected." -ForegroundColor Yellow
    Write-Host "Starting Microsoft-supported bootstrap process..." -ForegroundColor Cyan
    Write-Host ""

    # --------------------------------------------------------
    # Administrator Check
    # --------------------------------------------------------

    $CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

    $CurrentPrincipal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

    $IsAdmin = $CurrentPrincipal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )

    if ($IsAdmin) {
        Write-Host "Administrator privileges detected." -ForegroundColor Green
    }
    else {
        Write-Host "WARNING: Script is not running as Administrator." -ForegroundColor Yellow
        Write-Host "Some App Installer repairs may require elevation." -ForegroundColor Yellow
    }

    try {

        # ----------------------------------------------------
        # TLS 1.2 - important on older Windows 10 / PowerShell 5.1
        # ----------------------------------------------------

        Write-Host ""
        Write-Host "Enabling TLS 1.2 for PowerShell Gallery..." -ForegroundColor Cyan

        try {
            [Net.ServicePointManager]::SecurityProtocol = `
                [Net.ServicePointManager]::SecurityProtocol -bor `
                [Net.SecurityProtocolType]::Tls12
        }
        catch {
            Write-Host "Could not modify TLS settings; continuing..." -ForegroundColor Yellow
        }

        # ----------------------------------------------------
        # NuGet
        # ----------------------------------------------------

        Write-Host ""
        Write-Host "Ensuring NuGet Package Provider..." -ForegroundColor Cyan

        Install-PackageProvider `
            -Name NuGet `
            -Force `
            -Confirm:$false `
            -ErrorAction Stop | Out-Null

        Write-Host "NuGet ready." -ForegroundColor Green

        # ----------------------------------------------------
        # PSGallery
        # ----------------------------------------------------

        try {
            Set-PSRepository `
                -Name PSGallery `
                -InstallationPolicy Trusted `
                -ErrorAction SilentlyContinue
        }
        catch {
        }

        # ----------------------------------------------------
        # Microsoft.WinGet.Client
        # ----------------------------------------------------

        Write-Host ""
        Write-Host "Installing Microsoft.WinGet.Client..." -ForegroundColor Cyan

        # CurrentUser is intentional: the module does not need to be
        # installed machine-wide just to run the WinGet repair cmdlet.
        Install-Module `
            -Name Microsoft.WinGet.Client `
            -Repository PSGallery `
            -Force `
            -Confirm:$false `
            -AllowClobber `
            -Scope CurrentUser `
            -ErrorAction Stop | Out-Null

        Write-Host "Microsoft.WinGet.Client installed." -ForegroundColor Green

        # Make sure the module is available in this session.
        Import-Module Microsoft.WinGet.Client -Force -ErrorAction Stop

        # ----------------------------------------------------
        # Microsoft-supported WinGet repair/bootstrap
        # ----------------------------------------------------

        Write-Host ""
        Write-Host "Bootstrapping / repairing WinGet..." -ForegroundColor Cyan
        Write-Host "This may take a little while..." -ForegroundColor Gray

        Repair-WinGetPackageManager `
            -Force `
            -Latest `
            -ErrorAction Stop

        Write-Host "WinGet repair/bootstrap completed." -ForegroundColor Green

    }
    catch {

        Write-Host ""
        Write-Host "WinGet bootstrap error:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
    }

    # --------------------------------------------------------
    # Register App Installer for the current user
    # --------------------------------------------------------

    Register-AppInstaller

    # --------------------------------------------------------
    # Refresh environment
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "Refreshing environment..." -ForegroundColor Cyan

    Refresh-Path

    Start-Sleep -Seconds 5

    # --------------------------------------------------------
    # Try App Installer registration one more time
    # --------------------------------------------------------

    $AppInstaller = Get-AppxPackage `
        -Name "Microsoft.DesktopAppInstaller" `
        -ErrorAction SilentlyContinue

    if ($AppInstaller) {

        Write-Host ""
        Write-Host "Microsoft App Installer detected." -ForegroundColor Green
        Write-Host "Version: $($AppInstaller.Version)" -ForegroundColor Gray

        Register-AppInstaller
    }
    else {

        Write-Host ""
        Write-Host "Microsoft App Installer package is still not visible." -ForegroundColor Yellow
    }

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
    Write-Host "WinGet could not be located after bootstrap." -ForegroundColor Yellow

    return $null
}

# ============================================================
# START
# ============================================================

Clear-Host

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Windows Application Installer" -ForegroundColor Cyan
Write-Host " Windows 10 / Windows 11" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Operating System Check
# ============================================================

if (-not (Test-WindowsVersion)) {

    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

# ============================================================
# Check / Install WinGet
# ============================================================

Write-Host "Checking for WinGet..." -ForegroundColor Cyan
Write-Host ""

$WingetPath = Get-WinGetPath

if (-not $WingetPath) {
    $WingetPath = Install-WinGet
}

# ------------------------------------------------------------
# Final WinGet checks
# ------------------------------------------------------------

if (-not $WingetPath) {

    Refresh-Path
    Start-Sleep -Seconds 3

    $WingetPath = Get-WinGetPath
}

if (-not $WingetPath) {

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " ERROR: WinGet unavailable" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host ""

    Write-Host "The WinGet bootstrap/repair process completed, but winget.exe" -ForegroundColor Yellow
    Write-Host "could not be located for the current Windows user." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Possible causes:" -ForegroundColor Yellow
    Write-Host "  - Windows 10 is older than build 17763"
    Write-Host "  - Microsoft App Installer is missing"
    Write-Host "  - App Installer registration failed"
    Write-Host "  - Windows Store/AppX components are damaged"
    Write-Host "  - The script is running under SYSTEM instead of a normal user"
    Write-Host "  - Windows security policy is blocking MSIX/AppX installation"
    Write-Host ""
    Write-Host "For diagnostics, check:" -ForegroundColor Yellow
    Write-Host "  Event Viewer -> Applications and Services Logs ->"
    Write-Host "  Microsoft -> Windows -> AppxDeployment-Server -> Operational"
    Write-Host ""

    Read-Host "Press Enter to exit"
    exit 1
}

# ============================================================
# Add WinGet Directory to PATH
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

    if ($LASTEXITCODE -eq 0) {
        Write-Host "WinGet version: $WingetVersion" -ForegroundColor Green
    }
    else {
        Write-Host "WinGet exists but did not return a normal version response." -ForegroundColor Yellow
    }
}
catch {

    Write-Host "Unable to determine WinGet version." -ForegroundColor Yellow
}

# ============================================================
# Initialize WinGet Sources
# ============================================================

Write-Host ""
Write-Host "Refreshing WinGet sources..." -ForegroundColor Cyan

try {

    & $WingetPath source update --accept-source-agreements

    if ($LASTEXITCODE -eq 0) {
        Write-Host "WinGet sources updated." -ForegroundColor Green
    }
    else {
        Write-Host "WinGet source update returned exit code $LASTEXITCODE." -ForegroundColor Yellow
    }
}
catch {

    Write-Host "Unable to update WinGet sources." -ForegroundColor Yellow
}

# ============================================================
# Install Applications
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Installing Applications" -ForegroundColor Cyan
Write-Host " Source: winget" -ForegroundColor Cyan
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
        --source winget `
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
    Write-Host "Run the script again to retry the failed applications." -ForegroundColor Yellow
}

Write-Host ""
Read-Host "Press Enter to exit"
