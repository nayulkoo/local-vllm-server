#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

source .env.example
if [[ -f .env ]]; then
  source .env
fi
export HF_HOME UV_CACHE_DIR

mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$PID_FILE")"

if [[ ! -x "$VLLM_BIN" ]]; then
  echo "Missing vLLM binary: $VLLM_BIN" >&2
  echo "Run: ./scripts/install-vllm-metal.sh" >&2
  exit 1
fi

if [[ -f "$PID_FILE" ]]; then
  PID="$(cat "$PID_FILE")"
  if kill -0 "$PID" >/dev/null 2>&1; then
    echo "vLLM is already running with PID $PID"
    exit 1
  fi
  rm -f "$PID_FILE"
fi

nohup "$VLLM_BIN" serve "$MODEL_ID" \
  --host "$HOST" \
  --port "$PORT" \
  --served-model-name "$SERVED_MODEL_NAME" \
  --max-model-len "$MAX_MODEL_LEN" \
  >"$LOG_FILE" 2>&1 &

echo "$!" > "$PID_FILE"
echo "Started vLLM PID $(cat "$PID_FILE")"
echo "Log: $LOG_FILE"
