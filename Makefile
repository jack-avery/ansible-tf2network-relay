.PHONY: all build

all: build

build:
	nix build '.#packages.x86_64-linux.x86_64-linux.image'
	docker load -i result
	nix build '.#packages.x86_64-linux.aarch64-linux.image'
	docker load -i result

push:
	docker push jackavery/ansible-tf2network-relay:latest-x86_64
	docker push jackavery/ansible-tf2network-relay:latest-aarch64
	docker manifest create --amend jackavery/ansible-tf2network-relay:latest \
		jackavery/ansible-tf2network-relay:latest-x86_64 \
		jackavery/ansible-tf2network-relay:latest-aarch64
	docker manifest push jackavery/ansible-tf2network-relay:latest
