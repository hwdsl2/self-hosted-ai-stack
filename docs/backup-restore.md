[English](backup-restore.md) | [简体中文](backup-restore-zh.md) | [繁體中文](backup-restore-zh-Hant.md) | [Русский](backup-restore-ru.md)

# Backup and Restore

This guide covers how to back up and restore your Self-Hosted AI Stack data, including API keys, model weights, and service configurations. **Always back up before upgrading images.**

Run `docker compose` commands from the directory where you started the stack. For sub-stacks, this is usually `stacks/<name>/`; for the full stack, this is the repository root.

## What's stored in volumes

Each service stores its data in a named Docker volume:

| Volume | Service | Contains |
|---|---|---|
| `ollama-data` | Ollama | Downloaded models, API key, port/server config |
| `litellm-data` | LiteLLM | API key, proxy configuration |
| `litellm-db` | LiteLLM | PostgreSQL database (usage data, logs) |
| `ai-stack-shared` | Stack | Generated PostgreSQL password for fresh Compose installs |
| `embeddings-data` | Embeddings | Embedding model cache, generated API key |
| `whisper-data` | Whisper | Whisper model cache, generated API key |
| `whisper-live-data` | WhisperLive | Real-time STT model cache, generated API key |
| `kokoro-data` | Kokoro | TTS model/voice cache, generated API key |
| `mcp-data` | MCP Gateway | API key, tool configuration |
| `docling-data` | Docling | Document conversion model cache, generated API key |
| `anythingllm-data` | AnythingLLM | Chat history, workspaces, settings, uploaded documents, **admin password** (`server/.env` with `AUTH_TOKEN`/`JWT_SECRET`, plus the first-run `.initial_admin_password` copy) |
| `caddy-data` | Caddy | TLS certificates, private keys, OCSP staples, ACME account state |
| `caddy-config` | Caddy | Internal Caddy configuration storage |

**Important:** API keys for Ollama, LiteLLM, MCP Gateway, and fresh persistent installs of Whisper, WhisperLive, Kokoro, Embeddings, and Docling are stored inside these volumes. If you lose a volume, you lose its key. Connected clients will need to be updated with new keys.

**Important (AnythingLLM):** The current admin password and its `JWT_SECRET` live in `anythingllm-data` (`server/.env`). The `.initial_admin_password` file is only the first-run password copy and may be stale if you changed the password in Settings. Backing up this volume preserves the current password. Restoring it on a different host re-uses the same password — no need to re-seed.

**Important (Caddy):** If you use the HTTPS proxy overlay, back up `caddy-data`. It contains certificate private keys and ACME account state. Deleting it forces certificate reissuance and may run into certificate authority rate limits.

**Note:** Back up `ai-stack-shared` with `litellm-db`; fresh Compose installs store the generated PostgreSQL password there. The `ollama-shared`, `mcp-shared`, and `litellm-shared` volumes are ephemeral key-sharing volumes used to pass API keys between services automatically. They do not need to be backed up — the keys are already stored in `ollama-data`, `mcp-data`, and `litellm-data` respectively, and are re-copied on every container start.

## Export API keys

Before any maintenance, save your current API keys:

```bash
echo "=== API Keys ===" > ai-stack-keys.txt
echo "Ollama:      $(docker exec ollama ollama_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "LiteLLM:     $(docker exec litellm litellm_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "MCP:         $(docker exec mcp mcp_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "Whisper:     $(docker exec whisper whisper_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "WhisperLive: $(docker exec whisper-live whisper_live_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "Kokoro:      $(docker exec kokoro kokoro_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "Embeddings:  $(docker exec embeddings embed_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "Docling:     $(docker exec docling docling_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo ""
echo "Keys saved to ai-stack-keys.txt"
cat ai-stack-keys.txt
```

Store this file securely — it contains credentials.

## Back up all volumes

Stop the stack first to ensure data consistency:

```bash
# Stop and remove containers (data is preserved in Docker volumes)
docker compose down

# Create backup directory
mkdir -p backups

# Back up all volumes
for vol in ollama-data litellm-data litellm-db ai-stack-shared embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data caddy-data caddy-config; do
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "Backing up $vol..."
    docker run --rm \
      -v "${vol}:/source:ro" \
      -v "$(pwd)/backups:/backup" \
      alpine tar czf "/backup/${vol}.tar.gz" -C /source .
  else
    echo "Skipping $vol (not found)"
  fi
done

echo "Backup complete. Files:"
ls -lh backups/*.tar.gz
```

