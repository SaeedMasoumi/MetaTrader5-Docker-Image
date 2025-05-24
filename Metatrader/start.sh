#!/bin/bash

# Configuration variables
mt5file='/config/.wine/drive_c/Program Files/MetaTrader 5/terminal64.exe'
WINEPREFIX='/config/.wine'
wine_executable="wine"
metatrader_version="5.0.4993"
mt5server_port="8001"
mono_url="https://dl.winehq.org/wine/wine-mono/10.0.0/wine-mono-10.0.0-x86.msi"
# Updated to use 64-bit Python installer
python_url="https://www.python.org/ftp/python/3.9.13/python-3.9.13-amd64.exe"
mt5setup_url="https://download.mql5.com/cdn/web/metaquotes.software.corp/mt5/mt5setup.exe"

# Function to display a graphical message
show_message() {
    echo $1
}

# Function to check if a dependency is installed
check_dependency() {
    if ! command -v $1 &> /dev/null; then
        echo "$1 is not installed. Please install it to continue."
        exit 1
    fi
}

# Function to check if a Python package is installed
is_python_package_installed() {
    /opt/venv/bin/python -c "import pkg_resources; exit(not pkg_resources.require('$1'))" 2>/dev/null
    return $?
}

# Function to check if a Python package is installed in Wine
is_wine_python_package_installed() {
    WINEARCH=win64 $wine_executable python -c "import pkg_resources; exit(not pkg_resources.require('$1'))" 2>/dev/null
    return $?
}

# Check for necessary dependencies
check_dependency "curl"
check_dependency "$wine_executable"

# Ensure Wine prefix is 64-bit
export WINEARCH=win64
show_message "[0/7] Setting up 64-bit Wine environment..."

# Initialize Wine prefix if it doesn't exist
if [ ! -d "$WINEPREFIX" ]; then
    show_message "[0/7] Creating new 64-bit Wine prefix..."
    WINEARCH=win64 WINEPREFIX="$WINEPREFIX" winecfg
fi

# Set Windows 10 mode in Wine early
WINEARCH=win64 $wine_executable reg add "HKEY_CURRENT_USER\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f

# Install Mono if not present
if [ ! -e "/config/.wine/drive_c/windows/mono" ]; then
    show_message "[1/7] Downloading and installing Mono..."
    curl -o /config/.wine/drive_c/mono.msi $mono_url
    WINEARCH=win64 WINEDLLOVERRIDES=mscoree=d $wine_executable msiexec /i /config/.wine/drive_c/mono.msi /qn
    rm /config/.wine/drive_c/mono.msi
    show_message "[1/7] Mono installed."
else
    show_message "[1/7] Mono is already installed."
fi

# Check if MetaTrader 5 is already installed
if [ -e "$mt5file" ]; then
    show_message "[2/7] File $mt5file already exists."
else
    show_message "[2/7] File $mt5file is not installed. Installing..."

    show_message "[3/7] Downloading MT5 installer..."
    curl -o /config/.wine/drive_c/mt5setup.exe $mt5setup_url
    show_message "[3/7] Installing MetaTrader 5..."
    WINEARCH=win64 $wine_executable "/config/.wine/drive_c/mt5setup.exe" "/auto" &
    wait
    rm -f /config/.wine/drive_c/mt5setup.exe
fi

# Recheck if MetaTrader 5 is installed
if [ -e "$mt5file" ]; then
    show_message "[4/7] File $mt5file is installed. Running MT5..."
    WINEARCH=win64 $wine_executable "$mt5file" &
else
    show_message "[4/7] File $mt5file is not installed. MT5 cannot be run."
fi

# Install 64-bit Python in Wine if not present
if ! WINEARCH=win64 $wine_executable python --version 2>/dev/null; then
    show_message "[5/7] Installing 64-bit Python in Wine..."
    curl -L $python_url -o /tmp/python-installer.exe
    WINEARCH=win64 $wine_executable /tmp/python-installer.exe /quiet InstallAllUsers=1 PrependPath=1
    rm /tmp/python-installer.exe
    show_message "[5/7] 64-bit Python installed in Wine."
else
    show_message "[5/7] Python is already installed in Wine."
    # Verify it's 64-bit
    WINEARCH=win64 $wine_executable python -c "import platform; print('Architecture:', platform.architecture()[0])"
fi

# Upgrade pip and install required packages
show_message "[6/7] Installing Python libraries"
WINEARCH=win64 $wine_executable python -m pip install --upgrade --no-cache-dir pip

# Install MetaTrader5 library in Windows if not installed
show_message "[6/7] Installing MetaTrader5 library in Windows"
if ! is_wine_python_package_installed "MetaTrader5==$metatrader_version"; then
    WINEARCH=win64 $wine_executable python -m pip install --no-cache-dir MetaTrader5==$metatrader_version
fi

# Install mt5linux library in Windows if not installed
show_message "[6/7] Checking and installing mt5linux library in Windows if necessary"
if ! is_wine_python_package_installed "mt5linux"; then
    WINEARCH=win64 $wine_executable python -m pip install --no-cache-dir mt5linux
fi

# Start the MT5 server on Linux
show_message "[7/7] Starting the mt5linux server..."
# Using the specific Python 3.9 from our virtual environment
/opt/venv/bin/python -m mt5linux --host 0.0.0.0 -p $mt5server_port -w "WINEARCH=win64 $wine_executable python.exe" &

# Give the server some time to start
sleep 5

# Check if the server is running
if ss -tuln | grep ":$mt5server_port" > /dev/null; then
    show_message "[7/7] The mt5linux server is running on port $mt5server_port."
else
    show_message "[7/7] Failed to start the mt5linux server on port $mt5server_port."
fi

# Verify the Python architecture in Wine
show_message "Verifying Wine Python architecture:"
WINEARCH=win64 $wine_executable python -c "import platform; print('Architecture:', platform.architecture()); print('Machine:', platform.machine()); print('Platform:', platform.platform())"