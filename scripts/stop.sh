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

if [[ ! -f "$PID_FILE" ]]; then
  echo "not running"
  exit 0
fi

PID="$(cat "$PID_FILE")"
if ! kill -0 "$PID" >/dev/null 2>&1; then
  rm -f "$PID_FILE"
  echo "not running"
  exit 0
fi

kill "$PID"

for _ in {1..20}; do
  if ! kill -0 "$PID" >/dev/null 2>&1; then
    rm -f "$PID_FILE"
    echo "stopped"
    exit 0
  fi
  sleep 0.5
done

echo "PID $PID did not stop after TERM; log may help: $LOG_FILE" >&2
exit 1
