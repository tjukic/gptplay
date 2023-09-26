
param (
    [Parameter(Mandatory=$false)]
    [string]$folderPath,

    [Parameter(Mandatory=$false)]
    [ValidateSet("Overwrite", "Update", "Skip", "Keep")]
    [string]$defaultAction
)

# Function to display a usage legend
function DisplayUsage {
    Write-Output "Usage: ./YourScriptName.ps1 [-folderPath path_to_target_folder] [-defaultAction Overwrite|Update|Skip|Keep]"
    Write-Output ""
    Write-Output "Options:"
    Write-Output "  -folderPath        : Path to the target folder to process. If not provided, you will be prompted."
    Write-Output "  -defaultAction     : Action to take when an existing archive is found. Options are:"
    Write-Output "                        Overwrite - Overwrite the existing archive."
    Write-Output "                        Update    - Update the existing archive with new/changed files."
    Write-Output "                        Skip      - Skip compressing this folder."
    Write-Output "                        Keep      - Keep all versions by appending a number."
    Write-Output "                        If not provided, you will be prompted for each existing archive."
    Write-Output ""
}

# If no folderPath is provided, display usage and prompt for folderPath
if (-not $folderPath) {
    DisplayUsage
    $folderPath = Read-Host "Please enter the path to the target folder"
}

# Function to get a unique archive name by appending a number
function GetUniqueArchiveName($baseName) {
    $counter = 1
    while (Test-Path ("$baseName($counter).zip")) {
        $counter++
    }
    return "$baseName($counter).zip"
}

# Function to prompt the user for action
function PromptForAction($archiveName) {
    if ($defaultAction) {
        switch ($defaultAction) {
            "Overwrite" { return 0 }
            "Update"    { return 1 }
            "Skip"      { return 2 }
            "Keep"      { return 3 }
        }
    } else {
        $choices = @(
            [System.Management.Automation.Host.ChoiceDescription]::new("&Overwrite", "Overwrite the existing archive.")
            [System.Management.Automation.Host.ChoiceDescription]::new("&Update", "Update the existing archive with new/changed files.")
            [System.Management.Automation.Host.ChoiceDescription]::new("&Skip", "Skip compressing this folder.")
            [System.Management.Automation.Host.ChoiceDescription]::new("&Keep", "Keep all versions by appending a number.")
        )

        $decision = $host.ui.PromptForChoice("Existing Archive Found: $archiveName", "Choose an action:", $choices, 0)
        return $decision
    }
}

# Store the original location
$originalLocation = Get-Location

# Navigate to the specified folder
Set-Location -Path $folderPath

# Get all subfolders with 'packaged' in their name or named 'packaged'
$foldersToCompress = Get-ChildItem | Where-Object { ($_.PSIsContainer) -and ($_.Name -like '*packaged*') }


# Count the number of existing archives
$existingArchivesCount = ($foldersToCompress | Where-Object { Test-Path "$($_.Name).zip" }).Count

# If there are 3 or more existing archives, prompt the user for a default action
if ($existingArchivesCount -ge 3 -and (-not $defaultAction)) {
    $choices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new("&Overwrite", "Overwrite all existing archives.")
        [System.Management.Automation.Host.ChoiceDescription]::new("&Update", "Update all existing archives with new/changed files.")
        [System.Management.Automation.Host.ChoiceDescription]::new("&Skip", "Skip compressing all folders with existing archives.")
        [System.Management.Automation.Host.ChoiceDescription]::new("&Keep", "Keep all versions of all existing archives by appending a number.")
    )

    $decision = $host.ui.PromptForChoice("Multiple Existing Archives Found", "Choose a default action:", $choices, 0)
    switch ($decision) {
        0 { $defaultAction = "Overwrite" }
        1 { $defaultAction = "Update" }
        2 { $defaultAction = "Skip" }
        3 { $defaultAction = "Keep" }
    }
}

# Count the number of existing archives
$existingArchivesCount = ($foldersToCompress | Where-Object { Test-Path "$($_.Name).zip" }).Count

# If there are 3 or more existing archives and no defaultAction is provided, prompt the user for a default action
if ($existingArchivesCount -ge 3 -and (-not $defaultAction)) {
    $choices = @(
        [System.Management.Automation.Host.ChoiceDescription]::new("&Overwrite All", "Overwrite all existing archives.")
        [System.Management.Automation.Host.ChoiceDescription]::new("&Update All", "Update all existing archives with new/changed files.")
        [System.Management.Automation.Host.ChoiceDescription]::new("&Skip All", "Skip compressing all folders with existing archives.")
        [System.Management.Automation.Host.ChoiceDescription]::new("&Keep All", "Keep all versions of all existing archives by appending a number.")
        [System.Management.Automation.Host.ChoiceDescription]::new("&Prompt Individually", "Prompt for each individual archive.")
    )

    $decision = $host.ui.PromptForChoice("Multiple Existing Archives Found", "Choose a default action or opt to be prompted for each archive:", $choices, 0)
    switch ($decision) {
        0 { $defaultAction = "Overwrite" }
        1 { $defaultAction = "Update" }
        2 { $defaultAction = "Skip" }
        3 { $defaultAction = "Keep" }
        4 { $defaultAction = $null }
    }
}
# Compress each folder
foreach ($folder in $foldersToCompress) {
    $archiveName = "$($folder.Name).zip"

    # Check if folder is empty
    if (-not (Get-ChildItem -Path $folder.FullName)) {
        Write-Output "Skipped compressing $folder as it is empty."
        continue
    }

    # Check if the archive already exists
    if (Test-Path $archiveName) {
        $action = PromptForAction $archiveName
        switch ($action) {
            0 { # Overwrite
                Remove-Item -Path $archiveName -Force
                Compress-Archive -Path $folder.FullName -DestinationPath $archiveName -CompressionLevel Optimal
                Write-Output "Overwrote $archiveName with compressed contents of $folder."
            }
            1 { # Update
                # Temporarily extract the existing archive to a temp folder
                $tempPath = Join-Path $folderPath ("temp_" + $folder.Name)
                Expand-Archive -Path $archiveName -DestinationPath $tempPath
                # Copy the contents of the current folder into the temp folder
                Copy-Item -Path $folder.FullName\* -Destination $tempPath -Recurse
                # Re-compress the temp folder into the archive
                Compress-Archive -Path $tempPath -DestinationPath $archiveName -CompressionLevel Optimal -Force
                # Remove the temp folder
                Remove-Item -Path $tempPath -Recurse -Force
                Write-Output "Updated $archiveName with contents of $folder."
            }
            2 { # Skip
                Write-Output "Skipped compressing $folder."
            }
            3 { # Keep
                $archiveName = GetUniqueArchiveName $folder.Name
                Compress-Archive -Path $folder.FullName -DestinationPath $archiveName -CompressionLevel Optimal
                Write-Output "Compressed $folder into $archiveName without overwriting existing archives."
            }
        }
    }
    else {
        Compress-Archive -Path $folder.FullName -DestinationPath $archiveName -CompressionLevel Optimal
        Write-Output "Compressed $folder into $archiveName."
    }
}

# Return to the original location
Set-Location -Path $originalLocation
