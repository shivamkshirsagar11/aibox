#!/usr/bin/env bash
# =============================================================================
#  ask.sh — One-shot query to a BIG Nemotron model on NVIDIA's hosted GPUs
#  Runs from anywhere (VM or local). Needs NVIDIA_API_KEY in config.env.
#  Usage:  make ask PROMPT="explain quicksort in python"
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.env"
# shellcheck disable=SC1090
[[ -f "$CONFIG" ]] && source "$CONFIG"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; RESET='\033[0m'; BOLD='\033[1m'

if [[ -z "${NVIDIA_API_KEY:-}" ]]; then
  echo "❌  NVIDIA_API_KEY is not set in config.env."
  echo "    Get a free key at https://build.nvidia.com (starts with 'nvapi-')."
  exit 1
fi
command -v jq >/dev/null 2>&1 || { echo "❌  'jq' is required. Install it (apt install jq / brew install jq)."; exit 1; }

PROMPT="${PROMPT:-${*:-}}"
if [[ -z "$PROMPT" ]]; then
  echo "Usage: make ask PROMPT=\"your question\""
  exit 1
fi

echo -e "${CYAN}${BOLD}→ ${NVIDIA_MODEL}${RESET}  ${CYAN}(NVIDIA hosted GPU)${RESET}"
echo ""

BODY=$(jq -n \
  --arg model "$NVIDIA_MODEL" \
  --arg prompt "$PROMPT" \
  '{model: $model, messages: [{role: "user", content: $prompt}], temperature: 0.6, max_tokens: 1024, stream: false}')

RESP=$(curl -sS "${NVIDIA_BASE_URL}/chat/completions" \
  -H "Authorization: Bearer ${NVIDIA_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY")

# Surface API errors instead of printing "null"
if echo "$RESP" | jq -e '.error // .detail' >/dev/null 2>&1; then
  echo "❌  NVIDIA API error:"
  echo "$RESP" | jq -r '.error.message // .detail // .'
  exit 1
fi

echo "$RESP" | jq -r '.choices[0].message.content'
echo ""
echo -e "${GREEN}✓ done${RESET}"
