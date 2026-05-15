[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# AI 工具

本機 LLM 搭配 MCP 工具存取，適用於 AI 程式設計助手（Cline、Claude、Cursor 等）。

**服務：** Ollama (LLM) + LiteLLM (閘道) + MCP Gateway

**記憶體：** ~3 GB RAM（使用 3B 模型）

## 架構

```mermaid
graph LR
    C["🤖 AI 用戶端<br/>(Cline, Claude 等)"] -->|MCP 工具| M["MCP Gateway<br/>(MCP 端點)"]
    C -->|聊天| L["LiteLLM<br/>(AI 閘道)"]
    L -->|路由至| O["Ollama<br/>(本機 LLM)"]
    L -->|MCP 協定| M
```

## 服務

| 服務 | 用途 | 預設連接埠 |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh-Hant.md)** | 執行本機 LLM 模型（llama3、qwen、mistral 等） | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md)** | 帶管理介面的 AI 閘道 — 將請求路由至 Ollama 及 100+ 供應商 | `4000` |
| **[MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/README-zh-Hant.md)** | 為 AI 用戶端提供 MCP 工具（檔案系統、fetch、GitHub、搜尋、資料庫） | `3000` |

## 快速開始

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/ai-tools
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
# Ollama (LLM)
docker run -d --name ollama --restart always \
    --network ai-stack \
    -v ollama-data:/var/lib/ollama \
    hwdsl2/ollama-server

# LiteLLM (AI 閘道)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -v litellm-data:/etc/litellm \
    hwdsl2/litellm-server

# MCP Gateway
docker run -d --name mcp --restart always \
    --network ai-stack \
    -v mcp-data:/var/lib/mcp \
    hwdsl2/mcp-gateway
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

## 自訂設定

每個服務可以透過可選的 env 檔案進行設定。從相應儲存庫複製範例 env 檔案，編輯後取消 `docker-compose.yml` 中的磁碟區掛載註解：

| 服務 | Env 檔案 | 儲存庫 |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-zh-Hant.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-zh-Hant.md) |
| MCP Gateway | `mcp.env` | [docker-mcp-gateway](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/README-zh-Hant.md) |

有關詳細設定選項、API 參考和模型管理，請參閱各服務儲存庫的文件。

## 更新映像檔

將所有服務更新到最新版本：

```bash
docker compose pull
docker compose up -d
```

您的資料保存在 Docker 磁碟區中。

## 將 MCP Gateway 連接到 LiteLLM

LiteLLM 和 MCP Gateway 已在 compose 檔案中**自動接入**。`LITELLM_MCP_URL=http://mcp:3000/mcp` 已預設，因此 LiteLLM 在設定 API 金鑰後會自動注入 `mcp_servers:` 區塊。

完成接入只需在首次啟動後設定 MCP API 金鑰：

```bash
# 1. 取得 MCP Gateway API 金鑰
docker exec mcp mcp_manage --showkey

# 2. 將金鑰新增至 litellm.env（或作為環境變數傳入）並重新啟動：
#    LITELLM_MCP_API_KEY=mcp-xxxx...
docker compose restart litellm
```

或者，在啟動前在 `mcp.env` 中預設 `MCP_API_KEY=my-key`，並在 `litellm.env` 中為 `LITELLM_MCP_API_KEY` 使用相同的值——這樣就無需重新啟動。

## 使用方式

```bash
# 取得 API 金鑰
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)
MCP_KEY=$(docker exec mcp mcp_manage --showkey | grep '^mcp-' | head -1)

# 在 AI 用戶端中使用（例如 VS Code 中的 Cline）：
# LLM 端點：http://localhost:4000（使用 LITELLM_KEY）
# MCP 端點：http://localhost:3000/mcp（使用 MCP_KEY）