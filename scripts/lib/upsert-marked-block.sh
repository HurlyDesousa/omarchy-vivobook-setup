#!/usr/bin/env bash
# Replace or append a marked block in a dest file from a fragment.
# Markers are the first and last non-empty lines of the fragment.

upsert_marked_block() {
  local dest="$1"
  local fragment="$2"
  local begin end tmp

  if [[ ! -f "${fragment}" ]]; then
    printf 'upsert_marked_block: missing fragment %s\n' "${fragment}" >&2
    return 1
  fi

  begin="$(awk 'NF { print; exit }' "${fragment}")"
  end="$(awk 'NF { line = $0 } END { print line }' "${fragment}")"
  if [[ -z "${begin}" || -z "${end}" || "${begin}" == "${end}" ]]; then
    printf 'upsert_marked_block: fragment needs distinct begin/end marker lines\n' >&2
    return 1
  fi

  mkdir -p "$(dirname "${dest}")"

  if [[ ! -f "${dest}" ]]; then
    cat "${fragment}" > "${dest}"
    return 0
  fi

  tmp="$(mktemp)"
  awk -v begin="${begin}" -v end="${end}" -v frag="${fragment}" '
    BEGIN {
      while ((getline line < frag) > 0) {
        block = block line ORS
      }
      close(frag)
      if (block ~ /\n$/) {
        sub(/\n$/, "", block)
      }
    }
    $0 == begin {
      print block
      skipping = 1
      found = 1
      next
    }
    skipping && $0 == end {
      skipping = 0
      next
    }
    skipping { next }
    { print }
    END {
      if (!found) {
        if (NR > 0) print ""
        print block
      }
    }
  ' "${dest}" > "${tmp}"
  mv "${tmp}" "${dest}"
}
