[English](backup-restore.md) | [简体中文](backup-restore-zh.md) | [繁體中文](backup-restore-zh-Hant.md) | [Русский](backup-restore-ru.md)

# 备份与恢复

本指南介绍如何备份和恢复 Docker AI Stack 数据，包括 API 密钥、模型权重和服务配置。**升级镜像前请务必备份。**

## 卷中存储的内容

每个服务将数据存储在命名的 Docker 卷中：

| 卷名称 | 服务 | 包含内容 |
|---|---|---|
| `ollama-data` | Ollama | 已下载的模型、API 密钥、端口/服务器配置 |
| `litellm-data` | LiteLLM | API 密钥、代理配置 |
| `embeddings-data` | Embeddings | 嵌入模型缓存 |
| `whisper-data` | Whisper | Whisper 模型缓存 |
| `kokoro-data` | Kokoro | TTS 模型/语音缓存 |
| `mcp-data` | MCP Gateway | API 密钥、工具配置 |

**重要提示：** Ollama、LiteLLM 和 MCP Gateway 的 API 密钥在首次启动时自动生成，存储在这些卷中。如果丢失卷，密钥也会丢失。已连接的客户端需要更新为新密钥。

## 导出 API 密钥

在进行任何维护操作之前，请保存当前的 API 密钥：

```bash
echo "=== API Keys ===" > ai-stack-keys.txt
echo "Ollama:  $(docker exec ollama ollama_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo "LiteLLM: $(docker exec litellm litellm_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo "MCP:     $(docker exec mcp mcp_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo ""
echo "Keys saved to ai-stack-keys.txt"
cat ai-stack-keys.txt
```

请安全存储此文件 — 它包含凭据。

## 备份所有卷

先停止技术栈以确保数据一致性：

```bash
# 停止服务
docker compose down

# 创建备份目录
mkdir -p backups

# 备份所有卷
for vol in ollama-data litellm-data embeddings-data whisper-data kokoro-data mcp-data; do
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
docker compose down

docker run --rm \
  -v ollama-data:/source:ro \
  -v "$(pwd)/backups:/backup" \
  alpine tar czf /backup/ollama-data.tar.gz -C /source .
```

### 轻量级技术栈

如果您运行的是轻量级技术栈（如 chat-only），则只存在相关的卷。上述备份循环会自动跳过不存在的卷。

## 恢复所有卷

**警告：** 恢复操作会覆盖目标卷中的所有现有数据，包括 API 密钥。使用旧密钥的客户端需要更新。

```bash
# 停止服务
docker compose down

# 从备份恢复所有卷
for vol in ollama-data litellm-data embeddings-data whisper-data kokoro-data mcp-data; do
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
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack

# 将备份文件复制到位
cp -r /path/to/backups ./backups

# 恢复卷（自动创建）
for vol in ollama-data litellm-data embeddings-data whisper-data kokoro-data mcp-data; do
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
# 停止故障的技术栈
docker compose down

# 从备份恢复
#（按照上述恢复步骤操作）

# 如有需要，将镜像固定到之前的可用版本
# 编辑 docker-compose.yml 使用特定的镜像标签
docker compose up -d
```

## 注意事项

- **模型权重**（在 `ollama-data` 中）可能很大（每个模型数 GB）。仅在重新下载不便时才需备份（网速慢、自定义微调模型）。
- **模型缓存**（`embeddings-data`、`whisper-data`、`kokoro-data`）在首次启动时自动下载。如果带宽不是问题，可以跳过备份 — 它们会被重新下载。
- **关键卷**，应始终备份：`ollama-data`（如有自定义模型）、`litellm-data`、`mcp-data`（包含 API 密钥和配置）。
- 备份文件是标准的 `.tar.gz` 压缩包。可以使用以下命令查看内容：`tar tzf backups/ollama-data.tar.gz`
