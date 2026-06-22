[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Voice Chat

Web-based chat UI with voice input (speech-to-text) and voice output (text-to-speech) — a complete local AI personal assistant.

**Services:** Ollama (LLM) + LiteLLM (gateway) + [AnythingLLM](https://github.com/mintplex-labs/anything-llm) (chat UI) + Whisper (STT) + Kokoro (TTS)

**Memory:** ~6.5 GB RAM (with a 3B model)

**Platforms:** `linux/amd64`, `linux/arm64`

## Architecture

```mermaid
graph LR
    U["👤 User"] -->|chat| A["AnythingLLM<br/>(chat UI)"]
    U -->|speak| W["Whisper<br/>(speech-to-text)"]
    A -->|API| L["LiteLLM<br/>(AI gateway)"]
    L -->|routes to| O["Ollama<br/>(local LLM)"]
    L -->|response| K["Kokoro<br/>(text-to-speech)"]
    K --> S["🔊 Audio output"]
    W -->|text| L
```

## Services

| Service | Role | Default port |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama)** | Runs local LLM models (llama3, qwen, mistral, etc.) | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm)** | AI gateway with Admin UI — routes requests to Ollama and 100+ providers | `4000` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | Web-based chat UI with workspaces, RAG, and agent support | `3001` |
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper)** | Transcribes spoken audio to text | `9000` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro)** | Converts text to natural-sounding speech | `8880` |

## Quick start

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack/stacks/voice-chat
docker compose up -d
```

**Pull a model** (required before making LLM requests):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

**Open the chat UI:**

AnythingLLM is pre-configured to connect to LiteLLM. The API key is shared automatically via a Docker volume — no manual setup needed. The LLM provider, base URL, and model are pre-configured.

On first start, AnythingLLM may take a few minutes to become available (check progress with `docker logs anythingllm`).

**Password-protected by default.** A random admin password is auto-generated on first start, printed once to `docker logs anythingllm`, and saved to `/app/server/storage/.initial_admin_password` inside the `anythingllm-data` volume. The seeded password persists across container upgrades. Change it any time from **Settings → Security**; after you do, `.initial_admin_password` may no longer match the current login password.

Retrieve the auto-generated password:

```bash
# At any time from the data volume:
docker exec anythingllm cat /app/server/storage/.initial_admin_password

# Or from the live logs (only shown on first start):
docker compose logs anythingllm | grep -A4 "FIRST RUN"
```

Open `http://<server-ip>:3001` in your browser and log in with the password above.

