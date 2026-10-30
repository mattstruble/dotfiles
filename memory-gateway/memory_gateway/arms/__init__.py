import importlib
from pathlib import Path

from ..config import Config
from .base import Arm

REGISTRY: dict[str, str] = {
    "hindsight": "memory_gateway.arms.hindsight:HindsightArm",
    "graphiti": "memory_gateway.arms.graphiti:GraphitiArm",
    "wiki": "memory_gateway.arms.wiki:WikiArm",
}


def load_arm(name: str, config: Config, state_dir: Path) -> Arm:
    """Import and construct an arm lazily. Raises on any failure."""
    if name not in REGISTRY:
        raise KeyError(f"unknown arm {name!r}")
    mod_name, cls_name = REGISTRY[name].split(":")
    module = importlib.import_module(mod_name)
    return getattr(module, cls_name)(config, state_dir)
