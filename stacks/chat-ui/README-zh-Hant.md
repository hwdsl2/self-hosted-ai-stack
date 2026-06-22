[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 聊天介面

本機 ChatGPT 般的體驗 — 基於本機 LLM 和 OpenAI 相容 API 閘道的 Web 聊天介面。

**服務：** Ollama (LLM) + LiteLLM (閘道) + [AnythingLLM](https://github.com/mintplex-labs/anything-llm) (聊天介面)

**記憶體：** ~5 GB RAM（使用 3B 模型）

**平台：** `linux/amd64`、`linux/arm64`

## 架構

```mermaid
graph LR
    U["🌐 瀏覽器"] -->|聊天| A["AnythingLLM<br/>(聊天介面)"]
    A -->|API| L["LiteLLM<br/>(AI 閘道)"]
    L -->|路由至| O["Ollama<br/>(本機 LLM)"]
```

## 服務

| 服務 | 用途 | 預設埠 |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh-Hant.md)** | 執行本機 LLM 模型（llama3、qwen、mistral 等） | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md)** | 帶管理介面的 AI 閘道 — 將請求路由至 Ollama 及 100+ 供應商 | `4000` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | 基於 Web 的聊天介面，支援工作區、RAG 和智慧代理 | `3001` |

## 快速開始

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack/stacks/chat-ui
docker compose up -d
```

**拉取模型**（發出 LLM 請求前必須執行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

**開啟聊天介面：**

AnythingLLM 已預先設定連線到 LiteLLM。API 金鑰透過 Docker 卷自動共享 — 無需手動設定。LLM 供應商、基礎 URL 和模型已預先設定。

首次啟動時，AnythingLLM 可能需要幾分鐘才能就緒（使用 `docker logs anythingllm` 檢視進度）。

**預設啟用密碼保護。** 首次啟動時會自動產生隨機管理員密碼，僅列印一次到 `docker logs anythingllm`，並儲存到 `anythingllm-data` 資料卷中的 `/app/server/storage/.initial_admin_password` 檔案。種子密碼會在容器升級後持久保留。可隨時在 **Settings → Security** 中變更；變更後，`.initial_admin_password` 可能不再與目前登入密碼一致。

取得自動產生的密碼：

```bash
# 隨時從資料卷中取得：
docker exec anythingllm cat /app/server/storage/.initial_admin_password

# 或從即時日誌中取得（僅在首次啟動時顯示）：
docker compose logs anythingllm | grep -A4 "FIRST RUN"
```

在瀏覽器中開啟 `http://<伺服器IP>:3001`，並使用上面的密碼登入。

