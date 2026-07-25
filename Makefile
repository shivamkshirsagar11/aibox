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
	@echo "  $(BOLD)LOCAL MODEL (Ollama on the VM CPU)$(RESET)"
	@echo "    make models         List all downloaded models"
	@echo "    make chat           Quick terminal chat with your local model"
	@echo "    make update-model   Pull latest version of current model"
	@echo "    make switch-model   Change MODEL in config.env, then run this"
	@echo ""
	@echo "  $(BOLD)NVIDIA HOSTED GPU (big Nemotron + image gen)$(RESET)"
	@echo "    make ask PROMPT=\"...\"     Ask a big Nemotron model on NVIDIA's GPUs"
	@echo "    make image PROMPT=\"...\"   Generate an image (FLUX/SDXL) on NVIDIA's GPUs"
	@echo "    make pipe               Show the Open WebUI image function to paste in"
	@echo ""
	@echo "  $(BOLD)CLEANUP$(RESET)"
	@echo "    make cleanup            Delete generated images older than CLEANUP_DAYS"
	@echo "    make cleanup-install    Install a daily cron that runs cleanup"
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
		-e ENABLE_SIGNUP=true \
		$(if $(NVIDIA_API_KEY),-e OPENAI_API_BASE_URL="$(NVIDIA_BASE_URL)" -e OPENAI_API_KEY="$(NVIDIA_API_KEY)" -e NVIDIA_API_KEY="$(NVIDIA_API_KEY)",) \
		-v open-webui:/app/backend/data \
		ghcr.io/open-webui/open-webui:main
	@echo "$(GREEN)Open WebUI started at http://$(shell curl -s ifconfig.me):3000$(RESET)"
	@if [ -n "$(NVIDIA_API_KEY)" ]; then \
		echo "$(GREEN)  NVIDIA hosted Nemotron models are now in the model picker.$(RESET)"; \
	fi
	@$(MAKE) --no-print-directory setup-webui

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

# ── Ask a BIG Nemotron model on NVIDIA's hosted GPUs ─────────────────────────
.PHONY: ask
ask: _check_config
	@chmod +x $(SCRIPTS)/ask.sh
	@bash $(SCRIPTS)/ask.sh "$(PROMPT)"

# ── Generate an image on NVIDIA's hosted GPUs (FLUX / SDXL) ───────────────────
.PHONY: image
image: _check_config
	@chmod +x $(SCRIPTS)/image.sh
	@bash $(SCRIPTS)/image.sh "$(PROMPT)"

# ── Auto-setup Open WebUI: create admin login + install image gen (no browser) ─
.PHONY: setup-webui
setup-webui: _check_config
	@chmod +x $(SCRIPTS)/setup_webui.sh
	@bash $(SCRIPTS)/setup_webui.sh

# ── Show the Open WebUI image-generation function (paste into Admin→Functions) ─
.PHONY: pipe
pipe:
	@echo "$(CYAN)Open WebUI image function → paste into: Admin Panel → Functions → + New$(RESET)"
	@echo "$(CYAN)File: openwebui/nvidia_image.py$(RESET)"
	@echo "$(GREEN)After saving + enabling, the FLUX/Qwen/SD models appear in the chat dropdown.$(RESET)"
	@command -v pbcopy >/dev/null 2>&1 && pbcopy < $(SCRIPTS)/../openwebui/nvidia_image.py && echo "$(GREEN)(copied to clipboard)$(RESET)" || true
	@echo ""
	@echo "----------------------------------------------------------------------"
	@cat openwebui/nvidia_image.py

# ── Delete generated images older than CLEANUP_DAYS (run now) ─────────────────
.PHONY: cleanup
cleanup: _check_config
	@chmod +x $(SCRIPTS)/cleanup.sh
	@bash $(SCRIPTS)/cleanup.sh

# ── Install a daily cron job that runs the cleanup automatically ──────────────
.PHONY: cleanup-install
cleanup-install: _check_config
	@REPO="$(CURDIR)"; \
	LINE="30 3 * * * cd $$REPO && bash scripts/cleanup.sh >> /tmp/aibox-cleanup.log 2>&1 # aibox-cleanup"; \
	( crontab -l 2>/dev/null | grep -v 'aibox-cleanup'; echo "$$LINE" ) | crontab - ; \
	echo "$(GREEN)Installed daily cleanup cron (03:30). Logs: /tmp/aibox-cleanup.log$(RESET)"; \
	echo "  View:   crontab -l"; \
	echo "  Remove: make cleanup-uninstall"

# ── Remove the daily cleanup cron job ────────────────────────────────────────
.PHONY: cleanup-uninstall
cleanup-uninstall:
	@( crontab -l 2>/dev/null | grep -v 'aibox-cleanup' ) | crontab - || true
	@echo "$(GREEN)Removed the aibox cleanup cron job.$(RESET)"

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