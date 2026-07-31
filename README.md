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
