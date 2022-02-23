FROM #{FROM}

#{QEMU}

RUN apk add --no-cache git build-base gcc curl python3 python3-dev py-pip wget ca-certificates musl-dev openssl coreutils go

# Install AWS CLI
RUN pip install awscli

COPY . /
