#!/bin/bash
set -e  # Exit on error

# this script would install the miniconda to the ~/, and install the env to the vwa conda env

# Detect if conda is already available (from any installation)
if command -v conda &> /dev/null; then
    echo "Conda already installed and available, skipping installation..."
    # Initialize conda for this script
    eval "$(conda shell.bash hook)"
else
    echo "Conda not found, proceeding with installation..."

    # 1) Download Miniconda installer if not already downloaded
    if [ ! -f ~/Miniconda3-latest-Linux-x86_64.sh ]; then
        echo "Downloading Miniconda installer..."
        wget -P ~ https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    else
        echo "Miniconda installer already downloaded, skipping..."
    fi

    # 2) Install Miniconda if not already installed
    if [ ! -d ~/miniconda3 ]; then
        echo "Installing Miniconda..."
        bash ~/Miniconda3-latest-Linux-x86_64.sh -b -p ~/miniconda3
    else
        echo "Miniconda directory exists, skipping installation..."
    fi

    # 3) Use conda in this shell (script-safe)
    source ~/miniconda3/etc/profile.d/conda.sh

    # 4) Initialize conda for shell if not already initialized
    if ! grep -q "conda initialize" ~/.bashrc 2>/dev/null; then
        echo "Initializing conda for bash..."
        ~/miniconda3/bin/conda init bash
    else
        echo "Conda already initialized in ~/.bashrc, skipping..."
    fi

    source ~/.bashrc 2>/dev/null || true
fi

# Accept conda terms of service (required before creating environments)
echo "Accepting conda terms of service..."
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || echo "TOS already accepted or not required"
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || echo "TOS already accepted or not required"

# Initialize conda for shell if not already initialized (regardless of installation path)
if ! grep -q "conda initialize" ~/.bashrc 2>/dev/null; then
    echo "Initializing conda for bash shell..."
    conda init bash
else
    echo "Conda already initialized in ~/.bashrc, skipping..."
fi

# 6) Create conda environment if it doesn't exist
if conda env list | grep -q "^vwa "; then
    echo "Conda environment 'vwa' already exists, skipping creation..."
else
    echo "Creating conda environment 'vwa'..."
    conda create -n vwa python=3.10 -y
fi

# 7) Activate environment
echo "Activating conda environment 'vwa'..."
conda activate vwa

# 8) Install Python dependencies
echo "Installing Python dependencies from requirements.txt..."
pip install -r requirements.txt

# 9) Install Playwright browsers
echo "Installing Playwright browsers..."
playwright install

# 10) Install package in editable mode
echo "Installing package in editable mode..."
pip install -e .

echo "Setup complete!"
