[English](troubleshooting.md) | [简体中文](troubleshooting-zh.md) | [繁體中文](troubleshooting-zh-Hant.md) | [Русский](troubleshooting-ru.md)

# 故障排查

本指南帮助你在更改配置或提交 issue 之前诊断 Self-Hosted AI Stack 问题。

## 快速排查

先从以下检查开始：

```bash
# 显示容器状态和已发布端口
docker compose ps

# 运行技术栈健康检查
./stack-check.sh

# 查看某个服务的最近日志
docker compose logs --tail=100 <service>
```

如果启动技术栈时使用了多个 compose 文件，诊断命令也应使用相同文件：

```bash
docker compose -f docker-compose.yml -f docker-compose.proxy.yml ps
docker compose -f docker-compose.cuda.yml -f docker-compose.proxy.yml logs --tail=100 litellm
```

对于 Podman，`stack-check.sh` 会自动检测容器引擎。也可以强制指定：

```bash
CONTAINER_ENGINE=podman ./stack-check.sh
```

## 启动和就绪状态

首次启动时，服务可能需要几分钟完成初始化。模型下载、数据库启动和 AnythingLLM 初始化都会影响就绪时间。

如果 `./stack-check.sh` 在启动后立即失败：

1. 等待几分钟。
2. 再次运行 `./stack-check.sh`。
3. 查看失败服务的日志。

常用服务日志命令：

```bash
docker compose logs --tail=100 ollama
docker compose logs --tail=100 litellm
docker compose logs --tail=100 mcp
docker compose logs --tail=100 anythingllm
```

LiteLLM 依赖 Ollama、MCP Gateway 和 PostgreSQL。AnythingLLM 依赖 LiteLLM。如果依赖项仍在启动，下游服务可能暂时尚未就绪。

## Ollama 和本地模型问题

技术栈会自动启动 Ollama，但在发送 LLM 请求前必须先拉取至少一个模型：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

列出已下载模型：

```bash
docker exec ollama ollama_manage --listmodels
```

如果 LiteLLM 或 AnythingLLM 报告模型错误，请先确认该模型已存在于 Ollama 中，并确认 `./stack-check.sh` 显示 LiteLLM 路由测试成功。

对于 Ollama 镜像相关问题，请使用 `docker-ollama` 仓库。对于与此 Docker 镜像无关的上游 Ollama 行为，请使用上游 Ollama issue tracker。

## LiteLLM 问题

LiteLLM 默认暴露在端口 `4000`。管理界面地址：

```text
http://<server-ip>:4000/ui
```

用户名使用 `admin`，密码使用 LiteLLM master key。

显示 LiteLLM master key：

```bash
docker exec litellm litellm_manage --showkey
```

检查 LiteLLM 健康端点：

```bash
curl http://localhost:4000/health/liveliness
```

如果本地 Ollama 模型无法通过 LiteLLM 使用：

- 确认已下载 Ollama 模型。
- 确认 compose 文件或 env 文件中存在 `LITELLM_OLLAMA_BASE_URL=http://ollama:11434`。
- 查看 `docker compose logs --tail=100 litellm`。
- 运行 `./stack-check.sh` 并查看 LiteLLM 路由检查。

compose 文件会通过 Docker 卷自动将 Ollama 和 MCP API 密钥共享给 LiteLLM。除非已有备份，否则不要删除 `ollama-data`、`mcp-data` 或 `litellm-data`。

## MCP Gateway 问题

MCP Gateway 在 Docker 网络内部的端口 `3000` 上运行。主 compose 文件默认不向主机暴露该端口。

显示 MCP Gateway API 密钥：

```bash
docker exec mcp mcp_manage --showkey
```

从容器内部检查健康端点：

```bash
docker exec mcp curl -sf http://127.0.0.1:3000/health
```

如果外部 MCP 客户端需要直接访问，请取消 `docker-compose.yml` 中 `3000:3000` 端口映射的注释，然后重启服务。面向公网访问时，请放在 HTTPS 后面，并妥善保管 API 密钥。

## AnythingLLM 问题

AnythingLLM 默认暴露在端口 `3001`：

```text
http://<server-ip>:3001
```

首次启动时会生成随机管理员密码，并保存在 `anythingllm-data` 卷中。使用以下命令获取：

```bash
docker exec anythingllm cat /app/server/storage/.initial_admin_password
```

或查看首次启动日志：

```bash
docker compose logs anythingllm | grep -A4 "FIRST RUN"
```

如果 AnythingLLM 无法连接本地模型：

- 确认 Docker 网络内部可访问 LiteLLM 的 `http://litellm:4000/v1`。
- 确认模型 `ollama/llama3.2:3b` 存在，或将 AnythingLLM 更新为使用已存在的模型。
- 查看 `docker compose logs --tail=100 anythingllm`。

