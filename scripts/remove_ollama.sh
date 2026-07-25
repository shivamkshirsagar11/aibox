#!/usr/bin/env bash
# =============================================================================
#  remove_ollama.sh — Completely remove Ollama and all local models (runs ON VM)
#  Frees the RAM/disk Ollama used. The platform then runs purely on NVIDIA's
#  hosted GPUs. Also flips ENABLE_OLLAMA=false in config.env.
# =============================================================================

set -uo pipefail   # not -e: keep going even if a piece is already gone

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.env"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
info(){ echo -e "${CYAN}[INFO]${RESET}  $*"; }
ok(){ echo -e "${GREEN}[OK]${RESET}    $*"; }
warn(){ echo -e "${YELLOW}[WARN]${RESET}  $*"; }

echo -e "${BOLD}${CYAN}Removing Ollama from this VM...${RESET}"

info "Stopping and disabling the ollama service..."
sudo systemctl stop ollama 2>/dev/null || true
sudo systemctl disable ollama 2>/dev/null || true

info "Removing the systemd unit and our override..."
sudo rm -f /etc/systemd/system/ollama.service
sudo rm -rf /etc/systemd/system/ollama.service.d
sudo systemctl daemon-reload 2>/dev/null || true

info "Removing the ollama binary..."
sudo rm -f /usr/local/bin/ollama /usr/bin/ollama

info "Removing downloaded models (this frees the most disk)..."
sudo rm -rf /usr/share/ollama
rm -rf "$HOME/.ollama"

info "Removing the ollama user/group..."
sudo userdel ollama 2>/dev/null || true
sudo groupdel ollama 2>/dev/null || true

# Flip the flag in config.env so nothing tries to use Ollama again.
if [[ -f "$CONFIG" ]]; then
  if grep -q '^ENABLE_OLLAMA=' "$CONFIG"; then
    sed -i 's/^ENABLE_OLLAMA=.*/ENABLE_OLLAMA=false/' "$CONFIG"
  else
    sed -i '1i ENABLE_OLLAMA=false' "$CONFIG"
  fi
  ok "Set ENABLE_OLLAMA=false in config.env."
fi

echo ""
# Prove it's gone.
if command -v ollama >/dev/null 2>&1; then
  warn "'ollama' is still on PATH at $(command -v ollama) — remove it manually."
else
  ok "Verified: 'ollama' command is gone."
fi
if systemctl list-unit-files 2>/dev/null | grep -q '^ollama'; then
  warn "An ollama systemd unit still lingers — run: systemctl list-unit-files | grep ollama"
else
  ok "Verified: no ollama systemd service."
fi

echo ""
echo -e "${GREEN}${BOLD}Done. This VM no longer uses Ollama.${RESET}"
echo -e "Restart the web UI so it drops the Ollama connection:"
echo -e "  ${CYAN}make webui${RESET}"
