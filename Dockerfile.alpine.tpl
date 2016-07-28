FROM #{FROM}

RUN apk add --no-cache git build-base gcc curl python python-dev py-pip wget ca-certificates musl-dev openssl coreutils

# Install AWS CLI
RUN pip install awscli

COPY . /
