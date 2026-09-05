# Omarchy / AsusLaptop restore inventory

**Host:** AsusLaptop (ASUS Vivobook S15 S5507QA, Snapdragon X Elite)  
**Captured:** 2026-09-05 ~23:00 Europe/Berlin (UTC+2)  
**Running:** Linux `7.2.0-6-aarch64-vivobook-ARCH`, Omarchy `4.0.1rc3-1.5`, Quickshell `0.3.1`, Hyprland `0.56.1-3`  
**Target merge:** [HurlyDesousa/omarchy-vivobook-setup](https://github.com/HurlyDesousa/omarchy-vivobook-setup) @ `4c00c3e`  
**Policy:** Prefer fragments / `*.patch` / install scripts — **no GGUF blobs, no secrets**. Never stop `x1e-ec-tool`.

---

## Merge map → `omarchy-vivobook-setup` TODO:INVENTORY

| Placeholder in restore repo | Live source | Action for Code Master |
|---|---|---|
| `configs/hypr/autostart.lua.fragment` | `~/.config/hypr/autostart.lua` | Replace with live fragment (launch + float rule; **no** size/move clamp) |
| *(add)* `configs/hypr/input.lua.fragment` | `~/.config/hypr/input.lua` | New: `natural_scroll=true`, `scroll_factor=0.28` |
| `configs/omarchy/shell.json.fragment` | `~/.config/omarchy/shell.json` | Replace: bar layout IDs `sw.art.kbd-backlight` + `sw.art.task-manager`; idle `{dim:180, lock:300, screensaver:400}` |
| `configs/omarchy/plugins/.gitkeep` | `~/.config/omarchy/plugins/sw.art.*` | After TM install: copy/symlink plugins from repo `shell/` |
| `configs/quickshell/idle.patch` | live idle QML vs `.bak-predim` / `Service.qml.orig` | Generate real patch against stock Omarchy idle `Service.qml` (path below) |
| *(add)* `configs/quickshell/lock-lidharden.patch` | lock `Service.qml` vs `.bak-pre-lidlock-*` | New: 1500ms stabilize + stranded recovery fix |
| `configs/systemd/user/.gitkeep` | user units listed below | Export `omarchy-llama-server.service`, `battery-idle-suspend.service`; note idle-dim unit is **disabled** (QML path used) |
| `configs/state/kbd-backlight/*` | `~/.local/state/omarchy/kbd-backlight` | Single JSON file (not dir of fields) — update defaults |
| `scripts/fetch-gguf.sh` / `docs/GGUF.md` | GGUF path only | Keep download script; **do not** tarball GGUF |
| `docs/SECRETS.md` | auth paths only | Paths as re-auth; never export contents |

---

## 1. Keep (configs / state / hooks / docs)

| Path | Purpose | Exists | Notes |
|---|---|---|---|
| `/home/hurly/.config/omarchy/shell.json` | Bar layout + idle.dim/lock/screensaver | Y | idle: dim=180, lock=300, screensaver=400; center has `sw.art.kbd-backlight`, `sw.art.task-manager` |
| `/home/hurly/.config/omarchy/plugins/sw.art.task-manager/` | Quickshell bar widget | Y | `BarWidget.qml` + `manifest.json` v0.5.5-7; also in TM repo `shell/` |
| `/home/hurly/.config/omarchy/plugins/sw.art.kbd-backlight/` | Quickshell kbd RGB widget | Y | `KbdBacklight.qml` + `manifest.json` v0.5.5-5 |
| `/home/hurly/.config/omarchy/hooks/post-update.d/restore-idle-dim.hook` | Re-apply idle QML + helper after Omarchy update | Y | Custom; also rewrites shell.json idle ints |
| `/home/hurly/.config/hypr/autostart.lua` | Launch TM on start + float rule | Y | `o.launch_on_start(...omarchy-task-manager)`; `o.window("art.sw.omarchy.TaskManager", { float = true })` |
| `/home/hurly/.config/hypr/input.lua` | Touchpad scroll | Y | `natural_scroll=true`, `scroll_factor=0.28` |
| `/home/hurly/.config/hypr/input.lua.bak-pre-scroll-20260905` | Pre-scroll backup | Y | Had `scroll_factor=0.4` commented; optional keep |
| `/home/hurly/.local/state/omarchy/kbd-backlight` | Kbd prefs JSON | Y | `{"hex":"#ff8800","enabled":true,"brightness":100,"autostart":true,"auto_off":true}` (file, not directory) |
| `/home/hurly/.local/share/omarchy/idle-dim/Service.qml` | Patched idle QML backup for hook | Y | Also `Service.qml.orig`, `omarchy-idle-dim.service.bak` |
| `/home/hurly/.config/systemd/user/omarchy-llama-server.service` | User unit for llama | Y | enabled; threads=10 ctx=8192 port=8080 |
| `/home/hurly/.config/systemd/user/battery-idle-suspend.service` | Suspend after 1h idle on battery | Y | enabled via graphical-session |
| `/home/hurly/.config/systemd/user/omarchy-idle-dim.service.disabled-loginctl` | Old idle-dim unit (not active) | Y | Dim now via Quickshell idle plugin; keep as reference only |
| `/home/hurly/.local/share/applications/omarchy-task-manager.desktop` | Desktop entry | Y | Also shipped by TM install |
| `/home/hurly/.local/share/applications/cursor.desktop` | Cursor desktop entry | Y | Exec → `~/.local/bin/cursor` |
| `/home/hurly/.local/share/llm/README-omarchy-llama.md` | Llama restore notes | Y | Keep; points at GGUF path (download separately) |
| `/home/hurly/.pi/agent/settings.json` | pi defaults only | Y | theme=omarchy-system; defaultProvider=`llama-local`; defaultModel=`Qwen2.5-3B-Instruct-Q4_K_M` — **no secrets** |
| `/home/hurly/.pi/agent/models.json` | llama-local provider | Y | baseUrl `http://127.0.0.1:8080/v1`; apiKey placeholder `"local"` (not a secret) |
| `/home/hurly/qs-crash-issue-uz03ngatkt/` | Quickshell lid/lock crash report bundle | Y | ~128K; worth keeping for upstream; motivated lock patch |
| `/home/hurly/src/omarchy-task-manager/` | TM source + install | Y | HEAD `1e63b1f4fc7f347d94b4837625b53588495a27af` (`0.5.5-7`); remote github.com/HurlyDesousa/omarchy-task-manager |
| `/home/hurly/src/x1e-ec-tool/` | Upstream clone used to install | Y | HEAD `ce572b3b9ab3aa8e116dbc286e52759c331842a5` (icecream95); install.sh → `/usr/local` |

**Stock Omarchy hooks (not custom):** `install-voxtype.hook`, `setup-agent.hook`, `setup-fingerprint.hook` — no need to package.

---

## 2. Rebuild / reinstall (binaries / large trees)

| Path | Purpose | Exists | Notes |
|---|---|---|---|
| `/home/hurly/.local/bin/omarchy-task-manager` | GTK4 Task Manager | Y | Python; APP_VERSION `0.5.5-7`; rebuild via TM `install.sh` |
| `/home/hurly/.local/bin/omarchy-task-manager-toggle` | Toggle helper | Y | From TM repo |
| `/home/hurly/.local/bin/omarchy-task-manager-waybar` | Waybar helper (legacy) | Y | From TM repo |
| `/home/hurly/.local/bin/omarchy-idle-dim` (+ `.sh` identical) | Dim/restore + kbd off/on | Y | DIM_PCT=25; uses `x1e-ec-tool kb`; hook can regenerate |
| `/home/hurly/.local/bin/omarchy-battery-idle-suspend.sh` | Battery idle suspend loop | Y | Custom; pair with user unit |
| `/home/hurly/.local/bin/omarchy-llama-server` | Wrapper → llama-server | Y | models-dir router mode; GGUF dir `~/.local/share/llm` |
| `/home/hurly/.local/bin/llama-server` / `llama-cli` / `llama-bench` | Thin wrappers to run/ | Y | Point at `~/.local/share/llama.cpp/run` |
| `/home/hurly/.local/share/llama.cpp/` | Official b10819 ubuntu-arm64 unpack | Y | ~62M; cache tarball `~/.cache/llama-b10819-bin-ubuntu-arm64.tar.gz` — re-download preferred over tarball |
| `/home/hurly/.local/share/llm/Qwen2.5-3B-Instruct-Q4_K_M.gguf` | Model weights | Y | **~1.8G — EXCLUDE from restore tarball**; use `scripts/fetch-gguf.sh` |
| `/home/hurly/.local/opt/cursor/Cursor-3.19.13-aarch64.AppImage` | Cursor IDE | Y | ~282M AppImage; symlink `~/.local/bin/cursor` — re-download preferred |
| `/usr/local/bin/x1e-ec-tool` | EC fan/temp/kbd RGB | Y | Not a pacman pkg; from upstream `install.sh` (tool.py → 16723 bytes) |
| `/usr/local/lib/systemd/system/x1e-ec-tool.service` | System unit | Y | ConditionFirmware Vivobook S 15; **never stop** |
| `/usr/local/lib/modules-load.d/x1e-ec-tool.conf` | Module load | Y | From upstream install |

**Other `~/.local/bin` wrappers (Omarchy/mise agents — usually reinstall via Omarchy):** `agy`, `claude`, `codex`, `copilot`, `crush`, `gh`, `ghui`, `grok`, `hey`, `hunk`, `omp`, `opencode`, `ori`, `pi`, `playwright` — list for awareness; not Asus-specific customizations.

---

## 3. System patches (in `/usr` — wiped by Omarchy update; must re-apply)

| Path | Purpose | Exists | Risk |
|---|---|---|---|
| `/usr/share/omarchy/shell/plugins/services/idle/Service.qml` | Idle dim via helper + `dimTimeoutSeconds` | Y | **HIGH** — Omarchy pkg update overwrites; hook `restore-idle-dim.hook` re-copies from `~/.local/share/omarchy/idle-dim/Service.qml`. Stock bak: `Service.qml.bak-predim` |
| `/usr/share/omarchy/shell/plugins/lock/Service.qml` | Lid/resume lock harden | Y | **HIGH** — stabilize timer 500→1500ms; stranded recovery clears crashed lock before beginLock; loadBackground uses `sessionLock.locked \|\| secure`. Bak: `Service.qml.bak-pre-lidlock-20260905212924` |
| `/usr/local/*` x1e-ec-tool | Not in pacman; survives Omarchy update but **not** a fresh reinstall | Y | Re-run `/home/hurly/src/x1e-ec-tool/install.sh` after OS reinstall |

**Preferred packaging:** store as `configs/quickshell/idle.patch` and `configs/quickshell/lock-lidharden.patch` (diff vs stock Omarchy 4.0.1rc3), plus keep patched copies under `~/.local/share/omarchy/` for the post-update hook.

### Idle patch intent (summary)
- Read `idle.dim` from shell.json (`dimTimeoutSeconds`)
- On dim: run `/home/hurly/.local/bin/omarchy-idle-dim dim` (25% backlight + kbd `#000000` if auto_off)
- On restore: `... restore` (brightness + kbd hex from state)

### Lock lid-harden patch intent (summary)
- `sessionLockStabilizeTimer.interval`: 500 → **1500**
- Stranded recovery: clear crashed lock proc + delayed beginLock (avoid FATAL “lockscreen surfaces without active lock”)
- `loadBackground: sessionLock.locked || sessionLock.secure`

---

## 4. Re-auth after restore (paths only — never package contents)

| Path | Notes |
|---|---|
| `/home/hurly/.pi/agent/auth.json` | Exists Y — re-login pi / oauth providers |
| Cursor account / OAuth | AppImage local; re-sign-in after install |
| Any API keys in agent CLIs (`~/.config` for claude/codex/grok/etc.) | Re-auth; do not export |
| LUKS passphrase | Manual at boot (dual-boot) |

---

## 5. Out of scope (kernel / boot — Code owns)

| Item | Detail |
|---|---|
| Repo | `/home/hurly/src/linux-aarch64-vivobook` → github.com/HurlyDesousa/linux-aarch64-vivobook |
| Git HEAD (tree) | `8f147cdfee85d1254306e0763a6742dfe9526bec` (msg mentions pkgrel 9; **installed** pkg is older) |
| Installed | `linux-aarch64-vivobook 7.2.2-6` (+ headers); uname `7.2.0-6-aarch64-vivobook-ARCH` |
| Also present | stock `linux-aarch64 7.2-2` |
| qebspil | `/home/hurly/src/qebspil` HEAD `8e4d9e676a3b3afe136cda9b953a2139ff1a32d0`; `/boot/qebspilaa64.efi` — boot firmware helper; **kernel/boot track** |
| Limine/UKI | Stock Omarchy Snapdragon cmdline (`clk_ignore_unused pd_ignore_unused arm64.nopauth systemd.tpm2_wait=0`) + resume; `default_entry: Omarchy/linux-aarch64-vivobook`. **No custom Limine beyond selecting vivobook kernel / Omarchy hardware defaults.** Do not invent extra Limine patches for desktop restore. |

---

## Version / SHA cheat sheet

| Component | Version / SHA |
|---|---|
| Omarchy | `4.0.1rc3-1.5` |
| omarchy-task-manager | APP_VERSION `0.5.5-7` / git `1e63b1f4fc7f347d94b4837625b53588495a27af` |
| x1e-ec-tool src | `ce572b3b9ab3aa8e116dbc286e52759c331842a5` (upstream; installed via install.sh → `/usr/local`, not pacman) |
| llama.cpp | release **b10819** ubuntu-arm64 |
| Cursor | AppImage **3.19.13** aarch64 |
| GGUF | `Qwen2.5-3B-Instruct-Q4_K_M` @ `~/.local/share/llm/` (fetch, don’t pack) |
| linux-aarch64-vivobook | installed **7.2.2-6** (out of scope) |

---

## Top risks (will be wiped)

1. **`/usr/share/omarchy/shell/plugins/services/idle/Service.qml`** — Omarchy update wipes dim; rely on `restore-idle-dim.hook` + patched copy under `~/.local/share/omarchy/idle-dim/`.
2. **`/usr/share/omarchy/shell/plugins/lock/Service.qml`** — lid harden **not** covered by existing hook; add a post-update hook or patch apply in `install-all.sh` or lose lid/resume crash fix.
3. **`/usr/local` x1e-ec-tool** — gone on full OS reinstall; must re-run upstream `install.sh` before kbd RGB / EC temp service works. **Do not stop the service once installed.**

---

## CLEAN FILE LIST

One path per line for Code Master packaging / fragment export.  
**Excluded:** secrets (`auth.json`, tokens), GGUF blobs, Cursor AppImage binary, llama.cpp binary trees (re-download), kernel packages.

```
/home/hurly/.config/omarchy/shell.json
/home/hurly/.config/omarchy/plugins/sw.art.task-manager/BarWidget.qml
/home/hurly/.config/omarchy/plugins/sw.art.task-manager/manifest.json
/home/hurly/.config/omarchy/plugins/sw.art.kbd-backlight/KbdBacklight.qml
/home/hurly/.config/omarchy/plugins/sw.art.kbd-backlight/manifest.json
/home/hurly/.config/omarchy/hooks/post-update.d/restore-idle-dim.hook
/home/hurly/.config/hypr/autostart.lua
/home/hurly/.config/hypr/input.lua
/home/hurly/.config/hypr/input.lua.bak-pre-scroll-20260905
/home/hurly/.local/state/omarchy/kbd-backlight
/home/hurly/.local/share/omarchy/idle-dim/Service.qml
/home/hurly/.local/share/omarchy/idle-dim/Service.qml.orig
/home/hurly/.local/bin/omarchy-idle-dim
/home/hurly/.local/bin/omarchy-idle-dim.sh
/home/hurly/.local/bin/omarchy-battery-idle-suspend.sh
/home/hurly/.local/bin/omarchy-llama-server
/home/hurly/.local/bin/llama-server
/home/hurly/.local/bin/llama-cli
/home/hurly/.local/bin/llama-bench
/home/hurly/.config/systemd/user/omarchy-llama-server.service
/home/hurly/.config/systemd/user/battery-idle-suspend.service
/home/hurly/.config/systemd/user/omarchy-idle-dim.service.disabled-loginctl
/home/hurly/.local/share/applications/omarchy-task-manager.desktop
/home/hurly/.local/share/applications/cursor.desktop
/home/hurly/.local/share/llm/README-omarchy-llama.md
/home/hurly/.pi/agent/settings.json
/home/hurly/.pi/agent/models.json
/home/hurly/qs-crash-issue-uz03ngatkt/ISSUE_BODY.md
/home/hurly/qs-crash-issue-uz03ngatkt/SUBMIT.sh
/home/hurly/qs-crash-issue-uz03ngatkt/bt-full.txt
/home/hurly/qs-crash-issue-uz03ngatkt/journal-excerpt.txt
/home/hurly/qs-crash-issue-uz03ngatkt/report.txt
/home/hurly/qs-crash-issue-uz03ngatkt/log.qslog.log.gz
/usr/share/omarchy/shell/plugins/services/idle/Service.qml
/usr/share/omarchy/shell/plugins/services/idle/Service.qml.bak-predim
/usr/share/omarchy/shell/plugins/lock/Service.qml
/usr/share/omarchy/shell/plugins/lock/Service.qml.bak-pre-lidlock-20260905212924
/usr/local/lib/systemd/system/x1e-ec-tool.service
/usr/local/lib/modules-load.d/x1e-ec-tool.conf
/home/hurly/src/x1e-ec-tool/install.sh
/home/hurly/src/x1e-ec-tool/tool.py
/home/hurly/src/x1e-ec-tool/x1e-ec-tool.service
/home/hurly/src/x1e-ec-tool/x1e-ec-tool.conf
/home/hurly/src/omarchy-task-manager/install.sh
/home/hurly/src/omarchy-task-manager/omarchy-task-manager
/home/hurly/src/omarchy-task-manager/omarchy-task-manager.desktop
/home/hurly/src/omarchy-task-manager/shell/sw.art.task-manager/BarWidget.qml
/home/hurly/src/omarchy-task-manager/shell/sw.art.task-manager/manifest.json
/home/hurly/src/omarchy-task-manager/shell/sw.art.kbd-backlight/KbdBacklight.qml
/home/hurly/src/omarchy-task-manager/shell/sw.art.kbd-backlight/manifest.json
```

### Explicitly excluded from tarball

```
/home/hurly/.pi/agent/auth.json
/home/hurly/.local/share/llm/Qwen2.5-3B-Instruct-Q4_K_M.gguf
/home/hurly/.local/opt/cursor/Cursor-3.19.13-aarch64.AppImage
/home/hurly/.local/share/llama.cpp/
/home/hurly/.cache/llama-b10819-bin-ubuntu-arm64.tar.gz
/home/hurly/src/linux-aarch64-vivobook/
/boot/
```

### Suggested repo artifacts (fragments/patches — not full `/usr` copies)

```
configs/hypr/autostart.lua.fragment
configs/hypr/input.lua.fragment
configs/omarchy/shell.json.fragment
configs/omarchy/hooks/restore-idle-dim.hook
configs/omarchy/plugins/sw.art.task-manager/   # or install from TM repo
configs/omarchy/plugins/sw.art.kbd-backlight/
configs/state/kbd-backlight.json.default
configs/systemd/user/omarchy-llama-server.service
configs/systemd/user/battery-idle-suspend.service
configs/bin/omarchy-idle-dim
configs/bin/omarchy-battery-idle-suspend.sh
configs/bin/omarchy-llama-server
configs/quickshell/idle.patch
configs/quickshell/lock-lidharden.patch
configs/pi/settings.json.defaults
configs/pi/models.json
docs/qs-crash-issue/   # optional copy of qs-crash-issue-uz03ngatkt
```

---

## Counts

| Bucket | Items (approx) |
|---|---|
| Keep (configs/state/hooks/docs) | 20 |
| Rebuild/reinstall binaries | 14 (+ AppImage/GGUF/llama trees = download) |
| System patches (`/usr`) | 2 QML + x1e `/usr/local` install |
| Re-auth paths | 2+ |
| Out of scope (kernel/boot) | vivobook kernel + qebspil + limine default |
| CLEAN FILE LIST lines | 48 include / 7 exclude classes |
| TODO:INVENTORY placeholders touched | 5 existing + 3 suggested new |

**Inventory file:** `/home/hurly/omarchy-restore-inventory.md`
