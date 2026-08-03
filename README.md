# TranscriberBot

Телеграм-бот, который:

- 🎙 принимает **голосовые сообщения, аудиофайлы и видеофайлы** и расшифровывает их в текст с помощью **Whisper** (реализация `faster-whisper`);
- 💬 на **текстовые** сообщения отвечает локальной **LLM через Ollama** (по умолчанию `qwen2.5`).

## Требования

- Python 3.10+
- [FFmpeg](https://ffmpeg.org/) в `PATH` (нужен для декодирования аудио/видео)
- Запущенная [Ollama](https://ollama.com/) с нужной моделью
- Токен бота от [@BotFather](https://t.me/BotFather)

## Установка

```bash
python -m venv .venv
# Windows:
.venv\Scripts\activate
# Linux/macOS:
source .venv/bin/activate

pip install -r requirements.txt
```

Установите FFmpeg:

- **Windows:** `winget install Gyan.FFmpeg` (или `choco install ffmpeg`)
- **Linux:** `sudo apt install ffmpeg`
- **macOS:** `brew install ffmpeg`

## Настройка

1. Скопируйте `.env.example` в `.env` и заполните значения:

```bash
copy .env.example .env   # Windows
cp .env.example .env      # Linux/macOS
```

2. Укажите `TELEGRAM_BOT_TOKEN`, при необходимости поменяйте модель Whisper и модель Ollama.

## Ollama

Запустите сервис и скачайте модель:

```bash
ollama serve
ollama pull qwen2.5
```

> ⚠️ Модель `qwen3.5` в реестре Ollama не существует. Доступны, например, `qwen2.5`, `qwen3`.
> Впишите имя реальной модели в `OLLAMA_MODEL` внутри `.env`.

## Большие файлы (>20 МБ) — локальный Bot API сервер

Публичный `api.telegram.org` отдаёт ботам файлы **только до 20 МБ** — это лимит
Telegram, его нельзя обойти настройкой бота. Чтобы принимать файлы до **2000 МБ**,
на Mac mini поднимается собственный сервер [telegram-bot-api](https://github.com/tdlib/telegram-bot-api).

**1. Соберите сервер из исходников.**
Готовой формулы `telegram-bot-api` в Homebrew больше нет, сервер собирается вручную
(разово, ~5–15 мин). Из корня проекта:

```bash
xcode-select --install                       # если ещё не установлен
brew install cmake gperf openssl
git clone --recursive https://github.com/tdlib/telegram-bot-api.git
cd telegram-bot-api && rm -rf build && mkdir build && cd build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX:PATH=.. \
      -DOPENSSL_ROOT_DIR="$(brew --prefix openssl)" ..
cmake --build . --target install -j
cd ../..
```

Бинарник появится в `telegram-bot-api/bin/telegram-bot-api`
(`-DOPENSSL_ROOT_DIR` нужен, чтобы cmake нашёл openssl из Homebrew).

**2. Получите `api_id` и `api_hash`** на https://my.telegram.org → *API development tools*
(это данные вашего аккаунта Telegram, не бота).

**3. Пропишите в `.env`** параметры сервера и переключите бота на локальный API:

```
# запуск сервера (для scripts/mac/server-*.sh)
TELEGRAM_API_ID=ВАШ_API_ID
TELEGRAM_API_HASH=ВАШ_API_HASH
TELEGRAM_BOT_API_BIN=./telegram-bot-api/bin/telegram-bot-api
TELEGRAM_BOT_API_PORT=8081
TELEGRAM_BOT_API_DIR=./tg-bot-api-files

# бот → локальный сервер
TELEGRAM_API_BASE_URL=http://127.0.0.1:8081/bot
TELEGRAM_API_BASE_FILE_URL=http://127.0.0.1:8081/file/bot
TELEGRAM_LOCAL_MODE=true
MAX_FILE_MB=2000
```

**4. Запустите сервер** (в фоне, скриптом):

```bash
chmod +x scripts/mac/*.sh
./scripts/mac/server-start.sh     # старт сервера
./scripts/mac/server-status.sh    # статус
./scripts/mac/server-stop.sh      # остановка
```

Проверить, что сервер живой:

```bash
curl "http://127.0.0.1:8081/bot<ВАШ_ТОКЕН>/getMe"
```

Ответ с `"ok":true` — сервер работает. После этого запускайте бота
(`./scripts/mac/start.sh`).

После этого бот скачивает большие файлы напрямую с диска (в local-режиме `getFile`
возвращает локальный путь), лимит 20 МБ снят.

> **Важно при первом переходе с облака:** если бот уже работал через публичный
> `api.telegram.org`, Telegram не даст сразу подключить его к локальному серверу.
> Один раз выполните logout из облака (обычным токеном):
> ```bash
> curl -s "https://api.telegram.org/bot<ВАШ_ТОКЕН>/logOut"
> ```
> Подождите ~10 минут и запускайте бота уже против локального сервера.

> **Прокси:** бот обращается к серверу по `localhost` — этот трафик прокси не трогает.
> Во внешний Telegram ходит уже сам `telegram-bot-api`. Если весь трафик Mac mini идёт
> через Throne в системном/TUN-режиме — сервер попадёт под него автоматически.
> При использовании локального сервера `PROXY_URL` к Telegram-соединению не применяется
> (остаётся только для скачивания весов Whisper с HuggingFace).

> **Диск:** в local-режиме сервер складывает принятые файлы в `TELEGRAM_BOT_API_DIR`
> (`./tg-bot-api-files`) и **не удаляет их автоматически**. При больших файлах папка
> будет расти — периодически чистите её (cron/launchd) или удаляйте файлы после обработки.

## Прокси (Throne)

Весь **внешний** трафик бота идёт через прокси — на сервере это локальный
inbound-прокси [Throne](https://github.com/throneproj/Throne):

- **Telegram** (получение апдейтов, отправка ответов, скачивание присланных файлов) → через прокси
- **Скачивание весов Whisper** (HuggingFace, при первом запуске) → через прокси
- **Ollama** (`localhost`) → **напрямую**, в обход прокси

Настраивается в `.env`:

```
PROXY_URL=socks5://127.0.0.1:2080
NO_PROXY=localhost,127.0.0.1
```

По умолчанию используется дефолтный mixed-порт Throne `socks5://127.0.0.1:2080`.
SOCKS5-зависимости уже включены в `requirements.txt` (`python-telegram-bot[socks]`,
`httpx[socks]`, `PySocks`). Чтобы **отключить** прокси, оставьте `PROXY_URL` пустым.

## Запуск

```bash
python bot.py
```

## Управление службой

Скрипты запускают бота в фоне (PID-файл + логи в `logs/`). Логи: `logs/bot.log` (stdout)
и `logs/bot.err.log` (ошибки), PID — `logs/bot.pid`. Python берётся из `.venv`, если он есть,
иначе системный.

### macOS (`scripts/mac/`)

Один раз сделайте скрипты исполняемыми:

```bash
chmod +x scripts/mac/*.sh
```

```bash
./scripts/mac/start.sh     # запустить в фоне
./scripts/mac/stop.sh      # остановить
./scripts/mac/restart.sh   # перезапустить
./scripts/mac/status.sh    # проверить статус
```

### Windows (`scripts/windows/`)

```powershell
.\scripts\windows\start.ps1     # запустить в фоне
.\scripts\windows\stop.ps1      # остановить
.\scripts\windows\restart.ps1   # перезапустить
.\scripts\windows\status.ps1    # проверить статус
```

> Если PowerShell блокирует запуск скриптов:
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
> ```

## Использование

- `/start`, `/help` — краткая справка
- `/reset` — очистить контекст диалога с LLM
- Пришлите голосовое / аудио / видео → получите транскрипцию
- Напишите текст → получите ответ LLM

## Заметки

- Telegram Bot API отдаёт ботам файлы **примерно до 20 МБ** — это ограничение платформы, а не бота. Настраивается через `MAX_FILE_MB`.
- Первый запуск скачивает веса Whisper — это может занять время.
- На CPU используйте `WHISPER_MODEL=small` + `WHISPER_COMPUTE_TYPE=int8`. На GPU (CUDA) — `WHISPER_DEVICE=cuda` + `WHISPER_COMPUTE_TYPE=float16` и модель `large-v3`.
- История диалога хранится в памяти процесса (сбрасывается при перезапуске).
