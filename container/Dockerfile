FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HPC_DEV_VENV=/opt/hpc-dev/venv
ENV CODE_SERVER_VERSION=4.112.0
ENV RSTUDIO_SERVER_VERSION=2026.01.1-403
ENV DROPBEAR_VERSION=2025.89
ENV PATH="${HPC_DEV_VENV}/bin:/usr/local/sbin:/usr/local/bin:${PATH}"

RUN apt-get update && apt-get install -y \
    bash \
    build-essential \
    bzip2 \
    ca-certificates \
    curl \
    gdebi-core \
    git \
    iproute2 \
    less \
    netcat-openbsd \
    openssl \
    openssh-server \
    procps \
    python3 \
    r-base \
    python3-venv \
    zlib1g-dev \
    && curl -fsSLo "/tmp/rstudio-server.deb" "https://download2.rstudio.org/server/jammy/amd64/rstudio-server-${RSTUDIO_SERVER_VERSION}-amd64.deb" \
    && gdebi -n "/tmp/rstudio-server.deb" \
    && rm -f "/tmp/rstudio-server.deb" \
    && curl -fsSLo "/tmp/dropbear.tar.bz2" "https://matt.ucc.asn.au/dropbear/releases/dropbear-${DROPBEAR_VERSION}.tar.bz2" \
    && mkdir -p /tmp/dropbear-src \
    && tar -xjf "/tmp/dropbear.tar.bz2" -C /tmp/dropbear-src --strip-components=1 \
    && cd /tmp/dropbear-src \
    && ./configure --prefix=/usr/local \
    && make -j"$(nproc)" MULTI=1 \
    && make MULTI=1 install \
    && rm -rf /tmp/dropbear.tar.bz2 /tmp/dropbear-src \
    && apt-get purge -y build-essential bzip2 zlib1g-dev \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv "${HPC_DEV_VENV}" \
    && "${HPC_DEV_VENV}/bin/pip" install --no-cache-dir --upgrade pip \
    && "${HPC_DEV_VENV}/bin/pip" install --no-cache-dir jupyterlab
RUN curl -fsSL "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz" \
    | tar -xz -C /usr/local/lib \
    && mv "/usr/local/lib/code-server-${CODE_SERVER_VERSION}-linux-amd64" /usr/local/lib/code-server \
    && ln -sf /usr/local/lib/code-server/bin/code-server /usr/local/bin/code-server

RUN mkdir -p /var/run/sshd

# This is the owned-image baseline for the hpc-dev workflow.
# Extend it further with any site-specific certificates, mirrors, or extra tools.

COPY container/helpers/hpc-service-lib.sh /usr/local/bin/hpc-service-lib.sh
COPY container/helpers/hpc-service-sshd.sh /usr/local/bin/hpc-service-sshd.sh
COPY container/helpers/hpc-service-jupyter.sh /usr/local/bin/hpc-service-jupyter.sh
COPY container/helpers/hpc-service-rstudio.sh /usr/local/bin/hpc-service-rstudio.sh
COPY container/helpers/hpc-service-codeserver.sh /usr/local/bin/hpc-service-codeserver.sh

RUN chmod +x \
    /usr/local/bin/hpc-service-lib.sh \
    /usr/local/bin/hpc-service-sshd.sh \
    /usr/local/bin/hpc-service-jupyter.sh \
    /usr/local/bin/hpc-service-rstudio.sh \
    /usr/local/bin/hpc-service-codeserver.sh
