### BASE_IMAGE=ubuntu:26.04
ARG BASE_IMAGE=ubuntu@sha256:5e275723f82c67e387ba9e3c24baa0abdcb268917f276a0561c97bef9450d0b4
ARG OPENVPN_VER=2.7.0-1ubuntu1
ARG OPENSSL_VER=3.5.5-1ubuntu3
ARG OPENVPN_WORKDIR=/etc/openvpn

FROM ${BASE_IMAGE}

ARG OPENVPN_VER
ARG OPENSSL_VER
ARG OPENVPN_WORKDIR

RUN apt update && \
    apt install -y \
            openvpn=${OPENVPN_VER} \
            openssl=${OPENSSL_VER} \
            bind9-dnsutils \
            iptables \
            iproute2 \
            net-tools \
            bash \
            curl \
            dnsmasq

#COPY container-rootfs/ /

WORKDIR ${OPENVPN_WORKDIR}

EXPOSE 1194

ENTRYPOINT ["/srv/bin/entrypoint.sh"]
