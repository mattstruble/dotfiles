import asyncio
import json
import logging
import time
from contextlib import suppress
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

from .arms import load_arm
from .arms.base import Arm, IngestItem, Memory, SourceRecord
from .config import Config
from .queue import DurableQueue

log = logging.getLogger("memory_gateway")


def _memory_json(m: Memory) -> dict:
    d = asdict(m)
    d["ts"] = m.ts.isoformat() if m.ts else None
    return d


def _source_json(s: SourceRecord | None) -> dict | None:
    if s is None:
        return None
    d = asdict(s)
    d["ts"] = s.ts.isoformat() if s.ts else None
    return d


class Gateway:
    """Owns the arms, the durable ingest queue, its delivery workers and the recall log."""

    def __init__(
        self,
        config: Config,
        state_dir: Path,
        arms: dict[str, Arm] | None = None,
        poll_interval_s: float = 0.2,
        backoff_base_s: float = 1.0,
    ):
        self.config = config
        self.state_dir = state_dir
        self.queue = DurableQueue(state_dir / "queue.sqlite", backoff_base_s)
        self.recall_log = state_dir / "recall-log.jsonl"
        self.poll_interval_s = poll_interval_s
        self.arms: dict[str, Arm] = {}
        self.load_errors: dict[str, str] = {}
        self._started: set[str] = set()
        self._start_errors: dict[str, str] = {}
        self._tasks: list[asyncio.Task] = []
        if arms is not None:
            self.arms = dict(arms)
            self.enabled = list(arms)
        else:
            self.enabled = list(config.arms)
            for name in self.enabled:
                # a broken or not-yet-written arm must not crash the server
                try:
                    self.arms[name] = load_arm(name, config, state_dir)
                except Exception as e:  # noqa: BLE001
                    self.load_errors[name] = f"{type(e).__name__}: {e}"

    async def _ensure_started(self, name: str) -> None:
        if name in self._started:
            return
        try:
            await self.arms[name].start()
        except Exception as e:  # noqa: BLE001 - arm start may raise anything; retried lazily
            self._start_errors[name] = f"{type(e).__name__}: {e}"
            raise
        self._started.add(name)
        self._start_errors.pop(name, None)

    async def startup(self) -> None:
        for name in self.arms:
            with suppress(Exception):
                await self._ensure_started(name)
            self._tasks.append(asyncio.create_task(self._worker(name)))

    async def shutdown(self) -> None:
        for t in self._tasks:
            t.cancel()
        await asyncio.gather(*self._tasks, return_exceptions=True)
        self._tasks.clear()
        self.queue.close()

    async def _worker(self, name: str) -> None:
        arm = self.arms[name]
        while True:
            # The loop must survive anything (e.g. transient sqlite errors); a dead worker
            # would silently stop this arm's delivery until restart.
            try:
                job = self.queue.next_for(name)
                if job is None:
                    await asyncio.sleep(self.poll_interval_s)
                    continue
                item_id, item = job
                try:
                    await asyncio.wait_for(self._deliver(name, arm, item), self.config.ingest_timeout_s)
                except asyncio.CancelledError:
                    raise
                except asyncio.TimeoutError:
                    log.warning("ingest to %s timed out", name)
                    self.queue.mark_failed_attempt(
                        item_id, name, f"timeout after {self.config.ingest_timeout_s}s"
                    )
                except Exception as e:  # noqa: BLE001 - any arm failure means retry later
                    log.warning("ingest to %s failed: %s", name, e)
                    self.queue.mark_failed_attempt(item_id, name, f"{type(e).__name__}: {e}")
                else:
                    self.queue.mark_done(item_id, name)
            except asyncio.CancelledError:
                raise
            except Exception:  # noqa: BLE001 - keep the worker alive, retry next poll
                log.exception("delivery worker for %s hit an error", name)
                await asyncio.sleep(max(self.poll_interval_s, 0.5))

    async def _deliver(self, name: str, arm: Arm, item: IngestItem) -> None:
        await self._ensure_started(name)
        await arm.ingest(item)

    def ingest(self, item: IngestItem, arms: list[str] | None = None) -> int:
        return self.queue.enqueue(item, self.enabled if arms is None else arms)

    async def health(self) -> dict:
        async def one(name: str) -> str:
            if name in self.load_errors:
                return f"error: {self.load_errors[name]}"
            try:
                await self._ensure_started(name)
                return await asyncio.wait_for(self.arms[name].health(), 5)
            except Exception as e:  # noqa: BLE001
                return f"error: {type(e).__name__}: {e}"

        statuses = await asyncio.gather(*(one(n) for n in self.enabled))
        return {
            "ok": True,
            "arms": dict(zip(self.enabled, statuses)),
            "queue_depth": self.queue.depth(),
        }

    def _select(self, names: list[str] | None) -> tuple[list[str], dict[str, str]]:
        errors: dict[str, str] = {}
        chosen: list[str] = []
        for n in names if names is not None else self.enabled:
            if n in self.arms:
                chosen.append(n)
            elif n in self.load_errors:
                errors[n] = f"arm unavailable: {self.load_errors[n]}"
            else:
                errors[n] = "unknown arm"
        return chosen, errors

    async def recall(
        self, project: str | None, query: str, budget_tokens: int, names: list[str] | None
    ) -> dict:
        return await self._query("recall", project, query, budget_tokens, names)

    async def history(
        self, project: str | None, query: str, budget_tokens: int, names: list[str] | None
    ) -> dict:
        return await self._query("history", project, query, budget_tokens, names)

    async def _query(
        self, kind: str, project: str | None, query: str, budget_tokens: int,
        names: list[str] | None,
    ) -> dict:
        chosen, errors = self._select(names)
        results: dict[str, list[Memory]] = {}
        latency: dict[str, float] = {}

        async def one(name: str) -> None:
            t0 = time.monotonic()
            try:
                method = getattr(self.arms[name], kind, None)
                if method is None:
                    errors[name] = "unsupported"
                    return

                async def call() -> list[Memory]:
                    await self._ensure_started(name)
                    return await method(project, query, budget_tokens)

                mems = await asyncio.wait_for(call(), self.config.arm_timeout_s)
                kept: list[Memory] = []
                used = 0
                for m in mems:
                    if used + m.tokens > budget_tokens:
                        continue
                    used += m.tokens
                    kept.append(m)
                results[name] = kept
            except asyncio.TimeoutError:
                errors[name] = f"timeout after {self.config.arm_timeout_s}s"
            except Exception as e:  # noqa: BLE001 - one arm failing must not fail the call
                errors[name] = f"{type(e).__name__}: {e}"
            finally:
                latency[name] = round(time.monotonic() - t0, 4)

        await asyncio.gather(*(one(n) for n in chosen))
        self._log_recall(kind, project, query, budget_tokens, names, results, errors, latency)
        return {"results": results, "errors": errors}

    def _log_recall(self, kind, project, query, budget, names, results, errors, latency) -> None:
        entry = {
            "kind": kind,
            "ts": datetime.now(timezone.utc).isoformat(),
            "request": {
                "project": project,
                "query": query,
                "budget_tokens": budget,
                "arms": names,
            },
            "arms": {
                n: {
                    "memories": [
                        {"id": m.id, "text": m.text, "tokens": m.tokens}
                        for m in results.get(n, [])
                    ],
                    "latency_s": latency.get(n),
                    "error": errors.get(n),
                }
                for n in {*results, *errors}
            },
        }
        with self.recall_log.open("a") as f:
            f.write(json.dumps(entry) + "\n")

    async def source(self, arm: str, memory_id: str) -> dict:
        source: SourceRecord | None = None
        error: str | None = None
        t0 = time.monotonic()
        if arm in self.load_errors:
            error = f"arm unavailable: {self.load_errors[arm]}"
        elif arm not in self.arms:
            error = "unknown arm"
        else:
            method = getattr(self.arms[arm], "source", None)
            if method is None:
                error = "unsupported"
            else:
                try:
                    async def call() -> SourceRecord | None:
                        await self._ensure_started(arm)
                        return await method(memory_id)

                    source = await asyncio.wait_for(call(), self.config.arm_timeout_s)
                except asyncio.TimeoutError:
                    error = f"timeout after {self.config.arm_timeout_s}s"
                except Exception as e:  # noqa: BLE001
                    error = f"{type(e).__name__}: {e}"
        out = {"arm": arm, "source": _source_json(source), "error": error}
        entry = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "kind": "source",
            "request": {"arm": arm, "memory_id": memory_id},
            "source": out["source"],
            "error": error,
            "latency_s": round(time.monotonic() - t0, 4),
        }
        with self.recall_log.open("a") as f:
            f.write(json.dumps(entry) + "\n")
        return out

    async def forget(self, project: str | None, text: str, reason: str) -> dict:
        out: dict[str, list[str]] = {}

        async def one(name: str) -> None:
            try:
                await self._ensure_started(name)
                out[name] = await asyncio.wait_for(
                    self.arms[name].forget(project, text, reason),
                    self.config.arm_timeout_s,
                )
            except Exception as e:  # noqa: BLE001
                log.warning("forget on %s failed: %s", name, e)
                out[name] = []

        await asyncio.gather(*(one(n) for n in self.arms))
        return {"arms": out}
