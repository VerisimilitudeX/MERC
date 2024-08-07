$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/"
$outputPath = "C:\Users\achar\Downloads\RoadmapEpigenomics_Subset"
$visitedUrls = New-Object System.Collections.Generic.HashSet[string]
$totalSize = 0
$fileCount = 0
$lastReportTime = Get-Date

# Define the subset of cell types and marks you want to download
$cellTypes = @("E001", "E002", "E003", "E004", "E005")
$marks = @("H3K27me3", "H3K36me3", "H3K4me1", "H3K4me3", "H3K27ac")

function Get-FilesRecursively($url) {
    if (-not $visitedUrls.Add($url)) {
        return
    }
    
    Write-Host "Scanning URL: $url"
    
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $links = $response.Links | Where-Object { $_.href -like "*.bigwig" -or $_.href -like "*/" }

        foreach ($link in $links) {
            $newUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
            if ($newUrl -like "*.bigwig") {
                $fileName = [System.IO.Path]::GetFileName($newUrl)
                if (($cellTypes | Where-Object { $fileName.StartsWith($_) }) -and
                    ($marks | Where-Object { $fileName.Contains($_) })) {
                    $fileSize = Get-RemoteFileSize $newUrl
                    $script:totalSize += $fileSize
                    $script:fileCount++
                    Download-File $newUrl
                    Report-Progress
                }
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

function Download-File($url) {
    $filePath = Join-Path $outputPath ($url -replace [regex]::Escape($baseUrl), "")
    $fileDir = Split-Path $filePath -Parent
    if (!(Test-Path $fileDir)) {
        New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
    }
    Write-Host "Downloading $url to $filePath"
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($url, $filePath)
        $fileInfo = Get-Item $filePath
        Write-Host "Downloaded: $($fileInfo.Name), Size: $($fileInfo.Length) bytes"
    }
    catch {
        Write-Host "Error downloading $url : $_"
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
Write-Host "Total .bigwig files downloaded: $fileCount"
Write-Host "Total size of all files: $formattedSize"
