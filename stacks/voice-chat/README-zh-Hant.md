[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 語音聊天

基於網頁的聊天介面，搭配語音輸入（語音轉文字）和語音輸出（文字轉語音）— 完整的本機 AI 個人助手。

**服務：** Ollama (LLM) + LiteLLM (閘道) + [AnythingLLM](https://github.com/mintplex-labs/anything-llm) (聊天介面) + Whisper (STT) + Kokoro (TTS)

**記憶體：** ~6.5 GB RAM（使用 3B 模型）

**平台：** `linux/amd64`、`linux/arm64`

## 架構

```mermaid
graph LR
    U["👤 使用者"] -->|聊天| A["AnythingLLM<br/>(聊天介面)"]
    U -->|說話| W["Whisper<br/>(語音轉文字)"]
    A -->|API| L["LiteLLM<br/>(AI 閘道)"]
    L -->|路由至| O["Ollama<br/>(本機 LLM)"]
    L -->|回應| K["Kokoro<br/>(文字轉語音)"]
    K --> S["🔊 音訊輸出"]
    W -->|文字| L
```

## 服務

| 服務 | 用途 | 預設連接埠 |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh-Hant.md)** | 執行本機 LLM 模型（llama3、qwen、mistral 等） | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md)** | 帶管理介面的 AI 閘道 — 將請求路由至 Ollama 及 100+ 供應商 | `4000` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | 基於網頁的聊天介面，支援工作區、RAG 和代理 | `3001` |
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh-Hant.md)** | 將語音音訊轉錄為文字 | `9000` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh-Hant.md)** | 將文字轉換為自然語音 | `8880` |

## 快速開始

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/voice-chat
docker compose up -d
```

**拉取模型**（發出 LLM 請求前必須執行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

**開啟聊天介面：**

AnythingLLM 已預設連接到 LiteLLM。API 金鑰透過 Docker 磁碟區自動共享 — 無需手動設定。

在瀏覽器中開啟 `http://<server-ip>:3001` — 可以立即開始聊天。LLM 供應商、基礎 URL 和模型均已預設。

首次啟動時，AnythingLLM 可能需要幾分鐘才能就緒（使用 `docker logs anythingllm` 檢視進度）。

