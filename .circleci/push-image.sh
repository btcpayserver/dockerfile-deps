#!/bin/bash

echo "Pushing $DOCKERHUB_DOCKEFILE to dockerhub repository $DOCKERHUB_DESTINATION"
sudo docker login --username=$DOCKERHUB_USER --password=$DOCKERHUB_PASS
sudo docker build --pull -t $DOCKERHUB_DESTINATION -f "$DOCKERHUB_DOCKEFILE" "$NODE_NAME/$NODE_VERSION"
sudo docker push $DOCKERHUB_DESTINATION