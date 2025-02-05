# Use a slim Debian Bookworm image as the base.
FROM debian:bookworm-slim

###############################################################################
# Build-time Arguments
###############################################################################
ARG INSTALL_NODE_FROM_NODESOURCE=false
ARG NODE_MAJOR=22
ARG BUILD_DATE
ARG CODE_RELEASE
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEFAULT_WORKSPACE=/workspace
ARG SERVER_PORT=8080
ARG USER_NAME=coder
ARG USER_SHELL=/bin/bash

# New optional arguments for testing tools.
ARG INSTALL_CONTAINER_STRUCTURE_TEST=false
ARG CONTAINER_STRUCTURE_TEST_VERSION=latest
ARG INSTALL_HADOLINT=false
ARG HADOLINT_VERSION=v2.12.0

###############################################################################
# Environment Variables
###############################################################################
# Set environment variables from build-time args.
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND} \
    VERSION="v${CODE_RELEASE:-latest}" \
    DEFAULT_WORKSPACE=${DEFAULT_WORKSPACE} \
    SERVER_PORT=${SERVER_PORT} \
    SSH_DIR=${DEFAULT_WORKSPACE}/.ssh \
    NODE_MAJOR=${NODE_MAJOR} \
    INSTALL_NODE_FROM_NODESOURCE=${INSTALL_NODE_FROM_NODESOURCE} \
    USER_NAME=${USER_NAME} \
    USER_SHELL=${USER_SHELL}

# Labels for build metadata.
LABEL build_version="blineCodeServer version: ${VERSION} Build-date: ${BUILD_DATE}" \
      maintainer="sbeck"

###############################################################################
# System Dependencies
###############################################################################
# Install sudo and prerequisites.
RUN apt-get update && \
    apt-get install -y sudo curl ca-certificates gnupg && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###############################################################################
# Create Non-root User
###############################################################################
RUN useradd -m -d "$DEFAULT_WORKSPACE" --shell ${USER_SHELL} ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME} && \
    chmod 0440 /etc/sudoers.d/${USER_NAME}

###############################################################################
# Node.js Installation
###############################################################################
RUN apt-get update && \
    if [ "$INSTALL_NODE_FROM_NODESOURCE" = "true" ]; then \
      echo "Installing Node.js from NodeSource (Node.js ${NODE_MAJOR})." && \
      curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -; \
    else \
      echo "Installing Node.js from Debian's default repository (Node.js 18)."; \
    fi && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###############################################################################
# Install code-server
###############################################################################
RUN echo "**** Installing runtime dependencies ****" && \
    apt-get update && \
    apt-get install -y git libatomic1 && \
    echo "**** Installing code-server ****" && \
    if [ -z "${CODE_RELEASE+x}" ]; then \
      CODE_RELEASE=$(curl -sX GET https://api.github.com/repos/coder/code-server/releases/latest \
        | awk '/tag_name/{print $4;exit}' FS='[\"\"]' | sed 's|^v||'); \
    fi && \
    mkdir -p /app/code-server && \
    curl -o /tmp/code-server.tar.gz -L \
      "https://github.com/coder/code-server/releases/download/v${CODE_RELEASE}/code-server-${CODE_RELEASE}-linux-amd64.tar.gz" && \
    tar xf /tmp/code-server.tar.gz -C /app/code-server --strip-components=1 && \
    printf "blineCodeServer version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version

###############################################################################
# Install flyctl
###############################################################################
RUN echo "**** Installing flyctl ****" && \
    curl -L https://fly.io/install.sh | sh

###############################################################################
# Optionally Install Container-Structure-Test and Hadolint
###############################################################################
RUN if [ "$INSTALL_CONTAINER_STRUCTURE_TEST" = "true" ]; then \
      echo "**** Installing container-structure-test ****" && \
      curl -Lo /usr/local/bin/container-structure-test https://storage.googleapis.com/container-structure-test/${CONTAINER_STRUCTURE_TEST_VERSION}/container-structure-test && \
      chmod +x /usr/local/bin/container-structure-test; \
    else \
      echo "Skipping container-structure-test installation."; \
    fi && \
    if [ "$INSTALL_HADOLINT" = "true" ]; then \
      echo "**** Installing hadolint ****" && \
      curl -L https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VERSION}/hadolint-Linux-x86_64 -o /usr/local/bin/hadolint && \
      chmod +x /usr/local/bin/hadolint; \
    else \
      echo "Skipping hadolint installation."; \
    fi

###############################################################################
# Extra Packages Installation
###############################################################################
COPY packages.list /config/packages.list
RUN echo "**** Installing extra packages ****" && \
    apt-get update && \
    xargs -a /config/packages.list apt-get install -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###############################################################################
# Entrypoint & Configuration Files
###############################################################################
COPY entrypoint.lib.sh /usr/local/bin/entrypoint.lib.sh
COPY functions.lib.sh /usr/local/bin/functions.lib.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN rm -rf /config/*
COPY bashrc /tmp/.bashrc
COPY fly.toml /config/fly.toml
COPY packages.list /config/packages.list
COPY extra_env.list /config/extra_env.list

###############################################################################
# Prepare Workspace
###############################################################################
RUN mkdir -p "${DEFAULT_WORKSPACE}" && \
    cp /tmp/.bashrc "${DEFAULT_WORKSPACE}/.bashrc" && \
    chown -R ${USER_NAME}:${USER_NAME} "${DEFAULT_WORKSPACE}"

###############################################################################
# Expose Port and Set Entrypoint
###############################################################################
EXPOSE ${SERVER_PORT}
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
