#!/bin/bash
set -e
set -o pipefail

# set env var
GOLANG_VERSION=$1
# Go 1.4 required to build Go 1.5
#GOROOT_BOOTSTRAP_VERSION=1.4.3
TAR_FILE=go$GOLANG_VERSION.linux-$ARCH.tar.gz
BUCKET_NAME=$BUCKET_NAME

# comparing version: http://stackoverflow.com/questions/16989598/bash-comparing-version-numbers
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" == "$1"; }
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" != "$1"; }

mkdir /go-bootstrap
wget http://resin-packages.s3.amazonaws.com/golang/bootstrap/go-linux-$ARCH-bootstrap.tbz
echo "$(grep " go-linux-$ARCH-bootstrap.tbz" /checksums-commit-table)" | sha256sum -c -
tar -xjf "go-linux-$ARCH-bootstrap.tbz" -C /go-bootstrap --strip-components=1
rm go-linux-$ARCH-bootstrap.tbz
export GOROOT_BOOTSTRAP=/go-bootstrap

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
	'aarch64'|'alpine-aarch64')
		export GOARCH=arm64
	;;
	'alpine-armhf')
		export GOARM=7
	;;
	'alpine-i386')
		export GOARCH=386
		export GOHOSTARCH=386
	;;
	'i386')
		export GO386=387
		export GOARCH=386
		export GOHOSTARCH=386
	;;
esac

# compile Go
echo "GOARM: $GOARM"
echo "GOARCH: $GOARCH"

mkdir go
curl -SLO "https://storage.googleapis.com/golang/go$GOLANG_VERSION.src.tar.gz"
echo "$(grep " go$GOLANG_VERSION.src.tar.gz" /checksums-commit-table)" | sha256sum -c -
tar -xzvf go$GOLANG_VERSION.src.tar.gz -C go --strip-components=1

cd go
# There is an issue with musl libc and Go v1.6 on Alpine i386 image (https://github.com/golang/go/issues/14476)
# So we need to patch Go (https://github.com/golang/go/commit/1439158120742e5f41825de90a76b680da64bf76)
if [ $ARCH == "alpine-i386" ] && [ $GOLANG_VERSION == "1.6" ]; then
	patch -p1 < /patches/golang-$ARCH-$GOLANG_VERSION.patch
fi

# Fix for https://golang.org/issue/14851. Apply on Go v1.5 and v1.6 on Alpine.
# Ref: https://github.com/docker-library/golang/commit/0f3ab4a3d2eba38991ab7b41941f1dc99f13dc3f
if [[ $ARCH == *"alpine"* ]]; then
	if (version_ge $GOLANG_VERSION "1.5") && (version_le $GOLANG_VERSION "1.7"); then
		patch -p1 < /patches/golang-alpine-no-pic.patch
	fi
fi

# Fix for https://github.com/golang/go/issues/20763, Apply on Go v1.7 and v1.8.
# Ref: https://github.com/golang/go/commit/2673f9ed23348c634f6331ee589d489e4d9c7a9b
if (version_ge $GOLANG_VERSION "1.7") && (version_le $GOLANG_VERSION "1.8"); then
	patch -p1 < /patches/0001-runtime-pass-CLONE_SYSVSEM-to-clone.patch
fi

cd src
./make.bash --no-clean 2>&1 \
	&& cd / \
	&& tar -cvzf $TAR_FILE go/*

curl -SLO "http://resin-packages.s3.amazonaws.com/SHASUMS256.txt"
sha256sum $TAR_FILE >> SHASUMS256.txt

# Upload to S3 (using AWS CLI)
printf "$ACCESS_KEY\n$SECRET_KEY\n$REGION_NAME\n\n" | aws configure
aws s3 cp $TAR_FILE s3://$BUCKET_NAME/golang/v$GOLANG_VERSION/
aws s3 cp SHASUMS256.txt s3://$BUCKET_NAME/
