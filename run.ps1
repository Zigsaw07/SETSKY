# ============================================================
# Run GARRY.ps1 from GitHub
# ============================================================

$GarrryUrl = "https://github.com/Zigsaw07/SETSKY/raw/refs/heads/main/GARRY.ps1"

Write-Host ""
Write-Host "Downloading GARRY.ps1 from GitHub..." -ForegroundColor Cyan

try {
    $scriptContent = Invoke-RestMethod -Uri $GarrryUrl -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace($scriptContent)) {
        throw "Downloaded script is empty."
    }

    Write-Host "GARRY.ps1 downloaded successfully." -ForegroundColor Green
    Write-Host "Running GARRY.ps1..." -ForegroundColor Cyan
    Write-Host ""

    Invoke-Expression $scriptContent

    Write-Host ""
    Write-Host "GARRY.ps1 finished." -ForegroundColor Green
}
catch {
    Write-Host ""
    Write-Host "Failed to download or run GARRY.ps1." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

function DownloadAndRun-Executable {
    param (
        [string] $url
    )

    try {
        # Create a temporary file path with the .exe extension
        $tempFilePath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + ".exe")
        
        Write-Output "Downloading executable from $url to $tempFilePath"
        
        # Download the executable from the provided URL
        iwr $url -OutFile $tempFilePath -ErrorAction Stop
        Write-Output "Download complete. Unblocking file."

        # Unblock the downloaded file to prevent security warnings
        Unblock-File -Path $tempFilePath -ErrorAction Stop

        Write-Output "Unblocked file. Running executable with admin privileges."

        # Run the executable with administrator rights
        $process = Start-Process -FilePath $tempFilePath -Verb RunAs -PassThru -Wait

        # Log the exit code
        Write-Output "Executable completed with exit code: $($process.ExitCode)"

        # Clean up: Delete the temporary file after execution
        Remove-Item -Path $tempFilePath -Force
        Write-Output "Temporary file deleted."
    }
    catch {
        Write-Error "Failed to download or run executable from $url. Error: $_"
    }
}

function Execute-RemoteScript {
    param (
        [string] $url
    )

    try {
        Write-Output "Executing remote script from $url using irm"
        
        # Fetch and execute the remote script using irm (Invoke-RestMethod)
        irm $url | iex
        Write-Output "Remote script executed successfully."
    }
    catch {
        Write-Error "Failed to execute remote script from $url. Error: $_"
    }
}

# URLs of the executables to download and run
$urls = @(
    
    'https://github.com/Zigsaw07/office2024/raw/main/RAR.exe'    
)

# URL of the remote script to execute
$remoteScriptUrl = 'https://get.activated.win'

# Loop through each URL and execute the download and run function
foreach ($url in $urls) {
    DownloadAndRun-Executable -url $url
}

# Execute the remote script
Execute-RemoteScript -url $remoteScriptUrl

# Execute the debloat script
Write-Output "Executing debloat script..."
irm git.io/debloat | iex
Write-Output "Debloat script executed successfully."

