[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Чат-интерфейс

Локальный аналог ChatGPT — веб-интерфейс для чата на основе локальной LLM с OpenAI-совместимым API-шлюзом.

**Сервисы:** Ollama (LLM) + LiteLLM (шлюз) + [AnythingLLM](https://github.com/mintplex-labs/anything-llm) (чат-интерфейс)

**Память:** ~5 ГБ RAM (с моделью 3B)

**Платформы:** `linux/amd64`, `linux/arm64`

## Архитектура

```mermaid
graph LR
    U["🌐 Браузер"] -->|чат| A["AnythingLLM<br/>(чат-интерфейс)"]
    A -->|API| L["LiteLLM<br/>(AI-шлюз)"]
    L -->|маршрутизация| O["Ollama<br/>(локальная LLM)"]
```

## Сервисы

| Сервис | Назначение | Порт по умолчанию |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md)** | Запуск локальных LLM-моделей (llama3, qwen, mistral и др.) | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md)** | AI-шлюз с панелью администратора — маршрутизация запросов к Ollama и 100+ провайдерам | `4000` |
| **[AnythingLLM](https://github.com/mintplex-labs/anything-llm)** | Веб-интерфейс для чата с рабочими пространствами, RAG и агентами | `3001` |

## Быстрый старт

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack/stacks/chat-ui
docker compose up -d
```

**Загрузка модели** (необходимо перед отправкой запросов к LLM):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

**Откройте чат-интерфейс:**

AnythingLLM предварительно настроен для подключения к LiteLLM. API-ключ передаётся автоматически через Docker-том — ручная настройка не требуется. Провайдер LLM, базовый URL и модель уже предварительно настроены.

При первом запуске AnythingLLM может потребоваться несколько минут для готовности (проверяйте прогресс командой `docker logs anythingllm`).

**Защита паролем по умолчанию.** При первом запуске автоматически генерируется случайный пароль администратора, выводится один раз в `docker logs anythingllm` и сохраняется в `/app/server/storage/.initial_admin_password` внутри тома `anythingllm-data`. Пароль сохраняется при обновлении контейнера. Изменить его можно в любой момент через **Settings → Security**.

Получить автоматически сгенерированный пароль:

```bash
# В любой момент из тома данных:
docker exec anythingllm cat /app/server/storage/.initial_admin_password

# Или из живых логов (показывается только при первом запуске):
docker compose logs anythingllm | grep -A4 "FIRST RUN"
```

Откройте `http://<IP-сервера>:3001` в браузере и войдите с указанным выше паролем.

> **Совет:** При предоставлении доступа к AnythingLLM за пределами `localhost` или доверенной локальной сети используйте включённый Caddy HTTPS overlay, чтобы пароль шифровался при передаче, а прямые HTTP-порты были привязаны к localhost. См. ниже [Использование обратного прокси](#использование-обратного-прокси).

## GPU-ускорение (NVIDIA CUDA)

Для ускорения на GPU NVIDIA используйте CUDA-файл:

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

**Требования:** GPU NVIDIA, [драйвер NVIDIA](https://www.nvidia.com/en-us/drivers/) 575.57.08+ (Linux) или 576.57+ (Windows), и установленный на хосте [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html). CUDA-образы поддерживают только `linux/amd64`.

## Запуск без Docker Compose

Если вы предпочитаете использовать команды `docker run` напрямую, сначала создайте общую сеть для взаимодействия сервисов:

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

# LiteLLM (AI-шлюз)
docker run -d --name litellm --restart always \
    --network ai-stack \
    -p 4000:4000 \
    -e LITELLM_OLLAMA_BASE_URL=http://ollama:11434 \
    -e LITELLM_DATABASE_URL=postgresql://litellm:litellm@litellm-db:5432/litellm \
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
    -e EMBEDDING_ENGINE=native \
    -e DISABLE_TELEMETRY=true \
    -v anythingllm-data:/app/server/storage \
    -v litellm-shared:/var/lib/litellm-shared:ro \
    -v "$(pwd)/chat-ui-bootstrap.sh:/usr/local/bin/chat-ui-bootstrap.sh:ro" \
    --entrypoint /bin/bash \
    mintplexlabs/anythingllm:1.13 \
    /usr/local/bin/chat-ui-bootstrap.sh
```

**Примечание:** Общая сеть позволяет сервисам обращаться друг к другу по имени контейнера (например, AnythingLLM подключается к LiteLLM через `http://litellm:4000`).

**Загрузка модели** (необходимо перед отправкой запросов к LLM):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## Проверка развёртывания

После запуска можно проверить, что все сервисы работают корректно:

```bash
# Запустите из корневого каталога docker-ai-stack
../../stack-check.sh
```

**Доступ к панели администратора LiteLLM:**

Откройте `http://<server-ip>:4000/ui` в браузере. Войдите с именем пользователя `admin` и вашим мастер-ключом LiteLLM в качестве пароля. Панель администратора предоставляет управление виртуальными ключами, отслеживание расходов и настройку моделей.

> **Совет:** В панели администратора нажмите **Playground** в левом меню. Выберите локальную модель (например, `ollama/llama3.2:3b`) из выпадающего списка и начните общаться — это быстрый способ убедиться, что локальная языковая модель работает сквозным образом.

## Настройка

Каждый сервис можно настроить с помощью необязательного env-файла. Скопируйте пример env-файла из соответствующего репозитория, отредактируйте его и раскомментируйте монтирование тома в `docker-compose.yml`:

| Сервис | Env-файл | Репозиторий |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md) |

AnythingLLM настраивается через веб-интерфейс по адресу `http://<IP-сервера>:3001`. Вы можете изменить провайдера LLM, модель, движок эмбеддингов и другие параметры в разделе **Settings**. Подробнее см. [документацию AnythingLLM](https://docs.useanything.com/).

**Совет:** Если вы также запускаете другие подстеки (например, [voice-pipeline](../voice-pipeline/README-ru.md), [rag-pipeline](../rag-pipeline/README-ru.md)), вы можете направить AnythingLLM на эти сервисы через страницу настроек — например, использовать `docker-whisper` для распознавания речи или `docker-embeddings` для векторных эмбеддингов.

Подробные параметры настройки, справку по API и управление моделями см. в документации каждого репозитория сервиса.

## Использование обратного прокси

Для развёртываний с выходом в интернет используйте включённый Caddy overlay для автоматического HTTPS. Выполняйте эти команды из каталога `stacks/chat-ui`. В режиме прокси Caddy является единственным публичным слушателем на портах `80` и `443`; прямые порты AnythingLLM и LiteLLM заново привязываются к `127.0.0.1`.

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

Используйте один из следующих адресов для доступа к контейнеру AnythingLLM из обратного прокси:

- **`anythingllm:3001`** — если ваш обратный прокси работает как контейнер в **той же Docker-сети**, что и AnythingLLM (например, определён в том же `docker-compose.yml`).
- **`127.0.0.1:3001`** — если ваш обратный прокси работает **на хосте** и порт `3001` опубликован (по умолчанию `docker-compose.yml` публикует его).

**Пример с [Caddy](https://caddyserver.com/docs/) ([Docker-образ](https://hub.docker.com/_/caddy))** (автоматический TLS через Let's Encrypt, обратный прокси в той же Docker-сети):

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

**Важно:** AnythingLLM включает встроенную систему аутентификации пользователей — при открытии сервиса в интернет установите надёжный пароль при первоначальной настройке.

## Резервное копирование и восстановление

Инструкции по резервному копированию и восстановлению см. в руководстве [Резервное копирование и восстановление](../../docs/backup-restore-ru.md).

## Обновление образов

Обновление всех сервисов до последних версий:

```bash
git pull
docker compose pull
docker compose up -d
```

`git pull` обновляет этот репозиторий, включая compose-файлы или вспомогательные скрипты, используемые этим подстеком; `docker compose pull` обновляет образы сервисов.

**Одноразовое примечание для старых установок:** Если вы задали пароль AnythingLLM до исправления сохранения `.env`, первое пересоздание контейнера после обновления может очистить этот пароль и оставить AnythingLLM без защиты. После обновления сразу откройте AnythingLLM и проверьте, что защита паролем по-прежнему включена. Если нет, задайте новый пароль в **Settings → Security**. При следующих пересозданиях контейнера пароль будет сохраняться.

AnythingLLM закреплен на стабильном теге релиза, а не на `latest`, потому что upstream-образ `latest` отслеживает ветку master. Когда выйдет новый релиз AnythingLLM, сначала создайте резервную копию, обновите тег в compose-файлах, затем выполните команды выше.

Ваши данные сохраняются в томах Docker. **Всегда делайте [резервную копию](../../docs/backup-restore-ru.md) перед обновлением.**

## Пример

```bash
# Откройте чат-интерфейс в браузере
open http://localhost:3001
```

Или используйте API LiteLLM напрямую:

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
