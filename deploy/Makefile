tag ?= 1.0.0

.PHONY: help build_image push_image build_image_and_push

help: ## Display this help message.
	@echo "Please use \`make <target>\` where <target> is one of"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; \
	{printf "\033[36m%-40s\033[0m %s\n", $$1, $$2}'

build_image: ## Builds this project's docker image with the image's host referenced by `image_host` option.
	docker build --build-arg BUILDKIT_INLINE_CACHE=1 -t ajharry69/interintel:$(tag) .

push_image: ## Pushes this project's image(s) to host referenced by `image_host` option.
	docker push ajharry69/interintel:$(tag)

build_image_and_push: build_image push_image ## Builds and pushes this project's image(s) to host referenced by `image_host` option.
