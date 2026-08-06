.PHONY: help run clean dev-up dev-down dev-exec dev-clobber

SHELL := /bin/bash

help:
	@echo "Available targets"
	@echo ""
	@echo "  run              Run the scraper via Docker Compose (memory-limited, matches production)"
	@echo "  clean            Remove this scraper's built production image"
	@echo ""
	@echo "  dev-up           Start the devcontainer, rebuilding first if its sources have changed"
	@echo "  dev-exec         Run COMMAND inside the running devcontainer (default: bash)"
	@echo "  dev-down         Stop the devcontainer"
	@echo "  dev-clobber      Remove devcontainer images and volumes - full reset"
	@echo ""
	@echo "Extra vars:"
	@echo "  COMMAND          Command for dev-exec to run, e.g. COMMAND=\"bundle update\" (default: bash)"

run:
	docker compose run --build --rm scraper

clean:
	docker compose down --rmi local

.make:
	mkdir -p .make

DEVCONTAINER_STAMP := .make/dev-down.stamp
DEVCONTAINER_SOURCES := .devcontainer/devcontainer.json
LOCKFILE := .devcontainer/devcontainer-lock.json

# Keeps the committed lockfile in sync with devcontainer.json.
$(LOCKFILE): .devcontainer/devcontainer.json
	devcontainer upgrade --workspace-folder .

dev-up: $(DEVCONTAINER_STAMP) $(LOCKFILE)
	devcontainer up --workspace-folder .

# If devcontainer.json has changed since the last dev-down, stop the
# container first so dev-up rebuilds against the current sources instead
# of running stale.
$(DEVCONTAINER_STAMP): $(DEVCONTAINER_SOURCES) | .make
	$(MAKE) dev-down

dev-down: | .make
	docker compose -f .devcontainer/compose.yaml down
	touch $(DEVCONTAINER_STAMP)

COMMAND ?= bash

dev-exec:
	devcontainer exec --workspace-folder . $(COMMAND)

dev-clobber:
	docker compose -f .devcontainer/compose.yaml down --rmi all --volumes --remove-orphans
	rm -rf .make
