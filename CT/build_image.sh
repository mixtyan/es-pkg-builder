#!/bin/bash

docker build -t ct-pkg-builder:test . --build-arg SSH_PRIVATE_KEY="$(cat ~/.ssh/id_rsa)"