#!/usr/bin/env bash
# Safe file install helpers: backup, dirty detection, dry-run, force.
# Source from install-all.sh and post-update hooks after user-home.sh.

: "${INSTALL_DRY_RUN:=0}"
: "${INSTALL_FORCE:=0}"

VIVOBOOK_BACKUP_ROOT="${HOME}/.local/share/omarchy-vivobook-setup/backups"
VIVOBOOK_MANIFEST_DIR="${HOME}/.local/share/omarchy-vivobook-setup/manifests"

_vivobook_manifest_key() {
  printf '%s' "$1" | sed 's|^/|_|g; s|/|__|g'
}

_vivobook_manifest_path() {
  printf '%s/%s.sha256' "${VIVOBOOK_MANIFEST_DIR}" "$(_vivobook_manifest_key "$1")"
}

_vivobook_file_sha256() {
  local f="$1"
  [[ -f "${f}" ]] || return 1
  sha256sum "${f}" | awk '{print $1}'
}

_vivobook_record_manifest() {
  local dest="$1"
  local sha
  sha="$(_vivobook_file_sha256 "${dest}")" || return 0
  mkdir -p "${VIVOBOOK_MANIFEST_DIR}"
  printf '%s\n' "${sha}" > "$(_vivobook_manifest_path "${dest}")"
}

_vivobook_was_installed_by_us() {
  local dest="$1"
  local manifest sha current
  manifest="$(_vivobook_manifest_path "${dest}")"
  [[ -f "${manifest}" ]] || return 1
  sha="$(cat "${manifest}")"
  current="$(_vivobook_file_sha256 "${dest}")" || return 1
  [[ "${sha}" == "${current}" ]]
}

_vivobook_is_dirty() {
  local src="$1"
  local dest="$2"
  [[ -f "${dest}" ]] || return 1
  cmp -s "${src}" "${dest}" && return 1
  _vivobook_was_installed_by_us "${dest}" && return 1
  return 0
}

_vivobook_timestamp_backup() {
  local dest="$1"
  local label="${2:-$(basename "${dest}")}"
  local ts backup_dir backup_path

  [[ -f "${dest}" ]] || return 0
  ts="$(date -u +%Y%m%dT%H%M%SZ)"
  backup_dir="${VIVOBOOK_BACKUP_ROOT}/${ts}"
  mkdir -p "${backup_dir}"
  backup_path="${backup_dir}/${label}"
  cp -a "${dest}" "${backup_path}"
  printf '%s\n' "${backup_path}"
}

