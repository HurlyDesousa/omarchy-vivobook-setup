# Install pointers (live AsusLaptop, 2026-09-05)

Pinned versions/commits that the live Vivobook S15 (`S5507QA`, Snapdragon X Elite, Omarchy ARM) was running when the inventory was taken. Restore to these first; upgrade afterwards on purpose, not by accident.

| Component | Pin | Source |
|-----------|-----|--------|
| omarchy-task-manager | commit `1e63b1f` (0.5.5-7) | [HurlyDesousa/omarchy-task-manager@1e63b1f](https://github.com/HurlyDesousa/omarchy-task-manager/commit/1e63b1f4fc7f347d94b4837625b53588495a27af) |
| Cursor (linux-arm64) | stable via download API | `https://cursor.com/api/download?platform=linux-arm64&releaseTrack=stable` |
| llama.cpp | release `b10819` | [ggml-org/llama.cpp b10819](https://github.com/ggml-org/llama.cpp/releases/tag/b10819) |
| x1e-ec-tool | commit `ce572b3` | local build; see below |
| pi (coding agent) | `0.85.1`, provider `llama-local` | npm `@mariozechner/pi-coding-agent` |

## omarchy-task-manager @ `1e63b1f`

```bash
git clone https://github.com/HurlyDesousa/omarchy-task-manager.git
cd omarchy-task-manager
git checkout 1e63b1f
./install.sh
omarchy-restart-shell
```

`install.sh` at this commit installs `~/.local/bin/omarchy-task-manager{,-toggle,-waybar}`, the desktop entry, the marked `-- omarchy-task-manager begin/end` block in `~/.config/hypr/autostart.lua` (see `configs/hypr/autostart.lua.fragment`), and the two Quickshell plugins `sw.art.task-manager` and `sw.art.kbd-backlight` under `~/.config/omarchy/plugins/`. It patches `~/.config/omarchy/shell.json` to place `sw.art.task-manager` after `omarchy.weather` and `sw.art.kbd-backlight` left of `omarchy.clock` (matches `configs/omarchy/shell.json.fragment`).

## Cursor (linux-arm64)

Cursor publishes the current build through a JSON API; do not hardcode an AppImage URL.

```bash
json="$(curl -fsSL 'https://cursor.com/api/download?platform=linux-arm64&releaseTrack=stable')"
url="$(printf '%s' "$json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["downloadUrl"])')"
mkdir -p ~/.local/bin ~/.local/opt/cursor
curl -fL -o ~/.local/opt/cursor/Cursor.AppImage "$url"
chmod +x ~/.local/opt/cursor/Cursor.AppImage
ln -sf ~/.local/opt/cursor/Cursor.AppImage ~/.local/bin/cursor
```

The API also returns `version`, `commitSha`, `rehUrl` (remote server tarball), and on the stable track `debUrl`/`rpmUrl`. At inventory time it returned Cursor `3.19.13` (`dd066f33…`). Re-authenticate afterwards (OAuth; see `docs/SECRETS.md`).

## llama.cpp `b10819`

Prebuilt arm64 Linux assets exist for this tag: `llama-b10819-bin-ubuntu-arm64.tar.gz` (CPU) and `llama-b10819-bin-ubuntu-vulkan-arm64.tar.gz` (Vulkan, Adreno). Ubuntu builds link against glibc and generally run on Arch ARM; build from source if they do not.

```bash
tag=b10819
curl -fL -o /tmp/llama.tar.gz \
  "https://github.com/ggml-org/llama.cpp/releases/download/${tag}/llama-${tag}-bin-ubuntu-arm64.tar.gz"
mkdir -p ~/.local/opt/llama.cpp && tar -xzf /tmp/llama.tar.gz -C ~/.local/opt/llama.cpp --strip-components=1
ln -sf ~/.local/opt/llama.cpp/llama-server ~/.local/bin/llama-server
```

Source build alternative:

```bash
git clone https://github.com/ggml-org/llama.cpp.git && cd llama.cpp && git checkout b10819
cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j"$(nproc)" --target llama-server
install -Dm755 build/bin/llama-server ~/.local/bin/llama-server
```

`llama-server` listens on `127.0.0.1:8080` via `configs/systemd/user/llama-server.service`; the served model alias is `local` (what `configs/pi/models.json` expects). Weights: `docs/GGUF.md`.

## x1e-ec-tool @ `ce572b3`

Fan control and keyboard RGB on Snapdragon X Elite laptops through the embedded controller. Installed as `/usr/local/bin/x1e-ec-tool` plus the system unit `x1e-ec-tool.service`. **Never stop the service** once running; both the task manager fan profiles and the kbd-backlight plugin depend on it.

Commit `ce572b3` is the checkout that was live on the laptop. It does not resolve on the public upstream fetched during this inventory, so it is either a local/private commit or a fork; confirm the remote with `git -C <checkout> remote -v` on the laptop before relying on it. Upstream reference: [x1e-ec-tool](https://github.com/artem-senatorov/x1e-ec-tool).

```bash
git clone <x1e-ec-tool remote> && cd x1e-ec-tool && git checkout ce572b3
# build/install per that repo's README, then:
sudo systemctl enable --now x1e-ec-tool.service
sudo usermod -aG i2c hurly   # kbd-backlight and fan profiles call the tool without sudo
```

## pi `0.85.1` with `llama-local`

```bash
npm install -g @mariozechner/pi-coding-agent@0.85.1   # or via mise: mise use -g npm:@mariozechner/pi-coding-agent@0.85.1
```

Config lives in `~/.pi/agent/`:

| File | Repo source | Note |
|------|-------------|------|
| `~/.pi/agent/models.json` | `configs/pi/models.json` | provider `llama-local` → `http://127.0.0.1:8080/v1` |
| `~/.pi/agent/settings.json` | `configs/pi/settings.json.defaults` | copied only if missing; `defaultProvider: llama-local`, `defaultModel: local` |

`apiKey` in `models.json` is a dummy value (`llama-local`); llama-server ignores it, but pi hides keyless models from `/model` without one. Never commit `~/.pi/agent/auth.json` or anything else under `~/.pi/`.

Smoke test:

```bash
systemctl --user start llama-server.service
curl -s http://127.0.0.1:8080/v1/models
pi --model llama-local/local -p 'say hi'
```
