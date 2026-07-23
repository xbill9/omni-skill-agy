# Omni Flash video agent — build, test, and skill-packaging targets

SKILL_NAME := omni-video
SKILL_DIR  := .gemini/skills/$(SKILL_NAME)
PLUGIN_DIR := skills/$(SKILL_NAME)
DIST_DIR   := dist
IMAGE      := xbill9/omni-video-agent
VERSION    := 0.1.0

.PHONY: all help install run test lint clean skill skill-install skill-package init docker-build docker-push

all: help

help:
	@echo "========================================================="
	@echo " Omni Flash Video Agent - Makefile"
	@echo "========================================================="
	@echo "Available commands:"
	@echo "  make install       - Install Python requirements"
	@echo "  make run           - Start the FastMCP server (server.py)"
	@echo "  make test          - Run the agent integration tests"
	@echo "  make lint          - ruff on the Python sources, bash -n on the shell scripts"
	@echo "  make clean         - Remove Python caches"
	@echo "  make skill         - Refresh $(SKILL_NAME) skill snapshots from the root sources"
	@echo "                       (mcp/ snapshot, $(SKILL_DIR), plugin copy in skills/)"
	@echo "  make skill-install - Refresh + copy the skill to ~/.gemini/skills (all projects)"
	@echo "  make skill-package - Refresh + build $(DIST_DIR)/$(SKILL_NAME)-skill.zip"
	@echo "  make init TARGET=/path/to/project [ARGS='--model <name>']"
	@echo "                     - Refresh + install skill AND register the omni-video-agent MCP"
	@echo "                       server in TARGET (or globally with ARGS='--global')"
	@echo "  make docker-build  - Build the $(IMAGE) image ($(VERSION) + latest)"
	@echo "  make docker-push   - Build + push both tags to Docker Hub"
	@echo "========================================================="

install:
	pip install -r requirements.txt

run:
	python server.py

test:
	python test_agent.py

# Lint the repo-root sources (mcp/, .gemini/skills/ and skills/ hold generated
# copies — lint the sources, not the copies).
lint:
	@command -v ruff >/dev/null || { echo "ruff not found; install with: pip install ruff"; exit 1; }
	ruff check server.py test_agent.py refresh_skill.py
	ruff format --check server.py test_agent.py refresh_skill.py
	@for s in project-setup.sh init.sh set_env.sh mcp/project-setup.sh; do bash -n $$s || exit 1; done
	@echo "lint OK"

clean:
	rm -rf .ruff_cache .mypy_cache
	find . -type d -name "__pycache__" -exec rm -rf {} +

skill:
	python3 refresh_skill.py
	rm -rf $(PLUGIN_DIR)
	mkdir -p $(dir $(PLUGIN_DIR))
	cp -r $(SKILL_DIR) $(PLUGIN_DIR)
	@echo "Synced plugin copy -> $(PLUGIN_DIR)"

skill-install: skill
	mkdir -p $(HOME)/.gemini/skills
	rm -rf $(HOME)/.gemini/skills/$(SKILL_NAME)
	cp -r $(SKILL_DIR) $(HOME)/.gemini/skills/$(SKILL_NAME)
	@echo "Installed to $(HOME)/.gemini/skills/$(SKILL_NAME)"

skill-package: skill
	mkdir -p $(DIST_DIR)
	rm -f $(DIST_DIR)/$(SKILL_NAME)-skill.zip
	cd $(dir $(SKILL_DIR)) && zip -qr $(CURDIR)/$(DIST_DIR)/$(SKILL_NAME)-skill.zip $(notdir $(SKILL_DIR))
	@echo "Packaged $(DIST_DIR)/$(SKILL_NAME)-skill.zip"
	@unzip -l $(DIST_DIR)/$(SKILL_NAME)-skill.zip

# The image contains only server.py + requirements (see .dockerignore — key
# files can never enter the build context). Bump VERSION with plugin.json.
docker-build:
	docker build -t $(IMAGE):$(VERSION) -t $(IMAGE):latest .

docker-push: docker-build
	docker push $(IMAGE):$(VERSION)
	docker push $(IMAGE):latest

init: skill
	@if [ -z "$(TARGET)" ] && ! echo "$(ARGS)" | grep -q -- --global; then \
		echo "usage: make init TARGET=/path/to/project [ARGS='--model <name> ...']"; \
		echo "   or: make init ARGS='--global ...'"; \
		exit 1; \
	fi
	./project-setup.sh $(TARGET) $(ARGS)
