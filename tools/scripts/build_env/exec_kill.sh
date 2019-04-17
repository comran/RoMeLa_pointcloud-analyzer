#!/bin/bash

IMAGE=$(docker ps \
  --filter status=running \
  --filter name=illuminate_build_env \
  --format "{{.ID}}" \
  --latest)

if [ -z $IMAGE ]
then
  exit 1
fi

docker exec -t $IMAGE sh -c " \
  for f in /tmp/docker-exec-*.pid
  do
    if [ ! -f \"\$f\" ]
    then
      continue
    fi

    PID=\$(cat \"\$f\")
    echo \"KILLING \$PID\"
    kill -15 \$PID > /dev/null 2>&1 || true
    rm \$f
  done"
