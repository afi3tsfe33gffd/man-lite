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
    && ln -sf /usr/share/zoneinfo/Asia/Tehran /etc/localtime
    

COPY nginx.conf.template /etc/nginx/nginx.conf.template
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
