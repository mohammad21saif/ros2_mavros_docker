FROM ubuntu:jammy

ARG USERNAME
ARG USER_UID
ARG USER_GID=$USER_UID

# Set the locale
RUN apt-get update && apt-get install -y locales && \
    locale-gen en_US en_US.UTF-8 && \
    update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 && \
    export LANG=en_US.UTF-8

# Set the timezone
ENV ROS_VERSION=2
ENV ROS_DISTRO=humble
ENV ROS_PYTHON_VERSION=3
ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Setup the sources
RUN apt-get update && apt-get install -y software-properties-common curl sudo && \
    add-apt-repository universe && \
    curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | tee /etc/apt/sources.list.d/ros2.list > /dev/null

# Install ROS 2 packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y ros-humble-desktop 

# Install MAVROS and dependencies
RUN apt-get update && apt-get install -y \
    ros-humble-mavros \
    ros-humble-mavros-extras \
    ros-humble-mavros-msgs \
    python3-pip

# Install GeographicLib datasets required by MAVROS
RUN wget https://raw.githubusercontent.com/mavlink/mavros/master/mavros/scripts/install_geographiclib_datasets.sh && \
    chmod +x install_geographiclib_datasets.sh && \
    ./install_geographiclib_datasets.sh && \
    rm install_geographiclib_datasets.sh

# install bootstrap tools
RUN apt-get update && apt-get install --no-install-recommends -y \
    build-essential \
    git \
    nano \
    iputils-ping \
    wget \
    python3-colcon-common-extensions \
    python3-colcon-mixin \
    python3-rosdep \
    python3-vcstool \
    && rm -rf /var/lib/apt/lists/*

# bootstrap rosdep
RUN rosdep init && \
  rosdep update --rosdistro humble

# Create a MAVROS configuration directory and set parameters to allow motor control
RUN mkdir -p /opt/ros/humble/share/mavros/config && \
    echo "# MAVROS configuration to allow motor control\n\
plugin_allowlist:\n\
  - command\n\
  - setpoint_raw\n\
  - setpoint_velocity\n\
  - setpoint_attitude\n\
  - setpoint_position\n\
  - rc_io\n\
  - safety\n\
  - sys_status\n\
  - sys_time\n\
  - imu\n\
\n\
# Enable motor control\n\
safety_allowed_area:\n\
  enable: false\n\
\n\
command:\n\
  use_comp_id_system_control: true\n\
" > /opt/ros/humble/share/mavros/config/px4_config.yaml

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set up user environment
USER $USERNAME
WORKDIR /home/$USERNAME

# Environment setup
RUN echo 'source /opt/ros/humble/setup.bash' >> ~/.bashrc

# ROS entrypoint script
USER root
RUN echo '#!/usr/bin/env bash' > /ros_entrypoint.sh && \
    echo 'source /opt/ros/humble/setup.bash' >> /ros_entrypoint.sh && \
    echo 'exec "$@"' >> /ros_entrypoint.sh && \
    chmod +x /ros_entrypoint.sh

USER $USERNAME
ENTRYPOINT ["/ros_entrypoint.sh"]
CMD ["bash"]
