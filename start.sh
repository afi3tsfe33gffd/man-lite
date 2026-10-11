#!/bin/sh
set -eu

export NGINX_PORT="${NGINX_PORT:-3000}"

echo "Generating nginx configuration..."
envsubst '${NGINX_PORT}' \
  < /etc/nginx/nginx.conf.template \
  > /etc/nginx/nginx.conf

echo "Testing Xray configuration..."
/usr/bin/xray -test -config /etc/xray/config.json

echo "Testing Nginx configuration..."
nginx -t

echo "Starting Xray..."
/usr/bin/xray -config /etc/xray/config.json &
XRAY_PID=$!

echo "Starting Nginx..."
nginx -g "daemon off;" &
NGINX_PID=$!

cleanup() {
    kill "$XRAY_PID" "$NGINX_PID" 2>/dev/null || true
    wait "$XRAY_PID" "$NGINX_PID" 2>/dev/null || true
}

trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT

while kill -0 "$XRAY_PID" 2>/dev/null &&
      kill -0 "$NGINX_PID" 2>/dev/null; do
    sleep 2
done

echo "A service exited; stopping the container."
exit 1
