#!/bin/bash

echo "Pushing $DOCKERHUB_DOCKEFILE to dockerhub repository $DOCKERHUB_DESTINATION"
sudo docker $DOCKER_OPTIONS login --username=$DOCKERHUB_USER --password=$DOCKERHUB_PASS
sudo docker buildx create --use
DOCKER_BUILDX_OPTS="--platform linux/amd64,linux/arm64,linux/arm/v7 --push"
sudo docker buildx build $DOCKER_BUILDX_OPTS \
    -f "$DOCKERHUB_DOCKEFILE" \
    -t $DOCKERHUB_DESTINATION \
    "$NODE_NAME/$NODE_VERSION"
