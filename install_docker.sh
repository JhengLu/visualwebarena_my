#!/bin/bash
set -e  # Exit on error

echo "Installing Docker and Docker Compose..."

# Update package index
sudo apt update

# Install prerequisites
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
sudo apt update

# Install Docker Engine, containerd, and Docker Compose
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configure Docker to use /data for storage
echo "Configuring Docker to use /data directory for storage..."
sudo mkdir -p /data/docker
sudo mkdir -p /data/containerd

# Create Docker daemon configuration
sudo mkdir -p /etc/docker
cat << 'EOF' | sudo tee /etc/docker/daemon.json > /dev/null
{
  "data-root": "/data/docker"
}
EOF

# Configure containerd to use /data for storage
cat << 'EOF' | sudo tee /etc/containerd/config.toml > /dev/null
version = 2
root = "/data/containerd"
state = "/data/containerd/state"
EOF

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Make Docker socket accessible to everyone (no permission restrictions)
sudo chmod 666 /var/run/docker.sock

# Also set it permanently by creating a systemd override
sudo mkdir -p /etc/systemd/system/docker.socket.d
cat << 'EOF' | sudo tee /etc/systemd/system/docker.socket.d/override.conf > /dev/null
[Socket]
SocketMode=0666
EOF

# Reload systemd to apply changes
sudo systemctl daemon-reload

echo ""
echo "Docker installation complete!"
echo "Docker socket is now accessible to all users without sudo."
echo ""
echo "To verify installation, run: docker --version"
