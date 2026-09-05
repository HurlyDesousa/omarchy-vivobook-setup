# Vivobook power profiles (Omarchy overlay)

ASUS Vivobook S15 (`S5507QA`, Snapdragon X Elite) adds two **synthetic** power modes on top of stock Omarchy / `power-profiles-daemon` (PPD): **Performance** and **Full Speed Power**. They share PPD `balanced` but drive different `x1e-ec-tool` fan profiles so the tray can offer four distinct thermal presets on battery.

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

`install-all.sh` copies the wrapper scripts to `~/.local/lib/omarchy-vivobook/`, installs post-update hooks, symlinks them into `/usr/share/omarchy/bin/`, and applies the power-panel QML overlay.

After an Omarchy package update, hooks under `~/.config/omarchy/hooks/post-update.d/` re-apply symlinks and QML overlays automatically.

## Synthetic mode mapping

| Tray mode       | PPD profile   | x1e-ec-tool profile | Notes                                      |
|-----------------|---------------|---------------------|--------------------------------------------|
| Power Saver     | `power-saver` | 0                   | Stock PPD path via real `omarchy-powerprofiles-set` |
| Balanced        | `balanced`    | 1                   | Stock PPD path                             |
| Performance     | `balanced`    | 2                   | Synthetic — higher fan curve               |
| Full Speed Power| `balanced`    | 3                   | Synthetic — maximum fan curve              |

Active Vivobook mode is stored in `~/.local/state/omarchy/powerprofiles/vivobook-mode`. Per-context PPD state (`ac` / `battery`) is written under the same directory when synthetic modes bypass the stock setter.

## Wrapper layout

| Path | Role |
|------|------|
| `configs/lib/omarchy-vivobook/omarchy-powerprofiles-list` | Lists real PPD profiles plus `performance` and `full-speed` |
| `configs/lib/omarchy-vivobook/omarchy-powerprofiles-set` | Maps modes to PPD + EC; never stops `x1e-ec-tool.service` |
| `~/.local/lib/omarchy-vivobook/` | Installed copies (chmod +x) |
| `/usr/share/omarchy/bin/omarchy-powerprofiles-*` | Symlinks restored by `restore-vivobook-powerprofiles.hook` |

## Power panel QML polish

Stock Omarchy capitalizes profile slugs (`Full-speed`). Overlays under `configs/omarchy/overlays/panels/power/` are based on the **live laptop dump** (verified SHA256: Panel `bbd4da9e…`, Model `5ed21781…`, matching Omarchy `0af39c52608c`) with Vivobook polish applied:

- **`Model.js`** — `profileLabel()` for human labels (`Full Speed Power`, `Power Saver`, …) and a distinct Nerd Font icon (`󰈐`) for `full-speed`
- **`Panel.qml`** — uses `Model.profileLabel()` instead of naive capitalize

`restore-vivobook-power-panel.hook` copies these onto `/usr/share/omarchy/shell/plugins/panels/power/` (uses `sudo` when the target is not user-writable).

## Troubleshooting

- **Wrappers not used after Omarchy update:** run `~/.config/omarchy/hooks/post-update.d/restore-vivobook-powerprofiles.hook` or re-run `./scripts/install-all.sh`
- **Tray still shows `Full-speed`:** run `restore-vivobook-power-panel.hook` (may need sudo), then `omarchy-restart-shell`
- **Fans unchanged:** confirm `x1e-ec-tool.service` is active and `/usr/local/bin/x1e-ec-tool profile N` works
- **PPD warning on synthetic modes:** expected if PPD rejects a repeat set; EC profile is still applied

## Testing without the laptop user

Set `OMARCHY_POWERPROFILES_STATE_DIR` to a temp directory when exercising the list/set scripts in CI or a VM.
