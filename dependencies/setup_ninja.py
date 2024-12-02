import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
import requests
from rich import print
from rich.prompt import Prompt
import winreg
import zipfile
import ctypes

NINJA_MINIMUM_REQUIRED_VERSION = (1, 12, 1)


def print_header(message):
    print(f"[cyan]{message}[/cyan]")


def print_step(message):
    print(f"[bright_blue]{message}[/bright_blue]")


def print_success(message):
    print(f"[bright_green]{message}[/bright_green]")


def print_error(message):
    print(f"[red]{message}[/red]")
    sys.exit(1)


def print_error_prompt(message):
    print(f"[red]{message}[/red]")


def print_warning(message):
    print(f"[bright_yellow]{message}[/bright_yellow]")


def download_and_extract_ninja(url, dest_path):
    print_step("Downloading Ninja installer...")
    with tempfile.TemporaryDirectory() as temp_dir:
        ninja_zip_path = Path(temp_dir) / 'ninja-win.zip'

        # Download the Ninja zip file
        response = requests.get(url, stream=True)
        if response.status_code == 200:
            with open(ninja_zip_path, 'wb') as f:
                for chunk in response.iter_content(chunk_size=8192):
                    f.write(chunk)
            print_success("Download completed successfully.")
        else:
            print_error(f"Error: Failed to download file. Status code: {response.status_code}")

        # Extract the zip file to the temporary directory
        with zipfile.ZipFile(ninja_zip_path, 'r') as zip_ref:
            zip_ref.extractall(temp_dir)

        # Verify if ninja.exe exists
        extracted_ninja_path = Path(temp_dir) / "ninja.exe"

        if extracted_ninja_path.exists():
            dest_ninja_path = Path(dest_path) / "ninja.exe"
            dest_ninja_path.parent.mkdir(parents=True, exist_ok=True)  # Ensure directory exists
            extracted_ninja_path.replace(dest_ninja_path)
            grant_ninja_permissions(dest_ninja_path)
        else:
            print_error("ninja.exe not found in extracted contents.")


def install_ninja(installer_path):
    print_step("Installing Ninja...")

    installer_path = Path('C:/Program Files/Ninja')
    installer_path.mkdir(parents=True, exist_ok=True)

    print_success("Ninja was installed successfully.")


def grant_ninja_permissions(ninja_exe_path):
    # Set permissions for "Everyone" to read & execute
    everyone = "Everyone"
    command = f'icacls "{ninja_exe_path}" /grant {everyone}:(RX) /T /C /Q'
    subprocess.run(command, shell=True, check=True)
    print_success("Granted read and execute permissions to all users for ninja.exe.")


def add_ninja_to_system_path(ninja_path):
    ninja_binary_path = str(ninja_path)
    try:
        # Open the registry key for environment variables
        reg_key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,
                                 r"System\CurrentControlSet\Control\Session Manager\Environment",
                                 0, winreg.KEY_READ | winreg.KEY_WRITE)

        current_path, _ = winreg.QueryValueEx(reg_key, 'Path')

        if ninja_binary_path not in current_path.split(';'):
            new_path = f"{current_path};{ninja_binary_path}"
            winreg.SetValueEx(reg_key, 'Path', 0, winreg.REG_EXPAND_SZ, new_path)

        winreg.CloseKey(reg_key)

        # Broadcast a WM_SETTINGCHANGE message to signal a global environment update
        # It helps in making sure that new PATH is visible in the session
        import ctypes
        HWND_BROADCAST = 0xFFFF
        WM_SETTINGCHANGE = 0x1A
        ctypes.windll.user32.SendMessageW(HWND_BROADCAST, WM_SETTINGCHANGE, 0, 'Environment')

        subprocess.run(["setx", "/M", "PATH", new_path], shell=True, check=True)

        print_success("Ninja has been successfully added to the system PATH.")

    except Exception as e:
        print_error(f"Failed to update system PATH: {e}")


def prompt_and_install_ninja():
    response = Prompt.ask(
        "[bright_green]Would you like to install Ninja? (Y/n)[/bright_green]",
        default="Y",
        show_default=False
    )
    if response.lower() in ('y', ''):
        setup_ninja()
    else:
        print_warning("Cannot continue without installing Ninja. Exiting...")
        sys.exit(1)


def check_ninja_version(minimum_version=NINJA_MINIMUM_REQUIRED_VERSION):
    try:
        # Run the ninja version command
        result = subprocess.run(["ninja", "--version"], check=True, capture_output=True, text=True)

        # Get the first line of the output
        version_line = result.stdout.strip()

        # Parse the version directly from the first line
        if version_line:
            clean_version_str = re.match(r"(\d+\.\d+\.\d+)", version_line)

            if clean_version_str is None:
                print_error("Failed to parse version string from 'ninja --version'.")

            version_tuple = tuple(map(int, clean_version_str.group(1).split('.')))

            if version_tuple >= minimum_version:
                return True
            else:
                print_error_prompt(
                    f"\nNinja version {version_line} is installed, but it does not meet the required version {'.'.join(map(str, minimum_version))}.")
                prompt_and_install_ninja()
                return False
        else:
            print_error("Unexpected output format from 'ninja --version'.")

    except subprocess.CalledProcessError:
        print_error("Ninja encountered an error.")
    except FileNotFoundError:
        print_error_prompt(
            f"\nNinja is not currently installed. Required minimum version: {'.'.join(map(str, minimum_version))}.")
        prompt_and_install_ninja()
        return False
    except AttributeError:
        print_error("Error parsing Ninja version.")


def setup_ninja():
    installer_url = "https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-win.zip"
    dest_install_path = Path('C:/Program Files/Ninja')

    download_and_extract_ninja(installer_url, dest_install_path)
    add_ninja_to_system_path(dest_install_path)

    print_success("Finished Ninja setup\n\n")


if __name__ == "__main__":
    check_ninja_version()
    sys.exit(0)
