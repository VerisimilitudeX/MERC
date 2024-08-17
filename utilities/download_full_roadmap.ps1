# Common settings
$outputPath = "E:\"
$stateFile = Join-Path $outputPath "download_state.json"

# FTP servers list
$ftpServers = @(
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/data/homo_sapiens/GRCh38/venous_blood/"; OutputDir = "blueprint_venous_blood"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/data_homo_sapiens/GRCh38/"; OutputDir = "blueprint_homo_sapiens"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/data/"; OutputDir = "blueprint_data"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/releases/"; OutputDir = "blueprint_releases"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/paper_data_sets/"; OutputDir = "blueprint_paper_data_sets"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/blueprint_Epivar/"; OutputDir = "blueprint_Epivar"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/blueprint_mouse/"; OutputDir = "blueprint_mouse"}
    @{Server = "ftp.ebi.ac.uk"; Path = "/pub/databases/blueprint/reference/"; OutputDir = "blueprint_reference"}
)

# Create directories if they don't exist
foreach ($server in $ftpServers) {
    New-Item -ItemType Directory -Path (Join-Path $outputPath $server.OutputDir) -Force | Out-Null
}

# Function to load the state of downloaded files
function Load-State {
    if (Test-Path $stateFile) {
        try {
            return (Get-Content $stateFile | ConvertFrom-Json) -as [hashtable]
        } catch {
            Write-Host "Error loading state file: $_"
            return @{}
        }
    } else {
        return @{}
    }
}

# Function to save the state of downloaded files
function Save-State($downloadedFiles) {
    $downloadedFiles | ConvertTo-Json | Set-Content $stateFile
}

# Function to download file with retry logic
function Download-File($url, $localPath, $maxRetries = 3) {
    if (Test-Path $localPath) {
        $ftpRequest = [System.Net.FtpWebRequest]::Create($url)
        $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::GetFileSize
        $ftpRequest.UseBinary = $true
        $ftpRequest.UsePassive = $true
        $ftpRequest.KeepAlive = $false

        try {
            $response = $ftpRequest.GetResponse()
            $remoteFileSize = $response.ContentLength
            $response.Close()

            $localFileSize = (Get-Item $localPath).Length
            if ($localFileSize -eq $remoteFileSize) {
                Write-Host "File already exists and has correct size: $localPath"
                return $true
            }
        } catch {
            Write-Host "Error checking remote file size: $_"
        }
    }

    $attempts = 0
    while ($attempts -lt $maxRetries) {
        try {
            $ftpRequest = [System.Net.FtpWebRequest]::Create($url)
            $ftpRequest.Method = [System.Net.WebRequestMethods+Ftp]::DownloadFile
            $ftpRequest.UseBinary = $true
            $ftpRequest.UsePassive = $true
            $ftpRequest.KeepAlive = $false

            $response = $ftpRequest.GetResponse()
            $responseStream = $response.GetResponseStream()
            $fileStream = [System.IO.File]::Create($localPath)
            $buffer = New-Object byte[] 8192
            $totalBytes = $response.ContentLength
            $totalRead = 0
            $read = 0

            while (($read = $responseStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $fileStream.Write($buffer, 0, $read)
                $totalRead += $read
                $percentComplete = [math]::Round(($totalRead / $totalBytes) * 100, 2)
                Write-Host "Downloading $($localPath): $percentComplete% complete ($([math]::Round($totalRead / 1MB, 2)) MB of $([math]::Round($totalBytes / 1MB, 2)) MB)"
            }

            $fileStream.Close()
            $responseStream.Close()
            Write-Host "Downloaded: $localPath"
            return $true
        } catch {
            Write-Host "Error downloading $url : $_"
            $attempts++
            if ($attempts -ge $maxRetries) {
                Write-Host "Failed to download $url after $maxRetries attempts."
                return $false
            }
            Start-Sleep -Seconds (5 * $attempts)  # Exponential backoff
        }
    }
}

# Function to get FTP directory listing
function Get-FtpDirectoryListing($server, $path) {
    try {
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
    } catch {
        Write-Host "Error accessing FTP directory $server$path : $_"
        return @()  # Return an empty array on error
    }
}

# Function to process FTP directory
function Process-FtpDirectory($server, $currentPath, $outputDir, $downloadedFiles) {
    $items = Get-FtpDirectoryListing $server $currentPath
    foreach ($item in $items) {
        $tokens = $item -split "\s+"
        if ($tokens.Count -ge 9) {
            $name = $tokens[-1]
            $isDirectory = $tokens[0].StartsWith("d")
            if ($isDirectory) {
                Process-FtpDirectory $server "$currentPath$name/" $outputDir $downloadedFiles
            } else {
                $ftpFilePath = "ftp://$($server)$currentPath$name"
                $localFilePath = Join-Path $outputPath $outputDir ($currentPath.TrimStart("/") + $name)
                $localDir = Split-Path $localFilePath
                if (-not (Test-Path $localDir)) {
                    New-Item -ItemType Directory -Path $localDir -Force | Out-Null
                }
                if (-not $downloadedFiles.ContainsKey($localFilePath)) {
                    if (Download-File $ftpFilePath $localFilePath) {
                        $downloadedFiles[$localFilePath] = $true
                        Save-State $downloadedFiles
                    }
                }
            }
        }
    }
}

# Main execution
$downloadedFiles = Load-State
if (-not $downloadedFiles) {
    $downloadedFiles = @{}
}
foreach ($server in $ftpServers) {
    try {
        Process-FtpDirectory $server.Server $server.Path $server.OutputDir $downloadedFiles
    } catch {
        Write-Host "Error processing server $($server.Server): $_"
        $continue = Read-Host "Do you want to continue with the next server? (Y/N)"
        if ($continue -ne "Y") { break }
    }
}