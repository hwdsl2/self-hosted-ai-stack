[English](backup-restore.md) | [简体中文](backup-restore-zh.md) | [繁體中文](backup-restore-zh-Hant.md) | [Русский](backup-restore-ru.md)

# 备份与恢复

本指南介绍如何备份和恢复 Self-Hosted AI Stack 数据，包括 API 密钥、模型权重和服务配置。**升级镜像前请务必备份。**

## 卷中存储的内容

每个服务将数据存储在命名的 Docker 卷中：

| 卷名称 | 服务 | 包含内容 |
|---|---|---|
| `ollama-data` | Ollama | 已下载的模型、API 密钥、端口/服务器配置 |
| `litellm-data` | LiteLLM | API 密钥、代理配置 |
| `litellm-db` | LiteLLM | PostgreSQL 数据库（使用数据、日志） |
| `embeddings-data` | Embeddings | 嵌入模型缓存、已生成的 API 密钥 |
| `whisper-data` | Whisper | Whisper 模型缓存、已生成的 API 密钥 |
| `whisper-live-data` | WhisperLive | 实时语音转文本模型缓存、已生成的 API 密钥 |
| `kokoro-data` | Kokoro | TTS 模型/语音缓存、已生成的 API 密钥 |
| `mcp-data` | MCP Gateway | API 密钥、工具配置 |
| `docling-data` | Docling | 文档转换模型缓存、已生成的 API 密钥 |
| `anythingllm-data` | AnythingLLM | 聊天记录、工作区、设置、上传的文档、**管理员密码**（`server/.env` 中的 `AUTH_TOKEN`/`JWT_SECRET`，以及首次运行时生成的 `.initial_admin_password` 副本） |
| `caddy-data` | Caddy | TLS 证书、私钥、OCSP staple、ACME 账户状态 |
| `caddy-config` | Caddy | Caddy 内部配置存储 |

**重要提示：** Ollama、LiteLLM、MCP Gateway，以及 Whisper、WhisperLive、Kokoro、Embeddings 和 Docling 的新持久化安装所生成的 API 密钥，都会存储在这些卷中。如果丢失卷，密钥也会丢失。已连接的客户端需要更新为新密钥。

**重要提示（AnythingLLM）：** 当前管理员密码及其 `JWT_SECRET` 位于 `anythingllm-data` 卷中的 `server/.env`。`.initial_admin_password` 只是首次运行时的密码副本；如果你已在 Settings 中更改密码，该文件可能已经过期。备份此卷会保留当前密码。在其他主机上恢复时会重用相同的密码 — 无需重新生成。

**重要提示（Caddy）：** 如果使用 HTTPS 代理叠加文件，请备份 `caddy-data`。它包含证书私钥和 ACME 账户状态。删除该卷会强制重新签发证书，并可能触发证书颁发机构的速率限制。

**注：** `ollama-shared`、`mcp-shared` 和 `litellm-shared` 卷是用于在服务之间自动传递 API 密钥的临时共享卷，无需备份——密钥已分别存储在 `ollama-data`、`mcp-data` 和 `litellm-data` 中，每次容器启动时会重新复制。

## 导出 API 密钥

在进行任何维护操作之前，请保存当前的 API 密钥：

```bash
echo "=== API Keys ===" > ai-stack-keys.txt
echo "Ollama:      $(docker exec ollama ollama_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "LiteLLM:     $(docker exec litellm litellm_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "MCP:         $(docker exec mcp mcp_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "Whisper:     $(docker exec whisper whisper_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "WhisperLive: $(docker exec whisper-live whisper_live_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "Kokoro:      $(docker exec kokoro kokoro_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "Embeddings:  $(docker exec embeddings embed_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo "Docling:     $(docker exec docling docling_manage --getkey 2>/dev/null)" >> ai-stack-keys.txt
echo ""
echo "Keys saved to ai-stack-keys.txt"
cat ai-stack-keys.txt
```

请安全存储此文件 — 它包含凭据。

## 备份所有卷

先停止技术栈以确保数据一致性：

