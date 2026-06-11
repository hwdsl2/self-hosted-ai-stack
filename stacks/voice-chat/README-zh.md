[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 语音聊天

基于网页的聊天界面，配合语音输入（语音转文字）和语音输出（文字转语音）— 完整的本地 AI 个人助手。

**服务：** Ollama (LLM) + LiteLLM (网关) + [AnythingLLM](https://github.com/mintplex-labs/anything-llm) (聊天界面) + Whisper (STT) + Kokoro (TTS)

**内存：** ~6.5 GB RAM（使用 3B 模型）

**平台：** `linux/amd64`、`linux/arm64`

## 架构

```mermaid
graph LR
    U["👤 用户"] -->|聊天| A["AnythingLLM<br/>(聊天界面)"]
    U -->|说话| W["Whisper<br/>(语音转文字)"]
    A -->|API| L["LiteLLM<br/>(AI 网关)"]
    L -->|路由至| O["Ollama<br/>(本地 LLM)"]
    L -->|响应| K["Kokoro<br/>(文字转语音)"]
    K --> S["🔊 音频输出"]
    W -->|文本| L
```

## 服务

| 服务 | 用途 | 默认端口 |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md)** | 运行本地 LLM 模型（llama3、qwen、mistral 等） | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)** | 带管理界面的 AI 网关 — 将请求路由至 Ollama 及 100+ 供应商 | `4000` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | 基于网页的聊天界面，支持工作区、RAG 和代理 | `3001` |
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)** | 将语音音频转录为文字 | `9000` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md)** | 将文字转换为自然语音 | `8880` |

## 快速开始

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/voice-chat
docker compose up -d
```

**拉取模型**（发出 LLM 请求前必须执行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

**打开聊天界面：**

AnythingLLM 已预配置连接到 LiteLLM。API 密钥通过 Docker 卷自动共享 — 无需手动设置。LLM 供应商、基础 URL 和模型均已预配置。

首次启动时，AnythingLLM 可能需要几分钟才能就绪（使用 `docker logs anythingllm` 查看进度）。

**默认启用密码保护。** 首次启动时会自动生成随机管理员密码，仅打印一次到 `docker logs anythingllm`，并保存到 `anythingllm-data` 数据卷中的 `/app/server/storage/.initial_admin_password` 文件。密码在容器升级后持久保留。可随时在 **Settings → Security** 中更改。

获取自动生成的密码：

```bash
# 随时从数据卷中获取：
docker exec anythingllm cat /app/server/storage/.initial_admin_password

# 或从实时日志中获取（仅在首次启动时显示）：
docker compose logs anythingllm | grep -A4 "FIRST RUN"
```

在浏览器中打开 `http://<server-ip>:3001`，并使用上面的密码登录。

> **提示：** 当 AnythingLLM 暴露到 `localhost` 或受信任 LAN 之外时，请使用内置的 Caddy HTTPS 叠加文件，以加密传输中的密码并将直接 HTTP 端口绑定到 localhost。请参阅下方 [使用反向代理](#使用反向代理)。

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

# LiteLLM (AI 网关)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_DATABASE_URL=postgresql://litellm:litellm@litellm-db:5432/litellm \
    -v litellm-data:/etc/litellm \
    -v ollama-shared:/var/lib/ollama-shared:ro \
    -v litellm-shared:/var/lib/litellm-shared \
    hwdsl2/litellm-server

# AnythingLLM (聊天界面)
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
    mintplexlabs/anythingllm:1.13 \
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

**注：** 共享网络允许服务通过容器名称互相访问（例如 AnythingLLM 通过 `http://litellm:4000` 连接 LiteLLM）。

**拉取模型**（发出 LLM 请求前必须执行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## 验证部署

启动后，可以验证所有服务是否正常运行：

```bash
# 在 docker-ai-stack 根目录中运行
../../stack-check.sh
```

**访问 LiteLLM 管理界面：**

在浏览器中打开 `http://<server-ip>:4000/ui`。使用用户名 `admin` 和您的 LiteLLM 主密钥作为密码登录。管理界面提供虚拟密钥管理、支出追踪和模型配置功能。

> **提示：** 在管理界面中，点击左侧菜单的 **Playground**。从下拉列表中选择本地模型（例如 `ollama/llama3.2:3b`）并开始对话 — 这是验证本地大语言模型端到端正常工作的一种快速方式。

## 自定义配置

每个服务可以通过可选的 env 文件进行配置。从相应仓库复制示例 env 文件，编辑后取消 `docker-compose.yml` 中的卷挂载注释：

| 服务 | Env 文件 | 仓库 |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md) |
| Whisper | `whisper.env` | [docker-whisper](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md) |
| Kokoro | `kokoro.env` | [docker-kokoro](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md) |

