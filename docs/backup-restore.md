[English](backup-restore.md) | [简体中文](backup-restore-zh.md) | [繁體中文](backup-restore-zh-Hant.md) | [Русский](backup-restore-ru.md)

# Backup and Restore

This guide covers how to back up and restore your Docker AI Stack data, including API keys, model weights, and service configurations. **Always back up before upgrading images.**

## What's stored in volumes

Each service stores its data in a named Docker volume:

| Volume | Service | Contains |
|---|---|---|
| `ollama-data` | Ollama | Downloaded models, API key, port/server config |
| `litellm-data` | LiteLLM | API key, proxy configuration |
| `embeddings-data` | Embeddings | Embedding model cache |
| `whisper-data` | Whisper | Whisper model cache |
| `kokoro-data` | Kokoro | TTS model/voice cache |
| `mcp-data` | MCP Gateway | API key, tool configuration |

**Important:** API keys for Ollama, LiteLLM, and MCP Gateway are auto-generated on first start and stored inside these volumes. If you lose the volume, you lose the key. Connected clients will need to be updated with new keys.

## Export API keys

Before any maintenance, save your current API keys:

```bash
echo "=== API Keys ===" > ai-stack-keys.txt
echo "Ollama:  $(docker exec ollama ollama_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo "LiteLLM: $(docker exec litellm litellm_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo "MCP:     $(docker exec mcp mcp_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo ""
echo "Keys saved to ai-stack-keys.txt"
cat ai-stack-keys.txt
```

Store this file securely — it contains credentials.

## Back up all volumes

Stop the stack first to ensure data consistency:

```bash
# Stop services
docker compose down

# Create backup directory
mkdir -p backups

# Back up all volumes
for vol in ollama-data litellm-data embeddings-data whisper-data kokoro-data mcp-data; do
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
docker compose down

docker run --rm \
  -v ollama-data:/source:ro \
  -v "$(pwd)/backups:/backup" \
  alpine tar czf /backup/ollama-data.tar.gz -C /source .
```

### Lightweight stacks

If you're running a lightweight stack (e.g., chat-only), only the relevant volumes exist. The backup loop above automatically skips missing volumes.

## Restore all volumes

**Warning:** Restoring overwrites all existing data in the target volumes, including API keys. Any clients using the old keys will need to be updated.

```bash
# Stop services
docker compose down

# Restore all volumes from backup
for vol in ollama-data litellm-data embeddings-data whisper-data kokoro-data mcp-data; do
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
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack

# Copy backup files into place
cp -r /path/to/backups ./backups

# Restore volumes (creates them automatically)
for vol in ollama-data litellm-data embeddings-data whisper-data kokoro-data mcp-data; do
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
2. **Back up volumes** — at minimum, back up `ollama-data`, `litellm-data`, and `mcp-data`
3. **Pull new images** — `docker compose pull`
4. **Start updated stack** — `docker compose up -d`
5. **Run health check** — `./stack-check.sh`
6. **Verify API keys** — confirm keys are unchanged (they should survive upgrades)

If something breaks after an upgrade:

```bash
# Stop the broken stack
docker compose down

# Restore from backup
# (follow the restore steps above)

# Pin images to the previous working version if needed
# Edit docker-compose.yml to use specific image tags
docker compose up -d
```

## Notes

- **Model weights** (in `ollama-data`) can be large (several GB per model). Back up only if re-downloading is impractical (slow internet, custom fine-tuned models).
- **Model caches** (`embeddings-data`, `whisper-data`, `kokoro-data`) are downloaded automatically on first start. You can skip backing these up if bandwidth is not a concern — they will be re-downloaded.
- **Critical volumes** that should always be backed up: `ollama-data` (if custom models), `litellm-data`, `mcp-data` (contain API keys and configuration).
- Backups are standard `.tar.gz` archives. You can inspect contents with: `tar tzf backups/ollama-data.tar.gz`
