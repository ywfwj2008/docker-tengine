FROM ubuntu:latest

MAINTAINER ywfwj2008 <ywfwj2008@163.com>

ENV TENGINE_INSTALL_DIR /usr/local/tengine
ENV TENGINE_VERSION 2.1.2
ENV PCRE_VERSION 8.38
ENV RUN_USER www
ENV WWWROOT_DIR /home/wwwroot
ENV WWWLOGS_DIR /home/wwwlogs
ENV MALLOC_MODULE

RUN apt-get update && \
    apt-get install -y ca-certificates wget gcc g++ make cmake openssl libssl-dev
RUN useradd -M -s /sbin/nologin $RUN_USER

WORKDIR /tmp

# install pcre
RUN wget -c --no-check-certificate ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$PCRE_VERSION.tar.gz && \
    tar xzf pcre-$PCRE_VERSION.tar.gz && \
    cd pcre-$PCRE_VERSION && \
    ./configure && \
    make && \
    make install

# install tengine
RUN wget -c --no-check-certificate http://tengine.taobao.org/download/tengine-$TENGINE_VERSION.tar.gz && \
    tar xzf tengine-$TENGINE_VERSION.tar.gz && \
    echo tengine-$TENGINE_VERSION && \
    cd tengine-$TENGINE_VERSION && \
    # Modify Tengine version
    sed -i 's@TENGINE "/" TENGINE_VERSION@"Tengine/unknown"@' src/core/nginx.h && \
    # close debug
    sed -i 's@CFLAGS="$CFLAGS -g"@#CFLAGS="$CFLAGS -g"@' auto/cc/gcc && \
    ./configure \
        --prefix=$TENGINE_INSTALL_DIR \
        --user=$RUN_USER \
        --group=$RUN_USER \
        --with-http_stub_status_module \
        --with-http_spdy_module \
        --with-http_ssl_module \
        --with-ipv6 \
        --with-http_gzip_static_module \
        --with-http_realip_module \
        --with-http_flv_module \
        --with-http_concat_module=shared \
        --with-http_sysguard_module=shared \
        $MALLOC_MODULE && \
    make && \
    make install

ADD ./nginx.conf $TENGINE_INSTALL_DIR/conf/nginx.conf
ADD ./proxy.conf $TENGINE_INSTALL_DIR/conf/proxy.conf
ADD ./nginx /etc/init.d/nginx

RUN chmod +x /etc/init.d/nginx && \
    update-rc.d nginx defaults && \
    ln -s /usr/local/tengine/sbin/nginx /usr/sbin/nginx && \
    ldconfig

RUN mkdir -p $WWWLOGS_DIR && \
    mkdir -p $WWWROOT_DIR/default && \
    echo "Hello World!" > /$WWWROOT_DIR/default/index.html && \
    rm -rf /tmp/*

EXPOSE 80 443

# ENTRYPOINT ["nginx", "-g", "daemon off;"]

# CMD ["-c", "/usr/local/tengine/conf/nginx.conf"]