> **提示：** 當 AnythingLLM 暴露到 `localhost` 或受信任 LAN 之外時，請使用內建的 Caddy HTTPS 疊加檔案，以加密傳輸中的密碼並將直接 HTTP 連接埠繫結到 localhost。請參閱下方 [使用反向代理](#使用反向代理)。

## GPU 加速 (NVIDIA CUDA)

如需 NVIDIA GPU 加速，請使用 CUDA 編排檔案：

```bash
docker compose -f docker-compose.cuda.yml up -d
```

> **提示：** 為避免在後續每個 `docker compose` 指令（`down`、`pull`、`logs` 等）中都加上 `-f docker-compose.cuda.yml`，可在目前的 shell 工作階段中設定一次：
>
> ```bash
> export COMPOSE_FILE=docker-compose.cuda.yml
> ```
>
> 之後照常執行一般的 `docker compose` 指令。若要持久化，請在本目錄的 `.env` 檔案中加入 `COMPOSE_FILE=docker-compose.cuda.yml`。執行 `unset COMPOSE_FILE` 即可切回 CPU 設定。

**要求：** NVIDIA GPU、[NVIDIA 驅動程式](https://www.nvidia.com/en-us/drivers/) 575.57.08+（Linux）或 576.57+（Windows），以及在主機上安裝 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)。CUDA 映像僅支援 `linux/amd64`。

## 不使用 Docker Compose 執行

如需直接使用 `docker run` 命令，請先建立共享網路以便服務之間通訊：

```bash
docker network create ai-stack
```

然後在共享網路上啟動各服務：

> **注意：** 手動使用 `docker run` 時，請先等待每個依賴項就緒，再啟動使用它的服務（例如先等待 PostgreSQL 和其他依賴項（如 Ollama 或 MCP），再啟動 LiteLLM；如果使用 AnythingLLM，請先等待 LiteLLM 就緒再啟動它）。以下範例會產生一個 PostgreSQL 密碼變數，並在 Postgres 和 LiteLLM 中重複使用。

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

# LiteLLM (AI 閘道)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_DATABASE_URL="postgresql://litellm:${LITELLM_POSTGRES_PASSWORD}@litellm-db:5432/litellm" \
    -v litellm-data:/etc/litellm \
    -v ollama-shared:/var/lib/ollama-shared:ro \
    -v litellm-shared:/var/lib/litellm-shared \
    hwdsl2/litellm-server

# AnythingLLM (聊天介面)
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
```

**注：** 共享網路允許服務透過容器名稱互相存取（例如 AnythingLLM 透過 `http://litellm:4000` 連線 LiteLLM）。

**拉取模型**（發出 LLM 請求前必須執行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## 驗證部署

啟動後，可以驗證所有服務是否正常執行：

```bash
# 在 self-hosted-ai-stack 根目錄中執行
../../stack-check.sh
```

**存取 LiteLLM 管理介面：**

在瀏覽器中開啟 `http://<server-ip>:4000/ui`。使用使用者名稱 `admin` 和您的 LiteLLM 主密鑰作為密碼登入。管理介面提供虛擬金鑰管理、支出追蹤和模型設定功能。

> **提示：** 在管理介面中，點選左側選單的 **Playground**。從下拉清單中選擇本機模型（例如 `ollama/llama3.2:3b`）並開始對話 — 這是驗證本機大型語言模型端到端正常運作的一種快速方式。

## 自訂設定

每個服務可以透過可選的 env 檔案進行設定。從相應儲存庫複製範例 env 檔案，編輯後取消 `docker-compose.yml` 中的掛載註解：

| 服務 | Env 檔案 | 儲存庫 |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh-Hant.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md) |

AnythingLLM 透過其 Web 介面 `http://<伺服器IP>:3001` 進行設定。您可以在 **Settings** 中變更 LLM 供應商、模型、嵌入引擎和其他設定。詳情請參閱 [AnythingLLM 文件](https://docs.useanything.com/)。

**提示：** 如果您同時執行其他子棧（例如 [voice-pipeline](../voice-pipeline/README-zh-Hant.md)、[rag-pipeline](../rag-pipeline/README-zh-Hant.md)），可以透過 AnythingLLM 的設定頁面將其指向這些服務 — 例如使用 `docker-whisper` 進行語音轉文字，或使用 `docker-embeddings` 進行向量嵌入。

有關詳細設定選項、API 參考和模型管理，請參閱各服務儲存庫的文件。

## 使用反向代理

如需面向公網部署，請使用內建的 Caddy 疊加檔案新增自動 HTTPS。請從 `stacks/chat-ui` 目錄執行以下命令。根目錄的 `../../docker-compose.proxy.yml` 疊加檔案會有意掛載此技術棧本地的 `caddy/Caddyfile`。在代理模式下，Caddy 是唯一監聽公網 `80` 和 `443` 連接埠的服務；AnythingLLM 和 LiteLLM 的直接連接埠會重新繫結到 `127.0.0.1`。

前提條件：

- Docker Compose `2.24.4+`（代理疊加檔案的連接埠覆寫需要此版本）
- 網域的 DNS `A`/`AAAA` 記錄指向此伺服器
- 防火牆/安全群組已開放入站 `80/tcp`、`443/tcp`，最好也開放 `443/udp`
- 主機上沒有其他服務占用 `80` 或 `443` 連接埠

**CPU 技術堆疊：**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.yml -f ../../docker-compose.proxy.yml up -d
```

**CUDA 技術堆疊：**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.cuda.yml -f ../../docker-compose.proxy.yml up -d
```

開啟 `https://chat.example.com`（替換為你的 `DOMAIN`）存取 AnythingLLM。在代理模式下，主機本機仍可存取 `http://127.0.0.1:3001` 和 `http://127.0.0.1:4000/ui`，但伺服器外部無法直接存取 `3001` 和 `4000` 連接埠。

標準 compose 檔案會在 `4000` 連接埠發布 LiteLLM。代理疊加檔案會將該直接連接埠改為僅 localhost 可存取，且內建 Caddyfile 預設只路由 AnythingLLM。取消註解可選的 LiteLLM 主機名稱設定區塊會透過 Caddy 暴露 LiteLLM，請妥善保管 LiteLLM 主密鑰。

疑難排解：

```bash
docker logs ai-stack-caddy
# 使用啟動技術堆疊時相同的 -f 檔案
docker compose -f docker-compose.yml -f ../../docker-compose.proxy.yml ps
```

如果 Caddy 回報未知的 `request_body` 指令，請拉取目前的 `caddy:2` 映像檔並重新啟動疊加檔案部署。

舊版 Docker Compose 或 Podman 使用者仍可使用主機上的反向代理：將直接 HTTP 連接埠繫結到 localhost（例如 `"127.0.0.1:3001:3001/tcp"` 和 `"127.0.0.1:4000:4000/tcp"`），再反向代理到這些 localhost 連接埠。

### 手動反向代理

從反向代理存取 AnythingLLM 容器時使用以下位址之一：

- **`anythingllm:3001`** — 如果反向代理作為容器執行在與 AnythingLLM **同一 Docker 網路**中（例如定義在同一 `docker-compose.yml` 中）。
- **`127.0.0.1:3001`** — 如果反向代理執行在**主機上**且連接埠 `3001` 已發布（預設 `docker-compose.yml` 會發布該連接埠）。

**使用 [Caddy](https://caddyserver.com/docs/)（[Docker 映像檔](https://hub.docker.com/_/caddy)）的範例**（自動 Let's Encrypt TLS，反向代理在同一 Docker 網路中）：

`Caddyfile`：
```
chat.example.com {
  reverse_proxy anythingllm:3001
}
```

**使用 nginx 的範例**（反向代理執行在主機上）：

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

**重要提示：** AnythingLLM 包含內建的使用者驗證系統——將服務暴露到網際網路時，請在首次設定時設定強密碼。

## 備份和恢復

有關備份/恢復說明，請參閱[備份和恢復](../../docs/backup-restore-zh-Hant.md)指南。

## 更新映像

將所有服務更新到最新版本：

```bash
git pull
docker compose pull
docker compose up -d
../../stack-check.sh
```

子堆疊重新啟動後，執行 `../../stack-check.sh` 確認服務和產生的憑證設定正常。

`git pull` 用於更新此儲存庫，包括此子堆疊使用的所有 compose 檔案或輔助腳本；`docker compose pull` 用於更新服務映像檔。

**舊安裝的一次性提示：** 如果您在 `.env` 持久化修復之前設定過 AnythingLLM 密碼，升級後第一次重建容器可能會清除該密碼，讓 AnythingLLM 處於未受保護狀態。更新後，請立即開啟 AnythingLLM 並確認密碼保護仍然啟用。如果沒有，請在 **Settings → Security** 中設定新密碼。之後重建容器會保留該密碼。

AnythingLLM 固定為穩定發布標籤，而不是 `latest`，因為上游 `latest` 映像會追蹤 master 分支。有新的 AnythingLLM 發布版本時，請先備份，更新 compose 檔案中的標籤，然後執行上述命令。

您的資料保存在 Docker 卷中。 **升級前務必先[備份](../../docs/backup-restore-zh-Hant.md)。**

## 範例

```bash
# 在瀏覽器中開啟聊天介面
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

```