```bash
# 停止并移除容器（数据保留在 Docker 卷中）
docker compose down

# 创建备份目录
mkdir -p backups

# 备份所有卷
for vol in ollama-data litellm-data litellm-db embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data caddy-data caddy-config; do
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "Backing up $vol..."
    docker run --rm \
      -v "${vol}:/source:ro" \
      -v "$(pwd)/backups:/backup" \
      alpine tar czf "/backup/${vol}.tar.gz" -C /source .
  else
    echo "Skipping $vol (not found)"
  fi
done

echo "Backup complete. Files:"
ls -lh backups/*.tar.gz
```

### 备份单个卷

```bash
# 停止并移除容器（数据保留在 Docker 卷中）
docker compose down

docker run --rm \
  -v ollama-data:/source:ro \
  -v "$(pwd)/backups:/backup" \
  alpine tar czf /backup/ollama-data.tar.gz -C /source .
```

### 轻量级技术栈

如果您运行的是轻量级技术栈（如 chat-only），则只存在相关的卷。上述备份循环会自动跳过不存在的卷。

### 热备份（无停机）PostgreSQL

如果不能停机，可以在服务运行时使用 `pg_dump` 备份 PostgreSQL 数据库：

```bash
docker exec litellm-db pg_dump -U litellm litellm | gzip > backups/litellm-db.sql.gz
```

从 SQL 转储恢复：

```bash
# 仅启动数据库容器
docker compose up -d litellm-db
sleep 5

# 删除并重建数据库，然后恢复
docker exec litellm-db dropdb -U litellm litellm --if-exists
docker exec litellm-db createdb -U litellm litellm
gunzip -c backups/litellm-db.sql.gz | docker exec -i litellm-db psql -U litellm litellm

# 启动其余服务
docker compose up -d
```

### 哪些卷需要停机？

| 卷 | 可以热备份？ | 备注 |
|---|---|---|
| `litellm-db` | ✅ 是（使用 `pg_dump`） | PostgreSQL 支持一致性热转储 |
| `embeddings-data` | ✅ 是 | 初始模型下载后为只读 |
| `whisper-data` | ✅ 是 | 初始模型下载后为只读 |
| `whisper-live-data` | ✅ 是 | 初始模型下载后为只读 |
| `kokoro-data` | ✅ 是 | 初始模型下载后为只读 |
| `docling-data` | ✅ 是 | 初始模型下载后为只读 |
| `ollama-data` | ⚠️ 先停止 | 模型拉取时有写入；无拉取进行中则安全 |
| `litellm-data` | ⚠️ 先停止 | 包含启动时可能写入的配置 |
| `mcp-data` | ⚠️ 先停止 | 包含启动时可能写入的配置 |
| `anythingllm-data` | ⚠️ 先停止 | 聊天会话期间有活跃写入 |
| `caddy-data` | ⚠️ 先停止 | 包含证书、私钥、OCSP staple 和 ACME 账户状态 |
| `caddy-config` | ⚠️ 先停止 | 可与 Caddy 一起备份，但重要性低于 `caddy-data` |

## 恢复所有卷

**警告：** 恢复操作会覆盖目标卷中的所有现有数据，包括 API 密钥。使用旧密钥的客户端需要更新。

```bash
# 停止并移除容器（数据保留在 Docker 卷中）
docker compose down

# 从备份恢复所有卷
for vol in ollama-data litellm-data litellm-db embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data caddy-data caddy-config; do
  backup_file="backups/${vol}.tar.gz"
  if [ -f "$backup_file" ]; then
    echo "Restoring $vol..."
    # 如果卷不存在则创建
    docker volume create "$vol" >/dev/null 2>&1 || true
    # 清除现有数据并恢复
    docker run --rm \
      -v "${vol}:/target" \
      -v "$(pwd)/backups:/backup:ro" \
      alpine sh -c "rm -rf /target/* /target/.[!.]* 2>/dev/null; tar xzf /backup/${vol}.tar.gz -C /target"
  else
    echo "Skipping $vol (no backup file found)"
  fi
done

# 重启服务
docker compose up -d

echo "Restore complete. Verify with: ./stack-check.sh"
```

### 恢复单个卷

**警告：** 此操作会覆盖目标卷中的所有现有数据。

```bash
# 停止并移除容器（数据保留在 Docker 卷中）
docker compose down

docker volume create ollama-data >/dev/null 2>&1 || true
docker run --rm \
  -v ollama-data:/target \
  -v "$(pwd)/backups:/backup:ro" \
  alpine sh -c "rm -rf /target/* /target/.[!.]* 2>/dev/null; tar xzf /backup/ollama-data.tar.gz -C /target"

docker compose up -d
```

