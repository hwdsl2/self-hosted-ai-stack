[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Docker AI Stack

[![Docker Compose AI Stack](docs/images/ai-stack.svg)](https://docs.docker.com/compose/) &nbsp;[![Docker Pulls](https://raw.githubusercontent.com/hwdsl2/badges/main/img/docker-pulls-ai-stack.svg)](https://hub.docker.com/u/hwdsl2) &nbsp;[![授權協議: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

<p align="center">
  <img src="docs/images/docker-ai-stack-overview.png"
       alt="Docker AI Stack：一鍵部署完整的自託管 AI 技術堆疊"
       width="100%">
</p>

包含 Ollama、LiteLLM、AnythingLLM、Whisper、MCP Gateway、Embeddings、Docling 和 Kokoro — 使用 Docker Compose 完整配置，開箱即用。

- 零配置：所有服務在首次啟動時自動配置
- 安全：Ollama、LiteLLM 和 MCP Gateway 自動產生 API 金鑰
- 隱私：預設在本機執行，可透過 LiteLLM 選擇性接入外部提供商
- 可選驗證：Whisper、WhisperLive、Kokoro、Embeddings 和 Docling 預設無需 API 金鑰（對外網路部署時可透過 env 檔案設定金鑰）
- 提供[輕量級技術堆疊](#輕量級技術堆疊)，降低記憶體需求（最低約 4.5 GB）
- 支援 NVIDIA CUDA GPU 加速
- 多架構：`linux/amd64`、`linux/arm64`

## 社群

- 📬 [訂閱專案更新](https://selfhostedstack.beehiiv.com/subscribe?utm_campaign=ai-zh-hant)（每月 1–2 封郵件）——獲取免費的 AI 和 VPN 部署指南（PDF，英文）
- 💬 加入 [r/selfhostedstack](https://www.reddit.com/r/selfhostedstack/) 社群，參與討論與專案展示
- ⭐ 如果你覺得本專案有用，請為儲存庫加星——這能幫助更多人發現它。

Docker AI Stack 由 [Setup IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn)（27k+ 星標）的作者維護。

## 包含的服務

| 服務 | 用途 | 預設連接埠 |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh-Hant.md)** | 執行本機大型語言模型（llama3、qwen、mistral 等） | `11434` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | 基於 Web 的聊天介面 — 無需登入即可立即使用 | `3001` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md)** | AI 閘道（含管理介面）— 將請求路由至 Ollama 及 100+ 提供商 | `4000` |
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh-Hant.md)** | 將文字轉換為向量，用於語意搜尋和 RAG | `8000` |
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh-Hant.md)** | 將語音轉錄為文字 | `9000` |
| **[WhisperLive（即時語音轉文字）](https://github.com/hwdsl2/docker-whisper-live/blob/main/README-zh-Hant.md)** | 透過 WebSocket 即時語音轉文字 | `9090` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh-Hant.md)** | 將文字轉換為自然語音 | `8880` |
| **[MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/README-zh-Hant.md)** | 為 AI 用戶端提供 MCP 工具（檔案系統、網頁擷取、GitHub、搜尋、資料庫） | `3000` |
| **[Docling](https://github.com/hwdsl2/docker-docling/blob/main/README-zh-Hant.md)** | 將文件（PDF、DOCX 等）轉換為結構化文字/Markdown | `5001` |

## 快速開始

**系統需求：**

- 一台安裝了 Docker 的 Linux 伺服器（本機或雲端）
- 至少 8 GB 記憶體（使用小型模型）。對於較大的 LLM 模型（8B+），建議 16 GB 或以上。
- 您可以註解掉不需要的服務以減少記憶體使用。

**啟動完整技術堆疊：**

```bash
# 複製儲存庫以取得編排檔案
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack
docker compose up -d
```

**拉取模型**（發出 LLM 請求前必須執行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

執行健康檢查以驗證所有服務正常運作：

```bash
./stack-check.sh
```

> **提示：** 首次啟動時，服務可能需要幾分鐘完成初始化。如有檢查失敗，請稍等後再次執行 `./stack-check.sh`。使用 `docker compose logs` 檢視進度。

**取得 LiteLLM 主密鑰**（用於登入管理介面和 LLM 請求）：

```bash
docker exec litellm litellm_manage --showkey
```

<details>
<summary>顯示所有 API 金鑰（Ollama、LiteLLM、MCP Gateway）</summary>

```bash
docker exec ollama ollama_manage --showkey
docker exec litellm litellm_manage --showkey
docker exec mcp mcp_manage --showkey
```

</details>

**存取 AnythingLLM（聊天介面）：**

在瀏覽器中開啟 `http://<server-ip>:3001`。AnythingLLM 已預設透過 LiteLLM 連接本機大型語言模型 — 無需登入或設定，即可立即開始對話。首次啟動時，可能需要幾分鐘才能就緒（使用 `docker logs anythingllm` 檢視進度）。

> **提示：** 請[設定密碼](https://docs.useanything.com/features/security-and-access)保護 AnythingLLM，尤其是在伺服器可從公網存取時。

**存取 LiteLLM 管理介面：**

在瀏覽器中開啟 `http://<server-ip>:4000/ui`。使用使用者名稱 `admin` 和您的 LiteLLM 主密鑰作為密碼登入。管理介面提供虛擬金鑰管理、支出追蹤和模型設定功能。

> **提示：** 在管理介面中，點選左側選單的 **Playground**。從下拉清單中選擇本機模型（例如 `ollama/llama3.2:3b`）並開始對話 — 這是驗證本機大型語言模型端到端正常運作的一種快速方式。

> **注：** 對於面向網際網路的部署，強烈建議使用[反向代理](#面向網際網路的部署)新增 HTTPS。將 `docker-compose.yml` 中的 `"3001:3001/tcp"` 和 `"4000:4000/tcp"` 分別改為 `"127.0.0.1:3001:3001/tcp"` 和 `"127.0.0.1:4000:4000/tcp"`，以防止直接存取未加密連接埠。

**停止技術堆疊：**

```bash
# 停止並移除所有容器（資料保留在 Docker 卷中）
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

**需求：** NVIDIA GPU、[NVIDIA 驅動程式](https://www.nvidia.com/en-us/drivers/) 535+，以及在主機上安裝 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)。CUDA 映像檔僅支援 `linux/amd64`。

> **Podman 使用者：** Podman 會忽略 Compose 的 `deploy:` GPU 設定區塊。請改用 CDI — 參見[使用 Podman](#使用-podman)。

## 輕量級技術堆疊

不需要完整技術堆疊？使用 `stacks/` 資料夾中的預配置子集：

| 技術堆疊 | 服務 | 記憶體 | 使用場景 |
|---|---|---|---|
| **[chat-ui](stacks/chat-ui/README-zh-Hant.md)** | Ollama + LiteLLM + AnythingLLM | ~5 GB | 基於 Web 的 ChatGPT 式聊天介面 |
| **[voice-pipeline](stacks/voice-pipeline/README-zh-Hant.md)** | Whisper + Ollama + LiteLLM + Kokoro | ~6 GB | 語音轉文字 → LLM → 文字轉語音 |
| **[voice-chat](stacks/voice-chat/README-zh-Hant.md)** | Whisper + Ollama + LiteLLM + Kokoro + AnythingLLM | ~6.5 GB | 帶語音輸入/輸出的聊天介面 |
| **[rag-pipeline](stacks/rag-pipeline/README-zh-Hant.md)** | Ollama + LiteLLM + Embeddings | ~5 GB | 語意搜尋 + LLM 問答 |
| **[rag-pipeline-full](stacks/rag-pipeline-full/README-zh-Hant.md)** | Ollama + LiteLLM + Embeddings + Docling | ~6 GB | 文件解析 + 語意搜尋 + LLM 問答 |
| **[code-assistant](stacks/code-assistant/README-zh-Hant.md)** | Ollama + LiteLLM + MCP Gateway + Embeddings | ~5 GB | AI 程式設計，支援工具 + 語意程式碼搜尋 |
| **[ai-tools](stacks/ai-tools/README-zh-Hant.md)** | Ollama + LiteLLM + MCP Gateway | ~5 GB | AI 程式設計助手，支援工具存取 |
| **[chat-only](stacks/chat-only/README-zh-Hant.md)** | Ollama + LiteLLM | ~4.5 GB | 最小化本機 ChatGPT 替代方案 |

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/chat-ui  # 或 voice-pipeline、voice-chat、rag-pipeline、rag-pipeline-full、code-assistant、ai-tools、chat-only
docker compose up -d
```

## 架構

```mermaid
graph LR
    A["🎤 音訊輸入"] -->|轉錄| W["Whisper<br/>(語音轉文字)"]
    D["📄 文件"] -->|解析| DC["Docling<br/>(文件 → 文字)"]
    DC -->|嵌入| E["Embeddings<br/>(文字 → 向量)"]
    E -->|儲存| VDB["pgvector<br/>(共享 Postgres 中)"]
    W -->|查詢| E
    VDB -->|上下文| L["LiteLLM<br/>(AI 閘道)"]
    W -->|文字| L
    L -->|路由至| O["Ollama<br/>(本機 LLM)"]
    L -->|回應| T["Kokoro TTS<br/>(文字轉語音)"]
    T --> B["🔊 音訊輸出"]
    C["🤖 AI 用戶端<br/>(Cline, Claude 等)"] -->|MCP 工具| M["MCP Gateway<br/>(MCP 端點)"]
    C -->|對話| L
    L -->|MCP 協定| M
    U["👤 使用者"] -->|對話| AN["AnythingLLM<br/>(聊天介面)"]
    AN -->|LLM 請求| L
    AN -->|MCP 工具| M
    U -->|使用| C
    U -->|說話| A
    U -->|上傳| D
```

**注：**

- Ollama 的連接埠（`11434`）和 MCP Gateway 的連接埠（`3000`）僅在 Docker 網路內部可用，預設不暴露給主機。請透過 LiteLLM 的連接埠 `4000` 存取您的 LLM。
- 為降低記憶體使用量，Kokoro（TTS）、Docling（文件解析）和 WhisperLive（即時語音轉文字）預設為停用狀態。如需啟用，請在 `docker-compose.yml` 中取消註解這些服務。

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

# MCP Gateway
docker run -d --name mcp --restart always \
    --network ai-stack \
    -v mcp-data:/var/lib/mcp \
    -v mcp-shared:/var/lib/mcp-shared \
    hwdsl2/mcp-gateway

# LiteLLM (AI 閘道)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_MCP_URL=http://mcp:3000/mcp \
    -e LITELLM_DATABASE_URL=postgresql://litellm:litellm@litellm-db:5432/litellm \
    -v litellm-data:/etc/litellm \
    -v ollama-shared:/var/lib/ollama-shared:ro \
    -v mcp-shared:/var/lib/mcp-shared:ro \
    -v litellm-shared:/var/lib/litellm-shared \
    hwdsl2/litellm-server

# Embeddings
docker run -d --name embeddings --restart always \
    --network ai-stack \
    -p 127.0.0.1:8000:8000 \
    -v embeddings-data:/var/lib/embeddings \
    hwdsl2/embeddings-server

# Whisper (STT)
docker run -d --name whisper --restart always \
    --network ai-stack \
    -p 127.0.0.1:9000:9000 \
    -v whisper-data:/var/lib/whisper \
    hwdsl2/whisper-server

# WhisperLive (real-time STT)
docker run -d --name whisper-live --restart always \
    --network ai-stack \
    -p 127.0.0.1:9090:9090 \
    -v whisper-live-data:/var/lib/whisper-live \
    hwdsl2/whisper-live-server

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

# Kokoro (TTS)
docker run -d --name kokoro --restart always \
    --network ai-stack \
    -p 127.0.0.1:8880:8880 \
    -v kokoro-data:/var/lib/kokoro \
    hwdsl2/kokoro-server

# Docling (文件解析)
docker run -d --name docling --restart always \
    --network ai-stack \
    -p 127.0.0.1:5001:5001 \
    -v docling-data:/var/lib/docling \
    hwdsl2/docling-server
```

**注：** 共享網路允許服務透過容器名稱互相存取（例如 LiteLLM 透過 `http://ollama:11434` 連接 Ollama）。您可以只啟動需要的服務 — 不必全部執行。

**拉取模型**（發出 LLM 請求前必須執行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## 使用 Podman

本技術堆疊在盡力支援的基礎上可於 [Podman](https://podman.io/) 上執行。CPU 編排檔案無需修改即可使用；GPU 加速與啟用了 SELinux 的主機需要下文所述的幾個額外步驟。建議使用 Podman **4.1+**。

**1. 安裝 Docker CLI 相容層。** 為使本 README 中的 `docker` 指令以及 `stack-check.sh` 健康檢查指令碼無需改動即可執行，請安裝 `podman-docker` 套件（提供 `docker` → `podman` 封裝）：

```bash
# Fedora / RHEL / CentOS Stream
sudo dnf install -y podman-docker

# Debian / Ubuntu
sudo apt-get install -y podman-docker
```

> **注：** shell 別名 `alias docker=podman` **不**足夠 — 指令碼（如 `stack-check.sh`）無法辨識別名。請改用 `podman-docker` 套件（或在 `PATH` 中建立 `docker` → `podman` 符號連結）。此外，`stack-check.sh` 會自動偵測 Podman；您也可以透過 `CONTAINER_ENGINE=podman ./stack-check.sh` 強制指定。

**2. 安裝 Compose 提供程式。** `podman compose` 會委派給外部提供程式。請安裝 `podman-compose` 或 `docker-compose` 其中之一：

```bash
# Fedora / RHEL / CentOS Stream
sudo dnf install -y podman-compose

# Debian / Ubuntu
sudo apt-get install -y podman-compose
```

**3. 啟動技術堆疊。** 安裝相容層後，本 README 中的每條指令均可原樣執行。若未安裝，請將 `docker` 替換為 `podman`：

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack
podman compose up -d
```

執行健康檢查（自動偵測引擎）：

```bash
./stack-check.sh
```

**GPU 加速 (CDI)。** Podman 不會讀取 Compose 的 `deploy.resources` GPU 設定區塊。請改用[容器裝置介面 (CDI)](https://github.com/cncf-tags/container-device-interface)。在安裝 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) 後，產生 CDI 規範：

```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

然後將 GPU 暴露給相關服務。對於 `podman compose`，請將 `docker-compose.cuda.yml` 中 `ollama`（及 `whisper`）服務的 `deploy:` 設定區塊替換為 `devices:` 條目：

```yaml
    devices:
      - nvidia.com/gpu=all
```

對於一般的 `podman run` 指令，請加上 `--device nvidia.com/gpu=all`。

**SELinux。** 在啟用了 SELinux 的主機上（Fedora、RHEL、CentOS Stream），繫結掛載的檔案需要重新標記後綴，否則容器將被拒絕存取。請為 `chat-ui-bootstrap.sh` 繫結掛載加上 `:z`（共享）後綴：

- 在 `docker-compose.yml` 中：將 `./chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro` 改為 `./chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro,z`
- 在上文的 `podman run` 指令中：將 `"$(pwd)/chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro"` 改為 `"$(pwd)/chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro,z"`

具名磁碟區無需重新標記。

**後續步驟：** 拉取模型並存取服務 — 請按照[快速開始](#快速開始)中「拉取模型」之後的說明操作。安裝 `podman-docker` 相容層後，所有指令無需修改即可使用。

## 將 MCP Gateway 連接到 LiteLLM

在本倉庫的 compose 檔案中，LiteLLM 和 MCP Gateway 已**自動接入**——無需手動設定金鑰。

API 金鑰透過 Docker 共享卷在服務之間自動共享：

- Ollama 在首次啟動時生成 API 金鑰，並將其複製到共享卷
- MCP Gateway 執行相同操作
- LiteLLM 在啟動時自動從共享卷讀取這兩個金鑰

compose 檔案中已預設 `LITELLM_MCP_URL=http://mcp:3000/mcp` 和 `LITELLM_OLLAMA_BASE_URL=http://ollama:11434`，因此只需一條 `docker compose up -d` 命令即可自動連接所有服務。

連線成功後，呼叫 LiteLLM 的 AI 用戶端即可透過 LiteLLM 代理直接使用 MCP 工具（檔案系統、網頁擷取、GitHub 等）。

## 語音管道範例

轉錄語音問題，透過 Ollama 取得本機 LLM 回應，然後轉換為語音：

**注：** Kokoro（TTS）預設已停用。如需使用此範例，請先取消 `docker-compose.yml` 中 `kokoro` 服務的註解，然後執行 `docker compose up -d`。

**提示：** 需要範例音訊檔案？可以從 [Azure Samples](https://github.com/Azure-Samples/cognitive-services-speech-sdk) 儲存庫下載這個英語語音範例（WAV 格式，MIT 授權）：

```bash
curl -L -o sample_speech.wav \
    "https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/katiesteve.wav"
```

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# 第 1 步：將音訊轉錄為文字（Whisper）
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@sample_speech.wav -F model=whisper-1 | jq -r .text)

# 第 2 步：透過 LiteLLM 將文字傳送至 Ollama 並取得回應
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"ollama/llama3.2:3b\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# 第 3 步：將回應轉換為語音（Kokoro TTS）
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3
```

## 向量資料庫

本棧的 PostgreSQL 已內建 [pgvector](https://github.com/pgvector/pgvector) 擴充功能，因此您可以在 LiteLLM 使用的同一個資料庫中儲存與查詢嵌入向量 — 無需單獨的向量資料庫。

啟用擴充功能（只需執行一次，資料庫會持久保存）：

```bash
docker exec litellm-db psql -U litellm -d litellm -c 'CREATE EXTENSION IF NOT EXISTS vector;'
```

驗證是否已啟用：

```bash
docker exec litellm-db psql -U litellm -d litellm -c "SELECT extname, extversion FROM pg_extension WHERE extname='vector';"
```

隨後即可建立帶有 `vector` 欄位的資料表（維度需與嵌入模型一致 — 例如預設 `BAAI/bge-small-en-v1.5` 為 `384`），並使用 `<=>` 運算子進行相似度搜尋。如需更大規模或混合檢索，也可改用 Qdrant、Chroma 等專用向量資料庫。

## RAG 管道範例

嵌入文件用於語意搜尋，擷取上下文，然後使用本機 Ollama 模型回答問題：

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# 第 1 步：嵌入文件片段並將向量儲存到向量資料庫
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → 將傳回的向量與來源文字一起儲存到 pgvector（已包含在本棧的 Postgres 中），或 Qdrant、Chroma 等其他向量資料庫。

# 第 2 步：查詢時，嵌入問題，從向量資料庫中擷取最符合的片段，
#          然後透過 LiteLLM 將問題和擷取到的上下文傳送至 Ollama。
curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "ollama/llama3.2:3b",
      "messages": [
        {"role": "system", "content": "Answer using only the provided context."},
        {"role": "user", "content": "What does Docker do?\n\nContext: Docker simplifies deployment by packaging apps in containers."}
      ]
    }' \
    | jq -r '.choices[0].message.content'
```

## MCP 工具範例

使用 MCP Gateway 為您的 AI 助手提供檔案、網路和 GitHub 存取：

```bash
MCP_KEY=$(docker exec mcp mcp_manage --showkey | grep '^mcp-' | head -1)

# 在 AI 用戶端中使用 MCP 端點（例如 VS Code 中的 Cline）
# 設定 MCP 伺服器 URL：http://localhost:3000/mcp
# 設定 Authorization 標頭：Bearer <api_key>

# 或直接測試 MCP 端點
curl -s http://localhost:3000/mcp \
    -X POST \
    -H "Authorization: Bearer $MCP_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

## 自訂設定

每個服務可以透過可選的 env 檔案進行設定。從相應儲存庫複製範例 env 檔案，編輯後取消 `docker-compose.yml` 中的磁碟區掛載註解：

| 服務 | Env 檔案 | 儲存庫 |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh-Hant.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md) |
| Embeddings | `embed.env` | [docker-embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-zh-Hant.md) |
| Whisper | `whisper.env` | [docker-whisper](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh-Hant.md) |
| WhisperLive | `whisper-live.env` | [docker-whisper-live](https://github.com/hwdsl2/docker-whisper-live/blob/main/README-zh-Hant.md) |
| Kokoro | `kokoro.env` | [docker-kokoro](https://github.com/hwdsl2/docker-kokoro/blob/main/README-zh-Hant.md) |
| MCP Gateway | `mcp.env` | [docker-mcp-gateway](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/README-zh-Hant.md) |
| Docling | `docling.env` | [docker-docling](https://github.com/hwdsl2/docker-docling/blob/main/README-zh-Hant.md) |

AnythingLLM 透過其 Web 介面 `http://<伺服器IP>:3001` 進行設定。您可以在 **Settings** 中變更 LLM 供應商、模型、嵌入引擎和其他設定。詳情請參閱 [AnythingLLM 文件](https://docs.useanything.com/)。

有關詳細設定選項、API 參考和模型管理，請參閱各服務儲存庫的文件。

## 面向網際網路的部署

預設情況下，所有服務透過純 HTTP 監聽。對於面向網際網路的部署，請在技術堆疊前面放置反向代理（例如 [Caddy](https://caddyserver.com/)、Nginx 或 Traefik）以提供 HTTPS。每個服務儲存庫都包含詳細的[反向代理指南](https://github.com/hwdsl2/docker-whisper/blob/main/README-zh-Hant.md#使用反向代理)，含 Caddy 和 nginx 範例。[chat-ui](stacks/chat-ui/README-zh-Hant.md) 技術堆疊還包含針對 AnythingLLM 的反向代理章節。

將服務暴露到網際網路時，請透過相應的 env 檔案為預設無需驗證的服務（Whisper、WhisperLive、Kokoro、Embeddings、Docling）設定 API 金鑰。

## 備份與還原

您的 API 金鑰、模型和設定儲存在 Docker 磁碟區中。升級或變更前請先備份：

```bash
# 匯出 API 金鑰（在容器執行時）
docker exec ollama ollama_manage --showkey
docker exec litellm litellm_manage --showkey
docker exec mcp mcp_manage --showkey

# 備份所有磁碟區（先停止服務）
# 停止並移除所有容器（資料保留在 Docker 卷中）
docker compose down
mkdir -p backups
for vol in ollama-data litellm-data litellm-db embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data; do
  docker volume inspect "$vol" >/dev/null 2>&1 && \
    docker run --rm -v "${vol}:/source:ro" -v "$(pwd)/backups:/backup" \
      alpine tar czf "/backup/${vol}.tar.gz" -C /source .
done
```

**注：** `ollama-shared`、`mcp-shared` 和 `litellm-shared` 磁碟區是臨時金鑰共享卷，無需備份。

有關還原說明、伺服器遷移和完整的升級前檢查清單，請參閱[備份與還原](docs/backup-restore-zh-Hant.md)指南。

## 更新映像檔

將所有服務更新到最新版本：

```bash
docker compose pull
docker compose up -d
./stack-check.sh
```

您的資料保存在 Docker 磁碟區中。**升級前請務必[備份](#備份與還原)。**

## 授權協議

Copyright (C) 2026 Lin Song   
本專案以 [MIT 授權條款](https://opensource.org/licenses/MIT) 授權。

本專案是獨立的 Docker 設定，與 Ollama、Berri AI（LiteLLM）、Hugging Face、hexgrad（Kokoro）、OpenAI、SYSTRAN 或 MCPHub 無關聯，未獲其背書或贊助。
