#!/bin/sh
sudo DOCKER_BUILDKIT=1 docker build --build-arg CACHE_DATE=$(date +%Y-%m-%d:%H:%M:%S) --pull --rm -f "Dockerfile" -t kaww:latest "."