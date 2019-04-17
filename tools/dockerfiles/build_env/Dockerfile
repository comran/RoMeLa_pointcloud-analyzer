FROM debian:stretch

# Install compilation and testing dependencies #################################
RUN apt-get update     -qq                                                  && \
    apt-get install -y -qq curl                                             && \
    apt-get install -y -qq                                                     \
    git                                                                        \
    gnupg                                                                      \
    gnupg2

# Add apt-get repositories containing required packages. #######################
RUN curl https://bazel.build/bazel-release.pub.gpg | apt-key add -
RUN echo "deb http://deb.debian.org/debian testing main" \
  | tee /etc/apt/sources.list.d/python3_6.list
RUN curl https://bazel.build/bazel-release.pub.gpg | apt-key add -
RUN echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt " \
  "stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list

# Install apt dependencies. ####################################################
RUN apt-get update -qq                                                      && \
    apt-get upgrade -y -qq                                                  && \
    apt-get install -y                                                         \
    bmon                                                                       \
    build-essential                                                            \
    ca-certificates-java                                                       \
    check                                                                      \
    clang-6.0                                                                  \
    clang-format-7                                                             \
    cmake                                                                      \
    g++                                                                        \
    git                                                                        \
    google-perftools                                                           \
    gphoto2                                                                    \
    gphotofs                                                                   \
    htop                                                                       \
    libc++-dev                                                                 \
    libc++abi-dev                                                              \
    lib32z1-dev                                                                \
    libc6-dev-i386                                                             \
    libgoogle-perftools-dev                                                    \
    librsync-dev                                                               \
    libssl-dev                                                                 \
    lsb-release                                                                \
    libtool                                                                    \
    libyajl-dev                                                                \
    libz-dev                                                                   \
    make                                                                       \
    nmap                                                                       \
    openjdk-11-jdk                                                             \
    pkg-config                                                                 \
    protobuf-compiler                                                          \
    python2.7                                                                  \
    python2.7-lib                                                              \
    python2.7-dev                                                              \
    python3.7                                                                  \
    python3.7-dev                                                              \
    python3.7-distutils                                                        \
    python-matplotlib                                                          \
    python-empy                                                                \
    python-jinja2                                                              \
    screen                                                                     \
    sudo                                                                       \
    tmux                                                                       \
    uthash-dev                                                                 \
    unzip                                                                      \
    vim

# Install pip and python dependencies. #########################################
RUN curl https://bootstrap.pypa.io/get-pip.py | python2.7
RUN curl https://bootstrap.pypa.io/get-pip.py | python3.7
RUN pip2.7 install --upgrade pip                                            && \
    pip3.7 install --upgrade pip

# Set up workspace. ############################################################
# Fix xlocale.h renamed to locale.h
# https://bugs.launchpad.net/ubuntu/+source/libc++/+bug/1725858
RUN ln -s /usr/include/locale.h /usr/include/xlocale.h

RUN useradd -ms /bin/bash romela
# RUN echo 'romela:romela' | chpasswd
RUN echo "%sudo  ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
RUN usermod -aG sudo romela

# User env setup. ##############################################################
RUN mkdir /external_libs

RUN apt-get update && apt-get install -y openssh-client openssh-server

USER romela
RUN mkdir -p /home/romela/code_env
ENV WORKSPACE /home/romela/code_env WORKDIR /home/romela/code_env

WORKDIR /home/romela

# Use a stable version of bazel. ###############################################
WORKDIR /tmp
USER root
RUN curl -L https://github.com/bazelbuild/bazel/releases/download/0.22.0/bazel_0.22.0-linux-x86_64.deb > bazel_0.22.0-linux-x86_64.deb
RUN apt-get install -y bash-completion
RUN dpkg -i bazel_0.22.0-linux-x86_64.deb

# ROS installation. ############################################################
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu stretch main" > /etc/apt/sources.list.d/ros-latest.list'
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-key 421C365BD9FF1F717815A3895523BAEEB01FA116
RUN apt-get update && apt-get install -y ros-melodic-ros-base ros-melodic-mavros
RUN printf "source /opt/ros/melodic/setup.bash" > /home/romela/.bashrc
ENV ROS_MASTER_URI http://0.0.0.0:11311

# Install python requirements. #################################################
USER romela
RUN pip3.7 install --user future

RUN pip3.7 install --user                                                      \
  future==0.16.0                                                               \
  Flask==1.0.2                                                                 \
  Flask-SocketIO==3.3.1                                                        \
  futures==3.1.1                                                               \
  socketIO-client==0.7.2                                                       \
  empy==3.3.2                                                                  \
  opencv-python==4.0.0.21                                                      \
  toml==0.9.4                                                                  \
  eventlet==0.23.0                                                             \
  google==2.0.1                                                                \
  protobuf==3.6.1                                                              \
  python-socketio==3.1.2                                                       \
  python-engineio==3.4.2                                                       \
  pyzmq==17.0.0                                                                \
  Werkzeug==0.14.1                                                             \
  eventlet==0.23.0                                                             \
  zmq==0.0.0

USER root
WORKDIR /home/romela/code_env
COPY htoprc /home/romela/.config/htop/htoprc
