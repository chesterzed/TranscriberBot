"""Транскрибация аудио/видео через faster-whisper.

faster-whisper декодирует вход через PyAV/ffmpeg, поэтому принимает не только
аудио (ogg/mp3/wav/m4a...), но и видеофайлы (mp4/mov/...) — из них берётся
звуковая дорожка автоматически.
"""
from __future__ import annotations

import asyncio
import logging

from faster_whisper import WhisperModel

logger = logging.getLogger(__name__)


class Transcriber:
    def __init__(
        self,
        model_size: str,
        device: str,
        compute_type: str,
        language: str | None = None,
    ) -> None:
        self._model_size = model_size
        self._device = device
        self._compute_type = compute_type
        self._language = language
        self._model: WhisperModel | None = None

    def _ensure_model(self) -> WhisperModel:
        if self._model is None:
            logger.info(
                "Загрузка модели Whisper '%s' (device=%s, compute=%s)...",
                self._model_size,
                self._device,
                self._compute_type,
            )
            self._model = WhisperModel(
                self._model_size,
                device=self._device,
                compute_type=self._compute_type,
            )
            logger.info("Модель Whisper загружена.")
        return self._model

    def _transcribe_sync(self, path: str) -> str:
        model = self._ensure_model()
        segments, info = model.transcribe(
            path,
            language=self._language,
            vad_filter=True,  # отсекаем тишину — точнее и быстрее
        )
        logger.info(
            "Распознавание: язык=%s (p=%.2f)",
            getattr(info, "language", "?"),
            getattr(info, "language_probability", 0.0),
        )
        return "".join(segment.text for segment in segments).strip()

    async def transcribe(self, path: str) -> str:
        """Асинхронная обёртка: тяжёлая работа уходит в отдельный поток."""
        return await asyncio.to_thread(self._transcribe_sync, path)
