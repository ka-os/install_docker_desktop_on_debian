#!/bin/bash
set -e

# --- Configuration ---
DOCKER_DESKTOP_DEB="docker-desktop-amd64.deb"
DOWNLOAD_URL="https://desktop.docker.com/linux/main/amd64/${DOCKER_DESKTOP_DEB}" # NOTE: This link may need to be updated with the latest version number
# Example for a specific version: DOWNLOAD_URL="https://desktop.docker.com/linux/main/amd64/docker-desktop-4.27.2-amd64.deb"

echo "================================================"
echo " Starting Docker and Docker Desktop Installation "
echo "================================================"

# --- 1. System Update and Prerequisites ---
echo "1. Updating system packages and installing prerequisites..."
sudo apt update
sudo apt install -y ca-certificates curl gnupg apt-transport-https software-properties-common

# --- 2. Check for KVM (Required for Docker Desktop) ---
echo "2. Checking for KVM virtualization support..."
if [ -c /dev/kvm ]; then
    echo "   KVM device found. Virtualization support should be available."
    
    # Load KVM modules if not loaded
    if ! lsmod | grep -q kvm_intel && ! lsmod | grep -q kvm_amd; then
        echo "   Attempting to load KVM modules..."
        if grep -q vendor_id /proc/cpuinfo | grep -q "GenuineIntel"; then
            sudo modprobe kvm_intel
        elif grep -q vendor_id /proc/cpuinfo | grep -q "AuthenticAMD"; then
            sudo modprobe kvm_amd
        fi
    fi
else
    echo "   WARNING: KVM device /dev/kvm not found. Docker Desktop may not function without proper virtualization."
fi
# Install gnome-terminal if not present, as recommended for non-GNOME desktops
if ! command -v gnome-terminal &> /dev/null && [ -n "$DISPLAY" ]; then
    echo "   Installing gnome-terminal (recommended dependency for non-GNOME desktops)..."
    sudo apt install -y gnome-terminal
fi

# --- 3. Add Docker Official Repository (for Docker Engine and dependencies) ---
echo "3. Setting up Docker's APT repository..."

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
sudo apt update

# --- 4. Download Docker Desktop DEB Package ---
echo "4. Downloading Docker Desktop DEB package..."
wget -O "${DOCKER_DESKTOP_DEB}" "${DOWNLOAD_URL}"

# --- 5. Install Docker Desktop (This installs Docker Engine as a dependency) ---
echo "5. Installing Docker Desktop..."
# apt install handles dependencies better than dpkg -i
sudo apt install -y ./"${DOCKER_DESKTOP_DEB}"

# Check for installation success
if ! command -v docker-desktop &> /dev/null; then
    echo "ERROR: Docker Desktop installation failed. Check the output for errors."
    exit 1
fi
echo "   Docker Desktop installed successfully."

# --- 6. Post-Installation (Non-root access and cleanup) ---
echo "6. Performing post-installation setup..."
# Add current user to the 'docker' group to run commands without 'sudo'
# The user will need to log out and back in for this to take effect.
if ! getent group docker | grep -q "\b$USER\b"; then
    echo "   Adding current user ($USER) to the 'docker' group..."
    sudo usermod -aG docker "$USER"
fi

# Remove the downloaded deb file
rm -f ./"${DOCKER_DESKTOP_DEB}"

# Enable Docker Desktop service for the user
echo "   Enabling and starting Docker Desktop service..."
systemctl --user enable docker-desktop || true # true prevents failure if user doesn't have systemd user session
systemctl --user start docker-desktop || true

echo "================================================"
echo "         Installation Complete! 🚀             "
echo "================================================"
echo "NEXT STEPS:"
echo "1. Log out and log back in (or reboot) for the 'docker' group change to take effect."
echo "2. Launch Docker Desktop from your application menu or run 'docker-desktop' in the terminal."
echo "3. Accept the Docker Subscription Service Agreement when prompted."
