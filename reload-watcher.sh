#!/bin/sh

PORT=9999

while true; do
  nc -l -p $PORT -q 0 > /dev/null 2>&1 &
  pid=$!

  (
    head -c 1 <&3 >/dev/null 2>&1
    openresty -s reload
  ) 3</proc/$pid/fd/0 &

  wait $pid
done
