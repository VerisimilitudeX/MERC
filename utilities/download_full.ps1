$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/"
$outputPath = "C:\Users\achar\OneDrive\Documents\GitHub\merc\data\subset"
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
        $links = $response.Links | Where-Object { $_.href -like "*.bigwig" -or $_.href -like "*/" }

        foreach ($link in $links) {
            $newUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
            if ($newUrl -like "*.bigwig") {
                $fileSize = Get-RemoteFileSize $newUrl
                $script:totalSize += $fileSize
                $script:fileCount++git lfs push --all
                Download-File $newUrl
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

# The rest of the functions (Get-RemoteFileSize, Download-File, Format-FileSize, Report-Progress) 
# remain the same as in the subset script

# Start the recursive search
Get-FilesRecursively $baseUrl

# Final report
$formattedSize = Format-FileSize $totalSize
Write-Host "Final Report:"
Write-Host "Total .bigwig files downloaded: $fileCount"
Write-Host "Total size of all files: $formattedSize"
