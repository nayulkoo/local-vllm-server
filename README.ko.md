# Local LLM Server

[English](README.md) | [한국어](README.ko.md)

Apple Silicon macOS에서 vLLM-Metal 서버를 로컬로 실행하기 위한 최소 스크립트 모음입니다. 별도 API 래퍼 없이 vLLM의 OpenAI 호환 API를 그대로 사용합니다.

이 프로젝트의 범위는 의도적으로 작습니다. vLLM-Metal을 설치하고, 서버를 시작하고, 상태를 확인하고, 채팅 smoke 요청을 보내고, 서버를 종료합니다.

## 요구 사항

- Apple Silicon arm64 macOS
- Xcode Command Line Tools
- `curl`

Xcode Command Line Tools가 없다면 먼저 설치합니다.

```bash
xcode-select --install
```

## 빠른 시작

```bash
cp .env.example .env
./scripts/install-vllm-metal.sh
./scripts/start.sh
./scripts/status.sh
./scripts/smoke-chat.sh
./scripts/stop.sh
```

기본 API 주소:

```text
http://127.0.0.1:8000
```

## 설정

기본값은 `.env.example`에 있습니다. 로컬 설정을 바꾸려면 `.env`를 만들어 덮어씁니다.

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

## 스크립트

스크립트는 자기 위치를 기준으로 프로젝트 루트를 찾기 때문에 symlink로 실행해도 동작합니다.

프로젝트 내부 가상환경에 vLLM-Metal을 설치합니다.

```bash
./scripts/install-vllm-metal.sh
```

vLLM을 시작합니다.

```bash
./scripts/start.sh
```

`start.sh`는 전체/사용 가능 메모리를 출력하고, `VLLM_BOOTSTRAP_MEMORY_RESERVE_GB`만큼 남긴 뒤 사용할 `--gpu-memory-utilization` 값을 추천하고 확인을 받습니다. 확인 없이 `.env`의 `GPU_MEMORY_UTILIZATION` 값을 쓰려면 다음처럼 실행합니다.

```bash
./scripts/start.sh --use-env-gpu-memory-utilization
```

PID와 `/v1/models`를 확인합니다.

```bash
./scripts/status.sh
```

OpenAI 호환 채팅 요청을 한 번 보냅니다.

```bash
./scripts/smoke-chat.sh
```

PID가 가리키는 프로세스를 종료합니다.

```bash
./scripts/stop.sh
```

`stop.sh`는 오래된 PID 파일을 정리하고, `TERM` 이후 프로세스가 종료될 때까지 잠시 기다립니다.

## 직접 API 호출

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

## 파일

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

`.env`, `.venv-vllm-metal/`, `.cache/`, `logs/`, `run/`은 로컬 실행 파일이며 git에서 제외됩니다.

## 문제 확인

vLLM-Metal이 없으면 `start.sh`가 다음 메시지와 함께 종료됩니다.

```text
Missing vLLM binary: .venv-vllm-metal/bin/vllm
Run: ./scripts/install-vllm-metal.sh
```

런타임 오류는 다음 로그에서 확인합니다.

```bash
tail -n 200 logs/server.log
```

## 참고

- vLLM-Metal: https://github.com/vllm-project/vllm-metal
- vLLM OpenAI-compatible server: https://docs.vllm.ai/en/latest/serving/openai_compatible_server/
- 기본 모델: `mlx-community/Qwen3.5-9B-MLX-4bit`
