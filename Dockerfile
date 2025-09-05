FROM openresty/openresty:1.27.1.2-3-jammy

RUN apt update && apt install -y bash nano less jq curl iproute2 dnsutils netcat-openbsd gettext-base lsb-release luarocks logrotate wget gnupg ca-certificates git build-essential cmake inotify-tools docker.io && \
    rm -rf /var/lib/apt/lists/*

RUN luarocks install lua-resty-jit-uuid 0.0.7-2 && \
    luarocks install lua-resty-kafka 0.06-0 && \
    luarocks install botbye-openresty 0.0.13-0 && \
    luarocks install lua-resty-murmurhash3 1.0.1-0 && \
    luarocks install lua-resty-cookie

COPY healthcheck.sh /bin/healthcheck.sh
RUN chmod +x /bin/healthcheck.sh

RUN rm -rf /usr/local/openresty/nginx/html \
    && rm -f /usr/local/openresty/nginx/conf/nginx.conf.default \
    && rm -rf /etc/nginx/conf.d/*

COPY html /usr/local/openresty/nginx/html
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

COPY --chmod=644 logrotate/nginx /etc/logrotate.d/nginx

RUN mkdir -p /data/nginx/cache

RUN mv /etc/cron.daily/logrotate /etc/cron.hourly/logrotate

EXPOSE 80

CMD ["openresty", "-g", "daemon off;", "-c", "/usr/local/openresty/nginx/conf/nginx.conf"]
