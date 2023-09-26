
function DisplayUsage {
    Write-Host "Usage: .\CompressFolders.ps1 [-TargetFolder <PathToFolder>] [-DefaultAction <Overwrite|Update|Skip|Keep>]"
    Write-Host "Example: .\CompressFolders.ps1 -TargetFolder C:\MyFolders -DefaultAction Overwrite"
    exit
}

# Determine target folder
if (-not $TargetFolder) {
    $TargetFolder = Read-Host "Please enter the path to the target folder"
}

# Navigate to the target folder
Push-Location
Set-Location -Path $TargetFolder

# Gather a list of folders that have "packaged" in their name
$foldersToCompress = Get-ChildItem -Directory | Where-Object { $_.Name -like '*packaged*' }

# If no default action is provided, display the usage legend
if (-not $DefaultAction) {
    DisplayUsage
}

# Count the number of existing archives
$existingArchivesCount = ($foldersToCompress | Where-Object { Test-Path "$($_.Name).zip" }).Count

# Using the ForEach-Object -Parallel construct to compress the folders in parallel
$foldersToCompress | ForEach-Object -Parallel {
    param (
        $_,
        $defaultAction
    )

    $archiveName = "$($_.Name).zip"

    if (Test-Path $archiveName) {
        switch ($defaultAction) {
            "Overwrite" {
                Remove-Item -Path $archiveName -Force
                Compress-Archive -Path $_.FullName -DestinationPath $archiveName
            }
            "Update" {
                # Update the existing archive with new/changed files
                $tempFolder = New-Item -Path ([System.IO.Path]::GetTempPath()) -Name ([System.IO.Path]::GetRandomFileName()) -ItemType Directory
                Expand-Archive -Path $archiveName -DestinationPath $tempFolder
                Get-ChildItem -Path $_.FullName -Recurse | Copy-Item -Destination $tempFolder -Recurse -Force
                Compress-Archive -Path $tempFolder\* -DestinationPath $archiveName -Force
                Remove-Item -Path $tempFolder -Recurse -Force
            }
            "Skip" {
                # Do nothing, skip this folder
            }
            "Keep" {
                # Rename the existing archive and create a new one
                $counter = 1
                while (Test-Path ("$($_.Name)($counter).zip")) {
                    $counter++
                }
                Rename-Item -Path $archiveName -NewName "$($_.Name)($counter).zip"
                Compress-Archive -Path $_.FullName -DestinationPath $archiveName
            }
            default {
                Compress-Archive -Path $_.FullName -DestinationPath $archiveName
            }
        }
    } else {
        Compress-Archive -Path $_.FullName -DestinationPath $archiveName
    }
} -ArgumentList $defaultAction -ThrottleLimit $env:NUMBER_OF_PROCESSORS
