FROM debian:latest
MAINTAINER ywfwj2008 <ywfwj2008@163.com>

ENV TENGINE_INSTALL_DIR=/usr/local/tengine \
    TENGINE_VERSION=2.1.2_f \
    PCRE_VERSION=8.38 \
    OPENSSL_VERSION=1.0.2h \
    RUN_USER=www \
    WWWROOT_DIR=/home/wwwroot \
    WWWLOGS_DIR=/home/wwwlogs \
    JEMALLOC_VERSION=4.2.1 \
    MALLOC_MODULE="--with-jemalloc"

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y ca-certificates wget gcc g++ make cmake openssl libssl-dev bzip2 psmisc
RUN useradd -M -s /sbin/nologin $RUN_USER

WORKDIR /tmp

# install jemalloc
# 查看jemalloc状态  lsof -n | grep jemalloc
RUN wget -c --no-check-certificate https://github.com/jemalloc/jemalloc/releases/download/$JEMALLOC_VERSION/jemalloc-$JEMALLOC_VERSION.tar.bz2 && \
    tar xjf jemalloc-$JEMALLOC_VERSION.tar.bz2 && \
    cd jemalloc-$JEMALLOC_VERSION && \
    ./configure && \
    make && make install && \
    echo '/usr/local/lib' > /etc/ld.so.conf.d/local.conf && \
    ldconfig && \
    rm -rf /tmp/*

# install tengine
RUN wget -c --no-check-certificate ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$PCRE_VERSION.tar.gz && \
    wget -c --no-check-certificate https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz && \
    wget -c --no-check-certificate -O nginx-upload-module-2.2.tar.gz https://github.com/vkholodkov/nginx-upload-module/archive/2.2.tar.gz && \
    wget -c --no-check-certificate https://github.com/alibaba/tengine/archive/tengine-$TENGINE_VERSION.tar.gz && \
    tar xzf pcre-$PCRE_VERSION.tar.gz && \
    tar xzf openssl-$OPENSSL_VERSION.tar.gz && \
    tar xzf nginx-upload-module-2.2.tar.gz && \
    tar xzf tengine-$TENGINE_VERSION.tar.gz && \
    cd tengine-tengine-$TENGINE_VERSION && \
    # Modify Tengine version
    sed -i 's@TENGINE "/" TENGINE_VERSION@"Tengine/unknown"@' src/core/nginx.h && \
    # close debug
    sed -i 's@CFLAGS="$CFLAGS -g"@#CFLAGS="$CFLAGS -g"@' auto/cc/gcc && \
    ./configure \
        --prefix=$TENGINE_INSTALL_DIR \
        --user=$RUN_USER --group=$RUN_USER \
        --with-http_stub_status_module \
        --with-http_spdy_module \
        --with-http_ssl_module \
        --with-ipv6 \
        --with-http_gzip_static_module \
        --with-http_realip_module \
        --with-http_flv_module \
        --with-http_concat_module=shared \
        --with-http_sysguard_module=shared \
        --with-openssl=/tmp/openssl-$OPENSSL_VERSION
        --with-pcre=/tmp/pcre-$PCRE_VERSION \
        --with-pcre-jit \
        --add-module=/tmp/nginx-upload-module-2.2 \
        $MALLOC_MODULE && \
    make && make install && \
    rm -rf /tmp/*

ADD ./conf/nginx.conf $TENGINE_INSTALL_DIR/conf/nginx.conf
ADD ./conf/proxy.conf $TENGINE_INSTALL_DIR/conf/proxy.conf
ADD ./conf/none.conf  $TENGINE_INSTALL_DIR/conf/none.conf
ADD ./etc/init.d/nginx /etc/init.d/nginx
ADD ./etc/logrotate.d/nginx /etc/logrotate.d/nginx

RUN chmod +x /etc/init.d/nginx && \
    update-rc.d nginx defaults && \
    ln -s /usr/local/tengine/sbin/nginx /usr/sbin/nginx && \
    ldconfig

# ending
RUN mkdir -p $WWWLOGS_DIR && \
    mkdir -p $WWWROOT_DIR/default && \
    echo "Hello World!" > /$WWWROOT_DIR/default/index.html

CMD ["/bin/bash"]
