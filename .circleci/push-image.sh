#!/bin/bash

echo "Pushing $DOCKERHUB_DOCKEFILE to dockerhub repository $DOCKERHUB_DESTINATION"
sudo docker $DOCKER_OPTIONS login --username=$DOCKERHUB_USER --password=$DOCKERHUB_PASS
sudo docker $DOCKER_OPTIONS build --pull -t $DOCKERHUB_DESTINATION -f "$DOCKERHUB_DOCKEFILE" "$NODE_NAME/$NODE_VERSION"
sudo docker $DOCKER_OPTIONS push $DOCKERHUB_DESTINATION