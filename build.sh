#!/bin/bash

OPENVPN_VERSION="2.7.0"
DOCKER_TAG="${OPENVPN_VERSION}-no-configs"

docker build -t openvpn:${DOCKER_TAG} .
docker tag openvpn:${DOCKER_TAG} warkat/openvpn:${DOCKER_TAG}
# docker push warkat/openvpn:2.7.0-no-configs
