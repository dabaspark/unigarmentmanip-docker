#!/usr/bin/env bash

set -euo pipefail

# --- Configuration ---
DOCKER_IMAGE="dabaspark/unigarmentmanip:latest"
CONTAINER_NAME="unigarment_container"
GPUS="all"

# --- X11 Forwarding Setup ---
XSOCK=/tmp/.X11-unix
XAUTH_DIR=$(pwd)/../.tmp  # Note the path is relative to the parent directory
XAUTH_FILE=$XAUTH_DIR/docker.xauth
XAUTH_DOCKER=/tmp/.docker.xauth
mkdir -p "$XAUTH_DIR"

# Create or update the .xauth file
echo "Setting up X11 authentication..."
if [ ! -f "$XAUTH_FILE" ]; then
    touch "$XAUTH_FILE"
    # xauth_list=$(xauth nlist "$DISPLAY" | sed -e 's/^..../ffff/')
    # if [ -n "$xauth_list" ]; then
    #     echo "$xauth_list" | xauth -f "$XAUTH_FILE" nmerge -
    # fi
fi
chmod a+r "$XAUTH_FILE"

# --- Docker Pull ---
echo "Pulling the latest image: $DOCKER_IMAGE"
docker pull "$DOCKER_IMAGE"

# --- Docker Run ---
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