# syntax=docker/dockerfile:1

FROM ghcr.io/imagegenius/baseimage-ubuntu:jammy

# set version label
ARG BUILD_DATE
ARG VERSION
ARG IMMICH_VERSION
LABEL build_version="ImageGenius Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="hydazz, martabal"

# environment settings
ENV DEBIAN_FRONTEND="noninteractive" \
  IMMICH_WEB_URL=http://127.0.0.1:3000 \
  MMICH_SERVER_URL=http://127.0.0.1:3001 \
  IMMICH_MACHINE_LEARNING_URL=http://127.0.0.1:3003 \
  PUBLIC_IMMICH_SERVER_URL=http://127.0.0.1:3001

RUN \
  echo "**** install runtime packages ****" && \
  echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_16.x jammy main" >>/etc/apt/sources.list && \
  curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | gpg --dearmor | tee /usr/share/keyrings/nodesource.gpg && \
  apt-get update && \
  apt-get install --no-install-recommends -y \
    ffmpeg \
    g++ \
    libheif1 \
    libvips \
    perl \
    libvips-dev \
    make \
    nginx \
    nodejs && \
  echo "**** download immich ****" && \
  mkdir -p \
    /tmp/immich && \
  if [ -z ${IMMICH_VERSION} ]; then \
    IMMICH_VERSION=$(curl -sL https://api.github.com/repos/immich-app/immich/releases/latest | \
      jq -r '.tag_name'); \
  fi && \
  curl -o \
    /tmp/immich.tar.gz -L \
    "https://github.com/immich-app/immich/archive/${IMMICH_VERSION}.tar.gz" && \
  tar xf \
    /tmp/immich.tar.gz -C \
    /tmp/immich --strip-components=1 && \
  echo "**** build server ****" && \
  cd /tmp/immich/server && \
  npm ci && \
  npm run build && \
  npm prune --omit=dev --omit=optional && \
  npm link && \
  npm cache clean --force && \
  mkdir -p \
    /app/immich/server && \
  cp -a \
    package.json \
    package-lock.json \
    node_modules \
    dist \
    /app/immich/server && \
  echo "**** build web ****" && \
  cd /tmp/immich/web && \
  npm ci && \
  npm run build && \
  npm prune --omit=dev && \
  mkdir -p \
    /app/immich/web && \
  cp -a \
    package.json \
    package-lock.json \
    node_modules \
    build \
    static \
    /app/immich/web && \
  echo "**** build machine-learning ****" && \
  cd /tmp/immich/machine-learning && \
  npm ci && \
  npm rebuild @tensorflow/tfjs-node --build-from-source && \
  npm run build && \
  npm prune --omit=dev && \
  mkdir -p \
    /app/immich/machine-learning && \
  cp -a \
    package.json \
    package-lock.json \
    node_modules \
    dist \
    /app/immich/machine-learning/ && \
  echo "**** setup upload folder ****" && \
  mkdir -p \
    /photos && \
  ln -s \
    /photos \
    /app/immich/server/upload && \
  ln -s \
    /photos \
    /app/immich/machine-learning/upload && \
  echo "**** cleanup ****" && \
  apt-get remove -y --purge \
    libvips-dev \
    make \
    g++ && \
  apt-get autoremove -y --purge && \
  apt-get clean && \
  rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /root/.cache \
    /root/.npm

# environment settings
ENV NODE_ENV="production"

# copy local files
COPY root/ /

# ports and volumes
EXPOSE 8080
VOLUME /config /uploads
