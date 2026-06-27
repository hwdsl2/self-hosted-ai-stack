[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 语音管道

语音转文本 → LLM → 文本转语音。转录音频，获取 AI 回复，并以语音输出。

**服务：** Whisper (STT) + Ollama (LLM) + LiteLLM (网关) + Kokoro (TTS)

**内存：** ~6 GB RAM（使用 3B 模型）

**平台：** `linux/amd64`、`linux/arm64`

## 架构

```mermaid
graph LR
    A["🎤 音频输入"] -->|转录| W["Whisper<br/>(语音转文本)"]
    W -->|文本| L["LiteLLM<br/>(AI 网关)"]
    L -->|路由至| O["Ollama<br/>(本地 LLM)"]
    L -->|响应| T["Kokoro TTS<br/>(文本转语音)"]
    T --> B["🔊 音频输出"]
```

## 服务

| 服务 | 用途 | 默认端口 |
|---|---|---|
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)** | 将语音音频转录为文本 | `9000` |
| **[WhisperLive（实时语音转文本）](https://github.com/hwdsl2/docker-whisper-live/blob/main/README-zh.md)** | 通过 WebSocket 实时语音转文本 | `9090` |
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md)** | 运行本地 LLM 模型（llama3、qwen、mistral 等） | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)** | 带管理界面的 AI 网关 — 将请求路由至 Ollama 及 100+ 供应商 | `4000` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md)** | 将文本转换为自然语音 | `8880` |

**注：** WhisperLive（实时 STT）在 `docker-compose.yml` 中默认被注释掉。取消注释即可启用通过 WebSocket 的实时转录。

## 快速开始

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack/stacks/voice-pipeline
docker compose up -d
```

**拉取模型**（发出 LLM 请求前必须执行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## GPU 加速 (NVIDIA CUDA)

如需 NVIDIA GPU 加速，请使用 CUDA 编排文件：

```bash
docker compose -f docker-compose.cuda.yml up -d
```

> **提示：** 为避免在后续每个 `docker compose` 命令（`down`、`pull`、`logs` 等）中都添加 `-f docker-compose.cuda.yml`，可在当前 shell 会话中设置一次：
>
> ```bash
> export COMPOSE_FILE=docker-compose.cuda.yml
> ```
>
> 之后照常运行普通的 `docker compose` 命令。如需持久化，请在本目录的 `.env` 文件中添加 `COMPOSE_FILE=docker-compose.cuda.yml`。运行 `unset COMPOSE_FILE` 可切回 CPU 配置。

**要求：** NVIDIA GPU、[NVIDIA 驱动](https://www.nvidia.com/en-us/drivers/) 575.57.08+（Linux）或 576.57+（Windows），以及在宿主机上安装 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)。CUDA 镜像仅支持 `linux/amd64`。

## 不使用 Docker Compose 运行

如需直接使用 `docker run` 命令，请先创建共享网络以便服务之间通信：

```bash
docker network create ai-stack
```

然后在共享网络上启动各服务：

> **注意：** 手动使用 `docker run` 时，请先等待每个依赖项就绪，再启动使用它的服务（例如先等待 PostgreSQL 和其他依赖项（如 Ollama 或 MCP），再启动 LiteLLM；如果使用 AnythingLLM，请先等待 LiteLLM 就绪再启动它）。以下示例会生成一个 PostgreSQL 密码变量，并在 Postgres 和 LiteLLM 中复用。

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

# LiteLLM (AI 网关)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_DATABASE_URL="postgresql://litellm:${LITELLM_POSTGRES_PASSWORD}@litellm-db:5432/litellm" \
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

**注：** 共享网络允许服务通过容器名称互相访问（例如 LiteLLM 通过 `http://ollama:11434` 连接 Ollama）。

**拉取模型**（发出 LLM 请求前必须执行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## 验证部署

启动后，可以验证所有服务是否正常运行：

```bash
# 在 self-hosted-ai-stack 根目录中运行
../../stack-check.sh
```

**访问 LiteLLM 管理界面：**

在浏览器中打开 `http://<server-ip>:4000/ui`。使用用户名 `admin` 和您的 LiteLLM 主密钥作为密码登录。管理界面提供虚拟密钥管理、支出追踪和模型配置功能。

> **注：** 对于面向互联网的部署，强烈建议使用[反向代理](#面向互联网的部署)添加 HTTPS。在这种情况下，还需将 `docker-compose.yml` 中的 `"4000:4000/tcp"` 改为 `"127.0.0.1:4000:4000/tcp"`，以防止直接访问未加密端口。

> **提示：** 在管理界面中，点击左侧菜单的 **Playground**。从下拉列表中选择本地模型（例如 `ollama/llama3.2:3b`）并开始对话 — 这是验证本地大语言模型端到端正常工作的一种快速方式。

## 使用计数

此技术栈参与项目的匿名、聚合的 GitHub release 资源下载计数。使用 `AI_STACK_DISABLE_USAGE_COUNTS=1 docker compose up -d` 启动可禁用；详情见[使用计数](../../README-zh.md#使用计数)。

## 自定义配置

每个服务可以通过可选的 env 文件进行配置。从相应仓库复制示例 env 文件，编辑后取消 `docker-compose.yml` 中的卷挂载注释：

| 服务 | Env 文件 | 仓库 |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md) |
| Whisper | `whisper.env` | [docker-whisper](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md) |
| Kokoro | `kokoro.env` | [docker-kokoro](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md) |
| WhisperLive | `whisper-live.env` | [docker-whisper-live](https://github.com/hwdsl2/docker-whisper-live) |

有关详细配置选项、API 参考和模型管理，请参阅各服务仓库的文档。

## 面向互联网的部署

默认情况下，所有服务通过纯 HTTP 监听。对于面向互联网的部署，请在技术栈前面放置反向代理（例如 [Caddy](https://caddyserver.com/)、Nginx 或 Traefik）以提供 HTTPS。每个服务仓库都包含详细的[反向代理指南](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md#使用反向代理)，含 Caddy 和 nginx 示例。

## 备份和恢复

有关备份/恢复说明，请参阅[备份和恢复](../../docs/backup-restore-zh.md)指南。

## 更新镜像

将所有服务更新到最新版本：

```bash
git pull
docker compose pull
docker compose up -d
../../stack-check.sh
```

子栈重启后，运行 `../../stack-check.sh` 确认服务和生成的凭据配置正常。

`git pull` 用于更新此仓库，包括此子栈使用的所有 compose 文件或辅助脚本；`docker compose pull` 用于更新服务镜像。

您的数据保存在 Docker 卷中。 **升级前务必先[备份](../../docs/backup-restore-zh.md)。**

## 示例

**提示：** 需要示例音频文件？可以从 [Azure Samples](https://github.com/Azure-Samples/cognitive-services-speech-sdk) 仓库下载这个英语语音示例（WAV 格式，MIT 许可证）：

```bash
curl -L -o sample_speech.wav \
    "https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/katiesteve.wav"
```

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)
WHISPER_KEY=$(docker exec whisper whisper_manage --getkey)
KOKORO_KEY=$(docker exec kokoro kokoro_manage --getkey)

# 将音频转录为文本
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -H "Authorization: Bearer $WHISPER_KEY" \
    -F file=@sample_speech.wav -F model=whisper-1 | jq -r .text)

# 获取 LLM 响应
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"ollama/llama3.2:3b\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# 将响应转换为语音
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KOKORO_KEY" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3

```
