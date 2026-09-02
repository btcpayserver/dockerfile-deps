#!/bin/bash

set -euo pipefail

IMAGE_TYPE="${1:?Image type is required}"
MODE="${2:?Mode is required}"
DOCKER_HOST="${DOCKER_HOST:-}"

if [ "$MODE" != "build" ] && [ "$MODE" != "publish" ]; then
    echo "Unsupported mode: $MODE" >&2
    exit 1
fi

source ".github/scripts/parse-tag.sh"

DOCKER_ARGS=()
if [ -n "$DOCKER_OPTIONS" ]; then
    DOCKER_ARGS=("$DOCKER_OPTIONS")
fi

case "$IMAGE_TYPE" in
    linuxamd64)
        DOCKERHUB_DOCKEFILE="$DOCKERHUB_DOCKEFILE_AMD64"
        DOCKERHUB_DESTINATION="$DOCKERHUB_REPO:$LATEST_TAG-amd64"
        ;;
    linuxarm32v7)
        DOCKERHUB_DOCKEFILE="$DOCKERHUB_DOCKEFILE_ARM32"
        DOCKERHUB_DESTINATION="$DOCKERHUB_REPO:$LATEST_TAG-arm32v7"
        ;;
    linuxarm64v8)
        DOCKERHUB_DOCKEFILE="$DOCKERHUB_DOCKEFILE_ARM64"
        DOCKERHUB_DESTINATION="$DOCKERHUB_REPO:$LATEST_TAG-arm64v8"
        ;;
    buildx)
        DOCKERHUB_DOCKEFILE="$DOCKERHUB_DOCKEFILE_BUILDX"
        DOCKERHUB_DESTINATION="$DOCKERHUB_REPO:$LATEST_TAG"
        ;;
    *)
        echo "Unsupported image type: $IMAGE_TYPE" >&2
        exit 1
        ;;
esac

if [ ! -f "$DOCKERHUB_DOCKEFILE" ]; then
    echo "Skipping $IMAGE_TYPE because $DOCKERHUB_DOCKEFILE is not found"
    exit 0
fi

if [ "$IMAGE_TYPE" = "linuxarm32v7" ]; then
    sudo docker "${DOCKER_ARGS[@]}" run --rm --privileged multiarch/qemu-user-static:register --reset
    if grep "#EnableQEMU" "$DOCKERHUB_DOCKEFILE"; then
        sudo apt update
        sudo apt install -y qemu-user-static qemu-user binfmt-support
        sudo cp /usr/bin/qemu-arm-static "$(dirname "$DOCKERHUB_DOCKEFILE")/qemu-arm-static"
        sed -i -e 's/#EnableQEMU //g' "$DOCKERHUB_DOCKEFILE"
    fi
elif [ "$IMAGE_TYPE" = "linuxarm64v8" ]; then
    sudo docker "${DOCKER_ARGS[@]}" run --rm --privileged multiarch/qemu-user-static:register --reset
    sudo apt update
    sudo apt install -y qemu-user-static qemu-user binfmt-support
    sudo cp /usr/bin/qemu-aarch64-static "$(dirname "$DOCKERHUB_DOCKEFILE")/qemu-aarch64-static"
    sed -i -e 's/#EnableQEMU //g' "$DOCKERHUB_DOCKEFILE"
fi

if [ "$MODE" = "publish" ]; then
    echo "Pushing $DOCKERHUB_DOCKEFILE to dockerhub repository $DOCKERHUB_DESTINATION"
    sudo docker $DOCKER_OPTIONS login --username="$DOCKERHUB_USER" --password="$DOCKERHUB_PASS"
    if [ "$IMAGE_TYPE" = "buildx" ]; then
        sudo docker buildx create --use
        DOCKER_BUILDX_OPTS="--platform linux/amd64,linux/arm64,linux/arm/v7 --push"
        sudo docker buildx build $DOCKER_BUILDX_OPTS \
            -f "$DOCKERHUB_DOCKEFILE" \
            -t "$DOCKERHUB_DESTINATION" \
            "$NODE_NAME/$NODE_VERSION"
    else
        sudo docker $DOCKER_OPTIONS build --pull -t "$DOCKERHUB_DESTINATION" -f "$DOCKERHUB_DOCKEFILE" "$NODE_NAME/$NODE_VERSION"
        sudo docker $DOCKER_OPTIONS push "$DOCKERHUB_DESTINATION"
    fi
elif [ "$IMAGE_TYPE" = "buildx" ]; then
    docker buildx build \
        --platform linux/amd64,linux/arm64,linux/arm/v7 \
        -f "$DOCKERHUB_DOCKEFILE" \
        -t "$DOCKERHUB_DESTINATION" \
        "$NODE_NAME/$NODE_VERSION"
else
    sudo docker "${DOCKER_ARGS[@]}" build --pull \
        -t "$DOCKERHUB_DESTINATION" \
        -f "$DOCKERHUB_DOCKEFILE" \
        "$NODE_NAME/$NODE_VERSION"
fi
