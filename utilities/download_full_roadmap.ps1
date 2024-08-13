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

# Create directories if they don't exist
foreach ($server in $ftpServers) {
    New-Item -ItemType Directory -Path (Join-Path $outputPath $server.OutputDir) -Force | Out-Null
}

# Function to download file with progress
function Download-File($url, $localPath) {
    try {
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", "PowerShell Script")

        # Progress callback
        $webClient.DownloadProgressChanged += {
            param($sender, $e)
            Write-Host "Downloading $($localPath): $($e.ProgressPercentage)% complete ($($e.BytesReceived / 1MB) MB of $($e.TotalBytesToReceive / 1MB) MB)"
        }

        $webClient.DownloadFile($url, $localPath)
        Write-Host "Downloaded: $localPath"
    } catch {
        Write-Host "Error downloading $url : $_"
    } finally {
        if ($webClient) { $webClient.Dispose() }
    }
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
function Process-FtpDirectory($server, $currentPath, $outputDir) {
    $items = Get-FtpDirectoryListing $server $currentPath
    foreach ($item in $items) {
        $tokens = $item -split "\s+"
        if ($tokens.Count -ge 9) {
            $name = $tokens[-1]
            $isDirectory = $tokens[0].StartsWith("d")
            if ($isDirectory) {
                Process-FtpDirectory $server "$currentPath$name/" $outputDir
            } else {
                $ftpFilePath = "ftp://$($server)$currentPath$name"
                $localFilePath = Join-Path $outputPath $outputDir ($currentPath.TrimStart("/") + $name)
                New-Item -ItemType Directory -Path (Split-Path $localFilePath) -Force | Out-Null
                Download-File $ftpFilePath $localFilePath
            }
        }
    }
}

# Main execution
foreach ($server in $ftpServers) {
    Process-FtpDirectory $server.Server $server.Path $server.OutputDir
}
