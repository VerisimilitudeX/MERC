$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$outputPath = "E:\full\"
$logFile = Join-Path $outputPath "download_log.txt"
$visitedUrls = New-Object System.Collections.Generic.HashSet[string]
$maxDepth = 5
$totalSize = 0
$fileCount = 0
$startTime = Get-Date

function Log-Message($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    Write-Host $logMessage
    Add-Content $logFile $logMessage
}

function Get-FilesRecursively($url, $depth = 0) {
    if ($depth -gt $maxDepth -or -not $visitedUrls.Add($url)) {
        return
    }
    
    Log-Message "Accessing URL: $url (Depth: $depth)"
    
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $links = $response.Links | Where-Object { $_.href -ne $null }

        $totalLinks = $links.Count
        $processedLinks = 0

        foreach ($link in $links) {
            $processedLinks++
            $newUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
            Write-Progress -Activity "Processing links" -Status "Processing link $processedLinks of $totalLinks" -PercentComplete (($processedLinks / $totalLinks) * 100)

            if ($newUrl -like "*.bigwig") {
                Download-File $newUrl
            } elseif ($newUrl.StartsWith($baseUrl) -and $newUrl -ne $url) {
                Get-FilesRecursively $newUrl ($depth + 1)
            }
        }
        Write-Progress -Activity "Processing links" -Completed
    }
    catch {
        Log-Message "Error accessing $url : $_"
    }
}

function Download-File($url) {
    $filePath = Join-Path $outputPath ($url -replace [regex]::Escape($baseUrl), "")
    $fileDir = Split-Path $filePath -Parent
    if (!(Test-Path $fileDir)) {
        New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
    }
    
    if (Test-Path $filePath) {
        Log-Message "File already exists: $filePath"
        return
    }
    
    Log-Message "Attempting to download: $url to $filePath"
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "PowerShell Script")

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $webClient.DownloadFile($url, $filePath)
        $stopwatch.Stop()

        $fileInfo = Get-Item $filePath
        $script:totalSize += $fileInfo.Length
        $script:fileCount++
        
        $downloadSpeed = [math]::Round($fileInfo.Length / 1MB / $stopwatch.Elapsed.TotalSeconds, 2)
        Log-Message "Downloaded: $($fileInfo.Name), Size: $($fileInfo.Length) bytes, Time: $($stopwatch.Elapsed.TotalSeconds) seconds, Speed: $downloadSpeed MB/s"
    }
    catch {
        Log-Message "Error downloading $url : $_"
    }
    finally {
        if ($webClient) { $webClient.Dispose() }
    }
}

# Create the output directory if it doesn't exist
if (!(Test-Path $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
}

# Start the recursive search
Get-FilesRecursively $baseUrl

$endTime = Get-Date
$duration = $endTime - $startTime
$formattedSize = "{0:N2} MB" -f ($totalSize / 1MB)

Log-Message "Download process completed in $($duration.TotalSeconds) seconds."
Log-Message "Total files downloaded: $fileCount"
Log-Message "Total size of downloaded files: $formattedSize"