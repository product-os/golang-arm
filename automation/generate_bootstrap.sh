#!/bin/bash

# Jenkins build steps

for ARCH in $ARCHS
do
	if [[ $ARCH == *"alpine"* ]]; then
		cp -f Dockerfile.alpine.bootstrap Dockerfile
		tag='alpine'
	else
		cp -f Dockerfile.debian.bootstrap Dockerfile
		tag='debian'
	fi

	docker build -t go-bootstrap-builder:$tag .
	docker run --rm -e ARCH=$ARCH \
					-e ACCESS_KEY=$ACCESS_KEY \
					-e SECRET_KEY=$SECRET_KEY \
					-e BUCKET_NAME=$BUCKET_NAME go-bootstrap-builder:$tag bash -ex bootstrap.sh
done

# Clean up builder image after every run
docker rmi $(docker images -q go-bootstrap-builder)
