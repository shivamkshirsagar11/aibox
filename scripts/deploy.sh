#!/usr/bin/env bash
# =============================================================================
#  deploy.sh — Runs on YOUR LOCAL MACHINE (macOS). One command to update the VM.
#  Reads VM_IP / SSH_USER / SSH_KEY from config.env, then:
#    1. syncs the VM's repo to the latest main (config.env is preserved)
#    2. uploads your local config.env (real key + login)
#    3. runs the update on the VM (default: make install && make remove-ollama)
#  Override the remote step:  make deploy REMOTE="make webui"
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.env"
REPO_URL="https://github.com/shivamkshirsagar11/aibox.git"
REMOTE_DIR="aibox"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'
step(){ echo -e "\n${CYAN}${BOLD}▶ $*${RESET}"; }
die(){ echo -e "${RED}❌  $*${RESET}"; exit 1; }

[[ -f "$CONFIG" ]] || die "config.env not found."
# shellcheck disable=SC1090
source "$CONFIG"

# What to run on the VM (overridable: make deploy REMOTE="make status")
REMOTE_CMD="${REMOTE:-make install && make remove-ollama}"

# Validate connection settings
[[ "${VM_IP:-}" && "$VM_IP" != "YOUR_VM_IP_HERE" ]] || die "Set VM_IP in config.env."
[[ -n "${SSH_KEY:-}" ]] || die "Set SSH_KEY in config.env."
SSH_KEY="${SSH_KEY/#\~/$HOME}"          # expand a leading ~
[[ -f "$SSH_KEY" ]] || die "SSH key not found: $SSH_KEY"
SSH_USER="${SSH_USER:-ubuntu}"

SSH_OPTS=(-o StrictHostKeyChecking=accept-new -i "$SSH_KEY")
HOST="${SSH_USER}@${VM_IP}"

echo -e "${BOLD}${CYAN}Deploying to ${HOST}${RESET}"
echo -e "  remote step: ${BOLD}${REMOTE_CMD}${RESET}"

step "1/3  Syncing code on the VM to latest main"
ssh "${SSH_OPTS[@]}" "$HOST" \
  "test -d ~/$REMOTE_DIR || git clone $REPO_URL ~/$REMOTE_DIR; \
   cd ~/$REMOTE_DIR && git fetch origin && git reset --hard origin/main" \
  || die "Could not reach the VM or update the repo. Check VM_IP / SSH_KEY / that the VM is up."
echo -e "${GREEN}  ✓ code updated${RESET}"

step "2/3  Uploading your config.env"
scp "${SSH_OPTS[@]}" "$CONFIG" "$HOST:~/$REMOTE_DIR/config.env"
echo -e "${GREEN}  ✓ config uploaded${RESET}"

step "3/3  Running on the VM:  $REMOTE_CMD"
echo -e "${YELLOW}  (this can take a few minutes — apt upgrade, docker, model image)${RESET}\n"
ssh -t "${SSH_OPTS[@]}" "$HOST" "cd ~/$REMOTE_DIR && $REMOTE_CMD"

echo ""
echo -e "${GREEN}${BOLD}✅  Done.${RESET}  Open ${BOLD}http://${VM_IP}:${WEBUI_PORT:-3000}${RESET} and log in."
