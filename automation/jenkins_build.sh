#!/bin/bash

# Jenkins build steps

for ARCH in $ARCHS
do
	case "$ARCH" in
		'armv6hf')
			sed -i -e s~#{FROM}~resin/rpi-raspbian:latest~g Dockerfile
		;;
		'armv7hf')
			sed -i -e s~#{FROM}~resin/armv7hf-debian:latest~g Dockerfile
		;;
	esac
	docker build --no-cache=true -t go-$ARCH-builder .
	for GO_VERSION in $GO_VERSIONS
	do
		docker run --rm -e ARCH=$ARCH -e ACCESS_KEY=$ACCESS_KEY -e SECRET_KEY=$SECRET_KEY -e BUCKET_NAME=$BUCKET_NAME go-$ARCH-builder bash build.sh $GO_VERSION
    
	done
done
