@echo off

for /f %%a in ('type "%~0" ^| find /c /v ""') do set TotalLines=%%a
for /f "tokens=1,* delims=:" %%a in ('findstr /n /c:":PATCHER" "%~0"') do set StartLine=%%a
for /f "skip=%StartLine% delims=" %%i in ('type "%~0"') do (
    echo %%i >> patcher.ps1
)

powershell.exe -ExecutionPolicy Bypass -File patcher.ps1
pause
goto :eof

:PATCHER
Add-Type -AssemblyName System.Windows.Forms

function getLibraryFoldersVDFPath {
    $drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -like "[A-Z]:\" }

    foreach ($drive in $drives) {
        $targetPath = Join-Path $drive.Root "Program Files (x86)\Steam\config\libraryfolders.vdf"

        if (Test-Path $targetPath) {
            return $targetPath
        }
    }

    return $null
}

function getSteamLibraryPaths {
    $vdfPath = getLibraryFoldersVDFPath

    if (-not $vdfPath) {
        Write-Error "Failed to retrieve the Steam library info file (libraryfolders.vdf)."
        return @()
    }

    $content = Get-Content $vdfPath -Raw
    $matches = [regex]::Matches($content, """\d+""\s+{\s+""path""\s+""([^""]+)""")

    return $matches | ForEach-Object { 
        $_.Groups[1].Value -replace '\\\\', '\'
    }
}

function getUserBG3Path {
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select the Baldurs Gate 3 folder."
    $folderBrowser.RootFolder = [System.Environment+SpecialFolder]::MyComputer
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $folderBrowser.SelectedPath
    }

    return $null
}

function getSteamBG3Path {
    $libraries = getSteamLibraryPaths
    foreach ($library in $libraries) {
        $bg3Path = Join-Path $library "steamapps\common\Baldurs Gate 3"
        if (Test-Path $bg3Path) {
            return $bg3Path
        }
    }

    return $null
}

function Backup-File {
    param (
        [string]$path
    )

    $backupPath = "$path.1.bak"
    $counter = 1

    while (Test-Path $backupPath) {
        $counter++
        $backupPath = "$path.$counter.bak"
    }

    Move-Item -Path $path -Destination $backupPath -ErrorAction SilentlyContinue
}

function Copy-WithBackup {
    param (
        [string]$source,
        [string]$destination
    )

    if ($destination -like "*\Localization\*") {
        if (Test-Path $destination) {
            Backup-File -Path $destination
        }
    }

    Copy-Item -Path $source -Destination $destination -Force
    $trimmedSource = $source -replace "^.+\\Data", "Data"
    Write-Output "$trimmedSource >>> $destination"
}

$bg3Path = getSteamBG3Path

if ($bg3Path) {
	Write-Output "Baldurs Gate 3 Path (Steam): $bg3Path"
} else {
	Write-Output "Please select the folder where Baldurs Gate 3 is installed."
	$bg3Path = getUserBG3Path
	if($bg3Path) {
		Write-Output "Baldurs Gate 3 Path (User): $bg3Path"
	} else {
		Write-Output "Patch cancelled."
		Remove-Item -Path patcher.ps1
		exit
	}
}

if ($bg3Path) {
    $sourceData = Join-Path $PSScriptRoot "Data"
    $destinationData = Join-Path $bg3Path "Data"
    if (Test-Path $sourceData) {
        Get-ChildItem -Path $sourceData -Recurse | ForEach-Object {
            $relativePath = $_.FullName.Substring($sourceData.Length)
            $destinationPath = Join-Path $destinationData $relativePath
            if ($_ -is [System.IO.DirectoryInfo]) {
                if (-not (Test-Path $destinationPath)) {
                    New-Item -ItemType Directory -Path $destinationPath | Out-Null
                }
            } else {
                Copy-WithBackup -Source $_.FullName -Destination $destinationPath
            }
        }
        Write-Output "Patch completed. Balkkiyathou~!!!"
    } else {
        Write-Error "Patch file does not exist."
    }
}
Remove-Item -Path patcher.ps1
