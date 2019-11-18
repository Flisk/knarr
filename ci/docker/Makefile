image := gitlab-registry.flisk.xyz/flisk/knarr/ci

.PHONY: default build push

default: build push

build:
	docker build -t $(image) .

push:
	docker push $(image)