## 迁移到新服务器

1. **在旧服务器上：** 备份所有卷并导出密钥（参见上文）
2. **传输文件：** 将 `backups/` 目录和 `ai-stack-keys.txt` 复制到新服务器
3. **在新服务器上：**

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack

# 将备份文件复制到位
cp -r /path/to/backups ./backups

# 恢复卷（自动创建）
for vol in ollama-data litellm-data litellm-db embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data caddy-data caddy-config; do
  backup_file="backups/${vol}.tar.gz"
  if [ -f "$backup_file" ]; then
    echo "Restoring $vol..."
    docker volume create "$vol" >/dev/null 2>&1 || true
    docker run --rm \
      -v "${vol}:/target" \
      -v "$(pwd)/backups:/backup:ro" \
      alpine sh -c "tar xzf /backup/${vol}.tar.gz -C /target"
  fi
done

# 启动技术栈
docker compose up -d

# 验证
./stack-check.sh
```

您的 API 密钥、模型和配置将被保留。客户端可以使用相同的密钥连接。

## 升级前检查清单

在运行 `docker compose pull && docker compose up -d` 之前：

1. **导出 API 密钥** — 保存到文件（参见上文）
2. **备份卷** — 至少备份 `ollama-data`、`litellm-data` 和 `mcp-data`
3. **拉取新镜像** — `docker compose pull`
4. **启动更新后的技术栈** — `docker compose up -d`
5. **运行健康检查** — `./stack-check.sh`
6. **验证 API 密钥** — 确认密钥未变（升级后应保持不变）

如果升级后出现问题：

```bash
# 停止并移除容器（数据保留在 Docker 卷中）
docker compose down

# 从备份恢复
#（按照上述恢复步骤操作）

# 如有需要，将镜像固定到之前的可用版本
# 编辑 docker-compose.yml 使用特定的镜像标签
docker compose up -d
```

## 注意事项

- **模型权重**（在 `ollama-data` 中）可能很大（每个模型数 GB）。仅在重新下载不便时才需备份（网速慢、自定义微调模型）。
- **模型缓存**（`embeddings-data`、`whisper-data`、`whisper-live-data`、`kokoro-data`、`docling-data`）在首次启动时自动下载。如果带宽不是问题，可以跳过备份 — 它们会被重新下载。
- **关键卷**，应始终备份：密钥/配置卷（`litellm-data`、`litellm-db`、`mcp-data`），需要保留模型或已生成密钥的服务数据卷（`ollama-data`、`embeddings-data`、`whisper-data`、`whisper-live-data`、`kokoro-data`、`docling-data`），`anythingllm-data`（聊天记录和工作区），以及 `caddy-data`（如果使用 HTTPS 代理叠加文件）。
- 备份文件是标准的 `.tar.gz` 压缩包。可以使用以下命令查看内容：`tar tzf backups/ollama-data.tar.gz`

### 各堆栈使用的卷

| 堆栈 | 使用的卷 |
|---|---|
| chat-only | `ollama-data`, `litellm-data`, `litellm-db`, `ollama-shared` |
| chat-ui | `ollama-data`, `litellm-data`, `litellm-db`, `anythingllm-data`, `ollama-shared`, `litellm-shared` |
| voice-pipeline | `ollama-data`, `litellm-data`, `litellm-db`, `whisper-data`, `kokoro-data`, `ollama-shared` |
| voice-chat | `ollama-data`, `litellm-data`, `litellm-db`, `anythingllm-data`, `whisper-data`, `kokoro-data`, `ollama-shared`, `litellm-shared` |
| rag-pipeline | `ollama-data`, `litellm-data`, `litellm-db`, `embeddings-data`, `ollama-shared` |
| rag-pipeline-full | `ollama-data`, `litellm-data`, `litellm-db`, `embeddings-data`, `docling-data`, `ollama-shared` |
| code-assistant | `ollama-data`, `litellm-data`, `litellm-db`, `embeddings-data`, `mcp-data`, `ollama-shared`, `mcp-shared` |
| ai-tools | `ollama-data`, `litellm-data`, `litellm-db`, `mcp-data`, `ollama-shared`, `mcp-shared` |
| HTTPS 代理叠加文件 | `caddy-data`, `caddy-config` |
