# OpenVPN Server In a Container

## What each file is needed for

```
├── Dockerfile -- main Dockerfile
├── Makefile -- shortcuts for operating containers
├── README.md -- this README
├── container-rootfs  -- all files in this directory will be copied to '/' in a container image your build
│   ├── entrypoint.sh -- this is the container startup script that invokes other scripts and starts the main container process (OpenVPN Server)
│   └── etc
│       └── openvpn -- OpenVPN config directory
│           ├── auth-user-pass.sh -- this script is invoked by either 'openvpn_helper.sh' (for adding users and passwords to a local DB) or by OpenVPN Server (for authenticating users)
│           ├── client -- a directory for all client configurations
│           │   ├── ccd -- a directory for client configurations used by the server 
│           │   │   └── admin -- an individual file for each user (contains 'ifconfig-push' directives)
│           │   └── ipp.txt -- a file with unique IP addresses bound to each VPN user 
│           ├── client-config.template -- a base file for a '.ovpn' config file generated for each VPN user
│           ├── iptables.sh -- a script for adding basic firewall rules for the VPN to operate as well as for providing granular access for each VPN user
│           ├── iptables_vpn_users.sh -- an array of VPN users (the usernames are the same as in the 'ipp.txt' file)
│           ├── openvpn_helper.sh -- a script for creation of a CA, server and client certs, users (via 'auth-user-pass.sh') and deletion of client certs and usernames from the local DBs
│           ├── server.conf -- OpenVPN Server configuration file
│           └── tls-verify.sh -- a script used for an additional TLS validation (it checks whether the Common Name in a client's cert exists in the local DB or it has been revoked)
├── docker-compose-test.yml -- a docker-compose file for running local tests
└── docker-compose.yml -- a docker-compose file for running OpenVPN Server
```

## Commands (shortcuts) for operating the VPN container

Run this command to see all available shortcuts

```
make help
```

### Initial Setup

1. Replace `remote` in `container-rootfs/etc/openvpn/client-config.template`

2. Build an image and start the container

```
make start
```

3. Wait for the VPN server to start up (wait for `Initialization Sequence Completed`)

```
make logs
```

### Create a client certificate

```
make exec
./openvpn_helper.sh --client-create-cert client-1 3650
```

### Create a user

```
make exec
./openvpn_helper.sh --client-create-user client-1@gmail.com
```

### Revoke a client certificate

```
make exec
./openvpn_helper.sh --client-delete-cert client-1
```

### Delete a user

```
make exec
./openvpn_helper.sh --client-delete-user client-1@gmail.com
```

## ToDo List

1. Make the setup configurable via env vars (a .env file for docker-compose)
2. Move common variables for scripts to one file
3. Use the DNS resolver on the VPN server
