$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$outputFolder = "E:\full\pval"

# Create the output folder if it doesn't exist
if (-not (Test-Path $outputFolder)) {
    New-Item -ItemType Directory -Path $outputFolder | Out-Null
}

function Download-Files($url) {
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    $links = $response.Links | Where-Object { $_.href -like "*.bigwig" }

    $jobs = @()

    foreach ($link in $links) {
        $fileUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
        $fileName = $link.href
        $outputPath = Join-Path $outputFolder $fileName

        Write-Host "Queuing download: $fileName"

        $job = Start-Job -ScriptBlock {
            param($fileUrl, $outputPath)
            try {
                Write-Output "Starting download: $($outputPath | Split-Path -Leaf)"
                $webClient = New-Object System.Net.WebClient
                $webClient.DownloadFile($fileUrl, $outputPath)
                Write-Output "Downloaded: $($outputPath | Split-Path -Leaf)"
            }
            catch {
                Write-Output "Error downloading $($outputPath | Split-Path -Leaf): $_"
            }
        } -ArgumentList $fileUrl, $outputPath

        $jobs += $job
    }

    $jobs | ForEach-Object {
        $_ | Wait-Job | Receive-Job | ForEach-Object {
            Write-Host $_
        }
    }
    $jobs | Remove-Job
}

# Start the download process
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Download-Files $baseUrl
$stopwatch.Stop()

Write-Host "Download process completed in $($stopwatch.Elapsed.TotalSeconds) seconds."