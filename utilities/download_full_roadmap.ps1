$baseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$outputPath = "E:\full\"
$logFile = Join-Path $outputPath "check_files_log.txt"

function Log-Message($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    Write-Host $logMessage
    Add-Content $logFile $logMessage
}

function Check-Files {
    $webClient = New-Object System.Net.WebClient
    $htmlContent = $webClient.DownloadString($baseUrl)
    $pattern = 'href="([^"]+\.bigwig)"'
    $matches = [regex]::Matches($htmlContent, $pattern)

    $totalFiles = $matches.Count
    $missingFiles = @()
    $incompleteFiles = @()

    foreach ($match in $matches) {
        $fileName = $match.Groups[1].Value
        $filePath = Join-Path $outputPath $fileName
        
        if (Test-Path $filePath) {
            $localFile = Get-Item $filePath
            $remoteFileSize = [long]($webClient.GetResponse("$baseUrl$fileName").ContentLength)

            if ($localFile.Length -ne $remoteFileSize) {
                $incompleteFiles += $fileName
                Log-Message "File $fileName is incomplete. Local size: $($localFile.Length) bytes, Remote size: $remoteFileSize bytes"
            }
        } else {
            $missingFiles += $fileName
            Log-Message "File $fileName is missing"
        }
    }

    Log-Message "Total files: $totalFiles"
    Log-Message "Missing files: $($missingFiles.Count)"
    Log-Message "Incomplete files: $($incompleteFiles.Count)"

    if ($missingFiles.Count -gt 0) {
        Log-Message "Missing files:"
        $missingFiles | ForEach-Object { Log-Message "- $_" }
    }

    if ($incompleteFiles.Count -gt 0) {
        Log-Message "Incomplete files:"
        $incompleteFiles | ForEach-Object { Log-Message "- $_" }
    }
}

Check-Files
