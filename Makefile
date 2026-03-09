.DEFAULT_GOAL:=help

.PHONY: generate
generate: clean ## Re-generate content
	@gennit -target docs

.PHONY: clean
clean: ## Clean up generated content
	@rm -fr docs

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-8s\033[0m %s\n", $$1, $$2}'

.PHONY: serve
serve: ## Serve generated content
	@gennit -target docs -serve
