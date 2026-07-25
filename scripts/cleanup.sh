#!/usr/bin/env bash
# =============================================================================
#  cleanup.sh — Delete generated images older than CLEANUP_DAYS.
#  Cleans BOTH:
#    1. the CLI output dir (IMAGE_OUT_DIR, e.g. ./images)
#    2. Open WebUI's in-container generated images (via docker exec)
#  Run manually with `make cleanup`, or install a daily cron with
#  `make cleanup-install`.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/../config.env"
# shellcheck disable=SC1090
[[ -f "$CONFIG" ]] && source "$CONFIG"

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RESET='\033[0m'; BOLD='\033[1m'

DAYS="${CLEANUP_DAYS:-1}"
OUT_DIR="${IMAGE_OUT_DIR:-$SCRIPT_DIR/../images}"

echo -e "${CYAN}${BOLD}Cleanup — removing generated images older than ${DAYS} day(s)${RESET}"

# ── 1. Local CLI output directory ────────────────────────────────────────────
if [[ -d "$OUT_DIR" ]]; then
  n=$(find "$OUT_DIR" -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.tmp' \) -mtime +"$DAYS" | wc -l | tr -d ' ')
  find "$OUT_DIR" -type f \( -name '*.jpg' -o -name '*.png' -o -name '*.tmp' \) -mtime +"$DAYS" -delete
  echo -e "  ${GREEN}✓${RESET} $OUT_DIR: removed $n file(s)"
else
  echo -e "  ${YELLOW}○${RESET} $OUT_DIR not found — skipping"
fi

# ── 2. Open WebUI container (only images it generated) ───────────────────────
# Restrict to *generated-image* so we never touch users' uploaded RAG docs.
if command -v docker >/dev/null 2>&1 && docker ps --filter "name=open-webui" --filter "status=running" 2>/dev/null | grep -q open-webui; then
  for d in /app/backend/data/uploads /app/backend/data/cache/image/generations; do
    docker exec open-webui sh -c \
      "[ -d '$d' ] && find '$d' -type f -name '*generated-image*' -mtime +$DAYS -delete" 2>/dev/null || true
  done
  echo -e "  ${GREEN}✓${RESET} open-webui container: purged generated images >${DAYS}d"
else
  echo -e "  ${YELLOW}○${RESET} open-webui container not running — skipping its images"
fi

echo -e "${GREEN}Done.${RESET}"
