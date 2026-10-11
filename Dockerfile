FROM teddysun/xray:26.9.30

RUN apk add --no-cache \
    curl \
    bash \
    ca-certificates \
    socat \
    tzdata \
    sqlite \
    nginx \
    gettext \
    tmux \
    nano \
    jq \
    && ln -sf /usr/share/zoneinfo/Asia/Tehran /etc/localtime

RUN curl -fL \
    https://github.com/therealaleph/sni-spoofing-rust/releases/download/v1.0.2/sni-spoof-rs-linux-amd64-musl \
    -o /usr/local/bin/sni-spoof-rs \
    && chmod +x /usr/local/bin/sni-spoof-rs

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /start.sh

RUN chmod +x /start.sh

CMD ["/start.sh"]
