#Requires -Version 5.1

# ============================================================
# GARRY - Windows 10 / 11 Setup Launcher
# PowerShell 5.1 Compatible
#
# IMPORTANT:
# - The first three remote scripts are executed only once.
# - Do NOT make GARRY.ps1 download/execute itself.
# - Remote scripts are still trusted code: review them before use.
# ============================================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# TLS 1.2 for older Windows 10 / PowerShell 5.1
try {
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor `
        [Net.SecurityProtocolType]::Tls12
}
catch {
    Write-Warning "Could not enable TLS 1.2."
}

# ============================================================
# Helpers
# ============================================================

function Invoke-RemoteScript {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    try {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "Running: $Name" -ForegroundColor Cyan
        Write-Host "URL: $Url" -ForegroundColor Gray
        Write-Host "============================================" -ForegroundColor Cyan

        $Response = Invoke-WebRequest `
            -Uri $Url `
            -UseBasicParsing `
            -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($Response.Content)) {
            throw "The remote server returned an empty response."
        }

        Write-Host "Downloaded successfully. Executing..." -ForegroundColor Yellow

        # Execute the returned PowerShell source.
        & ([scriptblock]::Create($Response.Content))

        Write-Host "$Name completed." -ForegroundColor Green
    }
    catch {
        Write-Host "$Name failed." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        return $false
    }

    return $true
}

function DownloadAndRun-Executable {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $TempFilePath = $null

    try {
        $TempFilePath = Join-Path `
            ([System.IO.Path]::GetTempPath()) `
            (([System.IO.Path]::GetRandomFileName()) + ".exe")

        Write-Host ""
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "Downloading executable" -ForegroundColor Cyan
        Write-Host "URL: $Url" -ForegroundColor Gray
        Write-Host "============================================" -ForegroundColor Cyan

        Invoke-WebRequest `
            -Uri $Url `
            -UseBasicParsing `
            -OutFile $TempFilePath `
            -ErrorAction Stop

        if (-not (Test-Path $TempFilePath)) {
            throw "Downloaded file was not created."
        }

        $FileInfo = Get-Item $TempFilePath

        if ($FileInfo.Length -le 0) {
            throw "Downloaded file is empty."
        }

        Write-Host "Download complete." -ForegroundColor Green
        Write-Host "Size: $($FileInfo.Length) bytes" -ForegroundColor Gray

        try {
            Unblock-File -Path $TempFilePath -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Could not remove the downloaded-file security mark."
        }

        Write-Host "Requesting administrator privileges..." -ForegroundColor Yellow

        $Process = Start-Process `
            -FilePath $TempFilePath `
            -Verb RunAs `
            -PassThru `
            -Wait

        if ($Process.ExitCode -eq 0) {
            Write-Host "Executable completed successfully." -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "Executable returned exit code: $($Process.ExitCode)" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "Failed to download or run executable." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        return $false
    }
    finally {
        if ($TempFilePath -and (Test-Path $TempFilePath)) {
            Remove-Item `
                -Path $TempFilePath `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

# ============================================================
# START
# ============================================================

Clear-Host

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " GARRY Windows Setup" -ForegroundColor Cyan
Write-Host " Windows 10 / Windows 11" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Administrator Check
# ============================================================

$Identity = [Security.Principal.WindowsIdentity]::GetCurrent()

$Principal = New-Object Security.Principal.WindowsPrincipal($Identity)

$IsAdmin = $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $IsAdmin) {
    Write-Host "Administrator privileges are recommended." -ForegroundColor Yellow
    Write-Host "Some installers will request elevation individually." -ForegroundColor Yellow
}
else {
    Write-Host "Running as Administrator." -ForegroundColor Green
}

# ============================================================
# Windows Information
# ============================================================

try {
    $OS = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop

    Write-Host ""
    Write-Host "Operating System: $($OS.Caption)"
    Write-Host "Version:          $($OS.Version)"
    Write-Host "Build:            $($OS.BuildNumber)"
}
catch {
    Write-Warning "Could not read Windows version information."
}

# ============================================================
# Remote setup scripts
#
# IMPORTANT:
# Do NOT include GARRY.ps1 itself here.
# Otherwise GARRY.ps1 calls itself recursively.
# ============================================================

$RemoteScripts = @(
    @{
        Name = "MSGANG Windows Setup"
        Url  = "https://win.msgang.com"
    },
    @{
        Name = "MSGANG Installer"
        Url  = "https://install.msgang.com"
    }
)

foreach ($Script in $RemoteScripts) {
    $Result = Invoke-RemoteScript `
        -Url $Script.Url `
        -Name $Script.Name

    if (-not $Result) {
        Write-Host ""
        Write-Host "Remote script failed. Continuing with the remaining setup..." -ForegroundColor Yellow
    }
}

# ============================================================
# Download and run RAR.exe
# ============================================================

$ExecutableUrls = @(
    "https://github.com/Zigsaw07/office2024/raw/main/RAR.exe"
)

foreach ($Url in $ExecutableUrls) {
    DownloadAndRun-Executable -Url $Url | Out-Null
}

# ============================================================
# Activation script
#
# This executes third-party remote code. Review the destination
# before using it on production systems.
# ============================================================

$ActivationUrl = "https://get.activated.win"

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "Remote activation script" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

Invoke-RemoteScript `
    -Url $ActivationUrl `
    -Name "Remote activation script" | Out-Null

# ============================================================
# Debloat script
#
# The original script used git.io/debloat. That short URL may
# redirect or stop working. Verify the destination before use.
# ============================================================

$DebloatUrl = "https://git.io/debloat"

Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host "Remote debloat script" -ForegroundColor Yellow
Write-Host "URL: $DebloatUrl" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor Yellow

Invoke-RemoteScript `
    -Url $DebloatUrl `
    -Name "Debloat script" | Out-Null

# ============================================================
# DONE
# ============================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " Setup completed" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

Read-Host "Press Enter to exit"
