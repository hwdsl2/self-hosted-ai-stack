[English](troubleshooting.md) | [简体中文](troubleshooting-zh.md) | [繁體中文](troubleshooting-zh-Hant.md) | [Русский](troubleshooting-ru.md)

# 疑難排解

本指南協助你在變更設定或提交 issue 之前診斷 Self-Hosted AI Stack 問題。

## 快速排查

先從以下檢查開始：

請從啟動該技術堆疊的目錄執行 `docker compose` 指令。從子堆疊目錄執行健康檢查時使用 `../../stack-check.sh`；從儲存庫根目錄執行時使用 `./stack-check.sh`。

```bash
# 顯示容器狀態和已發布連接埠
docker compose ps

# 執行技術堆疊健康檢查
# 從子堆疊目錄執行：
../../stack-check.sh

# 或從儲存庫根目錄執行：
# ./stack-check.sh

# 查看某個服務的最近日誌
docker compose logs --tail=100 <service>
```

如果啟動技術堆疊時使用了多個 compose 檔案，診斷指令也應使用相同檔案：

```bash
docker compose -f docker-compose.yml -f docker-compose.proxy.yml ps
docker compose -f docker-compose.cuda.yml -f docker-compose.proxy.yml logs --tail=100 litellm
```

對於 Podman，`stack-check.sh` 會自動偵測容器引擎。也可以強制指定：

```bash
CONTAINER_ENGINE=podman ./stack-check.sh
```

## 啟動和就緒狀態

首次啟動時，服務可能需要幾分鐘完成初始化。模型下載、資料庫啟動和 AnythingLLM 初始化都會影響就緒時間。

如果 `./stack-check.sh` 在啟動後立即失敗：

1. 等待幾分鐘。
2. 再次執行 `./stack-check.sh`。
3. 查看失敗服務的日誌。

常用服務日誌指令：

```bash
docker compose logs --tail=100 ollama
docker compose logs --tail=100 litellm
docker compose logs --tail=100 mcp
docker compose logs --tail=100 anythingllm
```

LiteLLM 依賴 Ollama、MCP Gateway 和 PostgreSQL。AnythingLLM 依賴 LiteLLM。如果依賴項仍在啟動，下游服務可能暫時尚未就緒。

## Ollama 和本機模型問題

技術堆疊會自動啟動 Ollama，但在傳送 LLM 請求前必須先拉取至少一個模型：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

列出已下載模型：

```bash
docker exec ollama ollama_manage --listmodels
```

如果 LiteLLM 或 AnythingLLM 回報模型錯誤，請先確認該模型已存在於 Ollama 中，並確認 `./stack-check.sh` 顯示 LiteLLM 路由測試成功。

對於 Ollama 映像檔相關問題，請使用 `docker-ollama` 儲存庫。對於與此 Docker 映像檔無關的上游 Ollama 行為，請使用上游 Ollama issue tracker。

## LiteLLM 問題

LiteLLM 預設暴露在連接埠 `4000`。管理介面地址：

```text
http://<server-ip>:4000/ui
```

使用者名稱使用 `admin`，密碼使用 LiteLLM master key。

顯示 LiteLLM master key：

```bash
docker exec litellm litellm_manage --showkey
```

檢查 LiteLLM 健康端點：

```bash
curl http://localhost:4000/health/liveliness
```

如果本機 Ollama 模型無法透過 LiteLLM 使用：

- 確認已下載 Ollama 模型。
- 確認 compose 檔案或 env 檔案中存在 `LITELLM_OLLAMA_BASE_URL=http://ollama:11434`。
- 查看 `docker compose logs --tail=100 litellm`。
- 執行 `./stack-check.sh` 並查看 LiteLLM 路由檢查。

compose 檔案會透過 Docker 磁碟區自動將 Ollama 和 MCP API 金鑰共享給 LiteLLM。除非已有備份，否則不要刪除 `ollama-data`、`mcp-data` 或 `litellm-data`。

## MCP Gateway 問題

MCP Gateway 在 Docker 網路內部的連接埠 `3000` 上執行。主 compose 檔案預設不向主機暴露該連接埠。

顯示 MCP Gateway API 金鑰：

```bash
docker exec mcp mcp_manage --showkey
```

從容器內部檢查健康端點：

```bash
docker exec mcp curl -sf http://127.0.0.1:3000/health
```

如果外部 MCP 用戶端需要直接存取，請取消 `docker-compose.yml` 中 `3000:3000` 連接埠映射的註解，然後重新啟動服務。面向公網存取時，請放在 HTTPS 後面，並妥善保管 API 金鑰。

## AnythingLLM 問題

AnythingLLM 預設暴露在連接埠 `3001`：

```text
http://<server-ip>:3001
```

首次啟動時會產生隨機管理員密碼，並保存在 `anythingllm-data` 磁碟區中。使用以下指令取得：

```bash
docker exec anythingllm cat /app/server/storage/.initial_admin_password
```

