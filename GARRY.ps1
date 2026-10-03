# install-apps.ps1
# Installs commonly used Windows applications using WinGet.

$apps = @(
    "Google.Chrome",
    "Brave.Brave",
    "DucFabulous.UltraViewer",
    "MPC-BE.MPC-BE",
    "voidtools.Everything",
    "NitroSoftware.NitroPro.NLS"
)

Write-Host "Checking for WinGet..." -ForegroundColor Cyan

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "WinGet was not found. Please install/update App Installer from Microsoft Store." -ForegroundColor Red
    exit 1
}

foreach ($app in $apps) {
    Write-Host "`nInstalling $app..." -ForegroundColor Cyan

    winget install --id $app --exact --silent --accept-package-agreements --accept-source-agreements

    if ($LASTEXITCODE -eq 0) {
        Write-Host "$app installed successfully." -ForegroundColor Green
    }
    else {
        Write-Host "$app installation returned exit code $LASTEXITCODE." -ForegroundColor Yellow
    }
}

Write-Host "`nInstallation process completed." -ForegroundColor Green
