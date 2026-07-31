"""Клиент к локальной Ollama (chat API) с хранением истории по чатам."""
from __future__ import annotations

import logging
import re
from collections import defaultdict, deque

import httpx

logger = logging.getLogger(__name__)

# Некоторые модели (напр. qwen3) добавляют блок рассуждений <think>...</think>.
_THINK_RE = re.compile(r"<think>.*?</think>", re.DOTALL)


class OllamaClient:
    def __init__(
        self,
        base_url: str,
        model: str,
        system_prompt: str,
        history_limit: int = 10,
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._model = model
        self._system_prompt = system_prompt
        # deque на каждый chat_id; храним последние N сообщений (user/assistant)
        self._history: dict[int, deque[dict[str, str]]] = defaultdict(
            lambda: deque(maxlen=history_limit * 2)
        )

    def reset(self, chat_id: int) -> None:
        self._history.pop(chat_id, None)

    def _build_messages(self, chat_id: int, user_text: str) -> list[dict[str, str]]:
        messages: list[dict[str, str]] = [
            {"role": "system", "content": self._system_prompt}
        ]
        messages.extend(self._history[chat_id])
        messages.append({"role": "user", "content": user_text})
        return messages

    async def chat(self, chat_id: int, user_text: str) -> str:
        payload = {
            "model": self._model,
            "messages": self._build_messages(chat_id, user_text),
            "stream": False,
        }

        # trust_env=False: игнорируем *_PROXY из окружения — Ollama локальна и
        # должна ходить напрямую, в обход прокси Throne.
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(300.0), trust_env=False
        ) as client:
            resp = await client.post(f"{self._base_url}/api/chat", json=payload)
            resp.raise_for_status()
            data = resp.json()

        content = data.get("message", {}).get("content", "").strip()
        content = _THINK_RE.sub("", content).strip()

        # Сохраняем ход диалога
        self._history[chat_id].append({"role": "user", "content": user_text})
        self._history[chat_id].append({"role": "assistant", "content": content})

        return content or "🤔 Модель вернула пустой ответ."
