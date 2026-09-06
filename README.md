# omarchy-vivobook-setup

Durable restore repo for Toby's **ASUS Vivobook S15** (`S5507QA`, Snapdragon X Elite) Omarchy Hyprland customizations after a fresh Omarchy ARM reinstall.

> **Inventory pending:** Omarchy Master will send a live inventory dump soon. Files under `configs/` marked with `TODO: INVENTORY` are placeholders until that merge. See [Inventory merge](#inventory-merge-todo) below.

## Hardware

| Item | Value |
|------|-------|
| Model | ASUS Vivobook S15 `S5507QA` |
| SoC | Qualcomm Snapdragon X Elite |
| Boot | Dual-boot with LUKS (passphrase required at reboot) |

## Related repos

| Repo | Purpose |
|------|---------|
| [omarchy-task-manager](https://github.com/HurlyDesousa/omarchy-task-manager) | GTK4 Task Manager + Quickshell plugins (`task-manager`, `kbd-backlight`; AI tray Cursor/pi/Grok in flight) |
| [linux-aarch64-vivobook](https://github.com/HurlyDesousa/linux-aarch64-vivobook) | Custom ALARM kernel (ADSP, battmgr, camera Phase A/B CCI) |

See [docs/REPOS.md](docs/REPOS.md) for clone URLs, install entry points, and dependency notes.

## Quick restore (fresh Omarchy ARM)

```bash
git clone https://github.com/HurlyDesousa/omarchy-vivobook-setup.git
cd omarchy-vivobook-setup
./scripts/install-all.sh
```

`install-all.sh` is **idempotent**: safe to re-run after pulling updates or when Omarchy Master delivers the inventory merge.

### What the orchestrator does

1. Clone or update related repos (`omarchy-task-manager`, `linux-aarch64-vivobook` when applicable)
2. Run each repo's `install.sh` (or documented equivalent) if present
3. Apply config **fragments** from `configs/` (patches, snippets — not wholesale `/usr` overwrites)
4. Enable Omarchy shell plugins under `~/.config/omarchy/plugins/`
5. Create state directories under `~/.local/state/omarchy/`
6. Print the [SECRETS checklist](docs/SECRETS.md)
7. Remind you to run [scripts/fetch-gguf.sh](scripts/fetch-gguf.sh) for local AI weights (not committed here)

Missing inventory files fail **soft** with clear messages; the rest of the restore continues.

## Manual steps (not automated)

These require human interaction and are intentionally excluded from agent/SSH automation:

- **LUKS passphrase** at every reboot — allow time for manual unlock; do not expect SSH until the desktop session is up
- **Cursor OAuth** — re-authenticate after reinstall ([docs/SECRETS.md](docs/SECRETS.md))
- **`~/.pi` auth** — never committed; re-login to pi after restore
- **GGUF model download** — ~2 GB; use `scripts/fetch-gguf.sh` ([docs/GGUF.md](docs/GGUF.md))

## Customization themes (known)

Until the inventory merge, these are the documented targets. Placeholder configs live in `configs/`.

### Hyprland

- `autostart.lua`: task-manager float rule + login autostart block (Cursor ws1 … Opera ws6, Firefox ws7)
- See `configs/hypr/autostart.lua.fragment` and `configs/omarchy/autostart-apps.json`

### Omarchy shell (`shell.json`)

- Bar plugins installed under `~/.config/omarchy/plugins/`
- See `configs/omarchy/shell.json.fragment`

### State directories

| Path | Contents |
|------|----------|
| `~/.local/state/omarchy/task-manager/` | Task manager persisted state |
| `~/.local/state/omarchy/kbd-backlight` | JSON file: `hex`, `enabled`, `autostart`, `auto_off`, `brightness` |

### Idle policy

- Omarchy/Quickshell idle policy handles screen dim
- `kbd-backlight` `auto_off` affects **keyboard backlight only**, not screen dim

### x1e-ec-tool (fans / keyboard RGB)

- Use [x1e-ec-tool](https://github.com/artem-senatorov/x1e-ec-tool) for fan curves and keyboard RGB
- **Never stop** `x1e-ec-tool.service` — EC access is required for thermal and backlight control

### Local AI toolchain (mise)

| Tool | Notes |
|------|-------|
| `pi` | `llama-local` backend |
| `omarchy-llama-server` | listens on `:8080` (user unit `omarchy-llama-server.service`) |
| `grok` | Grok CLI |
| `cursor` | `~/.local/bin/cursor` |

Configured via mise; details in inventory TODO.

## Repository layout

```
README.md                 # this file — restore steps
scripts/
  install-all.sh          # idempotent orchestrator
  fetch-gguf.sh           # download GGUF weights (not committed)
configs/
  hypr/                   # Hyprland snippets
  omarchy/                # shell.json fragments, plugin stubs
  systemd/                # user unit fragments
  quickshell/             # QML patch files
docs/
  SECRETS.md              # re-auth checklist (no secrets in repo)
  GGUF.md                 # model download docs
  REPOS.md                # related repo pointers
```

## Inventory merge (TODO)

When Omarchy Master sends the live inventory:

1. Search the repo for `TODO: INVENTORY`
2. Replace placeholder fragments with exported configs from the live system
3. Prefer **patches** (`*.patch`) and **JSON fragments** over copying entire trees from `/usr` or `~/.config`
4. Re-run `./scripts/install-all.sh` on a test VM or spare install to validate
5. Remove or resolve each `TODO: INVENTORY` marker in a follow-up commit

## License

Configuration and scripts in this repo are maintained for personal restore use. Third-party projects (Omarchy, Hyprland, x1e-ec-tool, etc.) retain their own licenses.
