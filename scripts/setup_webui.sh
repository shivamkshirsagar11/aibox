#!/usr/bin/env bash
# =============================================================================
#  setup_webui.sh — Make Open WebUI turnkey (runs ON the VM after WebUI starts)
#  - Creates the admin account from config.env (first user = admin)
#  - Installs + enables the NVIDIA image-generation function
#  So there is ZERO browser setup: just log in and chat.
#  Safe to re-run; never fails the install (falls back to manual instructions).
# =============================================================================

set -uo pipefail   # not -e: this script must never abort `make install`

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.env"
FUNC_FILE="$SCRIPT_DIR/../openwebui/nvidia_image.py"
# shellcheck disable=SC1090
[[ -f "$CONFIG" ]] && source "$CONFIG"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'
info(){ echo -e "${CYAN}[webui]${RESET} $*"; }
ok(){ echo -e "${GREEN}[webui]${RESET} $*"; }
warn(){ echo -e "${YELLOW}[webui]${RESET} $*"; }

BASE="http://localhost:${WEBUI_PORT:-3000}"
FUNC_ID="nvidia_image"

manual_hint() {
  warn "Couldn't auto-install the image function. It's a 30-second manual step:"
  warn "  1. run 'make pipe'  2. Open WebUI -> Admin -> Functions -> + New"
  warn "  3. paste, Save, toggle ON."
}

command -v jq >/dev/null 2>&1 || { warn "jq not found — skipping WebUI auto-setup."; manual_hint; exit 0; }
[[ -f "$FUNC_FILE" ]] || { warn "function file missing — skipping."; exit 0; }

# ── Wait for Open WebUI to answer ────────────────────────────────────────────
info "Waiting for Open WebUI at $BASE ..."
for i in $(seq 1 40); do
  curl -sf "$BASE/health" >/dev/null 2>&1 && break
  sleep 3
  [[ $i -eq 40 ]] && { warn "Open WebUI didn't come up in time — skipping auto-setup."; manual_hint; exit 0; }
done
ok "Open WebUI is up."

# ── Need admin credentials to use the API ────────────────────────────────────
if [[ -z "${WEBUI_EMAIL:-}" || -z "${WEBUI_PASSWORD:-}" ]]; then
  warn "WEBUI_EMAIL / WEBUI_PASSWORD not set in config.env — skipping auto-setup."
  warn "Set them to auto-create your admin account + install image gen."
  manual_hint
  exit 0
fi

# ── Sign up (first user = admin) or sign in if the account already exists ────
signup_body=$(jq -n --arg n "${WEBUI_NAME:-Admin}" --arg e "$WEBUI_EMAIL" --arg p "$WEBUI_PASSWORD" \
  '{name:$n, email:$e, password:$p}')
RESP=$(curl -sS -X POST "$BASE/api/v1/auths/signup" -H "Content-Type: application/json" -d "$signup_body")
TOKEN=$(echo "$RESP" | jq -r '.token // empty')

if [[ -n "$TOKEN" ]]; then
  ok "Created admin account: $WEBUI_EMAIL"
else
  # already exists → sign in
  signin_body=$(jq -n --arg e "$WEBUI_EMAIL" --arg p "$WEBUI_PASSWORD" '{email:$e, password:$p}')
  RESP=$(curl -sS -X POST "$BASE/api/v1/auths/signin" -H "Content-Type: application/json" -d "$signin_body")
  TOKEN=$(echo "$RESP" | jq -r '.token // empty')
  if [[ -n "$TOKEN" ]]; then
    ok "Signed in as existing admin: $WEBUI_EMAIL"
  else
    warn "Could not sign up or sign in ($(echo "$RESP" | jq -r '.detail // "unknown error"'))."
    manual_hint
    exit 0
  fi
fi

AUTH=(-H "Authorization: Bearer $TOKEN")

# ── Create (or update) the image-generation function ─────────────────────────
body=$(jq -n --arg id "$FUNC_ID" --arg name "NVIDIA Image Generation" \
  --rawfile content "$FUNC_FILE" \
  '{id:$id, name:$name, content:$content,
    meta:{description:"Generate images on NVIDIA GPUs, inline in chat.", manifest:{}}}')

CREATE=$(curl -sS -X POST "$BASE/api/v1/functions/create" "${AUTH[@]}" \
  -H "Content-Type: application/json" -d "$body")

if echo "$CREATE" | jq -e '.id' >/dev/null 2>&1; then
  ok "Installed image function."
else
  # likely already exists → update it in place
  UPD=$(curl -sS -X POST "$BASE/api/v1/functions/id/$FUNC_ID/update" "${AUTH[@]}" \
    -H "Content-Type: application/json" -d "$body")
  if echo "$UPD" | jq -e '.id' >/dev/null 2>&1; then
    ok "Updated existing image function."
  else
    warn "Function create/update failed ($(echo "$CREATE" | jq -r '.detail // .'))."
    manual_hint
    exit 0
  fi
fi

# ── Ensure it's enabled (toggle only if currently inactive) ──────────────────
ACTIVE=$(curl -sS "${AUTH[@]}" "$BASE/api/v1/functions/id/$FUNC_ID" | jq -r '.is_active // false')
if [[ "$ACTIVE" != "true" ]]; then
  curl -sS -X POST "$BASE/api/v1/functions/id/$FUNC_ID/toggle" "${AUTH[@]}" >/dev/null 2>&1
fi
ok "Image models are now enabled in the chat model dropdown."
echo ""
ok "${BOLD}Done — open $BASE, log in, and pick a 🎨 model to generate images.${RESET}"
