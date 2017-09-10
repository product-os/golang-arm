#!/bin/bash
set -e
set -o pipefail

BOOTSTRAP_COMMIT='2b7a7b710f096b1b7e6f2ab5e9e3ec003ad7cd12' #release-branch.go1.7
BUCKET_NAME=$BUCKET_NAME
TAR_FILE=go-linux-$ARCH-bootstrap.tbz

mkdir /go-bootstrap
if [[ $ARCH == *"alpine"* ]]; then
	wget http://resin-packages.s3.amazonaws.com/golang/v1.7/go1.7.linux-alpine-amd64.tar.gz
	echo "90c4ca24818632f65903490c1637594860a2a27fe731735a7ee1ea28b73a144d  go1.7.linux-alpine-amd64.tar.gz" | sha256sum -c -
	tar -xzf go1.7.linux-alpine-amd64.tar.gz -C /go-bootstrap --strip-components=1
	rm go1.7.linux-alpine-amd64.tar.gz
else
	wget https://storage.googleapis.com/golang/go1.7.linux-amd64.tar.gz
	echo "702ad90f705365227e902b42d91dd1a40e48ca7f67a2f4b2fd052aaa4295cd95  go1.7.linux-amd64.tar.gz" | sha256sum -c -
	tar -xzf go1.7.linux-amd64.tar.gz -C /go-bootstrap --strip-components=1
	rm go1.7.linux-amd64.tar.gz
fi
export GOROOT_BOOTSTRAP=/go-bootstrap

case "$ARCH" in
	'armv6hf')
		export GOARM=6
		export GOARCH=arm
	;;
	'armv7hf')
		export GOARM=7
		export GOARCH=arm
	;;
	'armel')
		export GOARM=5
		export GOARCH=arm
	;;
	'aarch64'|'alpine-aarch64')
		export GOARCH=arm64
	;;
	'alpine-armhf')
		export GOARM=7
		export GOARCH=arm
	;;
	'alpine-i386')
		export GOARCH=386
	;;
	'i386')
		export GOARCH=386
	;;
	*)
		export GOARCH=amd64
	;;
esac

# compile Go
echo "GOARM: $GOARM"
echo "GOARCH: $GOARCH"

git clone https://go.googlesource.com/go /go

cd go/src
git checkout "$BOOTSTRAP_COMMIT"
rm -fr ../../go-linux-*-bootstrap
GOOS=linux GOARCH=$GOARCH ./bootstrap.bash
cd /
if [[ $ARCH == *"alpine"* ]]; then
	mv go-linux-$GOARCH-bootstrap.tbz go-linux-$ARCH-bootstrap.tbz
fi
curl -SLO "http://resin-packages.s3.amazonaws.com/SHASUMS256.txt"
sha256sum $TAR_FILE >> SHASUMS256.txt

# Upload to S3 (using AWS CLI)
printf "$ACCESS_KEY\n$SECRET_KEY\n$REGION_NAME\n\n" | aws configure
aws s3 cp $TAR_FILE s3://$BUCKET_NAME/golang/bootstrap/
aws s3 cp SHASUMS256.txt s3://$BUCKET_NAME/