AnythingLLM 通过其网页界面 `http://<server-ip>:3001` 进行配置。您可以在 **Settings** 中更改 LLM 供应商、模型、嵌入引擎和其他设置。详情请参阅 [AnythingLLM 文档](https://docs.useanything.com/)。

有关详细配置选项、API 参考和模型管理，请参阅各服务仓库的文档。

## 使用反向代理

对于面向互联网的部署，请使用内置的 Caddy 叠加文件添加自动 HTTPS。请从 `stacks/voice-chat` 目录运行以下命令。在代理模式下，Caddy 是唯一监听公网 `80` 和 `443` 端口的服务；AnythingLLM 和 LiteLLM 的直接端口会重新绑定到 `127.0.0.1`。默认情况下，代理只暴露 AnythingLLM；Whisper 和 Kokoro 仍按此子栈的 compose 文件绑定。

前提条件：

- Docker Compose `2.24.4+`（代理叠加文件的端口覆盖需要此版本）
- 域名的 DNS `A`/`AAAA` 记录指向此服务器
- 防火墙/安全组已开放入站 `80/tcp`、`443/tcp`，最好也开放 `443/udp`
- 主机上没有其他服务占用 `80` 或 `443` 端口

**CPU 技术栈：**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.yml -f ../../docker-compose.proxy.yml up -d
```

**CUDA 技术栈：**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.cuda.yml -f ../../docker-compose.proxy.yml up -d
```

打开 `https://chat.example.com`（替换为你的 `DOMAIN`）访问 AnythingLLM。在代理模式下，主机本机仍可访问 `http://127.0.0.1:3001` 和 `http://127.0.0.1:4000/ui`，但服务器外部无法直接访问 `3001` 和 `4000` 端口。

标准 compose 文件会在 `4000` 端口发布 LiteLLM。代理叠加文件会将该直接端口改为仅 localhost 可访问，且内置 Caddyfile 默认只路由 AnythingLLM。取消注释可选的 LiteLLM 主机名配置块会通过 Caddy 暴露 LiteLLM，请妥善保管 LiteLLM 主密钥。

故障排查：

```bash
docker logs ai-stack-caddy
# 使用启动技术栈时相同的 -f 文件
docker compose -f docker-compose.yml -f ../../docker-compose.proxy.yml ps
```

如果 Caddy 报告未知的 `request_body` 指令，请拉取当前的 `caddy:2` 镜像并重启叠加文件部署。

旧版 Docker Compose 或 Podman 用户仍可使用主机上的反向代理：将直接 HTTP 端口绑定到 localhost（例如 `"127.0.0.1:3001:3001/tcp"` 和 `"127.0.0.1:4000:4000/tcp"`），再反向代理到这些 localhost 端口。

### 手动反向代理

从反向代理访问 AnythingLLM 容器，可以使用以下地址之一：

- **`anythingllm:3001`** — 如果反向代理作为容器运行在与 AnythingLLM **相同的 Docker 网络**中（例如在同一个 `docker-compose.yml` 中定义）。
- **`127.0.0.1:3001`** — 如果反向代理运行在**宿主机**上且端口 `3001` 已发布（默认 `docker-compose.yml` 已发布）。

**[Caddy](https://caddyserver.com/docs/) 示例（[Docker 镜像](https://hub.docker.com/_/caddy)）**（通过 Let's Encrypt 自动 TLS，反向代理在同一 Docker 网络中）：

`Caddyfile`：
```
chat.example.com {
  reverse_proxy anythingllm:3001
}
```

**nginx 示例**（反向代理在宿主机上）：

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

**重要：** AnythingLLM 包含自己的用户认证系统 — 在将服务暴露到互联网时请在首次设置时设定强密码。

## 备份和恢复

有关备份/恢复说明，请参阅[备份和恢复](../../docs/backup-restore-zh.md)指南。

## 更新镜像

将所有服务更新到最新版本：

```bash
git pull
docker compose pull
docker compose up -d
```

`git pull` 用于更新此仓库，包括此子栈使用的所有 compose 文件或辅助脚本；`docker compose pull` 用于更新服务镜像。

**旧安装的一次性提示：** 如果您在 `.env` 持久化修复之前设置过 AnythingLLM 密码，升级后的第一次容器重建可能会清除该密码，使 AnythingLLM 处于未受保护状态。更新后，请立即打开 AnythingLLM 并确认密码保护仍然启用。如果没有，请在 **Settings → Security** 中设置新密码。之后的容器重建会保留该密码。

AnythingLLM 固定为稳定发布标签，而不是 `latest`，因为上游 `latest` 镜像跟踪 master 分支。有新的 AnythingLLM 发布版本时，请先备份，更新 compose 文件中的标签，然后运行上述命令。

您的数据保存在 Docker 卷中。 **升级前务必先[备份](../../docs/backup-restore-zh.md)。**

## 语音管道示例

转录语音问题，获取本地 LLM 响应，并转换为语音：

**提示：** 需要示例音频文件？从 [Azure Samples](https://github.com/Azure-Samples/cognitive-services-speech-sdk) 仓库下载此英语语音示例（WAV，MIT 许可证）：

```bash
curl -L -o sample_speech.wav \
    "https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/katiesteve.wav"
```

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# 步骤 1：将音频转录为文本 (Whisper)
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@sample_speech.wav -F model=whisper-1 | jq -r .text)

# 步骤 2：通过 LiteLLM 将文本发送给 Ollama 并获取响应
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"ollama/llama3.2:3b\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# 步骤 3：将响应转换为语音 (Kokoro TTS)
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3

```
