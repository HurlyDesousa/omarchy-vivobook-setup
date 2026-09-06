# Install pointers (live capture 2026-09-05)

Do **not** vendor binaries into this repo. Re-fetch / reinstall from these sources.

## omarchy-task-manager (TM)
- Repo: https://github.com/HurlyDesousa/omarchy-task-manager
- Install SHA (live HEAD): `1e63b1f4fc7f347d94b4837625b53588495a27af` (short `1e63b1f`)
- Local checkout used: `~/src/omarchy-task-manager/`
- Install: run repo `install.sh` (ships `~/.local/bin/omarchy-task-manager*` + plugins under `~/.config/omarchy/plugins/sw.art.task-manager/`)

## Login autostart (`sw.art.autostart`)
- Backend CLI: `~/.local/bin/omarchy-autostart-apps` (not vendored — copy from live system or rebuild from your autostart helper repo)
- Config: `configs/omarchy/autostart-apps.json` → `~/.config/omarchy/autostart-apps.json`
- Plugin: `configs/omarchy/plugins/sw.art.autostart/` → `~/.config/omarchy/plugins/sw.art.autostart/`
- Hypr block: `configs/hypr/autostart.lua.fragment` (live snapshot; `omarchy-autostart-apps apply` regenerates when CLI is present)
- Post-update: `restore-vivobook-autostart.hook`

## Cursor IDE (AppImage — exclude binary from tarball)
- Live: `~/.local/opt/cursor/Cursor-3.19.13-aarch64.AppImage` (~282M) → symlink `~/.local/bin/cursor`
- Prefer Cursor download API / official aarch64 AppImage for Linux ARM64 rather than copying the AppImage
- Desktop entry: `~/.local/share/applications/cursor.desktop`
- Cursor download/API: use Cursor product download endpoints for Linux ARM64 AppImage (version pinned live: 3.19.13)

## llama.cpp b10819
- Live unpack: `~/.local/share/llama.cpp/` (~62M) — re-download preferred
- Cache tarball seen: `~/.cache/llama-b10819-bin-ubuntu-arm64.tar.gz`
- Upstream release URL: `https://github.com/ggerganov/llama.cpp/releases/download/b10819/llama-b10819-bin-ubuntu-arm64.tar.gz`
  (verify asset name on the b10819 release page if 404)
- Wrappers: `~/.local/bin/llama-server`, `llama-cli`, `llama-bench` → `~/.local/share/llama.cpp/run`
- Omarchy wrapper unit: `configs/bin/omarchy-llama-server` + `configs/systemd/user/omarchy-llama-server.service`
- **GGUF excluded** — use `scripts/fetch-gguf.sh` / `docs/GGUF.md`; live model was `~/.local/share/llm/Qwen2.5-3B-Instruct-Q4_K_M.gguf`

## x1e-ec-tool (NEVER stop the service)
- Local checkout: `~/src/x1e-ec-tool/` HEAD `ce572b3b9ab3aa8e116dbc286e52759c331842a5` (icecream95 upstream)
- Install path: run `install.sh` from that tree → installs to `/usr/local` (`/usr/local/bin/x1e-ec-tool`, systemd unit under `/usr/local/lib/systemd/system/x1e-ec-tool.service`)
- Hard rule: do **not** reboot / stop `x1e-ec-tool` / kill kbuild while restoring

## Quickshell system patches (wiped by Omarchy update)
- Idle dim: apply `configs/quickshell/idle.patch` to `/usr/share/omarchy/shell/plugins/services/idle/Service.qml`
- Lock lid harden: apply `configs/quickshell/lock-lidharden.patch` to `/usr/share/omarchy/shell/plugins/lock/Service.qml`
- Bar no double-click transparency: apply `configs/omarchy/overlays/bar/bar-no-doubleclick-transparency.patch` to `/usr/share/omarchy/shell/plugins/bar/Bar.qml` (disables `CenterGestureArea.onDoubleClicked` → `toggleTransparency()`; bar-off / SUPER+SHIFT+SPACE unchanged)
- Auto night light (Berlin hyprsunset): overlays under `configs/omarchy/overlays/services/nightlight/` + `bar/indicators/` — see `docs/NIGHTLIGHT-AUTO.md`; toggle wrapper `configs/lib/omarchy-vivobook/omarchy-toggle-nightlight`
- Login autostart bar widget: `configs/omarchy/plugins/sw.art.autostart/` + `autostart-apps.json` — see Login autostart above
- Re-apply via `configs/omarchy/hooks/post-update.d/restore-*.hook` after Omarchy updates
