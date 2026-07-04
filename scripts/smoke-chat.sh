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

curl -fsS "http://$HOST:$PORT/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$SERVED_MODEL_NAME\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"Say hello in Korean.\"}
    ],
    \"max_tokens\": 64
  }"
echo
