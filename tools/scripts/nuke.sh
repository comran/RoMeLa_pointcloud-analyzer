#!/bin/bash

function kill_container {
  echo "Killing container $1"
  # Remove all running docker containers.
  while true
  do
    docker ps -a &> /dev/null
    if [[ $? > 0 ]]
    then
      # Docker is not running.
      break
    fi

    DOCKER_RUNNING_CONTAINER=$(docker ps \
      --filter name=$1 \
      --filter status=running \
      --format "{{.ID}}" \
      --latest \
    )

    if [[ ! -z $DOCKER_RUNNING_CONTAINER ]]
    then
      echo "Killing docker container: $DOCKER_RUNNING_CONTAINER"
      docker kill $DOCKER_RUNNING_CONTAINER
    fi

    DOCKER_CONTAINER=$(docker ps \
      --filter name=$1 \
      --format "{{.ID}}" \
      --latest \
    )

    if [[ -z $DOCKER_CONTAINER ]]
    then
      break
    else
      echo "Removing docker container: $DOCKER_CONTAINER"
      docker rm $DOCKER_CONTAINER
    fi
  done
}

kill_container illuminate_build_env

# Remove all cache.
printf "\nRemoving all cache..."
rm -rf tools/cache
