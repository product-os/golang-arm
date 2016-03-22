FROM #{FROM}

RUN apt-get -q update \
		&& apt-get install -y git-core build-essential mercurial gcc libc6-dev curl python python-dev python-pip wget ca-certificates libssl-dev --no-install-recommends \
		&& apt-get clean \
		&& rm -rf /var/lib/apt/lists/*

# Install AWS CLI
RUN pip install awscli

RUN git clone https://go.googlesource.com/go

COPY . /
