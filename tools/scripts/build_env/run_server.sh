#!/bin/bash

mkdir -p tools/cache/checksums
CHECKSUM=$(md5sum src/messages.proto)
MATCH=0

if [ -f tools/cache/checksums/messages.proto.md5 ]
then
  LAST_CHECKSUM=$(cat tools/cache/checksums/messages.proto.md5)

  CHECKSUM=$(echo -e "${CHECKSUM}" | tr -d '[:space:]')
  LAST_CHECKSUM=$(echo -e "${LAST_CHECKSUM}" | tr -d '[:space:]')

  if [ "$CHECKSUM" = "$LAST_CHECKSUM" ]
  then
    MATCH=1
  fi
fi

if [ $MATCH -eq 0 ]
then
  echo "messages.proto updated; re-running python protobuf generator..."
  protoc -I=src --python_out=tools/cache/proto src/messages.proto

  CHECKSUM=$(md5sum src/messages.proto)
  echo $CHECKSUM > tools/cache/checksums/messages.proto.md5
fi

python3.7 src/server/server.py $@