[English](backup-restore.md) | [简体中文](backup-restore-zh.md) | [繁體中文](backup-restore-zh-Hant.md) | [Русский](backup-restore-ru.md)

# 備份與還原

本指南介紹如何備份和還原 Docker AI Stack 資料，包括 API 金鑰、模型權重和服務設定。**升級映像檔前請務必備份。**

## 磁碟區中儲存的內容

每個服務將資料儲存在命名的 Docker 磁碟區中：

| 磁碟區名稱 | 服務 | 包含內容 |
|---|---|---|
| `ollama-data` | Ollama | 已下載的模型、API 金鑰、連接埠/伺服器設定 |
| `litellm-data` | LiteLLM | API 金鑰、代理設定 |
| `litellm-db` | LiteLLM | PostgreSQL 資料庫（使用資料、日誌） |
| `embeddings-data` | Embeddings | 嵌入模型快取 |
| `whisper-data` | Whisper | Whisper 模型快取 |
| `whisper-live-data` | WhisperLive | 即時語音轉文字模型快取 |
| `kokoro-data` | Kokoro | TTS 模型/語音快取 |
| `mcp-data` | MCP Gateway | API 金鑰、工具設定 |
| `docling-data` | Docling | 文件轉換模型快取 |
| `anythingllm-data` | AnythingLLM | 聊天記錄、工作區、設定、上傳的文件、**管理員密碼**（`server/.env` 中的 `AUTH_TOKEN`/`JWT_SECRET`，以及 `.initial_admin_password`） |

**重要提示：** Ollama、LiteLLM 和 MCP Gateway 的 API 金鑰在首次啟動時自動產生，儲存在這些磁碟區中。如果遺失磁碟區，金鑰也會遺失。已連線的用戶端需要更新為新金鑰。

**重要提示（AnythingLLM）：** 自動產生的管理員密碼及其 `JWT_SECRET` 位於 `anythingllm-data` 磁碟區中（`server/.env` 和 `.initial_admin_password`）。備份此磁碟區會保留密碼。在其他主機上還原時會重用相同的密碼 — 無需重新產生。

**注：** `ollama-shared`、`mcp-shared` 和 `litellm-shared` 磁碟區是用於在服務之間自動傳遞 API 金鑰的臨時共享卷，無需備份——金鑰已分別儲存在 `ollama-data`、`mcp-data` 和 `litellm-data` 中，每次容器啟動時會重新複製。

## 匯出 API 金鑰

在進行任何維護操作之前，請儲存目前的 API 金鑰：

```bash
echo "=== API Keys ===" > ai-stack-keys.txt
echo "Ollama:  $(docker exec ollama ollama_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo "LiteLLM: $(docker exec litellm litellm_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo "MCP:     $(docker exec mcp mcp_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo ""
echo "Keys saved to ai-stack-keys.txt"
cat ai-stack-keys.txt
```

請安全儲存此檔案 — 它包含憑證。

## 備份所有磁碟區

先停止技術堆疊以確保資料一致性：

```bash
# 停止並移除容器（資料保留在 Docker 卷中）
docker compose down

# 建立備份目錄
mkdir -p backups

# 備份所有磁碟區
for vol in ollama-data litellm-data litellm-db embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data; do
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

### 備份單個磁碟區

```bash
# 停止並移除容器（資料保留在 Docker 卷中）
docker compose down

docker run --rm \
  -v ollama-data:/source:ro \
  -v "$(pwd)/backups:/backup" \
  alpine tar czf /backup/ollama-data.tar.gz -C /source .
```

### 輕量級技術堆疊

如果您執行的是輕量級技術堆疊（如 chat-only），則只存在相關的磁碟區。上述備份迴圈會自動略過不存在的磁碟區。

### 熱備份（無停機）PostgreSQL

如果不能停機，可以在服務運行時使用 `pg_dump` 備份 PostgreSQL 資料庫：

```bash
docker exec litellm-db pg_dump -U litellm litellm | gzip > backups/litellm-db.sql.gz
```

從 SQL 轉儲恢復：

```bash
# 僅啟動資料庫容器
docker compose up -d litellm-db
sleep 5

# 刪除並重建資料庫，然後恢復
docker exec litellm-db dropdb -U litellm litellm --if-exists
docker exec litellm-db createdb -U litellm litellm
gunzip -c backups/litellm-db.sql.gz | docker exec -i litellm-db psql -U litellm litellm

# 啟動其餘服務
docker compose up -d
```

### 哪些卷需要停機？

| 卷 | 可以熱備份？ | 備註 |
|---|---|---|
| `litellm-db` | ✅ 是（使用 `pg_dump`） | PostgreSQL 支援一致性熱轉儲 |
| `embeddings-data` | ✅ 是 | 初始模型下載後為唯讀 |
| `whisper-data` | ✅ 是 | 初始模型下載後為唯讀 |
| `whisper-live-data` | ✅ 是 | 初始模型下載後為唯讀 |
| `kokoro-data` | ✅ 是 | 初始模型下載後為唯讀 |
| `docling-data` | ✅ 是 | 初始模型下載後為唯讀 |
| `ollama-data` | ⚠️ 先停止 | 模型拉取時有寫入；無拉取進行中則安全 |
| `litellm-data` | ⚠️ 先停止 | 包含啟動時可能寫入的設定 |
| `mcp-data` | ⚠️ 先停止 | 包含啟動時可能寫入的設定 |
| `anythingllm-data` | ⚠️ 先停止 | 聊天會話期間有活躍寫入 |

## 還原所有磁碟區

**警告：** 還原操作會覆寫目標磁碟區中的所有現有資料，包括 API 金鑰。使用舊金鑰的用戶端需要更新。

```bash
# 停止並移除容器（資料保留在 Docker 卷中）
docker compose down

