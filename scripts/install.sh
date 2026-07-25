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

# jq is used by 'make ask' and 'make image' to talk to NVIDIA's hosted API.
if ! command -v jq &>/dev/null; then
  info "Installing jq..."
  sudo apt-get install -y -qq jq && success "jq installed."
fi

# Guard: with Ollama off, NVIDIA is the only model source — a key is required.
if [[ "${ENABLE_OLLAMA:-false}" != "true" && -z "${NVIDIA_API_KEY:-}" ]]; then
  error "ENABLE_OLLAMA=false but NVIDIA_API_KEY is empty — there'd be no models. Set a key or enable Ollama."
fi

if [[ "${ENABLE_OLLAMA:-false}" == "true" ]]; then
  # ── Install Ollama ─────────────────────────────────────────────────────────
  if command -v ollama &>/dev/null; then
    warn "Ollama already installed — skipping."
  else
    info "Installing Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
    success "Ollama installed."
  fi

  # ── Configure Ollama to listen on 0.0.0.0 ──────────────────────────────────
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

  # ── Open OS firewall for Ollama port ───────────────────────────────────────
  info "Opening port $OLLAMA_PORT in iptables..."
  sudo iptables -I INPUT -p tcp --dport "$OLLAMA_PORT" -j ACCEPT 2>/dev/null || true
  if command -v netfilter-persistent &>/dev/null; then
    sudo netfilter-persistent save
  elif dpkg -l | grep -q iptables-persistent; then
    sudo sh -c 'iptables-save > /etc/iptables/rules.v4'
  else
    warn "iptables-persistent not installed — Ollama port rule resets on reboot."
  fi

  # ── Pull the model ─────────────────────────────────────────────────────────
  info "Pulling model: $MODEL  (this may take a few minutes...)"
  ollama pull "$MODEL"
  success "Model '$MODEL' ready."
else
  info "Ollama disabled (ENABLE_OLLAMA=false) — all models run on NVIDIA's hosted GPUs."
fi

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

  # If an NVIDIA key is set, add hosted Nemotron models to the WebUI picker.
  NVIDIA_ARGS=()
  if [[ -n "${NVIDIA_API_KEY:-}" ]]; then
    NVIDIA_ARGS=(-e OPENAI_API_BASE_URL="${NVIDIA_BASE_URL}" \
                 -e OPENAI_API_KEY="${NVIDIA_API_KEY}" \
                 -e NVIDIA_API_KEY="${NVIDIA_API_KEY}")
    info "NVIDIA key detected — hosted Nemotron models will appear in the WebUI."
  fi

  # Connect to Ollama only if it's enabled; otherwise disable it in the UI.
  if [[ "${ENABLE_OLLAMA:-false}" == "true" ]]; then
    OLLAMA_ARGS=(-e OLLAMA_BASE_URL="http://host.docker.internal:${OLLAMA_PORT}")
  else
    OLLAMA_ARGS=(-e ENABLE_OLLAMA_API=false)
  fi

  docker run -d \
    --name open-webui \
    --restart always \
    -p 3000:8080 \
    --add-host=host.docker.internal:host-gateway \
    "${OLLAMA_ARGS[@]}" \
    -e ENABLE_SIGNUP=true \
    "${NVIDIA_ARGS[@]}" \
    -v open-webui:/app/backend/data \
    ghcr.io/open-webui/open-webui:main

  success "Open WebUI started. Visit: http://$(curl -s ifconfig.me):3000"

  # Turnkey: create the admin login + install image generation (no browser setup)
  info "Configuring Open WebUI (admin account + image generation)..."
  bash "$SCRIPT_DIR/setup_webui.sh" || warn "WebUI auto-setup skipped — see 'make pipe'."
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
if [[ -n "${NVIDIA_API_KEY:-}" ]]; then
  echo -e "  ${BOLD}NVIDIA hosted GPU is enabled.${RESET} Try:"
  echo -e "    ${CYAN}make ask   PROMPT=\"write a haiku about oracle cloud\"${RESET}"
  echo -e "    ${CYAN}make image PROMPT=\"a red panda hacking on a laptop\"${RESET}"
  echo ""
  echo -e "  ${BOLD}Your chat site is ready.${RESET} Open it, log in with WEBUI_EMAIL /"
  echo -e "  WEBUI_PASSWORD from config.env, and pick a 🎨 model to generate images."
  echo -e "  (If auto-setup was skipped, run ${CYAN}make setup-webui${RESET}.)"
  echo -e "  Optional: ${CYAN}make cleanup-install${RESET} for a daily image cleanup cron."
  echo ""
else
  echo -e "  ${YELLOW}Tip:${RESET} add a free key from ${BOLD}https://build.nvidia.com${RESET} to"
  echo -e "       config.env (NVIDIA_API_KEY) to unlock big Nemotron models + image gen."
  echo ""
fi
