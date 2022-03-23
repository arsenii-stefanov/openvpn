#!/bin/bash

CLIENT_CONFIG_DIR="client/ccd"
CLIENT_IPP_FILE="client/ipp.txt"
DH_CERT="server/ssl/dh2048.pem"
OVPN_SRV_CONF="$(pwd)/server.conf"
OVPN_SRV_USER="nobody"
OVPN_SRV_GROUP="nogroup"
VPN_SRV_COMMON_NAME="docker-vpn.local"

echo "[INIT] Ensure that directories and files exist and have proper permissions"
mkdir -p ${CLIENT_CONFIG_DIR}
chmod 0755 ${CLIENT_CONFIG_DIR}
touch ${CLIENT_IPP_FILE}
chmod 0640 ${CLIENT_IPP_FILE}

if [ ! -f "${DH_CERT}" ]; then
  echo "[INIT] Ensure that a Diffie-Hellman key exists"
  openssl dhparam -out ${DH_CERT} 2048
fi

echo "[INIT] Ensure that a Certificate Authority for the VPN server exists"
./openvpn_helper.sh --ca-create

echo "[INIT] Ensure that a Server Certificate exist"
./openvpn_helper.sh --server-cert-create ${VPN_SRV_COMMON_NAME}

echo "[INIT] Apply iptables rules"
./iptables.sh

echo "[INIT] Start OpenVPN Server"
openvpn --config ${OVPN_SRV_CONF}
