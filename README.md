# Local LLM Server

[English](README.md) | [한국어](README.ko.md)

Minimal local vLLM-Metal server scripts for Apple Silicon macOS. The server exposes vLLM's OpenAI-compatible API directly.

This project is intentionally small: install vLLM-Metal, start the server, check it, send one chat smoke request, and stop it.

## Requirements

- macOS on Apple Silicon arm64
- Xcode Command Line Tools
- `curl`

Install Xcode Command Line Tools if needed.

```bash
xcode-select --install
```

## Quick Start

```bash
cp .env.example .env
./scripts/install-vllm-metal.sh
./scripts/start.sh
./scripts/status.sh
./scripts/smoke-chat.sh
./scripts/stop.sh
```

Default API base URL:

```text
http://127.0.0.1:8000
```

## Configuration

Defaults live in `.env.example`. Create `.env` to override local values.

```bash
MODEL_ID=mlx-community/Qwen3.5-9B-MLX-4bit
SERVED_MODEL_NAME=qwen3.5-9b
HOST=127.0.0.1
PORT=8000
MAX_MODEL_LEN=32768
GPU_MEMORY_UTILIZATION=0.50
VLLM_BOOTSTRAP_MEMORY_RESERVE_GB=2
VLLM_BIN=.venv-vllm-metal/bin/vllm
HF_HOME=.cache/huggingface
UV_CACHE_DIR=.cache/uv
LOG_FILE=logs/server.log
PID_FILE=run/vllm.pid
```

## Scripts

Scripts resolve the project root from their own path, so they can also be run through symlinks.

Install vLLM-Metal into the project-local virtualenv:

```bash
./scripts/install-vllm-metal.sh
```

Start vLLM:

```bash
./scripts/start.sh
```

`start.sh` prints total and available memory, recommends a `--gpu-memory-utilization` value after keeping `VLLM_BOOTSTRAP_MEMORY_RESERVE_GB` free, and asks before using it. To skip the prompt and use `GPU_MEMORY_UTILIZATION` from `.env`, run:

```bash
./scripts/start.sh --use-env-gpu-memory-utilization
```

Check the PID and `/v1/models`:

```bash
./scripts/status.sh
```

Send one OpenAI-compatible chat request:

```bash
./scripts/smoke-chat.sh
```

Stop the PID-owned process:

```bash
./scripts/stop.sh
```

`stop.sh` removes stale PID files and waits briefly for the process to exit after `TERM`.

## Manual API Call

```bash
curl -fsS "http://127.0.0.1:8000/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3.5-9b",
    "messages": [
      {"role": "user", "content": "Say hello in Korean."}
    ],
    "max_tokens": 64
  }'
```

## Files

```text
.env.example
.env
.venv-vllm-metal/
.cache/
logs/server.log
run/vllm.pid
scripts/install-vllm-metal.sh
scripts/start.sh
scripts/status.sh
scripts/smoke-chat.sh
scripts/stop.sh
```

`.env`, `.venv-vllm-metal/`, `.cache/`, `logs/`, and `run/` are local runtime files and are ignored by git.

## Troubleshooting

If vLLM-Metal is missing, `start.sh` exits with:

```text
Missing vLLM binary: .venv-vllm-metal/bin/vllm
Run: ./scripts/install-vllm-metal.sh
```

Check runtime errors in:

```bash
tail -n 200 logs/server.log
```

## References

- vLLM-Metal: https://github.com/vllm-project/vllm-metal
- vLLM OpenAI-compatible server: https://docs.vllm.ai/en/latest/serving/openai_compatible_server/
- Default model: `mlx-community/Qwen3.5-9B-MLX-4bit`
