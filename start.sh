#!/bin/sh
set -eu

export NGINX_PORT="${NGINX_PORT:-3000}"

AETHER_BIN="/usr/local/bin/aether"
AETHER_BIND="127.0.0.1:1820"

XRAY_PID=""
SNI_PID=""
AETHER_PID=""
NGINX_PID=""

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

start_aether() {
    echo "Starting Aether with Psiphon-only mode..."
    "$AETHER_BIN" --psiphon-only --bind "$AETHER_BIND" &
    AETHER_PID=$!
    echo "Aether started with PID $AETHER_PID"
}

# Find Aether's direct Psiphon child using BusyBox ps.
find_psiphon_child() {
    ps -o pid,ppid,args 2>/dev/null |
        awk -v parent="$AETHER_PID" \
        '$2 == parent && /psiphon-tunnel-core/ {print $1; exit}'
}

stop_aether() {
    [ -n "${AETHER_PID:-}" ] || return 0

    echo "Stopping Aether and its Psiphon child..."

    PSIPHON_PID="$(find_psiphon_child || true)"

    # Stop the Psiphon child first.
    if [ -n "$PSIPHON_PID" ]; then
        kill -TERM "$PSIPHON_PID" 2>/dev/null || true
    fi

    # Then stop Aether.
    kill -TERM "$AETHER_PID" 2>/dev/null || true
    wait "$AETHER_PID" 2>/dev/null || true

    # Give the child time to exit.
    if [ -n "$PSIPHON_PID" ]; then
        COUNT=0
        while kill -0 "$PSIPHON_PID" 2>/dev/null &&
              [ "$COUNT" -lt 5 ]; do
            sleep 1
            COUNT=$((COUNT + 1))
        done

        # Force-stop the child if it did not exit.
        if kill -0 "$PSIPHON_PID" 2>/dev/null; then
            kill -KILL "$PSIPHON_PID" 2>/dev/null || true
        fi
    fi

    AETHER_PID=""
    echo "Aether stopped."
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

restart_aether() {
    echo "Manual Aether restart requested..."
    stop_aether
    sleep 1
    start_aether
}

echo "Starting SNI..."
jq -e 'type == "object" and (.listeners | type == "array")' \
    /etc/xray/pconfig.json >/dev/null
start_sni

echo "Starting Xray..."
start_xray

echo "Starting Aether..."
start_aether

echo "Starting Nginx..."
nginx -g "daemon off;" &
NGINX_PID=$!

cleanup() {
    trap - EXIT TERM INT USR1 USR2 USR3

    echo "Stopping managed services..."

    stop_aether

    [ -n "${XRAY_PID:-}" ] &&
        kill -TERM "$XRAY_PID" 2>/dev/null || true

    [ -n "${SNI_PID:-}" ] &&
        kill -TERM "$SNI_PID" 2>/dev/null || true

    [ -n "${NGINX_PID:-}" ] &&
        kill -TERM "$NGINX_PID" 2>/dev/null || true

    [ -n "${XRAY_PID:-}" ] &&
        wait "$XRAY_PID" 2>/dev/null || true

    [ -n "${SNI_PID:-}" ] &&
        wait "$SNI_PID" 2>/dev/null || true

    [ -n "${NGINX_PID:-}" ] &&
        wait "$NGINX_PID" 2>/dev/null || true
}

trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'restart_xray || true' USR1
trap 'restart_sni || true' USR2
trap 'restart_aether || true' USR3

while kill -0 "$XRAY_PID" 2>/dev/null &&
      kill -0 "$SNI_PID" 2>/dev/null &&
      kill -0 "$AETHER_PID" 2>/dev/null &&
      kill -0 "$NGINX_PID" 2>/dev/null; do
    sleep 2 || true
done

echo "A service exited; stopping the container."
exit 1
