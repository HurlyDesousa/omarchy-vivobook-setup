# Live inventory — AsusLaptop, 2026-09-05

Short stub. The **full inventory** was produced by Omarchy Master and delivered via chat; the canonical copy lives on the laptop at:

```
/home/hurly/omarchy-restore-inventory.md
```

It is intentionally not mirrored here in full (too long for this repo); pull it from the laptop (or ask Omarchy Master) when you need the complete dump. This file only records what has been merged into the repo from it, and what is still pending.

## Full fragment dump (byte-exact from `hurly@AsusLaptop`, tarball `omarchy-frag-full/`, 2026-09-05)

The `omarchy-frag-full` tarball replaced every remaining stub. Sizes below are the live byte counts and match `docs/live-2026-09-05/MANIFEST-live-20260905.txt`; the tarball's own `INSTALL-POINTERS.md` and `docs/INVENTORY.md` are kept verbatim next to it.

| Live path on laptop | Repo file | Bytes | Status |
|---------------------|-----------|-------|--------|
| `~/.config/hypr/autostart.lua` | `configs/hypr/autostart.lua.fragment` | — | live content (task-manager marked block), earlier pass |
| `~/.config/hypr/input.lua` | `configs/hypr/input.lua.fragment` | — | touchpad block: `natural_scroll = true`, `scroll_factor = 0.28`, earlier pass |
| `~/.config/omarchy/shell.json` | `configs/omarchy/shell.json.fragment` | 1481 | **verbatim** — idle `lock` 300 / `screensaver` 400 / `dim` 180, tray pin `Cursor_status_icon_1`, clock `birthYear`/`lifeExpectancy` |
| `~/.local/state/omarchy/kbd-backlight` (JSON **file**) | `configs/state/kbd-backlight.json.default` | 101 | **verbatim** — `#ff8800`, enabled/autostart/auto_off true, brightness 100 |
| `~/.config/systemd/user/omarchy-llama-server.service` | `configs/systemd/user/omarchy-llama-server.service` | 470 | **verbatim** — LLAMA_THREADS=10, `LLAMA_CTX=32768`, `LLAMA_N_PREDICT=-1` |
| `~/.config/systemd/user/battery-idle-suspend.service` | `configs/systemd/user/battery-idle-suspend.service` | 280 | **verbatim** |
| `~/.local/bin/omarchy-llama-server` | `configs/bin/omarchy-llama-server` | 1277 | **verbatim** — router mode over `~/.local/share/llm`, ctx 32768, n-predict -1, `--jinja` |
| `~/.local/bin/omarchy-battery-idle-suspend.sh` | `configs/bin/omarchy-battery-idle-suspend.sh` | 1596 | **verbatim** — 1 h idle on battery, honors stay-awake indicator |
| `~/.local/bin/omarchy-idle-dim` | `configs/bin/omarchy-idle-dim` | 2698 | **verbatim** — 25% `dp_aux_backlight` dim + kbd RGB off/restore via x1e-ec-tool |
| `~/.config/omarchy/hooks/post-update.d/restore-idle-dim.hook` | `configs/omarchy/hooks/post-update.d/restore-idle-dim.hook` | 4130 | **verbatim** — re-copies patched idle `Service.qml`, reinstalls helper, forces dim=180/lock=300/ss=400 |
| `~/.local/share/omarchy/idle-dim/Service.qml` (patched `/usr/share/omarchy/shell/plugins/services/idle/Service.qml`) | `configs/share/idle-Service.qml` | 13672 | **verbatim** — hook copy source |
| Idle dim diff vs `Service.qml.bak-predim` | `configs/quickshell/idle.patch` | 6079 | **verbatim** (replaces 5998-byte stub) |
| Lock lid-harden diff vs `Service.qml.bak-pre-lidlock-20260905212924` | `configs/quickshell/lock-lidharden.patch` | 1579 | **verbatim** live diff; still references undefined `clearCrashedLockProc`/`strandedRecoverDelay` (BUG below) |
| `~/.config/omarchy/hooks/post-update.d/restore-lock-lidharden.hook` | `configs/omarchy/hooks/post-update.d/restore-lock-lidharden.hook` | — | stub — not part of the tarball |
| `~/.pi/agent/models.json` | `configs/pi/models.json` | 707 | **verbatim** — provider `llama-local`, model `Qwen2.5-3B-Instruct-Q4_K_M`, context/maxTokens 32768 |
| `~/.pi/agent/settings.json` | `configs/pi/settings.json.defaults` | — | defaults only (default model updated to the live id); live file may carry extra keys |
| Version pins | `docs/INSTALL-POINTERS.md` | — | TM `1e63b1f`, Cursor linux-arm64 API, llama.cpp `b10819`, x1e-ec-tool `ce572b3` @ `~/src/x1e-ec-tool/install.sh`, pi `0.85.1` |

Refused/absent from the dump: no `auth.json`, `*.gguf`, or `*.AppImage` (checked before merge).

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

Verbatim from the AsusLaptop dump: `shell.json`, both systemd units, all three `~/.local/bin` helpers, `restore-idle-dim.hook`, the patched idle `Service.qml`, both QML diffs, `kbd-backlight.json.default`, and `models.json`. Earlier pass supplied `autostart.lua.fragment` and touchpad values verbatim. Still reconstructed: `restore-lock-lidharden.hook` and `settings.json.defaults`.

## Known conflicts with the scaffold

- `configs/state/kbd-backlight/*.default` (four separate files) predates the inventory. The live plugin stores **one JSON file** at `~/.local/state/omarchy/kbd-backlight`; creating a directory at that path breaks the plugin's atomic save (`mv` into the directory). `scripts/install-all.sh` now installs the JSON default instead. The old directory files are left in place for one release and should be removed in a follow-up.
- `configs/quickshell/lock-lidharden.patch` is the live diff but still incomplete (missing Process/Timer defs on live laptop).
- The idle patch targets `/usr/share/omarchy/shell/plugins/services/idle/Service.qml` (root-owned). `scripts/install-all.sh` stages `configs/share/idle-Service.qml` at `~/.local/share/omarchy/idle-dim/Service.qml` and only patches `/usr/share` when writable; `restore-idle-dim.hook` copies the staged file over the target after each omarchy update.

## Still pending from the full inventory

- Kernel: exact `linux-aarch64-vivobook` package name, `mkinitcpio` hooks, boot entry (`docs/REPOS.md` TODO)
- Canonical GGUF model URL/filename for `scripts/fetch-gguf.sh` (`docs/GGUF.md` TODO) — live wrapper expects `~/.local/share/llm/Qwen2.5-3B-Instruct-Q4_K_M.gguf`
- mise tool versions (`~/.config/mise/config.toml`) for node/pi/grok
- Lock lid-harden: fix missing `clearCrashedLockProc`/`strandedRecoverDelay` defs; verbatim `restore-lock-lidharden.hook` body
- Live `~/.pi/agent/settings.json` (only defaults in repo)
- Any additional user units or Hyprland fragments (`bindings.lua`, `monitors.lua`, `envs.lua`) present on the laptop

No secrets are recorded here or anywhere in this repo. See `docs/SECRETS.md`.
