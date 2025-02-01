FROM ghcr.io/linuxserver/baseimage-ubuntu:noble

# Set version label
ARG BUILD_DATE
ARG CODE_RELEASE
ARG DEBIAN_FRONTEND="noninteractive"
ARG DEFAULT_WORKSPACE=/workspace
ARG SERVER_PORT=8080
ARG GIT_USER
ARG GIT_EMAIL


# Set environment variables
ENV VERSION="v${CODE_RELEASE:-latest}"
ENV DEFAULT_WORKSPACE=$DEFAULT_WORKSPACE
ENV SERVER_PORT=$SERVER_PORT
ENV SSH_DIR=${DEFAULT_WORKSPACE}/.ssh
ENV GIT_USER=$GIT_USER
ENV GIT_EMAIL=$GIT_EMAIL

LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="sbeck"



# Install code-server
RUN \
  echo "**** install runtime dependencies ****" && \
  apt-get update && \
  apt-get install -y \
    git \
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
  printf "Linuxserver.io version: ${VERSION}\nBuild-date: ${BUILD_DATE}" > /build_version && \
  echo "**** clean up ****" && \
  apt-get clean && \
  rm -rf \
    /config/* \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

# Copy package list
COPY packages.list /tmp/packages.list

# Install packages from the list
RUN echo "**** install extra packages ****" && \
    apt-get update && \
    xargs -a /tmp/packages.list apt-get install -y --no-install-recommends && \
    rm -f /tmp/packages.list && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Check if GIT_USER and GIT_EMAIL are set
RUN if [ -z "${GIT_USER}" ] || [ -z "${GIT_EMAIL}" ]; then \
      echo "WARN: GIT_USER and GIT_EMAIL should be set as arguments (build.args) to configure git." >&2; \
    else \
      echo "Configuring Git with user: ${GIT_USER}, email: ${GIT_EMAIL}"; \
      git config --global user.name "${GIT_USER}" && \
      git config --global user.email "${GIT_EMAIL}"; \
    fi

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
