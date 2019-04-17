#!/bin/bash

unset ENV_DOCKER_RUNNING_CONTAINER
unset ENV_DOCKER_CONTAINER
unset RUNNING_DOCKER_CONTAINERS

ENV_DOCKER_RUNNING_CONTAINER=$(docker ps \
  --filter name=illuminate_build_env \
  --filter status=running \
  --format "{{.ID}}" \
  --latest \
  )

# Check if Dockerfile was updated, indicating that the existing docker container
# needs to be killed.
mkdir -p tools/cache/checksums
CHECKSUM=$(md5sum tools/dockerfiles/build_env/Dockerfile)
MATCH=0

if [ -f tools/cache/checksums/build_env_dockerfile.md5 ]
then
  LAST_CHECKSUM=$(cat tools/cache/checksums/build_env_dockerfile.md5)

  CHECKSUM=$(echo -e "${CHECKSUM}" | tr -d '[:space:]')
  LAST_CHECKSUM=$(echo -e "${LAST_CHECKSUM}" | tr -d '[:space:]')

  if [ "$CHECKSUM" = "$LAST_CHECKSUM" ]
  then
    MATCH=1
  fi
fi

if [ $MATCH -eq 0 ]
then
  RUNNING_DOCKER_CONTAINERS=$(docker ps \
    --filter name=illuminate_build_env \
    --filter status=running \
    --format "{{.ID}}" \
    --latest \
  )

  if [ ! -z $RUNNING_DOCKER_CONTAINERS ]
  then
    echo "build_env dockerfile updated; killing existing container"

    docker kill $RUNNING_DOCKER_CONTAINERS

    while [ ! -z $RUNNING_DOCKER_CONTAINERS ]
    do
      RUNNING_DOCKER_CONTAINERS=$(docker ps \
        --filter name=illuminate_build_env \
        --filter status=running \
        --format "{{.ID}}" \
        --latest \
      )

      sleep 0.25
    done
  fi

  CHECKSUM=$(md5sum tools/dockerfiles/build_env/Dockerfile)
  echo $CHECKSUM > tools/cache/checksums/build_env_dockerfile.md5
fi

if [ ! -z $ENV_DOCKER_RUNNING_CONTAINER ]
then
  echo "Docker environment already running."

  exit
fi

ENV_DOCKER_CONTAINER=$(docker ps \
  --filter name=illuminate_build_env \
  --format "{{.ID}}" \
  --latest
  )

if [ ! -z $ENV_DOCKER_CONTAINER ]
then
  echo "Removing old container with ID $ENV_DOCKER_CONTAINER"
  docker rm $ENV_DOCKER_CONTAINER
fi

BUILD_FLAGS="-t illuminate_build_env"

while test $# -gt 0
do
    case "$1" in
        --rebuild) BUILD_FLAGS="$BUILD_FLAGS --no-cache"
            ;;
    esac
    shift
done

# Build docker container.
if [[ -z $TRAVIS ]]
then
  docker build $BUILD_FLAGS tools/dockerfiles/build_env
else
  docker build $BUILD_FLAGS tools/dockerfiles/build_env
fi

if [ $? -ne 0 ]
then
    echo "Error building Illuminate env docker container."
    exit 1
fi

# Create network for docker container to use.
docker network create -d bridge illuminate_bridge > /dev/null 2>&1 || true

mkdir -p tools/cache/bazel
pwd

# Set root path of the repository volume on the host machine.
# Note: If docker is called within another docker instance & is trying to start
#       the UAS@UCLA docker environment, the root will need to be set to the
#       path that is used by wherever dockerd is running.
ROOT_PATH=$(pwd)
if [ ! -z $HOST_ROOT_SEARCH ] && [ ! -z $HOST_ROOT_REPLACE ]
then
  # Need to use path of the host container running dockerd.
  ROOT_PATH=${ROOT_PATH/$HOST_ROOT_SEARCH/$HOST_ROOT_REPLACE}
fi

echo "Root path is $ROOT_PATH"

# Start docker container and let it run forever.
PLATFORM=$(uname -s)
DOCKER_BUILD_CMD="set -x; \
  getent group $(id -g) || groupadd -g $(id -g) host_group; \
  mkdir -p /tmp/home/illuminate; \
  usermod -d /tmp/home/illuminate illuminate; \
  usermod -u $(id -u) -g $(id -g) illuminate; \
  usermod -d /home/illuminate illuminate; \
  chown illuminate /home/illuminate; \
  chown illuminate /home/illuminate/.cache; \
  echo STARTED > /tmp/illuminate_init; \
  sudo -u illuminate bash -c \"bazel; \
  sleep infinity\""

docker run \
  -d \
  --rm \
  --net=host \
  -v $ROOT_PATH:/home/illuminate/code_env \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  --dns 8.8.8.8 \
  --name illuminate_build_env \
  illuminate_build_env \
  bash -c "$DOCKER_BUILD_CMD"

echo "Started illuminate_build_env docker image. Waiting for it to boot..."

# Wait for docker container to start up.
while [ -z $RUNNING_DOCKER_CONTAINERS ]
do
  RUNNING_DOCKER_CONTAINERS=$(docker ps \
    --filter name=illuminate_build_env \
    --filter status=running \
    --format "{{.ID}}" \
    --latest \
  )

  sleep 0.25
done

# Wait for permission scripts to execute.
./tools/scripts/build_env/exec.sh "while [ ! -f /tmp/illuminate_init ];do sleep 0.25;done"
