[English](backup-restore.md) | [简体中文](backup-restore-zh.md) | [繁體中文](backup-restore-zh-Hant.md) | [Русский](backup-restore-ru.md)

# Резервное копирование и восстановление

В этом руководстве описано, как создавать резервные копии и восстанавливать данные Docker AI Stack, включая API-ключи, веса моделей и конфигурации сервисов. **Всегда создавайте резервную копию перед обновлением образов.**

## Что хранится в томах

Каждый сервис хранит свои данные в именованном томе Docker:

| Том | Сервис | Содержимое |
|---|---|---|
| `ollama-data` | Ollama | Загруженные модели, API-ключ, конфигурация порта/сервера |
| `litellm-data` | LiteLLM | API-ключ, конфигурация прокси |
| `embeddings-data` | Embeddings | Кэш модели эмбеддингов |
| `whisper-data` | Whisper | Кэш модели Whisper |
| `kokoro-data` | Kokoro | Кэш модели/голосов TTS |
| `mcp-data` | MCP Gateway | API-ключ, конфигурация инструментов |

**Важно:** API-ключи для Ollama, LiteLLM и MCP Gateway генерируются автоматически при первом запуске и хранятся в этих томах. Если вы потеряете том, вы потеряете ключ. Подключённым клиентам потребуется обновить ключи.

**Примечание:** Тома `ollama-shared` и `mcp-shared` являются временными общими томами для автоматической передачи API-ключей между сервисами. Их не нужно резервировать — ключи уже хранятся в `ollama-data` и `mcp-data` соответственно и копируются заново при каждом запуске контейнера.

## Экспорт API-ключей

Перед любыми операциями обслуживания сохраните текущие API-ключи:

```bash
echo "=== API Keys ===" > ai-stack-keys.txt
echo "Ollama:  $(docker exec ollama ollama_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo "LiteLLM: $(docker exec litellm litellm_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo "MCP:     $(docker exec mcp mcp_manage --showkey 2>/dev/null | grep -v '^$')" >> ai-stack-keys.txt
echo ""
echo "Keys saved to ai-stack-keys.txt"
cat ai-stack-keys.txt
```

Храните этот файл в безопасном месте — он содержит учётные данные.

## Резервное копирование всех томов

Сначала остановите стек для обеспечения целостности данных:

```bash
# Остановить сервисы
docker compose down

# Создать директорию для резервных копий
mkdir -p backups

# Создать резервные копии всех томов
for vol in ollama-data litellm-data embeddings-data whisper-data kokoro-data mcp-data; do
  if docker volume inspect "$vol" >/dev/null 2>&1; then
    echo "Backing up $vol..."
    docker run --rm \
      -v "${vol}:/source:ro" \
      -v "$(pwd)/backups:/backup" \
      alpine tar czf "/backup/${vol}.tar.gz" -C /source .
  else
    echo "Skipping $vol (not found)"
  fi
done

echo "Backup complete. Files:"
ls -lh backups/*.tar.gz
```

### Резервное копирование одного тома

```bash
docker compose down

docker run --rm \
  -v ollama-data:/source:ro \
  -v "$(pwd)/backups:/backup" \
  alpine tar czf /backup/ollama-data.tar.gz -C /source .
```

### Облегчённые стеки

Если вы используете облегчённый стек (например, chat-only), существуют только соответствующие тома. Цикл резервного копирования выше автоматически пропускает отсутствующие тома.

## Восстановление всех томов

**Внимание:** Восстановление перезаписывает все существующие данные в целевых томах, включая API-ключи. Клиентам, использующим старые ключи, потребуется обновление.

