FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HPC_DEV_VENV=/opt/hpc-dev/venv
ENV PATH="${HPC_DEV_VENV}/bin:${PATH}"

RUN apt-get update && apt-get install -y \
    bash \
    ca-certificates \
    curl \
    git \
    iproute2 \
    less \
    netcat-openbsd \
    nodejs \
    npm \
    openssl \
    openssh-server \
    procps \
    python3 \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv "${HPC_DEV_VENV}" \
    && "${HPC_DEV_VENV}/bin/pip" install --no-cache-dir --upgrade pip \
    && "${HPC_DEV_VENV}/bin/pip" install --no-cache-dir jupyterlab
RUN npm install --global code-server

RUN mkdir -p /var/run/sshd

# This is a starter scaffold for the owned-image path.
# Extend it with your site-specific R and RStudio Server installation steps.

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
