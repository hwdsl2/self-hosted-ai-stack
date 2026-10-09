[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 語音管道

語音轉文字 → LLM → 文字轉語音。轉錄音訊，取得 AI 回覆，並以語音輸出。

**服務：** ScribeCrate (Whisper STT) + InferCrate (LLM) + GatewayCrate (閘道) + SpeakCrate (TTS)

**記憶體：** ~6 GB RAM（使用 3B 模型）

**平台：** `linux/amd64`、`linux/arm64`

> 📘 [The Self-Hosted AI Builder’s Guide](https://books2read.com/aiguide?store=amazon) 是此技術堆疊的實用配套指南，涵蓋部署、安全、備份與升級。

## 架構

```mermaid
graph LR
    A["🎤 音訊輸入"] -->|轉錄| W["ScribeCrate<br/>(語音轉文字)"]
    W -->|文字| L["GatewayCrate<br/>(AI 閘道)"]
    L -->|路由至| O["InferCrate<br/>(本機 LLM)"]
    L -->|回應| T["SpeakCrate TTS<br/>(文字轉語音)"]
    T --> B["🔊 音訊輸出"]
```

## 服務

| 服務 | 用途 | 預設連接埠 |
|---|---|---|
| **[ScribeCrate (Whisper STT)](https://github.com/hwdsl2/scribecrate/blob/main/README-zh-Hant.md)** | 將語音音訊轉錄為文字 | `9000` |
| **[ScribeCrate Live（即時語音轉文字）](https://github.com/hwdsl2/scribecrate-live/blob/main/README-zh-Hant.md)** | 透過 WebSocket 即時語音轉文字 | `9090` |
| **[InferCrate (Ollama LLM)](https://github.com/hwdsl2/infercrate/blob/main/README-zh-Hant.md)** | 執行本機 LLM 模型（llama3、qwen、mistral 等） | `11434` |
| **[GatewayCrate (LiteLLM)](https://github.com/hwdsl2/gatewaycrate/blob/main/README-zh-Hant.md)** | 帶管理介面的 AI 閘道 — 將請求路由至 InferCrate 及 100+ 供應商 | `4000` |
| **[SpeakCrate (TTS)](https://github.com/hwdsl2/speakcrate/blob/main/README-zh-Hant.md)** | 將文字轉換為自然語音 | `8880` |

**注：** ScribeCrate Live（即時 STT）在 `docker-compose.yml` 中預設被註解掉。取消註解即可啟用透過 WebSocket 的即時轉錄。

> [!IMPORTANT]
> 輕量級子堆疊預設共用容器名稱、連接埠和 Docker 卷名稱。使用預設 compose 檔案時，一次只執行一個子堆疊變體；切換到其他變體前，請先停止目前變體。

預設存取方式：

- GatewayCrate 發布在主機連接埠 `4000`。
- ScribeCrate 預設繫結到 `127.0.0.1:9000`。
- SpeakCrate 預設繫結到 `127.0.0.1:8880`。
- InferCrate 僅在 Docker 網路內部存取；主機或瀏覽器存取請使用 GatewayCrate。

## 快速開始

**要求：**

- 已安裝 Docker 的 Linux 伺服器（本機或雲端）
- 足夠執行此子堆疊和所選模型的記憶體（見上方記憶體估算）
- 對於較大的 LLM 模型（8B+），建議 16 GB 或更多記憶體

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack/stacks/voice-pipeline
docker compose up -d
```

**拉取模型**（發出 LLM 請求前必須執行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

執行健康檢查以驗證服務是否正常運作：

```bash
# 從此子堆疊目錄執行：
../../stack-check.sh

# 或從儲存庫根目錄執行：
# ./stack-check.sh
```

> **提示：** 首次啟動時，服務可能需要幾分鐘完成初始化。如有檢查失敗，請稍等後再次執行 `../../stack-check.sh`。使用 `docker compose logs` 檢視進度。

**取得 GatewayCrate master key**（用於登入管理介面以及直接發起 LLM API 請求）：

```bash
docker exec litellm litellm_manage --showkey
```

**存取 GatewayCrate 的 LiteLLM 管理介面：**

在瀏覽器中開啟 `http://<server-ip>:4000/ui`。使用使用者名稱 `admin` 和您的 GatewayCrate master key 作為密碼登入。管理介面提供虛擬金鑰管理、支出追蹤和模型設定功能。

> **提示：** 在管理介面中，點選左側選單的 **Playground**。從下拉清單中選擇本機模型（例如 `ollama-chat/llama3.2:3b`）並開始對話，這是驗證本機 LLM 端到端正常運作的一種快速方式。

**停止子堆疊：**

```bash
# 停止並移除容器（資料會保留在 Docker 卷中）
docker compose down
```

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

**需求：** NVIDIA GPU、[NVIDIA 驅動程式](https://www.nvidia.com/en-us/drivers/) 575.57.08+（Linux）或 576.57+（Windows），以及在主機上安裝 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)。CUDA 映像檔僅支援 `linux/amd64`。

## 不使用 Docker Compose 執行

如需直接使用 `docker run` 指令，請先建立共享網路以便服務之間通訊：

```bash
docker network create ai-stack
```

然後在共享網路上啟動各服務：

> **注意：** 手動使用 `docker run` 時，先啟動 PostgreSQL，再啟動目前技術堆疊中的模型和工具服務。等待相依服務就緒後再啟動 GatewayCrate；如果包含 AnythingLLM，最後啟動它。以下範例會產生一個 PostgreSQL 密碼變數，並在 Postgres 和 GatewayCrate 中重複使用。

```bash
LITELLM_POSTGRES_PASSWORD=$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)

# PostgreSQL with pgvector (required by GatewayCrate; pgvector enables vector storage for RAG)
docker run -d --name litellm-db --restart always \
    --network ai-stack \
    -e POSTGRES_USER=litellm \
    -e POSTGRES_PASSWORD="$LITELLM_POSTGRES_PASSWORD" \
    -e POSTGRES_DB=litellm \
    -v litellm-db:/var/lib/postgresql \
    pgvector/pgvector:pg18-trixie

# InferCrate (LLM)
docker run -d --name ollama --restart always \
    --network ai-stack \
    -v ollama-data:/var/lib/ollama \
    -v ollama-shared:/var/lib/ollama-shared \
    hwdsl2/ollama-server

# GatewayCrate (AI 閘道)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_DATABASE_URL="postgresql://litellm:${LITELLM_POSTGRES_PASSWORD}@litellm-db:5432/litellm" \
    -v litellm-data:/etc/litellm \
    -v ollama-shared:/var/lib/ollama-shared:ro \
    hwdsl2/litellm-server

# ScribeCrate (Whisper STT)
docker run -d --name whisper --restart always \
    --network ai-stack \
    -p 127.0.0.1:9000:9000 \
    -v whisper-data:/var/lib/whisper \
    hwdsl2/whisper-server

# SpeakCrate (TTS)
docker run -d --name kokoro --restart always \
    --network ai-stack \
    -p 127.0.0.1:8880:8880 \
    -v kokoro-data:/var/lib/kokoro \
    hwdsl2/kokoro-server

# 選用：ScribeCrate Live（即時語音轉文字）
docker run -d --name whisper-live --restart always \
    --network ai-stack \
    -p 127.0.0.1:9090:9090 \
    -p 127.0.0.1:8001:8000 \
    -v whisper-live-data:/var/lib/whisper-live \
    hwdsl2/whisper-live-server
```

**注：** 共享網路允許服務透過容器名稱互相存取（例如 GatewayCrate 透過 `http://ollama:11434` 連接 InferCrate）。

**拉取模型**（發出 LLM 請求前必須執行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## 使用計數

此技術堆疊參與專案的匿名、聚合的 GitHub release 資源下載計數。使用 `AI_STACK_DISABLE_USAGE_COUNTS=1 docker compose up -d` 啟動可停用；詳情見[使用計數](../../README-zh-Hant.md#使用計數)。

## 自訂設定

每個服務可以透過可選的 env 檔案進行設定。從相應儲存庫複製範例 env 檔案，編輯後取消 `docker-compose.yml` 中的磁碟區掛載註解：

| 服務 | Env 檔案 | 儲存庫 |
|---|---|---|
| InferCrate | `ollama.env` | [infercrate](https://github.com/hwdsl2/infercrate/blob/main/README-zh-Hant.md) |
| GatewayCrate | `litellm.env` | [gatewaycrate](https://github.com/hwdsl2/gatewaycrate/blob/main/README-zh-Hant.md) |
| ScribeCrate | `whisper.env` | [ScribeCrate](https://github.com/hwdsl2/scribecrate/blob/main/README-zh-Hant.md) |
| SpeakCrate | `kokoro.env` | [SpeakCrate](https://github.com/hwdsl2/speakcrate/blob/main/README-zh-Hant.md) |
| ScribeCrate Live | `whisper-live.env` | [ScribeCrate Live](https://github.com/hwdsl2/scribecrate-live/blob/main/README-zh-Hant.md) |

有關詳細設定選項、API 參考和模型管理，請參閱各服務儲存庫的文件。

## 面向網際網路的部署

預設情況下，GatewayCrate 會發布在主機連接埠 `4000`；各子堆疊的輔助 API 預設為僅 localhost 存取或僅內部存取，除非您修改其連接埠映射。對於面向網際網路的部署，請在技術堆疊前面放置反向代理（例如 [Caddy](https://caddyserver.com/)、Nginx 或 Traefik）以提供 HTTPS；代理這些連接埠時，請將 `4000` 等直接 HTTP 連接埠繫結到 `127.0.0.1`。每個服務儲存庫都包含詳細的[反向代理指南](https://github.com/hwdsl2/gatewaycrate/blob/main/README-zh-Hant.md#使用反向代理)，含 Caddy 和 nginx 範例。

## 備份和恢復

有關備份/恢復說明，請參閱[備份和恢復](../../docs/backup-restore-zh-Hant.md)指南。

## 更新映像檔

將所有服務更新到最新版本：

```bash
git pull
docker compose pull
docker compose up -d
../../stack-check.sh
```

子堆疊重新啟動後，執行 `../../stack-check.sh` 確認服務和產生的憑證設定正常。

`git pull` 用於更新此儲存庫，包括此子堆疊使用的所有 compose 檔案或輔助腳本；`docker compose pull` 用於更新服務映像檔。

您的資料保存在 Docker 磁碟區中。 **升級前務必先[備份](../../docs/backup-restore-zh-Hant.md)。**

## 範例

> **注意：** 下面的範例使用 `jq` 格式化 JSON 回應。如尚未安裝，請先安裝。

**提示：** 需要範例音訊檔案？可以從 [Azure Samples](https://github.com/Azure-Samples/cognitive-services-speech-sdk) 儲存庫下載這個英語語音範例（WAV 格式，MIT 授權）：

```bash
curl -L -o sample_speech.wav \
    "https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/katiesteve.wav"
```

```bash
gateway_master_key="$(docker exec litellm litellm_manage --getkey)"
scribe_api_key="$(docker exec whisper whisper_manage --getkey)"
speak_api_key="$(docker exec kokoro kokoro_manage --getkey)"

# 將音訊轉錄為文字
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -H "Authorization: Bearer $scribe_api_key" \
    -F file=@sample_speech.wav -F model=whisper-1 | jq -r .text)

# 取得 LLM 回應
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $gateway_master_key" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"ollama/llama3.2:3b\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# 將回應轉換為語音
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $speak_api_key" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3

```
