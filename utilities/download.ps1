$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$outputPath = "C:\Users\achar\Downloads"
$visitedUrls = @{}
$maxDepth = 5

function Get-FilesRecursively($url, $depth = 0) {
    if ($depth -gt $maxDepth) {
        Write-Host "Max depth reached for $url"
        return
    }
    
    if ($visitedUrls.ContainsKey($url)) {
        Write-Host "Already visited $url"
        return
    }
    
    $visitedUrls[$url] = $true
    Write-Host "Accessing URL: $url (Depth: $depth)"
    
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $links = $response.Links | Where-Object { $_.href -notlike "javascript:*" -and $_.href -notlike "mailto:*" }

        foreach ($link in $links) {
            $newUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
            if ($newUrl -like "*.bigwig") {
                $filePath = Join-Path $outputPath ($newUrl -replace [regex]::Escape($baseUrl), "")
                $fileDir = Split-Path $filePath -Parent
                if (!(Test-Path $fileDir)) {
                    New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
                }
                Write-Host "Attempting to download: $newUrl to $filePath"
                try {
                    $webClient = New-Object System.Net.WebClient
                    $webClient.DownloadFile($newUrl, $filePath)
                    $fileInfo = Get-Item $filePath
                    Write-Host "Downloaded: $($fileInfo.Name), Size: $($fileInfo.Length) bytes"
                }
                catch {
                    Write-Host "Error downloading $newUrl : $_"
                }
                finally {
                    if ($webClient) { $webClient.Dispose() }
                }
            } elseif ($newUrl -like "$baseUrl*") {
                Get-FilesRecursively $newUrl ($depth + 1)
            }
        }
    }
    catch {
        Write-Host "Error accessing $url : $_"
    }
}

Get-FilesRecursively $baseUrl
