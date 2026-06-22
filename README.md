# MK2 — Video Scout / Марк 2

**MK2** (Video Scout / Марк 2) — это сервис для автоматического сбора и обновления статистики по видеороликам клиентов в Google Sheets.

> **Ветка MK2_1** — объединённая версия из двух репозиториев (`Parser-for-tktk-analysis` + `MK2-parser`).
> Включает все функции: Docker, cron, батчинг, конкурентный анализ.

## Как это работает

1. **Конфигурация клиентов** загружается из мастер-таблицы Google Sheets через `CLIENTS_SHEET_ID` или из локального YAML-файла (`clients.yaml`)
2. Для каждого клиента парсер проходит по аккаунтам соцсетей и собирает:
   - 📹 Видеоролики
   - 👁 Просмотры
   - ❤️ Лайки
   - 💬 Комментарии
3. Результаты пишутся в лист **«База Данных видео по проекту»** в клиентской таблице (один `batchGet` + один `batchUpdate` на клиента)
4. **Авто-обновление:** воркер `video_refresh_worker.py` обновляет метрики для старых видео по расписанию (3 → 7 → 14 → 21 → 31 день)
5. **Чекбокс-фильтр:** колонка Z в мастер-таблице позволяет включать/отключать парсинг конкретного клиента

## Структура проекта

```
mk2/
├── workers/
│   ├── common.py                        # Google Sheets auth, загрузка клиентов
│   ├── project_content_daily_worker.py  # Точка запуска: ежедневный сбор новых видео
│   └── video_refresh_worker.py          # Обновление метрик для старых видео
├── services/
│   ├── project_content_pipeline.py      # Основная логика: Apify + нативные API
│   ├── video_refresh.py                 # Обновление метрик (YouTube, VK, Apify)
│   ├── video_refresh_scheduler.py       # Расписание рефрешей
│   ├── helpers.py                       # Утилиты (парсинг дат, чисел, текста)
│   ├── competitor_pipeline.py           # Утилиты для конкурентного анализа
│   └── downloader.py                    # Apify token
├── examples/
│   ├── clients.example.yaml             # Пример конфига клиента
│   └── env.example                      # Пример переменных окружения
├── config/                              # Директория для конфигов (service_account.json, clients.yaml)
├── db.py                                # Трекинг затрат API
├── test_connection.py                   # Проверка подключения к таблицам
├── find_nomos.py                        # Поиск клиента НОМОС
├── cron-daily.sh                        # Cron-скрипт для ежедневного запуска
├── Dockerfile                           # Docker-образ (Python 3.12 + Playwright)
├── docker-compose.yml                   # Docker Compose конфигурация
├── .dockerignore
├── .env.example
├── requirements.txt
└── README.md
```

## Установка

```bash
git clone https://github.com/DEVASTATOR1349/MK2-parser.git
cd mk2
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Отредактируй .env — вставь токены
```

## Docker

```bash
docker compose up --build
```

Образ включает Playwright + Chromium для парсинга платформ через headless-браузер.

## Настройка .env

```env
# Service account для Google Sheets API
GOOGLE_APPLICATION_CREDENTIALS=/app/config/service_account.json

# ИЛИ JSON ключа (если файл неудобно хранить)
# GOOGLE_SERVICE_ACCOUNT_JSON={"type":"service_account",...}

# Apify — для Instagram, TikTok, Facebook
APIFY_API_TOKEN=apify_api_...

# YouTube Data API v3
YOUTUBE_API_KEY=...

# VK API
VK_API_TOKEN=...

# Мастер-таблица Google Sheets с настройками клиентов
CLIENTS_SHEET_ID=1E4TmhKLulzI9y7ag3yJJPIt8LmL_DGm1kzjuOFgOxMM

# Дополнительный env-файл с API-ключами (опционально)
# SCOUT_EXTRA_ENV_FILE=/path/to/api-keys.env

# Apify акторы (можно переопределить)
# APIFY_INSTAGRAM_ACTOR_ID=shu8hvrXbJbY3Eb9W
# APIFY_INSTAGRAM_REEL_ACTOR_ID=apify~instagram-reel-scraper
# SCOUT_TIKTOK_APIFY_ACTOR_ID=clockworks~tiktok-profile-scraper
# SCOUT_FACEBOOK_PAGE_APIFY_ACTOR_ID=apify~facebook-pages-scraper

# Лимиты результатов
# SCOUT_PROJECT_INSTAGRAM_RESULTS_LIMIT=250
# SCOUT_PROJECT_YOUTUBE_RESULTS_LIMIT=250
# SCOUT_PROJECT_TIKTOK_RESULTS_LIMIT=200
# SCOUT_PROJECT_VK_RESULTS_LIMIT=500
# SCOUT_PROJECT_RUTUBE_RESULTS_LIMIT=500
# SCOUT_PROJECT_MAX_APIFY_RUNS_PER_CYCLE=1
```

