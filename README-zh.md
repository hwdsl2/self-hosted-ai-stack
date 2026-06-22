[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Self-Hosted AI Stack

[![Powered by Docker Compose](docs/images/powered-by-docker-compose.svg)](https://docs.docker.com/compose/) &nbsp;[![Docker Pulls](https://raw.githubusercontent.com/hwdsl2/badges/main/img/docker-pulls-ai-stack.svg)](https://hub.docker.com/u/hwdsl2) &nbsp;[![授权协议: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

<p align="center">
  <img src="docs/images/self-hosted-ai-stack-overview.png"
       alt="Self-Hosted AI Stack：一键部署完整的自托管 AI 技术栈"
       width="100%">
</p>

包含 Ollama、LiteLLM、AnythingLLM、Whisper、MCP Gateway、Embeddings、Docling 和 Kokoro — 使用 Docker Compose 完整配置，开箱即用。

- 零配置：所有服务在首次启动时自动配置
- 默认安全：AnythingLLM 默认启用密码保护，内置 API 服务会自动生成 API 密钥
- HTTPS 就绪：可选 Caddy 叠加文件提供自动 TLS，并将直接 HTTP 端口绑定到 localhost
- 隐私：默认在本地运行，可通过 LiteLLM 选择性接入外部提供商
- 灵活配置：可通过简单的 env 文件自定义模型、端口、提供商和 API 密钥
- 提供[轻量级技术栈](#轻量级技术栈)，降低内存要求（最低约 4.5 GB）
- 支持 NVIDIA CUDA GPU 加速
- 多架构：`linux/amd64`、`linux/arm64`

## 社区

- 📬 [订阅项目更新](https://selfhostedstack.beehiiv.com/subscribe?utm_campaign=ai-zh)（每月 1–2 封邮件）——获取免费的 AI 和 VPN 部署指南（PDF，英文）
- 💬 加入 [r/selfhostedstack](https://www.reddit.com/r/selfhostedstack/) 社区，参与讨论和项目展示
- ⭐ 如果你觉得本项目有用，请为仓库加星——这有助于让更多人发现它。

Self-Hosted AI Stack 由 [Setup IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/README-zh.md)（28k+ 星标）的作者维护。

## 包含的服务

| 服务 | 用途 | 默认端口 |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md)** | 运行本地大语言模型（llama3、qwen、mistral 等） | `11434` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | 基于 Web 的聊天界面 — 默认启用密码保护 | `3001` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)** | AI 网关（含管理界面）— 将请求路由至 Ollama 及 100+ 提供商 | `4000` |
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md)** | 将文本转换为向量，用于语义搜索和 RAG | `8000` |
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md)** | 将语音转录为文本 | `9000` |
| **[WhisperLive（实时语音转文本）](https://github.com/hwdsl2/docker-whisper-live/blob/main/README-zh.md)** | 通过 WebSocket 实时语音转文本 | `9090` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md)** | 将文本转换为自然语音 | `8880` |
| **[MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/README-zh.md)** | 为 AI 客户端提供 MCP 工具（文件系统、网页抓取、GitHub、搜索、数据库） | `3000` |
| **[Docling](https://github.com/hwdsl2/docker-docling/blob/main/README-zh.md)** | 将文档（PDF、DOCX 等）转换为结构化文本/Markdown | `5001` |

## 快速开始

**系统要求：**

- 一台安装了 Docker 的 Linux 服务器（本地或云端）
- 至少 8 GB 内存（使用小型模型）。对于较大的 LLM 模型（8B+），建议 16 GB 或以上。
- 您可以注释掉不需要的服务以减少内存使用。

**启动完整技术栈：**

```bash
# 克隆仓库以获取编排文件
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack
docker compose up -d
```

> **现有安装：** 如果您在本项目从 `docker-ai-stack` 更名前已经克隆，现有检出和部署会继续工作。GitHub 会重定向旧仓库 URL，您无需重命名本地目录、容器、卷或网络。

> **PostgreSQL 凭据：** 全新安装会自动生成 PostgreSQL 凭据；有关升级和自定义密码说明，请参阅 [PostgreSQL 凭据](#postgresql-凭据)。

**拉取模型**（发出 LLM 请求前必须执行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

运行健康检查以验证所有服务正常工作：

```bash
./stack-check.sh
```

> **提示：** 首次启动时，服务可能需要几分钟完成初始化。如有检查失败，请稍等后再次运行 `./stack-check.sh`。使用 `docker compose logs` 查看进度。

有关详细故障排查，请参阅[故障排查](docs/troubleshooting-zh.md)指南。

**获取 LiteLLM 主密钥**（用于登录管理界面和 LLM 请求）：

```bash
docker exec litellm litellm_manage --showkey
```

<details>
<summary>显示核心 API 密钥（Ollama、LiteLLM、MCP Gateway）</summary>

```bash
docker exec ollama ollama_manage --showkey
docker exec litellm litellm_manage --showkey
docker exec mcp mcp_manage --showkey
```

</details>

**访问 AnythingLLM（聊天界面）：**

AnythingLLM 已预配置通过 LiteLLM 连接本地大语言模型。首次启动时，可能需要几分钟才能就绪（使用 `docker logs anythingllm` 查看进度）。

**默认启用密码保护。** 首次启动时会自动生成随机管理员密码，仅打印一次到 `docker logs anythingllm`，并保存到 `anythingllm-data` 数据卷中的 `/app/server/storage/.initial_admin_password` 文件。种子密码会在容器升级后持久保留。可随时在 **Settings → Security** 中更改；更改后，`.initial_admin_password` 可能不再与当前登录密码一致。

获取自动生成的密码：

```bash
# 随时从数据卷中获取：
docker exec anythingllm cat /app/server/storage/.initial_admin_password

# 或从实时日志中获取（仅在首次启动时显示）：
docker compose logs anythingllm | grep -A4 "FIRST RUN"
```

在浏览器中打开 `http://<server-ip>:3001`，并使用上面的密码登录。

> **提示：** 当 AnythingLLM 暴露到 `localhost` 或受信任 LAN 之外时，请使用内置的 Caddy HTTPS 叠加文件，以加密传输中的密码并将直接 HTTP 端口绑定到 localhost。请参阅下方 [面向互联网的部署](#面向互联网的部署)。

**访问 LiteLLM 管理界面：**

在浏览器中打开 `http://<server-ip>:4000/ui`。使用用户名 `admin` 和您的 LiteLLM 主密钥作为密码登录。管理界面提供虚拟密钥管理、支出追踪和模型配置功能。

> **提示：** 在管理界面中，点击左侧菜单的 **Playground**。从下拉列表中选择本地模型（例如 `ollama/llama3.2:3b`）并开始对话 — 这是验证本地大语言模型端到端正常工作的一种快速方式。

**停止技术栈：**

```bash
# 停止并移除所有容器（数据保留在 Docker 卷中）
docker compose down
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

> **Podman 用户：** Podman 会忽略 Compose 的 `deploy:` GPU 配置块。请改用 CDI — 参见[使用 Podman](#使用-podman)。

## 轻量级技术栈

不需要完整技术栈？使用 `stacks/` 文件夹中的预配置子集：

| 技术栈 | 服务 | 内存 | 使用场景 |
|---|---|---|---|
| **[chat-ui](stacks/chat-ui/README-zh.md)** | Ollama + LiteLLM + AnythingLLM | ~5 GB | 基于 Web 的 ChatGPT 式聊天界面 |
| **[voice-pipeline](stacks/voice-pipeline/README-zh.md)** | Whisper + Ollama + LiteLLM + Kokoro | ~6 GB | 语音转文本 → LLM → 文本转语音 |
| **[voice-chat](stacks/voice-chat/README-zh.md)** | Whisper + Ollama + LiteLLM + Kokoro + AnythingLLM | ~6.5 GB | 带语音输入/输出的聊天界面 |
| **[rag-pipeline](stacks/rag-pipeline/README-zh.md)** | Ollama + LiteLLM + Embeddings | ~5 GB | 语义搜索 + LLM 问答 |
| **[rag-pipeline-full](stacks/rag-pipeline-full/README-zh.md)** | Ollama + LiteLLM + Embeddings + Docling | ~6 GB | 文档解析 + 语义搜索 + LLM 问答 |
| **[code-assistant](stacks/code-assistant/README-zh.md)** | Ollama + LiteLLM + MCP Gateway + Embeddings | ~5 GB | AI 编程，支持工具 + 语义代码搜索 |
| **[ai-tools](stacks/ai-tools/README-zh.md)** | Ollama + LiteLLM + MCP Gateway | ~5 GB | AI 编程助手，支持工具访问 |
| **[chat-only](stacks/chat-only/README-zh.md)** | Ollama + LiteLLM | ~4.5 GB | 最小化本地 ChatGPT 替代方案 |

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack/stacks/chat-ui  # 或 voice-pipeline、voice-chat、rag-pipeline、rag-pipeline-full、code-assistant、ai-tools、chat-only
docker compose up -d
```

## 架构

```mermaid
graph LR
    A["🎤 音频输入"] -->|转录| W["Whisper<br/>(语音转文本)"]
    D["📄 文档"] -->|解析| DC["Docling<br/>(文档 → 文本)"]
    DC -->|嵌入| E["Embeddings<br/>(文本 → 向量)"]
    E -->|存储| VDB["pgvector<br/>(共享 Postgres 中)"]
    W -->|查询| E
    VDB -->|上下文| L["LiteLLM<br/>(AI 网关)"]
    W -->|文本| L
    L -->|路由至| O["Ollama<br/>(本地 LLM)"]
    L -->|响应| T["Kokoro TTS<br/>(文本转语音)"]
    T --> B["🔊 音频输出"]
    C["🤖 AI 客户端<br/>(Cline, Claude 等)"] -->|MCP 工具| M["MCP Gateway<br/>(MCP 端点)"]
    C -->|对话| L
    L -->|MCP 协议| M
    U["👤 用户"] -->|对话| AN["AnythingLLM<br/>(聊天界面)"]
    AN -->|LLM 请求| L
    AN -->|MCP 工具| M
    U -->|使用| C
    U -->|讲话| A
    U -->|上传| D
```

**注：**

- Ollama 的端口（`11434`）和 MCP Gateway 的端口（`3000`）仅在 Docker 网络内部可用，默认不暴露给主机。请通过 LiteLLM 的端口 `4000` 访问您的 LLM。
- 为减少内存占用，Kokoro（TTS）、Docling（文档解析）和 WhisperLive（实时语音转文本）默认处于禁用状态。如需启用，请在 `docker-compose.yml` 中取消注释这些服务。

## 不使用 Docker Compose 运行

如需直接使用 `docker run` 命令，请先创建共享网络以便服务之间通信：

```bash
docker network create ai-stack
```

然后生成 PostgreSQL 密码，并在共享网络上启动各服务：

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

# MCP Gateway
docker run -d --name mcp --restart always \
    --network ai-stack \
    -v mcp-data:/var/lib/mcp \
    -v mcp-shared:/var/lib/mcp-shared \
    hwdsl2/mcp-gateway

# LiteLLM (AI 网关)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_MCP_URL=http://mcp:3000/mcp \
    -e LITELLM_DATABASE_URL="postgresql://litellm:${LITELLM_POSTGRES_PASSWORD}@litellm-db:5432/litellm" \
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
    mintplexlabs/anythingllm:1.14.1 \
    /usr/local/bin/chat-ui-bootstrap.sh

# Kokoro (TTS)
docker run -d --name kokoro --restart always \
    --network ai-stack \
    -p 127.0.0.1:8880:8880 \
    -v kokoro-data:/var/lib/kokoro \
    hwdsl2/kokoro-server

# Docling (文档解析)
docker run -d --name docling --restart always \
    --network ai-stack \
    -p 127.0.0.1:5001:5001 \
    -v docling-data:/var/lib/docling \
    hwdsl2/docling-server
```

**注：** 共享网络允许服务通过容器名称互相访问（例如 LiteLLM 通过 `http://ollama:11434` 连接 Ollama）。您可以只启动需要的服务 — 不必全部运行。

**拉取模型**（发出 LLM 请求前必须执行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## 使用 Podman

本技术栈在尽力支持的基础上可在 [Podman](https://podman.io/) 上运行。CPU 编排文件无需修改即可使用；GPU 加速和启用了 SELinux 的宿主机需要下文所述的几个额外步骤。建议使用 Podman **4.1+**。

**1. 安装 Docker CLI 兼容层。** 为使本 README 中的 `docker` 命令以及 `stack-check.sh` 健康检查脚本无需改动即可运行，请安装 `podman-docker` 软件包（提供 `docker` → `podman` 封装）：

```bash
# Fedora / RHEL / CentOS Stream
sudo dnf install -y podman-docker

# Debian / Ubuntu
sudo apt-get install -y podman-docker
```

> **注：** shell 别名 `alias docker=podman` **不**足够 — 脚本（如 `stack-check.sh`）无法识别别名。请改用 `podman-docker` 软件包（或在 `PATH` 中创建 `docker` → `podman` 符号链接）。此外，`stack-check.sh` 会自动检测 Podman；您也可以通过 `CONTAINER_ENGINE=podman ./stack-check.sh` 强制指定。

**2. 安装 Compose 提供程序。** `podman compose` 会委托给外部提供程序。请安装 `podman-compose` 或 `docker-compose` 之一：

```bash
# Fedora / RHEL / CentOS Stream
sudo dnf install -y podman-compose

# Debian / Ubuntu
sudo apt-get install -y podman-compose
```

**3. 启动技术栈。** 安装兼容层后，本 README 中的每条命令均可原样运行。若未安装，请将 `docker` 替换为 `podman`：

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack
podman compose up -d
```

运行健康检查（自动检测引擎）：

```bash
./stack-check.sh
```

**GPU 加速 (CDI)。** Podman 不会读取 Compose 的 `deploy.resources` GPU 配置块。请改用[容器设备接口 (CDI)](https://github.com/cncf-tags/container-device-interface)。在安装 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) 后，生成 CDI 规范：

```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

然后将 GPU 暴露给相关服务。对于 `podman compose`，请将 `docker-compose.cuda.yml` 中 `ollama`（及 `whisper`）服务的 `deploy:` 配置块替换为 `devices:` 条目：

```yaml
    devices:
      - nvidia.com/gpu=all
```

对于普通的 `podman run` 命令，请添加 `--device nvidia.com/gpu=all`。

**SELinux。** 在启用了 SELinux 的宿主机上（Fedora、RHEL、CentOS Stream），绑定挂载的文件需要重新打标签后缀，否则容器将被拒绝访问。请为 `chat-ui-bootstrap.sh` 绑定挂载添加 `:z`（共享）后缀：

- 在 `docker-compose.yml` 中：将 `./chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro` 改为 `./chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro,z`
- 在上文的 `podman run` 命令中：将 `"$(pwd)/chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro"` 改为 `"$(pwd)/chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro,z"`

命名卷无需重新打标签。

**后续步骤：** 拉取模型并访问服务 — 请按照[快速开始](#快速开始)中"拉取模型"之后的说明操作。安装 `podman-docker` 兼容层后，所有命令无需修改即可使用。

## 将 MCP Gateway 连接到 LiteLLM

在本仓库的 compose 文件中，LiteLLM 和 MCP Gateway 已**自动接入**——无需手动设置密钥。

API 密钥通过 Docker 共享卷在服务之间自动共享：

- Ollama 在首次启动时生成 API 密钥，并将其复制到共享卷
- MCP Gateway 执行相同操作
- LiteLLM 在启动时自动从共享卷读取这两个密钥

compose 文件中已预配置 `LITELLM_MCP_URL=http://mcp:3000/mcp` 和 `LITELLM_OLLAMA_BASE_URL=http://ollama:11434`，因此只需一条 `docker compose up -d` 命令即可自动连接所有服务。

连接成功后，调用 LiteLLM 的 AI 客户端即可通过 LiteLLM 代理直接使用 MCP 工具（文件系统、网页获取、GitHub 等）。

## 语音管道示例

转录语音问题，通过 Ollama 获取本地 LLM 响应，然后转换为语音：

**注：** Kokoro（TTS）默认已禁用。如需使用此示例，请先取消 `docker-compose.yml` 中 `kokoro` 服务的注释，然后运行 `docker compose up -d`。

**提示：** 需要示例音频文件？可以从 [Azure Samples](https://github.com/Azure-Samples/cognitive-services-speech-sdk) 仓库下载这个英语语音示例（WAV 格式，MIT 许可证）：

```bash
curl -L -o sample_speech.wav \
    "https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/katiesteve.wav"
```

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)
WHISPER_KEY=$(docker exec whisper whisper_manage --getkey)
KOKORO_KEY=$(docker exec kokoro kokoro_manage --getkey)

# 第 1 步：将音频转录为文本（Whisper）
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -H "Authorization: Bearer $WHISPER_KEY" \
    -F file=@sample_speech.wav -F model=whisper-1 | jq -r .text)

# 第 2 步：通过 LiteLLM 将文本发送至 Ollama 并获取响应
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"ollama/llama3.2:3b\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# 第 3 步：将响应转换为语音（Kokoro TTS）
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KOKORO_KEY" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3
```

## 向量数据库

本栈的 PostgreSQL 已内置 [pgvector](https://github.com/pgvector/pgvector) 扩展，因此您可以在 LiteLLM 使用的同一个数据库中存储和查询嵌入向量 — 无需单独的向量数据库。

启用扩展（只需执行一次，数据库会持久保存）：

```bash
docker exec litellm-db psql -U litellm -d litellm -c 'CREATE EXTENSION IF NOT EXISTS vector;'
```

验证是否已启用：

```bash
docker exec litellm-db psql -U litellm -d litellm -c "SELECT extname, extversion FROM pg_extension WHERE extname='vector';"
```

随后即可创建带有 `vector` 列的表（维度需与嵌入模型一致 — 例如默认 `BAAI/bge-small-en-v1.5` 为 `384`），并使用 `<=>` 运算符进行相似度搜索。如需更大规模或混合检索，也可改用 Qdrant、Chroma 等专用向量数据库。

## RAG 管道示例

嵌入文档用于语义搜索，检索上下文，然后使用本地 Ollama 模型回答问题：

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)
EMBED_KEY=$(docker exec embeddings embed_manage --getkey)

# 第 1 步：嵌入文档片段并将向量存储到向量数据库
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $EMBED_KEY" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → 将返回的向量与源文本一起存储到 pgvector（已包含在本栈的 Postgres 中），或 Qdrant、Chroma 等其他向量数据库。

# 第 2 步：查询时，嵌入问题，从向量数据库中检索最匹配的片段，
#          然后通过 LiteLLM 将问题和检索到的上下文发送至 Ollama。
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

## MCP 工具示例

使用 MCP Gateway 为您的 AI 助手提供文件、网络和 GitHub 访问：

```bash
MCP_KEY=$(docker exec mcp mcp_manage --getkey)

# 在 AI 客户端中使用 MCP 端点（例如 VS Code 中的 Cline）
# 设置 MCP 服务器 URL：http://localhost:3000/mcp
# 设置 Authorization 头：Bearer <api_key>

# 或直接测试 MCP 端点
curl -s http://localhost:3000/mcp \
    -X POST \
    -H "Authorization: Bearer $MCP_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

## 自定义配置

每个服务可以通过可选的 env 文件进行配置。从相应仓库复制示例 env 文件，编辑后取消 `docker-compose.yml` 中的卷挂载注释：

| 服务 | Env 文件 | 仓库 |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md) |
| Embeddings | `embed.env` | [docker-embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh.md) |
| Whisper | `whisper.env` | [docker-whisper](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md) |
| WhisperLive | `whisper-live.env` | [docker-whisper-live](https://github.com/hwdsl2/docker-whisper-live/blob/main/README-zh.md) |
| Kokoro | `kokoro.env` | [docker-kokoro](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh.md) |
| MCP Gateway | `mcp.env` | [docker-mcp-gateway](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/README-zh.md) |
| Docling | `docling.env` | [docker-docling](https://github.com/hwdsl2/docker-docling/blob/main/README-zh.md) |

AnythingLLM 通过其 Web 界面 `http://<服务器IP>:3001` 进行配置。您可以在 **Settings** 中更改 LLM 供应商、模型、嵌入引擎和其他设置。详情请参阅 [AnythingLLM 文档](https://docs.useanything.com/)。

**使用本技术栈的 Embeddings 服务（可选）。** 默认情况下，AnythingLLM 使用其内置的 MiniLM 模型进行进程内嵌入，并将向量存储在自带的 LanceDB 中。若要改用本技术栈的 [Embeddings](https://github.com/hwdsl2/docker-embeddings) 服务（BAAI/bge-small-en-v1.5）和/或本技术栈启用了 pgvector 的 Postgres，请编辑 `docker-compose.yml` 中的 `anythingllm` 服务：注释掉 `EMBEDDING_ENGINE=native` 并取消注释下方的可选启用代码块。同时取消注释 `depends_on` 备注，以便 embeddings/db 服务先启动。启用 `VECTOR_DB=pgvector` 且未设置 `PGVECTOR_CONNECTION_STRING` 时，AnythingLLM 会自动使用 `ai-stack-shared` 中生成的 Postgres 密码。AnythingLLM 首次使用时会自动创建 `vector` 扩展和 `anythingllm_vectors` 表。⚠️ 在现有部署上切换嵌入引擎或向量存储会使之前嵌入的文档不兼容 — 切换后请重新嵌入您的工作区。

有关详细配置选项、API 参考和模型管理，请参阅各服务仓库的文档。

## 面向互联网的部署

默认情况下，所有服务通过纯 HTTP 监听。对于面向互联网的部署，可以使用内置的 Caddy 叠加文件添加自动 HTTPS。在代理模式下，Caddy 是唯一监听公网 `80` 和 `443` 端口的服务；AnythingLLM 和 LiteLLM 的直接端口会重新绑定到 `127.0.0.1`。

前提条件：

- Docker Compose `2.24.4+`（代理叠加文件的端口覆盖需要此版本）
- 域名的 DNS `A`/`AAAA` 记录指向此服务器
- 防火墙/安全组已开放入站 `80/tcp`、`443/tcp`，最好也开放 `443/udp`
- 主机上没有其他服务占用 `80` 或 `443` 端口

**CPU 技术栈：**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.yml -f docker-compose.proxy.yml up -d
```

**CUDA 技术栈：**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.cuda.yml -f docker-compose.proxy.yml up -d
```

打开 `https://chat.example.com`（替换为你的 `DOMAIN`）访问 AnythingLLM。在代理模式下，主机本机仍可访问 `http://127.0.0.1:3001` 和 `http://127.0.0.1:4000/ui`，但服务器外部无法直接访问 `3001` 和 `4000` 端口。

标准 compose 文件会在 `4000` 端口发布 LiteLLM。代理叠加文件会将该直接端口改为仅 localhost 可访问，且内置 Caddyfile 默认只路由 AnythingLLM。取消注释可选的 LiteLLM 主机名配置块会通过 Caddy 暴露 LiteLLM，请妥善保管 LiteLLM 主密钥。

故障排查：

```bash
docker logs ai-stack-caddy
# 使用启动技术栈时相同的 -f 文件
docker compose -f docker-compose.yml -f docker-compose.proxy.yml ps
```

如果 Caddy 报告未知的 `request_body` 指令，请拉取当前的 `caddy:2` 镜像并重启叠加文件部署。

旧版 Docker Compose 或 Podman 用户仍可使用主机上的反向代理：将直接 HTTP 端口绑定到 localhost（例如 `"127.0.0.1:3001:3001/tcp"` 和 `"127.0.0.1:4000:4000/tcp"`），再反向代理到这些 localhost 端口。每个服务仓库都包含详细的[反向代理指南](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh.md#使用反向代理)，含 Caddy 和 nginx 示例。

将服务暴露到互联网时，请优先使用已生成的 API 密钥。对于已有且未设置密钥的部署，请先通过相应的 env 文件设置 API 密钥，再对外发布这些服务。

## 备份与恢复

您的 API 密钥、模型和配置存储在 Docker 卷中。升级或更改前请先备份：

```bash
# 导出 API 密钥（在容器运行时）
docker exec ollama ollama_manage --getkey
docker exec litellm litellm_manage --getkey
docker exec mcp mcp_manage --getkey
# 可选服务；如果容器未启用或未运行则忽略
docker exec whisper whisper_manage --getkey 2>/dev/null || true
docker exec whisper-live whisper_live_manage --getkey 2>/dev/null || true
docker exec kokoro kokoro_manage --getkey 2>/dev/null || true
docker exec embeddings embed_manage --getkey 2>/dev/null || true
docker exec docling docling_manage --getkey 2>/dev/null || true

# 备份所有卷（先停止服务）
# 停止并移除所有容器（数据保留在 Docker 卷中）
docker compose down
mkdir -p backups
for vol in ollama-data litellm-data litellm-db ai-stack-shared embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data caddy-data caddy-config; do
  docker volume inspect "$vol" >/dev/null 2>&1 && \
    docker run --rm -v "${vol}:/source:ro" -v "$(pwd)/backups:/backup" \
      alpine tar czf "/backup/${vol}.tar.gz" -C /source .
done
```

**注：** 请将 `ai-stack-shared` 与 `litellm-db` 一起备份；全新安装会将生成的 PostgreSQL 密码存储在那里。`ollama-shared`、`mcp-shared` 和 `litellm-shared` 卷是临时密钥共享卷，无需备份。

有关恢复说明、服务器迁移和完整的升级前检查清单，请参阅[备份与恢复](docs/backup-restore-zh.md)指南。

## PostgreSQL 凭据

全新的 Docker Compose 安装会自动生成随机 PostgreSQL 密码，并将其存储在 `ai-stack-shared` 卷中。现有默认安装会继续使用旧的 `litellm` 数据库密码以保持兼容。

如果您之前自定义过数据库密码，请在运行 `docker compose up -d` 前在 shell 环境中将 `LITELLM_POSTGRES_PASSWORD` 设置为当前密码，或在 `litellm.env` 中保留显式的 `LITELLM_DATABASE_URL` 覆盖。

## 更新镜像

将所有服务更新到最新版本：

```bash
git pull
docker compose pull
docker compose up -d
./stack-check.sh
```

技术栈重启后，运行 `./stack-check.sh` 确认服务和生成的凭据配置正常。

`git pull` 用于更新所有项目文件（包括 compose 文件的更改）；`docker compose pull` 用于更新服务镜像。如果您自定义过 `docker-compose.yml`，`git pull` 将自动合并更改，或在同一行存在冲突时提示您解决冲突。

**旧安装的一次性提示：** 如果您在 `.env` 持久化修复之前设置过 AnythingLLM 密码，升级后的第一次容器重建可能会清除该密码，使 AnythingLLM 处于未受保护状态。更新后，请立即打开 AnythingLLM 并确认密码保护仍然启用。如果没有，请在 **Settings → Security** 中设置新密码。之后的容器重建会保留该密码。

AnythingLLM 固定为稳定发布标签，而不是 `latest`，因为上游 `latest` 镜像跟踪 master 分支。有新的 AnythingLLM 发布版本时，请先备份，更新 compose 文件中的标签，然后运行上述命令。

您的数据保存在 Docker 卷中。**升级前请务必[备份](#备份与恢复)。**

## 授权协议

Copyright (C) 2026 Lin Song   
本项目以 [MIT 许可证](https://opensource.org/licenses/MIT) 授权。

本项目是独立的 Docker 配置，与 Docker, Inc.、Ollama、Berri AI（LiteLLM）、Hugging Face、hexgrad（Kokoro）、OpenAI、SYSTRAN 或 MCPHub 无关联，未获其背书或赞助。Docker 是 Docker, Inc. 的商标或注册商标。
