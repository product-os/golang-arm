#!/bin/bash
set -e

# set env var
GOLANG_VERSION=$1
# Go 1.4 required to build Go 1.5
GOROOT_BOOTSTRAP_VERSION=1.4.3
TAR_FILE=go-v$GOLANG_VERSION-linux-$ARCH.tar.gz
BUCKET_NAME=$BUCKET_NAME

# comparing version: http://stackoverflow.com/questions/16989598/bash-comparing-version-numbers
function version_cmp() { test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" == "$1"; }

# in order to build Go 1.5, need to download Go 1.4 first
if version_cmp $GOLANG_VERSION "1.5"; then
	mkdir /go-bootstrap
	wget http://resin-packages.s3.amazonaws.com/golang/v$GOROOT_BOOTSTRAP_VERSION/go-v$GOROOT_BOOTSTRAP_VERSION-linux-$ARCH.tar.gz
	tar -xzf "go-v$GOROOT_BOOTSTRAP_VERSION-linux-$ARCH.tar.gz" -C /go-bootstrap --strip-components=1
	rm go-v$GOROOT_BOOTSTRAP_VERSION-linux-$ARCH.tar.gz
	export GOROOT_BOOTSTRAP=/go-bootstrap
fi

case "$ARCH" in
	'armv6hf')
		export GOARM=6
	;;
	'armv7hf')
		export GOARM=7
	;;
esac
# compile Go
echo $GOARM
cd go/src \
	&& git checkout go$GOLANG_VERSION \
	&& ./make.bash --no-clean 2>&1 \
	&& cd / \
	&& tar -cvzf go-v$GOLANG_VERSION-linux-$ARCH.tar.gz go/*

# Upload to S3 (using AWS CLI)
printf "$ACCESS_KEY\n$SECRET_KEY\n$REGION_NAME\n\n" | aws configure
aws s3 cp $TAR_FILE s3://$BUCKET_NAME/golang/v$GOLANG_VERSION/
