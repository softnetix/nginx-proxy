FROM openresty/openresty:1.27.1.2-3-jammy AS compression-modules

ARG OPENRESTY_VERSION=1.27.1.2
ARG NGX_BROTLI_COMMIT=53e0fb55f250f48fe80c0ddbf6c0f7103cdbaae1
ARG ZSTD_NGINX_MODULE_COMMIT=057a7d339af1111d04b5a9ac5ae9b0250d17cd94

RUN apt update && apt install -y build-essential cmake git curl ca-certificates zlib1g-dev libzstd-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN git clone https://github.com/google/ngx_brotli && git -C ngx_brotli checkout ${NGX_BROTLI_COMMIT} && git -C ngx_brotli submodule update --init && \
    git clone https://github.com/tokers/zstd-nginx-module && git -C zstd-nginx-module checkout ${ZSTD_NGINX_MODULE_COMMIT} && \
    curl -fsSL https://openresty.org/download/openresty-${OPENRESTY_VERSION}.tar.gz | tar xz

# ngx_brotli links the encoder statically from its submodule.
RUN cmake -S ngx_brotli/deps/brotli -B ngx_brotli/deps/brotli/out -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_C_FLAGS="-O2 -fPIC" && \
    cmake --build ngx_brotli/deps/brotli/out --target brotlienc

# --with-compat matches the base image's nginx, so the modules load into it without rebuilding openresty.
RUN cd openresty-${OPENRESTY_VERSION}/bundle/nginx-* && \
    ./configure --with-compat \
        --with-cc-opt='-I/usr/local/openresty/pcre2/include -I/usr/local/openresty/openssl3/include' \
        --with-ld-opt='-L/usr/local/openresty/pcre2/lib -L/usr/local/openresty/openssl3/lib' \
        --add-dynamic-module=/src/ngx_brotli \
        --add-dynamic-module=/src/zstd-nginx-module && \
    make modules && \
    mkdir /modules && cp objs/ngx_http_brotli_filter_module.so objs/ngx_http_zstd_filter_module.so /modules/

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

COPY --from=compression-modules /modules/ /usr/local/openresty/nginx/modules/
# Outside nginx/conf, which the deployment mounts as a volume the nginx agent writes.
COPY compression /usr/local/openresty/compression

COPY html /usr/local/openresty/nginx/html
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf

COPY --chmod=644 logrotate/nginx /etc/logrotate.d/nginx

RUN mkdir -p /data/nginx/cache

RUN mv /etc/cron.daily/logrotate /etc/cron.hourly/logrotate

COPY reload-watcher.sh /usr/local/openresty/
RUN chmod +x /usr/local/openresty/reload-watcher.sh

COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh

EXPOSE 80

CMD ["/usr/local/bin/start.sh"]
