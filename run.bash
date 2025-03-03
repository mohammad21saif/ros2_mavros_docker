#!/bin/bash

# Set script to exit on any error
set -e

# Default values
IMAGE_NAME="ros2_mavros"
CONTAINER_NAME="ros2_mavros_container"
HOST_HOME_DIR="$HOME"
WORKSPACE_DIR="$HOME/ros2_ws"
CONTAINER_WORKSPACE_DIR="/ros2_ws"
ENABLE_GUI=true
ENABLE_GPU=false

# Get current user information
HOST_USER=$(whoami)
HOST_UID=$(id -u)
HOST_GID=$(id -g)

# Help function
show_help() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h, --help                 Show this help message"
    echo "  -i, --image NAME           Set the Docker image name (default: $IMAGE_NAME)"
    echo "  -c, --container NAME       Set the container name (default: $CONTAINER_NAME)"
    echo "  --workspace DIR            Set the host workspace directory to mount (default: $WORKSPACE_DIR)"
    echo "  --no-gui                   Disable GUI application support"
    echo "  --gpu                      Enable GPU support (for visualization or GPU-accelerated code)"
    echo "  --build                    Build the Docker image before running"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            show_help
            exit 0
            ;;
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --workspace)
            WORKSPACE_DIR="$2"
            shift 2
            ;;
        --no-gui)
            ENABLE_GUI=false
            shift
            ;;
        --gpu)
            ENABLE_GPU=true
            shift
            ;;
        --build)
            BUILD_IMAGE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Build the Docker image if requested
if [ "$BUILD_IMAGE" = true ]; then
    echo "Building Docker image: $IMAGE_NAME with user $HOST_USER (UID: $HOST_UID)"
    docker build \
        --build-arg USERNAME=$HOST_USER \
        --build-arg USER_UID=$HOST_UID \
        --build-arg USER_GID=$HOST_GID \
        -t $IMAGE_NAME .
fi

# Check if the container is already running
if docker ps -f name=$CONTAINER_NAME | grep -q $CONTAINER_NAME; then
    echo "Container $CONTAINER_NAME is already running. Attaching to it..."
    docker exec -it $CONTAINER_NAME bash
    exit 0
fi

# Check if the container exists but is stopped
if docker ps -a -f name=$CONTAINER_NAME | grep -q $CONTAINER_NAME; then
    echo "Container $CONTAINER_NAME exists but is not running. Starting and attaching..."
    docker start $CONTAINER_NAME
    docker exec -it $CONTAINER_NAME bash
    exit 0
fi

# Create workspace directory if it doesn't exist
mkdir -p $WORKSPACE_DIR

# Prepare docker run command
DOCKER_RUN_CMD="docker run -it --name $CONTAINER_NAME"

# Add volume mounts
DOCKER_RUN_CMD+=" -v $HOST_HOME_DIR:/home/$HOST_USER"
DOCKER_RUN_CMD+=" -v $WORKSPACE_DIR:$CONTAINER_WORKSPACE_DIR"

# Add network settings
DOCKER_RUN_CMD+=" --network=host"

# Add GUI support if enabled
if [ "$ENABLE_GUI" = true ]; then
    echo "Enabling GUI application support..."
    DOCKER_RUN_CMD+=" -e DISPLAY=$DISPLAY"
    DOCKER_RUN_CMD+=" -v /tmp/.X11-unix:/tmp/.X11-unix"
    
    # Grant permission to the X server
    xhost +local:docker > /dev/null 2>&1 || echo "Warning: Could not set xhost permissions. GUI applications may not work."
fi

# Add GPU support if enabled
if [ "$ENABLE_GPU" = true ]; then
    echo "Enabling GPU support..."
    DOCKER_RUN_CMD+=" --gpus all"
fi

# Add device access for connecting to drone/controllers
DOCKER_RUN_CMD+=" --privileged"
DOCKER_RUN_CMD+=" -v /dev:/dev"

# Add user environment variables
DOCKER_RUN_CMD+=" -e USER=$HOST_USER"
DOCKER_RUN_CMD+=" -w /home/$HOST_USER"

# Finally, add the image name
DOCKER_RUN_CMD+=" $IMAGE_NAME"

# Run the container
echo "Starting container $CONTAINER_NAME from image $IMAGE_NAME..."
echo "User configuration:"
echo "  - Username: $HOST_USER"
echo "  - UID: $HOST_UID"
echo "  - GID: $HOST_GID"
echo "Mounting:"
echo "  - Host $HOST_HOME_DIR to container /home/$HOST_USER"
echo "  - Host $WORKSPACE_DIR to container $CONTAINER_WORKSPACE_DIR"
echo ""

# Execute the command
eval $DOCKER_RUN_CMD