> **提示：** 請[設定密碼](https://docs.useanything.com/features/security-and-access)保護 AnythingLLM，尤其是在伺服器可從公網存取時。

> **注：** 對於面向網際網路的部署，強烈建議使用[反向代理](#使用反向代理)新增 HTTPS。將 `docker-compose.yml` 中的 `"3001:3001/tcp"` 和 `"4000:4000/tcp"` 分別改為 `"127.0.0.1:3001:3001/tcp"` 和 `"127.0.0.1:4000:4000/tcp"`，以防止直接存取未加密連接埠。

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

**需求：** NVIDIA GPU、[NVIDIA 驅動程式](https://www.nvidia.com/en-us/drivers/) 535+，以及在主機上安裝 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)。CUDA 映像檔僅支援 `linux/amd64`。

## 不使用 Docker Compose 執行

如需直接使用 `docker run` 指令，請先建立共享網路以便服務之間通訊：

```bash
docker network create ai-stack
```

然後在共享網路上啟動各服務：

```bash
# PostgreSQL with pgvector (required by LiteLLM; pgvector enables vector storage for RAG)
docker run -d --name litellm-db --restart always \
    --network ai-stack \
    -e POSTGRES_USER=litellm \
    -e POSTGRES_PASSWORD=litellm \
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
    -e LITELLM_DATABASE_URL=postgresql://litellm:litellm@litellm-db:5432/litellm \
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
    mintplexlabs/anythingllm \
    /usr/local/bin/chat-ui-bootstrap.sh

# Whisper (STT)
docker run -d --name whisper --restart always \
    --network ai-stack \
    -p 127.0.0.1:9000:9000 \
    -v whisper-data:/var/lib/whisper \
    hwdsl2/whisper-server

# Kokoro (TTS)
docker run -d --name kokoro --restart always \
    --network ai-stack \
    -p 127.0.0.1:8880:8880 \
    -v kokoro-data:/var/lib/kokoro \
    hwdsl2/kokoro-server
```

**注：** 共享網路允許服務透過容器名稱互相存取（例如 AnythingLLM 透過 `http://litellm:4000` 連接 LiteLLM）。

**拉取模型**（發出 LLM 請求前必須執行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## 驗證部署

啟動後，可以驗證所有服務是否正常運作：

```bash
# 在 docker-ai-stack 根目錄中執行
../../stack-check.sh
```

**存取 LiteLLM 管理介面：**

在瀏覽器中開啟 `http://<server-ip>:4000/ui`。使用使用者名稱 `admin` 和您的 LiteLLM 主密鑰作為密碼登入。管理介面提供虛擬金鑰管理、支出追蹤和模型設定功能。

> **提示：** 在管理介面中，點選左側選單的 **Playground**。從下拉清單中選擇本機模型（例如 `ollama/llama3.2:3b`）並開始對話 — 這是驗證本機大型語言模型端到端正常運作的一種快速方式。

## 自訂設定

每個服務可以透過可選的 env 檔案進行設定。從相應儲存庫複製範例 env 檔案，編輯後取消 `docker-compose.yml` 中的磁碟區掛載註解：

| 服務 | Env 檔案 | 儲存庫 |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh-Hant.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md) |
| Whisper | `whisper.env` | [docker-whisper](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh-Hant.md) |
| Kokoro | `kokoro.env` | [docker-kokoro](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh-Hant.md) |

AnythingLLM 透過其網頁介面 `http://<server-ip>:3001` 進行設定。您可以在 **Settings** 中更改 LLM 供應商、模型、嵌入引擎和其他設定。詳情請參閱 [AnythingLLM 文件](https://docs.useanything.com/)。

有關詳細設定選項、API 參考和模型管理，請參閱各服務儲存庫的文件。

## 使用反向代理

對於面向網際網路的部署，請在 AnythingLLM 前面放置反向代理以處理 HTTPS 終止。伺服器在本機或可信網路上無需 HTTPS 即可運作，但當聊天介面暴露在網際網路上時建議使用 HTTPS。

從反向代理存取 AnythingLLM 容器，可以使用以下位址之一：

- **`anythingllm:3001`** — 如果反向代理作為容器執行在與 AnythingLLM **相同的 Docker 網路**中（例如在同一個 `docker-compose.yml` 中定義）。
- **`127.0.0.1:3001`** — 如果反向代理執行在**主機**上且連接埠 `3001` 已發布（預設 `docker-compose.yml` 已發布）。

**[Caddy](https://caddyserver.com/docs/) 範例（[Docker 映像檔](https://hub.docker.com/_/caddy)）**（透過 Let's Encrypt 自動 TLS，反向代理在同一 Docker 網路中）：

`Caddyfile`：
```
chat.example.com {
  reverse_proxy anythingllm:3001
}
```

**nginx 範例**（反向代理在主機上）：

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

**重要：** AnythingLLM 包含自己的使用者認證系統 — 在將服務暴露到網際網路時請在首次設定時設定強密碼。

## 備份和恢復

有關備份/恢復說明，請參閱[備份和恢復](../../docs/backup-restore-zh-Hant.md)指南。

## 更新映像檔

將所有服務更新到最新版本：

```bash
docker compose pull
docker compose up -d
```

您的資料保存在 Docker 磁碟區中。 **升級前務必先[備份](../../docs/backup-restore-zh-Hant.md)。**

## 語音管道範例

轉錄語音問題，取得本機 LLM 回應，並轉換為語音：

**提示：** 需要範例音訊檔案？從 [Azure Samples](https://github.com/Azure-Samples/cognitive-services-speech-sdk) 儲存庫下載此英語語音範例（WAV，MIT 授權）：

```bash
curl -L -o sample_speech.wav \
    "https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/katiesteve.wav"
```

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# 步驟 1：將音訊轉錄為文字 (Whisper)
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@sample_speech.wav -F model=whisper-1 | jq -r .text)

# 步驟 2：透過 LiteLLM 將文字傳送給 Ollama 並取得回應
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"ollama/llama3.2:3b\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# 步驟 3：將回應轉換為語音 (Kokoro TTS)
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3
