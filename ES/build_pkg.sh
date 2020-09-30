#!/bin/bash

image_id=$1
type=$2

docker run -it -v /tmp/es-build:/tmp -v ~/.ssh:/root/.ssh $image_id $type $3 $4 $5