# Use a slim Debian Bookworm image as the base.
FROM debian:bookworm-slim

###############################################################################
# Build-time Arguments
###############################################################################
ARG BUILD_DATE
ARG CODE_RELEASE
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEFAULT_WORKSPACE=/workspace
ARG SERVER_PORT=8080
ARG USER_NAME=coder
ARG USER_SHELL=/bin/bash

# New optional arguments for testing tools.
ARG INSTALL_NODE=false
ARG NODE_MAJOR_VERSION=22
ARG INSTALL_CST=false
ARG CST_VERSION=latest
ARG INSTALL_HADOLINT=false
ARG HADOLINT_VERSION=v2.12.0
ARG INSTALL_RUST=false
ARG RUST_VERSION=1.84.1
ARG INSTALL_FLYCTL=false

###############################################################################
# Environment Variables
###############################################################################
# Set environment variables from build-time args.
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND} \
    VERSION="v${CODE_RELEASE:-latest}" \
    DEFAULT_WORKSPACE=${DEFAULT_WORKSPACE} \
    SERVER_PORT=${SERVER_PORT} \
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
# Feature Installation
###############################################################################

COPY features /tmp/features
# Use `:` to reference ARG variables to ensure Docker exports them
RUN apt-get update && \
  : \
    "${INSTALL_NODE?}" \
    "${NODE_MAJOR_VERSION?}" \
    "${INSTALL_CST?}" \
    "${CST_VERSION?}" \
    "${INSTALL_HADOLINT?}" \
    "${HADOLINT_VERSION?}" \
    "${INSTALL_RUST?}" \
    "${RUST_VERSION?}" \
    "${RUST_PACKAGES?}" \
    "${INSTALL_FLYCTL?}" && \
  if compgen -G "/tmp/features/*.sh" > /dev/null; then \
    for FILEPATH in /tmp/features/*.sh; do \
      FILENAME=$(basename "$FILEPATH"); \
      PART_NAME=$(echo "$FILENAME" | sed -E 's/^[0-9]+_//;s/\.sh$//' | tr '[:lower:]' '[:upper:]'); \
      ENABLED_VAR="INSTALL_${PART_NAME}"; \
      if [[ "${!ENABLED_VAR:-}" != "true" ]]; then \
        echo "Skipping $FILENAME -> $PART_NAME (not enabled)"; \
      else \
        echo "Running ${PART_NAME} install ${FILENAME}"; \
        bash "$FILEPATH"; \
      fi; \
    done; \
  else \
    echo "No feature scripts found in /tmp/features"; \
  fi && \
  rm -rf /var/lib/apt/lists/* /tmp/*

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
