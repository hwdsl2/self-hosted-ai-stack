[English](troubleshooting.md) | [简体中文](troubleshooting-zh.md) | [繁體中文](troubleshooting-zh-Hant.md) | [Русский](troubleshooting-ru.md)

# Troubleshooting

This guide helps diagnose Self-Hosted AI Stack issues before changing configuration or opening an issue.

## Quick triage

Start with these checks:

```bash
# Show container state and published ports
docker compose ps

# Run the stack health check
./stack-check.sh

# Check recent logs for one service
docker compose logs --tail=100 <service>
```

If you started the stack with multiple compose files, use the same files for diagnostic commands:

```bash
docker compose -f docker-compose.yml -f docker-compose.proxy.yml ps
docker compose -f docker-compose.cuda.yml -f docker-compose.proxy.yml logs --tail=100 litellm
```

For Podman, `stack-check.sh` auto-detects the engine. You can also force it:

```bash
CONTAINER_ENGINE=podman ./stack-check.sh
```

## Startup and readiness

On first start, services may take a few minutes to initialize. Model downloads, database startup, and AnythingLLM initialization can all delay readiness.

If `./stack-check.sh` fails immediately after startup:

1. Wait a few minutes.
2. Run `./stack-check.sh` again.
3. Check the logs for the failing service.

Useful service log commands:

```bash
docker compose logs --tail=100 ollama
docker compose logs --tail=100 litellm
docker compose logs --tail=100 mcp
docker compose logs --tail=100 anythingllm
```

LiteLLM depends on Ollama, MCP Gateway, and PostgreSQL. AnythingLLM depends on LiteLLM. If a dependency is still starting, downstream services may not be ready yet.

## Ollama and local model issues

The stack starts Ollama automatically, but you must pull at least one model before sending LLM requests:

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

List downloaded models:

```bash
docker exec ollama ollama_manage --listmodels
```

If LiteLLM or AnythingLLM reports model errors, first confirm that the model exists in Ollama and that `./stack-check.sh` reports a successful LiteLLM routing test.

For image-specific Ollama issues, use the `docker-ollama` repository. For upstream Ollama behavior unrelated to this Docker image, use the upstream Ollama issue tracker.

## LiteLLM issues

LiteLLM is exposed on port `4000` by default. The Admin UI is available at:

```text
http://<server-ip>:4000/ui
```

Use username `admin` and the LiteLLM master key as the password.

Show the LiteLLM master key:

```bash
docker exec litellm litellm_manage --showkey
```

Check the LiteLLM health endpoint:

```bash
curl http://localhost:4000/health/liveliness
```

If local Ollama models do not work through LiteLLM:

- Confirm an Ollama model is downloaded.
- Confirm `LITELLM_OLLAMA_BASE_URL=http://ollama:11434` is present in the compose file or env file.
- Check `docker compose logs --tail=100 litellm`.
- Run `./stack-check.sh` and review the LiteLLM routing check.

The compose files automatically share Ollama and MCP API keys with LiteLLM through Docker volumes. Avoid deleting `ollama-data`, `mcp-data`, or `litellm-data` unless you have a backup.

## MCP Gateway issues

MCP Gateway runs inside the Docker network on port `3000`. Its port is not exposed to the host by default in the main compose file.

Show the MCP Gateway API key:

```bash
docker exec mcp mcp_manage --showkey
```

Check its health endpoint from inside the container:

```bash
docker exec mcp curl -sf http://127.0.0.1:3000/health
```

If an external MCP client needs direct access, uncomment the `3000:3000` port mapping in `docker-compose.yml`, then restart the service. For internet-facing access, put it behind HTTPS and keep the API key secret.

## AnythingLLM issues

AnythingLLM is exposed on port `3001` by default:

```text
http://<server-ip>:3001
```

On first start, a random admin password is generated and saved in the `anythingllm-data` volume. Retrieve it with:

```bash
docker exec anythingllm cat /app/server/storage/.initial_admin_password
```

Or check the first-start logs:

```bash
docker compose logs anythingllm | grep -A4 "FIRST RUN"
```

If AnythingLLM cannot talk to the local model:

- Confirm LiteLLM is reachable at `http://litellm:4000/v1` from inside the Docker network.
- Confirm the model `ollama/llama3.2:3b` exists, or update AnythingLLM to use a model that exists.
- Check `docker compose logs --tail=100 anythingllm`.

