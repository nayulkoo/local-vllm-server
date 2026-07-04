#!/usr/bin/env bash
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_PATH" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
ROOT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")/.." && pwd)"
cd "$ROOT_DIR"

set -a
source .env.example
if [[ -f .env ]]; then
  source .env
fi
set +a

API_URL="http://$HOST:$PORT/v1/models"

if [[ ! -f "$PID_FILE" ]]; then
  echo "process: not running"
  echo "api: not checked"
  exit 1
fi

PID="$(cat "$PID_FILE")"
if ! kill -0 "$PID" >/dev/null 2>&1; then
  echo "process: stale pid $PID"
  echo "api: not checked"
  exit 1
fi

echo "process: running pid $PID"

if curl -fsS "$API_URL" >/dev/null; then
  echo "api: reachable $API_URL"
  exit 0
fi

echo "api: unreachable $API_URL"
echo "log: $LOG_FILE"
exit 1
