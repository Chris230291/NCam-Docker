
FROM lscr.io/linuxserver/oscam:latest

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
  build-base \
  libdvbcsa-dev \
  libusb-dev \
  linux-headers \
  openssl-dev \
  pcsc-lite-dev \
  curl-dev \
  git

RUN \
  echo "**** compile ncam ****" && \
  mkdir -p /tmp/ncam && \
  git clone https://github.com/fairbird/NCam.git /tmp/ncam && \
  cd /tmp/ncam && \
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
  pcsc-libusb

RUN \
  echo "**** replace oscam with ncam ****" && \
  mv /defaults/oscam.conf /defaults/ncam.conf && \
  sed -i '/^#/d' /defaults/ncam.conf && \
  find /etc/s6-overlay/s6-rc.d -type f -exec sed -i 's/oscam/ncam/g' {} + && \
  find /etc/s6-overlay/s6-rc.d -depth -name "*oscam*" -exec sh -c 'mv "$1" "$(dirname "$1")/$(basename "$1" | sed "s/oscam/ncam/")"' _ {} \; && \
  rm /usr/bin/oscam

RUN \
  echo "**** cleanup ****" && \
  apk del --purge \
  build-dependencies && \
  rm -rf \
  /tmp/*