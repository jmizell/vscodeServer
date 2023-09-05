FROM nvidia/cuda:11.8.0-cudnn8-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND="noninteractive"

RUN set -eux; \
	apt-get update; \
    apt-get -o Acquire::ForceIPv4=true update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
		curl \
		netbase \
		wget \
		tzdata \
	; \
	rm -rf /var/lib/apt/lists/*

RUN set -ex; \
	if ! command -v gpg > /dev/null; then \
		apt-get update; \
		apt-get install -y --no-install-recommends \
			gnupg \
			dirmngr \
		; \
		rm -rf /var/lib/apt/lists/*; \
	fi

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        aptitude build-essential bzip2 colordiff curl dnsutils ffmpeg \
        git git git-annex git-cvs git-lfs git-secrets git-svn gnupg \
        grep gzip imagemagick iperf jq libatomic1 mariadb-client node-npm nodejs \
        openjdk-19-jdk-headless p7zip php8.1 pigz postgresql-client \
        python-setuptools-doc python3 python3-all-dev python3-doc \
        python3-pip python3-tk python3-venv \
        rsync ruby sqlite sqlite3 sudo tmux vim wget zip \
    && rm -rf /var/lib/apt/lists/*

ENV PATH="$PATH:/usr/local/bin"

RUN export GO_VERSION="$(curl -s https://go.dev/VERSION?m=text | head -n 1)" \
    && wget "https://golang.org/dl/${GO_VERSION}.linux-amd64.tar.gz" -O go.tar.gz

RUN mkdir -p /usr/local/lib/go \
    && mkdir -p /usr/local/bin \
    && pigz -df go.tar.gz \
    && tar -xvf go.tar \
    && mv -v go /usr/local/lib/ \
    && ln -vs /usr/local/lib/go/bin/go /usr/local/bin/go \
    && ln -vs /usr/local/lib/go/bin/gofmt /usr/local/bin/gofmt \
    && rm go.tar

RUN go install github.com/golang/mock/mockgen@latest
RUN go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest 
RUN go install golang.org/x/tools/cmd/goimports@latest 
RUN go install github.com/traefik/yaegi/cmd/yaegi@latest
RUN go install -v golang.org/x/tools/gopls@latest
RUN go install honnef.co/go/tools/cmd/staticcheck@latest
RUN go install github.com/go-delve/delve/cmd/dlv@latest
RUN go install -v github.com/josharian/impl@latest
RUN mv /root/go/bin/* /usr/local/bin/ && rm -rf /root/go

RUN pip3 install --upgrade pip 
RUN pip3 install --upgrade awscli 
RUN pip3 install --upgrade virtualenv
RUN pip3 install --upgrade jupyterlab
RUN pip3 install --upgrade voila

RUN groupadd --gid 998 docker && curl -sSL https://get.docker.com/ | sh

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV PATH /opt/conda/bin:$PATH

ARG ANACONDA_URL="https://repo.anaconda.com/archive/Anaconda3-2022.10-Linux-x86_64.sh"
ARG SHA256SUM="e7ecbccbc197ebd7e1f211c59df2e37bc6959d081f2235d387e08c9026666acd"

RUN set -x && \
    apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends \
        bzip2 \
        ca-certificates \
        git \
        libglib2.0-0 \
        libsm6 \
        libxcomposite1 \
        libxcursor1 \
        libxdamage1 \
        libxext6 \
        libxfixes3 \
        libxi6 \
        libxinerama1 \
        libxrandr2 \
        libxrender1 \
        mercurial \
        openssh-client \
        procps \
        subversion \
        wget \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* && \
    wget "${ANACONDA_URL}" -O anaconda.sh -q && \
    echo "${SHA256SUM} anaconda.sh" > shasum && \
    sha256sum --check --status shasum && \
    /bin/bash anaconda.sh -b -p /opt/conda && \
    rm anaconda.sh shasum && \
    ln -s /opt/conda/etc/profile.d/conda.sh /etc/profile.d/conda.sh && \
    echo ". /opt/conda/etc/profile.d/conda.sh" >> ~/.bashrc && \
    echo "conda activate base" >> ~/.bashrc && \
    find /opt/conda/ -follow -type f -name '*.a' -delete && \
    find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
    /opt/conda/bin/conda clean -afy


WORKDIR /home/

ARG RELEASE_TAG="openvscode-server-v1.76.2"
ARG RELEASE_ORG="gitpod-io"
ARG OPENVSCODE_SERVER_ROOT="/home/.openvscode-server"

# Downloading the latest VSC Server release and extracting the release archive
# Rename `openvscode-server` cli tool to `code` for convenience
RUN if [ -z "${RELEASE_TAG}" ]; then \
        echo "The RELEASE_TAG build arg must be set." >&2 && \
        exit 1; \
    fi && \
    arch="x64"; \
    wget https://github.com/${RELEASE_ORG}/openvscode-server/releases/download/${RELEASE_TAG}/${RELEASE_TAG}-linux-${arch}.tar.gz && \
    tar -xzf ${RELEASE_TAG}-linux-${arch}.tar.gz && \
    mv -f ${RELEASE_TAG}-linux-${arch} ${OPENVSCODE_SERVER_ROOT} && \
    cp ${OPENVSCODE_SERVER_ROOT}/bin/remote-cli/openvscode-server ${OPENVSCODE_SERVER_ROOT}/bin/remote-cli/code && \
    rm -f ${RELEASE_TAG}-linux-${arch}.tar.gz

ARG USERNAME=openvscode-server
ARG USER_UID=1004
ARG USER_GID=$USER_UID

# Creating the user and usergroup
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USERNAME -m -s /bin/bash $USERNAME \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

RUN chmod g+rw /home && \
    mkdir -p /home/workspace && \
    chown -R $USERNAME:$USERNAME /home/workspace && \
    chown -R $USERNAME:$USERNAME ${OPENVSCODE_SERVER_ROOT}

RUN usermod -aG docker $USERNAME

ENV OPENVSCODE="${OPENVSCODE_SERVER_ROOT}/bin/openvscode-server"
SHELL ["/bin/bash", "-c"]
USER $USERNAME

WORKDIR /home/workspace/

ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    HOME=/home/workspace \
    EDITOR=code \
    VISUAL=code \
    GIT_EDITOR="code --wait" \
    OPENVSCODE_SERVER_ROOT=${OPENVSCODE_SERVER_ROOT}

# Default exposed port if none is specified
EXPOSE 3000

ENTRYPOINT [ "/bin/sh", "-c", "exec ${OPENVSCODE_SERVER_ROOT}/bin/openvscode-server --host 0.0.0.0 --without-connection-token \"${@}\"", "--" ]

SHELL ["/bin/bash", "-c"]
# RUN /home/.openvscode-server/bin/openvscode-server --install-extension ms-toolsai.jupyter 
RUN /home/.openvscode-server/bin/openvscode-server --install-extension gitpod.gitpod-theme
RUN /home/.openvscode-server/bin/openvscode-server --install-extension ms-python.anaconda-extension-pack
RUN /home/.openvscode-server/bin/openvscode-server --install-extension Kelvin.vscode-sshfs
RUN /home/.openvscode-server/bin/openvscode-server --install-extension ms-python.pylint
RUN /home/.openvscode-server/bin/openvscode-server --install-extension ms-python.anaconda-extension-pack
RUN /home/.openvscode-server/bin/openvscode-server --install-extension ms-python.python 
RUN /home/.openvscode-server/bin/openvscode-server --install-extension golang.go
RUN /home/.openvscode-server/bin/openvscode-server --install-extension ms-azuretools.vscode-docker
RUN /home/.openvscode-server/bin/openvscode-server --install-extension Rubberduck.rubberduck-vscode
