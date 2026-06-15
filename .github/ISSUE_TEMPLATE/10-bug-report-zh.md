---
name: 错误报告
about: 请使用这个模板来提交 bug
title: ''
labels: ''
assignees: ''

---
**任务列表**

- [ ] 我已阅读[自述文件](https://github.com/hwdsl2/self-hosted-ai-stack/blob/main/README-zh.md)或相关 stack README
- [ ] 我搜索了已有的 [Issues](https://github.com/hwdsl2/self-hosted-ai-stack/issues?q=is%3Aissue)
- [ ] 这个问题是关于 self-hosted-ai-stack、技术栈集成，或者我不确定哪个服务受影响

**问题描述**
使用清楚简明的语言描述这个问题。

**受影响的服务**
示例：Ollama、LiteLLM、AnythingLLM、Whisper、WhisperLive、Kokoro、Embeddings、MCP Gateway、Docling、PostgreSQL/pgvector、Caddy、Docker Compose、不确定。

**使用的技术栈**
- [ ] 完整技术栈
- [ ] `chat-ui`
- [ ] `voice-pipeline`
- [ ] `voice-chat`
- [ ] `rag-pipeline`
- [ ] `rag-pipeline-full`
- [ ] `code-assistant`
- [ ] `ai-tools`
- [ ] `chat-only`
- [ ] 其它 / 自定义

**重现步骤**
重现该问题的步骤：

1. ...
2. ...

**期待的正确结果**
简要描述你期望发生的结果。

**环境**
- Docker 主机操作系统: [例如 Ubuntu 24.04]
- 服务提供商（如果适用）: [例如 AWS, GCP, 家用服务器]
- CPU 架构: [例如 amd64, arm64]
- GPU/CUDA 配置（如果适用）：
- 使用的 Compose 命令/文件: [例如 `docker compose up -d`, `docker-compose.cuda.yml`]
- 修改过的 env 文件或 compose 文件（请删除敏感信息）：

**检查和日志**
如果可以，请包含以下输出：

```bash
./stack-check.sh
docker compose logs
```

对于某个受影响服务，请包含：

```bash
docker compose logs <service>
```

**是否可在 self-hosted-ai-stack 之外重现？**
如果你知道这个问题是否也会在单个服务仓库中出现，请在这里说明。

**其它信息**
添加关于该问题的其它信息。
