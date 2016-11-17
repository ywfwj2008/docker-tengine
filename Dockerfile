FROM debian:latest
MAINTAINER ywfwj2008 <ywfwj2008@163.com>

ENV TENGINE_INSTALL_DIR=/usr/local/tengine \
    TENGINE_VERSION=2.1.2_f \
    PCRE_VERSION=8.39 \
    OPENSSL_VERSION=1.0.2j \
    RUN_USER=www \
    WWWROOT_DIR=/home/wwwroot \
    WWWLOGS_DIR=/home/wwwlogs \
    JEMALLOC_VERSION=4.3.1 \
    MALLOC_MODULE="--with-jemalloc" \
    LIBICONV_VERSION=1.14 \
    CURL_VERSION=7.51.0 \
    LIBMCRYPT_VERSION=2.5.8 \
    MHASH_VERSION=0.9.9.9 \
    MCRYPT_VERSION=2.6.8

RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y ca-certificates wget gcc g++ make cmake openssl libssl-dev bzip2 psmisc patch
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
    #wget -c --no-check-certificate -O nginx-upload-module-2.2.tar.gz https://github.com/vkholodkov/nginx-upload-module/archive/2.2.tar.gz && \
    wget -c --no-check-certificate https://github.com/alibaba/tengine/archive/tengine-$TENGINE_VERSION.tar.gz && \
    tar xzf pcre-$PCRE_VERSION.tar.gz && \
    tar xzf openssl-$OPENSSL_VERSION.tar.gz && \
    #tar xzf nginx-upload-module-2.2.tar.gz && \
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
        --with-openssl=/tmp/openssl-$OPENSSL_VERSION \
        --with-pcre=/tmp/pcre-$PCRE_VERSION \
        --with-pcre-jit \
        #--add-module=/tmp/nginx-upload-module-2.2 \
        $MALLOC_MODULE && \
    make && make install && \
    touch $TENGINE_INSTALL_DIR/conf/none.conf && \
    rm -rf /tmp/*

# php dependent
# install libiconv
ADD ./libiconv-glibc-2.16.patch /tmp/libiconv-glibc-2.16.patch
RUN wget -c --no-check-certificate http://ftp.gnu.org/pub/gnu/libiconv/libiconv-$LIBICONV_VERSION.tar.gz && \
    tar xzf libiconv-$LIBICONV_VERSION.tar.gz && \
    patch -d libiconv-$LIBICONV_VERSION -p0 < libiconv-glibc-2.16.patch && \
    cd libiconv-$LIBICONV_VERSION && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    rm -rf /tmp/*

# install
RUN wget -c --no-check-certificate https://curl.haxx.se/download/curl-$CURL_VERSION.tar.gz && \
    tar xzf curl-$CURL_VERSION.tar.gz && \
    cd curl-$CURL_VERSION && \
    ./configure --prefix=/usr/local && \
    make && make install && \
    rm -rf /tmp/*

# install mhash
RUN wget -c --no-check-certificate http://downloads.sourceforge.net/project/mhash/mhash/$MHASH_VERSION/mhash-$MHASH_VERSION.tar.gz && \
    tar xzf mhash-$MHASH_VERSION.tar.gz && \
    cd mhash-$MHASH_VERSION && \
    ./configure && \
    make && make install && \
    rm -rf /tmp/*

# install libmcrypt
RUN wget -c --no-check-certificate http://downloads.sourceforge.net/project/mcrypt/Libmcrypt/$LIBMCRYPT_VERSION/libmcrypt-$LIBMCRYPT_VERSION.tar.gz && \
    tar xzf libmcrypt-$LIBMCRYPT_VERSION.tar.gz && \
    cd libmcrypt-$LIBMCRYPT_VERSION && \
    ./configure && \
    make && make install && \
    ldconfig && \
    cd libltdl && \
    ./configure --enable-ltdl-install && \
    make && make install && \
    rm -rf /tmp/*

# install mcrypt
RUN wget -c --no-check-certificate http://downloads.sourceforge.net/project/mcrypt/MCrypt/$MCRYPT_VERSION/mcrypt-$MCRYPT_VERSION.tar.gz && \
    tar xzf mcrypt-$MCRYPT_VERSION.tar.gz && \
    cd mcrypt-$MCRYPT_VERSION && \
    ldconfig && \
    ./configure && \
    make && make install && \
    rm -rf /tmp/*

ADD ./conf/nginx.conf $TENGINE_INSTALL_DIR/conf/nginx.conf
ADD ./conf/proxy.conf $TENGINE_INSTALL_DIR/conf/proxy.conf
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

# expose port
EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
