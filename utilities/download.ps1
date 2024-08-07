$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$outputPath = "C:\Users\achar\Downloads"
$visitedUrls = New-Object System.Collections.Generic.HashSet[string]
$maxDepth = 5
$totalSize = 0
$filesToDownload = @()

function Get-FilesRecursively($url, $depth = 0) {
    if ($depth -gt $maxDepth -or -not $visitedUrls.Add($url)) {
        return
    }
    
    Write-Host "Scanning URL: $url (Depth: $depth)"
    
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $links = $response.Links | Where-Object { $_.href -notlike "javascript:*" -and $_.href -notlike "mailto:*" }

        foreach ($link in $links) {
            $newUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
            if ($newUrl -like "*.bigwig") {
                $fileSize = Get-RemoteFileSize $newUrl
                $script:totalSize += $fileSize
                $script:filesToDownload += @{Url = $newUrl; Size = $fileSize}
                Write-Host "Found .bigwig file: $newUrl (Size: $fileSize bytes)"
            } elseif ($newUrl -like "$baseUrl*") {
                Get-FilesRecursively $newUrl ($depth + 1)
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

# Scan for files and calculate total size
Get-FilesRecursively $baseUrl

# Display total size for 10 seconds
$formattedSize = Format-FileSize $totalSize
Write-Host "Total size of files to download: $formattedSize"
Write-Host "Number of files to download: $($filesToDownload.Count)"
Write-Host "Waiting for 10 seconds before starting download..."
Start-Sleep -Seconds 10

# Now proceed with downloading
foreach ($file in $filesToDownload) {
    $filePath = Join-Path $outputPath ($file.Url -replace [regex]::Escape($baseUrl), "")
    $fileDir = Split-Path $filePath -Parent
    if (!(Test-Path $fileDir)) {
        New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
    }
    Write-Host "Downloading $($file.Url) to $filePath"
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.DownloadFile($file.Url, $filePath)
        $fileInfo = Get-Item $filePath
        Write-Host "Downloaded: $($fileInfo.Name), Size: $($fileInfo.Length) bytes"
    }
    catch {
        Write-Host "Error downloading $($file.Url) : $_"
    }
    finally {
        if ($webClient) { $webClient.Dispose() }
    }
}
