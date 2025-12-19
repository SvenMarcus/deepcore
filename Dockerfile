FROM alpine:3.22.1

RUN apk add --no-cache \
    bash \
    build-base \
    git \
    lua5.1-dev \
    luarocks5.1 \
    libc6-compat 

RUN ln -s /usr/bin/luarocks-5.1 /usr/bin/luarocks
RUN luarocks install busted

CMD [ "/bin/bash" ]