# Define main directories
$mainDir = "E:\"
$blueprintDir = Join-Path $mainDir "Blueprint"
$roadmapDir = Join-Path $mainDir "Roadmap"
$tcgaDir = Join-Path $mainDir "TCGA"
$otherDir = Join-Path $mainDir "Other"
$logsDir = Join-Path $mainDir "Logs"

# Create main directories
@($blueprintDir, $roadmapDir, $tcgaDir, $otherDir, $logsDir) | ForEach-Object {
    if (!(Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ | Out-Null
    }
}

# Move Blueprint folders
Get-ChildItem $mainDir -Directory | Where-Object { $_.Name -like "blueprint*" } | ForEach-Object {
    Move-Item $_.FullName $blueprintDir -Force
}

# Move Roadmap folders
Move-Item (Join-Path $mainDir "full") $roadmapDir -Force
Move-Item (Join-Path $mainDir "roadmapepigenomics") $roadmapDir -Force

# Move TCGA folder
Move-Item (Join-Path $mainDir "TCGA") $tcgaDir -Force

# Move other folders
Move-Item (Join-Path $mainDir "subset") $otherDir -Force

# Move log files
Move-Item (Join-Path $mainDir "download_log.txt") $logsDir -Force
Move-Item (Join-Path $mainDir "download_state.json") $logsDir -Force

Write-Host "Cleanup complete. Please review the changes."
