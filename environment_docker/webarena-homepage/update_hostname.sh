#!/bin/bash
set -e  # Exit on error

# Auto-detect public IP if SERVER_HOSTNAME is not set
if [ -z "$SERVER_HOSTNAME" ]; then
    echo "Detecting public IP address..."
    SERVER_HOSTNAME=$(curl -s ip.sb)

    if [ -z "$SERVER_HOSTNAME" ]; then
        echo "Warning: Failed to auto-detect IP. Defaulting to 127.0.0.1"
        SERVER_HOSTNAME="127.0.0.1"
    else
        echo "Detected IP: $SERVER_HOSTNAME"
    fi
fi

# Remove trailing / if it exists
SERVER_HOSTNAME=${SERVER_HOSTNAME%/}

echo "Using hostname: $SERVER_HOSTNAME"

# Replace placeholder in the HTML file
perl -pi -e "s|<your-server-hostname>|${SERVER_HOSTNAME}|g" templates/index.html

echo "Updated templates/index.html with hostname: $SERVER_HOSTNAME"
