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

# Write-Host "VERIFIFYING PYTHON INSTALLATION:" -ForegroundColor Blue

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
        # Write-Host "Found Python version: $installedVersion" -ForegroundColor Green
        $pythonExecutable = Get-Command python | Select-Object -ExpandProperty Path
        # Write-Host "Found Python Executable: $pythonExecutable" -ForegroundColor Green
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
    Write-Host "Virtual environment already exists. skipping..." -ForegroundColor Yellow
}
else
{
    Write-Host "Creating new virtual environment..." -ForegroundColor Blue
    python -m venv $venvPath
}

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

# Run the Python script and capture the exit code
$pythonNinjaScriptPath = Join-Path -Path $scriptDir -ChildPath "setup_ninja.py"
$pythonNinjaProcess = Start-Process -FilePath "python" -ArgumentList $pythonNinjaScriptPath -NoNewWindow -PassThru -Wait
$ninjaExitCode = $pythonNinjaProcess.ExitCode

if ($ninjaExitCode -eq 1)
{
    Exit
}

# Run the Python script and capture the exit code
$pythonClangScriptPath = Join-Path -Path $scriptDir -ChildPath "setup_compiler.py"
$pythonClangProcess = Start-Process -FilePath "python" -ArgumentList $pythonClangScriptPath -NoNewWindow -PassThru -Wait
$clangExitCode = $pythonClangProcess.ExitCode

if ($clangExitCode -eq 1)
{
    Exit
}

# Run the Python script and capture the exit code
$pythonVulkanScriptPath = Join-Path -Path $scriptDir -ChildPath "setup_vulkan.py"
$pythonVulkanProcess = Start-Process -FilePath "python" -ArgumentList $pythonVulkanScriptPath -NoNewWindow -PassThru -Wait
$vulkanExitCode = $pythonVulkanProcess.ExitCode

if ($vulkanExitCode -eq 1)
{
    Exit
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Verify Python installation
try
{
    Write-Host "VERIFYING PYTHON INSTALLATION:" -ForegroundColor Blue

    # Get Python version
    $pythonVersionOutput = & python --version 2>&1
    if ($pythonVersionOutput -match "\d+\.\d+\.\d+")
    {
        Write-Host "Found Python version: $pythonVersionOutput" -ForegroundColor Green
    }
    else
    {
        Write-Host "ERROR: Python version could not be verified" -ForegroundColor Red
    }

    # Get Python executable path
    $pythonPath = Get-Command python | Select-Object -ExpandProperty Definition
    if ($pythonPath)
    {
        Write-Host "Found Python Executable: $pythonPath" -ForegroundColor Green
    }
    else
    {
        Write-Host "ERROR: Python executable could not be found" -ForegroundColor Red
    }

}
catch
{
    Write-Host "ERROR: $_" -ForegroundColor Red
}

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

# Check if the VULKAN_SDK environment variable is set
$vulkanSdkPath = [System.Environment]::GetEnvironmentVariable("VULKAN_SDK", "Machine")

Write-Host "VERIFIFYING VULKAN INSTALLATION:" -ForegroundColor Blue

if (-not $vulkanSdkPath)
{
    Write-Host "ERROR: Could not find the VULKAN_SDK variable" -ForegroundColor Red
    Exit
}
else
{
    Write-Host "Found Vulkan: $vulkanSdkPath" -ForegroundColor Green
}

# Verify if Vulkan utilities are available
try
{
    # Check if vulkaninfo exists
    $vulkanInfo = Get-Command vulkaninfo -ErrorAction Stop
    Write-Host "Found VulkanInfo tool: $( $vulkanInfo.Path )" -ForegroundColor Green

    # Run vulkaninfo to verify it executes without error but suppress output
    & vulkaninfo > $null

    # Check other tools for further verification if needed
    # For example: Get-Command glslangValidator -ErrorAction Stop
}
catch
{
    Write-Host "ERROR: $_" -ForegroundColor Red
}

# Optionally check versions through outputs of Vulkan-specific commands
try
{
    $vulkanVersion = & vulkaninfo | Select-String "Vulkan Instance Version"

    if ($vulkanVersion)
    {
        # Extract exact version for output
        $vulkanVersionText = $vulkanVersion -replace ".*Vulkan Instance Version[^\d]*", ""
        Write-Host "Found Vulkan Instance Version: $vulkanVersionText" -ForegroundColor Green
    }
    else
    {
        Write-Host "ERROR: Unable to determine Vulkan version from vulkaninfo output." -ForegroundColor Red
    }
}
catch
{
    Write-Host "ERROR: $_" -ForegroundColor Red
}


# Run the Python script and capture the exit code
$pythonVS2022ScriptPath = Join-Path -Path $scriptDir -ChildPath "setup_vs2022.py"
$pythonVS2022Process = Start-Process -FilePath "python" -ArgumentList $pythonVS2022ScriptPath -NoNewWindow -PassThru -Wait
$vs2022ExitCode = $pythonVS2022Process.ExitCode

if ($vs2022ExitCode -eq 1)
{
    Exit
}

$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine")

# Verify Visual Studio 2022 installation
Set-Location "${Env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer"

# Get Visual Studio 2022 IDE instances in JSON format
$vs2022_ide_instances = .\vswhere -version 17 -latest -products * -requires Microsoft.VisualStudio.Workload.NativeDesktop -format json | ConvertFrom-Json

# Get Visual Studio 2022 Build Tools instances in JSON format
$vs2022_build_tools_instances = .\vswhere -version 17 -latest -products * -requires Microsoft.VisualStudio.Workload.VCTools -format json | ConvertFrom-Json

# Function to display paths for given instances
function Display-Paths($instances, $type) {
    foreach ($instance in $instances) {
        $installPath = $instance.installationPath
        $msbuildPath = Join-Path -Path $installPath -ChildPath "MSBuild\Current\Bin\MSBuild.exe"
        $vcPath = Join-Path -Path $installPath -ChildPath "VC\Auxiliary\Build"
        $vsDevCmdPath = Join-Path -Path $installPath -ChildPath "Common7\Tools\VsDevCmd.bat"

        # Path to the VC tools version file
        $vctoolsVersionFilePath = Join-Path -Path $vcPath -ChildPath "Microsoft.VCToolsVersion.default.txt"

        # Check if the version file exists before trying to read
        if (Test-Path -Path $vctoolsVersionFilePath) {
            # Read the VC tools version from the text file
            $vc_tools_version = Get-Content -Path $vctoolsVersionFilePath | ForEach-Object { $_.Trim() }

            # Construct the path to the cl.exe compiler
            $clPath = Join-Path -Path $installPath -ChildPath "VC\Tools\MSVC\$vc_tools_version\bin\Hostx64\x64\cl.exe"
        } else {
            $clPath = "VC tools version file not found."
        }

        Write-Host "$type Instance:"
        Write-Host "Installation Path: $installPath"
        Write-Host "MSBuild Path: $msbuildPath"
        Write-Host "MSVC Path: $clPath"
        Write-Host "VsDevCmd.bat Path: $vsDevCmdPath"
        Write-Host "`n"
    }
}

# Display paths for Visual Studio 2022 IDE
Write-Host "VERIFYING VS2022 INSTALLATION:" -ForegroundColor Blue
Display-Paths -instances $vs2022_ide_instances -type "Visual Studio 2022 IDE"

# Display paths for Visual Studio 2022 Build Tools
Display-Paths -instances $vs2022_build_tools_instances -type "Visual Studio 2022 Build Tools"

Write-Host "`n"
Write-Host "All Finished. You can now exit..." -ForegroundColor Green