```bash
# Остановить сервисы
docker compose down

# Восстановить все тома из резервных копий
for vol in ollama-data litellm-data embeddings-data whisper-data kokoro-data mcp-data; do
  backup_file="backups/${vol}.tar.gz"
  if [ -f "$backup_file" ]; then
    echo "Restoring $vol..."
    # Создать том, если он не существует
    docker volume create "$vol" >/dev/null 2>&1 || true
    # Очистить существующие данные и восстановить
    docker run --rm \
      -v "${vol}:/target" \
      -v "$(pwd)/backups:/backup:ro" \
      alpine sh -c "rm -rf /target/* /target/.[!.]* 2>/dev/null; tar xzf /backup/${vol}.tar.gz -C /target"
  else
    echo "Skipping $vol (no backup file found)"
  fi
done

# Перезапустить сервисы
docker compose up -d

echo "Restore complete. Verify with: ./stack-check.sh"
```

### Восстановление одного тома

**Внимание:** Эта операция перезаписывает все существующие данные в целевом томе.

```bash
docker compose down

docker volume create ollama-data >/dev/null 2>&1 || true
docker run --rm \
  -v ollama-data:/target \
  -v "$(pwd)/backups:/backup:ro" \
  alpine sh -c "rm -rf /target/* /target/.[!.]* 2>/dev/null; tar xzf /backup/ollama-data.tar.gz -C /target"

docker compose up -d
```

## Миграция на новый сервер

1. **На старом сервере:** Создайте резервные копии всех томов и экспортируйте ключи (см. выше)
2. **Перенос файлов:** Скопируйте директорию `backups/` и `ai-stack-keys.txt` на новый сервер
3. **На новом сервере:**

```bash
git clone https://github.com/hwdsl2/docker-ai-stack
cd docker-ai-stack

# Скопировать файлы резервных копий
cp -r /path/to/backups ./backups

# Восстановить тома (создаются автоматически)
for vol in ollama-data litellm-data embeddings-data whisper-data kokoro-data mcp-data; do
  backup_file="backups/${vol}.tar.gz"
  if [ -f "$backup_file" ]; then
    echo "Restoring $vol..."
    docker volume create "$vol" >/dev/null 2>&1 || true
    docker run --rm \
      -v "${vol}:/target" \
      -v "$(pwd)/backups:/backup:ro" \
      alpine sh -c "tar xzf /backup/${vol}.tar.gz -C /target"
  fi
done

# Запустить стек
docker compose up -d

# Проверить
./stack-check.sh
```

Ваши API-ключи, модели и конфигурация будут сохранены. Клиенты могут подключаться, используя те же ключи.

## Контрольный список перед обновлением

Перед выполнением `docker compose pull && docker compose up -d`:

1. **Экспортируйте API-ключи** — сохраните в файл (см. выше)
2. **Создайте резервные копии томов** — как минимум `ollama-data`, `litellm-data` и `mcp-data`
3. **Загрузите новые образы** — `docker compose pull`
4. **Запустите обновлённый стек** — `docker compose up -d`
5. **Выполните проверку работоспособности** — `./stack-check.sh`
6. **Проверьте API-ключи** — убедитесь, что ключи не изменились (они должны сохраниться после обновления)

Если после обновления возникли проблемы:

```bash
# Остановить неработающий стек
docker compose down

# Восстановить из резервной копии
# (следуйте шагам восстановления выше)

# При необходимости зафиксировать образы на предыдущей рабочей версии
# Отредактируйте docker-compose.yml, указав конкретные теги образов
docker compose up -d
```

## Примечания

- **Веса моделей** (в `ollama-data`) могут быть большими (несколько ГБ на модель). Создавайте резервную копию только если повторная загрузка затруднительна (медленный интернет, модели с пользовательской дообучкой).
- **Кэш моделей** (`embeddings-data`, `whisper-data`, `kokoro-data`) загружается автоматически при первом запуске. Если пропускная способность не является проблемой, резервное копирование можно пропустить — они будут загружены повторно.
- **Критические тома**, которые всегда следует копировать: `ollama-data` (если есть пользовательские модели), `litellm-data`, `mcp-data` (содержат API-ключи и конфигурацию).
- Резервные копии — это стандартные архивы `.tar.gz`. Просмотреть содержимое можно командой: `tar tzf backups/ollama-data.tar.gz`
