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

Write-Host "VERIFIFYING PYTHON INSTALLATION:" -ForegroundColor Blue

# Get the version of python
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
    $minVersionString = "3.9.0"

    # Compare the installed version with the minimum required version
    if ($installedVersion -ge $minVersion)
    {
        Write-Host "Found Python version: $installedVersion" -ForegroundColor Green
        $pythonExecutable = Get-Command python | Select-Object -ExpandProperty Path
        Write-Host "Found Python Executable: $pythonExecutable" -ForegroundColor Green
    }
    else
    {
        Write-Host "Python version $version is installed, but does not meet the required version: $minVersionString." -ForegroundColor Red
        Write-Host -NoNewline -ForegroundColor Green "Would you like to install Python 3.13.0? (Y/n): "
        $userResponse = Read-Host

        if ($userResponse -eq 'Y' -or $userResponse -eq 'y')
        {
            InstallPython
        }
        else
        {
            Write-Host "Cannot continue with your current version of Python. Exiting..." -ForegroundColor Yellow
            Exit
        }
    }
}
else
{
    $minVersionString = "3.9.0"

    Write-Host "Python is not currently installed. Required minimum version: $minVersionString" -ForegroundColor Red
    Write-Host -NoNewline -ForegroundColor Green "Would you like to install Python 3.13.0? (Y/n): "
    $userResponse = Read-Host

    if ($userResponse -eq 'Y' -or $userResponse -eq 'y')
    {
        InstallPython
    }
    else
    {
        Write-Host "Cannot run without Python installation. Exiting..." -ForegroundColor Yellow
        Exit
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


# Run the Python script and capture the exit code
$pythonCMakeScriptPath = Join-Path -Path $scriptDir -ChildPath "setup_cmake.py"
$pythonCMakeProcess = Start-Process -FilePath "python" -ArgumentList $pythonCMakeScriptPath -NoNewWindow -PassThru -Wait
$pythonExitCode = $pythonCMakeProcess.ExitCode

if ($pythonExitCode -eq 1)
{
    Exit
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Verify CMake installation
try
{
    Write-Host "VERIFIFYING CMAKE INSTALLATION:" -ForegroundColor Blue

    # Get CMake version
    $cmakeVersionOutput = & cmake --version
    $cmakeVersion = ($cmakeVersionOutput -split "cmake version ")[1] -split "`n" | Select-Object -First 1
    if ($cmakeVersion -match "\d+\.\d+\.\d+")
    {
        Write-Host "Found CMake version: $cmakeVersion" -ForegroundColor Green
    }
    else
    {
        Write-Host "ERROR: CMake version could not be verified" -ForegroundColor Red
    }

    # Get CMake executable path
    $cmakePath = Get-Command cmake | Select-Object -ExpandProperty Path
    Write-Host "Found CMake Executable: $cmakePath" -ForegroundColor Green

}
catch
{
    Write-Host "ERROR: : $_" -ForegroundColor Red
}

# Run the Python script and capture the exit code
$pythonNinjaScriptPath = Join-Path -Path $scriptDir -ChildPath "setup_ninja.py"
$pythonNinjaProcess = Start-Process -FilePath "python" -ArgumentList $pythonNinjaScriptPath -NoNewWindow -PassThru -Wait
$ninjaExitCode = $pythonNinjaProcess.ExitCode

if ($ninjaExitCode -eq 1)
{
    Exit
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Verify Ninja installation
try
{
    Write-Host "VERIFIFYING NINJA INSTALLATION:" -ForegroundColor Blue

    # Capture Ninja version
    $ninjaVersionOutput = & ninja --version
    if ($ninjaVersionOutput -match "(\d+\.\d+\.\d+)")
    {
        $ninjaVersion = $matches[1]
        Write-Host "Found Ninja version: $ninjaVersion" -ForegroundColor Green
    }

    else
    {
        Write-Host "ERROR: Ninja version could not be verified" -ForegroundColor Red
    }

    # Get Ninja executable path
    $ninjaPath = Get-Command ninja | Select-Object -ExpandProperty Path
    Write-Host "Found Ninja Executable: $ninjaPath" -ForegroundColor Green

}
catch
{
    Write-Host "ERROR: $_" -ForegroundColor Red
}

# Run the Python script and capture the exit code
$pythonClangScriptPath = Join-Path -Path $scriptDir -ChildPath "setup_clang.py"
$pythonClangProcess = Start-Process -FilePath "python" -ArgumentList $pythonClangScriptPath -NoNewWindow -PassThru -Wait
$clangExitCode = $pythonClangProcess.ExitCode

if ($clangExitCode -eq 1)
{
    Exit
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Verify Clang installation
try
{
    Write-Host "VERIFIFYING CLANG INSTALLATION:" -ForegroundColor Blue

    # Capture Clang version
    $clangVersionOutput = & clang --version
    $clangVersion = ($clangVersionOutput -split "clang version ")[1] -split "`n" | Select-Object -First 1
    if ($clangVersion -match "(\d+\.\d+\.\d+)")
    {
        $clangVersion = $matches[1]
        Write-Host "Found Clang version: $clangVersion" -ForegroundColor Green
    }
    else
    {
        Write-Host "ERROR: Clang version could not be verified" -ForegroundColor Red
    }

    # Get Clang executable path
    $clangPath = Get-Command clang | Select-Object -ExpandProperty Path
    Write-Host "Found Clang Executable: $clangPath" -ForegroundColor Green

}
catch
{
    Write-Host "ERROR: $_" -ForegroundColor Red
}

Write-Host "`n"
Write-Host "All Finished. You can now exit..." -ForegroundColor Green