#!/bin/bash
set -e

# set env var
GOLANG_VERSION=$1
# Go 1.4 required to build Go 1.5
GOROOT_BOOTSTRAP_VERSION=1.4.3
TAR_FILE=go-v$GOLANG_VERSION-linux-$ARCH.tar.gz
BUCKET_NAME=$BUCKET_NAME

COMMIT_1_4_3='50eb39bb23e8b03e823c38e844f0410d0b5325d2'
COMMIT_1_5_1='f2e4c8b5fb3660d793b2c545ef207153db0a34b1'
COMMIT_1_5_2='40cbf58f960a8f5287d2c3a93b3ca6119df67e85'

# comparing version: http://stackoverflow.com/questions/16989598/bash-comparing-version-numbers
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" == "$1"; }

# in order to build Go 1.5, need to download Go 1.4 first
if version_le $GOLANG_VERSION "1.5"; then
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
	'armel')
		export GOARM=5
	;;
esac

# compile Go
echo $GOARM

COMMIT=COMMIT_${GOLANG_VERSION//./_}
cd go && git checkout $(eval echo \$$COMMIT)

if version_le "1.5.1" $GOLANG_VERSION; then
	patch -p1 < /patches/golang-$GOLANG_VERSION.patch
fi

cd src \
	&& ./make.bash --no-clean 2>&1 \
	&& cd / \
	&& tar -cvzf $TAR_FILE go/*

curl -SLO "http://resin-packages.s3.amazonaws.com/SHASUMS256.txt"
sha256sum $TAR_FILE >> SHASUMS256.txt

# Upload to S3 (using AWS CLI)
printf "$ACCESS_KEY\n$SECRET_KEY\n$REGION_NAME\n\n" | aws configure
aws s3 cp $TAR_FILE s3://$BUCKET_NAME/golang/v$GOLANG_VERSION/
aws s3 cp SHASUMS256.txt s3://$BUCKET_NAME/

