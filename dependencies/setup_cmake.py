import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path
import requests
from rich import print
from rich.prompt import Prompt

CMAKE_MINIMUM_REQUIRED_VERSION = (3, 22, 0)


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


def download_file(url, dest_path):
    print_step("Downloading CMake 3.31.1 installer...")
    response = requests.get(url)
    if response.status_code == 200:
        with open(dest_path, "wb") as f:
            f.write(response.content)
        print_success("Download completed successfully.")
    else:
        print_error(f"Error: Failed to download file. Status code: {response.status_code}")


def install_cmake(installer_path):
    print_step("Installing CMake...")
    result = subprocess.run([
        "msiexec.exe",
        "/i", str(installer_path),
        "ALLUSERS=1",
        "ADD_CMAKE_TO_PATH=System",
        "/qn"],
        check=False
    )
    if result.returncode == 0:
        print_success("CMake was installed successfully.")
    else:
        print_error("Error: CMake installation failed.")

    # Cleanup
    try:
        os.remove(installer_path)
    except OSError as e:
        print_error(f"Error cleaning up installer: {e}")


def prompt_and_install_cmake():
    response = Prompt.ask(
        "[bright_green]Would you like to install CMake 3.31.1? (Y/n)[/bright_green]",
        default="Y",
        show_default=False
    )
    if response.lower() in ('y', ''):
        setup_cmake()
    else:
        print_warning("Cannot continue without the required version of CMake. Exiting...")
        sys.exit(1)


def setup_cmake():
    installer_url = "https://github.com/Kitware/CMake/releases/download/v3.31.1/cmake-3.31.1-windows-x86_64.msi"
    temp_dir = tempfile.gettempdir()
    installer_path = Path(temp_dir) / "cmake-3.31.1-windows-x86_64.msi"

    download_file(installer_url, installer_path)
    install_cmake(installer_path)

    print_success("Finished CMake setup\n\n")


def check_cmake_version(minimum_version=CMAKE_MINIMUM_REQUIRED_VERSION):
    try:
        result = subprocess.run(["cmake", "--version"], check=True, capture_output=True, text=True)
        version_line = result.stdout.splitlines()[0]
        version_str = version_line.split()[2]
        clean_version_str = re.match(r"(\d+\.\d+\.\d+)", version_str).group(1)
        version_tuple = tuple(map(int, clean_version_str.split('.')))

        if version_tuple >= minimum_version:
            return True
        else:
            print_error_prompt(
                f"\nCMake version {version_str} is installed, but it does not meet the required version {'.'.join(map(str, minimum_version))}.")
            prompt_and_install_cmake()
            return False

    except subprocess.CalledProcessError:
        prompt_and_install_cmake()
    except FileNotFoundError:
        print_error_prompt(
            f"\nCMake is not currently installed. Required minimum version: {'.'.join(map(str, minimum_version))}.")
        prompt_and_install_cmake()
    except AttributeError:
        print_error("Error parsing CMake version.")


if __name__ == "__main__":
    check_cmake_version()
    sys.exit(0)
