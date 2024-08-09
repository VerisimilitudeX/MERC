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
        $links = $response.Links | Where-Object { $_.href -like "*.bigwig" -or ($_.href -like "*/" -and $_.href -notlike "../") }

        foreach ($link in $links) {
            $newUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
            if ($newUrl -like "*.bigwig") {
                Download-File $newUrl
            } elseif ($newUrl.StartsWith($baseUrl)) {
                Get-FilesRecursively $newUrl ($depth + 1)
            }
        }
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
    Log-Message "Attempting to download: $url to $filePath"
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $filePath)
        $fileInfo = Get-Item $filePath
        $script:totalSize += $fileInfo.Length
        $script:fileCount++
        Log-Message "Downloaded: $($fileInfo.Name), Size: $($fileInfo.Length) bytes"
    }
    catch {
        Log-Message "Error downloading $url : $_"
    }
    finally {
        if ($webClient) { $webClient.Dispose() }
    }
}

function Format-FileSize($bytes) {
    $sizes = "Bytes", "KB", "MB", "GB", "TB"
    $order = 0
    while ($bytes -ge 1024 -and $order -lt $sizes.Count - 1) {
        $bytes /= 1024
        $order++
    }
    return "{0:N2} {1}" -f $bytes, $sizes[$order]
}

# Create the output directory if it doesn't exist
if (!(Test-Path $outputPath)) {
    New-Item -ItemType Directory -Path $outputPath -Force | Out-Null
}

# Start the recursive search
Get-FilesRecursively $baseUrl

$endTime = Get-Date
$duration = $endTime - $startTime
$formattedSize = Format-FileSize $totalSize

Log-Message "Download process completed in $($duration.TotalSeconds) seconds."
Log-Message "Total files downloaded: $fileCount"
Log-Message "Total size of downloaded files: $formattedSize"