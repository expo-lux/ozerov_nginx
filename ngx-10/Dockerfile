FROM ubuntu:20.04 as builder

ENV NGINX_VERSION 1.18.0

RUN sed -i 's/# deb-src/deb-src/g' /etc/apt/sources.list \
    && apt update && apt -y install git

WORKDIR /opt
#ставим все необходимое для сборки nginx
RUN DEBIAN_FRONTEND=noninteractive apt-get -q -y build-dep nginx=${NGINX_VERSION} \
    && apt-get source nginx=${NGINX_VERSION}

#клонируем nginx_upstream_check_module
RUN git clone https://github.com/yaoweibin/nginx_upstream_check_module \
    && cd nginx_upstream_check_module \
    && git checkout e85752f0b9bd848f7917e02275da4013566f34d8

#патчим nginx и запускаем сборку
WORKDIR /opt/nginx-${NGINX_VERSION}
RUN patch -p1 < /opt/nginx_upstream_check_module/check_1.16.1+.patch \
    && sed -i 's/--with-threads/& --add-module=\/opt\/nginx_upstream_check_module/g' /opt/nginx-${NGINX_VERSION}/debian/rules \
    && dpkg-buildpackage -b --no-sign

# необходимые файлы лежат в
# /opt/libnginx-mod-http-geoip2_1.18.0-0ubuntu1.3_amd64.deb
# 
