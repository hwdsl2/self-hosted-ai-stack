[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# RAG Pipeline

Embed documents for semantic search and answer questions with a local LLM.

**Services:** Ollama (LLM) + LiteLLM (gateway) + Embeddings

**Memory:** ~5 GB RAM (with a 3B model)

**Platforms:** `linux/amd64`, `linux/arm64`

## Architecture

```mermaid
graph LR
    D["📄 Documents"] -->|embed| E["Embeddings<br/>(text → vectors)"]
    E -->|store| VDB["pgvector<br/>(in shared Postgres)"]
    VDB -->|context| L["LiteLLM<br/>(AI gateway)"]
    L -->|routes to| O["Ollama<br/>(local LLM)"]
```

## Services

| Service | Role | Default port |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama)** | Runs local LLM models (llama3, qwen, mistral, etc.) | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm)** | AI gateway with Admin UI — routes requests to Ollama and 100+ providers | `4000` |
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings)** | Converts text to vectors for semantic search and RAG | `8000` |

## Quick start

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack/stacks/rag-pipeline
docker compose up -d
```

**Pull a model** (required before making LLM requests):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
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

> **Note:** With manual `docker run`, wait for each dependency to become ready before starting services that use it (for example, wait for PostgreSQL and any other dependencies, such as Ollama or MCP, before LiteLLM; if using AnythingLLM, wait for LiteLLM before starting it). For production or shared Docker networks, change the default PostgreSQL password before first start and update every matching connection string.

```bash
# PostgreSQL with pgvector (required by LiteLLM; pgvector enables vector storage for RAG)
docker run -d --name litellm-db --restart always \
    --network ai-stack \
    -e POSTGRES_USER=litellm \
    -e POSTGRES_PASSWORD=litellm \
    -e POSTGRES_DB=litellm \
    -v litellm-db:/var/lib/postgresql \
    pgvector/pgvector:pg18-trixie

# Ollama (LLM)
docker run -d --name ollama --restart always \
    --network ai-stack \
    -v ollama-data:/var/lib/ollama \
    -v ollama-shared:/var/lib/ollama-shared \
    hwdsl2/ollama-server

# LiteLLM (AI gateway)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_DATABASE_URL=postgresql://litellm:litellm@litellm-db:5432/litellm \
    -v litellm-data:/etc/litellm \
    -v ollama-shared:/var/lib/ollama-shared:ro \
    hwdsl2/litellm-server

# Embeddings
docker run -d --name embeddings --restart always \
    --network ai-stack \
    -p 127.0.0.1:8000:8000 \
    -v embeddings-data:/var/lib/embeddings \
    hwdsl2/embeddings-server
```

**Note:** The shared network allows services to reach each other by container name (e.g., LiteLLM connects to Ollama via `http://ollama:11434`).

**Pull a model** (required before making LLM requests):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## Verify deployment

After starting the stack, you can verify that all services are running correctly:

```bash
# Run from the self-hosted-ai-stack root directory
../../stack-check.sh
```

**Access the LiteLLM Admin UI:**

Open `http://<server-ip>:4000/ui` in your browser. Log in with username `admin` and your LiteLLM master key as the password. The UI provides virtual key management, spend tracking, and model configuration.

> **Note:** For internet-facing deployments, using a [reverse proxy](#internet-facing-deployments) to add HTTPS is **strongly recommended**. In that case, also change `"4000:4000/tcp"` to `"127.0.0.1:4000:4000/tcp"` in `docker-compose.yml`, to prevent direct access to the unencrypted port.

> **Tip:** In the Admin UI, click **Playground** in the left menu. Select a local model (e.g., `ollama/llama3.2:3b`) from the dropdown and start chatting — a quick way to verify your local LLM is working end-to-end.

## Customization

Each service can be configured with an optional env file. Copy the example env file from the respective repository, edit it, and uncomment the volume mount in `docker-compose.yml`:

| Service | Env file | Repository |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm) |
| Embeddings | `embed.env` | [docker-embeddings](https://github.com/hwdsl2/docker-embeddings) |

For detailed configuration options, API reference, and model management, see the documentation in each service's repository.

## Internet-facing deployments

By default, all services listen over plain HTTP. For internet-facing deployments, place a reverse proxy (e.g., [Caddy](https://caddyserver.com/), Nginx, or Traefik) in front of the stack to provide HTTPS. Each service repository includes a detailed [reverse proxy guide](https://github.com/hwdsl2/docker-litellm#using-a-reverse-proxy) with Caddy and nginx examples.

## Backup and restore

For backup/restore instructions, see the [Backup and Restore](../../docs/backup-restore.md) guide.

## Update images

To update all services to the latest versions:

```bash
git pull
docker compose pull
docker compose up -d
```

`git pull` updates this repository, including any compose files or helper scripts used by this sub-stack; `docker compose pull` updates the service images.

Your data is preserved in the Docker volumes. **Always [back up](../../docs/backup-restore.md) before upgrading.**

## Vector database

The stack's PostgreSQL ships with the [pgvector](https://github.com/pgvector/pgvector) extension, so you can store and query embeddings in the same database that LiteLLM uses — no separate vector database required.

Enable the extension once (the database persists, so this only needs to be done a single time):

```bash
docker exec litellm-db psql -U litellm -d litellm -c 'CREATE EXTENSION IF NOT EXISTS vector;'
```

Verify it is enabled:

```bash
docker exec litellm-db psql -U litellm -d litellm -c "SELECT extname, extversion FROM pg_extension WHERE extname='vector';"
```

You can then create a table with a `vector` column (use the dimension of your embedding model — e.g. `384` for the default `BAAI/bge-small-en-v1.5`) and run similarity search with the `<=>` operator. For larger-scale or hybrid search, you can run a dedicated vector database such as Qdrant or Chroma instead.

## Example

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# Embed a document chunk
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → Store the vector in pgvector (included in the stack's Postgres), or another vector DB such as Qdrant or Chroma.

# Query: embed the question, retrieve context from vector DB, then ask the LLM
curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "ollama/llama3.2:3b",
      "messages": [
        {"role": "system", "content": "Answer using only the provided context."},
        {"role": "user", "content": "What does Docker do?\n\nContext: Docker simplifies deployment by packaging apps in containers."}
      ]
    }' \
    | jq -r '.choices[0].message.content'

```