## Запуск

### Проверка подключения

```bash
python test_connection.py
```

### Ежедневный сбор новых видео

```bash
# Разовый прогон для всех клиентов
python workers/project_content_daily_worker.py --once

# Только для одного клиента
python workers/project_content_daily_worker.py --once --client client_1

# Тестовый режим (мало результатов)
python workers/project_content_daily_worker.py --once --test-limit 3

# Только одна платформа
python workers/project_content_daily_worker.py --once --platform youtube

# С ограничением количества Apify-запусков
python workers/project_content_daily_worker.py --once --max-apify-runs 5
```

### Обновление метрик для существующих видео

```bash
# Разовый прогон (максимум 50 видео для обновления)
python workers/video_refresh_worker.py --once

# Тестовый режим (всего 2 видео)
python workers/video_refresh_worker.py --once --max-rows 2

# Только для одного клиента
python workers/video_refresh_worker.py --once --client client_1
```

## Формат данных

### «База Данных видео по проекту» (клиентская таблица)

| Колонка | Поле | Описание |
|---------|------|----------|
| A | Дата публикации | Когда вышло видео |
| B | Ссылка на аккаунт | Аккаунт-источник |
| C | Платформа | Instagram / YouTube / TikTok / VK / Facebook / Rutube |
| D | Ссылка на ролик | Прямая ссылка |
| E | Подпись ролика | Текст описания |
| F | Первый комментарий | Топ-комментарий |
| G | Последние комментарии | Свежие комментарии |
| H | Хештеги | Извлечённые хештеги |
| I | Упоминания | @упоминания |
| J | Дочерние посты | Связанные посты |
| K | Комментарии | Количество |
| L | Лайки | Количество |
| M | Просмотры (play) | Для YouTube / VK |
| N | Просмотры (view) | Для Instagram / TikTok / Facebook |
| O | Длительность, сек | Длительность видео |
| P | Повторный сбор метрик | Флаг пересбора |
| Q | Чек через сутки | Дата проверки через 1 день |
| R | Чек через месяц | Дата проверки через 30 дней |
| S | Дата первого импорта | Когда видео впервые попало в базу |
| T | Количество сборов | Сколько раз парсер обновлял метрики |
| U | Последний рефреш | Дата последнего обновления |
| V | Следующий рефреш | Когда планируется следующее обновление |
| W | Статус | OK / ERROR / STOPPED |
| Z | Чекбокс | Вкл/выкл парсинг клиента (в мастер-таблице) |

### «История видео» (автоматически создаётся)

Хранит снимки метрик по каждому видео на каждую дату рефреша.

## Поддерживаемые платформы

| Платформа | Метод сбора | Обновление метрик | Статус |
|-----------|------------|-------------------|--------|
| Instagram | Apify (`instagram-reel-scraper`) | Apify | ✅ |
| YouTube | YouTube Data API v3 | YouTube Data API (до 50 видео/запрос) | ✅ |
| TikTok | Apify (`tiktok-profile-scraper`) | Apify | ✅ (отключён по умолчанию) |
| Facebook | Apify (`facebook-pages-scraper`) | Apify | ✅ |
| VK | VK API | VK API (до 200 видео/запрос) | ✅ |
| Rutube | Rutube Public API | Rutube Public API | ✅ |
| OK.ru | HTML scrape | HTML scrape | 🧪 |
| Pinterest | JSON-LD scrape | JSON-LD scrape | 🧪 |
| Дзен | — | — | ❌ |
| Likee | — | — | ❌ |

### Платформы отключены по умолчанию

`DISABLED_PROJECT_PLATFORMS = {"pinterest", "likee", "dzen", "ok", "tiktok"}`

TikTok отключён для экономии Apify-кредитов. Включить — убрать из `DISABLED_PROJECT_PLATFORMS` в `project_content_pipeline.py`.

## Cron (рекомендуемое расписание)

```cron
# Ежедневно в 06:00 МСК — сбор новых видео
0 3 * * * cd /path/to/mk2 && /path/to/venv/bin/python workers/project_content_daily_worker.py --once >> logs/daily.log 2>&1

# Каждые 2 часа — обновление метрик для старых видео
0 */2 * * * cd /path/to/mk2 && /path/to/venv/bin/python workers/video_refresh_worker.py --once >> logs/refresh.log 2>&1
```

Или используй готовый `cron-daily.sh`.

## Зависимости от внешних сервисов

- **Google Sheets API** — чтение/запись таблиц (сервисный аккаунт)
- **Apify** — парсинг Instagram, TikTok, Facebook (требует токен)
- **YouTube Data API v3** — чтение метрик YouTube (бесплатный лимит: 10 000 единиц/сутки)
- **VK API** — чтение метрик VK
- **Rutube API** — чтение метрик Rutube (публичный, без ключа)
- **Playwright** — headless-браузер для платформ без API

## Лицензия

MIT