### Back up a single volume

```bash
# Stop and remove containers (data is preserved in Docker volumes)
docker compose down

docker run --rm \
  -v ollama-data:/source:ro \
  -v "$(pwd)/backups:/backup" \
  alpine tar czf /backup/ollama-data.tar.gz -C /source .
```

### Lightweight stacks

If you're running a lightweight stack (e.g., chat-only), only the relevant volumes exist. The backup loop above automatically skips missing volumes.

### Hot backup (no downtime) for PostgreSQL

If you cannot afford downtime, use `pg_dump` to back up the PostgreSQL database while services are running:

```bash
docker exec litellm-db pg_dump -U litellm litellm | gzip > backups/litellm-db.sql.gz
```

To restore from a SQL dump:

```bash
# Start only the database container
docker compose up -d litellm-db
sleep 5

# Drop and recreate the database, then restore
docker exec litellm-db dropdb -U litellm litellm --if-exists
docker exec litellm-db createdb -U litellm litellm
gunzip -c backups/litellm-db.sql.gz | docker exec -i litellm-db psql -U litellm litellm

# Start remaining services
docker compose up -d
```

### Which volumes need downtime?

| Volume | Hot backup safe? | Notes |
|---|---|---|
| `litellm-db` | ✅ Yes (use `pg_dump`) | PostgreSQL supports consistent hot dumps |
| `embeddings-data` | ✅ Yes | Read-only after initial model download |
| `whisper-data` | ✅ Yes | Read-only after initial model download |
| `whisper-live-data` | ✅ Yes | Read-only after initial model download |
| `kokoro-data` | ✅ Yes | Read-only after initial model download |
| `docling-data` | ✅ Yes | Read-only after initial model download |
| `ollama-data` | ⚠️ Stop first | Writes during model pulls; safe if no pull is in progress |
| `litellm-data` | ⚠️ Stop first | Contains config that may be written on startup |
| `mcp-data` | ⚠️ Stop first | Contains config that may be written on startup |
| `anythingllm-data` | ⚠️ Stop first | Active writes during chat sessions |
| `caddy-data` | ⚠️ Stop first | Contains certificates, private keys, OCSP staples, and ACME account state |
| `caddy-config` | ⚠️ Stop first | Convenient to back up with Caddy, but less critical than `caddy-data` |

## Restore all volumes

**Warning:** Restoring overwrites all existing data in the target volumes, including API keys. Any clients using the old keys will need to be updated.

```bash
# Stop and remove containers (data is preserved in Docker volumes)
docker compose down

# Restore all volumes from backup
for vol in ollama-data litellm-data litellm-db ai-stack-shared embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data caddy-data caddy-config; do
  backup_file="backups/${vol}.tar.gz"
  if [ -f "$backup_file" ]; then
    echo "Restoring $vol..."
    # Create volume if it doesn't exist
    docker volume create "$vol" >/dev/null 2>&1 || true
    # Clear existing data and restore
    docker run --rm \
      -v "${vol}:/target" \
      -v "$(pwd)/backups:/backup:ro" \
      alpine sh -c "rm -rf /target/* /target/.[!.]* 2>/dev/null; tar xzf /backup/${vol}.tar.gz -C /target"
  else
    echo "Skipping $vol (no backup file found)"
  fi
done

# Restart services
docker compose up -d

echo "Restore complete. Verify with: ./stack-check.sh"
```

### Restore a single volume

**Warning:** This overwrites all existing data in the target volume.

```bash
# Stop and remove containers (data is preserved in Docker volumes)
docker compose down

docker volume create ollama-data >/dev/null 2>&1 || true
docker run --rm \
  -v ollama-data:/target \
  -v "$(pwd)/backups:/backup:ro" \
  alpine sh -c "rm -rf /target/* /target/.[!.]* 2>/dev/null; tar xzf /backup/ollama-data.tar.gz -C /target"

docker compose up -d
```

## Migrate to a new server

1. **On the old server:** Back up all volumes and export keys (see above)
2. **Transfer files:** Copy the `backups/` directory and `ai-stack-keys.txt` to the new server
3. **On the new server:**

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack

# Copy backup files into place
cp -r /path/to/backups ./backups

