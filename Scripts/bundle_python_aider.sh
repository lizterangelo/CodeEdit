#!/bin/bash
# bundle_python_aider.sh
# Script to bundle Aider with CodeEdit
# This script follows the official installation method from https://aider.chat/docs/install.html

set -e

# Configuration
RESOURCES_DIR="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Resources"
AIDER_DIR="${RESOURCES_DIR}/aider"
VENV_DIR="${AIDER_DIR}/venv"

echo "Setting up Aider integration..."
mkdir -p "${RESOURCES_DIR}"
mkdir -p "${AIDER_DIR}"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Python 3 not found. Skipping Aider installation."
    exit 0
fi

# Create a virtual environment for Aider
echo "Creating virtual environment for Aider..."
python3 -m venv "${VENV_DIR}"

# Install Aider inside the virtual environment
echo "Installing Aider in virtual environment..."
"${VENV_DIR}/bin/pip" install -U aider-chat

# Create a wrapper script to run Aider
echo "Creating Aider wrapper script..."
cat > "${RESOURCES_DIR}/aider_wrapper.sh" << EOF
#!/bin/bash
# Wrapper script to launch Aider from the bundled virtual environment

# Get the directory where this script is located
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="\${SCRIPT_DIR}/aider/venv"
AIDER_CMD="\${VENV_DIR}/bin/aider"

# Activate the virtual environment and run Aider with all arguments
if [ -f "\${AIDER_CMD}" ]; then
    # Source virtual environment activation script
    source "\${VENV_DIR}/bin/activate"
    
    # Run Aider with all provided arguments
    "\${AIDER_CMD}" "\$@"
else
    echo "Error: Aider executable not found at \${AIDER_CMD}"
    echo "Attempting to install Aider using system pip..."
    
    if pip3 install --user aider-chat; then
        echo "Aider installed successfully with pip."
        if command -v aider &> /dev/null; then
            aider "\$@"
        else
            echo "Aider command not found. You may need to restart your terminal."
            exit 1
        fi
    else
        echo "Failed to install Aider. Please install it manually with:"
        echo "  pip install aider-chat"
        exit 1
    fi
fi
EOF

# Make the script executable
chmod +x "${RESOURCES_DIR}/aider_wrapper.sh"

echo "Aider integration setup complete!" 