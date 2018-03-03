FROM #{FROM}

#{QEMU}

RUN apt-key adv --keyserver keyserver.ubuntu.com --recv-key 8B48AD6246925553 \
	&& apt-key adv --keyserver keyserver.ubuntu.com --recv-key 7638D0442B90D010 \
	&& echo deb http://ftp.debian.org/debian jessie-backports main > /etc/apt/sources.list.d/backports.list \
	&& apt-get -q update \
	&& apt-get install -y git-core build-essential mercurial gcc libc6-dev curl python python-dev python-pip wget ca-certificates libssl-dev  --no-install-recommends \
	&& apt-get -t jessie-backports install -y golang-go \
	&& apt-get clean \
	&& rm -rf /var/lib/apt/lists/*

# Install AWS CLI
RUN pip install awscli

COPY . /
