#!/bin/sh
set -eu

OVR=/etc/pdns/conf.d/10-env.conf
install -d /etc/pdns/conf.d
: > "$OVR"  # truncate

# Web & API (from env)
if [ "${PDNS_WS:-yes}" = "yes" ]; then
  {
    echo "webserver=yes"
    echo "webserver-address=${PDNS_WS_ADDR:-0.0.0.0}"
    echo "webserver-port=${PDNS_WS_PORT:-8081}"
    [ -n "${PDNS_WS_ALLOW_FROM:-}" ] && echo "webserver-allow-from=${PDNS_WS_ALLOW_FROM}"
  } >> "$OVR"
fi

if [ "${PDNS_API:-yes}" = "yes" ]; then
  echo "api=yes" >> "$OVR"
  # support *_FILE for secrets
  if [ -n "${PDNS_API_KEY_FILE:-}" ] && [ -r "${PDNS_API_KEY_FILE}" ]; then
    PDNS_API_KEY="$(cat "${PDNS_API_KEY_FILE}")"
  fi
  [ -n "${PDNS_API_KEY:-}" ] && echo "api-key=${PDNS_API_KEY}" >> "$OVR"
fi

# MySQL backend from env (turn on with MYSQL_AUTOCONF=1|true)
if [ "${MYSQL_AUTOCONF:-true}" = "true" ] || [ "${MYSQL_AUTOCONF:-0}" = "1" ]; then
  # support *_FILE for DB password too
  if [ -n "${MYSQL_PASS_FILE:-}" ] && [ -r "${MYSQL_PASS_FILE}" ]; then
    MYSQL_PASS="$(cat "${MYSQL_PASS_FILE}")"
  fi
  {
    echo "launch=gmysql"
    echo "gmysql-host=${MYSQL_HOST:-ipam-db}"
    echo "gmysql-port=${MYSQL_PORT:-3306}"
    echo "gmysql-dbname=${MYSQL_DB:-powerdns}"
    echo "gmysql-user=${MYSQL_USER:-powerdns}"
    echo "gmysql-password=${MYSQL_PASS:-superdbpass}"
    echo "gmysql-dnssec=${MYSQL_DNSSEC:-no}"
  } >> "$OVR"
fi

exec /usr/sbin/pdns_server "$@"
