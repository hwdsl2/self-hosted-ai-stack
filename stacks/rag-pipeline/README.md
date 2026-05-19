[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# RAG Pipeline

Embed documents for semantic search and answer questions with a local LLM.

**Services:** Ollama (LLM) + LiteLLM (gateway) + Embeddings

**Memory:** ~5 GB RAM (with a 3B model)

## Architecture

```mermaid
graph LR
    D["📄 Documents"] -->|embed| E["Embeddings<br/>(text → vectors)"]
    E -->|store| VDB["Vector DB<br/>(Qdrant, Chroma)"]
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
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/rag-pipeline
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

**Requirements:** NVIDIA GPU, [NVIDIA driver](https://www.nvidia.com/en-us/drivers/) 535+, and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed on the host. CUDA images are `linux/amd64` only.

## Running without Docker Compose

If you prefer using `docker run` commands directly, first create a shared network so services can communicate:

```bash
docker network create ai-stack
```

Then start each service on the shared network:

```bash
# PostgreSQL (required by LiteLLM)
docker run -d --name litellm-db --restart always \
    --network ai-stack \
    -e POSTGRES_USER=litellm \
    -e POSTGRES_PASSWORD=litellm \
    -e POSTGRES_DB=litellm \
    -v litellm-db:/var/lib/postgresql \
    postgres:18

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
# Run from the docker-ai-stack root directory
../../stack-check.sh
```

**Access the LiteLLM Admin UI:**

Open `http://<server-ip>:4000/ui` in your browser. Log in with username `admin` and your LiteLLM master key as the password. The UI provides virtual key management, spend tracking, and model configuration.

**Note:** For internet-facing deployments, using a [reverse proxy](#internet-facing-deployments) to add HTTPS is **strongly recommended**. In that case, also change `"4000:4000/tcp"` to `"127.0.0.1:4000:4000/tcp"` in `docker-compose.yml`, to prevent direct access to the unencrypted port.

**Try it in the Playground:**

In the Admin UI, click **Playground** in the left menu. Select a local model (e.g., `ollama/llama3.2:3b`) from the dropdown and start chatting — this is a quick way to verify your local LLM is working end-to-end.

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

## Update images

To update all services to the latest versions:

```bash
docker compose pull
docker compose up -d
```

Your data is preserved in the Docker volumes.

## Example

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# Embed a document chunk
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → Store the vector in your vector DB (Qdrant, Chroma, pgvector, etc.)

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