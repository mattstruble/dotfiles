from contextlib import asynccontextmanager
from datetime import datetime
from typing import Literal

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from .arms.base import IngestItem
from .gateway import Gateway, _memory_json


class IngestRequest(BaseModel):
    project: str | None = None
    session_id: str
    source: Literal["session", "seed", "retain"]
    timestamp: datetime
    text: str
    doc_id: str | None = None
    arms: list[str] | None = None


class RecallRequest(BaseModel):
    project: str | None = None
    query: str
    budget_tokens: int
    arms: list[str] | None = None


class SourceRequest(BaseModel):
    arm: str
    memory_id: str


class ForgetRequest(BaseModel):
    project: str | None = None
    text: str
    reason: str


def create_app(gateway: Gateway) -> FastAPI:
    @asynccontextmanager
    async def lifespan(_: FastAPI):
        await gateway.startup()
        yield
        await gateway.shutdown()

    app = FastAPI(title="memory-gateway", lifespan=lifespan)

    @app.get("/health")
    async def health():
        return await gateway.health()

    @app.post("/ingest", status_code=202)
    async def ingest(req: IngestRequest):
        fields = req.model_dump(exclude={"arms"})
        if req.arms is not None:
            bad = [a for a in req.arms if a not in gateway.enabled]
            if bad or not req.arms:
                raise HTTPException(422, f"unknown or empty arms: {bad or req.arms}")
        item_id = gateway.ingest(IngestItem(**fields), req.arms)
        return {"queued": True, "id": item_id}

    @app.post("/recall")
    async def recall(req: RecallRequest):
        out = await gateway.recall(req.project, req.query, req.budget_tokens, req.arms)
        return {
            "results": {
                arm: [_memory_json(m) for m in mems] for arm, mems in out["results"].items()
            },
            "errors": out["errors"],
        }

    @app.post("/history")
    async def history(req: RecallRequest):
        out = await gateway.history(req.project, req.query, req.budget_tokens, req.arms)
        return {
            "results": {
                arm: [_memory_json(m) for m in mems] for arm, mems in out["results"].items()
            },
            "errors": out["errors"],
        }

    @app.post("/source")
    async def source(req: SourceRequest):
        return await gateway.source(req.arm, req.memory_id)

    @app.post("/forget")
    async def forget(req: ForgetRequest):
        return await gateway.forget(req.project, req.text, req.reason)

    return app
