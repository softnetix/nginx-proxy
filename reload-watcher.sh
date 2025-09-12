#!/bin/bash
set -e

# How it works:
# 1. Starts a background heartbeat loop that updates $HEARTBEAT_FILE every 5 seconds (for health checks)
# 2. Uses inotifywait to watch recursively for "moved_to" events within the flag directory. Hidden/temporary files are ignored.
# Other processes can atomically signal a reload by moving a file into this directory
# 3. On every valid event, immediately runs "openresty -s reload"

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
    echo "$(date '+%Y/%m/%d %H:%M:%S') - [watcher] $1" >&2
}

reload_nginx() {
    log "Reloading Nginx..."

    openresty -s reload

    log "Nginx reloaded successfully"
}


log "Watching $RELOAD_NEEDED_FLAG_DIR"

# Watch for changes in RELOAD_NEEDED_FLAG_DIR
while read -r FILE EVENT; do
    BASENAME=$(basename "$FILE")
    # Ignore hidden/temp files
    if echo "$BASENAME" | grep -Eq '(^\.|\.tmp$|\.swp$)'; then
        continue
    fi

    log "$EVENT: $FILE"

    reload_nginx
done < <(inotifywait -m -r -e moved_to --format '%w%f %e' "$RELOAD_NEEDED_FLAG_DIR")
