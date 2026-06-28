[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Code Assistant

Local LLM with MCP tool access and semantic code search for AI coding assistants (Cline, Claude, Cursor, etc.).

**Services:** Ollama (LLM) + LiteLLM (gateway) + MCP Gateway + Embeddings

**Memory:** ~5 GB RAM (with a 3B model)

**Platforms:** `linux/amd64`, `linux/arm64`

## Architecture

```mermaid
graph LR
    U["👤 User"] -->|use| C["🤖 AI client<br/>(Cline, Claude, etc.)"]
    C -->|MCP tools| M["MCP Gateway<br/>(MCP endpoint)"]
    C -->|chat| L["LiteLLM<br/>(AI gateway)"]
    L -->|routes to| O["Ollama<br/>(local LLM)"]
    L -->|MCP protocol| M
    C -->|embed| E["Embeddings<br/>(text → vectors)"]
```

## Services

| Service | Role | Default port |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama)** | Runs local LLM models (llama3, qwen, mistral, etc.) | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm)** | AI gateway with Admin UI — routes requests to Ollama and 100+ providers | `4000` |
| **[MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway)** | Provides MCP tools (filesystem, fetch, GitHub, search, databases) to AI clients | `3000` |
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings)** | Converts text to vectors for semantic search and RAG | `8000` |

> **Note:** The lightweight stacks use shared default container names, ports, and Docker volume names. Run one stack variant at a time with the default compose files; stop the current variant before switching to another.

Default access:

- LiteLLM is published on host port `4000`.
- Embeddings is bound to `127.0.0.1:8000` by default.
- MCP Gateway is internal by default; uncomment its port mapping only when a host-side MCP client needs direct access.
- Ollama is internal to the Docker network; use LiteLLM for host or browser access.

## Quick start

**Requirements:**

- A Linux server (local or cloud) with Docker installed
- Enough RAM for this stack and your selected model (see the memory estimate above)
- For larger LLM models (8B+), 16 GB or more is recommended

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack/stacks/code-assistant
docker compose up -d
```

**Pull a model** (required before making LLM requests):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

Run the health check to verify the services are working:

```bash
# From this stack directory:
../../stack-check.sh

# Or from the repository root:
# ./stack-check.sh
```

> **Tip:** On first start, services may take a few minutes to initialize. If any checks fail, wait and run `../../stack-check.sh` again. Use `docker compose logs` to check progress.

**Get the LiteLLM master key** (used to log into the Admin UI and for direct LLM API requests):

```bash
docker exec litellm litellm_manage --showkey
```

**Access the LiteLLM Admin UI:**

Open `http://<server-ip>:4000/ui` in your browser. Log in with username `admin` and your LiteLLM master key as the password. The UI provides virtual key management, spend tracking, and model configuration.

> **Tip:** In the Admin UI, click **Playground** in the left menu. Select a local model (e.g., `ollama-chat/llama3.2:3b`) from the dropdown and start chatting — a quick way to verify your local LLM is working end-to-end.

**Stop the stack:**

```bash
# Stop and remove containers (data is preserved in Docker volumes)
docker compose down
```

## GPU acceleration (NVIDIA CUDA)

For NVIDIA GPU acceleration, use the CUDA compose file:

```bash
docker compose -f docker-compose.cuda.yml up -d
```

> **Tip:** To avoid adding `-f docker-compose.cuda.yml` to every subsequent `docker compose` command (`down`, `pull`, `logs`, etc.), set it once for your shell session:
>
> ```bash
> export COMPOSE_FILE=docker-compose.cuda.yml
> ```
>
> Then run plain `docker compose` commands as usual. To make it persistent, add `COMPOSE_FILE=docker-compose.cuda.yml` to a `.env` file in this directory. Run `unset COMPOSE_FILE` to switch back to the CPU configuration.

