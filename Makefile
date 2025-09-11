SHELL := /bin/sh

# Tooling
# Formatting is enforced via SwiftLint rules (2-space indentation).
SWIFTLINT := swiftlint

# Configs
LINT_CONFIG := .swiftlint.yml

# Paths (shared)
SRC_PATHS := Sources Tests

.PHONY: lint lint-fix precommit tools


## Run SwiftLint (strict)
lint:
	@echo "[lint] Running SwiftLint (strict)"
	@$(SWIFTLINT) --no-cache --strict --config $(LINT_CONFIG)

## Attempt SwiftLint fixes where possible
lint-fix:
	@echo "[lint] Running SwiftLint --fix"
	@$(SWIFTLINT) --fix --config $(LINT_CONFIG) || true

## Convenience: lint-fix + lint
precommit: lint-fix lint
	@echo "[precommit] OK"

## Check tools are installed
tools:
	@command -v $(SWIFTLINT) >/dev/null 2>&1 || { echo "Install SwiftLint: brew install swiftlint"; exit 1; }
	@echo "[tools] OK"
