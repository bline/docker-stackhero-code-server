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
    USER_NAME=${USER_NAME}

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
# Create a non-root user (configurable via USER_NAME) with home directory
# set to DEFAULT_WORKSPACE, and grant passwordless sudo.
RUN useradd -m -d "$DEFAULT_WORKSPACE" ${USER_NAME} && \
    echo "${USER_NAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${USER_NAME} && \
    chmod 0440 /etc/sudoers.d/${USER_NAME}

###############################################################################
# Node.js Installation
###############################################################################
# Conditionally install Node.js from NodeSource if requested.
RUN apt-get update && \
    if [ "$INSTALL_NODE_FROM_NODESOURCE" = "true" ]; then \
      echo "Installing Node.js from NodeSource (Node.js ${NODE_MAJOR})." && \
      curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash -; \
    else \
      echo "Installing Node.js from Debian's default repository (Node.js 18)." ; \
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
        | awk '/tag_name/{print $4;exit}' FS='[""]' | sed 's|^v||'); \
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
# Extra Packages Installation
###############################################################################
# Copy the package list and install extra packages.
COPY packages.list /config/packages.list
RUN echo "**** Installing extra packages ****" && \
    apt-get update && \
    xargs -a /config/packages.list apt-get install -y --no-install-recommends && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

###############################################################################
# Entrypoint & Configuration Files
###############################################################################
# Copy and set executable permissions on the entrypoint script.
COPY entrypoint.lib.sh /usr/local/bin/entrypoint.lib.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Clean the /config directory and copy fresh configuration files.
RUN rm -rf /config/*
COPY bashrc /tmp/.bashrc
COPY fly.toml /config/fly.toml
COPY packages.list /config/packages.list
COPY extra_env.list /config/extra_env.list

###############################################################################
# Prepare Workspace
###############################################################################
# Copy the bashrc into the workspace and ensure correct ownership.
RUN mkdir -p "${DEFAULT_WORKSPACE}" && \
    cp /tmp/.bashrc "${DEFAULT_WORKSPACE}/.bashrc" && \
    chown -R ${USER_NAME}:${USER_NAME} "${DEFAULT_WORKSPACE}"

###############################################################################
# Expose Port and Set Entrypoint
###############################################################################
EXPOSE ${SERVER_PORT}
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
