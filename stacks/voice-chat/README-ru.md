[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Голосовой чат

Веб-интерфейс чата с голосовым вводом (речь в текст) и голосовым выводом (текст в речь) — полноценный локальный AI-ассистент.

**Сервисы:** Ollama (LLM) + LiteLLM (шлюз) + [AnythingLLM](https://github.com/mintplex-labs/anything-llm) (чат-интерфейс) + Whisper (STT) + Kokoro (TTS)

**Память:** ~6.5 ГБ RAM (с моделью 3B)

**Платформы:** `linux/amd64`, `linux/arm64`

## Архитектура

```mermaid
graph LR
    U["👤 Пользователь"] -->|чат| A["AnythingLLM<br/>(чат-интерфейс)"]
    U -->|говорит| W["Whisper<br/>(речь в текст)"]
    A -->|API| L["LiteLLM<br/>(AI-шлюз)"]
    L -->|маршрутизация| O["Ollama<br/>(локальная LLM)"]
    L -->|ответ| K["Kokoro<br/>(текст в речь)"]
    K --> S["🔊 Аудиовыход"]
    W -->|текст| L
```

## Сервисы

| Сервис | Назначение | Порт по умолчанию |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md)** | Запускает локальные LLM-модели (llama3, qwen, mistral и др.) | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md)** | AI-шлюз с панелью администратора — маршрутизирует запросы к Ollama и 100+ провайдерам | `4000` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | Веб-интерфейс чата с рабочими пространствами, RAG и поддержкой агентов | `3001` |
| **[Whisper (STT)](https://github.com/hwdsl2/docker-whisper/blob/main/README-ru.md)** | Транскрибирует аудио в текст | `9000` |
| **[Kokoro (TTS)](https://github.com/hwdsl2/docker-kokoro/blob/main/README-ru.md)** | Преобразует текст в естественную речь | `8880` |

## Быстрый старт

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack/stacks/voice-chat
docker compose up -d
```

**Загрузка модели** (обязательно перед отправкой LLM-запросов):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

**Откройте чат-интерфейс:**

AnythingLLM предварительно настроен для подключения к LiteLLM. API-ключ автоматически передаётся через общий том Docker — ручная настройка не требуется. Провайдер LLM, базовый URL и модель уже настроены.

При первом запуске AnythingLLM может потребоваться несколько минут для готовности (проверяйте прогресс командой `docker logs anythingllm`).

**Защита паролем по умолчанию.** При первом запуске автоматически генерируется случайный пароль администратора, выводится один раз в `docker logs anythingllm` и сохраняется в `/app/server/storage/.initial_admin_password` внутри тома `anythingllm-data`. Сгенерированный пароль сохраняется при обновлении контейнера. Изменить его можно в любой момент через **Settings → Security**; после изменения `.initial_admin_password` может больше не совпадать с текущим паролем входа.

Получить автоматически сгенерированный пароль:

```bash
# В любой момент из тома данных:
docker exec anythingllm cat /app/server/storage/.initial_admin_password

# Или из живых логов (показывается только при первом запуске):
docker compose logs anythingllm | grep -A4 "FIRST RUN"
```

Откройте `http://<server-ip>:3001` в браузере и войдите с указанным выше паролем.

> **Совет:** При предоставлении доступа к AnythingLLM за пределами `localhost` или доверенной локальной сети используйте включённый Caddy HTTPS overlay, чтобы пароль шифровался при передаче, а прямые HTTP-порты были привязаны к localhost. См. ниже [Использование обратного прокси](#использование-обратного-прокси).

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

## Запуск без Docker Compose

Если вы предпочитаете использовать команды `docker run` напрямую, сначала создайте общую сеть для связи между сервисами:

```bash
docker network create ai-stack
```

Затем запустите каждый сервис в общей сети:

> **Примечание:** При ручном использовании `docker run` дождитесь готовности каждой зависимости перед запуском сервисов, которые её используют (например, дождитесь PostgreSQL и других зависимостей, например Ollama или MCP, перед запуском LiteLLM; если используется AnythingLLM, дождитесь готовности LiteLLM перед его запуском). В примерах ниже создаётся одна переменная пароля PostgreSQL и повторно используется для Postgres и LiteLLM.

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

# LiteLLM (AI-шлюз)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_DATABASE_URL="postgresql://litellm:${LITELLM_POSTGRES_PASSWORD}@litellm-db:5432/litellm" \
    -v litellm-data:/etc/litellm \
    -v ollama-shared:/var/lib/ollama-shared:ro \
    -v litellm-shared:/var/lib/litellm-shared \
    hwdsl2/litellm-server

# AnythingLLM (чат-интерфейс)
docker run -d --name anythingllm --restart always \
    --network ai-stack \
    -p 3001:3001 \
    -e STORAGE_DIR=/app/server/storage \
    -e LLM_PROVIDER=generic-openai \
    -e GENERIC_OPEN_AI_BASE_PATH=http://litellm:4000/v1 \
    -e GENERIC_OPEN_AI_MODEL_PREF=ollama/llama3.2:3b \
    -e GENERIC_OPEN_AI_MODEL_TOKEN_LIMIT=131072 \
    -e ANYTHINGLLM_DEFAULT_CHAT_MODE=chat \
    -e EMBEDDING_ENGINE=native \
    -e DISABLE_TELEMETRY=true \
    -v anythingllm-data:/app/server/storage \
    -v litellm-shared:/var/lib/litellm-shared:ro \
    -v "$(pwd)/chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro" \
    --entrypoint /bin/bash \
    mintplexlabs/anythingllm:1.14.1 \
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

**Примечание:** Общая сеть позволяет сервисам обращаться друг к другу по имени контейнера (например, AnythingLLM подключается к LiteLLM через `http://litellm:4000`).

**Загрузка модели** (обязательно перед отправкой LLM-запросов):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## Проверка развёртывания

После запуска стека можно проверить, что все сервисы работают корректно:

```bash
# Выполните из корневой директории self-hosted-ai-stack
../../stack-check.sh
```

**Доступ к панели администратора LiteLLM:**

Откройте `http://<server-ip>:4000/ui` в браузере. Войдите с именем пользователя `admin` и вашим мастер-ключом LiteLLM в качестве пароля. Панель администратора предоставляет управление виртуальными ключами, отслеживание расходов и настройку моделей.

> **Совет:** В панели администратора нажмите **Playground** в левом меню. Выберите локальную модель (например, `ollama/llama3.2:3b`) из выпадающего списка и начните общаться — это быстрый способ убедиться, что локальная языковая модель работает сквозным образом.

## Счётчики использования

Этот стек участвует в анонимном агрегированном подсчёте загрузок GitHub release assets проекта. Запустите с `AI_STACK_DISABLE_USAGE_COUNTS=1 docker compose up -d`, чтобы отключить их; подробнее см. [Счётчики использования](../../README-ru.md#счётчики-использования).

## Настройка

Каждый сервис можно настроить с помощью опционального env-файла. Скопируйте пример env-файла из соответствующего репозитория, отредактируйте его и раскомментируйте монтирование тома в `docker-compose.yml`:

| Сервис | Env-файл | Репозиторий |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md) |
| Whisper | `whisper.env` | [docker-whisper](https://github.com/hwdsl2/docker-whisper/blob/main/README-ru.md) |
| Kokoro | `kokoro.env` | [docker-kokoro](https://github.com/hwdsl2/docker-kokoro/blob/main/README-ru.md) |

AnythingLLM настраивается через веб-интерфейс `http://<server-ip>:3001`. Вы можете изменить провайдер LLM, модель, движок эмбеддингов и другие параметры в **Settings**. Подробнее см. [документацию AnythingLLM](https://docs.useanything.com/).

Подробные параметры настройки, справочник API и управление моделями описаны в документации каждого сервиса.

## Использование обратного прокси

Для развёртываний с выходом в интернет используйте включённый Caddy overlay для автоматического HTTPS. Выполняйте эти команды из каталога `stacks/voice-chat`. Корневой overlay `../../docker-compose.proxy.yml` намеренно монтирует локальный для этого стека `caddy/Caddyfile`. В режиме прокси Caddy является единственным публичным слушателем на портах `80` и `443`; прямые порты AnythingLLM и LiteLLM заново привязываются к `127.0.0.1`. По умолчанию прокси открывает только AnythingLLM; Whisper и Kokoro остаются привязанными согласно compose-файлу этого подстека.

Требования:

- Docker Compose `2.24.4+` (требуется для переопределения портов в proxy overlay)
- DNS-запись `A`/`AAAA` для вашего домена указывает на этот сервер
- В firewall/security group открыты входящие `80/tcp`, `443/tcp` и желательно `443/udp`
- На хосте нет другого сервиса, уже использующего порты `80` или `443`

**CPU-стек:**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.yml -f ../../docker-compose.proxy.yml up -d
```

**CUDA-стек:**

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.cuda.yml -f ../../docker-compose.proxy.yml up -d
```

Откройте `https://chat.example.com` (замените на ваш `DOMAIN`) для доступа к AnythingLLM. В режиме прокси `http://127.0.0.1:3001` и `http://127.0.0.1:4000/ui` остаются доступны на самом хосте, но прямые порты `3001` и `4000` недоступны извне сервера.

Стандартные compose-файлы публикуют LiteLLM на порту `4000`. Proxy overlay меняет этот прямой порт на доступный только через localhost, а включённый Caddyfile по умолчанию маршрутизирует только AnythingLLM. Если раскомментировать опциональный блок с отдельным hostname для LiteLLM, LiteLLM будет открыт через Caddy, поэтому храните мастер-ключ LiteLLM в секрете.

Диагностика:

```bash
docker logs ai-stack-caddy
# Используйте те же файлы -f, с которыми запускали стек
docker compose -f docker-compose.yml -f ../../docker-compose.proxy.yml ps
```

Если Caddy сообщает о неизвестной директиве `request_body`, загрузите текущий образ `caddy:2` и перезапустите overlay.

Пользователи старых версий Docker Compose или Podman по-прежнему могут использовать обратный прокси на хосте: привяжите прямые HTTP-порты к localhost (например, `"127.0.0.1:3001:3001/tcp"` и `"127.0.0.1:4000:4000/tcp"`) и проксируйте на эти localhost-порты.

### Ручной обратный прокси

Для доступа к контейнеру AnythingLLM из обратного прокси используйте один из адресов:

- **`anythingllm:3001`** — если обратный прокси работает как контейнер в **той же сети Docker** (например, определён в том же `docker-compose.yml`).
- **`127.0.0.1:3001`** — если обратный прокси работает **на хосте** и порт `3001` опубликован (по умолчанию в `docker-compose.yml`).

**Пример с [Caddy](https://caddyserver.com/docs/) ([Docker-образ](https://hub.docker.com/_/caddy))** (автоматический TLS через Let's Encrypt, обратный прокси в той же сети Docker):

`Caddyfile`:
```
chat.example.com {
  reverse_proxy anythingllm:3001
}
```

**Пример с nginx** (обратный прокси на хосте):

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

**Важно:** AnythingLLM включает собственную систему аутентификации — установите надёжный пароль при первой настройке, если сервис доступен из интернета.

## Резервное копирование и восстановление

Инструкции по резервному копированию и восстановлению см. в руководстве [Резервное копирование и восстановление](../../docs/backup-restore-ru.md).

## Обновление образов

Обновление всех сервисов до последних версий:

```bash
git pull
docker compose pull
docker compose up -d
../../stack-check.sh
```

После перезапуска подстека выполните `../../stack-check.sh`, чтобы проверить сервисы и настройку сгенерированных учётных данных.

`git pull` обновляет этот репозиторий, включая compose-файлы или вспомогательные скрипты, используемые этим подстеком; `docker compose pull` обновляет образы сервисов.

**Одноразовое примечание для старых установок:** Если вы задали пароль AnythingLLM до исправления сохранения `.env`, первое пересоздание контейнера после обновления может очистить этот пароль и оставить AnythingLLM без защиты. После обновления сразу откройте AnythingLLM и проверьте, что защита паролем по-прежнему включена. Если нет, задайте новый пароль в **Settings → Security**. При следующих пересозданиях контейнера пароль будет сохраняться.

AnythingLLM закреплен на стабильном теге релиза, а не на `latest`, потому что upstream-образ `latest` отслеживает ветку master. Когда выйдет новый релиз AnythingLLM, сначала создайте резервную копию, обновите тег в compose-файлах, затем выполните команды выше.

Ваши данные сохраняются в Docker-томах. **Всегда делайте [резервную копию](../../docs/backup-restore-ru.md) перед обновлением.**

## Пример голосового конвейера

Транскрибировать голосовой вопрос, получить ответ от локальной LLM и преобразовать в речь:

**Совет:** Нужен пример аудиофайла? Скачайте образец английской речи (WAV, лицензия MIT) из репозитория [Azure Samples](https://github.com/Azure-Samples/cognitive-services-speech-sdk):

```bash
curl -L -o sample_speech.wav \
    "https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/katiesteve.wav"
```

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)
WHISPER_KEY=$(docker exec whisper whisper_manage --getkey)
KOKORO_KEY=$(docker exec kokoro kokoro_manage --getkey)

# Шаг 1: Транскрибировать аудио в текст (Whisper)
TEXT=$(curl -s http://localhost:9000/v1/audio/transcriptions \
    -H "Authorization: Bearer $WHISPER_KEY" \
    -F file=@sample_speech.wav -F model=whisper-1 | jq -r .text)

# Шаг 2: Отправить текст в Ollama через LiteLLM и получить ответ
RESPONSE=$(curl -s http://localhost:4000/v1/chat/completions \
    -H "Authorization: Bearer $LITELLM_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"ollama/llama3.2:3b\",\"messages\":[{\"role\":\"user\",\"content\":\"$TEXT\"}]}" \
    | jq -r '.choices[0].message.content')

# Шаг 3: Преобразовать ответ в речь (Kokoro TTS)
curl -s http://localhost:8880/v1/audio/speech \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $KOKORO_KEY" \
    -d "{\"model\":\"tts-1\",\"input\":\"$RESPONSE\",\"voice\":\"af_heart\"}" \
    --output response.mp3

```
