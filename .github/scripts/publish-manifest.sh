#!/bin/bash

set -euo pipefail

DOCKER_HOST="${DOCKER_HOST:-}"
source ".github/scripts/parse-tag.sh"

DOCKER_ARGS=()
if [ -n "$DOCKER_OPTIONS" ]; then
    DOCKER_ARGS=("$DOCKER_OPTIONS")
fi

sudo docker "${DOCKER_ARGS[@]}" login --username="$DOCKERHUB_USER" --password="$DOCKERHUB_PASS"

IMAGES=()
if [ -f "$DOCKERHUB_DOCKEFILE_AMD64" ]; then
    IMAGES+=("$DOCKERHUB_DESTINATION-amd64")
fi
if [ -f "$DOCKERHUB_DOCKEFILE_ARM64" ]; then
    IMAGES+=("$DOCKERHUB_DESTINATION-arm64v8")
fi
if [ -f "$DOCKERHUB_DOCKEFILE_ARM32" ]; then
    IMAGES+=("$DOCKERHUB_DESTINATION-arm32v7")
fi

if [ "${#IMAGES[@]}" -eq 0 ]; then
    echo "Skipping $DOCKERHUB_DESTINATION as there were no supported platforms to build for"
    exit 0
fi

sudo docker manifest create --amend "$DOCKERHUB_DESTINATION" "${IMAGES[@]}"
if [ -f "$DOCKERHUB_DOCKEFILE_AMD64" ]; then
    sudo docker "${DOCKER_ARGS[@]}" manifest annotate "$DOCKERHUB_DESTINATION" "$DOCKERHUB_DESTINATION-amd64" --os linux --arch amd64
fi
if [ -f "$DOCKERHUB_DOCKEFILE_ARM32" ]; then
    sudo docker "${DOCKER_ARGS[@]}" manifest annotate "$DOCKERHUB_DESTINATION" "$DOCKERHUB_DESTINATION-arm32v7" --os linux --arch arm --variant v7
fi
if [ -f "$DOCKERHUB_DOCKEFILE_ARM64" ]; then
    sudo docker "${DOCKER_ARGS[@]}" manifest annotate "$DOCKERHUB_DESTINATION" "$DOCKERHUB_DESTINATION-arm64v8" --os linux --arch arm64 --variant v8
fi
sudo docker "${DOCKER_ARGS[@]}" manifest push "$DOCKERHUB_DESTINATION" -p
