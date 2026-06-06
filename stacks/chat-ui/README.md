[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Chat UI

A local ChatGPT-like experience — web-based chat UI powered by a local LLM with an OpenAI-compatible API gateway.

**Services:** Ollama (LLM) + LiteLLM (gateway) + [AnythingLLM](https://github.com/mintplex-labs/anything-llm) (chat UI)

**Memory:** ~5 GB RAM (with a 3B model)

**Platforms:** `linux/amd64`, `linux/arm64`

## Architecture

```mermaid
graph LR
    U["🌐 Browser"] -->|chat| A["AnythingLLM<br/>(chat UI)"]
    A -->|API| L["LiteLLM<br/>(AI gateway)"]
    L -->|routes to| O["Ollama<br/>(local LLM)"]
```

## Services

| Service | Role | Default port |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama)** | Runs local LLM models (llama3, qwen, mistral, etc.) | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm)** | AI gateway with Admin UI — routes requests to Ollama and 100+ providers | `4000` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | Web-based chat UI with workspaces, RAG, and agent support | `3001` |

## Quick start

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/chat-ui
docker compose up -d
```

**Pull a model** (required before making LLM requests):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

**Open the chat UI:**

AnythingLLM is pre-configured to connect to LiteLLM. The API key is shared automatically via a Docker volume — no manual setup needed.

Open `http://<server-ip>:3001` in your browser. The LLM provider, base URL, and model are pre-configured.

On first start, AnythingLLM may take a few minutes to become available (check progress with `docker logs anythingllm`).

**Password-protected by default.** A random admin password is auto-generated on first start, printed once to `docker logs anythingllm`, and saved to `/app/server/storage/.initial_admin_password` inside the `anythingllm-data` volume. It persists across container upgrades. Change it any time from **Settings → Security**.

Retrieve the auto-generated password:

```bash
# From the live logs (only shown on first start):
docker compose logs anythingllm | grep -A2 "FIRST RUN"

# Or at any time from the data volume:
docker exec anythingllm cat /app/server/storage/.initial_admin_password
```

> **Tip:** When exposing AnythingLLM beyond `localhost` or a trusted LAN, put it behind a reverse proxy with TLS so the password is encrypted in transit. See [Using a reverse proxy](#using-a-reverse-proxy) below.

> **Note:** For internet-facing deployments, using a [reverse proxy](#using-a-reverse-proxy) to add HTTPS is **strongly recommended**. Change `"3001:3001/tcp"` and `"4000:4000/tcp"` to `"127.0.0.1:3001:3001/tcp"` and `"127.0.0.1:4000:4000/tcp"` in `docker-compose.yml` to prevent direct access to unencrypted ports.

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

**Requirements:** NVIDIA GPU, [NVIDIA driver](https://www.nvidia.com/en-us/drivers/) 535+, and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed on the host. CUDA images are `linux/amd64` only.

## Running without Docker Compose

If you prefer using `docker run` commands directly, first create a shared network so services can communicate:

```bash
docker network create ai-stack
```

Then start each service on the shared network:

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
    -v litellm-shared:/var/lib/litellm-shared \
    hwdsl2/litellm-server

# AnythingLLM (chat UI)
docker run -d --name anythingllm --restart always \
    --network ai-stack \
    -p 3001:3001 \
    -e STORAGE_DIR=/app/server/storage \
    -e LLM_PROVIDER=generic-openai \
    -e GENERIC_OPEN_AI_BASE_PATH=http://litellm:4000/v1 \
    -e GENERIC_OPEN_AI_MODEL_PREF=ollama/llama3.2:3b \
    -e GENERIC_OPEN_AI_MODEL_TOKEN_LIMIT=131072 \
    -e EMBEDDING_ENGINE=native \
    -e DISABLE_TELEMETRY=true \
    -v anythingllm-data:/app/server/storage \
    -v litellm-shared:/var/lib/litellm-shared:ro \
    -v "$(pwd)/chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro" \
    --entrypoint /bin/bash \
    mintplexlabs/anythingllm \
    /usr/local/bin/chat-ui-bootstrap.sh
```

**Note:** The shared network allows services to reach each other by container name (e.g., AnythingLLM connects to LiteLLM via `http://litellm:4000`).

**Pull a model** (required before making LLM requests):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## Verify deployment

After starting the stack, you can verify that all services are running correctly:

```bash
# Run from the docker-ai-stack root directory
../../stack-check.sh
```

**Access the LiteLLM Admin UI:**

Open `http://<server-ip>:4000/ui` in your browser. Log in with username `admin` and your LiteLLM master key as the password. The UI provides virtual key management, spend tracking, and model configuration.

> **Tip:** In the Admin UI, click **Playground** in the left menu. Select a local model (e.g., `ollama/llama3.2:3b`) from the dropdown and start chatting — a quick way to verify your local LLM is working end-to-end.

## Customization

Each service can be configured with an optional env file. Copy the example env file from the respective repository, edit it, and uncomment the volume mount in `docker-compose.yml`:

| Service | Env file | Repository |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm) |

AnythingLLM is configured through its web UI at `http://<server-ip>:3001`. You can change the LLM provider, model, embedding engine, and other settings in **Settings**. See [AnythingLLM docs](https://docs.useanything.com/) for more details.

**Tip:** If you also run other sub-stacks (e.g., [voice-pipeline](../voice-pipeline/), [rag-pipeline](../rag-pipeline/)), you can point AnythingLLM at those services via its Settings page — for example, using `docker-whisper` for speech-to-text or `docker-embeddings` for vector embeddings.

For detailed configuration options, API reference, and model management, see the documentation in each service's repository.

## Using a reverse proxy

For internet-facing deployments, place a reverse proxy in front of AnythingLLM to handle HTTPS termination. The server works without HTTPS on a local or trusted network, but HTTPS is recommended when the chat UI is exposed to the internet.

Use one of the following addresses to reach the AnythingLLM container from your reverse proxy:

- **`anythingllm:3001`** — if your reverse proxy runs as a container in the **same Docker network** as AnythingLLM (e.g. defined in the same `docker-compose.yml`).
- **`127.0.0.1:3001`** — if your reverse proxy runs **on the host** and port `3001` is published (the default `docker-compose.yml` publishes it).

**Example with [Caddy](https://caddyserver.com/docs/) ([Docker image](https://hub.docker.com/_/caddy))** (automatic TLS via Let's Encrypt, reverse proxy in the same Docker network):

`Caddyfile`:
```
chat.example.com {
  reverse_proxy anythingllm:3001
}
```

**Example with nginx** (reverse proxy on the host):

```nginx
server {
    listen 443 ssl;
    server_name chat.example.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass         http://127.0.0.1:3001;
        proxy_set_header   Host $host;
        proxy_set_header   X-Real-IP $remote_addr;
        proxy_set_header   X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
        proxy_read_timeout 300s;
    }
}
```

**Important:** AnythingLLM includes its own user authentication system — set a strong password on first setup when exposing the service to the internet.

## Backup and restore

For backup/restore instructions, see the [Backup and Restore](../../docs/backup-restore.md) guide.

## Update images

To update all services to the latest versions:

```bash
docker compose pull
docker compose up -d
```

Your data is preserved in the Docker volumes. **Always [back up](../../docs/backup-restore.md) before upgrading.**

## Example

```bash
# Open the chat UI in your browser
open http://localhost:3001
```

Or use the LiteLLM API directly:

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

curl http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "ollama/llama3.2:3b",
      "messages": [{"role": "user", "content": "Hello, how are you?"}]
    }' | jq -r '.choices[0].message.content'
