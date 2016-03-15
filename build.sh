#!/bin/bash
set -e
set -o pipefail

# set env var
GOLANG_VERSION=$1
# Go 1.4 required to build Go 1.5
GOROOT_BOOTSTRAP_VERSION=1.4.3
TAR_FILE=go$GOLANG_VERSION.linux-$ARCH.tar.gz
BUCKET_NAME=$BUCKET_NAME

COMMIT_1_4_3='50eb39bb23e8b03e823c38e844f0410d0b5325d2'
COMMIT_1_5_1='f2e4c8b5fb3660d793b2c545ef207153db0a34b1'
COMMIT_1_5_2='40cbf58f960a8f5287d2c3a93b3ca6119df67e85'
COMMIT_1_5_3='27d5c0ede5b4411089f4bf52a41dd2f4eed36123'
COMMIT_1_6='7bc40ffb05d8813bf9b41a331b45d37216f9e747'

# comparing version: http://stackoverflow.com/questions/16989598/bash-comparing-version-numbers
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" == "$1"; }

# in order to build Go 1.5, need to download Go 1.4 first
if version_le $GOLANG_VERSION "1.5"; then
	mkdir /go-bootstrap
	wget http://resin-packages.s3.amazonaws.com/golang/v$GOROOT_BOOTSTRAP_VERSION/go$GOROOT_BOOTSTRAP_VERSION.linux-$ARCH.tar.gz
	tar -xzf "go$GOROOT_BOOTSTRAP_VERSION.linux-$ARCH.tar.gz" -C /go-bootstrap --strip-components=1
	rm go$GOROOT_BOOTSTRAP_VERSION.linux-$ARCH.tar.gz
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
	'alpine-armhf')
		export GOARM=7
	;;
	'alpine-i386')
		export GOARCH=386
		export GOHOSTARCH=386
	;;
esac

# compile Go
echo "GOARM: $GOARM"
echo "GOARCH: $GOARCH"

COMMIT=COMMIT_${GOLANG_VERSION//./_}
cd go && git checkout $(eval echo \$$COMMIT)

# There is an issue with musl libc and Go v1.6 on Alpine i386 image (https://github.com/golang/go/issues/14476)
# So we need to patch Go (https://github.com/golang/go/commit/1439158120742e5f41825de90a76b680da64bf76)
if [ $ARCH == "alpine-i386" ] && [ $GOLANG_VERSION == "1.6" ]; then
	patch -p1 < /patches/golang-$ARCH-$GOLANG_VERSION.patch
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
