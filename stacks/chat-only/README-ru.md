[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# Только чат

Минимальная локальная настройка для чата — локальная LLM с OpenAI-совместимым API-шлюзом.

**Сервисы:** Ollama (LLM) + LiteLLM (шлюз)

**Память:** ~4.5 ГБ RAM (с моделью 3B)

**Платформы:** `linux/amd64`, `linux/arm64`

## Архитектура

```mermaid
graph LR
    C["💬 AI-клиент"] -->|чат| L["LiteLLM<br/>(AI-шлюз)"]
    L -->|маршрутизация| O["Ollama<br/>(локальная LLM)"]
```

## Сервисы

| Сервис | Назначение | Порт по умолчанию |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md)** | Запускает локальные LLM-модели (llama3, qwen, mistral и др.) | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md)** | AI-шлюз с панелью администратора — маршрутизирует запросы к Ollama и 100+ провайдерам | `4000` |

> **Примечание:** Лёгкие подстеки используют общие стандартные имена контейнеров, порты и имена Docker volumes. С compose-файлами по умолчанию запускайте только один вариант подстека за раз; перед переключением на другой вариант остановите текущий.

Доступ по умолчанию:

- LiteLLM опубликован на порту хоста `4000`.
- Ollama доступен только внутри Docker-сети; для доступа с хоста или из браузера используйте LiteLLM.

## Быстрый старт

**Требования:**

- Linux-сервер (локальный или облачный) с установленным Docker
- Достаточно ОЗУ для этого подстека и выбранной модели (см. оценку памяти выше)
- Для крупных LLM-моделей (8B+) рекомендуется 16 ГБ ОЗУ или больше

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack/stacks/chat-only
docker compose up -d
```

**Загрузка модели** (обязательно перед отправкой LLM-запросов):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

Запустите проверку работоспособности, чтобы убедиться, что сервисы работают:

```bash
# Из каталога этого подстека:
../../stack-check.sh

# Или из корня репозитория:
# ./stack-check.sh
```

> **Совет:** При первом запуске сервисам может потребоваться несколько минут для инициализации. Если какие-либо проверки не пройдены, подождите и запустите `../../stack-check.sh` снова. Используйте `docker compose logs` для проверки прогресса.

**Получите master key LiteLLM** (используется для входа в Admin UI и для прямых LLM API-запросов):

```bash
docker exec litellm litellm_manage --showkey
```

**Откройте Admin UI LiteLLM:**

Откройте `http://<server-ip>:4000/ui` в браузере. Войдите с именем пользователя `admin` и master key LiteLLM в качестве пароля. UI предоставляет управление виртуальными ключами, учёт расходов и настройку моделей.

> **Совет:** В Admin UI нажмите **Playground** в левом меню. Выберите локальную модель (например, `ollama-chat/llama3.2:3b`) из списка и начните чат — это быстрый способ проверить локальную LLM end-to-end.

**Остановить подстек:**

```bash
# Остановить и удалить контейнеры (данные сохраняются в Docker volumes)
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
    hwdsl2/litellm-server
```

**Примечание:** Общая сеть позволяет сервисам обращаться друг к другу по имени контейнера (например, LiteLLM подключается к Ollama через `http://ollama:11434`).

**Загрузка модели** (обязательно перед отправкой LLM-запросов):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## Счётчики использования

Этот стек участвует в анонимном агрегированном подсчёте загрузок GitHub release assets проекта. Запустите с `AI_STACK_DISABLE_USAGE_COUNTS=1 docker compose up -d`, чтобы отключить их; подробнее см. [Счётчики использования](../../README-ru.md#счётчики-использования).

## Настройка

Каждый сервис можно настроить с помощью опционального env-файла. Скопируйте пример env-файла из соответствующего репозитория, отредактируйте его и раскомментируйте монтирование тома в `docker-compose.yml`:

| Сервис | Env-файл | Репозиторий |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md) |

Подробные параметры настройки, справочник API и управление моделями описаны в документации каждого сервиса.

## Развёртывание с доступом из интернета

По умолчанию все сервисы слушают по незашифрованному HTTP. Для развёртываний с доступом из интернета установите обратный прокси (например, [Caddy](https://caddyserver.com/), Nginx или Traefik) перед стеком для обеспечения HTTPS. Каждый репозиторий сервиса содержит подробное [руководство по обратному прокси](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md#использование-обратного-прокси) с примерами для Caddy и nginx.

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

Ваши данные сохраняются в Docker-томах. **Всегда делайте [резервную копию](../../docs/backup-restore-ru.md) перед обновлением.**

## Пример

> **Примечание:** В примерах ниже используется `jq` для форматирования JSON-ответов. Установите его, если он ещё не доступен.

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
