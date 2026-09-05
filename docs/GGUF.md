# GGUF model weights

Local AI on the Vivobook uses **GGUF** weights via `pi` / `llama-local` and `llama-server` on port **8080**.

**Do not commit GGUF files to git.** A typical model is ~2 GB and belongs on disk only.

## Download

```bash
./scripts/fetch-gguf.sh
```

Or with overrides:

```bash
GGUF_URL="https://example.com/model.gguf" \
GGUF_DEST="${HOME}/.local/share/models" \
./scripts/fetch-gguf.sh
```

## Default paths (placeholder)

| Variable | Default | Purpose |
|----------|---------|---------|
| `GGUF_DEST` | `$HOME/.local/share/models` | Download directory |
| `GGUF_FILENAME` | `model.gguf` | Local filename |
| `GGUF_URL` | *(unset — required)* | HTTPS URL to the `.gguf` file |

> **TODO: INVENTORY** — Set the canonical `GGUF_URL` and filename after Omarchy Master confirms which model pi/llama-local expects.

## Verify after download

```bash
ls -lh "${GGUF_DEST:-$HOME/.local/share/models}/${GGUF_FILENAME:-model.gguf}"
# Start llama-server (exact command depends on mise/pi setup — TODO: INVENTORY)
curl -s http://127.0.0.1:8080/health || curl -s http://127.0.0.1:8080/v1/models
```

## Git ignore

`*.gguf` is listed in `.gitignore`. If you add models under `configs/`, do not — use `GGUF_DEST` only.
