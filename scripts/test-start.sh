#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

grep -Fxq "GPU_MEMORY_UTILIZATION=0.50" .env.example
grep -Fq -- "--use-env-gpu-memory-utilization" scripts/start.sh
grep -Fq -- '--gpu-memory-utilization "$EFFECTIVE_GPU_MEMORY_UTILIZATION"' scripts/start.sh
grep -Fq -- '--reasoning-parser "$REASONING_PARSER"' scripts/start.sh
grep -Fq -- '--default-chat-template-kwargs "$DEFAULT_CHAT_TEMPLATE_KWARGS"' scripts/start.sh
grep -Fq "GPU memory utilization:" scripts/start.sh
grep -Fq "Darwin)" scripts/start.sh
grep -Fq "Linux)" scripts/start.sh
grep -Fq "/proc/meminfo" scripts/start.sh
grep -Fxq "VLLM_BOOTSTRAP_MEMORY_RESERVE_GB=2" .env.example
grep -Fxq "REASONING_PARSER=qwen3" .env.example
grep -Fxq "DEFAULT_CHAT_TEMPLATE_KWARGS='{\"enable_thinking\": false}'" .env.example

bash -n scripts/start.sh

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/scripts" "$TMP_DIR/logs" "$TMP_DIR/run"
cp scripts/start.sh "$TMP_DIR/scripts/start.sh"
cp .env.example "$TMP_DIR/.env.example"
chmod +x "$TMP_DIR/scripts/start.sh"

cat > "$TMP_DIR/fake-vllm" <<'FAKE_VLLM'
#!/usr/bin/env bash
printf 'fake vllm args: %s\n' "$*"
FAKE_VLLM
chmod +x "$TMP_DIR/fake-vllm"

cat > "$TMP_DIR/.env" <<'ENV'
VLLM_BIN=./fake-vllm
LOG_FILE=logs/test.log
PID_FILE=run/test.pid
GPU_MEMORY_UTILIZATION=0.42
ENV

(
  cd "$TMP_DIR"
  ./scripts/start.sh --use-env-gpu-memory-utilization >/dev/null
  sleep 1
  sed -n '1p' logs/test.log | grep -Fq "Total memory:"
  sed -n '2p' logs/test.log | grep -Fq "Available memory:"
  sed -n '3p' logs/test.log | grep -Fq "Bootstrap memory reserve: 2.0 GB"
  sed -n '4p' logs/test.log | grep -Fq "GPU memory utilization: 0.42 (42%)"
  grep -Fq -- "--gpu-memory-utilization 0.42" logs/test.log
  grep -Fq -- "--reasoning-parser qwen3" logs/test.log
  grep -Fq -- "--default-chat-template-kwargs {\"enable_thinking\": false}" logs/test.log
)

mkdir -p "$TMP_DIR/linux/bin"
cat > "$TMP_DIR/linux/bin/uname" <<'UNAME'
#!/usr/bin/env bash
echo Linux
UNAME
chmod +x "$TMP_DIR/linux/bin/uname"

cat > "$TMP_DIR/meminfo" <<'MEMINFO'
MemTotal:       1000000 kB
MemAvailable:    500000 kB
MEMINFO

(
  cd "$TMP_DIR"
  rm -f logs/test.log run/test.pid
  MEMINFO_FILE="$TMP_DIR/meminfo" PATH="$TMP_DIR/linux/bin:$PATH" ./scripts/start.sh --use-env-gpu-memory-utilization >/dev/null
  sleep 1
  sed -n '1p' logs/test.log | grep -Fq "Total memory: 977 MB"
  sed -n '2p' logs/test.log | grep -Fq "Available memory: 488 MB (50.0% of total)"
)

cat > "$TMP_DIR/meminfo" <<'MEMINFO'
MemTotal:      10485760 kB
MemAvailable:  5242880 kB
MEMINFO
cat > "$TMP_DIR/.env" <<'ENV'
VLLM_BIN=./fake-vllm
LOG_FILE=logs/test.log
PID_FILE=run/test.pid
GPU_MEMORY_UTILIZATION=0.42
VLLM_BOOTSTRAP_MEMORY_RESERVE_GB=1
ENV

(
  cd "$TMP_DIR"
  rm -f logs/test.log run/test.pid
  printf 'y\n' | MEMINFO_FILE="$TMP_DIR/meminfo" PATH="$TMP_DIR/linux/bin:$PATH" ./scripts/start.sh >/dev/null
  sleep 1
  grep -Fq "Bootstrap memory reserve: 1.0 GB" logs/test.log
  sed -n '4p' logs/test.log | grep -Fq "GPU memory utilization: 0.36 (36%)"
  grep -Fq -- "--gpu-memory-utilization 0.36" logs/test.log
)
