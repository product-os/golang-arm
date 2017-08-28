FROM #{FROM}

#{QEMU}

RUN echo deb http://ftp.debian.org/debian jessie-backports main > /etc/apt/sources.list.d/backports.list \
		&& apt-get -q update \
		&& apt-get install -y git-core build-essential mercurial gcc libc6-dev curl python python-dev python-pip wget ca-certificates libssl-dev golang-go --no-install-recommends \
		&& apt-get clean \
		&& rm -rf /var/lib/apt/lists/*

# Install AWS CLI
RUN pip install awscli

COPY . /
