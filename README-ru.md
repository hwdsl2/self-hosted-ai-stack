[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Docker AI Stack

[![Docker Compose AI Stack](docs/images/ai-stack.svg)](https://docs.docker.com/compose/) &nbsp;[![Docker Pulls](https://raw.githubusercontent.com/hwdsl2/badges/main/img/docker-pulls-ai-stack.svg)](https://hub.docker.com/u/hwdsl2) &nbsp;[![Лицензия: MIT](docs/images/license.svg)](https://opensource.org/licenses/MIT)

<p align="center">
  <img src="docs/images/docker-ai-stack-overview.png"
       alt="Docker AI Stack: разверните полный self-hosted AI-стек одной командой"
       width="100%">
</p>

Включает Ollama, LiteLLM, AnythingLLM, Whisper, MCP Gateway, Embeddings, Docling и Kokoro — полностью сконфигурирован и готов к запуску с Docker Compose.

- Без настройки: все сервисы автоматически конфигурируются при первом запуске
- Безопасность: защита AnythingLLM паролем включена по умолчанию, а Ollama, LiteLLM и MCP Gateway автоматически генерируют API-ключи
- Готовность к HTTPS: опциональный Caddy overlay предоставляет автоматический TLS и привязывает прямые HTTP-порты к localhost
- Приватность: по умолчанию работает локально с опциональной поддержкой внешних провайдеров через LiteLLM
- Опциональная авторизация: Whisper, WhisperLive, Kokoro, Embeddings и Docling работают без API-ключей по умолчанию (задайте ключи через env-файлы для публичных развёртываний)
- [Облегчённые стеки](#облегчённые-стеки) с меньшими требованиями к памяти (от ~4.5 ГБ)
- GPU-ускорение через NVIDIA CUDA
- Мультиархитектурность: `linux/amd64`, `linux/arm64`

## Сообщество

- 📬 [Подписаться на обновления проектов](https://selfhostedstack.beehiiv.com/subscribe?utm_campaign=ai-ru) (1–2 письма в месяц) — получить бесплатные руководства по развёртыванию AI и VPN (PDF, на английском)
- 💬 Присоединяйтесь к сообществу [r/selfhostedstack](https://www.reddit.com/r/selfhostedstack/) для обсуждений и демонстрации проектов
- ⭐ Поставьте звезду репозиторию, если он оказался вам полезен — это поможет другим пользователям его найти.

Docker AI Stack поддерживается автором [Setup IPsec VPN](https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/README-ru.md) (28k+ звёзд).

## Включённые сервисы

| Сервис | Назначение | Порт по умолчанию |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md)** | Запуск локальных LLM-моделей (llama3, qwen, mistral и др.) | `11434` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | Веб-чат — защита паролем включена по умолчанию | `3001` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md)** | AI-шлюз — маршрутизация запросов к Ollama, OpenAI, Anthropic и 100+ провайдерам | `4000` |
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-ru.md)** | Преобразование текста в векторы для семантического поиска и RAG | `8000` |
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-ru.md)** | Транскрибация речи в текст | `9000` |
| **[WhisperLive (STT в реальном времени)](https://github.com/hwdsl2/docker-whisper-live/blob/main/README-ru.md)** | Транскрибация речи в реальном времени через WebSocket | `9090` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-ru.md)** | Преобразование текста в естественную речь | `8880` |
| **[MCP Gateway](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/README-ru.md)** | Предоставление MCP-инструментов (файловая система, веб, GitHub, поиск, базы данных) AI-клиентам | `3000` |
| **[Docling](https://github.com/hwdsl2/docker-docling/blob/main/README-ru.md)** | Конвертирует документы (PDF, DOCX и др.) в структурированный текст/Markdown | `5001` |

## Быстрый старт

**Требования:**

- Linux-сервер (локальный или облачный) с установленным Docker
- Минимум 8 ГБ оперативной памяти (с небольшими моделями). Для крупных LLM-моделей (8B+) рекомендуется 16 ГБ и более.
- Вы можете закомментировать ненужные сервисы для уменьшения потребления памяти.

**Запуск полного стека:**

```bash
# Клонируйте репозиторий для получения compose-файлов
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack
docker compose up -d
```

**Загрузка модели** (обязательно перед отправкой LLM-запросов):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

Запустите проверку работоспособности, чтобы убедиться, что все сервисы работают:

```bash
./stack-check.sh
```

> **Совет:** При первом запуске сервисам может потребоваться несколько минут для инициализации. Если какие-либо проверки не пройдены, подождите и запустите `./stack-check.sh` снова. Используйте `docker compose logs` для проверки прогресса.

**Получение мастер-ключа LiteLLM** (используется для входа в панель администратора и LLM-запросов):

```bash
docker exec litellm litellm_manage --showkey
```

<details>
<summary>Показать все API-ключи (Ollama, LiteLLM, MCP Gateway)</summary>

```bash
docker exec ollama ollama_manage --showkey
docker exec litellm litellm_manage --showkey
docker exec mcp mcp_manage --showkey
```

</details>

**Доступ к AnythingLLM (чат-интерфейс):**

AnythingLLM предварительно настроен для подключения к локальной языковой модели через LiteLLM. При первом запуске может потребоваться несколько минут для готовности (проверяйте прогресс командой `docker logs anythingllm`).

**Защита паролем по умолчанию.** При первом запуске автоматически генерируется случайный пароль администратора, выводится один раз в `docker logs anythingllm` и сохраняется в `/app/server/storage/.initial_admin_password` внутри тома `anythingllm-data`. Пароль сохраняется при обновлении контейнера. Изменить его можно в любой момент через **Settings → Security**.

Получить автоматически сгенерированный пароль:

```bash
# В любой момент из тома данных:
docker exec anythingllm cat /app/server/storage/.initial_admin_password

# Или из живых логов (показывается только при первом запуске):
docker compose logs anythingllm | grep -A4 "FIRST RUN"
```

Откройте `http://<server-ip>:3001` в браузере и войдите с указанным выше паролем.

> **Совет:** При предоставлении доступа к AnythingLLM за пределами `localhost` или доверенной локальной сети используйте включённый Caddy HTTPS overlay, чтобы пароль шифровался при передаче, а прямые HTTP-порты были привязаны к localhost. См. ниже [Развёртывание с доступом из интернета](#развёртывание-с-доступом-из-интернета).

**Доступ к панели администратора LiteLLM:**

Откройте `http://<server-ip>:4000/ui` в браузере. Войдите с именем пользователя `admin` и вашим мастер-ключом LiteLLM в качестве пароля. Панель администратора предоставляет управление виртуальными ключами, отслеживание расходов и настройку моделей.

> **Совет:** В панели администратора нажмите **Playground** в левом меню. Выберите локальную модель (например, `ollama/llama3.2:3b`) из выпадающего списка и начните общаться — это быстрый способ убедиться, что локальная языковая модель работает сквозным образом.

**Остановка стека:**

```bash
# Остановка и удаление всех контейнеров (данные сохраняются в Docker-томах)
docker compose down
```

## GPU-ускорение (NVIDIA CUDA)

Для GPU-ускорения NVIDIA используйте CUDA compose-файл:

```bash
docker compose -f docker-compose.cuda.yml up -d
```

> **Совет:** Чтобы не добавлять `-f docker-compose.cuda.yml` к каждой последующей команде `docker compose` (`down`, `pull`, `logs` и т. д.), задайте её один раз для текущей сессии shell:
>
> ```bash
> export COMPOSE_FILE=docker-compose.cuda.yml
> ```
>
> Затем выполняйте обычные команды `docker compose` как всегда. Чтобы сделать это постоянным, добавьте `COMPOSE_FILE=docker-compose.cuda.yml` в файл `.env` в этом каталоге. Выполните `unset COMPOSE_FILE`, чтобы вернуться к конфигурации CPU.

**Требования:** GPU NVIDIA, [драйвер NVIDIA](https://www.nvidia.com/en-us/drivers/) 575.57.08+ (Linux) или 576.57+ (Windows), и [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html), установленный на хосте. CUDA-образы поддерживают только `linux/amd64`.

> **Пользователям Podman:** Podman игнорирует блок GPU `deploy:` в Compose. Используйте вместо него CDI — см. [Использование Podman](#использование-podman).

## Облегчённые стеки

Не нужен полный стек? Используйте преднастроенное подмножество из папки `stacks/`:

| Стек | Сервисы | Память | Сценарий использования |
|---|---|---|---|
| **[chat-ui](stacks/chat-ui/README-ru.md)** | Ollama + LiteLLM + AnythingLLM | ~5 ГБ | Веб-интерфейс для чата в стиле ChatGPT |
| **[voice-pipeline](stacks/voice-pipeline/README-ru.md)** | Whisper + Ollama + LiteLLM + Kokoro | ~6 ГБ | Речь в текст → LLM → текст в речь |
| **[voice-chat](stacks/voice-chat/README-ru.md)** | Whisper + Ollama + LiteLLM + Kokoro + AnythingLLM | ~6.5 ГБ | Чат-интерфейс с голосовым вводом/выводом |
| **[rag-pipeline](stacks/rag-pipeline/README-ru.md)** | Ollama + LiteLLM + Embeddings | ~5 ГБ | Семантический поиск + LLM Q&A |
| **[rag-pipeline-full](stacks/rag-pipeline-full/README-ru.md)** | Ollama + LiteLLM + Embeddings + Docling | ~6 ГБ | Разбор документов + семантический поиск + LLM Q&A |
| **[code-assistant](stacks/code-assistant/README-ru.md)** | Ollama + LiteLLM + MCP Gateway + Embeddings | ~5 ГБ | AI-разработка с инструментами + семантический поиск по коду |
| **[ai-tools](stacks/ai-tools/README-ru.md)** | Ollama + LiteLLM + MCP Gateway | ~5 ГБ | AI-ассистент для разработки с доступом к инструментам |
| **[chat-only](stacks/chat-only/README-ru.md)** | Ollama + LiteLLM | ~4.5 ГБ | Минимальная локальная замена ChatGPT |

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/chat-ui  # или voice-pipeline, voice-chat, rag-pipeline, rag-pipeline-full, code-assistant, ai-tools, chat-only
docker compose up -d
```

## Архитектура

```mermaid
graph LR
    A["🎤 Аудиовход"] -->|транскрибация| W["Whisper<br/>(речь в текст)"]
    D["📄 Документы"] -->|разбор| DC["Docling<br/>(документ → текст)"]
    DC -->|эмбеддинг| E["Embeddings<br/>(текст → векторы)"]
    E -->|хранение| VDB["pgvector<br/>(в общем Postgres)"]
    W -->|запрос| E
    VDB -->|контекст| L["LiteLLM<br/>(AI-шлюз)"]
    W -->|текст| L
    L -->|маршрутизация| O["Ollama<br/>(локальная LLM)"]
    L -->|ответ| T["Kokoro TTS<br/>(текст в речь)"]
    T --> B["🔊 Аудиовыход"]
    C["🤖 AI-клиент<br/>(Cline, Claude и др.)"] -->|MCP-инструменты| M["MCP Gateway<br/>(MCP-эндпоинт)"]
    C -->|чат| L
    L -->|MCP-протокол| M
    U["👤 Пользователь"] -->|чат| AN["AnythingLLM<br/>(чат-интерфейс)"]
    AN -->|запросы к LLM| L
    AN -->|MCP-инструменты| M
    U -->|использует| C
    U -->|говорит| A
    U -->|загружает| D
```

**Примечания:**

- Порт Ollama (`11434`) и порт MCP Gateway (`3000`) доступны только внутри сети Docker и не открыты на хосте по умолчанию. Доступ к LLM осуществляется через LiteLLM на порту `4000`.
- Для снижения потребления памяти сервисы Kokoro (TTS), Docling (парсинг документов) и WhisperLive (распознавание речи в реальном времени) по умолчанию отключены. Чтобы включить их, раскомментируйте соответствующие сервисы в `docker-compose.yml`.

## Запуск без Docker Compose

Если вы предпочитаете использовать команды `docker run` напрямую, сначала создайте общую сеть для связи между сервисами:

```bash
docker network create ai-stack
```

Затем запустите каждый сервис в общей сети:

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

# LiteLLM (AI-шлюз)
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

# AnythingLLM (чат-интерфейс)
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
    mintplexlabs/anythingllm:1.13 \
    /usr/local/bin/chat-ui-bootstrap.sh

# Kokoro (TTS)
docker run -d --name kokoro --restart always \
    --network ai-stack \
    -p 127.0.0.1:8880:8880 \
    -v kokoro-data:/var/lib/kokoro \
    hwdsl2/kokoro-server

# Docling (разбор документов)
docker run -d --name docling --restart always \
    --network ai-stack \
    -p 127.0.0.1:5001:5001 \
    -v docling-data:/var/lib/docling \
    hwdsl2/docling-server
```

**Примечание:** Общая сеть позволяет сервисам обращаться друг к другу по имени контейнера (например, LiteLLM подключается к Ollama через `http://ollama:11434`). Вы можете запускать только нужные сервисы — не обязательно запускать все.

**Загрузка модели** (обязательно перед отправкой LLM-запросов):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## Использование Podman

Стек работает под [Podman](https://podman.io/) на основе наилучших усилий. Compose-файлы для CPU работают без изменений; для GPU-ускорения и хостов с включённым SELinux нужны несколько дополнительных шагов, описанных ниже. Рекомендуется Podman **4.1+**.

**1. Установите слой совместимости с Docker CLI.** Чтобы команды `docker` из этого README и скрипт проверки `stack-check.sh` работали без изменений, установите пакет `podman-docker` (предоставляет обёртку `docker` → `podman`):

```bash
# Fedora / RHEL / CentOS Stream
sudo dnf install -y podman-docker

# Debian / Ubuntu
sudo apt-get install -y podman-docker
```

> **Примечание:** Псевдонима оболочки `alias docker=podman` **недостаточно** — псевдонимы не видны скриптам, таким как `stack-check.sh`. Используйте пакет `podman-docker` (или символическую ссылку `docker` → `podman` в `PATH`). Кроме того, `stack-check.sh` автоматически определяет Podman; вы также можете явно указать его через `CONTAINER_ENGINE=podman ./stack-check.sh`.

**2. Установите провайдер Compose.** `podman compose` делегирует выполнение внешнему провайдеру. Установите `podman-compose` или `docker-compose`:

```bash
# Fedora / RHEL / CentOS Stream
sudo dnf install -y podman-compose

# Debian / Ubuntu
sudo apt-get install -y podman-compose
```

**3. Запустите стек.** При установленном слое совместимости каждая команда из этого README работает без изменений. Без него замените `docker` на `podman`:

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack
podman compose up -d
```

Запустите проверку работоспособности (движок определяется автоматически):

```bash
./stack-check.sh
```

**GPU-ускорение (CDI).** Podman не читает блок GPU `deploy.resources` в Compose. Вместо этого используйте [Container Device Interface (CDI)](https://github.com/cncf-tags/container-device-interface). После установки [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) сгенерируйте спецификацию CDI:

```bash
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml
```

Затем предоставьте GPU соответствующим сервисам. Для `podman compose` замените блок `deploy:` у сервисов `ollama` (и `whisper`) в `docker-compose.cuda.yml` на запись `devices:`:

```yaml
    devices:
      - nvidia.com/gpu=all
```

Для обычной команды `podman run` добавьте `--device nvidia.com/gpu=all`.

**SELinux.** На хостах с включённым SELinux (Fedora, RHEL, CentOS Stream) для смонтированных файлов нужен суффикс переразметки, иначе контейнеру будет отказано в доступе. Добавьте `:z` (общий) к монтированию `chat-ui-bootstrap.sh`:

- В `docker-compose.yml`: измените `./chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro` на `./chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro,z`
- В команде `podman run` выше: измените `"$(pwd)/chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro"` на `"$(pwd)/chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro,z"`

Именованным томам переразметка не требуется.

**Дальнейшие шаги:** Загрузите модель и подключитесь к сервисам — следуйте инструкциям в разделе [Быстрый старт](#быстрый-старт), начиная с «Загрузка модели». При установленном пакете `podman-docker` все команды работают без изменений.

## Подключение MCP Gateway к LiteLLM

В compose-файлах этого репозитория LiteLLM и MCP Gateway **подключаются автоматически** — ручная настройка ключей не требуется.

API-ключи автоматически передаются между сервисами через общие Docker-тома:

- Ollama генерирует API-ключ при первом запуске и копирует его в общий том
- MCP Gateway делает то же самое
- LiteLLM считывает оба ключа из общих томов при запуске

Переменные `LITELLM_MCP_URL=http://mcp:3000/mcp` и `LITELLM_OLLAMA_BASE_URL=http://ollama:11434` уже заданы в compose-файлах, поэтому все сервисы подключаются автоматически одной командой `docker compose up -d`.

После подключения AI-клиенты, обращающиеся к LiteLLM, смогут использовать MCP-инструменты (файловая система, web-fetch, GitHub и др.) напрямую через прокси LiteLLM.

## Пример голосового конвейера

Транскрибируйте голосовой вопрос, получите ответ от локальной LLM через Ollama и преобразуйте его в речь:

**Примечание:** Kokoro (TTS) отключён по умолчанию. Чтобы использовать этот пример, сначала раскомментируйте сервис `kokoro` в файле `docker-compose.yml`, затем выполните `docker compose up -d`.

**Совет:** Нужен образец аудиофайла? Скачайте этот образец английской речи (WAV, лицензия MIT) из репозитория [Azure Samples](https://github.com/Azure-Samples/cognitive-services-speech-sdk):

```bash
curl -L -o sample_speech.wav \
    "https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/katiesteve.wav"
```

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# Шаг 1: Транскрибация аудио в текст (Whisper)
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -F file=@sample_speech.wav -F model=whisper-1 | jq -r .text)

# Шаг 2: Отправка текста в Ollama через LiteLLM и получение ответа
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"ollama/llama3.2:3b\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# Шаг 3: Преобразование ответа в речь (Kokoro TTS)
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3
```

## Векторная база данных

PostgreSQL в этом стеке поставляется с расширением [pgvector](https://github.com/pgvector/pgvector), поэтому вы можете хранить и запрашивать эмбеддинги в той же базе данных, которую использует LiteLLM — отдельная векторная база данных не требуется.

Включите расширение один раз (база данных сохраняется, поэтому это нужно сделать только однажды):

```bash
docker exec litellm-db psql -U litellm -d litellm -c 'CREATE EXTENSION IF NOT EXISTS vector;'
```

Проверьте, что оно включено:

```bash
docker exec litellm-db psql -U litellm -d litellm -c "SELECT extname, extversion FROM pg_extension WHERE extname='vector';"
```

Затем можно создать таблицу со столбцом `vector` (используйте размерность вашей модели эмбеддингов — например, `384` для модели по умолчанию `BAAI/bge-small-en-v1.5`) и выполнять поиск по сходству с помощью оператора `<=>`. Для большего масштаба или гибридного поиска можно использовать отдельную векторную базу данных, например Qdrant или Chroma.

## Пример RAG-конвейера

Создание эмбеддингов документов для семантического поиска, извлечение контекста и ответы на вопросы с помощью локальной модели Ollama:

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)

# Шаг 1: Создание эмбеддинга фрагмента документа и сохранение вектора в векторной БД
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → Сохраните возвращённый вектор вместе с исходным текстом в pgvector (входит в Postgres этого стека) или в другую векторную БД, например Qdrant или Chroma.

# Шаг 2: При запросе создайте эмбеддинг вопроса, извлеките наиболее релевантные фрагменты
#          из векторной БД, затем отправьте вопрос и контекст в Ollama через LiteLLM.
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

## Пример MCP-инструментов

Используйте MCP Gateway для предоставления AI-ассистенту доступа к файлам, вебу и GitHub:

```bash
MCP_KEY=$(docker exec mcp mcp_manage --showkey | grep '^mcp-' | head -1)

# Используйте MCP-эндпоинт с AI-клиентом (например, Cline в VS Code)
# URL MCP-сервера: http://localhost:3000/mcp
# Заголовок Authorization: Bearer <api_key>

# Или протестируйте MCP-эндпоинт напрямую
curl -s http://localhost:3000/mcp \
    -X POST \
    -H "Authorization: Bearer $MCP_KEY" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json, text/event-stream" \
    -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

## Настройка

Каждый сервис можно настроить с помощью опционального env-файла. Скопируйте пример env-файла из соответствующего репозитория, отредактируйте его и раскомментируйте монтирование тома в `docker-compose.yml`:

| Сервис | Env-файл | Репозиторий |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md) |
| Embeddings | `embed.env` | [docker-embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-ru.md) |
| Whisper | `whisper.env` | [docker-whisper](https://github.com/hwdsl2/docker-whisper/blob/main/README-ru.md) |
| WhisperLive | `whisper-live.env` | [docker-whisper-live](https://github.com/hwdsl2/docker-whisper-live/blob/main/README-ru.md) |
| Kokoro | `kokoro.env` | [docker-kokoro](https://github.com/hwdsl2/docker-kokoro/blob/main/README-ru.md) |
| MCP Gateway | `mcp.env` | [docker-mcp-gateway](https://github.com/hwdsl2/docker-mcp-gateway/blob/main/README-ru.md) |
| Docling | `docling.env` | [docker-docling](https://github.com/hwdsl2/docker-docling/blob/main/README-ru.md) |

AnythingLLM настраивается через веб-интерфейс по адресу `http://<IP-сервера>:3001`. Вы можете изменить провайдера LLM, модель, движок эмбеддингов и другие параметры в разделе **Settings**. Подробнее см. [документацию AnythingLLM](https://docs.useanything.com/).

**Использование сервиса Embeddings из стека (опционально).** По умолчанию AnythingLLM выполняет эмбеддинги внутри своего процесса с помощью встроенной модели MiniLM и сохраняет векторы в собственной LanceDB. Чтобы вместо этого использовать сервис [Embeddings](https://github.com/hwdsl2/docker-embeddings) из стека (BAAI/bge-small-en-v1.5) и/или Postgres с включённым pgvector, отредактируйте сервис `anythingllm` в `docker-compose.yml`: закомментируйте `EMBEDDING_ENGINE=native` и раскомментируйте опциональный блок под ним. Также раскомментируйте примечание `depends_on`, чтобы сервисы embeddings/db запускались первыми. Опциональный блок указывает на `http://embeddings:8000/v1` и `postgresql://litellm:litellm@db:5432/litellm`; AnythingLLM автоматически создаёт расширение `vector` и таблицу `anythingllm_vectors` при первом использовании. ⚠️ Переключение движка эмбеддингов или векторного хранилища на существующем развёртывании делает ранее проиндексированные документы несовместимыми — повторно проиндексируйте свои рабочие пространства после смены.

Подробные параметры настройки, справочник API и управление моделями описаны в документации каждого сервиса.

## Развёртывание с доступом из интернета

По умолчанию все сервисы слушают по незашифрованному HTTP. Для развёртываний с доступом из интернета можно использовать включённый Caddy overlay для автоматического HTTPS. В режиме прокси Caddy является единственным публичным слушателем на портах `80` и `443`; прямые порты AnythingLLM и LiteLLM заново привязываются к `127.0.0.1`.

Требования:

- Docker Compose `2.24.4+` (требуется для переопределения портов в proxy overlay)
- DNS-запись `A`/`AAAA` для вашего домена указывает на этот сервер
- В firewall/security group открыты входящие `80/tcp`, `443/tcp` и желательно `443/udp`
- На хосте нет другого сервиса, уже использующего порты `80` или `443`

**CPU-стек:**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.yml -f docker-compose.proxy.yml up -d
```

**CUDA-стек:**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.cuda.yml -f docker-compose.proxy.yml up -d
```

Откройте `https://chat.example.com` (замените на ваш `DOMAIN`) для доступа к AnythingLLM. В режиме прокси `http://127.0.0.1:3001` и `http://127.0.0.1:4000/ui` остаются доступны на самом хосте, но прямые порты `3001` и `4000` недоступны извне сервера.

Стандартные compose-файлы публикуют LiteLLM на порту `4000`. Proxy overlay меняет этот прямой порт на доступный только через localhost, а включённый Caddyfile по умолчанию маршрутизирует только AnythingLLM. Если раскомментировать опциональный блок с отдельным hostname для LiteLLM, LiteLLM будет открыт через Caddy, поэтому храните мастер-ключ LiteLLM в секрете.

Диагностика:

```bash
docker logs ai-stack-caddy
# Используйте те же файлы -f, с которыми запускали стек
docker compose -f docker-compose.yml -f docker-compose.proxy.yml ps
```

Если Caddy сообщает о неизвестной директиве `request_body`, загрузите текущий образ `caddy:2` и перезапустите overlay.

Пользователи старых версий Docker Compose или Podman по-прежнему могут использовать обратный прокси на хосте: привяжите прямые HTTP-порты к localhost (например, `"127.0.0.1:3001:3001/tcp"` и `"127.0.0.1:4000:4000/tcp"`) и проксируйте на эти localhost-порты. Каждый репозиторий сервиса содержит подробное [руководство по обратному прокси](https://github.com/hwdsl2/docker-whisper/blob/main/README-ru.md#использование-обратного-прокси) с примерами для Caddy и nginx.

При открытии сервисов в интернет установите API-ключи для сервисов с опциональной авторизацией (Whisper, WhisperLive, Kokoro, Embeddings, Docling) через соответствующие env-файлы.

## Резервное копирование и восстановление

Ваши API-ключи, модели и конфигурация хранятся в Docker-томах. Создайте резервную копию перед обновлением или внесением изменений:

```bash
# Экспорт API-ключей (при работающих контейнерах)
docker exec ollama ollama_manage --showkey
docker exec litellm litellm_manage --showkey
docker exec mcp mcp_manage --showkey

# Резервное копирование всех томов (сначала остановите сервисы)
# Остановка и удаление всех контейнеров (данные сохраняются в Docker-томах)
docker compose down
mkdir -p backups
for vol in ollama-data litellm-data litellm-db embeddings-data whisper-data whisper-live-data kokoro-data mcp-data docling-data anythingllm-data caddy-data caddy-config; do
  docker volume inspect "$vol" >/dev/null 2>&1 && \
    docker run --rm -v "${vol}:/source:ro" -v "$(pwd)/backups:/backup" \
      alpine tar czf "/backup/${vol}.tar.gz" -C /source .
done
```

**Примечание:** Тома `ollama-shared`, `mcp-shared` и `litellm-shared` являются временными томами для передачи ключей и не требуют резервного копирования.

Инструкции по восстановлению, миграции на новый сервер и полный контрольный список перед обновлением см. в руководстве [Резервное копирование и восстановление](docs/backup-restore-ru.md).

## Обновление образов

Обновление всех сервисов до последних версий:

```bash
git pull
docker compose pull
docker compose up -d
./stack-check.sh
```

`git pull` обновляет все файлы проекта (включая изменения compose-файлов); `docker compose pull` обновляет образы сервисов. Если вы изменяли `docker-compose.yml`, `git pull` объединит изменения автоматически или попросит разрешить конфликт, если изменены одни и те же строки.

**Одноразовое примечание для старых установок:** Если вы задали пароль AnythingLLM до исправления сохранения `.env`, первое пересоздание контейнера после обновления может очистить этот пароль и оставить AnythingLLM без защиты. После обновления сразу откройте AnythingLLM и проверьте, что защита паролем по-прежнему включена. Если нет, задайте новый пароль в **Settings → Security**. При следующих пересозданиях контейнера пароль будет сохраняться.

AnythingLLM закреплен на стабильном теге релиза, а не на `latest`, потому что upstream-образ `latest` отслеживает ветку master. Когда выйдет новый релиз AnythingLLM, сначала создайте резервную копию, обновите тег в compose-файлах, затем выполните команды выше.

Ваши данные сохраняются в Docker-томах. **Всегда [создавайте резервную копию](#резервное-копирование-и-восстановление) перед обновлением.**

## Лицензия

Copyright (C) 2026 Lin Song   
Данный проект лицензирован на условиях [лицензии MIT](https://opensource.org/licenses/MIT).

Данный проект представляет собой независимую Docker-конфигурацию и не аффилирован с Ollama, Berri AI (LiteLLM), Hugging Face, hexgrad (Kokoro), OpenAI, SYSTRAN или MCPHub, не одобрен и не спонсирован ими.
