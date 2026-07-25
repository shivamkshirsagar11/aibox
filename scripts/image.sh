#!/usr/bin/env bash
# =============================================================================
#  image.sh — Generate an image on NVIDIA's hosted GPUs (FLUX / SDXL)
#  Your 12GB CPU VM can't do this quickly, so we offload to NVIDIA's GPUs.
#  Needs NVIDIA_API_KEY in config.env.
#  Usage:  make image PROMPT="a red panda coding on a laptop, studio lighting"
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.env"
# shellcheck disable=SC1090
[[ -f "$CONFIG" ]] && source "$CONFIG"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'

if [[ -z "${NVIDIA_API_KEY:-}" ]]; then
  echo "❌  NVIDIA_API_KEY is not set in config.env."
  echo "    Get a free key at https://build.nvidia.com (starts with 'nvapi-')."
  exit 1
fi
command -v jq >/dev/null 2>&1 || { echo "❌  'jq' is required. Install it (apt install jq / brew install jq)."; exit 1; }

PROMPT="${PROMPT:-${*:-}}"
if [[ -z "$PROMPT" ]]; then
  echo "Usage: make image PROMPT=\"your description\""
  exit 1
fi

IMAGE_MODEL="${IMAGE_MODEL:-black-forest-labs/flux.1-schnell}"
IMAGE_API_URL="${IMAGE_API_URL:-https://ai.api.nvidia.com/v1/genai}"
OUT_DIR="${IMAGE_OUT_DIR:-./images}"
mkdir -p "$OUT_DIR"
OUT_FILE="$OUT_DIR/img_$(date +%Y%m%d_%H%M%S).png"

echo -e "${CYAN}${BOLD}→ ${IMAGE_MODEL}${RESET}  ${CYAN}(NVIDIA hosted GPU)${RESET}"
echo -e "  prompt: ${BOLD}${PROMPT}${RESET}"
echo ""

BODY=$(jq -n \
  --arg prompt "$PROMPT" \
  '{prompt: $prompt, width: 1024, height: 1024, steps: 4, seed: 0, cfg_scale: 3.5}')

RESP=$(curl -sS "${IMAGE_API_URL}/${IMAGE_MODEL}" \
  -H "Authorization: Bearer ${NVIDIA_API_KEY}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -d "$BODY")

# Surface API errors clearly
if echo "$RESP" | jq -e '.error // .detail // .title' >/dev/null 2>&1; then
  echo "❌  NVIDIA image API error:"
  echo "$RESP" | jq -r '.error.message // .detail // .title // .'
  exit 1
fi

# Different NVIDIA image models return the base64 in different fields.
# Try the known shapes: .artifacts[0].base64, .image, .data[0].b64_json
B64=$(echo "$RESP" | jq -r '
  .artifacts[0].base64
  // .image
  // .data[0].b64_json
  // empty')

if [[ -z "$B64" ]]; then
  echo "❌  Could not find image data in the response. Raw response:"
  echo "$RESP" | head -c 800
  echo ""
  exit 1
fi

# Strip a possible data-URI prefix, then decode
B64="${B64#data:image/*;base64,}"
if base64 --help 2>&1 | grep -q -- '-d'; then
  echo "$B64" | base64 -d > "$OUT_FILE"      # GNU / Linux
else
  echo "$B64" | base64 -D > "$OUT_FILE"      # BSD / macOS
fi

echo -e "${GREEN}✓ saved:${RESET} ${BOLD}${OUT_FILE}${RESET}"

# Offer to open it on macOS / Linux desktop
if command -v open >/dev/null 2>&1; then open "$OUT_FILE"
elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$OUT_FILE" >/dev/null 2>&1 || true
else echo -e "  ${YELLOW}(on a headless VM — scp it down or view via WebUI)${RESET}"; fi