> **Tip:** When exposing AnythingLLM beyond `localhost` or a trusted LAN, use the included Caddy HTTPS overlay so the password is encrypted in transit and direct HTTP ports are bound to localhost. See [Using a reverse proxy](#using-a-reverse-proxy) below.

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

# LiteLLM (AI gateway)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_DATABASE_URL="postgresql://litellm:${LITELLM_POSTGRES_PASSWORD}@litellm-db:5432/litellm" \
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
    mintplexlabs/anythingllm:1.14.1 \
    /usr/local/bin/chat-ui-bootstrap.sh

# Whisper (STT)
docker run -d --name whisper --restart always \
    --network ai-stack \
    -p 127.0.0.1:9000:9000 \
    -v whisper-data:/var/lib/whisper \
    hwdsl2/whisper-server

# Kokoro (TTS)
docker run -d --name kokoro --restart always \
    --network ai-stack \
    -p 127.0.0.1:8880:8880 \
    -v kokoro-data:/var/lib/kokoro \
    hwdsl2/kokoro-server
```

**Note:** The shared network allows services to reach each other by container name (e.g., AnythingLLM connects to LiteLLM via `http://litellm:4000`).

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

> **Tip:** In the Admin UI, click **Playground** in the left menu. Select a local model (e.g., `ollama/llama3.2:3b`) from the dropdown and start chatting — a quick way to verify your local LLM is working end-to-end.

## Customization

Each service can be configured with an optional env file. Copy the example env file from the respective repository, edit it, and uncomment the volume mount in `docker-compose.yml`:

| Service | Env file | Repository |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm) |
| Whisper | `whisper.env` | [docker-whisper](https://github.com/hwdsl2/docker-whisper) |
| Kokoro | `kokoro.env` | [docker-kokoro](https://github.com/hwdsl2/docker-kokoro) |

AnythingLLM is configured through its web UI at `http://<server-ip>:3001`. You can change the LLM provider, model, embedding engine, and other settings in **Settings**. See [AnythingLLM docs](https://docs.useanything.com/) for more details.

For detailed configuration options, API reference, and model management, see the documentation in each service's repository.

## Using a reverse proxy

For internet-facing deployments, use the included Caddy overlay to add automatic HTTPS. Run these commands from the `stacks/voice-chat` directory. The root `../../docker-compose.proxy.yml` overlay intentionally mounts this stack's local `caddy/Caddyfile`. In proxy mode, Caddy is the only public listener on ports `80` and `443`; the direct AnythingLLM and LiteLLM ports are rebound to `127.0.0.1`. The proxy exposes only AnythingLLM by default; Whisper and Kokoro remain bound according to the sub-stack compose file.

Prerequisites:

- Docker Compose `2.24.4+` (required for the proxy overlay's port override)
- A DNS `A`/`AAAA` record for your domain pointing to this server
- Inbound `80/tcp`, `443/tcp`, and ideally `443/udp` open in your firewall/security group
- No other service already using ports `80` or `443` on the host

**CPU stack:**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.yml -f ../../docker-compose.proxy.yml up -d
```

**CUDA stack:**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.cuda.yml -f ../../docker-compose.proxy.yml up -d
```

Open `https://chat.example.com` (replace with your `DOMAIN`) to access AnythingLLM. In proxy mode, `http://127.0.0.1:3001` and `http://127.0.0.1:4000/ui` remain available on the host, but the direct `3001` and `4000` ports are not reachable from outside the server.

The standard compose files publish LiteLLM on port `4000`. The proxy overlay changes that direct port to localhost-only, and the included Caddyfile routes only AnythingLLM by default. Uncommenting the optional LiteLLM hostname block exposes LiteLLM through Caddy, so keep the LiteLLM master key secret.

Troubleshooting:

```bash
docker logs ai-stack-caddy
# Use the same -f files you used to start the stack
docker compose -f docker-compose.yml -f ../../docker-compose.proxy.yml ps
```

If Caddy reports an unknown `request_body` directive, pull the current `caddy:2` image and restart the overlay.

For older Docker Compose versions or Podman, use a host-based reverse proxy instead: bind direct HTTP ports to localhost in the compose file (for example, `"127.0.0.1:3001:3001/tcp"` and `"127.0.0.1:4000:4000/tcp"`) and proxy to those localhost ports.

### Manual reverse proxy

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
git pull
docker compose pull
docker compose up -d
../../stack-check.sh
```

After the sub-stack restarts, run `../../stack-check.sh` to confirm the services and generated credential wiring are healthy.

`git pull` updates this repository, including any compose files or helper scripts used by this sub-stack; `docker compose pull` updates the service images.

**One-time note for older installs:** If you set an AnythingLLM password before the `.env` persistence fix, the first container recreation after upgrading may clear that password and leave AnythingLLM unprotected. After updating, open AnythingLLM immediately and confirm password protection is still enabled. If it is not, set a new password in **Settings → Security**. Future container recreations will preserve it.

AnythingLLM is pinned to a stable release tag instead of `latest` because the upstream `latest` image tracks the master branch. When a newer AnythingLLM release is available, back up first, update the tag in the compose files, then run the commands above.

Your data is preserved in the Docker volumes. **Always [back up](../../docs/backup-restore.md) before upgrading.**

## Voice pipeline example

Transcribe a spoken question, get a local LLM response, and convert it to speech:

**Tip:** Need a sample audio file? Download this English speech sample (WAV, MIT License) from the [Azure Samples](https://github.com/Azure-Samples/cognitive-services-speech-sdk) repository:

```bash
curl -L -o sample_speech.wav \
    "https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/katiesteve.wav"
```

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)
WHISPER_KEY=$(docker exec whisper whisper_manage --getkey)
KOKORO_KEY=$(docker exec kokoro kokoro_manage --getkey)

# Step 1: Transcribe audio to text (Whisper)
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -H "Authorization: Bearer $WHISPER_KEY" \
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
    -H "Authorization: Bearer $KOKORO_KEY" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3

```
