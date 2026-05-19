[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# 純聊天

最小化本機聊天設定 — 本機 LLM 搭配 OpenAI 相容 API 閘道。

**服務：** Ollama (LLM) + LiteLLM (閘道)

**記憶體：** ~4.5 GB RAM（使用 3B 模型）

## 架構

```mermaid
graph LR
    C["💬 AI 客戶端"] -->|聊天| L["LiteLLM<br/>(AI 閘道)"]
    L -->|路由至| O["Ollama<br/>(本機 LLM)"]
```

## 服務

| 服務 | 用途 | 預設連接埠 |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh-Hant.md)** | 執行本機 LLM 模型（llama3、qwen、mistral 等） | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md)** | 帶管理介面的 AI 閘道 — 將請求路由至 Ollama 及 100+ 供應商 | `4000` |

## 快速開始

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/chat-only
docker compose up -d
```

**拉取模型**（發出 LLM 請求前必須執行）：

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## GPU 加速 (NVIDIA CUDA)

如需 NVIDIA GPU 加速，請使用 CUDA 編排檔案：

```bash
docker compose -f docker-compose.cuda.yml up -d
```

**需求：** NVIDIA GPU、[NVIDIA 驅動程式](https://www.nvidia.com/en-us/drivers/) 535+，以及在主機上安裝 [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)。CUDA 映像檔僅支援 `linux/amd64`。

## 不使用 Docker Compose 執行

如需直接使用 `docker run` 指令，請先建立共享網路以便服務之間通訊：

```bash
docker network create ai-stack
```

然後在共享網路上啟動各服務：

```bash
# PostgreSQL (required by LiteLLM)
docker run -d --name litellm-db --restart always \
    --network ai-stack \
    -e POSTGRES_USER=litellm \
    -e POSTGRES_PASSWORD=litellm \
    -e POSTGRES_DB=litellm \
    -v litellm-db:/var/lib/postgresql \
    postgres:18

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
    hwdsl2/litellm-server
```

**注：** 共享網路允許服務透過容器名稱互相存取（例如 LiteLLM 透過 `http://ollama:11434` 連接 Ollama）。

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

**注：** 對於面向網際網路的部署，強烈建議使用[反向代理](#面向網際網路的部署)新增 HTTPS。在這種情況下，還需將 `docker-compose.yml` 中的 `"4000:4000/tcp"` 改為 `"127.0.0.1:4000:4000/tcp"`，以防止直接存取未加密連接埠。

**在 Playground 中試用：**

在管理介面中，點選左側選單的 **Playground**。從下拉清單中選擇本機模型（例如 `ollama/llama3.2:3b`）並開始對話 — 這是驗證本機大型語言模型端到端正常運作的一種快速方式。

## 自訂設定

每個服務可以透過可選的 env 檔案進行設定。從相應儲存庫複製範例 env 檔案，編輯後取消 `docker-compose.yml` 中的磁碟區掛載註解：

| 服務 | Env 檔案 | 儲存庫 |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh-Hant.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md) |

有關詳細設定選項、API 參考和模型管理，請參閱各服務儲存庫的文件。

## 面向網際網路的部署

預設情況下，所有服務透過純 HTTP 監聽。對於面向網際網路的部署，請在技術堆疊前面放置反向代理（例如 [Caddy](https://caddyserver.com/)、Nginx 或 Traefik）以提供 HTTPS。每個服務儲存庫都包含詳細的[反向代理指南](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md#使用反向代理)，含 Caddy 和 nginx 範例。

## 更新映像檔

將所有服務更新到最新版本：

```bash
docker compose pull
docker compose up -d
```

您的資料保存在 Docker 磁碟區中。

## 範例

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

curl http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "ollama/llama3.2:3b",
      "messages": [{"role": "user", "content": "Hello, how are you?"}]
    }' | jq -r '.choices[0].message.content'