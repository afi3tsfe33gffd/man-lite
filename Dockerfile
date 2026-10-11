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

COPY cotten/CottenDns_Client_Linux-Legacy_AMD64_v2026.10.08.163633-1f3cc52 /usr/local/bin/cotten
COPY cotten/slipnet-linux-amd64 /usr/local/bin/slipnet

RUN chmod +x /usr/local/bin/cotten /usr/local/bin/slipnet

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /start.sh

RUN chmod +x /start.sh

CMD ["/start.sh"]
