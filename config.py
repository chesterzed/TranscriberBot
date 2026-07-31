"""Загрузка конфигурации из переменных окружения (.env)."""
from __future__ import annotations

import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


def _get(name: str, default: str = "") -> str:
    return os.getenv(name, default).strip()


@dataclass(frozen=True)
class Config:
    # Telegram
    telegram_token: str

    # Whisper
    whisper_model: str
    whisper_device: str
    whisper_compute_type: str
    whisper_language: str | None

    # Ollama
    ollama_url: str
    ollama_model: str
    ollama_system_prompt: str
    history_limit: int

    # Прочее
    max_file_mb: int


def load_config() -> Config:
    token = _get("TELEGRAM_BOT_TOKEN")
    if not token:
        raise RuntimeError(
            "Не задан TELEGRAM_BOT_TOKEN. Скопируйте .env.example в .env и заполните токен."
        )

    language = _get("WHISPER_LANGUAGE") or None

    return Config(
        telegram_token=token,
        whisper_model=_get("WHISPER_MODEL", "small"),
        whisper_device=_get("WHISPER_DEVICE", "cpu"),
        whisper_compute_type=_get("WHISPER_COMPUTE_TYPE", "int8"),
        whisper_language=language,
        ollama_url=_get("OLLAMA_URL", "http://localhost:11434").rstrip("/"),
        ollama_model=_get("OLLAMA_MODEL", "qwen2.5"),
        ollama_system_prompt=_get(
            "OLLAMA_SYSTEM_PROMPT",
            "Ты дружелюбный ассистент. Отвечай кратко и по делу на языке пользователя.",
        ),
        history_limit=int(_get("HISTORY_LIMIT", "10") or "10"),
        max_file_mb=int(_get("MAX_FILE_MB", "20") or "20"),
    )
