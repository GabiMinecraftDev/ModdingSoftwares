[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$DOWNLOAD_URL = "https://archive.org/download/modding_tools/modding_tools.bin"

$tempFolder = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "ModdingSetup_" + [System.Guid]::NewGuid().ToString("N"))
$tempBinPath = Join-Path $tempFolder "modding_tools.bin"
$targetProgramFiles = Join-Path $env:ProgramFiles "ModdingSoftwares"

Clear-Host
Write-Host "------------------------------------" -ForegroundColor Cyan
Write-Host "MODDING SOFTWARES - SETUP" -ForegroundColor Cyan
Write-Host "------------------------------------" -ForegroundColor Cyan
Write-Host "This operation will take 100-150Mo of disk space continue ?" -ForegroundColor Yellow

$response = Read-Host "y/n"
if ($response.Trim().ToLower() -ne 'y') {
    Write-Host "`nInstallation canceled by user." -ForegroundColor Red
    Exit
}

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "`n[!] Admin privileges required to install in Program Files..." -ForegroundColor Yellow
    $scriptPath = $MyInvocation.MyCommand.Path
    $currentDir = Get-Location
    if ($scriptPath) {
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"Set-Location '$currentDir'; & '$scriptPath'`"" -Verb RunAs
        Exit
    } else {
        Write-Host "[X] Error: Please run PowerShell as administrator." -ForegroundColor Red
        Exit
    }
}

New-Item -ItemType Directory -Path $tempFolder -Force | Out-Null

try {
    Write-Host "`nDownloading files on disk.." -ForegroundColor Green

    $webClient = New-Object System.Net.WebClient
    $webClient.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    $global:downloadPercent = 0
    $global:bytesReceived = 0
    $global:totalBytes = 0
    $global:downloadCompleted = $false
    $global:downloadError = $null

    $evtProgress = Register-ObjectEvent -InputObject $webClient -EventName DownloadProgressChanged -Action {
        $global:downloadPercent = $Event.SourceEventArgs.ProgressPercentage
        $global:bytesReceived = $Event.SourceEventArgs.BytesReceived
        $global:totalBytes = $Event.SourceEventArgs.TotalBytesToReceive
    }

    $evtComplete = Register-ObjectEvent -InputObject $webClient -EventName DownloadFileCompleted -Action {
        if ($Event.SourceEventArgs.Error) { $global:downloadError = $Event.SourceEventArgs.Error }
        $global:downloadCompleted = $true
    }

    $webClient.DownloadFileAsync((New-Object System.Uri($DOWNLOAD_URL)), $tempBinPath)

    while (-not $global:downloadCompleted) {
        $mbReceived = [math]::Round($global:bytesReceived / 1MB, 1)
        $mbTotal = [math]::Round($global:totalBytes / 1MB, 1)
        
        Write-Progress -Activity "Downloading files on disk.." `
                       -Status "$mbReceived MB / $mbTotal MB ($($global:downloadPercent)%)" `
                       -PercentComplete $global:downloadPercent
        Start-Sleep -Milliseconds 50
    }
    Write-Progress -Activity "Downloading files on disk.." -Completed

    Unregister-Event -SourceIdentifier $evtProgress.Name -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $evtComplete.Name -ErrorAction SilentlyContinue

    if ($global:downloadError) {
        throw "Download error: $($global:downloadError.Message)"
    }

    Write-Host "installing..." -ForegroundColor Green

    Write-Progress -Activity "installing..." -Status "Unpacking files..." -PercentComplete -1
    $extractedFolder = Join-Path $tempFolder "Extracted"
    New-Item -ItemType Directory -Path $extractedFolder -Force | Out-Null

    tar -xf $tempBinPath -C $extractedFolder

    Write-Progress -Activity "installing..." -Status "Moving files to Program Files..." -PercentComplete -1
    if (-not (Test-Path $targetProgramFiles)) {
        New-Item -ItemType Directory -Path $targetProgramFiles -Force | Out-Null
    }
    Get-ChildItem -Path $extractedFolder | Move-Item -Destination $targetProgramFiles -Force
    Write-Progress -Activity "installing..." -Completed

    Write-Host "`nWould you install dotnet 48 ?" -ForegroundColor Yellow
    $dotnetResponse = Read-Host "y/n"

    if ($dotnetResponse.Trim().ToLower() -eq 'y') {
        Write-Host "Downloading .NET Framework 4.8..." -ForegroundColor Green
        $dotnetUrl = "https://go.microsoft.com/fwlink/?linkid=2088631"
        $dotnetSetupPath = Join-Path $tempFolder "ndp48-web.exe"

        $webClientDotNet = New-Object System.Net.WebClient
        $webClientDotNet.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        $global:dotnetPercent = 0
        $global:dotnetCompleted = $false

        $evtDotnetProgress = Register-ObjectEvent -InputObject $webClientDotNet -EventName DownloadProgressChanged -Action {
            $global:dotnetPercent = $Event.SourceEventArgs.ProgressPercentage
        }

        $evtDotnetComplete = Register-ObjectEvent -InputObject $webClientDotNet -EventName DownloadFileCompleted -Action {
            $global:dotnetCompleted = $true
        }

        $webClientDotNet.DownloadFileAsync((New-Object System.Uri($dotnetUrl)), $dotnetSetupPath)

        while (-not $global:dotnetCompleted) {
            Write-Progress -Activity "Downloading .NET Framework 4.8" `
                           -Status "$($global:dotnetPercent)%" `
                           -PercentComplete $global:dotnetPercent
            Start-Sleep -Milliseconds 50
        }
        Write-Progress -Activity "Downloading .NET Framework 4.8" -Completed

        Unregister-Event -SourceIdentifier $evtDotnetProgress.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $evtDotnetComplete.Name -ErrorAction SilentlyContinue

        Write-Host "Running .NET 4.8 installer..." -ForegroundColor Green
        Start-Process -FilePath $dotnetSetupPath -ArgumentList "/q /norestart" -Wait
    } else {
        Write-Host "Skipping .NET 4.8 installation." -ForegroundColor Gray
    }

    Write-Host "`n*Program ended with success" -ForegroundColor Green
    Read-Host "Press Enter to exit..."

} catch {
    Write-Host "`n[X] Error: $_" -ForegroundColor Red
    Read-Host "Press Enter to exit..."
} finally {
    if (Test-Path $tempFolder) {
        Remove-Item -Path $tempFolder -Recurse -Force -ErrorAction SilentlyContinue
    }
}