如果你已在 Settings 中更改 AnythingLLM 密码，`.initial_admin_password` 可能不再匹配当前密码。升级或迁移前请备份 `anythingllm-data`。

## 可选服务

在完整 compose 文件中，Embeddings 和 Whisper 默认启用。Kokoro、Docling 和 WhisperLive 为降低内存使用而默认注释掉。

启用被注释的服务：

1. 在 `docker-compose.yml` 或 `docker-compose.cuda.yml` 中取消该服务的注释。
2. 取消文件底部对应命名卷的注释。
3. 如需自定义设置，请添加或挂载该服务的 env 文件。
4. 运行 `docker compose up -d`。

服务文档：

| 服务 | 仓库 |
|---|---|
| Ollama | https://github.com/hwdsl2/docker-ollama |
| LiteLLM | https://github.com/hwdsl2/docker-litellm |
| Embeddings | https://github.com/hwdsl2/docker-embeddings |
| Whisper | https://github.com/hwdsl2/docker-whisper |
| WhisperLive | https://github.com/hwdsl2/docker-whisper-live |
| Kokoro | https://github.com/hwdsl2/docker-kokoro |
| MCP Gateway | https://github.com/hwdsl2/docker-mcp-gateway |
| Docling | https://github.com/hwdsl2/docker-docling |

## GPU 和 CUDA

如需 NVIDIA GPU 加速，请启动 CUDA compose 文件：

```bash
docker compose -f docker-compose.cuda.yml up -d
```

要求：

- NVIDIA GPU
- NVIDIA 驱动
- NVIDIA Container Toolkit
- CUDA 镜像需要 `linux/amd64` 主机

如果未使用 GPU 加速：

- 确认启动的是 `docker-compose.cuda.yml`，而不是 `docker-compose.yml`。
- 查看 `docker compose logs --tail=100 ollama`，以及启用 Whisper 时的 `docker compose logs --tail=100 whisper`。
- 确认主机可以通过 NVIDIA Container Toolkit 运行 GPU 容器。

对于 Podman，Compose 的 `deploy.resources` GPU 块不会生效。请按照 README 中的 Podman CDI 说明操作。

## 反向代理和公网部署

技术栈包含用于 HTTPS 的 Caddy 叠加文件：

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.yml -f docker-compose.proxy.yml up -d
```

在代理模式下，Caddy 是端口 `80` 和 `443` 上的公网监听服务。AnythingLLM 和 LiteLLM 的直接端口会重新绑定到 `127.0.0.1`。

查看 Caddy 日志：

```bash
docker logs ai-stack-caddy
```

如果 Caddy 无法获取证书，请检查：

- DNS `A`/`AAAA` 记录指向此服务器。
- 端口 `80/tcp` 和 `443/tcp` 可从公网访问。
- 没有其他服务占用端口 `80` 或 `443`。
- `DOMAIN` 和 `ACME_EMAIL` 的值正确。

公网暴露可选服务时，请优先使用已生成的 API 密钥。对于已有且未设置密钥的部署，请先通过相应的 env 文件设置 API 密钥，或将服务置于代理认证之后再对外发布。

## 卷、备份和更新

API 密钥、模型缓存、聊天记录、服务配置和 Caddy 证书状态存储在 Docker 卷中。升级、迁移或执行破坏性清理前请先备份。

请参阅完整备份指南：

- [备份与恢复](backup-restore-zh.md)

排查问题时，除非已有当前备份，否则不要删除卷。删除卷可能会移除 API 密钥、模型缓存、AnythingLLM 数据、LiteLLM 配置、MCP Gateway 设置、可选服务密钥和 Caddy 证书。

更新镜像后运行：

```bash
docker compose pull
docker compose up -d
./stack-check.sh
```

## 在哪里提交 issue

以下问题请提交到 `self-hosted-ai-stack`：

- compose 文件问题
- 跨服务连接问题
- 技术栈启动或健康检查问题
- 本仓库中的 Caddy 叠加文件问题
- 本仓库文档问题

以下问题请提交到对应的单个服务仓库：

- 镜像特定行为
- 服务特定 env 选项
- 服务特定 API 行为
- 服务特定模型下载或缓存行为

如果问题出在上游应用本身，而不是 Docker 镜像或技术栈连接方式，请提交到上游。

## issue 中应包含的信息

请包含：

- 主机 OS 和架构
- Docker 或 Podman 版本
- 使用的 compose 文件，例如 `docker-compose.yml` 或 `docker-compose.cuda.yml`
- CPU 或 GPU 模式
- `docker compose ps` 输出
- `./stack-check.sh` 输出
- 相关日志，例如 `docker compose logs --tail=100 litellm`
- 自定义 env 文件或 compose 变更，并移除密钥

发布前请移除 API 密钥、密码、提供商密钥、令牌、包含私密路径的公网 URL，以及日志中的任何敏感内容。
