[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Voice Pipeline

Speech-to-text → LLM → text-to-speech. Transcribe audio, get an AI response, and hear it spoken back.

**Services:** Whisper (STT) + Ollama (LLM) + LiteLLM (gateway) + Kokoro (TTS)

**Memory:** ~6 GB RAM (with a 3B model)

**Platforms:** `linux/amd64`, `linux/arm64`

## Architecture

```mermaid
graph LR
    A["🎤 Audio input"] -->|transcribe| W["Whisper<br/>(speech-to-text)"]
    W -->|text| L["LiteLLM<br/>(AI gateway)"]
    L -->|routes to| O["Ollama<br/>(local LLM)"]
    L -->|response| T["Kokoro TTS<br/>(text-to-speech)"]
    T --> B["🔊 Audio output"]
```

## Services

| Service | Role | Default port |
|---|---|---|
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper)** | Transcribes spoken audio to text | `9000` |
| **[WhisperLive (real-time STT)](https://github.com/hwdsl2/docker-whisper-live)** | Real-time speech-to-text transcription over WebSocket | `9090` |
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama)** | Runs local LLM models (llama3, qwen, mistral, etc.) | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm)** | AI gateway with Admin UI — routes requests to Ollama and 100+ providers | `4000` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro)** | Converts text to natural-sounding speech | `8880` |

**Note:** WhisperLive (real-time STT) is commented out by default in `docker-compose.yml`. Uncomment it to enable real-time transcription over WebSocket.

## Quick start

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/voice-pipeline
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

# WhisperLive (real-time STT)
docker run -d --name whisper-live --restart always \
    --network ai-stack \
    -p 127.0.0.1:9090:9090 \
    -v whisper-live-data:/var/lib/whisper-live \
    hwdsl2/whisper-live-server
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

> **Note:** For internet-facing deployments, using a [reverse proxy](#internet-facing-deployments) to add HTTPS is **strongly recommended**. In that case, also change `"4000:4000/tcp"` to `"127.0.0.1:4000:4000/tcp"` in `docker-compose.yml`, to prevent direct access to the unencrypted port.

> **Tip:** In the Admin UI, click **Playground** in the left menu. Select a local model (e.g., `ollama/llama3.2:3b`) from the dropdown and start chatting — a quick way to verify your local LLM is working end-to-end.

## Customization

Each service can be configured with an optional env file. Copy the example env file from the respective repository, edit it, and uncomment the volume mount in `docker-compose.yml`:

| Service | Env file | Repository |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm) |
| Whisper | `whisper.env` | [docker-whisper](https://github.com/hwdsl2/docker-whisper) |
| Kokoro | `kokoro.env` | [docker-kokoro](https://github.com/hwdsl2/docker-kokoro) |
| WhisperLive | `whisper-live.env` | [docker-whisper-live](https://github.com/hwdsl2/docker-whisper-live) |

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

## Example

**Tip:** Need a sample audio file? Download this English speech sample (WAV, MIT License) from the [Azure Samples](https://github.com/Azure-Samples/cognitive-services-speech-sdk) repository:

```bash
curl -L -o sample_speech.wav \
    "https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/katiesteve.wav"
```

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# Transcribe audio to text
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@sample_speech.wav -F model=whisper-1 | jq -r .text)

# Get LLM response
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"ollama/llama3.2:3b\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# Convert response to speech
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3

```
