# Related repositories

Pointers to repos that this restore orchestrator clones, builds, or depends on.

## Primary (installed by `install-all.sh`)

### [omarchy-task-manager](https://github.com/HurlyDesousa/omarchy-task-manager)

**Purpose:** GTK4 Task Manager and Quickshell bar plugins for Omarchy on Hyprland.

| Component | Description |
|-----------|-------------|
| `task-manager` | Quickshell bar plugin — task/process UI |
| `kbd-backlight` | Keyboard backlight control plugin |
| AI tray | Cursor / pi / Grok integration (in flight) |

**Clone:**

```bash
git clone https://github.com/HurlyDesousa/omarchy-task-manager.git
```

**Install:** Run `./install.sh` from the repo root if present; otherwise follow that repo's README.

**State after install:**

- `~/.config/omarchy/plugins/` — enabled plugins
- `~/.local/state/omarchy/task-manager/`
- `~/.local/state/omarchy/kbd-backlight` (JSON file: `hex`, `enabled`, `autostart`, `auto_off`)

---

### [linux-aarch64-vivobook](https://github.com/HurlyDesousa/linux-aarch64-vivobook)

**Purpose:** Custom Arch Linux ARM (ALARM) kernel for the Vivobook S15 Snapdragon platform.

| Feature | Status |
|---------|--------|
| ADSP (audio DSP) | Custom patches |
| `battmgr` | Battery manager |
| Camera Phase A/B CCI | Camera pipeline |

**Clone:**

```bash
git clone https://github.com/HurlyDesousa/linux-aarch64-vivobook.git
```

**Install:** Kernel build/install is **manual** and reboot-required. `install-all.sh` only clones/updates the repo and prints instructions unless an `install.sh` is added upstream.

> **TODO: INVENTORY** — Record exact kernel package name, `mkinitcpio` hooks, and `grub`/`systemd-boot` entry after Omarchy Master dump.

---

### ALSA UCM overlay (local package — **HOLD** from `install-all.sh`)

**Purpose:** Ensure `ucm2/Qualcomm/x1e80100/` has Vivobook S15 DMI regex (`e055d16`+) and T14s-HiFi profile chain when distro `alsa-ucm-conf` is too old.

| Item | Location |
|------|----------|
| Docs | [docs/ALSA-UCM-VIVOBOOK.md](ALSA-UCM-VIVOBOOK.md) |
| Check (read-only) | `scripts/check-alsa-ucm-vivobook.sh` |
| Overlay PKGBUILD | `packages/alsa-ucm-vivobook-overlay/PKGBUILD` |

**Install (manual / when check fails):** `cd packages/alsa-ucm-vivobook-overlay && makepkg -si`

Pinned overlay source: alsa-ucm-conf `00175aa645c482111d096c3d8230f182a875d286`. UCM is useless until `aplay` lists a real card (ADSP). AudioReach tplg firmware is a separate HOLD package (PR #26).

---

## External (referenced, not cloned by default)

### [x1e-ec-tool](https://github.com/artem-senatorov/x1e-ec-tool)

Fan control and keyboard RGB on Snapdragon X Elite laptops via the embedded controller.

- System service: `x1e-ec-tool.service`
- **Live install:** `~/src/x1e-ec-tool/install.sh`
- **Do not stop** this service — thermal and backlight depend on it

### Omarchy (upstream)

Hyprland-based Arch ARM desktop. Base install is assumed before running this restore repo.

---

## Clone directory convention

`install-all.sh` uses:

```
${HOME}/src/omarchy-vivobook-setup/repos/
  omarchy-task-manager/
  linux-aarch64-vivobook/
```

Override with `OMARCHY_REPOS_DIR` if needed.
