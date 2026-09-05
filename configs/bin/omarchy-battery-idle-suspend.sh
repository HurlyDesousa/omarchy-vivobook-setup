#!/bin/bash
# Suspend after 1 hour idle, only when on battery.
# Unreadable charger sysfs (ADSP down): assume battery and still suspend.

set -u
IDLE_SEC=3600
POLL_SEC=30
STAY_AWAKE="${HOME}/.local/state/omarchy/indicators/stay-awake"

on_ac() {
  python3 - << 'PY'
from pathlib import Path
saw_readable = False
for p in Path("/sys/class/power_supply").iterdir():
    tpath, opath = p / "type", p / "online"
    if not tpath.exists() or not opath.exists():
        continue
    try:
        t = tpath.read_text().strip()
    except Exception:
        continue
    if t not in ("Mains", "USB", "Wireless"):
        continue
    try:
        v = opath.read_text().strip()
    except Exception:
        continue
    saw_readable = True
    if v == "1":
        raise SystemExit(0)
raise SystemExit(1)
PY
}

idle_seconds() {
  local sid since now
  sid=$(loginctl list-sessions --no-legend | awk '$3=="hurly" {print $1; exit}')
  if [[ -z ${sid:-} ]]; then
    echo 0
    return
  fi
  if [[ $(loginctl show-session "$sid" -p IdleHint --value) != yes ]]; then
    echo 0
    return
  fi
  since=$(loginctl show-session "$sid" -p IdleSinceHint --value)
  if [[ -z ${since:-} || $since -eq 0 ]]; then
    echo 0
    return
  fi
  now=$(date +%s%6N)
  echo $(( (now - since) / 1000000 ))
}

while true; do
  sleep "$POLL_SEC"
  [[ -e $STAY_AWAKE ]] && continue
  if on_ac; then
    continue
  fi
  idle=$(idle_seconds)
  [[ $idle =~ ^[0-9]+$ ]] || idle=0
  if (( idle >= IDLE_SEC )); then
    logger -t omarchy-battery-idle-suspend "idle ${idle}s on battery, suspending"
    systemctl suspend
  fi
done
