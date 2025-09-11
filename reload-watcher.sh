#!/bin/sh
set -e

# How it works:
# 1. Any file event triggers the EVENT_PENDING flag.
# 2. If more than THROTTLE seconds have passed since the last reload, the reload is performed immediately.
# 3. If it is less, watcher waits until the required interval has passed, and makes one reload for all accumulated events.

RELOAD_NEEDED_FLAG_DIR="/usr/local/openresty/nginx/conf/reload"
mkdir -p "$RELOAD_NEEDED_FLAG_DIR"

HEARTBEAT_FILE="/tmp/nginx-watcher.heartbeat"

# daemon process for healthcheck
(
  while true; do
    date +%s > "$HEARTBEAT_FILE"
    sleep 5
  done
) &

log() {
    echo "$(date '+%Y/%m/%d %H:%M:%S') - [watcher] $1"
}

reload_nginx() {
    log "Reloading Nginx..."

    openresty -s reload

    log "Nginx reloaded successfully"
}


log "Watching $RELOAD_NEEDED_FLAG_DIR"

# Watch for changes in RELOAD_NEEDED_FLAG_DIR
inotifywait -m -r -e moved_to --format '%w%f %e' "$RELOAD_NEEDED_FLAG_DIR" |
while read -r FILE EVENT; do
    BASENAME=$(basename "$FILE")
    # Ignore hidden/temp files
    if echo "$BASENAME" | grep -Eq '(^\.|\.tmp$|\.swp$)'; then
        continue
    fi

    log "$EVENT: $FILE"

    reload_nginx
done
