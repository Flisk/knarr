image := gitlab-registry.flisk.xyz/flisk/knarr/ci
from := elixir:1.10-slim

.PHONY: default build push

default: build push

build:
	docker build --build-arg=from=$(from) --tag=$(image) .

push:
	docker push $(image)
