#!/usr/bin/env bash

set -euo pipefail

# --- Configuration ---
DOCKER_IMAGE="dabaspark/unigarmentmanip-build"
CONTAINER_NAME="unigarment_container"
MAIN_REPO_DIR="UniGarmentManip"

# --- Step 1: Automated Project Setup ---
# Check if the main repo directory exists. If not, clone everything.
if [ ! -d "$MAIN_REPO_DIR" ]; then
    echo "Cloning required repositories..."
    git clone https://github.com/luhr2003/UniGarmentManip.git
    cd "$MAIN_REPO_DIR"
    git clone --recursive https://github.com/erikwijmans/Pointnet2_PyTorch.git
    git clone https://github.com/szabolcsdombi/python-mesh-raycast.git

    echo "Modifying environment.yml to remove pip dependencies for PointNet2..."
    # Use sed to comment out the specific lines. This is more robust than a simple grep.
    sed -i '/^\s*- pointnet2-ops==3.0.0/s/^/#/' environment.yml
    sed -i '/^\s*- pointnet2==3.0.0/s/^/#/' environment.yml
    
    cd ..
    echo "Setup complete."
fi

# --- Step 2: Docker Build ---
echo "Building Docker image '$DOCKER_IMAGE' from the '$MAIN_REPO_DIR' directory..."
# The key fix: Run docker build with the correct context path.
docker build -t "$DOCKER_IMAGE" -f Dockerfile "$MAIN_REPO_DIR"


# --- Step 3: X11 Forwarding and Container Launch ---
echo "Authorizing X server for local container access..."
xhost +local:docker

echo "Starting Docker container '$CONTAINER_NAME'..."
echo "NOTE: If you get a 'container already in use' error, run 'docker rm $CONTAINER_NAME' first."

docker run -it --rm \
    --gpus all \
    --name "$CONTAINER_NAME" \
    -e NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics \
    -e __GLX_VENDOR_LIBRARY_NAME=nvidia \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY=$DISPLAY \
    "$DOCKER_IMAGE" \
    /bin/bash

echo "Container '$CONTAINER_NAME' has exited."