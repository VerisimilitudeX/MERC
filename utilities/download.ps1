$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$outputPath = "C:\Users\achar\Downloads"
$visitedUrls = New-Object System.Collections.Generic.HashSet[string]
$totalSize = 0
$fileCount = 0
$lastReportTime = Get-Date

function Get-FilesRecursively($url) {
    if (-not $visitedUrls.Add($url)) {
        return
    }
    
    Write-Host "Scanning URL: $url"
    
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $links = $response.Links | Where-Object { $_.href -notlike "javascript:*" -and $_.href -notlike "mailto:*" }

        foreach ($link in $links) {
            $newUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
            if ($newUrl -like "*.bigwig") {
                $fileSize = Get-RemoteFileSize $newUrl
                $script:totalSize += $fileSize
                $script:fileCount++
                Write-Host "Found .bigwig file: $newUrl (Size: $fileSize bytes)"
                Report-Progress
            } elseif ($newUrl -like "$baseUrl*") {
                Get-FilesRecursively $newUrl
            }
        }
    }
    catch {
        Write-Host "Error accessing $url : $_"
    }
}

function Get-RemoteFileSize($url) {
    try {
        $request = [System.Net.WebRequest]::Create($url)
        $request.Method = "HEAD"
        $response = $request.GetResponse()
        $fileSize = $response.ContentLength
        $response.Close()
        return $fileSize
    }
    catch {
        Write-Host "Error getting file size for $url : $_"
        return 0
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

function Report-Progress {
    $currentTime = Get-Date
    if (($currentTime - $script:lastReportTime).TotalSeconds -ge 10) {
        $formattedSize = Format-FileSize $script:totalSize
        Write-Host "Progress Report:"
        Write-Host "Total files found: $script:fileCount"
        Write-Host "Total size: $formattedSize"
        $script:lastReportTime = $currentTime
    }
}

# Start the recursive search
Get-FilesRecursively $baseUrl

# Final report
$formattedSize = Format-FileSize $totalSize
Write-Host "Final Report:"
Write-Host "Total .bigwig files found: $fileCount"
Write-Host "Total size of all files: $formattedSize"
