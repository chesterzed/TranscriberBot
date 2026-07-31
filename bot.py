"""Telegram-бот: транскрибация голоса/аудио/видео (Whisper) + ответы LLM (Ollama)."""
from __future__ import annotations

import logging
import os
import tempfile

from telegram import Update
from telegram.constants import ChatAction
from telegram.ext import (
    Application,
    CommandHandler,
    ContextTypes,
    MessageHandler,
    filters,
)

from config import Config, load_config
from llm import OllamaClient
from transcriber import Transcriber

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger("bot")

# Заполняется в main()
config: Config
transcriber: Transcriber
llm: OllamaClient


# ---------- Команды ----------

async def cmd_start(update: Update, _: ContextTypes.DEFAULT_TYPE) -> None:
    await update.message.reply_text(
        "👋 Привет!\n\n"
        "🎙 Пришли *голосовое*, *аудио* или *видео* — я расшифрую его в текст (Whisper).\n"
        "💬 Напиши *текстом* — ответит локальная LLM (Ollama).\n\n"
        "Команда /reset очистит контекст диалога с LLM.",
        parse_mode="Markdown",
    )


async def cmd_reset(update: Update, _: ContextTypes.DEFAULT_TYPE) -> None:
    llm.reset(update.effective_chat.id)
    await update.message.reply_text("🧹 Контекст диалога очищен.")


# ---------- Текст → LLM ----------

async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    chat_id = update.effective_chat.id
    user_text = update.message.text

    await context.bot.send_chat_action(chat_id, ChatAction.TYPING)
    try:
        answer = await llm.chat(chat_id, user_text)
    except Exception as exc:  # noqa: BLE001
        logger.exception("Ошибка обращения к Ollama")
        await update.message.reply_text(
            "⚠️ Не удалось получить ответ от LLM.\n"
            f"Проверь, что Ollama запущена и модель '{config.ollama_model}' скачана.\n\n"
            f"`{exc}`",
            parse_mode="Markdown",
        )
        return

    await _reply_long(update, answer)


# ---------- Медиа → Whisper ----------

async def handle_media(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    message = update.message
    chat_id = update.effective_chat.id

    tg_file = (
        message.voice
        or message.audio
        or message.video
        or message.video_note
        or message.document
    )
    if tg_file is None:
        return

    # Проверка размера (Bot API отдаёт боту файлы примерно до 20 МБ)
    size = getattr(tg_file, "file_size", None)
    if size and size > config.max_file_mb * 1024 * 1024:
        await message.reply_text(
            f"❌ Файл слишком большой ({size / 1024 / 1024:.1f} МБ). "
            f"Лимит — {config.max_file_mb} МБ."
        )
        return

    status = await message.reply_text("⏳ Скачиваю файл...")
    await context.bot.send_chat_action(chat_id, ChatAction.TYPING)

    tmp_path: str | None = None
    try:
        file = await context.bot.get_file(tg_file.file_id)
        suffix = os.path.splitext(file.file_path or "")[1] or ".bin"
        fd, tmp_path = tempfile.mkstemp(suffix=suffix)
        os.close(fd)
        await file.download_to_drive(tmp_path)

        await status.edit_text("🎧 Распознаю речь...")
        text = await transcriber.transcribe(tmp_path)

        if not text:
            await status.edit_text("🤷 Речь не распознана (возможно, тишина).")
            return

        await status.delete()
        await _reply_long(update, f"📝 *Транскрипция:*\n\n{text}", markdown=True)
    except Exception as exc:  # noqa: BLE001
        logger.exception("Ошибка транскрибации")
        await status.edit_text(f"⚠️ Не удалось расшифровать файл.\n\n{exc}")
    finally:
        if tmp_path and os.path.exists(tmp_path):
            os.remove(tmp_path)


# ---------- Утилиты ----------

async def _reply_long(update: Update, text: str, markdown: bool = False) -> None:
    """Telegram ограничивает сообщение 4096 символами — режем на части."""
    limit = 4000
    parts = [text[i : i + limit] for i in range(0, len(text), limit)] or [text]
    for part in parts:
        await update.message.reply_text(
            part, parse_mode="Markdown" if markdown else None
        )


def main() -> None:
    global config, transcriber, llm

    config = load_config()

    # Прокси (Throne): весь внешний трафик — через него.
    # Выставляем ДО первой загрузки весов Whisper, чтобы скачивание из HuggingFace
    # (requests внутри huggingface_hub) тоже шло через прокси. Ollama на localhost
    # исключаем через NO_PROXY (плюс trust_env=False в самом клиенте Ollama).
    if config.proxy_url:
        os.environ["HTTP_PROXY"] = config.proxy_url
        os.environ["HTTPS_PROXY"] = config.proxy_url
        os.environ["NO_PROXY"] = config.no_proxy
        logger.info("Внешний трафик идёт через прокси %s (в обход: %s)",
                    config.proxy_url, config.no_proxy)

    transcriber = Transcriber(
        model_size=config.whisper_model,
        device=config.whisper_device,
        compute_type=config.whisper_compute_type,
        language=config.whisper_language,
    )
    llm = OllamaClient(
        base_url=config.ollama_url,
        model=config.ollama_model,
        system_prompt=config.ollama_system_prompt,
        history_limit=config.history_limit,
    )

    builder = Application.builder().token(config.telegram_token)

    if config.tg_base_url:
        # Локальный Telegram Bot API сервер (снимает лимит 20 МБ на скачивание,
        # позволяет файлы до 2000 МБ). Соединение с ним локальное (localhost),
        # поэтому прокси к нему НЕ применяем — во внешний Telegram ходит сам сервер.
        builder = builder.base_url(config.tg_base_url)
        if config.tg_base_file_url:
            builder = builder.base_file_url(config.tg_base_file_url)
        if config.tg_local_mode:
            # file_path приходит как локальный путь — файл берётся с диска напрямую
            builder = builder.local_mode(True)
        logger.info("Использую локальный Bot API: %s (local_mode=%s)",
                    config.tg_base_url, config.tg_local_mode)
    elif config.proxy_url:
        # Публичный api.telegram.org — и polling, и отправка/скачивание через прокси
        builder = builder.proxy(config.proxy_url).get_updates_proxy(config.proxy_url)

    app = builder.build()

    app.add_handler(CommandHandler("start", cmd_start))
    app.add_handler(CommandHandler("help", cmd_start))
    app.add_handler(CommandHandler("reset", cmd_reset))

    media_filter = (
        filters.VOICE
        | filters.AUDIO
        | filters.VIDEO
        | filters.VIDEO_NOTE
        | filters.Document.AUDIO
        | filters.Document.VIDEO
    )
    app.add_handler(MessageHandler(media_filter, handle_media))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))

    logger.info("Бот запущен. Ожидаю сообщения...")
    app.run_polling(allowed_updates=Update.ALL_TYPES)


if __name__ == "__main__":
    main()
