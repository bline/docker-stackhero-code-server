FROM debian:bookworm-slim

# Optional: Upgrade Node.js if desired
# Build-time argument to control installation source for Node.js
ARG INSTALL_NODE_FROM_NODESOURCE=false
ARG NODE_MAJOR=22

ARG BUILD_DATE
ARG CODE_RELEASE
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEFAULT_WORKSPACE=/workspace
ARG SERVER_PORT=8080

# Set environment variables
ENV DEBIAN_FRONTEND=${DEBIAN_FRONTEND}
ENV VERSION="v${CODE_RELEASE:-latest}"
ENV DEFAULT_WORKSPACE=$DEFAULT_WORKSPACE
ENV SERVER_PORT=$SERVER_PORT
ENV SSH_DIR=${DEFAULT_WORKSPACE}/.ssh
ENV NODE_MAJOR=$NODE_MAJOR
ENV INSTALL_NODE_FROM_NODESOURCE=$INSTALL_NODE_FROM_NODESOURCE

LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="sbeck"

# Conditionally install Node.js from NodeSource if INSTALL_NODE_FROM_NODESOURCE is true.
RUN if [ "$INSTALL_NODE_FROM_NODESOURCE" = "true" ]; then \
      apt-get update && \
      apt-get install -y curl ca-certificates gnupg && \
      curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - && \
      apt-get install -y nodejs && \
      rm -rf /var/lib/apt/lists/*; \
    else \
      echo "Installing Node.js from Debian's default repository (Node.js 18)"; \
      apt-get update && \
      apt-get install -y nodejs && \
      rm -rf /var/lib/apt/lists/*; \
    fi

# Install code-server
RUN \
  echo "**** install runtime dependencies ****" && \
  apt-get update && \
  apt-get install -y \
    git \
    curl \
    ca-certificates \
    libatomic1 && \
  echo "**** install code-server ****" && \
  if [ -z ${CODE_RELEASE+x} ]; then \
    CODE_RELEASE=$(curl -sX GET https://api.github.com/repos/coder/code-server/releases/latest \
      | awk '/tag_name/{print $4;exit}' FS='[""]' | sed 's|^v||'); \
  fi && \
  mkdir -p /app/code-server && \
  curl -o \
    /tmp/code-server.tar.gz -L \
    "https://github.com/coder/code-server/releases/download/v${CODE_RELEASE}/code-server-${CODE_RELEASE}-linux-amd64.tar.gz" && \
  tar xf /tmp/code-server.tar.gz -C \
    /app/code-server --strip-components=1 && \
  printf "blineCodeServer version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** clean up ****" && \
  apt-get clean && \
  rm -rf \
    /config/* \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

RUN echo "**** install flyctl ****" && \
  curl -L https://fly.io/install.sh | sh


# Copy package list
COPY packages.list /tmp/packages.list

# Install packages from the list
RUN echo "**** install extra packages ****" && \
    apt-get update && \
    xargs -a /tmp/packages.list apt-get install -y --no-install-recommends && \
    rm -f /tmp/packages.list && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy the entrypoint script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# Copy the bashrc file to /tmp
COPY bashrc /tmp/.bashrc

# Copy the fly.toml for reference in bashrc
COPY fly.toml /fly.toml

# Move .bashrc to the default workspace at runtime
RUN mkdir -p "${DEFAULT_WORKSPACE}" && \
    cp /tmp/.bashrc "${DEFAULT_WORKSPACE}/.bashrc"

# Expose the default port
EXPOSE $SERVER_PORT

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
