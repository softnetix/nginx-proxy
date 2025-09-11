#!/bin/bash

# run watcher in background
/usr/local/openresty/reload-watcher.sh &

exec openresty -g "daemon off;" -c /usr/local/openresty/nginx/conf/nginx.conf
