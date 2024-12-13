import subprocess
import sys
import os
import tempfile

import requests
from rich import print
from rich.prompt import Prompt


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
    print_step("Downloading Vulkan SDK installer...")
    try:
        response = requests.get(url)
        response.raise_for_status()
        with open(dest_path, "wb") as f:
            f.write(response.content)
        print_success("Download completed successfully.")
    except requests.RequestException as e:
        print_error(f"Error occurred during download: {e}")


def install_vulkan(installer_path):
    print_step("Installing Vulkan SDK...")
    try:
        result = subprocess.run([
            installer_path,
            "install",
            "--accept-licenses",
            "--confirm-command",
            "--default-answer",
            "--no-force-installations",
            "--install-components",
            "com.lunarg.vulkan.volk",
            "com.lunarg.vulkan.vma",
            "com.lunarg.vulkan.debug"
        ], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print_success("Vulkan SDK was installed successfully.")
    except subprocess.CalledProcessError as e:
        print_error(f"Error: Installation command failed with return code {e.returncode}")

    # Cleanup
    try:
        os.remove(installer_path)
    except OSError as e:
        print_error(f"Error cleaning up installer: {e}")


def setup_vulkan():
    url = "https://sdk.lunarg.com/sdk/download/1.3.296.0/windows/VulkanSDK-1.3.296.0-Installer.exe"
    installer_path = os.path.join(tempfile.gettempdir(), "VulkanSDK-Installer.exe")

    download_file(url, installer_path)
    install_vulkan(installer_path)
    print_success("Finished Vulkan SDK setup\n\n")


def prompt_and_install_vulkan():
    response = Prompt.ask(
        "[bright_green]Would you like to install the Vulkan SDK 1.3.204.0? (Y/n)[/bright_green]",
        default="Y",
        show_default=False
    )
    if response.lower() in ('y', ''):
        setup_vulkan()
    else:
        print_warning("Cannot continue without installing Vulkan SDK. Exiting...")
        sys.exit(1)


def compare_versions(version1, version2):
    v1 = tuple(map(int, version1.split('.')))
    v2 = tuple(map(int, version2.split('.')))
    return v1 >= v2


def check_vulkan_sdk_version():
    vulkan_sdk_path = os.environ.get('VULKAN_SDK')

    if not vulkan_sdk_path:
        print_error_prompt(
            "\nVulkan SDK is not currently installed. Required minimum version: 1.3.204.0."
        )
        prompt_and_install_vulkan()
        return

    # Extracting the version from the VULKAN_SDK path
    version_str = vulkan_sdk_path.split('\\')[-1]
    required_version = '1.3.204.0'

    if not compare_versions(version_str, required_version):
        print_error_prompt(
            f"\nVulkan SDK version {version_str} is installed, but it does not meet the required version {required_version}."
        )
        prompt_and_install_vulkan()


if __name__ == "__main__":
    check_vulkan_sdk_version()
    sys.exit(0)