# Restore volumes (creates them automatically)
for vol in ollama-data litellm-data litellm-db ai-stack-shared embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data caddy-data caddy-config; do
  backup_file="backups/${vol}.tar.gz"
  if [ -f "$backup_file" ]; then
    echo "Restoring $vol..."
    docker volume create "$vol" >/dev/null 2>&1 || true
    docker run --rm \
      -v "${vol}:/target" \
      -v "$(pwd)/backups:/backup:ro" \
      alpine sh -c "tar xzf /backup/${vol}.tar.gz -C /target"
  fi
done

# Start the stack
docker compose up -d

# Verify
./stack-check.sh
```

Your API keys, models, and configuration will be preserved. Clients can connect using the same keys.

## Pre-upgrade checklist

Before running `docker compose pull && docker compose up -d`:

1. **Export API keys** — save them to a file (see above)
2. **Back up volumes** — run the backup loop above, or include all critical volumes listed below, including `litellm-db`, `ai-stack-shared`, `anythingllm-data`, and `caddy-data` if using the HTTPS proxy overlay
3. **Pull new images** — `docker compose pull`
4. **Start updated stack** — `docker compose up -d`
5. **Run health check** — `./stack-check.sh`
6. **Verify API keys** — confirm keys are unchanged (they should survive upgrades)

If something breaks after an upgrade:

```bash
# Stop and remove containers (data is preserved in Docker volumes)
docker compose down

# Restore from backup
# (follow the restore steps above)

# Pin images to the previous working version if needed
# Edit docker-compose.yml to use specific image tags
docker compose up -d
```

## Notes

- **Model weights** (in `ollama-data`) can be large (several GB per model). Back up only if re-downloading is impractical (slow internet, custom fine-tuned models).
- **Model caches** (`embeddings-data`, `whisper-data`, `whisper-live-data`, `kokoro-data`, `docling-data`) are downloaded automatically on first start. You can skip backing these up if bandwidth is not a concern — they will be re-downloaded.
- **Critical volumes** that should always be backed up: key/config volumes (`litellm-data`, `litellm-db`, `ai-stack-shared`, `mcp-data`), service data volumes whose models or generated keys you need to preserve (`ollama-data`, `embeddings-data`, `whisper-data`, `whisper-live-data`, `kokoro-data`, `docling-data`), `anythingllm-data` (chat history and workspaces), and `caddy-data` (if using the HTTPS proxy overlay).
- Backups are standard `.tar.gz` archives. You can inspect contents with: `tar tzf backups/ollama-data.tar.gz`

### Volumes by stack

| Stack | Volumes used |
|---|---|
| full stack | Core: `ollama-data`, `litellm-data`, `litellm-db`, `ai-stack-shared`, `embeddings-data`, `whisper-data`, `mcp-data`, `anythingllm-data`, `ollama-shared`, `mcp-shared`, `litellm-shared`; optional when enabled: `docling-data`, `kokoro-data`, `whisper-live-data` |
| chat-only | `ollama-data`, `litellm-data`, `litellm-db`, `ai-stack-shared`, `ollama-shared` |
| chat-ui | `ollama-data`, `litellm-data`, `litellm-db`, `ai-stack-shared`, `anythingllm-data`, `ollama-shared`, `litellm-shared` |
| voice-pipeline | `ollama-data`, `litellm-data`, `litellm-db`, `ai-stack-shared`, `whisper-data`, `kokoro-data`, `ollama-shared` |
| voice-chat | `ollama-data`, `litellm-data`, `litellm-db`, `ai-stack-shared`, `anythingllm-data`, `whisper-data`, `kokoro-data`, `ollama-shared`, `litellm-shared` |
| rag-pipeline | `ollama-data`, `litellm-data`, `litellm-db`, `ai-stack-shared`, `embeddings-data`, `ollama-shared` |
| rag-pipeline-full | `ollama-data`, `litellm-data`, `litellm-db`, `ai-stack-shared`, `embeddings-data`, `docling-data`, `ollama-shared` |
| code-assistant | `ollama-data`, `litellm-data`, `litellm-db`, `ai-stack-shared`, `embeddings-data`, `mcp-data`, `ollama-shared`, `mcp-shared` |
| ai-tools | `ollama-data`, `litellm-data`, `litellm-db`, `ai-stack-shared`, `mcp-data`, `ollama-shared`, `mcp-shared` |
| HTTPS proxy overlay | `caddy-data`, `caddy-config` |
