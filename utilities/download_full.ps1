$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$outputFolder = "/Volumes/T9/roadmapepigenomics"
$maxConcurrentJobs = 5  # Adjust this based on your internet connection and system capabilities

# Create the output folder if it doesn't exist
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

# Function to download a single file
function Download-File($fileUrl, $outputPath) {
    try {
        Invoke-WebRequest -Uri $fileUrl -OutFile $outputPath
        return $true
    } catch {
        Write-Host "Error downloading $fileUrl : $_"
        return $false
    }
}

function Download-Files($url) {
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    $links = $response.Links | Where-Object { $_.href -like "*.bigwig" }
    $totalFiles = $links.Count
    $downloadedFiles = 0
    $totalSize = 0

    $jobs = @()

    foreach ($link in $links) {
        $fileUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
        $fileName = $link.href
        $outputPath = Join-Path $outputFolder $fileName

        # Start a new job for downloading
        $job = Start-Job -ScriptBlock ${function:Download-File} -ArgumentList $fileUrl, $outputPath

        $jobs += @{Job = $job; FileName = $fileName}

        # Wait if max concurrent jobs reached
        while (($jobs | Where-Object { $_.Job.State -eq 'Running' }).Count -ge $maxConcurrentJobs) {
            $completedJobs = $jobs | Where-Object { $_.Job.State -eq 'Completed' }
            foreach ($completedJob in $completedJobs) {
                $result = Receive-Job $completedJob.Job
                if ($result) {
                    $fileSize = (Get-Item (Join-Path $outputFolder $completedJob.FileName)).Length
                    $totalSize += $fileSize
                    $downloadedFiles++
                    Write-Host "Downloaded: $($completedJob.FileName) (Size: $($fileSize / 1MB) MB)"
                }
                Remove-Job $completedJob.Job
                $jobs = $jobs | Where-Object { $_ -ne $completedJob }
            }
            $percentComplete = ($downloadedFiles / $totalFiles) * 100
            Write-Progress -Activity "Downloading Files" -Status "$downloadedFiles of $totalFiles files downloaded" -PercentComplete $percentComplete
            Start-Sleep -Seconds 1
        }
    }

    # Wait for remaining jobs
    while ($jobs.Count -gt 0) {
        $completedJobs = $jobs | Where-Object { $_.Job.State -eq 'Completed' }
        foreach ($completedJob in $completedJobs) {
            $result = Receive-Job $completedJob.Job
            if ($result) {
                $fileSize = (Get-Item (Join-Path $outputFolder $completedJob.FileName)).Length
                $totalSize += $fileSize
                $downloadedFiles++
                Write-Host "Downloaded: $($completedJob.FileName) (Size: $($fileSize / 1MB) MB)"
            }
            Remove-Job $completedJob.Job
            $jobs = $jobs | Where-Object { $_ -ne $completedJob }
        }
        $percentComplete = ($downloadedFiles / $totalFiles) * 100
        Write-Progress -Activity "Downloading Files" -Status "$downloadedFiles of $totalFiles files downloaded" -PercentComplete $percentComplete
        Start-Sleep -Seconds 1
    }

    Write-Host "Download process completed."
    Write-Host "Total files downloaded: $downloadedFiles"
    Write-Host "Total size downloaded: $($totalSize / 1GB) GB"
}

# Start the download process
Download-Files $baseUrl