If you changed the AnythingLLM password in Settings, `.initial_admin_password` may no longer match the current password. Back up `anythingllm-data` before upgrades or migrations.

## Optional services

In the full compose file, Embeddings and Whisper are enabled by default. Kokoro, Docling, and WhisperLive are commented out to reduce memory usage.

To enable a commented service:

1. Uncomment the service in `docker-compose.yml` or `docker-compose.cuda.yml`.
2. Uncomment its named volume at the bottom of the file.
3. Add or mount the service env file if you need custom settings.
4. Run `docker compose up -d`.

Service-specific docs:

| Service | Repository |
|---|---|
| Ollama | https://github.com/hwdsl2/docker-ollama |
| LiteLLM | https://github.com/hwdsl2/docker-litellm |
| Embeddings | https://github.com/hwdsl2/docker-embeddings |
| Whisper | https://github.com/hwdsl2/docker-whisper |
| WhisperLive | https://github.com/hwdsl2/docker-whisper-live |
| Kokoro | https://github.com/hwdsl2/docker-kokoro |
| MCP Gateway | https://github.com/hwdsl2/docker-mcp-gateway |
| Docling | https://github.com/hwdsl2/docker-docling |

## GPU and CUDA

For NVIDIA GPU acceleration, start the CUDA compose file:

```bash
docker compose -f docker-compose.cuda.yml up -d
```

Requirements:

- NVIDIA GPU
- NVIDIA driver
- NVIDIA Container Toolkit
- `linux/amd64` host for CUDA images

If GPU acceleration is not used:

- Confirm you started `docker-compose.cuda.yml`, not `docker-compose.yml`.
- Check `docker compose logs --tail=100 ollama` and, if enabled, `docker compose logs --tail=100 whisper`.
- Confirm the host can run GPU containers with the NVIDIA Container Toolkit.

For Podman, the Compose `deploy.resources` GPU block is not used. Follow the README's Podman CDI instructions.

## Reverse proxy and internet-facing deployments

The stack includes a Caddy overlay for HTTPS:

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.yml -f docker-compose.proxy.yml up -d
```

In proxy mode, Caddy is the public listener on ports `80` and `443`. AnythingLLM and LiteLLM direct ports are rebound to `127.0.0.1`.

Check Caddy logs:

```bash
docker logs ai-stack-caddy
```

If Caddy cannot get a certificate, check:

- DNS `A`/`AAAA` record points to this server.
- Ports `80/tcp` and `443/tcp` are reachable from the internet.
- No other service is using ports `80` or `443`.
- The `DOMAIN` and `ACME_EMAIL` values are correct.

When exposing optional services publicly, use the generated API keys where present. For existing no-key deployments, set API keys via the relevant env files or put the services behind proxy authentication before publishing them.

## Volumes, backups, and updates

API keys, model caches, chat history, service config, and Caddy certificate state are stored in Docker volumes. Back up before upgrades, migrations, or destructive cleanup.

See the full backup guide:

- [Backup and Restore](backup-restore.md)

Avoid deleting volumes while troubleshooting unless you have a current backup. Deleting volumes can remove API keys, model caches, AnythingLLM data, LiteLLM configuration, MCP Gateway settings, optional service keys, and Caddy certificates.

After updating images, run:

```bash
docker compose pull
docker compose up -d
./stack-check.sh
```

## Where to file issues

File an issue in `self-hosted-ai-stack` for:

- Compose file problems
- Cross-service wiring issues
- Stack startup or health-check problems
- Caddy overlay issues in this repository
- Documentation issues in this repository

File an issue in an individual service repository for:

- Image-specific behavior
- Service-specific env options
- Service-specific API behavior
- Service-specific model download or cache behavior

File upstream if the issue is in the upstream application itself rather than the Docker image or stack wiring.

## What to include in an issue

Please include:

- Host OS and architecture
- Docker or Podman version
- Compose files used, for example `docker-compose.yml` or `docker-compose.cuda.yml`
- CPU or GPU mode
- Output of `docker compose ps`
- Output of `./stack-check.sh`
- Relevant logs, for example `docker compose logs --tail=100 litellm`
- Any custom env files or compose changes, with secrets redacted

Redact API keys, passwords, provider keys, tokens, public URLs with private paths, and any sensitive log content before posting.
