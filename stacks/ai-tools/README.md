[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# AI Tools

Local LLM with MCP tool access for AI coding assistants (Cline, Claude, Cursor, etc.).

**Services:** Ollama (LLM) + LiteLLM (gateway) + MCP Gateway

**Memory:** ~3 GB RAM (with a 3B model)

## Architecture

```mermaid
graph LR
    C["🤖 AI client<br/>(Cline, Claude, etc.)"] -->|MCP tools| M["MCP Gateway<br/>(MCP endpoint)"]
    C -->|chat| L["LiteLLM<br/>(AI gateway)"]
    L -->|routes to| O["Ollama<br/>(local LLM)"]
    L -->|MCP protocol| M
```

## Services

| Service | Role | Default port |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama)** | Runs local LLM models (llama3, qwen, mistral, etc.) | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm)** | AI gateway with Admin UI — routes requests to Ollama and 100+ providers | `4000` |
| **[MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway)** | Provides MCP tools (filesystem, fetch, GitHub, search, databases) to AI clients | `3000` |

## Quick start

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/ai-tools
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
# Ollama (LLM)
docker run -d --name ollama --restart always \
    --network ai-stack \
    -v ollama-data:/var/lib/ollama \
    hwdsl2/ollama-server

# LiteLLM (AI gateway)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -v litellm-data:/etc/litellm \
    hwdsl2/litellm-server

# MCP Gateway
docker run -d --name mcp --restart always \
    --network ai-stack \
    -v mcp-data:/var/lib/mcp \
    hwdsl2/mcp-gateway
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
| MCP Gateway | `mcp.env` | [docker-mcp-gateway](https://github.com/hwdsl2/docker-mcp-gateway) |

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

## Connect MCP Gateway to LiteLLM

LiteLLM and MCP Gateway are **automatically wired** in the compose file. `LITELLM_MCP_URL=http://mcp:3000/mcp` is pre-configured, so LiteLLM injects the `mcp_servers:` block once the API key is also set.

To complete the wiring, set the MCP API key after first start:

```bash
# 1. Get the MCP Gateway API key
docker exec mcp mcp_manage --showkey

# 2. Add it to litellm.env (or set as environment variable) and restart:
#    LITELLM_MCP_API_KEY=mcp-xxxx...
docker compose restart litellm
```

Alternatively, pre-set `MCP_API_KEY=my-key` in `mcp.env` and use the same value for `LITELLM_MCP_API_KEY` in `litellm.env` before first start — then no restart is needed.

## Usage

```bash
# Get API keys
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)
MCP_KEY=$(docker exec mcp mcp_manage --showkey | grep '^mcp-' | head -1)

# Use with an AI client (e.g., Cline in VS Code):
# LLM endpoint: http://localhost:4000 (with LITELLM_KEY)
# MCP endpoint: http://localhost:3000/mcp (with MCP_KEY)
