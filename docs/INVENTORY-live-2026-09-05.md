# Live inventory — AsusLaptop, 2026-09-05

Short stub. The **full inventory** was produced by Omarchy Master and delivered via chat; the canonical copy lives on the laptop at:

```
/home/hurly/omarchy-restore-inventory.md
```

It is intentionally not mirrored here in full (too long for this repo); pull it from the laptop (or ask Omarchy Master) when you need the complete dump. This file only records what has been merged into the repo from it, and what is still pending.

## Merged in this pass

| Live path on laptop | Repo file | Status |
|---------------------|-----------|--------|
| `~/.config/hypr/autostart.lua` | `configs/hypr/autostart.lua.fragment` | live content (task-manager marked block) |
| `~/.config/hypr/input.lua` | `configs/hypr/input.lua.fragment` | touchpad block: `natural_scroll = true`, `scroll_factor = 0.28` |
| `~/.config/omarchy/shell.json` | `configs/omarchy/shell.json.fragment` | full file: Omarchy default layout + `sw.art.kbd-backlight` (left of clock) + `sw.art.task-manager` (after weather), exactly as `install.sh` @ `1e63b1f` patches it |
| `~/.local/state/omarchy/kbd-backlight` (JSON **file**, not a directory) | `configs/state/kbd-backlight.json.default` | default state as written by `KbdBacklight.qml` |
| `~/.config/systemd/user/llama-server.service` | `configs/systemd/user/llama-server.service` | user unit, `127.0.0.1:8080`, alias `local` |
| `~/.config/systemd/user/kbd-backlight-restore.service` | `configs/systemd/user/kbd-backlight-restore.service` | oneshot at `graphical-session.target` |
| `~/.pi/agent/models.json` | `configs/pi/models.json` | provider `llama-local` |
| `~/.pi/agent/settings.json` | `configs/pi/settings.json.defaults` | defaults only; live file may carry extra keys |
| Version pins | `docs/INSTALL-POINTERS.md` | TM `1e63b1f`, Cursor linux-arm64 API, llama.cpp `b10819`, x1e-ec-tool `ce572b3`, pi `0.85.1` |

## Reconstructed vs. verbatim

Only `autostart.lua.fragment` and the touchpad values in `input.lua.fragment` were supplied verbatim in this pass. The other bodies were reconstructed from the upstream sources they are derived from (Omarchy `config/omarchy/shell.json` default, `omarchy-task-manager` `install.sh`/`KbdBacklight.qml` at `1e63b1f`, pi `models.json`/`settings.json` schema). Omarchy Master should diff them against the live files and send corrections; the systemd unit names in particular need confirming against `systemctl --user list-unit-files --state=enabled` on the laptop.

## Known conflicts with the scaffold

- `configs/state/kbd-backlight/*.default` (four separate files) predates the inventory. The live plugin stores **one JSON file** at `~/.local/state/omarchy/kbd-backlight`; creating a directory at that path breaks the plugin's atomic save (`mv` into the directory). `scripts/install-all.sh` now installs the JSON default instead. The old directory files are left in place for one release and should be removed in a follow-up.
- `configs/quickshell/idle.patch` is still a placeholder (`TODO: INVENTORY`).

## Still pending from the full inventory

- Kernel: exact `linux-aarch64-vivobook` package name, `mkinitcpio` hooks, boot entry (`docs/REPOS.md` TODO)
- Canonical GGUF model URL/filename for `scripts/fetch-gguf.sh` (`docs/GGUF.md` TODO)
- mise tool versions (`~/.config/mise/config.toml`) for node/pi/grok
- Quickshell idle policy patch (`configs/quickshell/idle.patch`)
- Any additional user units or Hyprland fragments (`bindings.lua`, `monitors.lua`, `envs.lua`) present on the laptop

No secrets are recorded here or anywhere in this repo. See `docs/SECRETS.md`.
