#!/usr/bin/env bash
# Idempotent restore orchestrator for Omarchy Vivobook S15 (S5507QA).
# Safe to re-run. Fails soft on missing inventory files.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIGS_DIR="${REPO_ROOT}/configs"
REPOS_DIR="${OMARCHY_REPOS_DIR:-${HOME}/src/omarchy-vivobook-setup/repos}"

# --- helpers -----------------------------------------------------------------

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m %s\n' "$*"; }
fail()  { printf '\033[1;31m[FAIL]\033[0m %s\n' "$*"; }

clone_or_update() {
  local url="$1"
  local name="$2"
  local dir="${REPOS_DIR}/${name}"

  mkdir -p "${REPOS_DIR}"

  if [[ -d "${dir}/.git" ]]; then
    info "Updating ${name}…"
    git -C "${dir}" pull --ff-only || warn "Could not fast-forward ${name}; resolve manually in ${dir}"
  else
    info "Cloning ${name}…"
    git clone "${url}" "${dir}" || {
      warn "Clone failed for ${name}; skipping."
      return 1
    }
  fi
  return 0
}

run_repo_install() {
  local name="$1"
  local dir="${REPOS_DIR}/${name}"

  if [[ ! -d "${dir}" ]]; then
    warn "Repo ${name} not present; skipping install."
    return 0
  fi

  if [[ -x "${dir}/install.sh" ]]; then
    info "Running ${name}/install.sh…"
    (cd "${dir}" && ./install.sh) || warn "${name}/install.sh returned non-zero; continuing."
  else
    warn "No install.sh in ${name}; see docs/REPOS.md for manual steps."
  fi
}

apply_fragment() {
  local src="$1"
  local dest="$2"
  local label="$3"

  if [[ ! -f "${src}" ]]; then
    warn "Missing inventory file: ${src} (${label}) — TODO: INVENTORY"
    return 0
  fi

  mkdir -p "$(dirname "${dest}")"

  if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
    ok "Already applied: ${label}"
    return 0
  fi

  if [[ -f "${dest}" ]]; then
    info "Updating ${label} → ${dest}"
  else
    info "Installing ${label} → ${dest}"
  fi
  cp "${src}" "${dest}"
  ok "${label}"
}

apply_patch_if_present() {
  local patch="$1"
  local target="$2"
  local label="$3"

  if [[ ! -f "${patch}" ]]; then
    warn "Missing patch: ${patch} (${label}) — TODO: INVENTORY"
    return 0
  fi

  if [[ ! -f "${target}" ]]; then
    warn "Patch target missing: ${target} (${label}); apply manually after Omarchy base install."
    return 0
  fi

  if patch --dry-run -R -p1 -d "$(dirname "${target}")" < "${patch}" >/dev/null 2>&1; then
    ok "Patch already applied: ${label}"
    return 0
  fi

  info "Applying patch: ${label}"
  patch -p1 -d "$(dirname "${target}")" < "${patch}" || warn "Patch failed for ${label}; resolve manually."
}

ensure_state_dir() {
  local dir="$1"
  mkdir -p "${dir}"
  ok "State dir: ${dir}"
}

install_system_file() {
  local src="$1"
  local dest="$2"
  local label="$3"
  local mode="${4:-644}"

  if [[ ! -f "${src}" ]]; then
    warn "Missing inventory file: ${src} (${label})"
    return 0
  fi

  if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
    ok "Already applied: ${label}"
    return 0
  fi

  if [[ -w "$(dirname "${dest}")" ]]; then
    cp "${src}" "${dest}"
    chmod "${mode}" "${dest}" 2>/dev/null || true
  elif command -v sudo >/dev/null 2>&1; then
    sudo cp "${src}" "${dest}"
    sudo chmod "${mode}" "${dest}" 2>/dev/null || true
  else
    warn "Cannot install ${label} → ${dest} (sudo required)"
    return 1
  fi
  ok "${label}"
}

# --- main --------------------------------------------------------------------

