# FROM alpine:3.23 AS builder
FROM golang:1.26.2-alpine3.23 AS builder

ARG BRIDGE_VERSION=3.22.0
ENV BRIDGE_VERSION=$BRIDGE_VERSION

RUN \
  apk --no-cache add --update \
  go \
  git \
  make \
  bash \
  pkgconf \
  libcbor-dev \
  libfido2-dev \
  libsecret-dev && \
  mkdir /bridge && cd /bridge && \
  git clone https://github.com/ProtonMail/proton-bridge.git && \
  cd proton-bridge && \
  git checkout v$BRIDGE_VERSION && \
  make build-nogui

FROM alpine:3.23

COPY resources/gpgparams resources/entrypoint.sh /protonmail/
COPY --from=builder /bridge/proton-bridge/bridge /usr/bin/
COPY --from=builder /bridge/proton-bridge/proton-bridge /usr/bin/

RUN \
  apk --no-cache add --update \
  pass \
  gnupg \
  socat \
  libfido2 \
  libsecret && \
  adduser -s /bin/sh -D -u 99 protonmail && \
  mkdir -p /home/protonmail && chown -R protonmail: /home/protonmail

RUN \
  sed -i 's#^root:[^:]*:#root:!*:#' /etc/shadow && \
  sed -i 's#^\(root:[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\).*#\1/sbin/nologin#' /etc/passwd && \
  rm -f /bin/su /usr/bin/su /usr/bin/sudo /sbin/sudo 2>/dev/null || true

USER protonmail
ENV HOME=/data
ENV IMAP_PORT=143
ENV SMTP_PORT=587

VOLUME /data

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=60s \
  CMD sh -c 'nc -z 127.0.0.1 "${IMAP_PORT}" && nc -z 127.0.0.1 1143 || exit 1'

ENTRYPOINT ["sh", "/protonmail/entrypoint.sh"]
