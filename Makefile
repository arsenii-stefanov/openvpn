### Common variables
vpn_compose_file:="docker-compose.yml"
vpn_compose_svc_name:="openvpn"


vpn_compose_file_test:="docker-compose-test.yml"
vpn_srv_compose_svc_name_test:="openvpn_server"
vpn_client_compose_svc_name_test:="openvpn_client"

.DEFAULT_GOAL:=help

define vpn_compose
  docker compose -f $(vpn_compose_file) ${1}
endef

define vpn_compose_test
  docker compose -f $(vpn_compose_file_test) ${1}
endef

.PHONY: build start stop restart logs exec connect test-build test-start test-stop test-logs test-client-create-cert test-client-create-user test-client-delete-cert test-client-delete-user test-connection

help: ## Displays help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ OpenVPN Server

build: ## Build a container image
	$(call vpn_compose,build)

build-no-cache:  ## Build a container image without using layers cached previously
	$(call vpn_compose,build --no-cache)

start:  ## docker-compose up
	$(call vpn_compose,up -d)

stop:  ## docker-compose down
	$(call vpn_compose,down)

restart:  ## docker-compose down && docker-compose up
	make stop && make start

logs:  ## Tail container logs (all containers in the docker-compose file)
	$(call vpn_compose,logs -f)

exec:  ## Enter the container's shell
	$(call vpn_compose,exec $(vpn_compose_svc_name) bash)

##@ OpenVPN tests

test-build: ### Build a test container image
	$(call vpn_compose_test,build)

test-build-no-cache: ### Build a test container image without using layers cached previously
	$(call vpn_compose_test,build --no-cache)

test-start:  ## docker-compose up
	$(call vpn_compose_test,up -d)

test-stop:  ## docker-compose down (all images built locally and volumes will be removed)
	$(call vpn_compose_test,down --rmi local -v)

test-logs:  ## Tail container logs (all containers in the docker-compose file)
	$(call vpn_compose_test,logs -f)

test-exec-server:  ## Enter the server container's shell
	$(call vpn_compose_test,exec $(vpn_srv_compose_svc_name_test) bash)

test-exec-client:  ## Enter the client container's shell
	$(call vpn_compose_test,exec $(vpn_client_compose_svc_name_test) bash)

test-client-create-cert:  ## Test generation of a certificate for an OpenVPN test client
	$(call vpn_compose_test,exec $(vpn_srv_compose_svc_name_test) ./openvpn_helper.sh --client-create-cert test-user 3650)

test-client-create-user:  ## Test creation of an OpenVPN client (username and password)
	$(call vpn_compose_test,exec $(vpn_srv_compose_svc_name_test) ./openvpn_helper.sh --client-create-user test-user@gmail.com)

test-client-delete-cert:  ## Test deletion of a client certificate
	$(call vpn_compose_test,exec $(vpn_srv_compose_svc_name_test) ./openvpn_helper.sh --client-delete-cert test-user)

test-client-delete-user:  ## Test deletion of a client
	$(call vpn_compose_test,exec $(vpn_srv_compose_svc_name_test) ./openvpn_helper.sh --client-delete-user test-user@gmail.com)

test-connection:  ## Test connection to a test OpenVPN server
	$(call vpn_compose_test,exec $(vpn_srv_compose_svc_name_test) openvpn --config /etc/openvpn/client/config/test-user.ovpn)

test-full-stage-one:  ## Build test images, start test containers and show container logs (wait for all startup scripts to complete execution)
	make test-stop && make test-build && make test-start && make test-logs

test-full-stage-two:  ## Create a cert and a user, then test try to establish a coonection with the test server
	make test-client-create-cert && make test-client-create-user && make test-connection

test-full-stage-three:  ## Test deletion of the certificate and the user and clean up everything
	make test-client-delete-cert && make test-client-delete-user && make test-stop
