#!/usr/bin/env bash
set -x 
set -e

## Import software versions
source 'data/versions.sh'

## Import extra modules
source 'data/modules.sh'

## File/directory names
NGINX="nginx-$NGINX_VERSION"
OPENSSL="openssl-$OPENSSL_VERSION"
PCRE="pcre-$PCRE_VERSION"
ZLIB="zlib-$ZLIB_VERSION"

echo "nginx-$NGINX_VERSION"
echo "openssl-$OPENSSL_VERSION"
echo "pcre-$PCRE_VERSION"
echo "zlib-$ZLIB_VERSION"

## Go to the local source code directory
cd /usr/local/src

## Download Nginx
if [ ! -f $NGINX.tar.gz ] ; then
    wget -q https://nginx.org/download/$NGINX.tar.gz
    tar -xzf $NGINX.tar.gz
    rm -f $NGINX.tar.gz
fi

## Download OpenSSL
if [ ! -f $OPENSSL.tar.gz ] ; then
    wget -q https://www.openssl.org/source/$OPENSSL.tar.gz
    tar -xzf $OPENSSL.tar.gz
    rm -f $OPENSSL.tar.gz
fi

## Download PCRE
if [ ! -f $PCRE.tar.gz ] ; then
    wget -q https://ftp.pcre.org/pub/pcre/$PCRE.tar.gz
    tar -xzf $PCRE.tar.gz
    rm -f $PCRE.tar.gz
fi

## Download Zlib
if [ ! -f $ZLIB.tar.gz ] ; then
    wget -q https://zlib.net/$ZLIB.tar.gz
    tar -xzf $ZLIB.tar.gz
    rm -f $ZLIB.tar.gz
fi

## Download PageSpeed module (optional)
if [ ${INSTALL_PAGESPEED} == "yes" ]; then
        if [ ! -f v${PAGESPEED_VERSION}-stable.zip ] ; then
            wget -q https://github.com/pagespeed/ngx_pagespeed/archive/v${PAGESPEED_VERSION}-stable.zip
            unzip -qq v${PAGESPEED_VERSION}-stable.zip
            rm -f v${PAGESPEED_VERSION}-stable.zip
        fi

	cd ngx_pagespeed-${PAGESPEED_VERSION}-stable
        if [ ! -f psol-${PAGESPEED_VERSION}.tar.gz ] ; then
            PSOL_URL=`scripts/format_binary_url.sh PSOL_BINARY_URL`
            wget -q ${PSOL_URL} -O psol-${PAGESPEED_VERSION}.tar.gz
            tar xzf psol-${PAGESPEED_VERSION}.tar.gz && rm -f psol-${PAGESPEED_VERSION}.tar.gz
        fi
	cd ..

	PAGESPEED_MODULE="--add-module=../ngx_pagespeed-${PAGESPEED_VERSION}-stable"
else
	PAGESPEED_MODULE=""
fi

## Download NAXSI module (optional)
if [ ${INSTALL_NAXSI} == "yes" ]; then
        if [ -d naxsi ] ; then
            git clone https://github.com/nbs-system/naxsi.git --branch http2
        fi
	NAXSI_MODULE="--add-module=../naxsi/naxsi_src"
else
	NAXSI_MODULE=""
fi

## Configure, compile and install
cd $NGINX

DEBIAN_CFLAGS="$(dpkg-buildflags --get CFLAGS | sed 's/-O3/-O2/') $(dpkg-buildflags --get CPPFLAGS)"
DEBIAN_LDFLAGS="$(dpkg-buildflags --get LDFLAGS)"

./configure \
        --with-cc-opt="${DEBIAN_CFLAGS}" \
        --with-ld-opt="${DEBIAN_LDFLAGS}" \
	--prefix=/usr/share/nginx \
	--sbin-path=/usr/sbin/nginx \
	--conf-path=/etc/nginx/nginx.conf \
	--pid-path=/run/nginx.pid \
	--error-log-path=/var/log/nginx/error.log \
	--http-log-path=/var/log/nginx/access.log \
	--user=www-data \
	--group=www-data \
	--lock-path=/var/lock/nginx.lock \
	--modules-path=/usr/lib64/nginx/modules \
        --http-client-body-temp-path=/var/lib/nginx/body \
        --http-fastcgi-temp-path=/var/lib/nginx/fastcgi \
        --http-proxy-temp-path=/var/lib/nginx/proxy \
        --http-scgi-temp-path=/var/lib/nginx/scgi \
        --http-uwsgi-temp-path=/var/lib/nginx/uwsgi \
        --with-debug \
	--with-compat \
	--with-file-aio \
	--with-threads \
	--with-http_addition_module \
	--with-http_auth_request_module \
	--with-http_dav_module \
	--with-http_flv_module \
	--with-http_gunzip_module \
	--with-http_gzip_static_module \
	--with-http_mp4_module \
	--with-http_random_index_module \
	--with-http_realip_module \
	--with-http_secure_link_module \
	--with-http_slice_module \
	--with-http_ssl_module \
	--with-http_stub_status_module \
	--with-http_sub_module \
	--with-http_v2_module \
	--with-mail \
	--with-mail_ssl_module \
        --with-stream \
        --with-stream_realip_module \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-zlib=/usr/local/src/$ZLIB \
        --with-ipv6 \
        --with-http_geoip_module \
        --with-http_image_filter_module \
        --with-http_xslt_module \
	--with-openssl=/usr/local/src/$OPENSSL \
	--with-pcre=/usr/local/src/$PCRE \
	--with-pcre-jit \
        ${PAGESPEED_MODULE} \
        ${NAXSI_MODULE}

## working
#        --with-cc-opt='-g -O2 -fstack-protector --param=ssp-buffer-size=4 -Wformat -Werror=format-security -D_FORTIFY_SOURCE=2'
## not working - repo default
#        --with-cc-opt='-O2 -g -pipe -Wall -Wp,-D_FORTIFY_SOURCE=2 -fexceptions -fstack-protector-strong --param=ssp-buffer-size=4 -grecord-gcc-switches -m64 -mtune=generic'

make -j $(nproc)
# make install

## Naxsi rules
if [ "${INSTALL_NAXSI}" == "yes" ]; then
	if [ ! -e "/etc/nginx/naxsi" ]; then
		mkdir -p /etc/nginx/naxsi
	fi

	# Download core rules
	if [ ! -e "/etc/nginx/naxsi/naxsi-core.rules" ]; then
		wget -q -O /etc/nginx/naxsi/naxsi-core.rules https://raw.githubusercontent.com/nbs-system/naxsi/master/naxsi_config/naxsi_core.rules
	fi

	# Download WordPress rules
	if [ ! -e "/etc/nginx/naxsi/naxsi-wordpress.rules" ]; then
		wget -q -O /etc/nginx/naxsi/naxsi-wordpress.rules https://raw.githubusercontent.com/nbs-system/naxsi-rules/master/wordpress.rules
	fi

	# Download Drupal rules
	if [ ! -e "/etc/nginx/naxsi/naxsi-drupal.rules" ]; then
		wget -q -O /etc/nginx/naxsi/naxsi-drupal.rules https://raw.githubusercontent.com/nbs-system/naxsi-rules/master/drupal.rules
	fi
fi

## Cleanup
cd ..
# rm -rf $NGINX $OPENSSL $PCRE $ZLIB naxsi* ngx_pagespeed-*-stable

