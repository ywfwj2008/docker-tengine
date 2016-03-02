FROM ubuntu:latest

MAINTAINER ywfwj2008 <ywfwj2008@163.com>

ENV TENGINE_INSTALL_DIR=/usr/local/tengine
ENV TENGINE_VERSION=2.1.2_f
ENV PCRE_VERSION=8.38
ENV RUN_USER=www
ENV WWWROOT_DIR=/home/wwwroot
ENV WWWLOGS_DIR=/home/wwwlogs

ENV JEMALLOC_VERSION=4.1.0
ENV MALLOC_MODULE="--with-jemalloc"

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y ca-certificates wget gcc g++ make cmake openssl libssl-dev
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
    ldconfig

# install pcre
RUN wget -c --no-check-certificate ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-$PCRE_VERSION.tar.gz && \
    tar xzf pcre-$PCRE_VERSION.tar.gz && \
    cd pcre-$PCRE_VERSION && \
    ./configure && \
    make && \
    make install

# install tengine
RUN wget -c --no-check-certificate https://github.com/alibaba/tengine/archive/tengine-$TENGINE_VERSION.tar.gz && \
    tar xzf tengine-$TENGINE_VERSION.tar.gz && \
    cd tengine-tengine-$TENGINE_VERSION && \
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

ADD ./conf/nginx.conf $TENGINE_INSTALL_DIR/conf/nginx.conf
ADD ./conf/proxy.conf $TENGINE_INSTALL_DIR/conf/proxy.conf
ADD ./etc/init.d/nginx /etc/init.d/nginx
ADD ./etc/logrotate.d/nginx /etc/logrotate.d/nginx

RUN chmod +x /etc/init.d/nginx && \
    update-rc.d nginx defaults && \
    ln -s /usr/local/tengine/sbin/nginx /usr/sbin/nginx && \
    ldconfig

# end
RUN mkdir -p $WWWLOGS_DIR && \
    mkdir -p $WWWROOT_DIR/default && \
    echo "Hello World!" > /$WWWROOT_DIR/default/index.html && \
    rm -rf /tmp/*

# CMD ["nginx", "-g", "daemon off;"]
