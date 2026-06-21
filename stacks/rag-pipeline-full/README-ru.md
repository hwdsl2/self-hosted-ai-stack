[English](README.md) | [简体中文](README-zh.md) | [繁體中文](README-zh-Hant.md) | [Русский](README-ru.md)

# RAG-конвейер (полный)

Разбор документов, создание эмбеддингов для семантического поиска и ответы на вопросы с помощью локальной LLM.

**Сервисы:** Ollama (LLM) + LiteLLM (шлюз) + Embeddings + Docling (разбор документов)

**Память:** ~6 ГБ RAM (с моделью 3B)

**Платформы:** `linux/amd64`, `linux/arm64`

## Архитектура

```mermaid
graph LR
    D["📄 Документы<br/>(PDF, DOCX и др.)"] -->|разбор| DC["Docling<br/>(документ → текст)"]
    DC -->|эмбеддинг| E["Embeddings<br/>(текст → векторы)"]
    E -->|хранение| VDB["pgvector<br/>(в общем Postgres)"]
    VDB -->|контекст| L["LiteLLM<br/>(AI-шлюз)"]
    L -->|маршрутизация| O["Ollama<br/>(локальная LLM)"]
```

## Сервисы

| Сервис | Назначение | Порт по умолчанию |
|---|---|---|
| **[Ollama (LLM)](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md)** | Запуск локальных LLM-моделей (llama3, qwen, mistral и др.) | `11434` |
| **[LiteLLM](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md)** | AI-шлюз с панелью администратора — маршрутизация запросов к Ollama и 100+ провайдерам | `4000` |
| **[Embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-ru.md)** | Преобразование текста в векторы для семантического поиска и RAG | `8000` |
| **[Docling](https://github.com/hwdsl2/docker-docling/blob/main/README-ru.md)** | Конвертирует документы (PDF, DOCX и др.) в структурированный текст/Markdown | `5001` |

## Быстрый старт

```bash
git clone https://github.com/hwdsl2/self-hosted-ai-stack
cd self-hosted-ai-stack/stacks/rag-pipeline-full
docker compose up -d
```

**Загрузка модели** (обязательно перед отправкой LLM-запросов):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
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

> **Примечание:** При ручном использовании `docker run` дождитесь готовности каждой зависимости перед запуском сервисов, которые её используют (например, дождитесь PostgreSQL и других зависимостей, например Ollama или MCP, перед запуском LiteLLM; если используется AnythingLLM, дождитесь готовности LiteLLM перед его запуском). Для production-сред или общих Docker-сетей измените стандартный пароль PostgreSQL перед первым запуском и обновите все соответствующие строки подключения.

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
    hwdsl2/litellm-server

# Embeddings
docker run -d --name embeddings --restart always \
    --network ai-stack \
    -p 127.0.0.1:8000:8000 \
    -v embeddings-data:/var/lib/embeddings \
    hwdsl2/embeddings-server

# Docling (разбор документов)
docker run -d --name docling --restart always \
    --network ai-stack \
    -p 127.0.0.1:5001:5001 \
    -v docling-data:/var/lib/docling \
    hwdsl2/docling-server
```

**Примечание:** Общая сеть позволяет сервисам обращаться друг к другу по имени контейнера (например, LiteLLM подключается к Ollama через `http://ollama:11434`).

**Загрузка модели** (обязательно перед отправкой LLM-запросов):

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

## Проверка развёртывания

После запуска стека можно проверить, что все сервисы работают корректно:

```bash
# Запустите из корневой директории self-hosted-ai-stack
../../stack-check.sh
```

**Доступ к панели администратора LiteLLM:**

Откройте `http://<server-ip>:4000/ui` в браузере. Войдите с именем пользователя `admin` и вашим мастер-ключом LiteLLM в качестве пароля. Панель администратора предоставляет управление виртуальными ключами, отслеживание расходов и настройку моделей.

> **Примечание:** Для развёртываний с выходом в интернет настоятельно рекомендуется использовать [обратный прокси](#развёртывание-с-доступом-из-интернета) для добавления HTTPS. В этом случае также измените `"4000:4000/tcp"` на `"127.0.0.1:4000:4000/tcp"` в `docker-compose.yml`, чтобы предотвратить прямой доступ к незашифрованному порту.

> **Совет:** В панели администратора нажмите **Playground** в левом меню. Выберите локальную модель (например, `ollama/llama3.2:3b`) из выпадающего списка и начните общаться — это быстрый способ убедиться, что локальная языковая модель работает сквозным образом.

## Настройка

Каждый сервис можно настроить с помощью опционального env-файла. Скопируйте пример env-файла из соответствующего репозитория, отредактируйте его и раскомментируйте монтирование тома в `docker-compose.yml`:

| Сервис | Env-файл | Репозиторий |
|---|---|---|
| Ollama | `ollama.env` | [docker-ollama](https://github.com/hwdsl2/docker-ollama/blob/main/README-ru.md) |
| LiteLLM | `litellm.env` | [docker-litellm](https://github.com/hwdsl2/docker-litellm/blob/main/README-ru.md) |
| Embeddings | `embed.env` | [docker-embeddings](https://github.com/hwdsl2/docker-embeddings/blob/main/README-ru.md) |
| Docling | `docling.env` | [docker-docling](https://github.com/hwdsl2/docker-docling/blob/main/README-ru.md) |

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
```

`git pull` обновляет этот репозиторий, включая compose-файлы или вспомогательные скрипты, используемые этим подстеком; `docker compose pull` обновляет образы сервисов.

Ваши данные сохраняются в Docker-томах. **Всегда делайте [резервную копию](../../docs/backup-restore-ru.md) перед обновлением.**

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

## Пример

```bash
LITELLM_KEY=$(docker exec litellm litellm_manage --getkey)
EMBED_KEY=$(docker exec embeddings embed_manage --getkey)
DOCLING_KEY=$(docker exec docling docling_manage --getkey)

# Шаг 1: Конвертация PDF в Markdown с помощью Docling
curl -s -X POST http://localhost:5001/v1/convert/file \
    -H "X-Api-Key: $DOCLING_KEY" \
    -F "file=@document.pdf" \
    | jq -r '.document.md_content' > extracted.md

# Шаг 2: Создание эмбеддинга извлечённого текста
curl -s http://localhost:8000/v1/embeddings \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $EMBED_KEY" \
    -d '{"input": "Docker simplifies deployment by packaging apps in containers.", "model": "text-embedding-ada-002"}' \
    | jq '.data[0].embedding'
# → Сохраните вектор вместе с исходным текстом в pgvector (входит в Postgres этого стека) или в другую векторную БД, например Qdrant или Chroma.

# Шаг 3: Запрос — создайте эмбеддинг вопроса, извлеките контекст из векторной БД, затем спросите LLM
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
