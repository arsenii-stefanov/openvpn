#!/bin/bash

set -eo pipefail

### CHANGE THESE VALUES TO YOUR ORG VALUES
CERT_SUBJ_COUNTRY="US"
CERT_SUBJ_STATE="NY"
CERT_SUBJ_LOCATION="NewYork"
CERT_SUBJ_ORGANISATION="MyCompany"
CERT_SUBJ_ORG_UNIT="IT"
CERT_SUBJ_COMMON_NAME="vpn.local"
CERT_SUBJ_EMAIL="admin@vpn.local"
OVPN_SRV_USER="nobody"
OVPN_SRV_GROUP="nogroup"

### Certificate Authority
CERT_ENCRYPTION_KEY_STRENGTH_CA="4096"
CERT_EXP_DAYS_CA="3650"

### Server
CERT_ENCRYPTION_KEY_STRENGTH_SERVER="4096"
CERT_EXP_DAYS_SERVER="3650"

### Client
CERT_ENCRYPTION_KEY_STRENGTH_CLIENT="4096"
CERT_EXP_DAYS_DEFAULT="3650"

################################
###     SYSTEM VARIABLES     ###
################################
CUR_DIR=$(pwd)
WORKDIR_SERVER="${CUR_DIR}/server"
SSL_DIR_SERVER="${WORKDIR_SERVER}/ssl"
WORKDIR_CLIENT="${CUR_DIR}/client"
CONF_DIR_CLIENT="${WORKDIR_CLIENT}/config"
CA_ROOT_DIR="${SSL_DIR_SERVER}/ca"
CA_ROOT_CRT="${CA_ROOT_DIR}/rootCA.crt"
CA_ROOT_KEY="${CA_ROOT_DIR}/rootCA.key"
OVPN_TA_KEY="${SSL_DIR_SERVER}/ta.key"
CLIENT_CONFIG_TEMPLATE="${CUR_DIR}/client-config.template"
IPP_FILE="${WORKDIR_CLIENT}/ipp.txt"
CCD_DIR="${WORKDIR_CLIENT}/ccd"
USER_CERT_DB="client/user-cert-db.txt"

help() {
	echo "Script usage:
$0 --ca-create - generate root (CA) cert and key
$0 --server-cert-create <openvpn_server_name> - generate server cert, key
Ex.: $0 --server-cert-create myvpn.local
$0 --client-create-cert <common_name> <cert_expiration_days> - generate a client cert
Ex.: $0 --client-create-cert john-doe 3650
$0 --client-create-user <username> - add a user to the database
Ex.: $0 --client-create-user john-doe@gmail.com
$0 --client-delete-cert <common_name> - delete a client certificate
Ex.: $0 --client-delete-cert jane-doe
$0 --client-delete-user <username> - delete a user from the database
Ex.: $0 --client-delete-user jane-doe
"
}

function check_file() {
    local file_path="$1"
    if [ -f "${file_path}" ]; then
      echo -e "File already exists: ${file_path}\nSkipping...\nNote: if you would like to have a new one generated, please delete the old one first"
      return 1
    else
      return 0
    fi
}

function create_cert_db() {
  if [ ! -f "${USER_CERT_DB}" ]
  then
    echo "No certificate database found. Creating one..."
    touch "${USER_CERT_DB}"
    chown "${OVPN_SRV_USER}:${OVPN_SRV_GROUP}" "${USER_CERT_DB}"
    chmod 0400 "${USER_CERT_DB}"
  fi
}

function gen_ssl_subj() {
  local common_name="${1}"
  if [ -z "${common_name// }" ]; then
    common_name="${CERT_SUBJ_COMMON_NAME}"
  fi
  local subj="/C=${CERT_SUBJ_COUNTRY}/ST=${CERT_SUBJ_STATE}/L=${CERT_SUBJ_LOCATION}/O=${CERT_SUBJ_ORGANISATION}/OU=${CERT_SUBJ_ORG_UNIT}/CN=${common_name}/emailAddress=${CERT_SUBJ_EMAIL}"
  echo "${subj}"
}

function gen_ssl_ca() {
	openssl req -x509 -newkey rsa:${CERT_ENCRYPTION_KEY_STRENGTH_CA} \
	            -keyout ${CA_ROOT_KEY} \
	            -out ${CA_ROOT_CRT} \
	            -days ${CERT_EXP_DAYS_CA} \
	            -nodes \
                    -subj $(gen_ssl_subj)
}

