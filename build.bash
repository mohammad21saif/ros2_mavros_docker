#!/bin/bash

# ROS2 Humble Docker Container Builder
# This script builds the ROS2 Humble development container with current user settings

echo "Building ROS2 Humble Docker container..."
echo "Username: $USER"
echo "User ID: $(id -u)"
echo "Group ID: $(id -g)"
echo ""

docker build \
  --build-arg USERNAME=$USER \
  --build-arg USER_UID=$(id -u) \
  --build-arg USER_GID=$(id -g) \
  -t ros2-humble-dev .

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build completed successfully!"
    echo "Image tagged as: ros2-humble-dev"
    echo "You can now run the container using: ./run.bash"
    echo ""
    echo "Image details:"
    docker images ros2-humble-dev --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
else
    echo ""
    echo "❌ Build failed!"
    echo "Common issues:"
    echo "  - Check your internet connection"
    echo "  - Ensure Docker has enough disk space"
    echo "  - Try: docker system prune -f"
    exit 1
fi
