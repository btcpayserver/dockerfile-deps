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
ARCHITECTURES=()
VARIANTS=()

add_image() {
    local dockerfile="$1" suffix="$2" architecture="$3" variant="$4"
    local image manifest digest
    [ -f "$dockerfile" ] || return 0

    image="$DOCKERHUB_DESTINATION-$suffix"
    manifest=$(sudo docker "${DOCKER_ARGS[@]}" buildx imagetools inspect --raw "$image")
    # Newer builders wrap even single-platform images in an index with attestations.
    # docker manifest create requires leaf image manifests, not nested indexes.
    digest=$(jq -er '
        def image_manifest:
            . == "application/vnd.oci.image.manifest.v1+json" or
            . == "application/vnd.docker.distribution.manifest.v2+json";
        if .mediaType == "application/vnd.oci.image.index.v1+json" or
           .mediaType == "application/vnd.docker.distribution.manifest.list.v2+json" then
            [.manifests[] | select(
                (.mediaType | image_manifest) and
                .platform.os != "unknown" and
                .annotations["vnd.docker.reference.type"] != "attestation-manifest"
            )] |
            if length == 1 and (.[0].digest | test("^sha256:[0-9a-f]{64}$")) then
                .[0].digest
            else
                error("Expected exactly one runnable image manifest in architecture tag")
            end
        elif .mediaType | image_manifest then
            ""
        else
            error("Unsupported architecture image manifest format")
        end
    ' <<< "$manifest")
    if [ -n "$digest" ]; then
        image="$DOCKERHUB_REPO@$digest"
    fi

    IMAGES+=("$image")
    ARCHITECTURES+=("$architecture")
    VARIANTS+=("$variant")
}

add_image "$DOCKERHUB_DOCKEFILE_AMD64" amd64 amd64 ""
add_image "$DOCKERHUB_DOCKEFILE_ARM64" arm64v8 arm64 v8
add_image "$DOCKERHUB_DOCKEFILE_ARM32" arm32v7 arm v7

if [ "${#IMAGES[@]}" -eq 0 ]; then
    echo "Skipping $DOCKERHUB_DESTINATION as there were no supported platforms to build for"
    exit 0
fi

sudo docker "${DOCKER_ARGS[@]}" manifest create --amend "$DOCKERHUB_DESTINATION" "${IMAGES[@]}"
for i in "${!IMAGES[@]}"; do
    ANNOTATION_ARGS=(--os linux --arch "${ARCHITECTURES[$i]}")
    if [ -n "${VARIANTS[$i]}" ]; then
        ANNOTATION_ARGS+=(--variant "${VARIANTS[$i]}")
    fi
    sudo docker "${DOCKER_ARGS[@]}" manifest annotate \
        "$DOCKERHUB_DESTINATION" "${IMAGES[$i]}" "${ANNOTATION_ARGS[@]}"
done
sudo docker "${DOCKER_ARGS[@]}" manifest push "$DOCKERHUB_DESTINATION" -p
