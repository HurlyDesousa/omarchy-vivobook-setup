#!/usr/bin/env bash
# Download GGUF model weights for local pi/llama-local inference.
# Does NOT commit blobs to git. See docs/GGUF.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/user-home.sh
source "${SCRIPT_DIR}/lib/user-home.sh"
resolve_omarchy_home || exit 1

GGUF_DEST="${GGUF_DEST:-${HOME}/.local/share/models}"
GGUF_FILENAME="${GGUF_FILENAME:-model.gguf}"
GGUF_URL="${GGUF_URL:-}"

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }

if [[ -z "${GGUF_URL}" ]]; then
  warn "GGUF_URL is not set."
  echo
  echo "  TODO: INVENTORY — set the canonical download URL in docs/GGUF.md"
  echo "  and export GGUF_URL before running, e.g.:"
  echo
  echo '    export GGUF_URL="https://example.com/your-model.gguf"'
  echo '    export GGUF_FILENAME="your-model.gguf"  # optional'
  echo "    ./scripts/fetch-gguf.sh"
  echo
  exit 1
fi

DEST_PATH="${GGUF_DEST}/${GGUF_FILENAME}"
mkdir -p "${GGUF_DEST}"

if [[ -f "${DEST_PATH}" ]]; then
  info "File already exists: ${DEST_PATH}"
  read -r -p "Re-download and overwrite? [y/N] " ans
  if [[ "${ans,,}" != "y" ]]; then
    ok "Keeping existing file."
    exit 0
  fi
fi

info "Downloading → ${DEST_PATH}"
info "URL: ${GGUF_URL}"

if command -v curl >/dev/null 2>&1; then
  curl -fL --progress-bar -o "${DEST_PATH}.partial" "${GGUF_URL}"
elif command -v wget >/dev/null 2>&1; then
  wget -O "${DEST_PATH}.partial" "${GGUF_URL}"
else
  echo "ERROR: need curl or wget" >&2
  exit 1
fi

mv "${DEST_PATH}.partial" "${DEST_PATH}"
ok "Download complete: $(du -h "${DEST_PATH}" | cut -f1) — ${DEST_PATH}"
info "Configure pi/llama-local to use this path (TODO: INVENTORY for exact config key)"
