import json
import os
from pathlib import Path

from pydantic import BaseModel, Field


class Config(BaseModel):
    host: str = "127.0.0.1"
    port: int = 8010
    state_dir: str = "~/.local/share/memory-gateway"
    arms: list[str] = Field(default_factory=lambda: ["hindsight", "graphiti", "wiki"])
    hindsight_url: str = "http://127.0.0.1:8011"
    hindsight_bank: str = "memory-eval"
    hindsight_latest_only: bool = True
    bedrock_model: str = "us.anthropic.claude-haiku-4-5-20251001-v1:0"
    aws_region: str = "us-east-1"
    cognee_url: str = "http://127.0.0.1:8012"
    wiki_source: str = "~/llm-wiki"
    arm_timeout_s: float = 20.0
    ingest_timeout_s: float = 300.0

    @property
    def state_path(self) -> Path:
        return Path(self.state_dir).expanduser()

    @property
    def wiki_path(self) -> Path:
        return Path(self.wiki_source).expanduser()


def default_config_path() -> Path:
    return Path(
        os.environ.get("MEMORY_GATEWAY_CONFIG", "~/.config/memory-gateway/config.json")
    ).expanduser()


def load_config(path: Path | None = None) -> Config:
    path = path or default_config_path()
    if path.exists():
        return Config(**json.loads(path.read_text()))
    return Config()


def ensure_state_dir(config: Config) -> Path:
    p = config.state_path
    p.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(p, 0o700)
    return p
