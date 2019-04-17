#!/bin/bash

PORT=9000
USER=illuminate
HOST="comran.org"
LOCAL_BAZEL_RASPI_OUTPUT_ROOT="tools/cache/bazel/execroot/com_illuminate/bazel-out/raspi-fastbuild/bin"
#LOCAL_BAZEL_RASPI_OUTPUT_ROOT="./"
REMOTE_PATH="/home/$USER/illuminate"

rsync \
  -rvz \
  -e "ssh -p $PORT" \
  --progress \
  --bwlimit=100 \
  "$LOCAL_BAZEL_RASPI_OUTPUT_ROOT/$1" "$USER@$HOST":"$REMOTE_PATH"

#ssh -p $PORT "$USER@$HOST" killall display || true
