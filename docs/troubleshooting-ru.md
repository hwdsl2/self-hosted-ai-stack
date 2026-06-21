[English](troubleshooting.md) | [简体中文](troubleshooting-zh.md) | [繁體中文](troubleshooting-zh-Hant.md) | [Русский](troubleshooting-ru.md)

# Устранение неполадок

Это руководство помогает диагностировать проблемы Self-Hosted AI Stack перед изменением конфигурации или созданием issue.

## Быстрая диагностика

Начните с этих проверок:

```bash
# Показать состояние контейнеров и опубликованные порты
docker compose ps

# Запустить проверку работоспособности стека
./stack-check.sh

# Посмотреть последние журналы одного сервиса
docker compose logs --tail=100 <service>
```

Если стек был запущен с несколькими compose-файлами, используйте те же файлы для диагностических команд:

```bash
docker compose -f docker-compose.yml -f docker-compose.proxy.yml ps
docker compose -f docker-compose.cuda.yml -f docker-compose.proxy.yml logs --tail=100 litellm
```

Для Podman `stack-check.sh` автоматически определяет движок. Его также можно указать явно:

```bash
CONTAINER_ENGINE=podman ./stack-check.sh
```

## Запуск и готовность

При первом запуске сервисам может потребоваться несколько минут для инициализации. Загрузка моделей, запуск базы данных и инициализация AnythingLLM могут задерживать готовность.

Если `./stack-check.sh` завершается ошибкой сразу после запуска:

1. Подождите несколько минут.
2. Запустите `./stack-check.sh` снова.
3. Проверьте журналы сервиса, который не прошел проверку.

Полезные команды для журналов сервисов:

```bash
docker compose logs --tail=100 ollama
docker compose logs --tail=100 litellm
docker compose logs --tail=100 mcp
docker compose logs --tail=100 anythingllm
```

LiteLLM зависит от Ollama, MCP Gateway и PostgreSQL. AnythingLLM зависит от LiteLLM. Если зависимость еще запускается, нижестоящие сервисы могут быть временно не готовы.

## Проблемы Ollama и локальных моделей

Стек запускает Ollama автоматически, но перед отправкой LLM-запросов нужно загрузить хотя бы одну модель:

```bash
docker exec ollama ollama_manage --pull llama3.2:3b
```

Список загруженных моделей:

```bash
docker exec ollama ollama_manage --listmodels
```

Если LiteLLM или AnythingLLM сообщает об ошибках модели, сначала убедитесь, что модель есть в Ollama и что `./stack-check.sh` показывает успешную проверку маршрутизации LiteLLM.

По вопросам, связанным с образом Ollama, используйте репозиторий `docker-ollama`. Если проблема относится к поведению upstream Ollama и не связана с этим Docker-образом, используйте issue tracker upstream Ollama.

## Проблемы LiteLLM

LiteLLM по умолчанию доступен на порту `4000`. Административный интерфейс доступен по адресу:

```text
http://<server-ip>:4000/ui
```

Используйте имя пользователя `admin` и master key LiteLLM в качестве пароля.

Показать master key LiteLLM:

```bash
docker exec litellm litellm_manage --showkey
```

Проверить endpoint работоспособности LiteLLM:

```bash
curl http://localhost:4000/health/liveliness
```

Если локальные модели Ollama не работают через LiteLLM:

- Убедитесь, что модель Ollama загружена.
- Убедитесь, что в compose-файле или env-файле есть `LITELLM_OLLAMA_BASE_URL=http://ollama:11434`.
- Проверьте `docker compose logs --tail=100 litellm`.
- Запустите `./stack-check.sh` и проверьте тест маршрутизации LiteLLM.

Compose-файлы автоматически передают API-ключи Ollama и MCP в LiteLLM через Docker-тома. Не удаляйте `ollama-data`, `mcp-data` или `litellm-data`, если у вас нет резервной копии.

## Проблемы MCP Gateway

MCP Gateway работает внутри Docker-сети на порту `3000`. В основном compose-файле этот порт по умолчанию не публикуется на хост.

Показать API-ключ MCP Gateway:

```bash
docker exec mcp mcp_manage --showkey
```

Проверить endpoint работоспособности изнутри контейнера:

```bash
docker exec mcp curl -sf http://127.0.0.1:3000/health
```

Если внешнему MCP-клиенту нужен прямой доступ, раскомментируйте сопоставление порта `3000:3000` в `docker-compose.yml`, затем перезапустите сервис. Для доступа из интернета размещайте его за HTTPS и храните API-ключ в секрете.

## Проблемы AnythingLLM

AnythingLLM по умолчанию доступен на порту `3001`:

```text
http://<server-ip>:3001
```

При первом запуске создается случайный пароль администратора, который сохраняется в томе `anythingllm-data`. Получить его можно так:

```bash
docker exec anythingllm cat /app/server/storage/.initial_admin_password
```

Или проверьте журналы первого запуска:

```bash
docker compose logs anythingllm | grep -A4 "FIRST RUN"
```

Если AnythingLLM не может подключиться к локальной модели:

- Убедитесь, что LiteLLM доступен внутри Docker-сети по адресу `http://litellm:4000/v1`.
- Убедитесь, что модель `ollama/llama3.2:3b` существует, или настройте AnythingLLM на существующую модель.
- Проверьте `docker compose logs --tail=100 anythingllm`.

