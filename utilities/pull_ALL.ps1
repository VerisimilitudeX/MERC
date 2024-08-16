$baseUrl = "https://epigenomesportal.ca/ihec/"
$outputDir = "C:\Your\Download\Directory"

if (!(Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir
}

$pageContent = Invoke-WebRequest -Uri "$baseUrl/download.html"

$fileLinks = Select-String -InputObject $pageContent.Content -Pattern '(?<=href=")([^"]+\.(gz|zip|txt))' -AllMatches | ForEach-Object { $_.Matches.Groups[1].Value }

foreach ($fileLink in $fileLinks) {
    $fileUrl = "$baseUrl$fileLink"
    $outputFile = Join-Path -Path $outputDir -ChildPath (Split-Path -Leaf $fileLink)
    Write-Host "Downloading $fileUrl to $outputFile..."
    Invoke-WebRequest -Uri $fileUrl -OutFile $outputFile
}
