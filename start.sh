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

start_xray() {
    /usr/bin/xray -config /etc/xray/config.json &
    XRAY_PID=$!
    echo "Xray started with PID $XRAY_PID"
}

start_sni() {
    /usr/local/bin/sni-spoof-rs /etc/xray/pconfig.json &
    SNI_PID=$!
    echo "SNI started with PID $SNI_PID"
}

restart_xray() {
    echo "Validating Xray configuration..."

    if ! /usr/bin/xray -test -config /etc/xray/config.json; then
        echo "Invalid Xray config; keeping current process."
        return 1
    fi

    echo "Restarting Xray..."
    kill -TERM "$XRAY_PID" 2>/dev/null || true
    wait "$XRAY_PID" 2>/dev/null || true

    start_xray
}

restart_sni() {
    echo "Validating SNI configuration..."

    if ! jq -e 'type == "object" and (.listeners | type == "array")' \
        /etc/xray/pconfig.json >/dev/null; then
        echo "Invalid SNI JSON structure; keeping current process."
        return 1
    fi

    echo "Restarting SNI..."
    kill -TERM "$SNI_PID" 2>/dev/null || true
    wait "$SNI_PID" 2>/dev/null || true

    start_sni
}

echo "Starting SNI..."
jq -e 'type == "object" and (.listeners | type == "array")' \
    /etc/xray/pconfig.json >/dev/null
start_sni

echo "Starting Xray..."
start_xray

echo "Starting Nginx..."
nginx -g "daemon off;" &
NGINX_PID=$!

cleanup() {
    kill "$XRAY_PID" "$SNI_PID" "$NGINX_PID" 2>/dev/null || true
    wait "$XRAY_PID" "$SNI_PID" "$NGINX_PID" 2>/dev/null || true
}

trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'restart_xray || true' USR1
trap 'restart_sni || true' USR2

while kill -0 "$XRAY_PID" 2>/dev/null &&
      kill -0 "$SNI_PID" 2>/dev/null &&
      kill -0 "$NGINX_PID" 2>/dev/null; do
    sleep 2 || true
done

echo "A service exited; stopping the container."
exit 1
