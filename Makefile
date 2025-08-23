# OpenAPI tooling with native Spectral CLI
# Requires bun, pnpm, or npx to be available

OPENAPI_DIR ?= openapi
RULESET ?= spectral.yaml

.PHONY: lint-openapi lint-openapi-all

lint-openapi:
	@echo "Linting $(OPENAPI_DIR)/main.yaml with Spectral..."
	@if command -v bun >/dev/null 2>&1; then \
		bun x @stoplight/spectral-cli lint $(OPENAPI_DIR)/main.yaml -r $(RULESET) --fail-severity=error; \
	elif command -v pnpm >/dev/null 2>&1; then \
		pnpm dlx @stoplight/spectral-cli lint $(OPENAPI_DIR)/main.yaml -r $(RULESET) --fail-severity=error; \
	elif command -v npx >/dev/null 2>&1; then \
		npx @stoplight/spectral-cli lint $(OPENAPI_DIR)/main.yaml -r $(RULESET) --fail-severity=error; \
	else \
		echo "Error: No package manager found. Please install bun, pnpm, or npm."; \
		exit 1; \
	fi

lint-openapi-all:
	@echo "Linting all OpenAPI YAML files under $(OPENAPI_DIR)/ ..."
	@if command -v bun >/dev/null 2>&1; then \
		bun x @stoplight/spectral-cli lint "$(OPENAPI_DIR)/**/*.yaml" -r $(RULESET) --fail-severity=error; \
	elif command -v pnpm >/dev/null 2>&1; then \
		pnpm dlx @stoplight/spectral-cli lint "$(OPENAPI_DIR)/**/*.yaml" -r $(RULESET) --fail-severity=error; \
	elif command -v npx >/dev/null 2>&1; then \
		npx @stoplight/spectral-cli lint "$(OPENAPI_DIR)/**/*.yaml" -r $(RULESET) --fail-severity=error; \
	else \
		echo "Error: No package manager found. Please install bun, pnpm, or npm."; \
		exit 1; \
	fi
