#!/usr/bin/env bash

NETWORK_NAME="proxy-net"
SUBNET="172.21.0.0/16"
GATEWAY="172.21.0.1"

if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
  echo "Docker network '$NETWORK_NAME' already exists."
  exit 0
fi

docker network create \
  --driver bridge \
  --subnet "$SUBNET" \
  --gateway "$GATEWAY" \
  "$NETWORK_NAME"

echo "Docker network '$NETWORK_NAME' created with subnet $SUBNET and gateway $GATEWAY"