# ---- Builder ----
FROM alpine:3.20 AS builder
ARG POWERDNS_VERSION=5.0.0

RUN apk add --no-cache \
      build-base git autoconf automake libtool pkgconfig \
      openssl-dev boost-dev \
      mariadb-connector-c-dev \
      luajit-dev jansson-dev \
      curl bzip2 xz

RUN curl -fsSL "https://downloads.powerdns.com/releases/pdns-${POWERDNS_VERSION}.tar.bz2" \
     | tar xj -C /tmp \
 && cd /tmp/pdns-${POWERDNS_VERSION} \
 && ./configure \
      --prefix="" \
      --exec-prefix=/usr \
      --sysconfdir=/etc/pdns \
      --with-modules="bind gmysql" \
      --disable-lua-records \
 && make -j"$(nproc)" \
 && make install-strip \
 && mkdir -p /usr/lib/pdns

# ---- Runtime (lean) ----
FROM alpine:3.20

# Only the libs PDNS needs at runtime (no bash, no mariadb-client, no curl CLI)
RUN apk add --no-cache \
      ca-certificates \
      libstdc++ libgcc boost-libs \
      mariadb-connector-c \
      luajit jansson \
      libssl3 libcrypto3

# Non-root user
RUN addgroup -S pdns && adduser -S -D -H -h /var/empty -s /sbin/nologin -G pdns pdns

# Binaries & modules
COPY --from=builder /usr/sbin/pdns_server  /usr/sbin/pdns_server
COPY --from=builder /usr/lib/pdns          /usr/lib/pdns

# Config
WORKDIR /etc/pdns
COPY pdns.conf   /etc/pdns/pdns.conf
RUN  install -d /etc/pdns/conf.d
# (schema comes from DB container now)

# Minimal entrypoint that just execs PDNS; no DB wait/seed here
COPY --chown=pdns:pdns <<'SH' /entrypoint.sh
#!/bin/sh
set -eu
# enable webserver/API from env if provided (optional)
[ "${PDNS_WS:-yes}" = "yes" ] && {
  printf '%s\n' "webserver=yes" \
                 "webserver-address=${PDNS_WS_ADDR:-0.0.0.0}" \
                 "webserver-port=${PDNS_WS_PORT:-8081}" \
                 "webserver-print-arguments=no" >> /etc/pdns/pdns.conf
  [ -n "${PDNS_WS_ALLOW_FROM:-}" ] && echo "webserver-allow-from=${PDNS_WS_ALLOW_FROM}" >> /etc/pdns/pdns.conf
}
[ "${PDNS_API:-yes}" = "yes" ] && {
  echo "api=yes" >> /etc/pdns/pdns.conf
  [ -n "${PDNS_API_KEY:-}" ] && echo "api-key=${PDNS_API_KEY}" >> /etc/pdns/pdns.conf
}
# exec
exec /usr/sbin/pdns_server "$@"
SH
RUN chmod +x /entrypoint.sh

EXPOSE 53/tcp 53/udp 8081/tcp

HEALTHCHECK --interval=30s --timeout=3s --retries=5 CMD \
  wget -qO- --header="X-API-Key: ${PDNS_API_KEY:-change-me-long-random}" \
  http://127.0.0.1:8081/api/v1/servers/localhost >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--daemon=no","--disable-syslog=yes","--write-pid=no","--loglevel=4"]
