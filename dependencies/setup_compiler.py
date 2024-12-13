import ctypes
import re
import shutil
import subprocess
import sys
import tempfile
import winreg
import zipfile
from pathlib import Path

import requests
from rich import print
from rich.prompt import Prompt

CLANG_MINIMUM_REQUIRED_VERSION = (11, 0, 0)


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
    with requests.get(url, stream=True) as response:
        response.raise_for_status()  # Raises an error for bad status codes
        with open(dest_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)


def download_and_extract_mingw_llvm(url, dest_path):
    print_step("Downloading MinGW-LLVM repository zip...")
    mingw_llvm_zip_path = dest_path / 'llvm-mingw.zip'

    download_file(url, mingw_llvm_zip_path)
    print_success("Download completed successfully.")

    print_step("Extracting MinGW-LLVM repository contents...")

    # Extract zip to destination path
    with zipfile.ZipFile(mingw_llvm_zip_path, 'r') as zip_ref:
        zip_ref.extractall(dest_path)

    # Cleanup zip file after extraction
    mingw_llvm_zip_path.unlink()

    # Find the main subdirectory (assuming one top-level folder exists)
    subdirectories = [p for p in dest_path.iterdir() if p.is_dir()]
    if len(subdirectories) == 1:
        main_subdir = subdirectories[0]

        print_step(f"Moving files from {main_subdir.name} to {dest_path}...")

        # Move all contents from the subdirectory to the target directory
        for item in main_subdir.iterdir():
            shutil.move(str(item), dest_path / item.name)

        # Remove the now-empty directory
        main_subdir.rmdir()

    print_success("Extraction and reorganization completed.")

    extracted_files = list(dest_path.rglob('*'))
    print(f"Extracted {len(extracted_files)} files.")


def grant_clang_permissions(bin_path):
    everyone = "Everyone"
    # Grant permissions recursively to the entire directory and its contents
    command = f'icacls "{bin_path}" /grant {everyone}:(RX) /T /C /Q >nul 2>&1'
    result = subprocess.run(command, shell=True)

    if result.returncode != 0:
        print_error(f"Failed to grant permissions for {bin_path}.")


def add_mingw_llvm_to_system_path(dest_path):
    bin_path = str(Path(dest_path) / "bin")
    try:
        # Open the registry key for system environment variables
        reg_key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE,
                                 r"System\CurrentControlSet\Control\Session Manager\Environment",
                                 0, winreg.KEY_READ | winreg.KEY_WRITE)

        current_path, _ = winreg.QueryValueEx(reg_key, 'Path')

        if bin_path not in current_path.split(';'):
            new_path = f"{current_path};{bin_path}"
            winreg.SetValueEx(reg_key, 'Path', 0, winreg.REG_EXPAND_SZ, new_path)

        winreg.CloseKey(reg_key)

        # Broadcast a WM_SETTINGCHANGE message to signal a global environment update
        HWND_BROADCAST = 0xFFFF
        WM_SETTINGCHANGE = 0x1A
        ctypes.windll.user32.SendMessageW(HWND_BROADCAST, WM_SETTINGCHANGE, 0, 'Environment')

    except Exception as e:
        print_error(f"Failed to update system PATH: {e}")


def prompt_and_install_clang():
    response = Prompt.ask(
        "[bright_green]Would you like to install Clang 19.1.4? (Y/n)[/bright_green]",
        default="Y",
        show_default=False
    )
    if response.lower() in ('y', ''):
        setup_clang()
    else:
        print_warning("Cannot continue without installing Clang. Exiting...")
        sys.exit(1)


def check_compiler_version(minimum_version=CLANG_MINIMUM_REQUIRED_VERSION):
    try:
        # Run the clang version command
        result = subprocess.run(["clang", "--version"], capture_output=True, text=True)

        # Get the first line of the output and parse it
        version_line = result.stdout.splitlines()[0]
        clean_version_str = re.search(r"(\d+\.\d+\.\d+)", version_line)
        if clean_version_str:
            version_tuple = tuple(map(int, clean_version_str.group(1).split('.')))
            if version_tuple >= minimum_version:
                return True
            else:
                print_error_prompt(
                    f"Clang version {version_line} is installed, but it does not meet the required version {'.'.join(map(str, minimum_version))}.")
                prompt_and_install_clang()
                return False
        else:
            print_error("Unexpected format in 'clang --version'.")

    except subprocess.CalledProcessError:
        print_error_prompt("Error running 'clang --version'.")
    except FileNotFoundError:
        print_error_prompt(
            f"Clang is not installed and must be of version {'.'.join(map(str, minimum_version))} or higher.")
        prompt_and_install_clang()
        return False


def setup_clang():
    installer_url = "https://github.com/mstorsjo/llvm-mingw/releases/download/20241119/llvm-mingw-20241119-ucrt-x86_64.zip"
    dest_install_path = Path('C:/Program Files/MinGW-LLVM')
    dest_install_path.mkdir(parents=True, exist_ok=True)

    download_and_extract_mingw_llvm(installer_url, dest_install_path)

    # Grant permissions for the bin directory
    bin_path = dest_install_path / "bin"
    grant_clang_permissions(bin_path)

    add_mingw_llvm_to_system_path(dest_install_path)

    print_success("Finished Clang setup")


if __name__ == "__main__":
    check_compiler_version()
    sys.exit(0)
