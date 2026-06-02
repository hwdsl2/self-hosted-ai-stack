[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Docker AI Stack

[![Docker Compose AI Stack](docs/images/ai-stack.svg)](https://docs.docker.com/compose/) &nbsp;[![Docker Pulls](https://raw.githubusercontent.com/hwdsl2/badges/main/img/docker-pulls-ai-stack.svg)](https://hub.docker.com/u/hwdsl2) &nbsp;[![License: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

<p align="center">
  <img src="docs/images/docker-ai-stack-overview.png"
       alt="Docker AI Stack: deploy a complete self-hosted AI stack with one command"
       width="100%">
</p>

Includes Ollama, LiteLLM, AnythingLLM, Whisper, MCP Gateway, Embeddings, Docling, and Kokoro — fully configured and ready to run with Docker Compose.

- Zero-config: all services auto-configure on first start
- Secure: Ollama, LiteLLM, and MCP Gateway generate API keys automatically
- Private: runs locally by default with optional external provider support via LiteLLM
- Optional auth: Whisper, WhisperLive, Kokoro, Embeddings, and Docling work without API keys by default (set keys via env files for public deployments)
- [Lightweight stacks](#lightweight-stacks) for lower memory requirements (as low as ~4.5 GB)
- GPU acceleration via NVIDIA CUDA
- Multi-arch: `linux/amd64`, `linux/arm64`

## Community

- 📬 [Subscribe for project updates](https://selfhostedstack.beehiiv.com/subscribe?utm_campaign=ai) (1–2 emails/month) — get free AI and VPN deployment guides (PDF)
- 💬 Join the [r/selfhostedstack](https://www.reddit.com/r/selfhostedstack/) community for discussions and showcases
- ⭐ Star the repository if you find it useful — it helps others discover it

Docker AI Stack is maintained by the author of [Setup IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn) (27k+ stars).

## Included services

| Service | Role | Default port |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama)** | Runs local LLM models (llama3, qwen, mistral, etc.) | `11434` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | Web-based chat UI — works instantly with no login required | `3001` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm)** | AI gateway with Admin UI — routes requests to Ollama and 100+ providers | `4000` |
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings)** | Converts text to vectors for semantic search and RAG | `8000` |
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper)** | Transcribes spoken audio to text | `9000` |
| **[WhisperLive (real-time STT)](https://github.com/hwdsl2/docker-whisper-live)** | Real-time speech-to-text transcription over WebSocket | `9090` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro)** | Converts text to natural-sounding speech | `8880` |
| **[MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway)** | Provides MCP tools (filesystem, fetch, GitHub, search, databases) to AI clients | `3000` |
| **[Docling](https://github.com/hwdsl2/docker-docling)** | Converts documents (PDF, DOCX, etc.) to structured text/Markdown | `5001` |

## Quick start

**Requirements:**

- A Linux server (local or cloud) with Docker installed
- At least 8 GB of RAM (with small models). For larger LLM models (8B+), 16 GB or more is recommended.
- You can comment out services you don't need to reduce memory usage.

**Start the full stack:**

```bash
# Clone the repository to get the compose files
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack
docker compose up -d
```

**Pull a model** (required before making LLM requests):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

Run the health check to verify all services are working:

```bash
./stack-check.sh
```

> **Tip:** On first start, services may take a few minutes to initialize. If any checks fail, wait and run `./stack-check.sh` again. Use `docker compose logs` to check progress.

**Get the LiteLLM master key** (used to log into the Admin UI and for LLM requests):

```bash
docker exec litellm litellm_manage --showkey
```

<details>
<summary>Show all API keys (Ollama, LiteLLM, MCP Gateway)</summary>

```bash
docker exec ollama ollama_manage --showkey
docker exec litellm litellm_manage --showkey
docker exec mcp mcp_manage --showkey
```

</details>

**Access AnythingLLM (Chat UI):**

Open `http://<server-ip>:3001` in your browser. AnythingLLM is pre-configured to connect to your local LLM via LiteLLM — no login or setup required. Start chatting immediately. On first start, it may take a few minutes to become available (check progress with `docker logs anythingllm`).

> **Tip:** [Set a password](https://docs.useanything.com/features/security-and-access) to protect AnythingLLM, especially when the server is accessible from the public internet.

**Access the LiteLLM Admin UI:**

Open `http://<server-ip>:4000/ui` in your browser. Log in with username `admin` and your LiteLLM master key as the password. The UI provides virtual key management, spend tracking, and model configuration.

> **Tip:** In the Admin UI, click **Playground** in the left menu. Select a local model (e.g., `ollama/llama3.2:3b`) from the dropdown and start chatting — a quick way to verify your local LLM is working end-to-end.

> **Note:** For internet-facing deployments, using a [reverse proxy](#internet-facing-deployments) to add HTTPS is **strongly recommended**. Change `"3001:3001/tcp"` and `"4000:4000/tcp"` to `"127.0.0.1:3001:3001/tcp"` and `"127.0.0.1:4000:4000/tcp"` in `docker-compose.yml` to prevent direct access to unencrypted ports.

**Stop the stack:**

```bash
# Stop and remove all containers (data is preserved in Docker volumes)
docker compose down
```

## GPU acceleration (NVIDIA CUDA)

For NVIDIA GPU acceleration, use the CUDA compose file:

```bash
docker compose -f docker-compose.cuda.yml up -d
```

**Requirements:** NVIDIA GPU, [NVIDIA driver](https://www.nvidia.com/en-us/drivers/) 535+, and the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) installed on the host. CUDA images are `linux/amd64` only.

## Lightweight stacks

Don't need the full stack? Use a pre-configured subset from the `stacks/` folder:

| Stack | Services | Memory | Use case |
|---|---|---|---|
| **[chat-ui](stacks/chat-ui/)** | Ollama + LiteLLM + AnythingLLM | ~5 GB | Web-based ChatGPT-like chat interface |
| **[voice-pipeline](stacks/voice-pipeline/)** | Whisper + Ollama + LiteLLM + Kokoro | ~6 GB | Speech-to-text → LLM → text-to-speech |
| **[voice-chat](stacks/voice-chat/)** | Whisper + Ollama + LiteLLM + Kokoro + AnythingLLM | ~6.5 GB | Chat UI with voice input/output |
| **[rag-pipeline](stacks/rag-pipeline/)** | Ollama + LiteLLM + Embeddings | ~5 GB | Semantic search + LLM Q&A |
| **[rag-pipeline-full](stacks/rag-pipeline-full/)** | Ollama + LiteLLM + Embeddings + Docling | ~6 GB | Document parsing + semantic search + LLM Q&A |
| **[code-assistant](stacks/code-assistant/)** | Ollama + LiteLLM + MCP Gateway + Embeddings | ~5 GB | AI coding with tools + semantic code search |
| **[ai-tools](stacks/ai-tools/)** | Ollama + LiteLLM + MCP Gateway | ~5 GB | AI coding assistant with tool access |
| **[chat-only](stacks/chat-only/)** | Ollama + LiteLLM | ~4.5 GB | Minimal local ChatGPT replacement |

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/chat-ui  # or voice-pipeline, voice-chat, rag-pipeline, rag-pipeline-full, code-assistant, ai-tools, chat-only
docker compose up -d
```

## Architecture

```mermaid
graph LR
    A["🎤 Audio input"] -->|transcribe| W["Whisper<br/>(speech-to-text)"]
    D["📄 Documents"] -->|parse| DC["Docling<br/>(document → text)"]
    DC -->|embed| E["Embeddings<br/>(text → vectors)"]
    E -->|store| VDB["External Vector DB<br/>(Qdrant, Chroma)"]
    W -->|query| E
    VDB -->|context| L["LiteLLM<br/>(AI gateway)"]
    W -->|text| L
    L -->|routes to| O["Ollama<br/>(local LLM)"]
    L -->|response| T["Kokoro TTS<br/>(text-to-speech)"]
    T --> B["🔊 Audio output"]
    C["🤖 AI client<br/>(Cline, Claude, etc.)"] -->|MCP tools| M["MCP Gateway<br/>(MCP endpoint)"]
    C -->|chat| L
    L -->|MCP protocol| M
    U["👤 User"] -->|chat| AN["AnythingLLM<br/>(chat UI)"]
    AN -->|LLM requests| L
    AN -->|MCP tools| M
    U -->|use| C
    U -->|speak| A
    U -->|upload| D
```

**Notes:**

- Ollama's port (`11434`) and MCP Gateway's port (`3000`) are internal to the Docker network and not exposed to the host by default. Access your LLM through LiteLLM on port `4000`.
- Kokoro (TTS), Docling (document parsing), and WhisperLive (real-time STT) are disabled by default to reduce memory usage. Uncomment these services in `docker-compose.yml` to enable them.

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

# MCP Gateway
docker run -d --name mcp --restart always \
    --network ai-stack \
    -v mcp-data:/var/lib/mcp \
    -v mcp-shared:/var/lib/mcp-shared \
    hwdsl2/mcp-gateway

# LiteLLM (AI gateway)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_MCP_URL=http://mcp:3000/mcp \
    -e LITELLM_DATABASE_URL=postgresql://litellm:litellm@litellm-db:5432/litellm \
    -v litellm-data:/etc/litellm \
    -v ollama-shared:/var/lib/ollama-shared:ro \
    -v mcp-shared:/var/lib/mcp-shared:ro \
    -v litellm-shared:/var/lib/litellm-shared \
    hwdsl2/litellm-server

# Embeddings
docker run -d --name embeddings --restart always \
    --network ai-stack \
    -p 127.0.0.1:8000:8000 \
    -v embeddings-data:/var/lib/embeddings \
    hwdsl2/embeddings-server

# Whisper (STT)
docker run -d --name whisper --restart always \
    --network ai-stack \
    -p 127.0.0.1:9000:9000 \
    -v whisper-data:/var/lib/whisper \
    hwdsl2/whisper-server

# WhisperLive (real-time STT)
docker run -d --name whisper-live --restart always \
    --network ai-stack \
    -p 127.0.0.1:9090:9090 \
    -v whisper-live-data:/var/lib/whisper-live \
    hwdsl2/whisper-live-server

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

# Kokoro (TTS)
docker run -d --name kokoro --restart always \
    --network ai-stack \
    -p 127.0.0.1:8880:8880 \
    -v kokoro-data:/var/lib/kokoro \
    hwdsl2/kokoro-server

# Docling (document parsing)
docker run -d --name docling --restart always \
    --network ai-stack \
    -p 127.0.0.1:5001:5001 \
    -v docling-data:/var/lib/docling \
    hwdsl2/docling-server
```

**Note:** The shared network allows services to reach each other by container name (e.g., LiteLLM connects to Ollama via `http://ollama:11434`). You can start only the services you need — they don't all have to run together.

**Pull a model** (required before making LLM requests):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## Connect MCP Gateway to LiteLLM

LiteLLM and MCP Gateway are **automatically wired** when using the compose files in this repository — no manual key setup is needed.

API keys are shared automatically between services via Docker shared volumes:

- Ollama generates an API key on first start and copies it to a shared volume
- MCP Gateway does the same
- LiteLLM reads both keys from the shared volumes on startup

The `LITELLM_MCP_URL=http://mcp:3000/mcp` and `LITELLM_OLLAMA_BASE_URL=http://ollama:11434` environment variables are pre-configured in the compose files, so all services are connected automatically with a single `docker compose up -d`.

Once connected, AI clients that call LiteLLM can use MCP tools (filesystem, fetch, GitHub, etc.) directly through the LiteLLM proxy.

## Voice pipeline example

Transcribe a spoken question, get a local LLM response via Ollama, and convert it to speech:

**Note:** Kokoro (TTS) is disabled by default. To use this example, first uncomment the `kokoro` service in `docker-compose.yml`, then run `docker compose up -d`.

**Tip:** Need a sample audio file? Download this English speech sample (WAV, MIT License) from the [Azure Samples](https://github.com/Azure-Samples/cognitive-services-speech-sdk) repository:

```bash
curl -L -o sample_speech.wav \
    "https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/katiesteve.wav"
```

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# Step 1: Transcribe audio to text (Whisper)
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@sample_speech.wav -F model=whisper-1 | jq -r .text)

# Step 2: Send text to Ollama via LiteLLM and get a response
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"ollama/llama3.2:3b\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# Step 3: Convert the response to speech (Kokoro TTS)
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3
```

## RAG pipeline example

Embed documents for semantic search, retrieve context, then answer questions with a local Ollama model:

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# Step 1: Embed a document chunk and store the vector in your vector DB
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → Store the returned vector alongside the source text in Qdrant, Chroma, pgvector, etc.

# Step 2: At query time, embed the question, retrieve the top matching chunks from
#          the vector DB, then send the question and retrieved context to Ollama via LiteLLM.
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

## MCP tools example

Use MCP Gateway to give your AI assistant access to files, web, and GitHub:

```bash
MCP_KEY=$(docker exec mcp mcp_manage --showkey | grep '^mcp-' | head -1)

# Use MCP endpoint with an AI client (e.g., Cline in VS Code)
# Set the MCP server URL: http://localhost:3000/mcp
# Set Authorization header: Bearer <api_key>

# Or test the MCP endpoint directly with an initialize request
curl -s http://localhost:3000/mcp \
    -X POST \
    -H "Authorization: Bearer $MCP_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

## Customization

Each service can be configured with an optional env file. Copy the example env file from the respective repository, edit it, and uncomment the volume mount in `docker-compose.yml`:

| Service | Env file | Repository |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm) |
| Embeddings | `embed.env` | [docker-embeddings](https://github.com/hwdsl2/docker-embeddings) |
| Whisper | `whisper.env` | [docker-whisper](https://github.com/hwdsl2/docker-whisper) |
| WhisperLive | `whisper-live.env` | [docker-whisper-live](https://github.com/hwdsl2/docker-whisper-live) |
| Kokoro | `kokoro.env` | [docker-kokoro](https://github.com/hwdsl2/docker-kokoro) |
| MCP Gateway | `mcp.env` | [docker-mcp-gateway](https://github.com/hwdsl2/docker-mcp-gateway) |
| Docling | `docling.env` | [docker-docling](https://github.com/hwdsl2/docker-docling) |

AnythingLLM is configured through its web UI at `http://<server-ip>:3001`. You can change the LLM provider, model, embedding engine, and other settings in **Settings**. See [AnythingLLM docs](https://docs.useanything.com/) for more details.

For detailed configuration options, API reference, and model management, see the documentation in each service's repository.

## Internet-facing deployments

By default, all services listen over plain HTTP. For internet-facing deployments, place a reverse proxy (e.g., [Caddy](https://caddyserver.com/), Nginx, or Traefik) in front of the stack to provide HTTPS. Each service repository includes a detailed [reverse proxy guide](https://github.com/hwdsl2/docker-whisper#using-a-reverse-proxy) with Caddy and nginx examples. The [chat-ui](stacks/chat-ui/) stack also includes a reverse proxy section specific to AnythingLLM.

When exposing services to the internet, set API keys for services that are optional-auth by default (Whisper, WhisperLive, Kokoro, Embeddings, Docling) via their respective env files.

## Backup and restore

Your API keys, models, and configuration are stored in Docker volumes. Back up before upgrading or making changes:

```bash
# Export API keys (while containers are running)
docker exec ollama ollama_manage --showkey
docker exec litellm litellm_manage --showkey
docker exec mcp mcp_manage --showkey

# Back up all volumes (stop services first)
# Stop and remove all containers (data is preserved in Docker volumes)
docker compose down
mkdir -p backups
for vol in ollama-data litellm-data litellm-db embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data; do
  docker volume inspect "$vol" >/dev/null 2>&1 && \
    docker run --rm -v "${vol}:/source:ro" -v "$(pwd)/backups:/backup" \
      alpine tar czf "/backup/${vol}.tar.gz" -C /source .
done
```

**Note:** The `ollama-shared`, `mcp-shared`, and `litellm-shared` volumes are ephemeral key-sharing volumes and do not need to be backed up.

For restore instructions, server migration, and the full pre-upgrade checklist, see the [Backup and Restore](docs/backup-restore.md) guide.

## Update images

To update all services to the latest versions:

```bash
docker compose pull
docker compose up -d
./stack-check.sh
```

Your data is preserved in the Docker volumes. **Always [back up](#backup-and-restore) before upgrading.**

## License

Copyright (C) 2026 Lin Song   
This work is licensed under the [MIT License](https://opensource.org/licenses/MIT).

This project is an independent Docker configuration and is not affiliated with, endorsed by, or sponsored by Ollama, Berri AI (LiteLLM), Hugging Face, hexgrad (Kokoro), OpenAI, SYSTRAN, or MCPHub.
