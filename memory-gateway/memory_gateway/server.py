import uvicorn

from .app import create_app
from .config import ensure_state_dir, load_config
from .gateway import Gateway


def main() -> None:
    config = load_config()
    state_dir = ensure_state_dir(config)
    app = create_app(Gateway(config, state_dir))
    uvicorn.run(app, host=config.host, port=config.port)


if __name__ == "__main__":
    main()
