# Vivobook power profiles (Omarchy overlay)

ASUS Vivobook S15 (`S5507QA`, Snapdragon X Elite) adds two **synthetic** power modes on top of stock Omarchy / `power-profiles-daemon` (PPD): **Performance** and **Full Speed**. Both request PPD’s max-performance CPU profile (`performance`) and drive different `x1e-ec-tool` fan curves. **Full Speed** also pins the Adreno GPU to its max clock; Performance does not. This SoC’s PPD often only exposes `power-saver` and `balanced` (placeholder driver); in that case the wrapper pins CPUFreq to the `performance` governor.

## Prerequisites

- Omarchy with stock `omarchy-powerprofiles-list` / `omarchy-powerprofiles-set` under `/usr/bin/`
- [x1e-ec-tool](https://github.com/artem-senatorov/x1e-ec-tool) at `/usr/local/bin/x1e-ec-tool`
- **`x1e-ec-tool.service` must stay running** — never stop or disable it; EC access is required for fan curves and keyboard RGB

## Install (this repo)

```bash
cd ~/src/omarchy-vivobook-setup   # or your clone path
git pull
./scripts/install-all.sh
omarchy-restart-shell
```

`install-all.sh` copies the wrapper scripts to `~/.local/lib/omarchy-vivobook/`, installs the autodetect helper to `/usr/local/bin/`, installs the udev rule and systemd oneshot (sudo may be required), symlinks wrappers into `/usr/share/omarchy/bin/`, and applies the power-panel QML overlay.

After an Omarchy package update, hooks under `~/.config/omarchy/hooks/post-update.d/` re-apply symlinks and QML overlays automatically.

## Auto defaults (AC / battery)

When Omarchy calls `omarchy-powerprofiles-set` with `ac` or `battery` and **no explicit profile** (or via `autodetect`), the Vivobook wrapper applies:

| Power context | Default mode   | EC profile |
|---------------|----------------|------------|
| AC            | `balanced`      | 1          |
| Battery       | `power-saver`  | 0          |

Event-driven re-apply:

- **Boot / session init** — Omarchy `omarchy-powerprofiles-init` eventually calls the wrapped setter; `omarchy-vivobook-powerprofiles-autodetect` runs the same `autodetect` path on demand.
- **AC plug / unplug** — udev rule `99-omarchy-vivobook-powerprofiles.rules` starts `omarchy-vivobook-powerprofiles-autodetect.service` (UPower `OnBattery` via `busctl` inside the set wrapper).

Explicit tray picks always pass a profile slug and override these defaults until the next context switch or autodetect run.

## EC profile mapping

| Tray mode        | CPU (PPD / CPUFreq) | x1e-ec-tool profile | EC name     |
|------------------|---------------------|---------------------|-------------|
| Power Saver      | PPD `power-saver` | 0                   | Whisper     |
| Balanced         | PPD `balanced`    | 1                   | Standard    |
| Performance      | PPD `performance` (else CPUFreq `performance`); GPU scales | 2 | Performance |
| Full Speed | PPD `performance` (else CPUFreq `performance`); **GPU pinned to 1250 MHz** | 3 | Full speed — **manual max RPM** (not the auto curve) |

Active Vivobook mode is stored in `~/.local/state/omarchy/powerprofiles/vivobook-mode`. Per-context PPD state (`ac` / `battery`) is written under the same directory when synthetic modes bypass the stock setter.

## Wrapper layout

| Path | Role |
|------|------|
| `configs/lib/omarchy-vivobook/omarchy-powerprofiles-list` | Lists real PPD profiles plus `performance` and `full-speed` |
| `configs/lib/omarchy-vivobook/omarchy-powerprofiles-set` | Maps modes to PPD + EC; AC/battery auto defaults; never stops `x1e-ec-tool.service` |
| `configs/lib/omarchy-vivobook/omarchy-vivobook-gpu` | Pins Adreno GPU max clock for Full Speed only; restores ondemand otherwise |
| `configs/systemd/system/omarchy-vivobook-gpu.service` / `.path` | Root oneshot when `vivobook-mode` changes |
| `configs/udev/99-omarchy-vivobook-powerprofiles.rules` | AC plug/unplug → autodetect service |
| `configs/systemd/system/omarchy-vivobook-powerprofiles-autodetect.service` | systemd oneshot unit |
| `~/.local/lib/omarchy-vivobook/` | Installed copies (chmod +x) |
| `/usr/share/omarchy/bin/omarchy-powerprofiles-*` | Symlinks restored by `restore-vivobook-powerprofiles.hook` |

## Power panel QML polish

Stock Omarchy lays out four profile buttons in a single row. Overlays under `configs/omarchy/overlays/panels/power/` use a **2×2 grid**:

- **Row 1:** Power Saver | Balanced
- **Row 2:** Performance | Full Speed

Additional polish:

- **`Model.js`** — `profileLabel()` for human labels (`Full Speed`, `Power Saver`, …), ordered profile list, and 2D keyboard navigation
- **`Panel.qml`** — 2×2 grid; uses `Model.profileLabel()` instead of naive capitalize

`restore-vivobook-power-panel.hook` copies these onto `/usr/share/omarchy/shell/plugins/panels/power/` (uses `sudo` when the target is not user-writable).

## Troubleshooting

- **Wrappers not used after Omarchy update:** run `~/.config/omarchy/hooks/post-update.d/restore-vivobook-powerprofiles.hook` or re-run `./scripts/install-all.sh`
- **Tray still shows `Full-speed` or single row:** run `restore-vivobook-power-panel.hook` (may need sudo), then `omarchy-restart-shell`
- **Wrong profile after plug/unplug:** confirm udev rule and `omarchy-vivobook-powerprofiles-autodetect.service` are installed (`./scripts/install-all.sh` with sudo)
- **Fans unchanged:** confirm `x1e-ec-tool.service` is active and `/usr/local/bin/x1e-ec-tool profile N` works
- **PPD warning on synthetic modes:** expected if PPD rejects a repeat set; EC profile is still applied

## Testing without the laptop user

Set `OMARCHY_POWERPROFILES_STATE_DIR` to a temp directory when exercising the list/set scripts in CI or a VM.
