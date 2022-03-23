#!/bin/bash

DOCKER_DNS_RESOLVER_IP="127.0.0.11"
CONT_NI="eth0"
VPN_NI="tun0" # use 'tun+' for all TUN devices
VPN_SUBNET="10.8.0.0/16"
CUR_DIR=$(pwd)
WORKDIR_CLIENT="${CUR_DIR}/client"
IPP_FILE="${WORKDIR_CLIENT}/ipp.txt"
VPN_USERS_FILE="${CUR_DIR}/iptables_vpn_users.sh"



function cur_time() {
  local t="$(date +'%Y-%m-%d_%H-%M-%S_%Z_%z')"
  echo "${t}"
}

function iptables_save() {
  local timestamp="${1}"
  local dir="server/iptables-save/${timestamp}"
  local file_prefix="${2}"
  mkdir -p "${dir}"
  iptables-save > "${dir}/iptables_rules_${file_prefix}.v4"
}

function check_file() {
  local path="${1}"
  if [ ! -f "${path}" ]; then
    echo "WARNING. File not found: ${path}"
    return 1
  else return 0
  fi
}

### Get port numbers of a local DNS resolver inside the container
function dns_port_local() {
  local protocol="${1}"
  if [ -n "${protocol}" ]; then
    local listen="$(netstat -tuln)"
    local port=$(echo "${listen}" | grep "^${protocol}" | grep -oE '127.0.0.11:[0-9]{2,5}' | cut -d: -f2 | grep -oEw '[0-9]{2,5}')
    echo "${port}"
  fi
}

### iptables rules for Docker (inside the container)
function iptables_dock_cont() {
  local dplt=$(dns_port_local "tcp")
  local dplu=$(dns_port_local "udp")

  ### Create chains required by Docker
  for docker_chain in DOCKER_OUTPUT DOCKER_POSTROUTING
  do
    iptables -t nat -N "${docker_chain}"
  done

  iptables -t nat -A OUTPUT -d "${DOCKER_DNS_RESOLVER_IP}/32" -j DOCKER_OUTPUT
  iptables -t nat -A POSTROUTING -d "${DOCKER_DNS_RESOLVER_IP}/32" -j DOCKER_POSTROUTING
  iptables -t nat -A DOCKER_OUTPUT -d "${DOCKER_DNS_RESOLVER_IP}/32" -p tcp -m tcp --dport 53 -j DNAT --to-destination "${DOCKER_DNS_RESOLVER_IP}:${dplt}"
  iptables -t nat -A DOCKER_OUTPUT -d "${DOCKER_DNS_RESOLVER_IP}/32" -p udp -m udp --dport 53 -j DNAT --to-destination "${DOCKER_DNS_RESOLVER_IP}:${dplu}"
  iptables -t nat -A DOCKER_POSTROUTING -s "${DOCKER_DNS_RESOLVER_IP}/32" -p tcp -m tcp --sport "${dplt}" -j SNAT --to-source :53
  iptables -t nat -A DOCKER_POSTROUTING -s "${DOCKER_DNS_RESOLVER_IP}/32" -p udp -m udp --sport "${dplu}" -j SNAT --to-source :53
}

function iptables_flush_all() {
  for chain in INPUT FORWARD OUTPUT
  do
    ### Set policies in all default chains to ACCEPT
    iptables -t filter -P "${chain}" ACCEPT
  done

  for table in filter nat mangle security raw
  do
    ### Flush default chains in all tables
    iptables -t "${table}" -F
    ### Delete user defined chains in all tables
    iptables -t "${table}" -X
  done
}

### Get local DNS ports
dplt=$(dns_port_local "tcp")
dplu=$(dns_port_local "udp")

### Get an IP of the primary network interface in the container
cont_ip=$(ip -o -4 addr list "${CONT_NI}" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}' | cut -d/ -f1)

### Flush all iptables rules
iptables_flush_all

### An array (dictionary) of key=value pairs: <vpn_user>=<tag1>,<tag2>...<tagN>
if check_file "${VPN_USERS_FILE}"; then
  declare -A USERS
  . "${VPN_USERS_FILE}"
fi

### Add rules for VPN users
for user in "${!USERS[@]}"
do
  echo "Adding iptables rules for USER [${user}]"
  user_ip=$(grep -w "${user}" "${IPP_FILE}" | grep -v '^\#' | cut -d, -f2)

  ### Prohibit clients to see each other. You need to make sure 'client-to-client' is disabled in the OpenVPN config
  ### otherwise, the server will still be able to forward client-to-client packets internally despite this rule
  iptables -t filter -A FORWARD -i "${VPN_NI}" -s "${user_ip}/32" -d "${VPN_SUBNET}" -j DROP

  ### Privileged users
  if echo "${USERS[${user}]}" | grep -q ',full_access,'
  then
    iptables -t filter -A FORWARD -i "${VPN_NI}" -s "${user_ip}/32" -d 0.0.0.0/0 -j ACCEPT    # full access to all IPs
#    iptables -t filter -A FORWARD -i "${VPN_NI}" -p tcp -s "${user_ip}/32" -d 0.0.0.0/0 -j ACCEPT    # full access to all IPv4 IPs via TCP
#    iptables -t filter -A FORWARD -i "${VPN_NI}" -p udp --dport 53 -s "${user_ip}/32" -d 0.0.0.0/0 -j ACCEPT    # allow public DNS via UDP, port 53m IPv4
  fi

  ### Restrics access to all destinations except those allowed above
  iptables -t filter -A FORWARD -i "${VPN_NI}" -s "${user_ip}/32" -d 0.0.0.0/0 -j DROP

done

### Route traffic from all IPs in the VPN subnet (internal virtual network) to the primary IP of the container
iptables -t nat -A POSTROUTING -o "${CONT_NI}" -s "${VPN_SUBNET}" -j SNAT --to-source "${cont_ip}"

### Add rules for Docker
iptables_dock_cont "${dplt}" "${dplu}"

### Save 2 sets of iptables rules
iptables_save "$(cur_time)" "before"
iptables_save "$(cur_time)" "after"