**Requirements:** NVIDIA GPU, [NVIDIA driver](https://www.nvidia.com/en-us/drivers/) 575.57.08+ (Linux) or 576.57+ (Windows), and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed on the host. CUDA images are `linux/amd64` only.

## Running without Docker Compose

If you prefer using `docker run` commands directly, first create a shared network so services can communicate:

```bash
docker network create ai-stack
```

Then start each service on the shared network:

> **Note:** With manual `docker run`, wait for each dependency to become ready before starting services that use it (for example, wait for PostgreSQL and any other dependencies, such as Ollama or MCP, before LiteLLM; if using AnythingLLM, wait for LiteLLM before starting it). The examples below generate one PostgreSQL password variable and reuse it for Postgres and LiteLLM.

```bash
LITELLM_POSTGRES_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)

# PostgreSQL with pgvector (required by LiteLLM; pgvector enables vector storage for RAG)
docker run -d --name litellm-db --restart always \
    --network ai-stack \
    -e POSTGRES_USER=litellm \
    -e POSTGRES_PASSWORD="$LITELLM_POSTGRES_PASSWORD" \
    -e POSTGRES_DB=litellm \
    -v litellm-db:/var/lib/postgresql \
    pgvector/pgvector:pg18-trixie

# Ollama (LLM)
docker run -d --name ollama --restart always \
    --network ai-stack \
    -v ollama-data:/var/lib/ollama \
    -v ollama-shared:/var/lib/ollama-shared \
    hwdsl2/ollama-server

# MCP Gateway
docker run -d --name mcp --restart always \
    --network ai-stack \
    -v mcp-data:/var/lib/mcp \
    -v mcp-shared:/var/lib/mcp-shared \
    hwdsl2/mcp-gateway

# Embeddings
docker run -d --name embeddings --restart always \
    --network ai-stack \
    -p 127.0.0.1:8000:8000 \
    -v embeddings-data:/var/lib/embeddings \
    hwdsl2/embeddings-server

# LiteLLM (AI gateway)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_MCP_URL=http://mcp:3000/mcp \
    -e LITELLM_DATABASE_URL="postgresql://litellm:${LITELLM_POSTGRES_PASSWORD}@litellm-db:5432/litellm" \
    -v litellm-data:/etc/litellm \
    -v ollama-shared:/var/lib/ollama-shared:ro \
    -v mcp-shared:/var/lib/mcp-shared:ro \
    hwdsl2/litellm-server
```

**Note:** The shared network allows services to reach each other by container name (e.g., LiteLLM connects to Ollama via `http://ollama:11434`).

**Pull a model** (required before making LLM requests):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## Usage counts

This stack participates in the project's anonymous aggregate GitHub release asset download counts. Start with `AI_STACK_DISABLE_USAGE_COUNTS=1 docker compose up -d` to disable them; see [Usage counts](../../README.md#usage-counts).

## Customization

Each service can be configured with an optional env file. Copy the example env file from the respective repository, edit it, and uncomment the volume mount in `docker-compose.yml`:

| Service | Env file | Repository |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm) |
| MCP Gateway | `mcp.env` | [docker-mcp-gateway](https://github.com/hwdsl2/docker-mcp-gateway) |
| Embeddings | `embed.env` | [docker-embeddings](https://github.com/hwdsl2/docker-embeddings) |

For detailed configuration options, API reference, and model management, see the documentation in each service's repository.

## Internet-facing deployments

By default, LiteLLM is published on host port `4000`; stack-specific helper APIs are localhost-only or internal unless you change their port mappings. For internet-facing deployments, place a reverse proxy (e.g., [Caddy](https://caddyserver.com/), Nginx, or Traefik) in front of the stack to provide HTTPS, and bind direct HTTP ports such as `4000` to `127.0.0.1` when proxying them. Each service repository includes a detailed [reverse proxy guide](https://github.com/hwdsl2/docker-litellm#using-a-reverse-proxy) with Caddy and nginx examples.

## Backup and restore

For backup/restore instructions, see the [Backup and Restore](../../docs/backup-restore.md) guide.

## Update images

To update all services to the latest versions:

```bash
git pull
docker compose pull
docker compose up -d
../../stack-check.sh
```

After the sub-stack restarts, run `../../stack-check.sh` to confirm the services and generated credential wiring are healthy.

`git pull` updates this repository, including any compose files or helper scripts used by this sub-stack; `docker compose pull` updates the service images.

Your data is preserved in the Docker volumes. **Always [back up](../../docs/backup-restore.md) before upgrading.**

## Connect MCP Gateway to LiteLLM

LiteLLM and MCP Gateway are **automatically wired** when using the compose file or the `docker run` commands above — no manual key setup is needed.

API keys are shared automatically between services via Docker shared volumes:

- MCP Gateway generates an API key on first start and copies it to the `mcp-shared` volume
- LiteLLM reads the MCP key from the shared volume on startup

The `LITELLM_MCP_URL=http://mcp:3000/mcp` environment variable is pre-configured, so all services are connected automatically.

## Usage

> **Note:** The examples below use `jq` to format JSON responses. Install it first if it is not already available.

LiteLLM can reach MCP Gateway inside Docker automatically. For a host-side AI client to use `http://localhost:3000/mcp` directly, uncomment the `3000:3000/tcp` port mapping for the `mcp` service in `docker-compose.yml` and restart it.

```bash
# Get API keys
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)
MCP_KEY=$(docker exec mcp mcp_manage --getkey)
EMBED_KEY=$(docker exec embeddings embed_manage --getkey)

# Use with an AI client (e.g., Cline in VS Code):
# LLM endpoint: http://localhost:4000 (with LITELLM_KEY)
# MCP endpoint: http://localhost:3000/mcp (with MCP_KEY)

# Generate embeddings for semantic code search
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $EMBED_KEY" \
    -d '{"input": "function to handle authentication", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding[:5]'

```
