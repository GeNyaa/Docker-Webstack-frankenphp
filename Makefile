# Variables
PROJECTNAME=genyaa/webstack-frankenphp
TAG=UNDEF
PHP_VERSION=$(shell echo "$(TAG)" | sed -e 's/-.*//')

.PHONY: all
all: build start test stop clean

build:
	if [ "$(TAG)" = "UNDEF" ]; then echo "Please provide a valid TAG" && exit 1; fi
	docker build -t $(PROJECTNAME):$(TAG) --build-arg="BUILDPLATFORM=linux/amd64" -f $(TAG).Dockerfile --pull .; \

buildx-and-push:
	if [ "$(TAG)" = "UNDEF" ]; then echo "Please provide a valid TAG" && exit 1; fi
	docker buildx create --use
	docker buildx build --platform=linux/amd64,linux/arm64 -f $(TAG).Dockerfile -t $(PROJECTNAME):$(TAG) . --push; \
	docker buildx stop

start:
	if [ "$(TAG)" = "UNDEF" ]; then echo "please provide a valid TAG" && exit 1; fi
	docker run -d -p 8080:80 --name genyaa_webstack_instance $(PROJECTNAME):$(TAG); \

stop:
	docker stop -t0 genyaa_webstack_instance || true
	docker rm genyaa_webstack_instance || true

clean:
	if [ "$(TAG)" = "UNDEF" ]; then echo "please provide a valid TAG" && exit 1; fi
	rm -rf files/s6-overlay || true
	docker rmi $(PROJECTNAME):$(TAG) || true; \

shell:
	docker exec -ti genyaa_webstack_instance /bin/sh

logs:
	while true; do docker logs -f genyaa_webstack_instance; sleep 1; done