function gen_ssl() {
  local common_name="${1}"
  local key_name="${2}"
  local csr_name="${3}"
  local crt_name="${4}"
  local cert_exp_days="${5}"

  if [ -z "${cert_exp_days// }" ]; then
  	cert_exp_days="${CERT_EXP_DAYS_DEFAULT}"
  fi

  openssl genrsa ${CERT_ENCRYPTION_KEY_STRENGTH} > ${key_name} 2>/dev/null

  openssl req -new -key ${key_name} \
              -out ${csr_name} \
              -subj $(gen_ssl_subj "${common_name}") \
              -addext "basicConstraints = CA:TRUE" \
              -addext "keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment" \
              -addext "subjectKeyIdentifier = hash" \
              -addext "extendedKeyUsage = serverAuth" \
              -addext "nsComment = 'OpenSSL Generated Certificate'"

  openssl x509 -req -in ${csr_name} -CA ${CA_ROOT_CRT} -CAkey ${CA_ROOT_KEY} -CAcreateserial \
              -sha256 \
              -out ${crt_name} \
              -days ${cert_exp_days}

}

function gen_ovpn_client_conf() {
  local common_name="${1}"
  local ca_path="${2}"
  local crt_path="${3}"
  local key_path="${4}"
  local ta_path="${5}"
  local ovpn_path="${6}"
  local ca=$(cat ${ca_path})
  local crt=$(cat ${crt_path})
  local key=$(cat ${key_path})
  local ta=$(cat ${ta_path})

#  cp "${CLIENT_CONFIG_TEMPLATE}" "${ovpn_path}"

  grep -v '^\#' "${CLIENT_CONFIG_TEMPLATE}" > "${ovpn_path}"

  cat >> "${ovpn_path}" <<EOF
<ca>
${ca}
</ca>
<cert>
${crt}
</cert>
<key>
${key}
</key>
<tls-auth>
${ta}
</tls-auth>
EOF

  ls ${crt_path} ${key_path} ${csr_path} ${ovpn_path}
}

##########################
###        MAIN        ###
##########################

### Ensure that directories created by the command below have permissions 0755
umask 0077

mkdir -p ${SSL_DIR_SERVER} ${WORKDIR_SERVER} ${WORKDIR_CLIENT} ${CONF_DIR_CLIENT} ${CA_ROOT_DIR}

### Command line arguments
option="${1}"
name="${2}"
cert_exp_days="${3}"

### Ensure that file created by the commands below have permissions 0600
umask 0177

case "${option}" in
  "--ca-create")
    ### Generate root certificate authority cert and key if they do not exist, otherwise use the existing ones
    if check_file ${CA_ROOT_CRT}; then
      echo "Generating Certificate Authority cert and key"
      gen_ssl_ca
    fi
  ;;
  "--server-cert-create")
    if check_file "${SSL_DIR_SERVER}/server.crt"; then
      echo "Generating server cert and key"
      gen_ssl "${name}" \
              "${SSL_DIR_SERVER}/server.key" \
              "${SSL_DIR_SERVER}/server.csr" \
              "${SSL_DIR_SERVER}/server.crt" \
              "${CERT_EXP_DAYS_SERVER}"
      openvpn --genkey secret "${OVPN_TA_KEY}"
    fi
  ;;
  "--client-create-cert")
    if check_file "${CONF_DIR_CLIENT}/${name}.ovpn"; then
      echo "Generating client cert and key"
      gen_ssl "${name}" \
              "${CONF_DIR_CLIENT}/${name}.key" \
              "${CONF_DIR_CLIENT}/${name}.csr" \
              "${CONF_DIR_CLIENT}/${name}.crt" \
              "${cert_exp_days}"
      client_conf=$(gen_ovpn_client_conf "${name}" \
                                         "${CA_ROOT_CRT}" \
                                         "${CONF_DIR_CLIENT}/${name}.crt" \
                                         "${CONF_DIR_CLIENT}/${name}.key" \
                                         "${OVPN_TA_KEY}" \
                                         "${CONF_DIR_CLIENT}/${name}.ovpn"
                  )
      create_cert_db
      echo "Adding the CN [${name}] to the database [${USER_CERT_DB}]"
      echo "${name}" >> "${USER_CERT_DB}"
      echo "${client_conf}"
    fi
  ;;
    "--client-create-user")
      ./auth-user-pass.sh --client-create "${name}"
  ;;
  "--client-delete-cert")
    rm -fv "${CONF_DIR_CLIENT}/${name}.crt" \
           "${CONF_DIR_CLIENT}/${name}.csr" \
           "${CONF_DIR_CLIENT}/${name}.key" \
           "${CONF_DIR_CLIENT}/${name}.ovpn"
    sed -i "/^${name},/d" "${IPP_FILE}"
    rm -fv "${CCD_DIR}/${name}"
    sed -i "/^${name}\$/d" "${USER_CERT_DB}"
  ;;
  "--client-delete-user")
    ./auth-user-pass.sh --client-delete "${name}"
  ;;
  *|"help")
      help
  ;;
esac
