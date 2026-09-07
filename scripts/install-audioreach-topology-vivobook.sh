#!/usr/bin/env bash
# Build and install audioreach-topology-vivobook from packages/ PKGBUILD.
# Not wired into install-all.sh — run when Omarchy greenlights audio firmware.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PKG_DIR="${REPO_ROOT}/packages/audioreach-topology-vivobook"

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }

if [[ ! -f "${PKG_DIR}/PKGBUILD" ]]; then
  echo "Missing PKGBUILD: ${PKG_DIR}/PKGBUILD" >&2
  exit 1
fi

for cmd in makepkg pacman; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "Required command not found: ${cmd} (Arch/Omarchy ARM expected)" >&2
    exit 1
  fi
done

info "AudioReach topology — ASUS Vivobook S15 (see docs/AUDIOREACH-TOPOLOGY.md)"
info "Building from ${PKG_DIR}"

if ! pacman -Q cmake alsa-utils m4 &>/dev/null; then
  info "Installing build dependencies…"
  sudo pacman -S --needed --noconfirm base-devel cmake alsa-utils m4
fi

(
  cd "${PKG_DIR}"
  makepkg -si --noconfirm
)

ok "Installed. Verify:"
echo "  ls -l /usr/lib/firmware/qcom/x1e80100/ASUSTeK/vivobook-s15/"
warn "Topology on disk does not imply aplay cards until full ADSP — see docs/AUDIOREACH-TOPOLOGY.md"
