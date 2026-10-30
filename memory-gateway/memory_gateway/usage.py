import json
import logging
import os
from datetime import datetime, timezone
from pathlib import Path

log = logging.getLogger(__name__)

USAGE_FILE = "llm-usage.jsonl"
SAMPLING_PARAMS = ("temperature", "top_p", "top_k")


def record_usage(state_dir, arm: str, op: str, input_tokens, output_tokens, model: str) -> None:
    """Append one LLM usage line to <state_dir>/llm-usage.jsonl. Never raises."""
    try:
        line = json.dumps({
            "ts": datetime.now(timezone.utc).isoformat(),
            "arm": arm,
            "op": op,
            "input_tokens": int(input_tokens or 0),
            "output_tokens": int(output_tokens or 0),
            "model": model,
        })
        fd = os.open(Path(state_dir) / USAGE_FILE, os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
        try:
            os.write(fd, (line + "\n").encode())
        finally:
            os.close(fd)
    # Usage logging must never break the arm's real work.
    except Exception as e:
        log.warning("failed to record llm usage: %s", e)


def record_response_usage(state_dir, arm: str, op: str, response, model: str) -> None:
    u = getattr(response, "usage", None)
    record_usage(state_dir, arm, op, getattr(u, "input_tokens", 0),
                 getattr(u, "output_tokens", 0), model)


class UsageRecordingClient:
    """Thin proxy around an Anthropic client: records usage of messages.create."""

    def __init__(self, client, state_dir, arm: str, op: str):
        self._client = client
        self._state_dir = state_dir
        self._arm = arm
        self._op = op
        self.messages = _Messages(self)

    def __getattr__(self, name):
        return getattr(self._client, name)


class _Messages:
    def __init__(self, owner: UsageRecordingClient):
        self._o = owner

    async def create(self, *args, **kwargs):
        # anthropic SDK >=2.3 dropped these kwargs; Bedrock still accepts them in the body.
        moved = {k: kwargs.pop(k) for k in SAMPLING_PARAMS if k in kwargs}
        if moved:
            kwargs["extra_body"] = {**(kwargs.get("extra_body") or {}), **moved}
        resp = await self._o._client.messages.create(*args, **kwargs)
        record_response_usage(self._o._state_dir, self._o._arm, self._o._op, resp,
                              kwargs.get("model", ""))
        return resp

    def __getattr__(self, name):
        return getattr(self._o._client.messages, name)
