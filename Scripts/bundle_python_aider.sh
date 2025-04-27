#!/bin/bash
# bundle_python_aider.sh
# Script to bundle Aider with CodeEdit
# This script should be run during the app build process

set -e

# Configuration
RESOURCES_DIR="${BUILT_PRODUCTS_DIR}/${CONTENTS_FOLDER_PATH}/Resources"
AIDER_DIR="${RESOURCES_DIR}/aider"

echo "Setting up Aider integration..."
mkdir -p "${RESOURCES_DIR}"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Python 3 not found. Skipping Aider installation."
    exit 0
fi

# Create a script to run Aider
echo "Creating Aider wrapper script..."
cat > "${RESOURCES_DIR}/aider_wrapper.sh" << EOF
#!/bin/bash
# Wrapper script to launch Aider
# This script will use the system Python to run Aider

# Try to find Aider
if command -v aider &> /dev/null; then
    # System-wide Aider is available
    aider "\$@"
else
    # Try to install Aider
    echo "Aider not found. Attempting to install..."
    if pip3 install --user aider-chat; then
        echo "Aider installed successfully."
        aider "\$@"
    else
        echo "Failed to install Aider. Please install it manually with 'pip install aider-chat'."
        exit 1
    fi
fi
EOF

# Make the script executable
chmod +x "${RESOURCES_DIR}/aider_wrapper.sh"

echo "Aider integration setup complete!" 