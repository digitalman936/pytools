import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import requests
from rich.console import Console
from rich.prompt import Prompt

console = Console(color_system="auto", force_terminal=True)


def print_header(message):
    console.print(f"[cyan]{message}[/cyan]")


def print_step(message):
    console.print(f"[bright_blue]{message}[/bright_blue]")


def print_success(message):
    console.print(f"[bright_green]{message}[/bright_green]")


def print_error(message):
    console.print(f"[red]{message}[/red]")
    sys.exit(1)


def print_error_prompt(message):
    console.print(f"[red]{message}[/red]")


def print_warning(message):
    console.print(f"[bright_yellow]{message}[/bright_yellow]")


VS_BUILD_TOOLS_URL = "https://aka.ms/vs/17/release/vs_BuildTools.exe"
INSTALL_COMMAND = [
    '--passive', '--wait', '--norestart',
    '--add', 'Microsoft.VisualStudio.Workload.VCTools',
    '--add', 'Microsoft.VisualStudio.Workload.NativeDesktop',
    '--includeRecommended'
]


def download_file(url, dest_path):
    print_step("Downloading Visual Studio 2022 Build Tools installer...")
    response = requests.get(url)
    if response.status_code == 200:
        with open(dest_path, "wb") as f:
            f.write(response.content)
        print_success("Download completed successfully.")
    else:
        print_error(f"Error: Failed to download file. Status code: {response.status_code}")


def check_vswhere():
    vswhere_common_locations = [
        os.path.join(os.environ.get('ProgramFiles(x86)', ''), r'Microsoft Visual Studio\Installer'),
        r'C:\ProgramData\chocolatey\lib\vswhere\tools',
        os.path.join(os.environ.get('USERPROFILE', ''), r'.nuget\packages'),
        os.path.join(os.environ.get('USERPROFILE', ''), r'scoop\apps\vswhere\current')
    ]

    for path in vswhere_common_locations:
        full_path = os.path.join(path, 'vswhere.exe')
        if os.path.exists(full_path):
            return full_path
    return None


def get_vs_instances(vswhere_path, args):
    try:
        result = subprocess.run(
            [vswhere_path] + args,
            capture_output=True,
            text=True,
            check=True
        )
        return json.loads(result.stdout)
    except subprocess.CalledProcessError:
        print_error("Error fetching Visual Studio instances. Please check your setup.")
        return None


def display_paths(instances, instance_type):
    for instance in instances:
        install_path = instance['installationPath']
        # print_success(f"Found {instance_type}")
        # print_success(f"Installation Path: {install_path}")
        print("\n")


def prompt_and_install_vs_component(missing_component):
    response = Prompt.ask(
        f"[bright_green]Would you like to install the missing Desktop Development with C++workload? (Y/n)[/bright_green]",
        default="Y",
        show_default=False
    )
    if response.lower() in ('y', ''):
        setup_visual_studio()
    else:
        print_warning(f"Cannot continue without required Desktop Development for C++ workload. Exiting...")
        sys.exit(1)


def prompt_and_install_vs2022_build_tools():
    response = Prompt.ask(
        f"[bright_green]Would you like to install Visual Studio 2022 Build Tools for C++? (Y/n)[/bright_green]",
        default="Y",
        show_default=False
    )
    if response.lower() in ('y', ''):
        setup_visual_studio()
    else:
        print_warning(f"Cannot continue without required workload. Exiting...")
        sys.exit(1)


def setup_visual_studio():
    try:
        temp_dir = Path(tempfile.gettempdir())
        installer_path = temp_dir / "vs_BuildTools.exe"
        download_file(VS_BUILD_TOOLS_URL, installer_path)

        print_step("Installing Visual Studio 2022 Build Tools...")
        subprocess.run([str(installer_path)] + INSTALL_COMMAND, check=True)
        print_success("Visual Studio 2022 Build Tools were installed successfully.")
    finally:
        if installer_path.exists():
            installer_path.unlink()


def check_and_prompt_for_workloads(vswhere_path):
    # Check for Visual Studio IDEs with the Desktop Development with C++ workload
    vs_ide_args = [
        '-version', '17', '-products',
        'Microsoft.VisualStudio.Product.Enterprise,Microsoft.VisualStudio.Product.Professional,Microsoft.VisualStudio.Product.Community',
        '-requires', 'Microsoft.VisualStudio.Workload.NativeDesktop', '-format', 'json'
    ]

    # Check for Visual Studio Build Tools with the VC++ workload
    vs_build_tools_args = [
        '-version', '17', '-products', 'Microsoft.VisualStudio.Product.BuildTools',
        '-requires', 'Microsoft.VisualStudio.Workload.VCTools', '-format', 'json'
    ]

    # Check for any Visual Studio 2022 IDE installations (without filtering by workload)
    vs_any_ide_args = [
        '-version', '17', '-products',
        'Microsoft.VisualStudio.Product.Enterprise,Microsoft.VisualStudio.Product.Professional,Microsoft.VisualStudio.Product.Community',
        '-format', 'json'
    ]

    # Check for any Visual Studio 2022 Build Tools installations (without filtering by workload)
    vs_any_build_tools_args = [
        '-version', '17', '-products', 'Microsoft.VisualStudio.Product.BuildTools',
        '-format', 'json'
    ]

    vs_ide_instances = get_vs_instances(vswhere_path, vs_ide_args)
    vs_build_tools_instances = get_vs_instances(vswhere_path, vs_build_tools_args)
    vs_any_ide_instances = get_vs_instances(vswhere_path, vs_any_ide_args)
    vs_any_build_tools_instances = get_vs_instances(vswhere_path, vs_any_build_tools_args)

    if vs_ide_instances:
        display_paths(vs_ide_instances, "Visual Studio 2022 IDE with Desktop Development for C++:")
    elif vs_any_ide_instances:
        print_error_prompt(
            "Visual Studio 2022 IDE was found, but it does not contain the Desktop Development with C++ workload."
        )
        prompt_and_install_vs_component("Microsoft.VisualStudio.Workload.NativeDesktop")

    if vs_build_tools_instances:
        display_paths(vs_build_tools_instances, "Visual Studio 2022 Build Tools with Desktop Development for C++:")
    elif vs_any_build_tools_instances:
        print_error_prompt(
            "Visual Studio 2022 Build Tools were found, but they do not contain the C++ workload."
        )
        prompt_and_install_vs_component("Microsoft.VisualStudio.Workload.VCTools")

    if not vs_any_ide_instances and not vs_any_build_tools_instances:
        print_error_prompt("Visual Studio 2022 is not installed, which is required for C++ development on windows.")
        prompt_and_install_vs2022_build_tools()


def main():
    vswhere_path = check_vswhere()
    if vswhere_path:
        check_and_prompt_for_workloads(vswhere_path)
    else:
        print_warning("vswhere.exe was not found in any of the specified locations.")
        sys.exit(1)


if __name__ == "__main__":
    main()
