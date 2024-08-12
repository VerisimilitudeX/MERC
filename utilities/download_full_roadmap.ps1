# Common settings
$outputPath = "E:\"
$logFile = Join-Path $outputPath "download_log.txt"
$stateFile = Join-Path $outputPath "download_state.json"

# Blueprint settings
$ftpServer = "ftp.ebi.ac.uk"
$ftpPath = "/pub/databases/blueprint/data/homo_sapiens/GRCh38/venous_blood/"
$blueprintPath = Join-Path $outputPath "blueprint"

# Roadmap settings
$roadmapBaseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$roadmapPath = Join-Path $outputPath "full"

# Create directories if they don't exist
New-Item -ItemType Directory -Path $blueprintPath -Force | Out-Null
New-Item -ItemType Directory -Path $roadmapPath -Force | Out-Null

# Function to save state
function Save-State($blueprintFiles, $roadmapUrls, $totalSize) {
    $state = @{
        BlueprintFiles = $blueprintFiles
        RoadmapUrls = $roadmapUrls
        TotalSize = $totalSize
    }
    $state | ConvertTo-Json | Set-Content $stateFile
}

# Function to load state
function Load-State {
    if (Test-Path $stateFile) {
        try {
            $state = Get-Content $stateFile | ConvertFrom-Json
            $blueprintFiles = if ($state.BlueprintFiles -is [array]) { $state.BlueprintFiles } else { @() }
            $visitedUrls = New-Object System.Collections.Generic.HashSet[string]
            if ($state.RoadmapUrls -is [array]) {
                foreach ($url in $state.RoadmapUrls) {
                    $visitedUrls.Add($url) | Out-Null
                }
            }
            $totalSize = if ($state.TotalSize -is [long]) { $state.TotalSize } else { 0 }
            return @($blueprintFiles, $visitedUrls, $totalSize)
        }
        catch {
            Log-Message "Error loading state file: $_"
        }
    }
    return @(@(), (New-Object System.Collections.Generic.HashSet[string]), 0)
}

function Log-Message($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    Write-Host $logMessage
    Add-Content $logFile $logMessage
}

# Blueprint download function
function Download-BlueprintFiles($currentPath, $downloadedFiles) {
    $ftpRequest = [System.Net.FtpWebRequest]::Create("ftp://$ftpServer$currentPath")
    $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
    $ftpRequest.UsePassive = $true
    $ftpRequest.UseBinary = $true
    $ftpRequest.KeepAlive = $false

    $response = $ftpRequest.GetResponse()
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    $directoryListing = $reader.ReadToEnd()
    $reader.Close()
    $response.Close()

    $items = $directoryListing -split "`r`n"

    foreach ($item in $items) {
        $tokens = $item -split "\s+"
        if ($tokens.Count -ge 9) {
            $name = $tokens[-1]
            $isDirectory = $tokens[0].StartsWith("d")

            if ($isDirectory) {
                $downloadedFiles = Download-BlueprintFiles "$currentPath$name/" $downloadedFiles
            } else {
                if ($name -match "\.(bam|bed|bigwig|wig)$") {
                    $ftpFilePath = "ftp://$ftpServer$currentPath$name"
                    $localFilePath = Join-Path $blueprintPath ($currentPath.TrimStart("/") + $name)

                    if (!(Test-Path (Split-Path $localFilePath))) {
                        New-Item -ItemType Directory -Path (Split-Path $localFilePath) -Force | Out-Null
                    }

                    if (!(Test-Path $localFilePath) -and $localFilePath -notin $downloadedFiles) {
                        Log-Message "Downloading Blueprint file: $name"
                        $webClient = New-Object System.Net.WebClient
                        $webClient.DownloadFile($ftpFilePath, $localFilePath)
                        $webClient.Dispose()

                        $fileInfo = Get-Item $localFilePath
                        $script:totalSize += $fileInfo.Length
                        $downloadedFiles += $localFilePath

                        Save-State $downloadedFiles $visitedUrls $script:totalSize
                    } else {
                        Log-Message "Blueprint file $name already downloaded. Skipping."
                    }
                }
            }
        }
    }
    return $downloadedFiles
}

# Roadmap download function
function Get-RoadmapFilesRecursively($url, $depth = 0) {
    if ($depth -gt 5 -or -not $visitedUrls.Add($url)) {
        return
    }

    Log-Message "Accessing Roadmap URL: $url (Depth: $depth)"

    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        $links = $response.Links | Where-Object { $_.href -ne $null }

        foreach ($link in $links) {
            $newUrl = [System.Uri]::new([System.Uri]$url, $link.href).AbsoluteUri
            Log-Message "Processing Roadmap link: $newUrl"

            if ($newUrl -like "*.bigwig") {
                Download-RoadmapFile $newUrl
            } elseif ($newUrl.StartsWith($roadmapBaseUrl) -and $newUrl -ne $url) {
                Get-RoadmapFilesRecursively $newUrl ($depth + 1)
            }
        }
    }
    catch {
        Log-Message "Error accessing Roadmap URL $url : $_"
    }
}

function Download-RoadmapFile($url) {
    $filePath = Join-Path $roadmapPath ($url -replace [regex]::Escape($roadmapBaseUrl), "")
    $fileDir = Split-Path $filePath -Parent
    if (!(Test-Path $fileDir)) {
        New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
    }

    if (Test-Path $filePath) {
        Log-Message "Roadmap file already exists: $filePath"
        return
    }

    Log-Message "Attempting to download Roadmap file: $url to $filePath"
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "PowerShell Script")

        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $webClient.DownloadFile($url, $filePath)
        $stopwatch.Stop()

        $fileInfo = Get-Item $filePath
        $script:totalSize += $fileInfo.Length
        $script:fileCount++

        $downloadSpeed = [math]::Round($fileInfo.Length / 1MB / $stopwatch.Elapsed.TotalSeconds, 2)
        Log-Message "Downloaded Roadmap file: $($fileInfo.Name), Size: $($fileInfo.Length) bytes, Time: $($stopwatch.Elapsed.TotalSeconds) seconds, Speed: $downloadSpeed MB/s"

        Save-State $blueprintFiles $visitedUrls $script:totalSize
    }
    catch {
        Log-Message "Error downloading Roadmap file $url : $_"
    }
    finally {
        if ($webClient) { $webClient.Dispose() }
    }
}

# Load previous state
$blueprintFiles, $visitedUrls, $totalSize = Load-State

# Start the download processes sequentially
Log-Message "Starting Blueprint download..."
$blueprintFiles = Download-BlueprintFiles $ftpPath $blueprintFiles

Log-Message "Starting Roadmap download..."
Get-RoadmapFilesRecursively $roadmapBaseUrl

$script:totalSize = (Get-ChildItem -Path $blueprintPath, $roadmapPath -Recurse | Measure-Object -Property Length -Sum).Sum
Write-Host "Download complete. Total size: $($script:totalSize / 1GB) GB"