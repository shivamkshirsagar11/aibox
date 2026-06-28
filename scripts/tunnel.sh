#!/usr/bin/env bash
# =============================================================================
#  tunnel.sh — Runs on YOUR LOCAL MACHINE
#  Forwards VM's Ollama port to localhost:11434 via SSH tunnel
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.env"

if [[ ! -f "$CONFIG" ]]; then
  echo "❌  config.env not found."
  exit 1
fi

# shellcheck disable=SC1090
source "$CONFIG"

CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'; GREEN='\033[0;32m'

if [[ "$VM_IP" == "YOUR_VM_IP_HERE" ]]; then
  echo "❌  Please set VM_IP in config.env first."
  exit 1
fi

echo ""
echo -e "${BOLD}${CYAN}🔗  Starting SSH tunnel to $SSH_USER@$VM_IP${RESET}"
echo ""
echo -e "  Ollama will be available at: ${GREEN}http://localhost:${OLLAMA_PORT}${RESET}"
echo ""
echo -e "  Press ${BOLD}Ctrl+C${RESET} to stop the tunnel."
echo ""

ssh -N -L "${OLLAMA_PORT}:localhost:${OLLAMA_PORT}" "${SSH_USER}@${VM_IP}"
