#!/usr/bin/env bash
# =============================================================================
#  install.sh — Runs ON your Oracle VM
#  Installs Ollama, pulls your chosen model, optionally sets up Open WebUI
# =============================================================================

set -euo pipefail

# ── Load config ──────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.env"

if [[ ! -f "$CONFIG" ]]; then
  echo "❌  config.env not found. Copy it from the repo root."
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG"

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERR]${RESET}   $*"; exit 1; }

# ── Banner ───────────────────────────────────────────────────────────────────
echo -e ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║         vm-ai-setup  installer           ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════╝${RESET}"
echo ""
info "Model   : $MODEL"
info "WebUI   : $ENABLE_WEBUI"
info "Port    : $OLLAMA_PORT"
echo ""

# ── Step 1: System update ─────────────────────────────────────────────────────
info "Updating system packages..."
sudo apt-get update -qq && sudo apt-get upgrade -y -qq
success "System updated."

# ── Step 2: Install Ollama ───────────────────────────────────────────────────
if command -v ollama &>/dev/null; then
  warn "Ollama already installed — skipping."
else
  info "Installing Ollama..."
  curl -fsSL https://ollama.ai/install.sh | sh
  success "Ollama installed."
fi

# ── Step 3: Configure Ollama to listen on 0.0.0.0 ───────────────────────────
info "Configuring Ollama service..."
sudo mkdir -p /etc/systemd/system/ollama.service.d
sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null <<EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0:${OLLAMA_PORT}"
EOF
sudo systemctl daemon-reload
sudo systemctl enable ollama
sudo systemctl restart ollama
success "Ollama service configured and started."

# ── Step 4: Open OS firewall for Ollama port ─────────────────────────────────
info "Opening port $OLLAMA_PORT in iptables..."
sudo iptables -I INPUT -p tcp --dport "$OLLAMA_PORT" -j ACCEPT 2>/dev/null || true

# Persist iptables rules across reboots
if command -v netfilter-persistent &>/dev/null; then
  sudo netfilter-persistent save
elif dpkg -l | grep -q iptables-persistent; then
  sudo sh -c 'iptables-save > /etc/iptables/rules.v4'
else
  warn "iptables-persistent not installed — rules will reset on reboot."
  warn "Run: sudo apt install iptables-persistent   to persist them."
fi

# ── Step 5: Pull the model ───────────────────────────────────────────────────
info "Pulling model: $MODEL  (this may take a few minutes...)"
ollama pull "$MODEL"
success "Model '$MODEL' ready."

# ── Step 6: Open WebUI (optional) ────────────────────────────────────────────
if [[ "${ENABLE_WEBUI:-false}" == "true" ]]; then
  if ! command -v docker &>/dev/null; then
    info "Docker not found — installing..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker "$USER"
    success "Docker installed."
  else
    warn "Docker already installed — skipping."
  fi

  info "Starting Open WebUI on port 3000..."
  sudo iptables -I INPUT -p tcp --dport 3000 -j ACCEPT 2>/dev/null || true

  # Remove old container if exists
  docker rm -f open-webui 2>/dev/null || true

  docker run -d \
    --name open-webui \
    --restart always \
    -p 3000:8080 \
    --add-host=host.docker.internal:host-gateway \
    -e OLLAMA_BASE_URL="http://host.docker.internal:${OLLAMA_PORT}" \
    -v open-webui:/app/backend/data \
    ghcr.io/open-webui/open-webui:main

  success "Open WebUI started. Visit: http://$(curl -s ifconfig.me):3000"
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}✅  All done!${RESET}"
echo ""
echo -e "  ${BOLD}Ollama API${RESET}  →  http://$(curl -s ifconfig.me):${OLLAMA_PORT}"
[[ "${ENABLE_WEBUI:-false}" == "true" ]] && \
echo -e "  ${BOLD}Chat UI${RESET}     →  http://$(curl -s ifconfig.me):3000"
echo ""
echo -e "  ${YELLOW}⚠️  IMPORTANT:${RESET} You must also open these ports in Oracle Cloud Console:"
echo -e "  Go to: VCN → Security Lists → Add Ingress Rules"
echo -e "  Add TCP port ${OLLAMA_PORT}  (and 3000 if WebUI enabled)"
echo ""
echo -e "  On your local machine, run:  ${CYAN}make tunnel${RESET}"
echo ""
