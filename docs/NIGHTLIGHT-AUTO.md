# Auto night light (hyprsunset / Berlin)

Vivobook adds **optional auto scheduling** on top of stock Omarchy night light (`hyprsunset`, `omarchy-toggle-nightlight`, Quickshell `omarchy.nightlight`).

## Stack (unchanged)

| Piece | Path |
|-------|------|
| Engine | `/usr/bin/hyprsunset` |
| CLI toggle | `/usr/share/omarchy/bin/omarchy-toggle-nightlight` (wrapped when auto hook installed) |
| Bind | `SUPER + CTRL + N` |
| Config | `~/.config/hypr/hyprsunset.conf` (regenerated when auto is on) |
| QS service | `/usr/share/omarchy/shell/plugins/services/nightlight/` |
| QS indicator | `/usr/share/omarchy/shell/plugins/bar/indicators/NightLight.qml` |

## Enable auto (Berlin ~52.52°N, 13.40°E)

After `scripts/install-all.sh`:

```bash
omarchy-vivobook-nightlight-auto on
```

- **Sunrise** → `hyprctl hyprsunset identity` (day)
- **Sunset** → `4000K` (night)
- Daily refresh at 00:05 (`omarchy-vivobook-nightlight-auto.timer`) regenerates today's civil times.

## Controls

| Action | How |
|--------|-----|
| Auto on/off | **Right-click** bar night-light indicator → Auto toggle (+ today's sunrise/sunset when on), or `omarchy-vivobook-nightlight-auto on` / `off` / `toggle` |
| Manual on/off | **Left-click** indicator or `SUPER+CTRL+N` (works with auto off; while auto on, sets override until next daily refresh) |
| Status | `omarchy-vivobook-nightlight-auto status` |
| Disable auto | `omarchy-vivobook-nightlight-auto off` → restores stock `hyprsunset.conf` via `omarchy-refresh-hyprsunset` |

## State

`~/.local/state/omarchy/nightlight/`:

- `auto` — `on` / `off` (default `off`)
- `manual_override` — `on` / `off` while auto is on and user toggled manually
- `hyprsunset.conf.stock` — backup before first auto regen

## systemd (user)

- `omarchy-vivobook-nightlight-auto.timer` — daily schedule regen
- `omarchy-vivobook-nightlight-auto-apply.service` — apply on graphical login

## Overlays / hooks

Post-update hook `restore-vivobook-nightlight-auto.hook` re-applies:

- `configs/omarchy/overlays/services/nightlight/Service.qml` — manual override IPC
- `configs/omarchy/overlays/bar/indicators/NightLight.qml` — right-click auto options menu (`import Quickshell.Io` required for `Process` / `StdioCollector`)
- Symlink `omarchy-toggle-nightlight` wrapper in `/usr/share/omarchy/bin/`

Does **not** touch power/fan/bar patches from PR #7–#10.
