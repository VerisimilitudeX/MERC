# Common settings
$outputPath = "E:\"
$logFile = Join-Path $outputPath "download_log.txt"
$stateFile = Join-Path $outputPath "download_state.json"

# FTP servers list
$ftpServers = @(
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/data/homo_sapiens/GRCh38/venous_blood/"; OutputDir = "blueprint_venous_blood"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/data/homo_sapiens/GRCh38/"; OutputDir = "blueprint_homo_sapiens"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/data/"; OutputDir = "blueprint_data"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/releases/"; OutputDir = "blueprint_releases"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/paper_data_sets/"; OutputDir = "blueprint_paper_data_sets"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/blueprint_Epivar/"; OutputDir = "blueprint_Epivar"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/blueprint_mouse/"; OutputDir = "blueprint_mouse"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/reference/"; OutputDir = "blueprint_reference"}
)

# Roadmap settings
$roadmapBaseUrl = "http://egg2.wustl.edu/roadmap/data/byFileType/signal/consolidated/macs2signal/foldChange/"
$roadmapPath = Join-Path $outputPath "full"

# Create directories if they don't exist
foreach ($server in $ftpServers) {
    New-Item -ItemType Directory -Path (Join-Path $outputPath $server.OutputDir) -Force | Out-Null
}
New-Item -ItemType Directory -Path $roadmapPath -Force | Out-Null

# Global variables for progress tracking
$script:totalFiles = 0
$script:downloadedFiles = 0
$script:totalSize = 0
$script:startTime = Get-Date

# Function to save state
function Save-State($downloadedFiles, $visitedUrls, $totalSize) {
    $state = @{
        DownloadedFiles = $downloadedFiles
        VisitedUrls = $visitedUrls
        TotalSize = $totalSize
    }
    $state | ConvertTo-Json | Set-Content $stateFile
}

# Function to load state
function Load-State {
    if (Test-Path $stateFile) {
        try {
            $state = Get-Content $stateFile | ConvertFrom-Json
            $downloadedFiles = @{}
            if ($state.DownloadedFiles -is [PSCustomObject]) {
                $state.DownloadedFiles.PSObject.Properties | ForEach-Object { $downloadedFiles[$_.Name] = $_.Value }
            }
            $visitedUrls = New-Object System.Collections.Generic.HashSet[string]
            if ($state.VisitedUrls -is [array]) {
                foreach ($url in $state.VisitedUrls) {
                    $visitedUrls.Add($url) | Out-Null
                }
            }
            $totalSize = if ($state.TotalSize -is [long]) { $state.TotalSize } else { 0 }
            return @($downloadedFiles, $visitedUrls, $totalSize)
        }
        catch {
            Log-Message "Error loading state file: $_"
        }
    }
    return @(@{}, (New-Object System.Collections.Generic.HashSet[string]), 0)
}

function Log-Message($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    Write-Host $logMessage
    Add-Content $logFile $logMessage
}

function Log-Progress {
    $currentTime = Get-Date
    $elapsedTime = ($currentTime - $script:startTime).TotalSeconds
    $percentComplete = if ($script:totalFiles -gt 0) { ($script:downloadedFiles / $script:totalFiles) * 100 } else { 0 }
    $downloadSpeed = if ($elapsedTime -gt 0) { $script:totalSize / $elapsedTime / 1MB } else { 0 }
    $estimatedTimeRemaining = if ($downloadSpeed -gt 0) { ($script:totalFiles - $script:downloadedFiles) / ($script:downloadedFiles / $elapsedTime) } else { 0 }
    $logMessage = "Progress: $($script:downloadedFiles) / $($script:totalFiles) files | " +
                  "$($percentComplete.ToString("F2"))% complete | " +
                  "Speed: $($downloadSpeed.ToString("F2")) MB/s | " +
                  "ETA: $($estimatedTimeRemaining.ToString("F2")) seconds"
    Write-Host $logMessage
    Add-Content $logFile $logMessage
}

# Function to get FTP directory listing
function Get-FtpDirectoryListing($server, $path) {
    $ftpRequest = [System.Net.FtpWebRequest]::Create("ftp://$($server)$path")
    $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::ListDirectoryDetails
    $ftpRequest.UsePassive = $true
    $ftpRequest.UseBinary = $true
    $ftpRequest.KeepAlive = $false
    $response = $ftpRequest.GetResponse()
    $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
    $directoryListing = $reader.ReadToEnd()
    $reader.Close()
    $response.Close()
    return $directoryListing -split "`r`n"
}

# Function to process FTP directory
function Process-FtpDirectory($server, $currentPath, $outputDir, $downloadedFiles, $downloadQueue) {
    $items = Get-FtpDirectoryListing $server $currentPath
    foreach ($item in $items) {
        $tokens = $item -split "\s+"
        if ($tokens.Count -ge 9) {
            $name = $tokens[-1]
            $isDirectory = $tokens[0].StartsWith("d")
            if ($isDirectory) {
                Process-FtpDirectory $server "$currentPath$name/" $outputDir $downloadedFiles $downloadQueue
            } else {
                if ($name -match "\.(bam|bed|bigwig|wig)$") {
                    $script:totalFiles++
                    $ftpFilePath = "ftp://$($server)$currentPath$name"
                    $localFilePath = Join-Path $outputPath $outputDir ($currentPath.TrimStart("/") + $name)
                    if (!(Test-Path (Split-Path $localFilePath))) {
                        New-Item -ItemType Directory -Path (Split-Path $localFilePath) -Force | Out-Null
                    }
                    if (!(Test-Path $localFilePath) -and !$downloadedFiles.ContainsKey($localFilePath)) {
                        $downloadQueue.Enqueue(@{
                            Url = $ftpFilePath
                            LocalPath = $localFilePath
                            Type = "FTP"
                        })
                    } else {
                        $script:downloadedFiles++
                        Log-Progress
                    }
                }
            }
        }
    }
}

