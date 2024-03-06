#!/usr/bin/env pwsh

# # Utility functions

$wingetPath = $env:LocalAppData + "\Microsoft\WindowsApps"
$pythonPath = $env:ProgramFiles + "\Python311"

# Workaround: Add LocalAppData\Microsoft\WindowsApps if we can't find winget
function Reload-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath    = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path    = $machinePath + ";" + $userPath + ";" + $wingetPath + ";" + $pythonPath
}

function Print-Step {
    echo "`n:: $args`n"
}

# Have Winget installed
function Have-Winget {
    Reload-Path
    if ((Get-Command winget -ErrorAction SilentlyContinue)) {
        return
    }

    Print-Step "Installing Winget"

    # Try installing with Add-AppxPackage
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe
    Reload-Path

    # Attempt manual method if still not found
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        echo "Winget installation with Add-AppxPackage failed, trying 'manual' method.."
        Print-Step "Downloading Winget installer, might take a while."

        # Why tf does disabling progress bar yields 50x faster downloads????? https://stackoverflow.com/a/43477248
        $msi="https://github.com/microsoft/winget-cli/releases/download/v1.7.10582/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
        $tempFile = [System.IO.Path]::GetTempPath() + "\winget.msixbundle"
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $msi -OutFile $tempFile

        # Install the Appx package
        echo "Finished download, now installing it.."
        Add-AppxPackage -Path $tempFile
        Reload-Path
    }

    # If Winget is still not available, exit
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        echo "`n:: Winget Installation Error`n"
        echo "Winget was installed but still not found. Probably a Path issue or installation failure"
        echo "> Please get it at https://learn.microsoft.com/en-us/windows/package-manager/winget"
        echo "> Alternatively, install manually what previously failed"
        exit
    }
}

# # Install basic dependencies
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Print-Step "Git was not found, installing with Winget"
    Have-Winget
    winget install -e --id Git.Git
    Reload-Path
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        echo "`n:: Git Installation Error`n"
        echo "Git was installed but still not found. Probably a Path issue or installation failure"
        echo "> Please get it at https://git-scm.com/download/win"
        exit
    } else {
        echo "Git was installed successfully"
    }
}

# Avoid false-positives with LocalAppData/WindowsApps/python.exe to MS Store alias
if (-not (Test-Path $pythonPath\python.exe)) {
    Print-Step "Python was not found, installing with Winget"
    Read-Host "> We'll open a Admin Powershell to install it with Winget, press Enter to continue"
    Have-Winget
    Start-Process -FilePath "powershell" -ArgumentList "winget install -e --id Python.Python.3.11 --scope=machine" -Verb RunAs -Wait
    if (-not (Test-Path $pythonPath\python.exe)) {
        echo "`n:: Python Installation Error`n"
        echo "Python was installed but still not found. Probably a Path issue or installation failure"
        echo "> Please get Python 3.11 at https://www.python.org/downloads"
        exit
    } else {
        echo "Python was installed successfully"
    }
}

Reload-Path

# # Bootstrap BrokenSource Monorepo

Print-Step "Cloning BrokenSource Repository"
git clone https://github.com/BrokenSource/BrokenSource --recurse-submodules --jobs 4

echo "`n> Running brakeit.py"
python ./BrokenSource/brakeit.py
