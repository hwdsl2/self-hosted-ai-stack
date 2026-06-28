[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 纯聊天

最小化本地聊天设置 — 本地 LLM 搭配 OpenAI 兼容 API 网关。

**服务：** Ollama (LLM) + LiteLLM (网关)

**内存：** ~4.5 GB RAM（使用 3B 模型）

**平台：** `linux/amd64`、`linux/arm64`

## 架构

```mermaid
graph LR
    C["💬 AI 客户端"] -->|聊天| L["LiteLLM<br/>(AI 网关)"]
    L -->|路由至| O["Ollama<br/>(本地 LLM)"]
```

## 服务

| 服务 | 用途 | 默认端口 |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md)** | 运行本地 LLM 模型（llama3、qwen、mistral 等） | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md)** | 带管理界面的 AI 网关 — 将请求路由至 Ollama 及 100+ 供应商 | `4000` |

> **注意：** 轻量级子栈默认共用容器名称、端口和 Docker 卷名称。使用默认 compose 文件时，一次只运行一个子栈变体；切换到其他变体前，请先停止当前变体。

默认访问方式：

- LiteLLM 发布在宿主机端口 `4000`。
- Ollama 仅在 Docker 网络内部访问；宿主机或浏览器访问请使用 LiteLLM。

## 快速开始

**要求：**

- 已安装 Docker 的 Linux 服务器（本地或云端）
- 足够运行此子栈和所选模型的内存（见上方内存估算）
- 对于较大的 LLM 模型（8B+），建议 16 GB 或更多内存

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack/stacks/chat-only
docker compose up -d
```

**拉取模型**（发出 LLM 请求前必须执行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

运行健康检查以验证服务是否正常工作：

```bash
# 从此子栈目录运行：
../../stack-check.sh

# 或从仓库根目录运行：
# ./stack-check.sh
```

> **提示：** 首次启动时，服务可能需要几分钟完成初始化。如有检查失败，请稍等后再次运行 `../../stack-check.sh`。使用 `docker compose logs` 查看进度。

**获取 LiteLLM master key**（用于登录管理界面以及直接发起 LLM API 请求）：

```bash
docker exec litellm litellm_manage --showkey
```

**访问 LiteLLM 管理界面：**

在浏览器中打开 `http://<server-ip>:4000/ui`。使用用户名 `admin` 和您的 LiteLLM master key 作为密码登录。管理界面提供虚拟密钥管理、支出追踪和模型配置功能。

> **提示：** 在管理界面中，点击左侧菜单的 **Playground**。从下拉列表中选择本地模型（例如 `ollama-chat/llama3.2:3b`）并开始对话，这是验证本地 LLM 端到端正常工作的一种快速方式。

**停止子栈：**

```bash
# 停止并移除容器（数据会保留在 Docker 卷中）
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
```

**注：** 共享网络允许服务通过容器名称互相访问（例如 LiteLLM 通过 `http://ollama:11434` 连接 Ollama）。

**拉取模型**（发出 LLM 请求前必须执行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## 使用计数

此技术栈参与项目的匿名、聚合的 GitHub release 资源下载计数。使用 `AI_STACK_DISABLE_USAGE_COUNTS=1 docker compose up -d` 启动可禁用；详情见[使用计数](../../README-zh.md#使用计数)。

## 自定义配置

每个服务可以通过可选的 env 文件进行配置。从相应仓库复制示例 env 文件，编辑后取消 `docker-compose.yml` 中的卷挂载注释：

| 服务 | Env 文件 | 仓库 |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md) |

有关详细配置选项、API 参考和模型管理，请参阅各服务仓库的文档。

## 面向互联网的部署

默认情况下，LiteLLM 会发布在宿主机端口 `4000`；各子栈的辅助 API 默认为仅 localhost 访问或仅内部访问，除非您修改其端口映射。对于面向互联网的部署，请在技术栈前面放置反向代理（例如 [Caddy](https://caddyserver.com/)、Nginx 或 Traefik）以提供 HTTPS；代理这些端口时，请将 `4000` 等直接 HTTP 端口绑定到 `127.0.0.1`。每个服务仓库都包含详细的[反向代理指南](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh.md#使用反向代理)，含 Caddy 和 nginx 示例。

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

> **注意：** 下面的示例使用 `jq` 格式化 JSON 响应。如尚未安装，请先安装。

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

curl http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "ollama/llama3.2:3b",
      "messages": [{"role": "user", "content": "Hello, how are you?"}]
    }' | jq -r '.choices[0].message.content'

```