main() {
  info "omarchy-vivobook-setup restore (repo: ${REPO_ROOT})"
  echo

  # 1. Related repos
  info "=== Related repositories ==="
  clone_or_update "https://github.com/HurlyDesousa/omarchy-task-manager.git" \
    "omarchy-task-manager" || true
  clone_or_update "https://github.com/HurlyDesousa/linux-aarch64-vivobook.git" \
    "linux-aarch64-vivobook" || true
  echo

  # 2. Repo install scripts
  info "=== Repo install scripts ==="
  run_repo_install "omarchy-task-manager"
  info "linux-aarch64-vivobook: kernel install is manual/reboot-required — see docs/REPOS.md"
  echo

  # 3. Hyprland config fragments
  info "=== Hyprland ==="
  apply_fragment \
    "${CONFIGS_DIR}/hypr/autostart.lua.fragment" \
    "${HOME}/.config/hypr/autostart.lua" \
    "hypr autostart.lua"
  apply_fragment \
    "${CONFIGS_DIR}/hypr/input.lua.fragment" \
    "${HOME}/.config/hypr/input.lua" \
    "hypr input.lua"
  echo

  # 4. Omarchy shell.json fragment (merge note — full merge TODO: INVENTORY)
  info "=== Omarchy shell ==="
  if [[ -f "${CONFIGS_DIR}/omarchy/shell.json.fragment" ]]; then
    mkdir -p "${HOME}/.config/omarchy"
    if [[ ! -f "${HOME}/.config/omarchy/shell.json" ]]; then
      apply_fragment \
        "${CONFIGS_DIR}/omarchy/shell.json.fragment" \
        "${HOME}/.config/omarchy/shell.json" \
        "omarchy shell.json (initial)"
    else
      warn "shell.json already exists — manual merge required from configs/omarchy/shell.json.fragment"
      warn "TODO: INVENTORY — implement JSON merge or document jq recipe"
    fi
  else
    warn "Missing configs/omarchy/shell.json.fragment — TODO: INVENTORY"
  fi

  # Plugin stubs / symlinks
  if [[ -d "${CONFIGS_DIR}/omarchy/plugins" ]]; then
    mkdir -p "${HOME}/.config/omarchy/plugins"
    for stub in "${CONFIGS_DIR}"/omarchy/plugins/*; do
      [[ -e "${stub}" ]] || continue
      base="$(basename "${stub}")"
      dest="${HOME}/.config/omarchy/plugins/${base}"
      if [[ -L "${dest}" || -e "${dest}" ]]; then
        ok "Plugin stub exists: ${base}"
      else
        ln -sf "${stub}" "${dest}" 2>/dev/null || cp -a "${stub}" "${dest}"
        ok "Installed plugin stub: ${base}"
      fi
    done
  else
    warn "No configs/omarchy/plugins/ yet — TODO: INVENTORY"
  fi
  echo

  # 5. State directories
  info "=== State directories ==="
  ensure_state_dir "${HOME}/.local/state/omarchy/task-manager"

  # kbd-backlight state is a single JSON *file* written by KbdBacklight.qml
  # (~/.local/state/omarchy/kbd-backlight). Never create a directory at that path.
  kbd_state="${HOME}/.local/state/omarchy/kbd-backlight"
  if [[ -d "${kbd_state}" ]]; then
    warn "${kbd_state} is a directory (pre-inventory layout); move it aside so the plugin can write its JSON state file"
  elif [[ -f "${kbd_state}" ]]; then
    ok "kbd-backlight state present (keeping live values)"
  elif [[ -f "${CONFIGS_DIR}/state/kbd-backlight.json.default" ]]; then
    cp "${CONFIGS_DIR}/state/kbd-backlight.json.default" "${kbd_state}"
    ok "kbd-backlight default state → ${kbd_state}"
  else
    warn "Missing configs/state/kbd-backlight.json.default — TODO: INVENTORY"
  fi
  echo

  # 6. systemd user units
  info "=== systemd user units ==="
  if [[ -d "${CONFIGS_DIR}/systemd/user" ]]; then
    mkdir -p "${HOME}/.config/systemd/user"
    for unit in "${CONFIGS_DIR}"/systemd/user/*; do
      [[ -f "${unit}" ]] || continue
      apply_fragment "${unit}" "${HOME}/.config/systemd/user/$(basename "${unit}")" \
        "systemd $(basename "${unit}")"
    done
    systemctl --user daemon-reload 2>/dev/null || warn "Could not reload user systemd (no session?)"
  else
    warn "No configs/systemd/user/ yet — TODO: INVENTORY"
  fi
  echo

  # 6b. Local bin helpers (configs/bin -> ~/.local/bin)
  info "=== Local bin helpers ==="
  if [[ -d "${CONFIGS_DIR}/bin" ]]; then
    mkdir -p "${HOME}/.local/bin"
    for bin in "${CONFIGS_DIR}"/bin/*; do
      [[ -f "${bin}" ]] || continue
      dest="${HOME}/.local/bin/$(basename "${bin}")"
      apply_fragment "${bin}" "${dest}" "bin $(basename "${bin}")"
      chmod +x "${dest}" 2>/dev/null || true
    done
  else
    warn "No configs/bin/ yet — TODO: INVENTORY"
  fi
  echo

  # 7. Quickshell QML patches
  info "=== Quickshell QML patches ==="
  if [[ -f "${CONFIGS_DIR}/quickshell/idle.patch" ]]; then
    # Target path is placeholder until inventory confirms install location
    QS_IDLE_TARGET="${HOME}/.config/quickshell/idle.qml"
    apply_patch_if_present \
      "${CONFIGS_DIR}/quickshell/idle.patch" \
      "${QS_IDLE_TARGET}" \
      "quickshell idle policy"
  else
    warn "No configs/quickshell/idle.patch — TODO: INVENTORY"
  fi

  if [[ -f "${CONFIGS_DIR}/quickshell/lock-lidharden.patch" ]]; then
    QS_LOCK_TARGET="/usr/share/omarchy/shell/plugins/lock/Service.qml"
    if grep -q '^# Quickshell lock lid-harden patch (placeholder)' "${CONFIGS_DIR}/quickshell/lock-lidharden.patch" 2>/dev/null; then
      warn "lock-lidharden.patch is still a placeholder — TODO: INVENTORY"
    elif [[ -w "$(dirname "${QS_LOCK_TARGET}")" ]] && [[ -f "${QS_LOCK_TARGET}" ]]; then
      apply_patch_if_present \
        "${CONFIGS_DIR}/quickshell/lock-lidharden.patch" \
        "${QS_LOCK_TARGET}" \
        "quickshell lock lid-harden"
    else
      warn "lock-lidharden target ${QS_LOCK_TARGET} not writable — apply via restore-lock-lidharden.hook after omarchy update (may need sudo)"
    fi
  else
    warn "No configs/quickshell/lock-lidharden.patch — TODO: INVENTORY"
  fi
  echo

  # 7b. Omarchy post-update hooks (re-apply patches after omarchy updates)
  info "=== Omarchy post-update hooks ==="
  if [[ -d "${CONFIGS_DIR}/omarchy/hooks/post-update.d" ]]; then
    mkdir -p "${HOME}/.config/omarchy/hooks/post-update.d"
    for hook in "${CONFIGS_DIR}"/omarchy/hooks/post-update.d/*; do
      [[ -f "${hook}" ]] || continue
      dest="${HOME}/.config/omarchy/hooks/post-update.d/$(basename "${hook}")"
      apply_fragment "${hook}" "${dest}" "omarchy hook $(basename "${hook}")"
      chmod +x "${dest}" 2>/dev/null || true
    done
  else
    warn "No configs/omarchy/hooks/post-update.d/ yet — TODO: INVENTORY"
  fi
  echo

  # 7c. Vivobook powerprofiles wrappers + power panel QML overlay
  info "=== Vivobook powerprofiles ==="
  VIVOBOOK_LIB="${HOME}/.local/lib/omarchy-vivobook"
  mkdir -p "${VIVOBOOK_LIB}"
  for script in omarchy-powerprofiles-list omarchy-powerprofiles-set; do
    apply_fragment \
      "${CONFIGS_DIR}/lib/omarchy-vivobook/${script}" \
      "${VIVOBOOK_LIB}/${script}" \
      "vivobook ${script}"
    chmod +x "${VIVOBOOK_LIB}/${script}" 2>/dev/null || true
  done
  ensure_state_dir "${HOME}/.local/state/omarchy/powerprofiles"

  install_system_file \
    "${CONFIGS_DIR}/lib/omarchy-vivobook/omarchy-vivobook-powerprofiles-autodetect" \
    "/usr/local/bin/omarchy-vivobook-powerprofiles-autodetect" \
    "vivobook autodetect → /usr/local/bin" \
    "755"
  install_system_file \
    "${CONFIGS_DIR}/udev/99-omarchy-vivobook-powerprofiles.rules" \
    "/etc/udev/rules.d/99-omarchy-vivobook-powerprofiles.rules" \
    "udev 99-omarchy-vivobook-powerprofiles.rules"
  install_system_file \
    "${CONFIGS_DIR}/systemd/system/omarchy-vivobook-powerprofiles-autodetect.service" \
    "/etc/systemd/system/omarchy-vivobook-powerprofiles-autodetect.service" \
    "systemd omarchy-vivobook-powerprofiles-autodetect.service"

  if command -v systemctl >/dev/null 2>&1; then
    if [[ -w /etc/systemd/system ]] || command -v sudo >/dev/null 2>&1; then
      if command -v sudo >/dev/null 2>&1; then
        sudo systemctl daemon-reload 2>/dev/null || warn "systemctl daemon-reload failed"
        sudo systemctl enable omarchy-vivobook-powerprofiles-autodetect.service 2>/dev/null \
          || warn "Could not enable omarchy-vivobook-powerprofiles-autodetect.service"
      else
        systemctl daemon-reload 2>/dev/null || warn "systemctl daemon-reload failed"
        systemctl enable omarchy-vivobook-powerprofiles-autodetect.service 2>/dev/null \
          || warn "Could not enable omarchy-vivobook-powerprofiles-autodetect.service"
      fi
    fi
    if command -v udevadm >/dev/null 2>&1; then
      if command -v sudo >/dev/null 2>&1; then
        sudo udevadm control --reload-rules 2>/dev/null || true
        sudo udevadm trigger --subsystem-match=power_supply 2>/dev/null || true
      else
        udevadm control --reload-rules 2>/dev/null || true
        udevadm trigger --subsystem-match=power_supply 2>/dev/null || true
      fi
    fi
  fi

  PP_HOOK="${HOME}/.config/omarchy/hooks/post-update.d/restore-vivobook-powerprofiles.hook"
  if [[ -x "${PP_HOOK}" ]]; then
    info "Running restore-vivobook-powerprofiles.hook…"
    "${PP_HOOK}" || warn "restore-vivobook-powerprofiles.hook failed (may need omarchy base install or sudo for /usr/share/omarchy/bin)"
  else
    warn "restore-vivobook-powerprofiles.hook not installed yet — re-run after hooks section"
  fi

  PANEL_HOOK="${HOME}/.config/omarchy/hooks/post-update.d/restore-vivobook-power-panel.hook"
  if [[ -x "${PANEL_HOOK}" ]]; then
    info "Running restore-vivobook-power-panel.hook…"
    "${PANEL_HOOK}" || warn "restore-vivobook-power-panel.hook failed (sudo may be required for /usr/share/omarchy/shell/plugins/panels/power/)"
  else
    warn "restore-vivobook-power-panel.hook not installed yet — re-run after hooks section"
  fi

  BATT_HOOK="${HOME}/.config/omarchy/hooks/post-update.d/restore-vivobook-battery-status.hook"
  if [[ -x "${BATT_HOOK}" ]]; then
    info "Running restore-vivobook-battery-status.hook…"
    "${BATT_HOOK}" || warn "restore-vivobook-battery-status.hook failed (may need omarchy base install or sudo for /usr/share/omarchy/bin)"
  else
    warn "restore-vivobook-battery-status.hook not installed yet — re-run after hooks section"
  fi
  echo

  # 8. x1e-ec-tool reminder
  info "=== x1e-ec-tool ==="
  if [[ -x "${HOME}/src/x1e-ec-tool/install.sh" ]]; then
    ok "x1e-ec-tool install script: ${HOME}/src/x1e-ec-tool/install.sh"
  else
    warn "x1e-ec-tool not at ~/src/x1e-ec-tool/install.sh — clone/build per docs/INSTALL-POINTERS.md"
  fi
  if systemctl is-active --quiet x1e-ec-tool.service 2>/dev/null; then
    ok "x1e-ec-tool.service is active (do not stop)"
  else
    warn "x1e-ec-tool.service not active — install/enable separately; never stop once running"
  fi
  echo

  # 9. mise / local AI reminder
  info "=== Local AI (mise) ==="
  if command -v mise >/dev/null 2>&1; then
    ok "mise found — run 'mise install' if tools are missing"
  else
    warn "mise not in PATH — TODO: INVENTORY for tool versions (pi, grok, llama-server)"
  fi
  if [[ -x "${HOME}/.local/bin/cursor" ]]; then
    ok "cursor: ${HOME}/.local/bin/cursor"
  else
    warn "cursor not at ~/.local/bin/cursor — reinstall Cursor ARM build (docs/INSTALL-POINTERS.md)"
  fi

  # pi (~/.pi/agent): models.json is fully managed; settings.json only seeded when absent.
  # Nothing under ~/.pi is ever read back into this repo (auth.json etc. are secrets).
  apply_fragment \
    "${CONFIGS_DIR}/pi/models.json" \
    "${HOME}/.pi/agent/models.json" \
    "pi models.json (llama-local)"
  if [[ -f "${HOME}/.pi/agent/settings.json" ]]; then
    ok "pi settings.json present (keeping live values)"
  else
    apply_fragment \
      "${CONFIGS_DIR}/pi/settings.json.defaults" \
      "${HOME}/.pi/agent/settings.json" \
      "pi settings.json (defaults)"
  fi
  echo

  # 10. SECRETS checklist
  info "=== SECRETS checklist ==="
  echo "  Re-authenticate after restore (see docs/SECRETS.md):"
  echo "    [ ] LUKS passphrase (reboot — no SSH until unlocked)"
  echo "    [ ] Cursor OAuth"
  echo "    [ ] pi ~/.pi auth (NEVER commit)"
  echo "    [ ] Grok CLI auth"
  echo "    [ ] GGUF model: ./scripts/fetch-gguf.sh"
    echo "    [ ] omarchy-llama-server :8080"
  echo
  info "Full checklist: ${REPO_ROOT}/docs/SECRETS.md"
  echo

  ok "Restore pass complete (soft failures reported above)."
  info "TODO: INVENTORY — re-run after Omarchy Master merges live config dump."
}

main "$@"