或查看首次啟動日誌：

```bash
docker compose logs anythingllm | grep -A4 "FIRST RUN"
```

如果 AnythingLLM 無法連接本機模型：

- 確認 Docker 網路內部可存取 LiteLLM 的 `http://litellm:4000/v1`。
- 確認模型 `ollama/llama3.2:3b` 存在，或將 AnythingLLM 更新為使用已存在的模型。
- 查看 `docker compose logs --tail=100 anythingllm`。

如果你已在 Settings 中變更 AnythingLLM 密碼，`.initial_admin_password` 可能不再符合目前密碼。升級或遷移前請備份 `anythingllm-data`。

## 可選服務

在完整 compose 檔案中，Embeddings 和 Whisper 預設啟用。Kokoro、Docling 和 WhisperLive 為降低記憶體使用而預設註解掉。

啟用被註解的服務：

1. 在 `docker-compose.yml` 或 `docker-compose.cuda.yml` 中取消該服務的註解。
2. 取消檔案底部對應命名磁碟區的註解。
3. 如需自訂設定，請新增或掛載該服務的 env 檔案。
4. 執行 `docker compose up -d`。

服務文件：

| 服務 | 儲存庫 |
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

如需 NVIDIA GPU 加速，請啟動 CUDA compose 檔案：

```bash
docker compose -f docker-compose.cuda.yml up -d
```

要求：

- NVIDIA GPU
- NVIDIA 驅動程式
- NVIDIA Container Toolkit
- CUDA 映像檔需要 `linux/amd64` 主機

如果未使用 GPU 加速：

- 確認啟動的是 `docker-compose.cuda.yml`，而不是 `docker-compose.yml`。
- 查看 `docker compose logs --tail=100 ollama`，以及啟用 Whisper 時的 `docker compose logs --tail=100 whisper`。
- 確認主機可以透過 NVIDIA Container Toolkit 執行 GPU 容器。

對於 Podman，Compose 的 `deploy.resources` GPU 區塊不會生效。請按照 README 中的 Podman CDI 說明操作。

## 反向代理和公網部署

技術堆疊包含用於 HTTPS 的 Caddy 疊加檔案：

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.yml -f docker-compose.proxy.yml up -d
```

在代理模式下，Caddy 是連接埠 `80` 和 `443` 上的公網監聽服務。AnythingLLM 和 LiteLLM 的直接連接埠會重新繫結到 `127.0.0.1`。

查看 Caddy 日誌：

```bash
docker logs ai-stack-caddy
```

如果 Caddy 無法取得憑證，請檢查：

- DNS `A`/`AAAA` 記錄指向此伺服器。
- 連接埠 `80/tcp` 和 `443/tcp` 可從公網存取。
- 沒有其他服務佔用連接埠 `80` 或 `443`。
- `DOMAIN` 和 `ACME_EMAIL` 的值正確。

公網暴露可選服務時，請優先使用已產生的 API 金鑰。對於已有且未設定金鑰的部署，請先透過相應的 env 檔案設定 API 金鑰，或將服務置於代理驗證之後再對外發布。

## 磁碟區、備份和更新

API 金鑰、模型快取、聊天記錄、服務設定和 Caddy 憑證狀態儲存在 Docker 磁碟區中。升級、遷移或執行破壞性清理前請先備份。

請參閱完整備份指南：

- [備份與還原](backup-restore-zh-Hant.md)

排查問題時，除非已有目前備份，否則不要刪除磁碟區。刪除磁碟區可能會移除 API 金鑰、模型快取、AnythingLLM 資料、LiteLLM 設定、MCP Gateway 設定、可選服務金鑰和 Caddy 憑證。

更新映像檔後執行：

```bash
docker compose pull
docker compose up -d
./stack-check.sh
```

## 在哪裡提交 issue

以下問題請提交到 `self-hosted-ai-stack`：

- compose 檔案問題
- 跨服務連接問題
- 技術堆疊啟動或健康檢查問題
- 本儲存庫中的 Caddy 疊加檔案問題
- 本儲存庫文件問題

以下問題請提交到對應的單個服務儲存庫：

- 映像檔特定行為
- 服務特定 env 選項
- 服務特定 API 行為
- 服務特定模型下載或快取行為

如果問題出在上游應用本身，而不是 Docker 映像檔或技術堆疊連接方式，請提交到上游。

## issue 中應包含的資訊

請包含：

- 主機 OS 和架構
- Docker 或 Podman 版本
- 使用的 compose 檔案，例如 `docker-compose.yml` 或 `docker-compose.cuda.yml`
- CPU 或 GPU 模式
- `docker compose ps` 輸出
- `./stack-check.sh` 輸出
- 相關日誌，例如 `docker compose logs --tail=100 litellm`
- 自訂 env 檔案或 compose 變更，並移除密鑰

發布前請移除 API 金鑰、密碼、提供商金鑰、權杖、包含私密路徑的公網 URL，以及日誌中的任何敏感內容。
