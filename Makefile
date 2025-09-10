SHELL := /bin/sh

# Tooling
# Formatting is enforced via SwiftLint rules (2-space indentation).
SWIFTLINT := swiftlint

# Configs
LINT_CONFIG := .swiftlint.yml

# Paths (shared)
SRC_PATHS := Sources Tests

.PHONY: lint lint-fix precommit install-hooks tools


## Run SwiftLint (strict)
lint:
	@echo "[lint] Running SwiftLint (strict)"
	@$(SWIFTLINT) --no-cache --strict --config $(LINT_CONFIG)

## Attempt SwiftLint autocorrect where possible
lint-fix:
	@echo "[lint] Running SwiftLint autocorrect"
	@$(SWIFTLINT) autocorrect --config $(LINT_CONFIG) || true

## Convenience: lint-fix + lint
precommit: lint-fix lint
	@echo "[precommit] OK"

## Point git to use repo hooks (includes pre-commit format+lint)
install-hooks:
	@git config core.hooksPath .githooks
	@echo "[hooks] Installed: git will use .githooks/"

## Check tools are installed
tools:
	@command -v $(SWIFTLINT) >/dev/null 2>&1 || { echo "Install SwiftLint: brew install swiftlint"; exit 1; }
	@echo "[tools] OK"
