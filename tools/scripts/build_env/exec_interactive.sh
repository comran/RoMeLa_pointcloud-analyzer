#!/bin/bash

if [ $(uname -s) == "Darwin" ]
then
  source tools/scripts/docker/start_machine_mac.sh
fi

function docker_exec {
    IMAGE=$(docker ps \
      --filter status=running \
      --filter name=illuminate_build_env \
      --format "{{.ID}}" \
      --latest)

    if [ -z $IMAGE ]
    then
      echo "Could not find illuminate_build_env docker image. Exiting..."
      exit 1
    fi

    PIDFILE=/tmp/docker-exec-$$
    NAMEFILE=/tmp/docker-exec-$$

    docker exec -it -u $(id -u):$(id -g) $IMAGE \
      bash -c "echo \"\$\$\" > \"$PIDFILE\".pid; echo \"$*\" > \"$NAMEFILE\".name;$*"

    exit $?
}

docker_exec "$@"
