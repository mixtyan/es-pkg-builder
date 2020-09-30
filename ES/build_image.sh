#!/bin/bash

docker build -t es-pkg-builder:test . --build-arg SSH_PRIVATE_KEY="$(cat ~/.ssh/id_rsa)"