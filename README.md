# MK2 — Парсер статистики видеороликов

**MK2** (Video Scout / Марк 2) — это сервис для автоматического сбора и обновления статистики по видеороликам клиентов в Google Sheets.

## Как это работает

1. **Конфигурация клиентов** загружается из мастер-таблицы (Google Sheets) через `CLIENTS_SHEET_ID` или из локального YAML-файла
2. Для каждого клиента парсер проходит по аккаунтам соцсетей (Instagram, YouTube, TikTok, Facebook, VK, Rutube) и собирает:
   - 📹 Видеоролики
   - 👁 Просмотры
   - ❤️ Лайки
   - 💬 Комментарии
3. Результаты пишутся в лист **«База Данных видео по проекту»** в клиентской таблице
4. **Авто-обновление:** воркер `video_refresh_worker.py` периодически обновляет метрики для старых видео по расписанию (3 → 7 → 14 → 21 → 31 день)

## Структура проекта

```
mk2/
├── workers/
│   ├── common.py                        # Google Sheets auth, загрузка клиентов
│   ├── project_content_daily_worker.py  # Ежедневный сбор новых видео
│   └── video_refresh_worker.py          # Обновление метрик для старых видео
├── services/
│   ├── project_content_pipeline.py      # Основная логика: Apify + нативные API
│   ├── video_refresh.py                 # Обновление метрик (YouTube, VK, Apify)
│   ├── video_refresh_scheduler.py       # Расписание рефрешей
│   ├── competitor_pipeline.py           # Утилиты (форматирование, парсинг дат)
│   └── downloader.py                    # Apify токен
├── db.py                                # Трекинг затрат API
├── .env.example                         # Пример конфигурации
├── requirements.txt
└── README.md
```

## Установка

```bash
git clone <repo-url>
cd mk2
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Отредактируй .env — вставь токены
```

## Настройка .env

```env
# Service account для Google Sheets API
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service_account.json

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
```

## Запуск

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
| C | Платформа | Instagram / YouTube / TikTok / VK / Facebook / Rutube |
| D | Ссылка на ролик | Прямая ссылка |
| K | Комментарии | Количество |
| L | Лайки | Количество |
| M | Просмотры (play) | Для YouTube / VK |
| N | Просмотры (raw) | Для Instagram / TikTok / Facebook |
| AO | Количество сборов | Сколько раз парсер обновлял метрики |
| AP | Последний рефреш | Дата последнего обновления |
| AQ | Следующий рефреш | Когда планируется следующее обновление |
| AR | Статус | OK / ERROR / STOPPED |

### «История видео» (автоматически создаётся)

Хранит снимки метрик по каждому видео на каждую дату рефреша.

## Поддерживаемые платформы

| Платформа | Метод сбора | Обновление метрик |
|-----------|------------|-------------------|
| Instagram | Apify (actor: `apify~instagram-reel-scraper`) | Apify |
| YouTube | YouTube Data API v3 | YouTube Data API (бесплатно, до 50 видео за запрос) |
| TikTok | Apify (actor: `clockworks~tiktok-profile-scraper`) | Apify |
| Facebook | Apify (actor: `apify~facebook-pages-scraper`) | Apify |
| VK | VK API | VK API (до 200 видео за запрос) |
| Rutube | Rutube Public API | Rutube Public API |
| OK.ru | HTML scrape | HTML scrape |
| Pinterest | JSON-LD scrape | JSON-LD scrape |

## Cron (рекомендуемое расписание)

```cron
# Ежедневно в 06:00 МСК — сбор новых видео
0 3 * * * cd /path/to/mk2 && /path/to/venv/bin/python workers/project_content_daily_worker.py --once >> logs/daily.log 2>&1

# Каждые 2 часа — обновление метрик для старых видео
0 */2 * * * cd /path/to/mk2 && /path/to/venv/bin/python workers/video_refresh_worker.py --once >> logs/refresh.log 2>&1
```

## Зависимости от внешних сервисов

- **Google Sheets API** — чтение/запись таблиц (сервисный аккаунт)
- **Apify** — парсинг Instagram, TikTok, Facebook (требует токен)
- **YouTube Data API v3** — чтение метрик YouTube (бесплатный лимит: 10 000 единиц в сутки)
- **VK API** — чтение метрик VK
- **Rutube API** — чтение метрик Rutube (публичный, без ключа)

## Лицензия

MIT
