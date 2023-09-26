
param (
    [string]$TargetFolder,
    [string]$DefaultAction
)

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

# If 3 or more archives exist, offer the user the option to bulk-select an action
$existingArchivesCount = ($foldersToCompress | Where-Object { Test-Path "$($_.Name).zip" }).Count
if ($existingArchivesCount -ge 3 -and (-not $DefaultAction)) {
    $bulkChoice = $true
    $DefaultAction = Read-Host "Multiple existing archives detected. Would you like to [B]ulk-select an action or be [P]rompted for each? (B/P)"
    if ($DefaultAction -eq "B") {
        $DefaultAction = Read-Host "Choose a default action: [O]verwrite, [U]pdate, [S]kip, [K]eep"
    } else {
        $DefaultAction = $null
    }
}

# Parallel compression logic
$foldersToCompress | ForEach-Object -Parallel {
    param (
        $_,
        $defaultAction
    )

    $archiveName = "$($_.Name).zip"

    if (Test-Path $archiveName) {
        if (-not $defaultAction) {
            $defaultAction = Read-Host "Archive $archiveName already exists. Choose an action: [O]verwrite, [U]pdate, [S]kip, [K]eep"
        }

        switch ($defaultAction) {
            "O" {
                Remove-Item -Path $archiveName -Force
                Compress-Archive -Path $_.FullName -DestinationPath $archiveName
            }
            "U" {
                # Update the existing archive with new/changed files
                $tempFolder = New-Item -Path ([System.IO.Path]::GetTempPath()) -Name ([System.IO.Path]::GetRandomFileName()) -ItemType Directory
                Expand-Archive -Path $archiveName -DestinationPath $tempFolder
                Get-ChildItem -Path $_.FullName -Recurse | Copy-Item -Destination $tempFolder -Recurse -Force
                Compress-Archive -Path $tempFolder\* -DestinationPath $archiveName -Force
                Remove-Item -Path $tempFolder -Recurse -Force
            }
            "S" {
                # Do nothing, skip this folder
            }
            "K" {
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
} -ArgumentList $DefaultAction -ThrottleLimit $env:NUMBER_OF_PROCESSORS

# Return to the original directory
Pop-Location
