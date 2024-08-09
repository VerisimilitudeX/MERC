$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$outputFolder = "/Volumes/T9/full”

# Create the output folder if it doesn't exist
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

function Download-Files($url) {
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    $links = $response.Links | Where-Object { $_.href -like "*.bigwig" }

    foreach ($link in $links) {
        $fileUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
        $fileName = $link.href
        $outputPath = Join-Path $outputFolder $fileName

        Write-Host "Downloading: $fileName"
        try {
            Invoke-WebRequest -Uri $fileUrl -OutFile $outputPath
            Write-Host "Downloaded: $fileName"
        }
        catch {
            Write-Host "Error downloading $fileName : $_"
        }
    }
}

# Start the download process
Download-Files $baseUrl

Write-Host "Download process completed."