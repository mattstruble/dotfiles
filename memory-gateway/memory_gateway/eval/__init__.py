"""Evaluation data tooling. Generated data lives outside the repo (privacy)."""
import os
from pathlib import Path


def eval_dir() -> Path:
    """Return the eval data dir, creating it with mode 700."""
    d = Path(os.environ.get("MEMORY_GATEWAY_EVAL_DIR") or "~/.local/share/memory-gateway/eval").expanduser()
    d.mkdir(parents=True, exist_ok=True, mode=0o700)
    d.chmod(0o700)
    return d
