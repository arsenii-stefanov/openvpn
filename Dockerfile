### BASE_IMAGE=alpine:3.15.1
ARG BASE_IMAGE=alpine@sha256:14b55f5bb845c7b810283290ce057f175de87838be56f49060e941580032c60c
ARG OPENVPN_VER=2.5.6-r0
ARG OPENSSL_VER=1.1.1q-r0
ARG OPENVPN_WORKDIR=/etc/openvpn

FROM ${BASE_IMAGE}

ARG OPENVPN_VER
ARG OPENSSL_VER
ARG OPENVPN_WORKDIR

RUN apk add --no-cache \
            openvpn=${OPENVPN_VER} \
            openssl=${OPENSSL_VER} \
            bind-tools \
            bash \
            curl

COPY container-rootfs/ /

WORKDIR ${OPENVPN_WORKDIR}

EXPOSE 1194

ENTRYPOINT ["/entrypoint.sh"]
