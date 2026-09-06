#!/usr/bin/env bash
# Resolve Vivobook install target home — never /root when invoked via sudo/root.
# Source from install-all.sh, fetch-gguf.sh, and post-update hooks.

# OMARCHY_HOME / TARGET_HOME override; else SUDO_USER home when EUID=0; else /home/hurly
# for bare root; else current $HOME.
resolve_omarchy_home() {
  local resolved=""

  if [[ -n "${OMARCHY_HOME:-}" ]]; then
    resolved="${OMARCHY_HOME}"
  elif [[ -n "${TARGET_HOME:-}" ]]; then
    resolved="${TARGET_HOME}"
  elif [[ "${EUID}" -eq 0 ]]; then
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
      resolved="$(getent passwd "${SUDO_USER}" 2>/dev/null | cut -d: -f6 || true)"
    fi
    if [[ -z "${resolved}" ]]; then
      resolved="/home/hurly"
    fi
  else
    resolved="${HOME}"
  fi

  if [[ -z "${resolved}" || ! -d "${resolved}" ]]; then
    printf 'ERROR: cannot resolve Vivobook install home (set OMARCHY_HOME or TARGET_HOME)\n' >&2
    return 1
  fi

  export OMARCHY_HOME="${resolved}"
  export HOME="${resolved}"
}

# Call from hooks when they may run under sudo/root.
vivobook_ensure_user_home() {
  if [[ "${EUID}" -eq 0 ]]; then
    resolve_omarchy_home
  elif [[ -n "${OMARCHY_HOME:-}" && "${HOME}" != "${OMARCHY_HOME}" ]]; then
    export HOME="${OMARCHY_HOME}"
  fi
}

# Source user-home.sh from a hook (installed copy, repo checkout, or inline fallback).
vivobook_source_user_home() {
  local candidate lib=""

  for candidate in \
    "/home/hurly/.local/lib/omarchy-vivobook/user-home.sh" \
    "${OMARCHY_VIVOBOOK_SETUP:+$OMARCHY_VIVOBOOK_SETUP/scripts/lib/user-home.sh}" \
    "${HOME}/.local/lib/omarchy-vivobook/user-home.sh"; do
    if [[ -n "${candidate}" && -f "${candidate}" ]]; then
      lib="${candidate}"
      break
    fi
  done

  if [[ -n "${lib}" ]]; then
    # shellcheck source=/dev/null
    source "${lib}"
    vivobook_ensure_user_home
    return 0
  fi

  # First install before user-home.sh is deployed — inline resolve for root/sudo.
  if [[ "${EUID}" -eq 0 ]]; then
    local resolved=""
    if [[ -n "${OMARCHY_HOME:-}" ]]; then
      resolved="${OMARCHY_HOME}"
    elif [[ -n "${TARGET_HOME:-}" ]]; then
      resolved="${TARGET_HOME}"
    elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
      resolved="$(getent passwd "${SUDO_USER}" 2>/dev/null | cut -d: -f6 || true)"
    fi
    resolved="${resolved:-/home/hurly}"
    export OMARCHY_HOME="${resolved}" HOME="${resolved}"
  fi
}
