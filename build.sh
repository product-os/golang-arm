#!/bin/bash
set -e
set -o pipefail

# set env var
GOLANG_VERSION=$1
GOROOT_BOOTSTRAP_VERSION=1.18.9
TAR_FILE=go$GOLANG_VERSION.linux-$ARCH.tar.gz
BUCKET_NAME=$BUCKET_NAME

# comparing version: http://stackoverflow.com/questions/16989598/bash-comparing-version-numbers
function version_ge() { test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" == "$1"; }
function version_le() { test "$(echo "$@" | tr " " "\n" | sort -V | tail -n 1)" != "$1"; }

case "$ARCH" in
	'armv6hf')
		export GOARM=6
		curl -SL -o go-bootstrap.tar.gz "https://storage.googleapis.com/golang/go$GOROOT_BOOTSTRAP_VERSION.linux-armv6l.tar.gz"
		GOROOT_BOOTSTRAP_CHECKSUM=e01ef720700e1b198391e88dfca3d3b0e744c88348d0cc5ff560edf42555cb89
	;;
	'armv7hf')
		export GOARM=7
		curl -SL -o go-bootstrap.tar.gz "http://resin-packages.s3.amazonaws.com/golang/v$GOROOT_BOOTSTRAP_VERSION/go$GOROOT_BOOTSTRAP_VERSION.linux-armv7hf.tar.gz"
		GOROOT_BOOTSTRAP_CHECKSUM=63ae0c7e08c8068e19c07707dfb4470f79426cc8bc93aed3717e9a31fa405fc1
	;;
	'aarch64')
		export GOARCH=arm64
		curl -SL -o go-bootstrap.tar.gz "https://storage.googleapis.com/golang/go$GOROOT_BOOTSTRAP_VERSION.linux-arm64.tar.gz"
		GOROOT_BOOTSTRAP_CHECKSUM=ae21430756c69c48201c51c3a17ac785613d9616105959a0fb7592e407be8588
	;;
	'i386')
		export GOARCH=386
		export GOHOSTARCH=386
		curl -SL -o go-bootstrap.tar.gz "https://storage.googleapis.com/golang/go$GOROOT_BOOTSTRAP_VERSION.linux-386.tar.gz"
		GOROOT_BOOTSTRAP_CHECKSUM=2d78087a1e9627e69bbd8ed517a8fa37a8a505572dce3b16048458894492ef11
	;;
	'alpine-armv6hf')
		export GOARM=6
		curl -SL -o go-bootstrap.tar.gz "http://resin-packages.s3.amazonaws.com/golang/v$GOROOT_BOOTSTRAP_VERSION/go$GOROOT_BOOTSTRAP_VERSION.linux-alpine-armv6hf.tar.gz"
		GOROOT_BOOTSTRAP_CHECKSUM=c4110beadcc72fafae02b2545accf0ae5608c47705024f53928be79e56135366
	;;
	'alpine-armv7hf')
		export GOARM=7
		curl -SL -o go-bootstrap.tar.gz "http://resin-packages.s3.amazonaws.com/golang/v$GOROOT_BOOTSTRAP_VERSION/go$GOROOT_BOOTSTRAP_VERSION.linux-alpine-armv7hf.tar.gz"
		GOROOT_BOOTSTRAP_CHECKSUM=41e02efb554818f0f595b3b474c485311c906e4df38a2bdf310139a504737e63
	;;
	'alpine-aarch64')
		export GOARCH=arm64
		curl -SL -o go-bootstrap.tar.gz "http://resin-packages.s3.amazonaws.com/golang/v$GOROOT_BOOTSTRAP_VERSION/go$GOROOT_BOOTSTRAP_VERSION.linux-alpine-aarch64.tar.gz"
		GOROOT_BOOTSTRAP_CHECKSUM=3efa111a50257db31b7f9fe0b4e94405d1b5ad8a8217dcbcf0b77c9b375fa8b3
	;;
	'alpine-i386')
		export GOARCH=386
		export GOHOSTARCH=386
		curl -SL -o go-bootstrap.tar.gz "http://resin-packages.s3.amazonaws.com/golang/v$GOROOT_BOOTSTRAP_VERSION/go$GOROOT_BOOTSTRAP_VERSION.linux-alpine-i386.tar.gz"
		GOROOT_BOOTSTRAP_CHECKSUM=e22de72347e723e4a78b7df5fee8d145d607002c2bf37e38f8400c4a97f4ce28
	;;
	'alpine-amd64')
		curl -SL -o go-bootstrap.tar.gz "http://resin-packages.s3.amazonaws.com/golang/v$GOROOT_BOOTSTRAP_VERSION/go$GOROOT_BOOTSTRAP_VERSION.linux-alpine-amd64.tar.gz"
		GOROOT_BOOTSTRAP_CHECKSUM=1fac6e07aa24eb130c49ee8215ecbfddbfdac161d0f71534b569e01b5dbc182b
	;;
esac

mkdir /go-bootstrap
export GOROOT_BOOTSTRAP=/go-bootstrap
echo "$GOROOT_BOOTSTRAP_CHECKSUM  go-bootstrap.tar.gz" | sha256sum -c -
tar -xzf "go-bootstrap.tar.gz" -C /go-bootstrap --strip-components=1
rm -f go-bootstrap.tar.gz

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
