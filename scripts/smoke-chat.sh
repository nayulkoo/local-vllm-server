#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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
