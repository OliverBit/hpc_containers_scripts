FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HPC_DEV_VENV=/opt/hpc-dev/venv
ENV CODE_SERVER_VERSION=4.112.0
ENV RSTUDIO_SERVER_VERSION=2026.01.1-403
ENV PATH="${HPC_DEV_VENV}/bin:${PATH}"

RUN apt-get update && apt-get install -y \
    bash \
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
    && curl -fsSLo "/tmp/rstudio-server.deb" "https://download2.rstudio.org/server/jammy/amd64/rstudio-server-${RSTUDIO_SERVER_VERSION}-amd64.deb" \
    && gdebi -n "/tmp/rstudio-server.deb" \
    && rm -f "/tmp/rstudio-server.deb" \
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
