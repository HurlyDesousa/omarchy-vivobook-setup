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
| `~/.config/omarchy/shell.json` | `configs/omarchy/shell.json.fragment` | full file: Omarchy default layout + `sw.art.kbd-backlight` (left of clock) + `sw.art.task-manager` (after weather); idle `dim` 180 / `screensaver` 400 / `lock` 300 |
| `~/.local/state/omarchy/kbd-backlight` (JSON **file**, not a directory) | `configs/state/kbd-backlight.json.default` | live hex `#ff8800`; `enabled`/`autostart`/`auto_off` true; `brightness` 100 |
| `~/.config/systemd/user/omarchy-llama-server.service` | `configs/systemd/user/omarchy-llama-server.service` | stub — paste verbatim ExecStart from AsusLaptop; expected wrapper `~/.local/bin/omarchy-llama-server` |
| `~/.config/systemd/user/battery-idle-suspend.service` | `configs/systemd/user/battery-idle-suspend.service` | stub — paste verbatim ExecStart from AsusLaptop; battery suspend script path TBD |
| `~/.config/omarchy/hooks/post-update.d/restore-idle-dim.hook` | `configs/omarchy/hooks/post-update.d/restore-idle-dim.hook` | stub mirroring live hook pattern; re-applies `configs/quickshell/idle.patch` |
| `~/.config/omarchy/hooks/post-update.d/restore-lock-lidharden.hook` | `configs/omarchy/hooks/post-update.d/restore-lock-lidharden.hook` | stub mirroring idle hook; re-applies `configs/quickshell/lock-lidharden.patch` |
| Lock lid-harden diff | `configs/quickshell/lock-lidharden.patch` | placeholder — live sources: `/usr/share/omarchy/shell/plugins/lock/Service.qml` vs `Service.qml.bak-pre-lidlock-*` |
| `~/.pi/agent/models.json` | `configs/pi/models.json` | provider `llama-local` |
| `~/.pi/agent/settings.json` | `configs/pi/settings.json.defaults` | defaults only; live file may carry extra keys |
| Version pins | `docs/INSTALL-POINTERS.md` | TM `1e63b1f`, Cursor linux-arm64 API, llama.cpp `b10819`, x1e-ec-tool `ce572b3` @ `~/src/x1e-ec-tool/install.sh`, pi `0.85.1` |

## Removed (guessed unit names — not on live laptop)

| Removed repo file | Reason |
|-------------------|--------|
| `configs/systemd/user/llama-server.service` | live unit is `omarchy-llama-server.service` |
| `configs/systemd/user/kbd-backlight-restore.service` | not present on live laptop |

## Reconstructed vs. verbatim

Only `autostart.lua.fragment` and the touchpad values in `input.lua.fragment` were supplied verbatim in this pass. The other bodies were reconstructed from the upstream sources they are derived from (Omarchy `config/omarchy/shell.json` default, `omarchy-task-manager` `install.sh`/`KbdBacklight.qml` at `1e63b1f`, pi `models.json`/`settings.json` schema). Omarchy Master should diff them against the live files and send corrections; systemd unit **ExecStart** bodies and hook scripts in particular need pasting verbatim from AsusLaptop.

## Known conflicts with the scaffold

- `configs/state/kbd-backlight/*.default` (four separate files) predates the inventory. The live plugin stores **one JSON file** at `~/.local/state/omarchy/kbd-backlight`; creating a directory at that path breaks the plugin's atomic save (`mv` into the directory). `scripts/install-all.sh` now installs the JSON default instead. The old directory files are left in place for one release and should be removed in a follow-up.
- `configs/quickshell/idle.patch` is still a placeholder (`TODO: INVENTORY`).
- `configs/quickshell/lock-lidharden.patch` is still a placeholder (`TODO: INVENTORY`).
- `configs/systemd/user/omarchy-llama-server.service` and `battery-idle-suspend.service` are stubs pending verbatim paste from AsusLaptop.

## Still pending from the full inventory

- Kernel: exact `linux-aarch64-vivobook` package name, `mkinitcpio` hooks, boot entry (`docs/REPOS.md` TODO)
- Canonical GGUF model URL/filename for `scripts/fetch-gguf.sh` (`docs/GGUF.md` TODO)
- mise tool versions (`~/.config/mise/config.toml`) for node/pi/grok
- Quickshell idle policy patch (`configs/quickshell/idle.patch`) — verbatim from AsusLaptop
- Lock lid-harden patch (`configs/quickshell/lock-lidharden.patch`) — diff `Service.qml` vs `Service.qml.bak-pre-lidlock-*`
- Verbatim `ExecStart` for `omarchy-llama-server.service` and `battery-idle-suspend.service`
- Verbatim post-update hook bodies (`restore-idle-dim.hook`, `restore-lock-lidharden.hook`)
- Any additional user units or Hyprland fragments (`bindings.lua`, `monitors.lua`, `envs.lua`) present on the laptop

No secrets are recorded here or anywhere in this repo. See `docs/SECRETS.md`.
