#!/usr/bin/env bash
# =============================================================================
#  status.sh — Check what's running on the VM
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; RESET='\033[0m'

echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}${CYAN}  vm-ai-setup — Status${RESET}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""

# Ollama (off by default — everything runs on NVIDIA's hosted GPUs)
if [[ "${ENABLE_OLLAMA:-false}" != "true" ]]; then
  if command -v ollama &>/dev/null; then
    echo -e "  Ollama           ${YELLOW}○ disabled${RESET}  (still installed — run: make remove-ollama)"
  else
    echo -e "  Ollama           ${GREEN}● not installed${RESET}  (using NVIDIA hosted models)"
  fi
else
  if systemctl is-active --quiet ollama 2>/dev/null; then
    echo -e "  Ollama service   ${GREEN}● running${RESET}"
  else
    echo -e "  Ollama service   ${RED}✗ stopped${RESET}  →  run: sudo systemctl start ollama"
  fi
  echo ""
  echo -e "  ${BOLD}Loaded models:${RESET}"
  ollama list 2>/dev/null | tail -n +2 | while read -r line; do
    echo -e "    ${CYAN}→${RESET} $line"
  done
fi

# NVIDIA hosted GPU
echo ""
if [[ -n "${NVIDIA_API_KEY:-}" ]]; then
  echo -e "  NVIDIA hosted    ${GREEN}● enabled${RESET}  (${NVIDIA_MODEL:-?} + image gen)"
else
  echo -e "  NVIDIA hosted    ${YELLOW}○ disabled${RESET}  (set NVIDIA_API_KEY in config.env)"
fi

# Open WebUI
echo ""
if docker ps --filter "name=open-webui" --filter "status=running" | grep -q open-webui 2>/dev/null; then
  echo -e "  Open WebUI       ${GREEN}● running${RESET}  →  http://$(curl -s ifconfig.me 2>/dev/null):3000"
elif [[ "${ENABLE_WEBUI:-false}" == "true" ]]; then
  echo -e "  Open WebUI       ${RED}✗ stopped${RESET}  →  run: make webui"
else
  echo -e "  Open WebUI       ${YELLOW}○ disabled${RESET}  (set ENABLE_WEBUI=true to enable)"
fi

echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo ""
