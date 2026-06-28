# =============================================================================
#  vm-ai-setup — Makefile
#  The only interface you need.
# =============================================================================

CONFIG := config.env
-include $(CONFIG)
export

SCRIPTS := scripts

.DEFAULT_GOAL := help

# ── Colors ───────────────────────────────────────────────────────────────────
CYAN  := \033[0;36m
GREEN := \033[0;32m
BOLD  := \033[1m
RESET := \033[0m

# ── Help ─────────────────────────────────────────────────────────────────────
.PHONY: help
help:
	@echo ""
	@echo "  $(BOLD)$(CYAN)vm-ai-setup$(RESET)  —  Run AI on your Oracle VM, use it from local machine"
	@echo ""
	@echo "  $(BOLD)SETUP (run these on your VM via SSH)$(RESET)"
	@echo "    make install        Install Ollama + pull model + setup WebUI"
	@echo "    make start          Start Ollama + WebUI"
	@echo "    make stop           Stop Ollama + WebUI"
	@echo "    make status         Show what's running on the VM"
	@echo "    make webui          (Re)start the Open WebUI chat interface"
	@echo ""
	@echo "  $(BOLD)MODEL$(RESET)"
	@echo "    make models         List all downloaded models"
	@echo "    make chat           Quick terminal chat with your model"
	@echo "    make update-model   Pull latest version of current model"
	@echo "    make switch-model   Change MODEL in config.env, then run this"
	@echo ""
	@echo "  $(BOLD)LOCAL MACHINE$(RESET)"
	@echo "    make tunnel         SSH tunnel — use Ollama at localhost:$(OLLAMA_PORT)"
	@echo ""
	@echo "  Edit $(BOLD)config.env$(RESET) to change model, VM IP, or options."
	@echo ""

# ── Install (run ON your VM) ─────────────────────────────────────────────────
.PHONY: install
install: _check_config
	@echo "$(CYAN)Running installer on this machine...$(RESET)"
	@chmod +x $(SCRIPTS)/install.sh
	@bash $(SCRIPTS)/install.sh

# ── Start everything ─────────────────────────────────────────────────────────
.PHONY: start
start: _check_config
	@echo "$(CYAN)Starting Ollama...$(RESET)"
	@sudo systemctl start ollama && echo "  Ollama started."
	@if docker ps -a --filter "name=open-webui" | grep -q open-webui; then \
		docker start open-webui && echo "  Open WebUI started."; \
	fi

# ── Stop everything ──────────────────────────────────────────────────────────
.PHONY: stop
stop:
	@echo "$(CYAN)Stopping Ollama...$(RESET)"
	@sudo systemctl stop ollama && echo "  Ollama stopped." || echo "  Ollama was not running."
	@echo "$(CYAN)Stopping Open WebUI...$(RESET)"
	@docker stop open-webui 2>/dev/null && echo "  Open WebUI stopped." || echo "  Open WebUI was not running."

# ── Status ───────────────────────────────────────────────────────────────────
.PHONY: status
status: _check_config
	@chmod +x $(SCRIPTS)/status.sh
	@bash $(SCRIPTS)/status.sh

# ── WebUI ────────────────────────────────────────────────────────────────────
.PHONY: webui
webui: _check_config
	@echo "$(CYAN)Starting Open WebUI...$(RESET)"
	@docker rm -f open-webui 2>/dev/null || true
	@docker run -d \
		--name open-webui \
		--restart always \
		-p 3000:8080 \
		--add-host=host.docker.internal:host-gateway \
		-e OLLAMA_BASE_URL="http://host.docker.internal:$(OLLAMA_PORT)" \
		-v open-webui:/app/backend/data \
		ghcr.io/open-webui/open-webui:main
	@echo "$(GREEN)Open WebUI started at http://$(shell curl -s ifconfig.me):3000$(RESET)"

# ── SSH Tunnel (run on LOCAL machine) ────────────────────────────────────────
.PHONY: tunnel
tunnel: _check_config _check_vm_ip
	@chmod +x $(SCRIPTS)/tunnel.sh
	@bash $(SCRIPTS)/tunnel.sh

# ── List downloaded models ───────────────────────────────────────────────────
.PHONY: models
models:
	@ollama list

# ── Quick terminal chat ───────────────────────────────────────────────────────
.PHONY: chat
chat: _check_config
	@ollama run $(MODEL)

# ── Update current model to latest version ───────────────────────────────────
.PHONY: update-model
update-model: _check_config
	@echo "$(CYAN)Pulling latest version of $(MODEL)...$(RESET)"
	@ollama pull $(MODEL)
	@echo "$(GREEN)Done! $(MODEL) is up to date.$(RESET)"

# ── Switch to a different model (change MODEL in config.env first) ────────────
.PHONY: switch-model
switch-model: _check_config
	@echo "$(CYAN)Pulling new model: $(MODEL)$(RESET)"
	@ollama pull $(MODEL)
	@echo "$(GREEN)Switched to $(MODEL). Run 'make chat' to try it.$(RESET)"

# ── Internal: config check ───────────────────────────────────────────────────
.PHONY: _check_config
_check_config:
	@if [ ! -f "$(CONFIG)" ]; then \
		echo "❌  config.env not found. Are you in the repo root?"; \
		exit 1; \
	fi

.PHONY: _check_vm_ip
_check_vm_ip:
	@if [ "$(VM_IP)" = "YOUR_VM_IP_HERE" ]; then \
		echo "❌  Please set VM_IP in config.env before running make tunnel."; \
		exit 1; \
	fi