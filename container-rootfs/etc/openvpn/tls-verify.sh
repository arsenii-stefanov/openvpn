#!/bin/bash

### $1 - certificate depth; '0' means that it is the final cert in the chain, i.e. the client cert
### $2 - certificate x509 SUBJ string separated with ', '

USER_CERT_DB="client/user-cert-db.txt"

if [ "${1}" == 0 ]
then
  USER_CERT_DB="client/user-cert-db.txt"
  subj="${2}"
  if [ ! -f "${USER_CERT_DB}" ]
  then
    echo "No database with user certificate common names found"
    exit 1
  fi
  common_name=$(echo "${subj}" | awk -F"CN=" '{print $2}' | awk '{print $1}' | sed 's/,$//')
  if grep -q "^${common_name}\$" "${USER_CERT_DB}"
  then
    echo "CN ${common_name} verified successfully"
    exit 0
  else
    echo "CN ${common_name} not found in the database"
    exit 1
  fi
else
  echo "The certificate depth is not 0. This does not seem to be a client certificate. Continue processing"
  exit 0
fi