# Roadmap download function
function Get-RoadmapFilesRecursively($url, $depth = 0, $visitedUrls, $downloadQueue) {
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
                $script:totalFiles++
                $filePath = Join-Path $roadmapPath ($newUrl -replace [regex]::Escape($roadmapBaseUrl), "")
                if (!(Test-Path $filePath)) {
                    $downloadQueue.Enqueue(@{
                        Url = $newUrl
                        LocalPath = $filePath
                        Type = "Roadmap"
                    })
                } else {
                    $script:downloadedFiles++
                    Log-Progress
                }
            } elseif ($newUrl.StartsWith($roadmapBaseUrl) -and $newUrl -ne $url) {
                Get-RoadmapFilesRecursively $newUrl ($depth + 1) $visitedUrls $downloadQueue
            }
        }
    }
    catch {
        Log-Message "Error accessing Roadmap URL $url : $_"
    }
}

# Function to download file
function Download-File($url, $localPath) {
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "PowerShell Script")
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $webClient.DownloadFile($url, $localPath)
        $stopwatch.Stop()
        $fileInfo = Get-Item $localPath
        $downloadSpeed = [math]::Round($fileInfo.Length / 1MB / $stopwatch.Elapsed.TotalSeconds, 2)
        Log-Message "Downloaded: $($fileInfo.Name), Size: $($fileInfo.Length) bytes, Time: $($stopwatch.Elapsed.TotalSeconds) seconds, Speed: $downloadSpeed MB/s"
        $script:downloadedFiles++
        $script:totalSize += $fileInfo.Length
        Log-Progress
        return $true
    }
    catch {
        Log-Message "Error downloading $url : $_"
        return $false
    }
    finally {
        if ($webClient) { $webClient.Dispose() }
    }
}

# Main execution
$downloadedFiles, $visitedUrls, $script:totalSize = Load-State
$downloadQueue = New-Object System.Collections.Queue

# Queue FTP downloads
foreach ($server in $ftpServers) {
    Process-FtpDirectory $server.Server $server.Path $server.OutputDir $downloadedFiles $downloadQueue
}

# Queue Roadmap downloads
Get-RoadmapFilesRecursively $roadmapBaseUrl 0 $visitedUrls $downloadQueue

Log-Message "Total files to download: $($script:totalFiles)"

# Set up runspace pool for parallel downloads
$maxConcurrentDownloads = 10
$runspacePool = [runspacefactory]::CreateRunspacePool(1, $maxConcurrentDownloads)
$runspacePool.Open()
$runspaces = @()

# Process download queue
while ($downloadQueue.Count -gt 0 -or $runspaces.Count -gt 0) {
    # Start new downloads
    while ($runspaces.Count -lt $maxConcurrentDownloads -and $downloadQueue.Count -gt 0) {
        $download = $downloadQueue.Dequeue()
        $powershell = [powershell]::Create().AddScript({
            param($url, $localPath)
            try {
                $webClient = New-Object System.Net.WebClient
                $webClient.Headers.Add("User-Agent", "PowerShell Script")
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $webClient.DownloadFile($url, $localPath)
                $stopwatch.Stop()
                $fileInfo = Get-Item $localPath
                return @{
                    Success = $true
                    Size = $fileInfo.Length
                    Time = $stopwatch.Elapsed.TotalSeconds
                    Path = $localPath
                }
            }
            catch {
                return @{
                    Success = $false
                    Error = $_.Exception.Message
                    Path = $localPath
                }
            }
            finally {
                if ($webClient) { $webClient.Dispose() }
            }
        }).AddArgument($download.Url).AddArgument($download.LocalPath)
        $powershell.RunspacePool = $runspacePool
        $runspaces += @{
            Powershell = $powershell
            AsyncResult = $powershell.BeginInvoke()
        }
    }

    # Check for completed downloads
    $completedRunspaces = @($runspaces | Where-Object { $_.AsyncResult.IsCompleted })
    foreach ($runspace in $completedRunspaces) {
        $result = $runspace.Powershell.EndInvoke($runspace.AsyncResult)
        if ($result.Success) {
            $script:totalSize += $result.Size
            $downloadedFiles[$result.Path] = $true
            $script:downloadedFiles++
            $downloadSpeed = [math]::Round($result.Size / 1MB / $result.Time, 2)
            Log-Message "Downloaded: $($result.Path), Size: $($result.Size) bytes, Time: $($result.Time) seconds, Speed: $downloadSpeed MB/s"
        } else {
            Log-Message "Error downloading $($result.Path): $($result.Error)"
        }
        $runspace.Powershell.Dispose()
    }
    $runspaces = @($runspaces | Where-Object { -not $_.AsyncResult.IsCompleted })

    # Save state periodically
    Save-State $downloadedFiles $visitedUrls $script:totalSize
    Log-Progress
    Start-Sleep -Milliseconds 1000
}

$runspacePool.Close()
$runspacePool.Dispose()

Write-Host "Download complete. Total size: $($script:totalSize / 1GB) GB"