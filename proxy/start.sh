#!/bin/bash

source config.env
docker kill vsproxy
docker rm vsproxy
docker build -t vsproxy .
docker run \
  -d \
  --name vsproxy \
  --restart always \
  -e USER="${AUTHUSER}" \
  -e PASS="${AUTHPASS}" \
  -p 3001:3001 \
  --link vscode:vscode \
  vsproxy:latest
