# ALSA UCM — ASUS Vivobook S15 (X1E80100)

Use Case Manager (UCM) profiles for mixer routing once the Qualcomm ADSP sound card appears. This is **additive packaging/docs only** — **not** wired into `scripts/install-all.sh` until Toby greenlights audio install (same HOLD as AudioReach topology, PR #26).

## How Vivobook maps to upstream UCM

Upstream [alsa-ucm-conf](https://github.com/alsa-project/alsa-ucm-conf) does **not** ship a Vivobook-specific profile file. The Vivobook S15 (`S5507QA`) matches the existing **ThinkPad T14s Gen 6** DMI block in `ucm2/Qualcomm/x1e80100/x1e80100.conf`:

| Step | File | Role |
|------|------|------|
| DMI match | `x1e80100.conf` | `If.LENOVOT14s` regex includes `ASUSTeK COMPUTER.*ASUS ... Vivobook S 15` |
| Profile selector | `LENOVO-T14s.conf` | `SectionUseCase."HiFi"` → `T14s-HiFi.conf` |
| Mixer graph | `T14s-HiFi.conf` | 2× WSA speakers, DMICs, headset path (shared with T14s / Zenbook A14 / etc.) |

Vivobook support landed in commit **`e055d16`** (“add ASUS Vivobook S 15 support”) — a one-line regex extension on the LENOVOT14s `If` block. Later tip commits widened the same regex (Vivobook 14/16, Ideapad, …); Vivobook S 15 remains in that block.

Pinned overlay source (when distro `alsa-ucm-conf` is too old): **`00175aa645c482111d096c3d8230f182a875d286`** (alsa-ucm-conf master tip at packaging time). See `packages/alsa-ucm-vivobook-overlay/PKGBUILD`.

## Prerequisites (already in flight)

| Item | Status |
|------|--------|
| DTS `/sound` on [linux-aarch64-vivobook](https://github.com/HurlyDesousa/linux-aarch64-vivobook) `7.2.2-12+` | Present |
| AudioReach tplg | `audioreach-topology-vivobook` (PR #26) — separate package |
| `CONFIG_RESET_GPIO=y` in vivobook kernel | Set (`SD_N` for WSA amp reset) |
| Full ADSP / PAS auth | **Not yet** — PAS still lite (`-22`); see caveats below |

UCM configures ALSA mixer routes **after** a real `snd` card exists. It does not replace topology firmware or fix ADSP attach.

## Quick check

```bash
./scripts/check-alsa-ucm-vivobook.sh
```

Exit `0` = distro (or prior overlay) already has Vivobook regex + required profile chain. Exit `1` = missing or too old → see overlay package below.

## Manual verify

```bash
# Installed alsa-ucm-conf package (version / build date)
pacman -Qi alsa-ucm-conf

# UCM tree for X1E80100
ls -l /usr/share/alsa/ucm2/Qualcomm/x1e80100/
grep -F 'Vivobook S 15' /usr/share/alsa/ucm2/Qualcomm/x1e80100/x1e80100.conf

# DMI string UCM matches (board_vendor-product_family-board_name)
printf '%s-%s-%s\n' \
  "$(cat /sys/devices/virtual/dmi/id/board_vendor)" \
  "$(cat /sys/devices/virtual/dmi/id/product_family)" \
  "$(cat /sys/devices/virtual/dmi/id/board_name)"

# Once aplay shows a real card (not only Dummy) — list UCM use cases:
aplay -l
alsaucm -c 0 list _verbs
alsaucm -c 0 set _verb HiFi
alsaucm -c 0 list _configs
```

On the live machine today, `aplay -l` may still list only **Dummy** until full ADSP is up. Running `alsaucm` before a card exists will fail — that is expected; stage UCM now so routing is ready when audio comes online.

## Overlay install (only if check fails)

When `check-alsa-ucm-vivobook.sh` reports missing Vivobook regex or profile files:

```bash
sudo pacman -S --needed alsa-ucm-conf base-devel
cd ~/src/omarchy-vivobook-setup/packages/alsa-ucm-vivobook-overlay
makepkg -si
```

The overlay vendors **only** the three x1e80100-specific conf files from alsa-ucm-conf git tip (no binary blobs in this repo). It requires base `alsa-ucm-conf` for shared includes (`/codecs/wcd938x`, `wsa884x`, `card-init.conf`, etc.).

Re-run `./scripts/check-alsa-ucm-vivobook.sh` after install.

## ADSP / PAS caveats (live machine)

- PAS `0x24` (DTB) and `0x1` (main ADSP) still return **-22** from NS `PAS_INIT`; kernel uses **attach-to-lite** fallback.
- Topology + UCM on disk **do not** create `aplay -l` sound cards until full ADSP is authenticated and running.
- **Do not touch** `qebspil` / UEFI AUTH flows as part of this packaging.
- PAS parallel work is **separate** from UCM; UCM is useless until `aplay` lists a real Qualcomm card.

## HOLD policy

| Action | Status |
|--------|--------|
| `scripts/install-all.sh` | **No UCM wiring** — do not add until greenlight |
| `scripts/check-alsa-ucm-vivobook.sh` | Safe to run anytime (read-only) |
| Overlay `makepkg -si` | Manual / when check fails — confirm with Toby before production install |

## Related

| Doc / package | Role |
|---------------|------|
| AudioReach tplg (PR #26) | Topology `.bin` prerequisite |
| [REPOS.md](REPOS.md) | Repo index |
| [INSTALL-POINTERS.md](INSTALL-POINTERS.md) | Live install capture pointers |
