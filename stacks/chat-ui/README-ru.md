[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Чат-интерфейс

Локальный аналог ChatGPT — веб-интерфейс для чата на основе локальной LLM с OpenAI-совместимым API-шлюзом.

**Сервисы:** Ollama (LLM) + LiteLLM (шлюз) + [AnythingLLM](https://github.com/Mintplex-Labs/anything-llm) (чат-интерфейс)

**Память:** ~5 ГБ RAM (с моделью 3B)

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
| **[AnythingLLM](https://github.com/Mintplex-Labs/anything-llm)** | Веб-интерфейс для чата с рабочими пространствами, RAG и агентами | `3001` |

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

AnythingLLM предварительно настроен для подключения к LiteLLM. API-ключ передаётся автоматически через Docker-том — ручная настройка не требуется.

**Примечание:** При первом запуске AnythingLLM может потребоваться несколько минут для готовности (ожидание API-ключа LiteLLM). Проверяйте прогресс командой `docker logs anythingllm`.

Откройте `http://<IP-сервера>:3001` в браузере — можно сразу начинать общаться. Провайдер LLM, базовый URL и модель уже предварительно настроены.

**Примечание:** Для развёртываний с доступом из интернета **настоятельно рекомендуется** использовать [обратный прокси](#использование-обратного-прокси) для добавления HTTPS. В этом случае также измените `"3001:3001/tcp"` на `"127.0.0.1:3001:3001/tcp"` и `"4000:4000/tcp"` на `"127.0.0.1:4000:4000/tcp"` в `docker-compose.yml`, чтобы предотвратить прямой доступ к незашифрованным портам. [Установите пароль](https://docs.useanything.com/features/security-and-access) для защиты AnythingLLM, особенно когда сервер доступен из интернета.

## GPU-ускорение (NVIDIA CUDA)

Для ускорения на GPU NVIDIA используйте CUDA-файл:

```bash
docker compose -f docker-compose.cuda.yml up -d
```

**Требования:** GPU NVIDIA, [драйвер NVIDIA](https://www.nvidia.com/en-us/drivers/) 535+, и установленный на хосте [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html). CUDA-образы поддерживают только `linux/amd64`.

## Запуск без Docker Compose

Если вы предпочитаете использовать команды `docker run` напрямую, сначала создайте общую сеть для взаимодействия сервисов:

```bash
docker network create ai-stack
```

Затем запустите каждый сервис в общей сети:

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
    mintplexlabs/anythingllm \
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

**Попробуйте в Playground:**

В панели администратора нажмите **Playground** в левом меню. Выберите локальную модель (например, `ollama/llama3.2:3b`) из выпадающего списка и начните общаться — это быстрый способ убедиться, что локальная языковая модель работает сквозным образом.

## Настройка

Каждый сервис можно настроить с помощью необязательного env-файла. Скопируйте пример env-файла из соответствующего репозитория, отредактируйте его и раскомментируйте монтирование тома в `docker-compose.yml`:

| Сервис | Env-файл | Репозиторий |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md) |

AnythingLLM настраивается через веб-интерфейс по адресу `http://<IP-сервера>:3001`. Вы можете изменить провайдера LLM, модель, движок эмбеддингов и другие параметры в разделе **Settings**.

**Совет:** Если вы также запускаете другие подстеки (например, [voice-pipeline](../voice-pipeline/README-ru.md), [rag-pipeline](../rag-pipeline/README-ru.md)), вы можете направить AnythingLLM на эти сервисы через страницу настроек — например, использовать `docker-whisper` для распознавания речи или `docker-embeddings` для векторных эмбеддингов.

Подробные параметры настройки, справку по API и управление моделями см. в документации каждого репозитория сервиса.

## Использование обратного прокси

Для развёртывания с выходом в интернет разместите обратный прокси перед AnythingLLM для обработки HTTPS-терминации. Сервер работает без HTTPS в локальной или доверенной сети, но HTTPS рекомендуется при открытом доступе к чат-интерфейсу из интернета.

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

## Обновление образов

Обновление всех сервисов до последних версий:

```bash
docker compose pull
docker compose up -d
```

Ваши данные сохраняются в томах Docker.

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