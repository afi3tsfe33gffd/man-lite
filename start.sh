#!/bin/bash
set -e

echo "Starting X-UI + Nginx with ArvanCloud Real-IP support..."

# پورت ثابت داخلی Nginx برای ارتباط با Railway
export NGINX_PORT=3000

echo "Generating nginx.conf from template..."
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

sleep 2

echo "Starting Nginx..."
nginx -t
exec nginx -g "daemon off;"
