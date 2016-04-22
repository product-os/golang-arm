#!/bin/bash
set -e
set -o pipefail

# set env var
GOLANG_VERSION=$1
# Go 1.4 required to build Go 1.5
GOROOT_BOOTSTRAP_VERSION=1.4.3
TAR_FILE=go$GOLANG_VERSION.linux-$ARCH.tar.gz
BUCKET_NAME=$BUCKET_NAME

# comparing version: http://stackoverflow.com/questions/16989598/bash-comparing-version-numbers
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" == "$1"; }

# in order to build Go 1.5, need to download Go 1.4 first
if version_ge $GOLANG_VERSION "1.5"; then
	mkdir /go-bootstrap
	wget http://resin-packages.s3.amazonaws.com/golang/v$GOROOT_BOOTSTRAP_VERSION/go$GOROOT_BOOTSTRAP_VERSION.linux-$ARCH.tar.gz
	echo "$(grep " go$GOROOT_BOOTSTRAP_VERSION.linux-$ARCH.tar.gz" /checksums-commit-table)" | sha256sum -c -
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

commit=($(echo "$(grep " go$GOLANG_VERSION$" /checksums-commit-table)" | tr " " "\n"))
cd go && git checkout ${commit[0]}

# There is an issue with musl libc and Go v1.6 on Alpine i386 image (https://github.com/golang/go/issues/14476)
# So we need to patch Go (https://github.com/golang/go/commit/1439158120742e5f41825de90a76b680da64bf76)
if [ $ARCH == "alpine-i386" ] && [ $GOLANG_VERSION == "1.6" ]; then
	patch -p1 < /patches/golang-$ARCH-$GOLANG_VERSION.patch
fi

# Fix for https://golang.org/issue/14851. Apply on Go v1.5 and higher on Alpine.
# Ref: https://github.com/docker-library/golang/commit/0f3ab4a3d2eba38991ab7b41941f1dc99f13dc3f
if [[ $ARCH == *"alpine"* ]]; then
	if version_ge $GOLANG_VERSION "1.5"; then
		patch -p1 < /patches/golang-alpine-no-pic.patch
	fi
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
