FROM ghcr.io/linuxserver/baseimage-alpine:3.16 as amd64-platform
FROM ghcr.io/linuxserver/baseimage-alpine:arm64v8-3.16 as arm64-platform
FROM ghcr.io/linuxserver/baseimage-alpine:arm32v7-3.16-version-4a1e3db5 as armv7-platform

FROM ${TARGETARCH}${TARGETVARIANT}-platform as platform
############## build platform ##############

# set version label
ARG BUILD_DATE
ARG VERSION
ARG NCAM_COMMIT
LABEL build_version="version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="chris230291"

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    gcc \
    g++ \
    libusb-dev \
    linux-headers \
    make \
    openssl-dev \
    curl-dev \
    pcsc-lite-dev \
    git \
    tar && \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    ccid \
    curl \
    libcrypto1.1 \
    libssl1.1 \
    libusb \
    pcsc-lite \
    pcsc-lite-libs && \
  echo "**** compile ncam ****" && \
  if [ -z ${NCAM_COMMIT+x} ]; then \
    NCAM_COMMIT=$(curl -sX GET https://api.github.com/repos/fairbird/NCam/commits/master \
    | jq -r '. | .sha'); \
  fi && \
  mkdir -p \
    /tmp/ncam && \
  git clone https://github.com/fairbird/NCam.git /tmp/ncam && \
  cd /tmp/ncam && \
  git checkout ${NCAM_COMMIT} && \
  ./config.sh \
    --enable all \
    --disable \
    CARDREADER_DB2COM \
    CARDREADER_INTERNAL \
    CARDREADER_STINGER \
    CARDREADER_STAPI \
    CARDREADER_STAPI5 \
    IPV6SUPPORT \
    LCDSUPPORT \
    LEDSUPPORT \
    WITH_NEUTRINO \
    WITH_SOFTCAM \
    WITH_CARDLIST && \
  make \
    CONF_DIR=/config \
    DEFAULT_PCSC_FLAGS="-I/usr/include/PCSC" \
    NO_PLUS_TARGET=1 \
    NCAM_BIN=/usr/bin/ncam \
    USE_LIBCURL=1 \
    pcsc-libusb && \
  echo "**** fix broken permissions from pcscd install ****" && \
  chown root:root \
    /usr/sbin/pcscd && \
  chmod 755 \
    /usr/sbin/pcscd && \
  echo "**** install PCSC drivers ****" && \
  mkdir -p \
    /tmp/omnikey && \
  curl -o \
    /tmp/omnikey.tar.gz -L \
    "https://ci-tests.linuxserver.io/artifacts/ifdokccid_linux_x86_64-v4.2.8.tar.gz" && \
  tar xzf \
    /tmp/omnikey.tar.gz -C \
    /tmp/omnikey --strip-components=2 && \
  cd /tmp/omnikey && \
  ./install && \
  echo "**** fix group for card readers and add abc to dialout group ****" && \
  groupmod -g 24 cron && \
  groupmod -g 16 dialout && \
  usermod -a -G 16 abc && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/* /usr/bin/ncam.debug

# copy local files
COPY root/ /

RUN \
  echo "**** permissions to run ****" && \
  chmod 755 \
    /etc/s6-overlay/s6-rc.d/svc-pcsd/run \
    /etc/s6-overlay/s6-rc.d/svc-ncam/run \
    /etc/s6-overlay/s6-rc.d/init-ncam-config/run

# Ports and volumes
EXPOSE 8181

VOLUME /config
