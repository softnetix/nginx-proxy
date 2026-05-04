#!/bin/bash
set -e

LOG_DIR=/usr/local/openresty/nginx/logs

mkdir -p "$LOG_DIR"
touch "$LOG_DIR/service__api.access.log" "$LOG_DIR/service__api.error.log"

tail -n 0 -F "$LOG_DIR/service__api.access.log" &
tail -n 0 -F "$LOG_DIR/service__api.error.log" >&2 &

# run watcher in background
/usr/local/openresty/reload-watcher.sh &

exec openresty -g "daemon off;" -c /usr/local/openresty/nginx/conf/nginx.conf
