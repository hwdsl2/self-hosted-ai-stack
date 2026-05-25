[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 聊天界面

本地 ChatGPT 般的体验 — 基于本地 LLM 和 OpenAI 兼容 API 网关的 Web 聊天界面。

**服务：** Ollama (LLM) + LiteLLM (网关) + [AnythingLLM](https://github.com/mintplex-labs/anything-llm) (聊天界面)

**内存：** ~5 GB RAM（使用 3B 模型）

**平台：** `linux/amd64`、`linux/arm64`

## 架构

```mermaid
graph LR
    U["🌐 浏览器"] -->|聊天| A["AnythingLLM<br/>(聊天界面)"]
    A -->|API| L["LiteLLM<br/>(AI 网关)"]
    L -->|路由至| O["Ollama<br/>(本地 LLM)"]
```

## 服务

| 服务 | 用途 | 默认端口 |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md)** | 运行本地 LLM 模型（llama3、qwen、mistral 等） | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)** | 带管理界面的 AI 网关 — 将请求路由至 Ollama 及 100+ 供应商 | `4000` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | 基于 Web 的聊天界面，支持工作区、RAG 和智能体 | `3001` |

## 快速开始

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/chat-ui
docker compose up -d
```

**拉取模型**（发出 LLM 请求前必须执行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

**打开聊天界面：**

AnythingLLM 已预配置连接到 LiteLLM。API 密钥通过 Docker 卷自动共享 — 无需手动设置。

**注：** 首次启动时，AnythingLLM 可能需要几分钟才能就绪（等待 LiteLLM API 密钥）。可使用 `docker logs anythingllm` 查看进度。

在浏览器中打开 `http://<服务器IP>:3001` — 即可直接开始聊天。LLM 供应商、基础 URL 和模型已预配置。

**注：** 对于面向公网的部署，**强烈建议**使用[反向代理](#使用反向代理)添加 HTTPS。在这种情况下，还应将 `docker-compose.yml` 中的 `"3001:3001/tcp"` 改为 `"127.0.0.1:3001:3001/tcp"`，并将 `"4000:4000/tcp"` 改为 `"127.0.0.1:4000:4000/tcp"`，以防止直接访问未加密的端口。请[设置密码](https://docs.useanything.com/features/security-and-access)保护 AnythingLLM，尤其是在服务器可从公网访问时。

## GPU 加速 (NVIDIA CUDA)

如需 NVIDIA GPU 加速，请使用 CUDA 编排文件：

```bash
docker compose -f docker-compose.cuda.yml up -d
```

**要求：** NVIDIA GPU、[NVIDIA 驱动](https://www.nvidia.com/en-us/drivers/) 535+，以及在宿主机上安装 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)。CUDA 镜像仅支持 `linux/amd64`。

## 不使用 Docker Compose 运行

如需直接使用 `docker run` 命令，请先创建共享网络以便服务之间通信：

```bash
docker network create ai-stack
```

然后在共享网络上启动各服务：

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
    mintplexlabs/anythingllm \
    /usr/local/bin/chat-ui-bootstrap.sh
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

**在 Playground 中试用：**

在管理界面中，点击左侧菜单的 **Playground**。从下拉列表中选择本地模型（例如 `ollama/llama3.2:3b`）并开始对话 — 这是验证本地大语言模型端到端正常工作的一种快速方式。

## 自定义配置

每个服务可以通过可选的 env 文件进行配置。从相应仓库复制示例 env 文件，编辑后取消 `docker-compose.yml` 中的卷挂载注释：

| 服务 | Env 文件 | 仓库 |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md) |

AnythingLLM 通过其 Web 界面 `http://<服务器IP>:3001` 进行配置。您可以在 **Settings** 中更改 LLM 供应商、模型、嵌入引擎和其他设置。详情请参阅 [AnythingLLM 文档](https://docs.useanything.com/)。

**提示：** 如果您同时运行其他子栈（例如 [voice-pipeline](../voice-pipeline/README-zh.md)、[rag-pipeline](../rag-pipeline/README-zh.md)），可以通过 AnythingLLM 的设置页面将其指向这些服务 — 例如使用 `docker-whisper` 进行语音转文字，或使用 `docker-embeddings` 进行向量嵌入。

有关详细配置选项、API 参考和模型管理，请参阅各服务仓库的文档。

## 使用反向代理

如需面向公网部署，可在 AnythingLLM 前置反向代理处理 HTTPS 终止。在本地或可信网络中使用无需 HTTPS，但将聊天界面暴露在公网时建议启用 HTTPS。

从反向代理访问 AnythingLLM 容器时使用以下地址之一：

- **`anythingllm:3001`** — 如果反向代理作为容器运行在与 AnythingLLM **同一 Docker 网络**中（例如定义在同一 `docker-compose.yml` 中）。
- **`127.0.0.1:3001`** — 如果反向代理运行在**主机上**且端口 `3001` 已发布（默认 `docker-compose.yml` 会发布该端口）。

**使用 [Caddy](https://caddyserver.com/docs/)（[Docker 镜像](https://hub.docker.com/_/caddy)）的示例**（自动 Let's Encrypt TLS，反向代理在同一 Docker 网络中）：

`Caddyfile`：
```
chat.example.com {
  reverse_proxy anythingllm:3001
}
```

**使用 nginx 的示例**（反向代理运行在主机上）：

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

**重要提示：** AnythingLLM 包含内置的用户认证系统——将服务暴露到互联网时，请在首次设置时设置强密码。

## 备份和恢复

有关备份/恢复说明，请参阅[备份和恢复](../../docs/backup-restore-zh.md)指南。

## 更新镜像

将所有服务更新到最新版本：

```bash
docker compose pull
docker compose up -d
```

您的数据保存在 Docker 卷中。 **升级前务必先[备份](../../docs/backup-restore-zh.md)。**

## 示例

```bash
# 在浏览器中打开聊天界面
open http://localhost:3001
```

或直接使用 LiteLLM API：

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

curl http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "ollama/llama3.2:3b",
      "messages": [{"role": "user", "content": "Hello, how are you?"}]
    }' | jq -r '.choices[0].message.content'