# 從備份還原所有磁碟區
for vol in ollama-data litellm-data litellm-db embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data; do
  backup_file="backups/${vol}.tar.gz"
  if [ -f "$backup_file" ]; then
    echo "Restoring $vol..."
    # 如果磁碟區不存在則建立
    docker volume create "$vol" >/dev/null 2>&1 || true
    # 清除現有資料並還原
    docker run --rm \
      -v "${vol}:/target" \
      -v "$(pwd)/backups:/backup:ro" \
      alpine sh -c "rm -rf /target/* /target/.[!.]* 2>/dev/null; tar xzf /backup/${vol}.tar.gz -C /target"
  else
    echo "Skipping $vol (no backup file found)"
  fi
done

# 重新啟動服務
docker compose up -d

echo "Restore complete. Verify with: ./stack-check.sh"
```

### 還原單個磁碟區

**警告：** 此操作會覆寫目標磁碟區中的所有現有資料。

```bash
# 停止並移除容器（資料保留在 Docker 卷中）
docker compose down

docker volume create ollama-data >/dev/null 2>&1 || true
docker run --rm \
  -v ollama-data:/target \
  -v "$(pwd)/backups:/backup:ro" \
  alpine sh -c "rm -rf /target/* /target/.[!.]* 2>/dev/null; tar xzf /backup/ollama-data.tar.gz -C /target"

docker compose up -d
```

## 遷移到新伺服器

1. **在舊伺服器上：** 備份所有磁碟區並匯出金鑰（參見上文）
2. **傳輸檔案：** 將 `backups/` 目錄和 `ai-stack-keys.txt` 複製到新伺服器
3. **在新伺服器上：**

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack

# 將備份檔案複製到位
cp -r /path/to/backups ./backups

# 還原磁碟區（自動建立）
for vol in ollama-data litellm-data litellm-db embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data; do
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

# 啟動技術堆疊
docker compose up -d

# 驗證
./stack-check.sh
```

您的 API 金鑰、模型和設定將被保留。用戶端可以使用相同的金鑰連線。

## 升級前檢查清單

在執行 `docker compose pull && docker compose up -d` 之前：

1. **匯出 API 金鑰** — 儲存到檔案（參見上文）
2. **備份磁碟區** — 至少備份 `ollama-data`、`litellm-data` 和 `mcp-data`
3. **拉取新映像檔** — `docker compose pull`
4. **啟動更新後的技術堆疊** — `docker compose up -d`
5. **執行健康檢查** — `./stack-check.sh`
6. **驗證 API 金鑰** — 確認金鑰未變（升級後應保持不變）

如果升級後出現問題：

```bash
# 停止並移除容器（資料保留在 Docker 卷中）
docker compose down

# 從備份還原
#（按照上述還原步驟操作）

# 如有需要，將映像檔固定到之前的可用版本
# 編輯 docker-compose.yml 使用特定的映像檔標籤
docker compose up -d
```

## 注意事項

- **模型權重**（在 `ollama-data` 中）可能很大（每個模型數 GB）。僅在重新下載不便時才需備份（網速慢、自訂微調模型）。
- **模型快取**（`embeddings-data`、`whisper-data`、`whisper-live-data`、`kokoro-data`、`docling-data`）在首次啟動時自動下載。如果頻寬不是問題，可以略過備份 — 它們會被重新下載。
- **關鍵磁碟區**，應始終備份：`ollama-data`（如有自訂模型）、`litellm-data`、`litellm-db`、`mcp-data`（包含 API 金鑰和設定）以及 `anythingllm-data`（聊天記錄和工作區）。
- 備份檔案是標準的 `.tar.gz` 壓縮檔。可以使用以下命令檢視內容：`tar tzf backups/ollama-data.tar.gz`

### 各堆疊使用的卷

| 堆疊 | 使用的卷 |
|---|---|
| chat-only | `ollama-data`, `litellm-data`, `litellm-db`, `ollama-shared` |
| chat-ui | `ollama-data`, `litellm-data`, `litellm-db`, `anythingllm-data`, `ollama-shared`, `litellm-shared` |
| voice-pipeline | `ollama-data`, `litellm-data`, `litellm-db`, `whisper-data`, `kokoro-data`, `ollama-shared` |
| voice-chat | `ollama-data`, `litellm-data`, `litellm-db`, `anythingllm-data`, `whisper-data`, `kokoro-data`, `ollama-shared`, `litellm-shared` |
| rag-pipeline | `ollama-data`, `litellm-data`, `litellm-db`, `embeddings-data`, `ollama-shared` |
| rag-pipeline-full | `ollama-data`, `litellm-data`, `litellm-db`, `embeddings-data`, `docling-data`, `ollama-shared` |
| code-assistant | `ollama-data`, `litellm-data`, `litellm-db`, `embeddings-data`, `mcp-data`, `ollama-shared`, `mcp-shared` |
| ai-tools | `ollama-data`, `litellm-data`, `litellm-db`, `mcp-data`, `ollama-shared`, `mcp-shared` |
