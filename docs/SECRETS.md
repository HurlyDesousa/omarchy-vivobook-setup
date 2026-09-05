# Secrets and re-authentication checklist

**Nothing in this file is a secret.** It lists what you must re-configure manually after a fresh Omarchy ARM install. **Never commit** tokens, keys, or auth files to this repo.

## After running `scripts/install-all.sh`

Work through this checklist in order:

- [ ] **LUKS passphrase** — verify dual-boot unlock works; expect no remote SSH until you enter the passphrase locally
- [ ] **Cursor OAuth** — launch `~/.local/bin/cursor` and sign in; OAuth tokens live in Cursor's app data, not in this repo
- [ ] **pi (`~/.pi`)** — re-authenticate pi; **never** commit `~/.pi` auth files or tokens
- [ ] **Grok CLI** — re-run `grok auth` or equivalent if your Grok CLI version requires it
- [ ] **GitHub / git credentials** — SSH keys or credential helper for private forks
- [ ] **mise** — `mise install` for tool versions if `~/.config/mise` was not restored from backup
- [ ] **GGUF model** — run `./scripts/fetch-gguf.sh` (see [GGUF.md](GGUF.md)); weights are not in git
- [ ] **omarchy-llama-server** — confirm `:8080` is reachable after pi/llama-local setup
- [ ] **Wi-Fi / VPN** — NetworkManager connections if not in system backup

## Explicitly excluded from this repo

| Item | Reason |
|------|--------|
| `~/.pi/**` auth | Personal API/session tokens |
| Cursor OAuth tokens | App-managed secret store |
| GGUF / model blobs | ~2 GB; use `fetch-gguf.sh` |
| LUKS keys | Hardware/user passphrase only |
| SSH private keys | Use `ssh-copy-id` or secure backup separately |

## Backup recommendation

Before reinstall, archive (encrypted, offline) if you need fast restore:

```bash
# Example — adjust paths after inventory merge
tar czf omarchy-secrets-backup.tar.gz \
  ~/.config/mise \
  ~/.ssh \
  # DO NOT include ~/.pi in git; keep tarball private
```

> **TODO: INVENTORY** — Add any additional secret locations discovered in Omarchy Master's dump (e.g. API keys in `~/.config/*`).
