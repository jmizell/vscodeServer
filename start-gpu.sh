#!/bin/bash

docker run \
  -d \
  --init \
  --gpus all \
  --name vscode \
  --restart always \
  -p 4860:4860 \
  -v "${HOME}/Projects:/home/workspace/projects" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v "${HOME}/.gitconfig:/home/workspace/.gitconfig" \
  -v "${HOME}/.ssh:/home/workspace/.ssh" \
  jmizell/nvidia-vscodeserver:latest
