# memory-gateway

Local HTTP service fronting several agent-memory "arms" (Hindsight, Graphiti, wiki) for
an evaluation. pi talks only to this gateway; arms live in `memory_gateway/arms/`.

## API (default `127.0.0.1:8010`)

- `GET /health` → `{"ok", "arms": {name: "ok"|"error: ..."}, "queue_depth"}`
- `POST /ingest` `{project, session_id, source: session|seed|retain, timestamp, text, doc_id?}`
  → 202. Persisted to `state_dir/queue.sqlite`, then delivered to each arm independently
  by a background worker (per-arm ordering, exponential backoff, gives up after 24h).
- `POST /recall` `{project, query, budget_tokens, arms?}` → `{results: {arm: [Memory]}, errors: {arm: msg}}`.
  Every call is appended to `state_dir/recall-log.jsonl`.
- `POST /forget` `{project, text, reason}` → `{arms: {arm: [ids]}}` (marks superseded, never deletes).

## Config

JSON at `$MEMORY_GATEWAY_CONFIG` (default `~/.config/memory-gateway/config.json`); all keys optional:
`host`, `port`, `state_dir`, `arms`, `hindsight_url`, `hindsight_bank`, `bedrock_model`,
`aws_region`, `wiki_source`, `arm_timeout_s` (defaults: see `memory_gateway/config.py`).
Arms that fail to import or start are reported unhealthy; the server keeps running.

## Run / test

    uv sync --frozen
    uv run --frozen memory-gateway
    uv run --frozen pytest -q
