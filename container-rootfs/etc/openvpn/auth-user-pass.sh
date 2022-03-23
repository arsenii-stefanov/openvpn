#!/bin/bash

USERS_DB="client/user-db.txt" # File with usernames and password hashes
PASSWORD_LENGTH="32" # Length of the password that will be generated
OVPN_SRV_USER="nobody"
OVPN_SRV_GROUP="nogroup"

function create_db() {
  if [ ! -f "${USERS_DB}" ]
  then
    echo "No user database found. Creating one..."
    touch "${USERS_DB}"
    chown "${OVPN_SRV_USER}:${OVPN_SRV_GROUP}" "${USERS_DB}"
    chmod 0400 "${USERS_DB}"
  fi
}

### Generate a SHA1 hash value of the given password multiple times
function hashround() {
  local hash rest
  read hash rest
  printf '%s%s' "$hash" "$hash" | sha1sum
}

### Get username and password from a temporary file generated by the OpenVPN server
### and provided as a command line argument
function get_user_pass_file() {
  local openvpn_temp_cred_file="$1"
  local username="$(awk 'NR==1' ${openvpn_temp_cred_file})"
  local password="$(awk 'NR==2' ${openvpn_temp_cred_file})"
  hashpass=$(hash_pass "${username}" "${password}")
  validate_user_pass "${username}" "${hashpass}"
}

### Get username and password provided by the OpenVPN server
### as environment variables
function get_user_pass_env() {
  local username="${username}"
  local password="${password}"
  if [ -z "${username// }" ] || [ -z "${password// }" ]
  then
    echo "Either username or password is empty."
    exit 1
  fi
  hashpass=$(hash_pass "${username}" "${password}")
  validate_user_pass "${username}" "${hashpass}"
}

function hash_pass() {
  local username="${1}"
  local password="${2}"
  ### Generate a SHA1 hash of the given password and loop it 10 times before comparing with the hash value in the users database file
  hashpass=$(printf '%s%s' "$username" "$password" | sha1sum \
             | hashround | hashround | hashround | hashround | hashround \
             | hashround | hashround | hashround | hashround | hashround \
             | cut -d' ' -f1)
  echo "${hashpass}"
}

### Check if username and password provided by the OpenVPN server exist in the user database
function validate_user_pass() {
  local username="${1}"
  local password="${2}"
  if grep -Fxq "${username}:${hashpass}" "$USERS_DB"
  then
    echo "User Authenticated: ${username}" >&2
    exit 0
  else
    echo "Invalid username or password for user: ${username}" >&2
    exit 1
  fi
}

function validate_username() {
  local username="${1}"
  if [ -z "${username}" ]
  then
    echo "Please supply a username."
    return 1
  fi
  if echo ${username} | grep -Eq '!|#|\$|%|\^|&|\*|\(|\)|\{|\}|\[|\]|"|\?|,|~|\+|=' || echo ${username} | grep -q "'" || echo ${username} | grep -q '"'
  then
    echo -n "The username must not contain special characters.\nThe following characters are allowed: a-z, A-Z, . (dot), - (dash), _ (underscore), @ (at)"
    return 1
  fi
  if grep -q "^${username}:" "$USERS_DB"
  then
    echo "User ${username} alread exists in $USERS_DB"
    return 1
  fi
  return 0
}

### Generate a strong random password
function gen_pswd() {
  local LC_CTYPE=C
  local password=$(cat /dev/urandom | tr -dc a-zA-Z0-9\+\@\! | fold -w ${PASSWORD_LENGTH:-32} | head -n 1)
  echo "${password}"
}

if [ -n "${1}" ]
then
  if [ "$1" == "--client-create" ]
  then
    username="${2}"
    if validate_username "${username}"
    then
      password=$(gen_pswd)
      hashpass=$(hash_pass "${username}" "${password}")
      echo "Username: ${username}"
      echo "Password: ${password}"
      create_db
      echo "Adding the user to the database ${USERS_DB}"
      echo "${username}:${hashpass}" >> "${USERS_DB}"
    fi
  elif [ "$1" == "--client-delete" ]
  then
    username="${2}"
    if grep -q "^${username}:" "$USERS_DB"
    then
      echo "Deleting user ${username}"
      sed -i "/^${username}:/d" "${USERS_DB}"
    else
      echo "User ${username} not found in ${USERS_DB}"
    fi
  else
    get_user_pass_file "${1}"
  fi
else
  get_user_pass_env
fi
