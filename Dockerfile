FROM alpine:edge

ENV KEA_URL https://downloads.isc.org/isc/kea/1.6.2/kea-1.6.2.tar.gz

RUN addgroup -S kea && adduser -S kea -G kea

RUN set -x \
  \
  && echo http://dl-cdn.alpinelinux.org/alpine/edge/testing >> /etc/apk/repositories \
  && apk add --no-cache --virtual .build-deps \
    mariadb-dev \
    postgresql-dev \
    boost-dev \
    log4cplus-dev \
    autoconf \
    make \
    automake \
    libtool \
    g++ \
  \
## build kea
  && cd / \
  && wget -O kea.tar.gz $KEA_URL \
  && mkdir -p /usr/src/kea \
  && tar xf kea.tar.gz --strip-components=1 -C /usr/src/kea \
  && rm kea.tar.gz \
  && cd /usr/src/kea \
  \
  && autoreconf \
    --install \
  && CXXFLAGS='-Os' ./configure \
    --prefix=/usr/local \
    --sysconfdir=/etc \
    --localstatedir=/var \
    --with-mysql \
    --with-pgsql \
    --with-openssl \
    --enable-static=false \
  && make -j "$(getconf _NPROCESSORS_ONLN)" \
  && make install \
  \
## cleanup
  && cd / \
  && rm -rf /usr/src \
  \
  && runDeps="$( \
    scanelf --needed --nobanner --format '%n#p' --recursive /usr/local \
      | tr ',' '\n' \
      | sort -u \
      | awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
  )" \
  && apk add --virtual .kea-rundeps $runDeps \
  && apk add tcpdump \
  && apk add libcap \
  && apk add iptables \
  && apk add curl \
  && apk del .build-deps \
  && chgrp -R kea /usr/local \
  && chown -R kea /var/lib/kea \
  && chgrp -R kea /run/kea \
  && chown -R kea /run/kea \
  # Allows kea executables, running as a non-root user, to open privileged network ports:
  && setcap 'cap_net_bind_service,cap_net_raw=+ep' /usr/local/sbin/kea-dhcp4 \
  && setcap 'cap_net_bind_service,cap_net_raw=+ep' /usr/local/sbin/kea-dhcp6

#USER kea
#WORKDIR /home/kea
