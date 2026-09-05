# Live inventory — AsusLaptop, 2026-09-05

Short stub. The **full inventory** was produced by Omarchy Master and delivered via chat; the canonical copy lives on the laptop at:

```
/home/hurly/omarchy-restore-inventory.md
```

It is intentionally not mirrored here in full (too long for this repo); pull it from the laptop (or ask Omarchy Master) when you need the complete dump. This file only records what has been merged into the repo from it, and what is still pending.

## Merged in this pass (verbatim from Omarchy Master, 2026-09-05 ~23:21 CEST)

| Live path on laptop | Repo file | Status |
|---------------------|-----------|--------|
| `~/.config/hypr/autostart.lua` | `configs/hypr/autostart.lua.fragment` | live content (task-manager marked block) |
| `~/.config/hypr/input.lua` | `configs/hypr/input.lua.fragment` | touchpad block: `natural_scroll = true`, `scroll_factor = 0.28` |
| `~/.config/omarchy/shell.json` | `configs/omarchy/shell.json.fragment` | full file + idle `lock` 300 / `screensaver` 400 / `dim` 180 (verbatim) |
| `~/.local/state/omarchy/kbd-backlight` (JSON **file**) | `configs/state/kbd-backlight.json.default` | verbatim live: `#ff8800`, enabled/autostart/auto_off true, brightness 100 |
| `~/.config/systemd/user/omarchy-llama-server.service` | `configs/systemd/user/omarchy-llama-server.service` | **verbatim** — `~/.local/bin/omarchy-llama-server`, LLAMA_THREADS=10, LLAMA_CTX=8192 |
| `~/.config/systemd/user/battery-idle-suspend.service` | `configs/systemd/user/battery-idle-suspend.service` | **verbatim** — `~/.local/bin/omarchy-battery-idle-suspend.sh` |
| `~/.config/omarchy/hooks/post-update.d/restore-idle-dim.hook` | `configs/omarchy/hooks/post-update.d/restore-idle-dim.hook` | stub (full bytes pending); forces dim=180/lock=300/ss=400, kbd state, honors auto_off, never stops x1e-ec-tool |
| `~/.config/omarchy/hooks/post-update.d/restore-lock-lidharden.hook` | `configs/omarchy/hooks/post-update.d/restore-lock-lidharden.hook` | stub (full bytes pending); see lock-lidharden BUG below |
| Lock lid-harden diff | `configs/quickshell/lock-lidharden.patch` | placeholder + BUG notes (missing `clearCrashedLockProc`/`strandedRecoverDelay` defs) |
| `~/.pi/agent/models.json` | `configs/pi/models.json` | provider `llama-local` |
| `~/.pi/agent/settings.json` | `configs/pi/settings.json.defaults` | defaults only; live file may carry extra keys |
| Version pins | `docs/INSTALL-POINTERS.md` | TM `1e63b1f`, Cursor linux-arm64 API, llama.cpp `b10819`, x1e-ec-tool `ce572b3` @ `~/src/x1e-ec-tool/install.sh`, pi `0.85.1` |

## Removed (guessed unit names — not on live laptop)

| Removed repo file | Reason |
|-------------------|--------|
| `configs/systemd/user/llama-server.service` | live unit is `omarchy-llama-server.service` |
| `configs/systemd/user/kbd-backlight-restore.service` | not present on live laptop |

## Lock lid-harden known bug (live)

Live `/usr/share/omarchy/shell/plugins/lock/Service.qml` references `clearCrashedLockProc` and `strandedRecoverDelay` but **neither id is defined** (no matching `Process` or `Timer`). Diff vs `Service.qml.bak-pre-lidlock-*` shows:

- stranded-recover path uses those missing ids
- `loadBackground` uses `sessionLock.locked || sessionLock.secure`
- stabilize timer interval: 500 → 1500 ms

Complete the patch with real `Process`/`Timer` defs, or document as incomplete live state.

## Reconstructed vs. verbatim

Verbatim from Omarchy Master: `shell.json` idle block, both systemd units, `kbd-backlight.json.default`. Earlier pass supplied `autostart.lua.fragment` and touchpad values verbatim. Remaining hook bodies and QML patches are stubs pending tarball follow-up.

## Known conflicts with the scaffold

- `configs/state/kbd-backlight/*.default` (four separate files) predates the inventory. The live plugin stores **one JSON file** at `~/.local/state/omarchy/kbd-backlight`; creating a directory at that path breaks the plugin's atomic save (`mv` into the directory). `scripts/install-all.sh` now installs the JSON default instead. The old directory files are left in place for one release and should be removed in a follow-up.
- `configs/quickshell/idle.patch` is still a placeholder (`TODO: INVENTORY`).
- `configs/quickshell/lock-lidharden.patch` is incomplete (missing Process/Timer defs on live laptop).

## Still pending from the full inventory

- Kernel: exact `linux-aarch64-vivobook` package name, `mkinitcpio` hooks, boot entry (`docs/REPOS.md` TODO)
- Canonical GGUF model URL/filename for `scripts/fetch-gguf.sh` (`docs/GGUF.md` TODO)
- mise tool versions (`~/.config/mise/config.toml`) for node/pi/grok
- Quickshell idle policy patch (`configs/quickshell/idle.patch`) — verbatim QML diff from AsusLaptop
- Lock lid-harden patch (`configs/quickshell/lock-lidharden.patch`) — complete diff + fix missing `clearCrashedLockProc`/`strandedRecoverDelay` defs
- Verbatim post-update hook bodies (`restore-idle-dim.hook`, `restore-lock-lidharden.hook`) — tarball follow-up from Omarchy Master
- `~/.local/bin/omarchy-llama-server` wrapper script and `~/.local/bin/omarchy-battery-idle-suspend.sh` (referenced by units, not in repo)
- Any additional user units or Hyprland fragments (`bindings.lua`, `monitors.lua`, `envs.lua`) present on the laptop

No secrets are recorded here or anywhere in this repo. See `docs/SECRETS.md`.
