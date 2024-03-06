#!/usr/bin/env pwsh

# # Utility functions

function Reload-Path {
    # Trivia: I don't know why, but this must be a single line command. I really don't PowerShell
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

function Print-Step {
    echo "`n:: $args`n"
}

# Have Winget installed
function Have-Winget {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Print-Step "Installing Winget"

        # Try with Add-AppxPackage
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
            echo "> Please get it at https://learn.microsoft.com/en-us/windows/package-manager/winget/"
            echo "> We can't do much here, it should be bundled with any modern Windows"
            exit
        }
    }
}

# # Install basic dependencies

Print-Step "Installing Git"
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    echo "Git was not found, we'll install it with Winget."
    Have-Winget
    winget install -e --id Git.Git
    Reload-Path

    # Check if Git is still not found
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        echo "`n:: Git Installation Error`n"
        echo "Git was installed but still not found. Probably a Path issue or installation failure"
        echo "> Please get it at https://git-scm.com/download/win"
        exit
    } else {
        echo "Git was installed successfully"
    }
}

Print-Step "Installing Python"
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    echo "Python was not found, or maybe it was installed without --scope-machine"
    Have-Winget
    echo "> We'll open a Admin Powershell to install it with Winget"
    Read-Host "`nPress Enter to continue"
    Start-Process -FilePath "powershell" -ArgumentList "winget install -e --id Python.Python.3.11 --scope=machine" -Verb RunAs
    Read-Host "> Press Enter after Python is installed"
    Reload-Path

    # Check if Python is still not found
    if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
        echo "`n:: Python Installation Error`n"
        echo "Python was installed but still not found. Probably a Path issue or installation failure"
        echo "> Please get it at https://www.python.org/downloads/"
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