# safe_apply_file SRC DEST LABEL
# Skips when dest exists, differs from src, and was not last written by us (unless INSTALL_FORCE=1).
safe_apply_file() {
  local src="$1"
  local dest="$2"
  local label="$3"

  if [[ ! -f "${src}" ]]; then
    printf '[WARN] Missing inventory file: %s (%s)\n' "${src}" "${label}" >&2
    return 0
  fi

  mkdir -p "$(dirname "${dest}")"

  if [[ -f "${dest}" ]] && cmp -s "${src}" "${dest}"; then
    _vivobook_record_manifest "${dest}"
    printf '[ OK ] Already applied: %s\n' "${label}"
    return 0
  fi

  if [[ -f "${dest}" ]] && _vivobook_is_dirty "${src}" "${dest}"; then
    if [[ "${INSTALL_FORCE}" == "1" ]]; then
      local backup
      backup="$(_vivobook_timestamp_backup "${dest}" "${label// /_}")"
      printf '[INFO] Force overwrite (backup: %s): %s\n' "${backup}" "${label}"
    elif [[ "${INSTALL_DRY_RUN}" == "1" ]]; then
      printf '[INFO] Dry-run skip dirty file: %s → %s\n' "${label}" "${dest}"
      return 0
    else
      printf '[WARN] Skipping dirty file (use --force to overwrite): %s → %s\n' "${label}" "${dest}"
      return 0
    fi
  elif [[ -f "${dest}" ]]; then
    _vivobook_timestamp_backup "${dest}" "${label// /_}" >/dev/null
    printf '[INFO] Updating %s → %s\n' "${label}" "${dest}"
  else
    printf '[INFO] Installing %s → %s\n' "${label}" "${dest}"
  fi

  if [[ "${INSTALL_DRY_RUN}" == "1" ]]; then
    printf '[INFO] Dry-run would install: %s\n' "${label}"
    return 0
  fi

  cp "${src}" "${dest}"
  _vivobook_record_manifest "${dest}"
  printf '[ OK ] %s\n' "${label}"
}

# seed_if_absent SRC DEST LABEL — never overwrite an existing dest.
seed_if_absent() {
  local src="$1"
  local dest="$2"
  local label="$3"

  if [[ -f "${dest}" ]]; then
    printf '[ OK ] Keeping existing: %s\n' "${label}"
    return 0
  fi
  safe_apply_file "${src}" "${dest}" "${label}"
}

# merge_pi_models SRC DEST — merge llama-local provider only; seed if dest absent.
merge_pi_models() {
  local src="$1"
  local dest="$2"
  local label="$3"

  if [[ ! -f "${src}" ]]; then
    printf '[WARN] Missing inventory file: %s (%s)\n' "${src}" "${label}" >&2
    return 0
  fi

  mkdir -p "$(dirname "${dest}")"

  if [[ ! -f "${dest}" ]]; then
    safe_apply_file "${src}" "${dest}" "${label}"
    return 0
  fi

  if [[ "${INSTALL_DRY_RUN}" == "1" ]]; then
    printf '[INFO] Dry-run would merge llama-local into %s\n' "${dest}"
    return 0
  fi

  python3 - <<'PY' "${src}" "${dest}"
import json, sys
from pathlib import Path

src = Path(sys.argv[1])
dest = Path(sys.argv[2])
incoming = json.loads(src.read_text())
existing = json.loads(dest.read_text())
providers = existing.setdefault("providers", {})
if "llama-local" in providers and providers["llama-local"] != incoming["providers"]["llama-local"]:
    print("[WARN] pi models.json llama-local differs — keeping live values")
    raise SystemExit(0)
providers["llama-local"] = incoming["providers"]["llama-local"]
dest.write_text(json.dumps(existing, indent=2) + "\n")
print("[ OK ] pi models.json (merged llama-local)")
PY
}

# ensure_hypr_tm_block DEST FRAGMENT — inject omarchy-task-manager marked block if missing.
ensure_hypr_tm_block() {
  local dest="$1"
  local fragment="$2"

  [[ -f "${dest}" ]] || return 0
  if grep -q 'omarchy-task-manager begin' "${dest}" 2>/dev/null; then
    printf '[ OK ] Hypr autostart TM block present\n'
    return 0
  fi

  if [[ ! -f "${fragment}" ]]; then
    printf '[WARN] Missing autostart fragment for TM block: %s\n' "${fragment}" >&2
    return 1
  fi

  local tm_block
  tm_block="$(awk '/-- omarchy-task-manager begin/,/-- omarchy-task-manager end/' "${fragment}" | sed "s|/home/hurly|${HOME}|g")"
  if [[ -z "${tm_block}" ]]; then
    printf '[WARN] TM block not found in fragment: %s\n' "${fragment}" >&2
    return 1
  fi

  if [[ "${INSTALL_DRY_RUN}" == "1" ]]; then
    printf '[INFO] Dry-run would inject Hypr TM block into %s\n' "${dest}"
    return 0
  fi

  _vivobook_timestamp_backup "${dest}" "hypr-autostart.lua" >/dev/null
  {
    printf '%s\n' "${tm_block}"
    cat "${dest}"
  } > "${dest}.tmp" && mv "${dest}.tmp" "${dest}"
  _vivobook_record_manifest "${dest}"
  printf '[ OK ] Hypr autostart TM block restored\n'
}

# merge_shell_json_idle_keys DEST FRAGMENT — set idle keys only when missing in dest.
merge_shell_json_idle_keys() {
  local dest="$1"
  local fragment="$2"

  [[ -f "${dest}" ]] || return 0
  [[ -f "${fragment}" ]] || return 0

  python3 - <<'PY' "${dest}" "${fragment}"
import json, sys
from pathlib import Path

dest = Path(sys.argv[1])
fragment = Path(sys.argv[2])
desired = json.loads(fragment.read_text()).get("idle") or {}
if not desired:
    raise SystemExit(0)
data = json.loads(dest.read_text())
idle = data.get("idle") or {}
changed = False
for key, value in desired.items():
    if key not in idle:
        idle[key] = value
        changed = True
    elif idle[key] != value:
        print(f"[WARN] shell.json idle.{key}={idle[key]} (keeping live; desired {value})")
if changed:
    data["idle"] = idle
    dest.write_text(json.dumps(data, indent=2) + "\n")
    print("[ OK ] shell.json idle keys merged (missing only)")
else:
    print("[ OK ] shell.json idle keys unchanged")
PY
}

# expand_home_placeholders SRC — print path with @OMARCHY_HOME@ / @HOME@ replaced.
expand_home_placeholders() {
  local src="$1"
  sed "s|@OMARCHY_HOME@|${HOME}|g; s|@HOME@|${HOME}|g" "${src}"
}

# safe_overlay_symlink SRC DEST LABEL — ln -sfn with sudo when /usr/share/omarchy/bin is not writable.
safe_overlay_symlink() {
  local src="$1"
  local dest="$2"
  local label="$3"

  [[ -e "${src}" || -L "${src}" ]] || return 0

  if [[ "${INSTALL_DRY_RUN}" == "1" ]]; then
    printf '[INFO] Dry-run would symlink %s → %s (%s)\n' "${src}" "${dest}" "${label}"
    return 0
  fi

  if [[ -w "$(dirname "${dest}")" ]]; then
    ln -sfn "${src}" "${dest}"
  elif command -v sudo >/dev/null 2>&1; then
    sudo ln -sfn "${src}" "${dest}"
  else
    printf '[WARN] Cannot symlink %s → %s (sudo required)\n' "${src}" "${dest}" >&2
    return 1
  fi
  printf '[ OK ] %s\n' "${label}"
}
