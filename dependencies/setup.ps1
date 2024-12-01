function InstallPython
{
    # Define installer URL and target path
    $installerUrl = "https://www.python.org/ftp/python/3.13.0/python-3.13.0-amd64.exe"
    $installerPath = "$env:TEMP\python-3.13.0-amd64.exe"

    # Download Python installer
    Write-Host "Downloading Python 3.13.0 installer..." -ForegroundColor Blue
    try
    {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
        Write-Host "Download completed." -ForegroundColor Green
    }
    catch
    {
        Write-Host "ERROR: Failed to download Python installer." -ForegroundColor Red
        exit 1
    }

    # Install Python silently
    Write-Host "Installing Python 3.13.0..." -ForegroundColor Blue
    $installArgs = '/quiet', 'InstallAllUsers=1', 'PrependPath=1'
    Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait
    Remove-Item -Path $installerPath -Force
    Write-Host "Python installation completed." -ForegroundColor Green

    # Refresh PowerShell session's system path to reflect python installation
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
}

# Get the version of python
Write-Host "Detecting Python..." -ForegroundColor Blue
$p = &{ python -V } 2>&1

# Check if an ErrorRecord was returned
$version = if ($p -is [System.Management.Automation.ErrorRecord])
{
    # Assume Python is not installed if there's an error
    ""
}
else
{
    # Otherwise return as is
    $p
}

# Extract the version number from the output string
if ($version -match "Python (\d+\.\d+\.\d+)")
{
    $installedVersion = [Version]$matches[1]
    $minVersion = [Version]"3.9.0"

    # Compare the installed version with the minimum required version
    if ($installedVersion -ge $minVersion)
    {
        Write-Host "Found Python version: $installedVersion" -ForegroundColor Green
        $pythonExecutable = Get-Command python | Select-Object -ExpandProperty Path
        Write-Host "Found Python Executable: $pythonExecutable" -ForegroundColor Green
    }
    else
    {
        Write-Host "WARNING: Installed Python version is older than 3.9." -ForegroundColor Yellow
        Write-Host -NoNewline -ForegroundColor Green "Would you like to install Python 3.13.0? (Y/n): "
        $userResponse = Read-Host

        if ($userResponse -eq 'Y' -or $userResponse -eq 'y')
        {
            InstallPython
        }
        else
        {
            Write-Host "Cannot continue with your current version of Python. Exiting..." -ForegroundColor Yellow
        }
    }
}
else
{
    Write-Host "WARNING: Python is not currently installed." -ForegroundColor Yellow
    Write-Host -NoNewline -ForegroundColor Green "Would you like to install Python 3.13.0? (Y/n): "
    $userResponse = Read-Host

    if ($userResponse -eq 'Y' -or $userResponse -eq 'y')
    {
        InstallPython
    }
    else
    {
        Write-Host "Python installation declined." -ForegroundColor Yellow
    }
}

# Setup python virtual environment
Write-Host "Configuring python virtual environment..." -ForegroundColor Blue
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Set-Location -Path $scriptDir
$venvPath = Join-Path -Path $scriptDir -ChildPath "..\.venv"
if (Test-Path $venvPath)
{
    Write-Host "Existing virtual environment found. Removing..." -ForegroundColor Yellow
    Remove-Item -Path $venvPath -Recurse -Force
}
python -m venv $venvPath
Write-Host "Activating python virtual environment..." -ForegroundColor Blue
& "$venvPath\Scripts\Activate.ps1"
if (-not ($env:VIRTUAL_ENV))
{
    Write-Host "ERROR: Failed to activate the virtual environment." -ForegroundColor Red
    exit 1
}

# Upgrade pip
Write-Host "Installing pip to virtual environment" -ForegroundColor Blue
python -m pip install --upgrade pip

# Install required packages from requirements.txt
if (Test-Path (Join-Path -Path $scriptDir -ChildPath "requirements.txt"))
{
    Write-Host "Installing required pip packages..." -ForegroundColor Blue
    pip install -r (Join-Path -Path $scriptDir -ChildPath "requirements.txt")
}
else
{
    Write-Host "ERROR: requirements.txt not found." -ForegroundColor Red
    exit 1
}

Write-Host "Finished Python setup." -ForegroundColor Green
Write-Host "`n"

# Run setup_cmake.py
python (Join-Path -Path $scriptDir -ChildPath "main.py")
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Verify CMake installation
try
{
    Write-Host "Detecting CMake..." -ForegroundColor Blue

    # Get CMake version
    $cmakeVersionOutput = cmake --version
    if ($cmakeVersionOutput -match "cmake version (\d+\.\d+\.\d+)")
    {
        $cmakeVersion = $matches[1]
        Write-Host "Found CMake version: $cmakeVersion" -ForegroundColor Green
    }
    else
    {
        Write-Host "ERROR: CMake version could not be verfied" -ForegroundColor Red
    }

    # Get CMake executable path
    $cmakePath = Get-Command cmake | Select-Object -ExpandProperty Path
    Write-Host "Found CMake Executable: $cmakePath" -ForegroundColor Green

}
catch
{
    Write-Host "ERROR: : $_" -ForegroundColor Red
}

Write-Host "`n"
Write-Host "*****************************************" -ForegroundColor Cyan
Write-Host "`n--- Success. You can now exit... ---`n" -ForegroundColor Cyan
Write-Host "*****************************************" -ForegroundColor Cyan
Write-Host "`n"