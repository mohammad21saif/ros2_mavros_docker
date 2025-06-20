#!/bin/bash

# ROS2 Humble Docker Container Runner
# This script runs the ROS2 Humble development container with full device access

echo "Starting ROS2 Humble Docker container..."

# Allow X11 forwarding for GUI applications
xhost +local:docker >/dev/null 2>&1

# Create workspace directory if it doesn't exist
mkdir -p $HOME/ros2_workspace

docker run -it --rm \
  -v $HOME:/home/$USER \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -e DISPLAY=$DISPLAY \
  -e QT_X11_NO_MITSHM=1 \
  --network host \
  --privileged \
  -v /dev:/dev \
  --name ros2-humble-container \
  ros2-humble-dev

echo "Container has stopped."
