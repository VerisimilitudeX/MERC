$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$outputFolder = "/Volumes/T9/roadmapepigenomics"
$maxConcurrentJobs = 10  # Adjust based on your internet speed and system capabilities

# Create the output folder if it doesn't exist
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

function Get-FileSize($url) {
    try {
        $response = Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing
        return [long]($response.Headers['Content-Length'][0])
    } catch {
        Write-Host "Error getting file size for $url : $_"
        return 0
    }
}

function Download-File($fileUrl, $outputPath, $fileSize) {
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($fileUrl, $outputPath)
        return $true
    } catch {
        Write-Host "Error downloading $fileUrl : $_"
        return $false
    }
}

function Format-FileSize($bytes) {
    if ($bytes -ge 1GB) {
        return "{0:N2} GB" -f ($bytes / 1GB)
    } elseif ($bytes -ge 1MB) {
        return "{0:N2} MB" -f ($bytes / 1MB)
    } else {
        return "{0:N2} KB" -f ($bytes / 1KB)
    }
}

function Download-Files($url) {
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    $links = $response.Links | Where-Object { $_.href -like "*.bigwig" }
    $totalFiles = $links.Count
    $downloadedFiles = 0
    $totalSize = 0
    $downloadedSize = 0
    $startTime = Get-Date

    Write-Host "Calculating total size..."
    foreach ($link in $links) {
        $fileUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
        $totalSize += Get-FileSize $fileUrl
    }
    Write-Host "Total size to download: $(Format-FileSize $totalSize)"

    $jobs = @()

    foreach ($link in $links) {
        $fileUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
        $fileName = $link.href
        $outputPath = Join-Path $outputFolder $fileName
        $fileSize = Get-FileSize $fileUrl

        $job = Start-Job -ScriptBlock ${function:Download-File} -ArgumentList $fileUrl, $outputPath, $fileSize

        $jobs += @{Job = $job; FileName = $fileName; FileSize = $fileSize}

        while (($jobs | Where-Object { $_.Job.State -eq 'Running' }).Count -ge $maxConcurrentJobs) {
            $completedJobs = $jobs | Where-Object { $_.Job.State -eq 'Completed' }
            foreach ($completedJob in $completedJobs) {
                $result = Receive-Job $completedJob.Job
                if ($result) {
                    $downloadedFiles++
                    $downloadedSize += $completedJob.FileSize
                    Write-Host "Downloaded: $($completedJob.FileName) ($(Format-FileSize $completedJob.FileSize))"
                }
                Remove-Job $completedJob.Job
                $jobs = $jobs | Where-Object { $_ -ne $completedJob }
            }
            $percentComplete = ($downloadedSize / $totalSize) * 100
            $elapsedTime = (Get-Date) - $startTime
            $estimatedTotalTime = $elapsedTime.TotalSeconds / ($downloadedSize / $totalSize)
            $remainingTime = $estimatedTotalTime - $elapsedTime.TotalSeconds

            Write-Progress -Activity "Downloading Files" -Status "$downloadedFiles of $totalFiles files downloaded" -PercentComplete $percentComplete
            Write-Host "Progress: $($percentComplete.ToString("N2"))% | Downloaded: $(Format-FileSize $downloadedSize) of $(Format-FileSize $totalSize) | ETA: $($remainingTime.ToString("N0")) seconds"
            Start-Sleep -Milliseconds 500
        }
    }

    while ($jobs.Count -gt 0) {
        $completedJobs = $jobs | Where-Object { $_.Job.State -eq 'Completed' }
        foreach ($completedJob in $completedJobs) {
            $result = Receive-Job $completedJob.Job
            if ($result) {
                $downloadedFiles++
                $downloadedSize += $completedJob.FileSize
                Write-Host "Downloaded: $($completedJob.FileName) ($(Format-FileSize $completedJob.FileSize))"
            }
            Remove-Job $completedJob.Job
            $jobs = $jobs | Where-Object { $_ -ne $completedJob }
        }
        $percentComplete = ($downloadedSize / $totalSize) * 100
        $elapsedTime = (Get-Date) - $startTime
        $estimatedTotalTime = $elapsedTime.TotalSeconds / ($downloadedSize / $totalSize)
        $remainingTime = $estimatedTotalTime - $elapsedTime.TotalSeconds

        Write-Progress -Activity "Downloading Files" -Status "$downloadedFiles of $totalFiles files downloaded" -PercentComplete $percentComplete
        Write-Host "Progress: $($percentComplete.ToString("N2"))% | Downloaded: $(Format-FileSize $downloadedSize) of $(Format-FileSize $totalSize) | ETA: $($remainingTime.ToString("N0")) seconds"
        Start-Sleep -Milliseconds 500
    }

    $totalTime = (Get-Date) - $startTime
    Write-Host "Download process completed."
    Write-Host "Total files downloaded: $downloadedFiles"
    Write-Host "Total size downloaded: $(Format-FileSize $downloadedSize)"
    Write-Host "Total time: $($totalTime.ToString())"
    Write-Host "Average speed: $((($downloadedSize / 1MB) / $totalTime.TotalSeconds).ToString("N2")) MB/s"
}

# Start the download process
Download-Files $baseUrl
