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

### AudioReach topology (local package — **HOLD** from `install-all.sh`)

**Purpose:** Build and install `X1E80100-ASUS-Vivobook-S15-tplg.bin` from [linux-msm/audioreach-topology](https://github.com/linux-msm/audioreach-topology) at package time (no blobs in git).

| Item | Location |
|------|----------|
| PKGBUILD | `packages/audioreach-topology-vivobook/PKGBUILD` |
| Docs | [docs/AUDIOREACH-TOPOLOGY.md](AUDIOREACH-TOPOLOGY.md) |
| Wrapper | `scripts/install-audioreach-topology-vivobook.sh` |

**Install (manual / when greenlit):**

```bash
cd packages/audioreach-topology-vivobook && makepkg -si
# or: ./scripts/install-audioreach-topology-vivobook.sh
```

Pinned upstream: `e7b20b2b16cdda18eb8ae143c8d95c4815c0288e`. See docs for ADSP/PAS and UCM follow-on caveats.

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
