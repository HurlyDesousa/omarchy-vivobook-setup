#!/usr/bin/env bash
# Report whether distro alsa-ucm-conf already covers ASUS Vivobook S15 (X1E80100).
# Read-only — safe to run before ADSP/audio card exists.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

UCM_DIR='/usr/share/alsa/ucm2/Qualcomm/x1e80100'
MAIN_CONF="${UCM_DIR}/x1e80100.conf"
T14S_SELECTOR="${UCM_DIR}/LENOVO-T14s.conf"
T14S_HIFI="${UCM_DIR}/T14s-HiFi.conf"
VIVOBOOK_REGEX='ASUSTeK COMPUTER.*ASUS .*Vivobook S 15'
MIN_COMMIT='e055d16'  # alsa-ucm-conf: first Vivobook S 15 regex

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
fail()  { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*"; }

issues=0
note() { issues=$((issues + 1)); fail "$1"; }

info "ALSA UCM — ASUS Vivobook S15 (see docs/ALSA-UCM-VIVOBOOK.md)"

if command -v pacman >/dev/null 2>&1; then
  if pacman -Qi alsa-ucm-conf &>/dev/null; then
    ok "alsa-ucm-conf installed: $(pacman -Qi alsa-ucm-conf | awk -F': ' '/^Version /{print $2; exit}')"
  else
    note "alsa-ucm-conf not installed (pacman -Qi alsa-ucm-conf)"
  fi
else
  warn "pacman not found — skipping package query"
fi

for f in "${MAIN_CONF}" "${T14S_SELECTOR}" "${T14S_HIFI}"; do
  if [[ -r "${f}" ]]; then
    ok "present: ${f}"
  else
    note "missing: ${f}"
  fi
done

if [[ -r "${MAIN_CONF}" ]]; then
  if grep -qE 'Vivobook S 15' "${MAIN_CONF}"; then
    ok "x1e80100.conf includes Vivobook S 15 (>= alsa-ucm-conf ${MIN_COMMIT})"
  else
    note "x1e80100.conf lacks Vivobook S 15 regex (need alsa-ucm-conf >= ${MIN_COMMIT})"
  fi

  if grep -q 'LENOVO-T14s.conf' "${MAIN_CONF}"; then
    ok "x1e80100.conf routes LENOVOT14s If block → LENOVO-T14s.conf"
  else
    note "x1e80100.conf does not include LENOVO-T14s.conf"
  fi
fi

if [[ -r "${T14S_SELECTOR}" ]] && grep -q 'T14s-HiFi.conf' "${T14S_SELECTOR}"; then
  ok "LENOVO-T14s.conf → T14s-HiFi profile"
elif [[ -r "${T14S_SELECTOR}" ]]; then
  note "LENOVO-T14s.conf does not reference T14s-HiFi.conf"
fi

if [[ -r /sys/devices/virtual/dmi/id/board_vendor ]]; then
  dmi="$(printf '%s-%s-%s' \
    "$(cat /sys/devices/virtual/dmi/id/board_vendor)" \
    "$(cat /sys/devices/virtual/dmi/id/product_family)" \
    "$(cat /sys/devices/virtual/dmi/id/board_name)")"
  info "DMI (UCM Define.DMI_info): ${dmi}"
  if [[ -r "${MAIN_CONF}" ]] && grep -qE 'Vivobook S 15' "${MAIN_CONF}"; then
    if printf '%s\n' "${dmi}" | grep -qE 'ASUSTeK COMPUTER.*ASUS.*Vivobook S 15'; then
      ok "DMI matches Vivobook S 15 pattern (would select T14s-HiFi when card exists)"
    else
      warn "DMI does not match Vivobook S 15 regex on this machine (expected on S5507QA)"
    fi
  fi
else
  warn "DMI sysfs not readable — skip DMI match preview"
fi

if command -v aplay >/dev/null 2>&1; then
  if aplay -l 2>/dev/null | grep -qiE 'dummy|no soundcards'; then
    warn "aplay -l: no real ALSA card yet (Dummy only) — UCM/alsaucm not usable until ADSP"
  elif aplay -l 2>/dev/null | grep -qiE 'x1e80100|qcom|snapdragon|asoc'; then
    ok "aplay -l: Qualcomm/X1E sound card present"
    if command -v alsaucm >/dev/null 2>&1; then
      card_idx="$(aplay -l 2>/dev/null | awk -F'[: ]' '/card [0-9]+:/{print $2; exit}')"
      if [[ -n "${card_idx}" ]]; then
        info "alsaucm -c ${card_idx} list _verbs:"
        alsaucm -c "${card_idx}" list _verbs 2>/dev/null || warn "alsaucm failed (card may not expose UCM yet)"
      fi
    else
      warn "alsaucm not installed (alsa-utils)"
    fi
  else
    info "aplay -l output:"
    aplay -l 2>/dev/null | sed 's/^/  /' || true
  fi
else
  warn "aplay not found"
fi

if [[ "${issues}" -eq 0 ]]; then
  ok "UCM coverage looks good for Vivobook S15"
  exit 0
fi

warn "${issues} issue(s) — distro alsa-ucm-conf may be too old or incomplete"
info "Fix: cd ${REPO_ROOT}/packages/alsa-ucm-vivobook-overlay && makepkg -si"
info "HOLD: not wired into install-all.sh until Toby greenlight — see docs/ALSA-UCM-VIVOBOOK.md"
exit 1
