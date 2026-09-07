# AudioReach topology — ASUS Vivobook S15

Ships the Qualcomm AudioReach topology blob the Vivobook kernel expects at probe time. This is **additive firmware packaging only** — not wired into `scripts/install-all.sh` until Omarchy greenlights audio install.

## What gets installed

| Path | Purpose |
|------|---------|
| `/usr/lib/firmware/qcom/x1e80100/ASUSTeK/vivobook-s15/X1E80100-ASUS-Vivobook-S15-tplg.bin` | AudioReach topology matched to kernel DTS `model = "X1E80100-ASUS-Vivobook-S15"` |

Arch `linux-firmware` uses `/usr/lib/firmware/` (not `/lib/firmware`). A local overlay may also live under `/usr/lib/firmware/updates/` if you prefer not to replace distro files; this package installs the conventional path above.

Upstream source mapping (merged [linux-msm/audioreach-topology PR #22](https://github.com/linux-msm/audioreach-topology/pull/22)):

- Input: `X1E80100-LENOVO-Thinkpad-T14s.m4`
- Output name: `X1E80100-ASUS-Vivobook-S15`
- Install dir: `qcom/x1e80100/ASUSTeK/vivobook-s15`

The Thinkpad T14s topology is the **source** `.m4`; only the Vivobook-named `.bin` is packaged here.

## Build and install (on the Vivobook / Omarchy ARM)

Pinned upstream tip at package time: **`e7b20b2b16cdda18eb8ae143c8d95c4815c0288e`** (see `packages/audioreach-topology-vivobook/PKGBUILD`).

```bash
sudo pacman -S --needed base-devel cmake alsa-utils m4
cd ~/src/omarchy-vivobook-setup/packages/audioreach-topology-vivobook
makepkg -si
```

Or use the thin wrapper (same PKGBUILD, not yet in `install-all.sh`):

```bash
./scripts/install-audioreach-topology-vivobook.sh
```

`makepkg` clones [linux-msm/audioreach-topology](https://github.com/linux-msm/audioreach-topology), builds **only** the Vivobook topology target, and installs the `.bin` — no firmware blobs are committed to this repo.

## Verify

```bash
ls -l /usr/lib/firmware/qcom/x1e80100/ASUSTeK/vivobook-s15/
# expect: X1E80100-ASUS-Vivobook-S15-tplg.bin

# After reboot with vivobook kernel — topology load (card may still be absent; see caveats):
dmesg | grep -iE 'tplg|audioreach|snd|adsp'
```

## Kernel / DTS prerequisites (already in flight)

- **`/sound` on vivobook kernel:** DTS sound node is present on `7.2.x-12+` [linux-aarch64-vivobook](https://github.com/HurlyDesousa/linux-aarch64-vivobook) builds (PR #18 model string `X1E80100-ASUS-Vivobook-S15`).
- **`CONFIG_RESET_GPIO=y`:** Already set in `config.vivobook` for WSA amp reset (`SD_N`) — required before the UCM unmute path can matter once ADSP/audio stack is up.

## UCM — follow-on (not in this package)

Use [alsa-ucm-conf](https://github.com/alsa-project/alsa-ucm-conf) commit `e055d16` / `ucm2/Qualcomm/x1e80100` when wiring mixer/UCM profiles. Do not expect this topology package alone to configure UCM.

## ADSP / PAS caveats (live machine)

On the current S5507QA Omarchy install:

- PAS `0x24` (DTB) and `0x1` (main ADSP) still return **-22** from NS `PAS_INIT`; the kernel uses **attach-to-lite** fallback.
- Installing topology on disk **does not** create `aplay -l` sound cards until full ADSP is authenticated and running.
- **Do not touch** `qebspil` / UEFI AUTH flows as part of this packaging — see [linux-aarch64-vivobook ADSP docs](https://github.com/HurlyDesousa/linux-aarch64-vivobook#adsp--22).

Ship the tplg now so firmware is ready when ADSP/audio comes online.

## Related repos

| Repo | Role |
|------|------|
| [linux-msm/audioreach-topology](https://github.com/linux-msm/audioreach-topology) | Topology source (built at package time) |
| [linux-aarch64-vivobook](https://github.com/HurlyDesousa/linux-aarch64-vivobook) | Vivobook kernel + DTS `model` string |