Если вы изменили пароль AnythingLLM в Settings, `.initial_admin_password` может больше не совпадать с текущим паролем. Перед обновлениями или миграцией сделайте резервную копию `anythingllm-data`.

## Опциональные сервисы

В полном compose-файле Embeddings и Whisper включены по умолчанию. Kokoro, Docling и WhisperLive закомментированы для уменьшения потребления памяти.

Чтобы включить закомментированный сервис:

1. Раскомментируйте сервис в `docker-compose.yml` или `docker-compose.cuda.yml`.
2. Раскомментируйте его именованный том внизу файла.
3. Добавьте или смонтируйте env-файл сервиса, если нужны пользовательские настройки.
4. Запустите `docker compose up -d`.

Документация сервисов:

| Сервис | Репозиторий |
|---|---|
| Ollama | https://github.com/hwdsl2/docker-ollama |
| LiteLLM | https://github.com/hwdsl2/docker-litellm |
| Embeddings | https://github.com/hwdsl2/docker-embeddings |
| Whisper | https://github.com/hwdsl2/docker-whisper |
| WhisperLive | https://github.com/hwdsl2/docker-whisper-live |
| Kokoro | https://github.com/hwdsl2/docker-kokoro |
| MCP Gateway | https://github.com/hwdsl2/docker-mcp-gateway |
| Docling | https://github.com/hwdsl2/docker-docling |

## GPU и CUDA

Для ускорения NVIDIA GPU запустите CUDA compose-файл:

```bash
docker compose -f docker-compose.cuda.yml up -d
```

Требования:

- NVIDIA GPU
- Драйвер NVIDIA
- NVIDIA Container Toolkit
- Хост `linux/amd64` для CUDA-образов

Если GPU-ускорение не используется:

- Убедитесь, что запущен `docker-compose.cuda.yml`, а не `docker-compose.yml`.
- Проверьте `docker compose logs --tail=100 ollama` и, если Whisper включен, `docker compose logs --tail=100 whisper`.
- Убедитесь, что хост может запускать GPU-контейнеры через NVIDIA Container Toolkit.

Для Podman блок GPU `deploy.resources` из Compose не используется. Следуйте инструкциям Podman CDI в README.

## Reverse proxy и публичные развертывания

Стек включает Caddy overlay для HTTPS:

```bash
DOMAIN=chat.example.com ACME_EMAIL=you@example.com \
  docker compose -f docker-compose.yml -f docker-compose.proxy.yml up -d
```

В режиме proxy Caddy является публичным слушателем на портах `80` и `443`. Прямые порты AnythingLLM и LiteLLM привязываются к `127.0.0.1`.

Проверить журналы Caddy:

```bash
docker logs ai-stack-caddy
```

Если Caddy не может получить сертификат, проверьте:

- DNS-запись `A`/`AAAA` указывает на этот сервер.
- Порты `80/tcp` и `443/tcp` доступны из интернета.
- Никакой другой сервис не использует порты `80` или `443`.
- Значения `DOMAIN` и `ACME_EMAIL` корректны.

При публикации опциональных сервисов в интернет используйте сгенерированные API-ключи, если они есть. Для существующих развёртываний без ключей сначала задайте API-ключи через соответствующие env-файлы или поместите сервисы за proxy-аутентификацию.

## Тома, резервные копии и обновления

API-ключи, кэши моделей, история чатов, конфигурация сервисов и состояние сертификатов Caddy хранятся в Docker-томах. Перед обновлениями, миграцией или разрушительной очисткой сделайте резервную копию.

См. полное руководство по резервному копированию:

- [Резервное копирование и восстановление](backup-restore-ru.md)

Не удаляйте тома при диагностике, если у вас нет актуальной резервной копии. Удаление томов может удалить API-ключи, кэши моделей, данные AnythingLLM, конфигурацию LiteLLM, настройки MCP Gateway, ключи опциональных сервисов и сертификаты Caddy.

После обновления образов выполните:

```bash
docker compose pull
docker compose up -d
./stack-check.sh
```

## Куда отправлять issue

Создавайте issue в `self-hosted-ai-stack` для:

- Проблем compose-файлов
- Проблем связей между сервисами
- Проблем запуска стека или проверки работоспособности
- Проблем Caddy overlay в этом репозитории
- Проблем документации в этом репозитории

Создавайте issue в репозитории отдельного сервиса для:

- Поведения, специфичного для образа
- Env-опций конкретного сервиса
- API-поведения конкретного сервиса
- Загрузки моделей или кэша конкретного сервиса

Если проблема находится в самом upstream-приложении, а не в Docker-образе или связях стека, создавайте issue upstream.

## Что включить в issue

Укажите:

- ОС и архитектуру хоста
- Версию Docker или Podman
- Использованные compose-файлы, например `docker-compose.yml` или `docker-compose.cuda.yml`
- Режим CPU или GPU
- Вывод `docker compose ps`
- Вывод `./stack-check.sh`
- Релевантные журналы, например `docker compose logs --tail=100 litellm`
- Пользовательские env-файлы или изменения compose, с удаленными секретами

Перед публикацией удалите API-ключи, пароли, ключи провайдеров, токены, публичные URL с приватными путями и любое чувствительное содержимое журналов.
