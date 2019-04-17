#!/bin/bash

if [ $(uname -s) == "Darwin" ]
then
  source tools/scripts/docker/start_machine_mac.sh
fi

function interrupt_exec {
  if [ ! -z $PIDFILE ]
  then
    docker exec -t $IMAGE sh -c "PID=\$(cat $PIDFILE);echo \"KILLING \$PID\";kill -15 \$PID > /dev/null 2>&1 || true;rm $PIDFILE;rm $NAMEFILE"
    printf "\033[91mINTERRUPTED!\033[0m\n"
  fi
}

function docker_exec {
    IMAGE=$(docker ps \
      --filter status=running \
      --filter name=romela_build_env \
      --format "{{.ID}}" \
      --latest)

    if [ -z $IMAGE ]
    then
      echo "Could not find docker image. Exiting..."
      exit 1
    fi

    PIDFILE=/tmp/docker-exec-$$.pid
    NAMEFILE=/tmp/docker-exec-$$.name

    trap interrupt_exec INT

    docker exec -t -u $(id -u):$(id -g) \
       -e COLUMNS="`tput cols`" -e LINES="`tput lines`" \
       $IMAGE \
      bash -c "echo \"\$\$\" > \"$PIDFILE\"; echo \"$*\" > \"$NAMEFILE\";$*"
    CODE=$?

    docker exec -t $IMAGE sh -c "rm -f $PIDFILE"
    docker exec -t $IMAGE sh -c "rm -f $NAMEFILE"

    exit $CODE
}

docker_exec "$@"
