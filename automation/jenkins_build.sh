#!/bin/bash

# Jenkins build steps

for ARCH in $ARCHS
do
	case "$ARCH" in
		'armv6hf')
			sed -e s~#{FROM}~balenalib/rpi-raspbian:jessie~g \
				-e s~#{QEMU}~"COPY qemu/qemu-arm-static /usr/bin/"~g Dockerfile.debian.tpl > Dockerfile
		;;
		'armv7hf')
			sed -e s~#{FROM}~balenalib/armv7hf-debian:jessie~g \
				-e s~#{QEMU}~"COPY qemu/qemu-arm-static /usr/bin/"~g Dockerfile.debian.tpl > Dockerfile
		;;
		'armel')
			sed -e s~#{FROM}~balenalib/armel-debian:jessie~g \
				-e s~#{QEMU}~"COPY qemu/qemu-arm-static /usr/bin/"~g Dockerfile.debian.tpl > Dockerfile
		;;
		'aarch64')
			sed -e s~#{FROM}~balenalib/aarch64-debian:jessie~g \
				-e s~#{QEMU}~"COPY qemu/qemu-aarch64-static /usr/bin/"~g Dockerfile.debian.tpl > Dockerfile
		;;
		'i386')
			sed -e s~#{FROM}~balenalib/i386-debian:jessie~g \
				-e s~#{QEMU}~""~g Dockerfile.debian.tpl > Dockerfile
		;;
		'i386-nlp')
			sed -e s~#{FROM}~balenalib/i386-nlp-debian:jessie~g \
				-e s~#{QEMU}~""~g Dockerfile.debian.tpl > Dockerfile
		;;
		'alpine-armv6hf')
			sed -e s~#{FROM}~balenalib/rpi-alpine:3.9~g \
				-e s~#{QEMU}~"COPY qemu/qemu-arm-static /usr/bin/"~g Dockerfile.alpine.tpl > Dockerfile
		;;
		'alpine-i386')
			sed -e s~#{FROM}~balenalib/i386-alpine:3.9~g \
				-e s~#{QEMU}~""~g Dockerfile.alpine.tpl > Dockerfile
		;;
		'alpine-amd64')
			sed -e s~#{FROM}~balenalib/amd64-alpine:3.9~g \
				-e s~#{QEMU}~""~g Dockerfile.alpine.tpl > Dockerfile
		;;
		'alpine-aarch64')
			sed -e s~#{FROM}~balenalib/aarch64-alpine:3.9~g \
				-e s~#{QEMU}~"COPY qemu/qemu-aarch64-static /usr/bin/"~g Dockerfile.alpine.tpl > Dockerfile
		;;
		'alpine-armv7hf')
			# armv7hf-alpine v3.9 and later are armv7
			sed -e s~#{FROM}~balenalib/armv7hf-alpine:3.9~g \
				-e s~#{QEMU}~"COPY qemu/qemu-arm-static /usr/bin/"~g Dockerfile.alpine.tpl > Dockerfile
		;;
	esac
	docker build -t go-$ARCH-builder .
	for GO_VERSION in $GO_VERSIONS
	do
		docker run --rm -e ARCH=$ARCH \
						-e ACCESS_KEY=$ACCESS_KEY \
						-e SECRET_KEY=$SECRET_KEY \
						-e BUCKET_NAME=$BUCKET_NAME go-$ARCH-builder bash -ex build.sh $GO_VERSION
	done
done

# Clean up builder image after every run
docker rmi -f go-$ARCH-builder
