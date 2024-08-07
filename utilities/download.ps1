$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$outputPath = "C:\Users\achar\OneDrive\Documents\GitHub\merc\data"

function Get-FilesRecursively($url) {
    $response = Invoke-WebRequest -Uri $url
    $links = $response.Links | Where-Object { $_.href -like "*.bigwig" -or $_.href -like "*/" }

    foreach ($link in $links) {
        $newUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
        if ($link.href -like "*/") {
            Get-FilesRecursively $newUrl
        } elseif ($link.href -like "*.bigwig") {
            $filePath = Join-Path $outputPath ($newUrl -replace [regex]::Escape($baseUrl), "")
            $fileDir = Split-Path $filePath -Parent
            if (!(Test-Path $fileDir)) {
                New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
            }
            Write-Host "Downloading $newUrl to $filePath"
            Invoke-WebRequest -Uri $newUrl -OutFile $filePath
        }
    }
}

Get-FilesRecursively $baseUrl
