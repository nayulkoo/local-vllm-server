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

USE_ENV_GPU_MEMORY_UTILIZATION=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --use-env-gpu-memory-utilization)
      USE_ENV_GPU_MEMORY_UTILIZATION=1
      ;;
    -h|--help)
      echo "Usage: ./scripts/start.sh [--use-env-gpu-memory-utilization]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Usage: ./scripts/start.sh [--use-env-gpu-memory-utilization]" >&2
      exit 1
      ;;
  esac
  shift
done

source .env.example
if [[ -f .env ]]; then
  source .env
fi
MEMINFO_FILE="${MEMINFO_FILE:-/proc/meminfo}"
export HF_HOME UV_CACHE_DIR

bytes_to_human() {
  awk -v bytes="$1" 'BEGIN {
    if (bytes >= 1073741824) printf "%.1f GB", bytes / 1073741824;
    else printf "%.0f MB", bytes / 1048576;
  }'
}

memory_total_bytes() {
  case "$(uname -s)" in
    Darwin)
      sysctl -n hw.memsize 2>/dev/null || vm_stat | awk '
        /page size of/ { page_size = $8 }
        /^Pages free:/ { free = clean($3) }
        /^Pages active:/ { active = clean($3) }
        /^Pages inactive:/ { inactive = clean($3) }
        /^Pages speculative:/ { speculative = clean($3) }
        /^Pages throttled:/ { throttled = clean($3) }
        /^Pages wired down:/ { wired = clean($4) }
        /^Pages occupied by compressor:/ { compressor = clean($5) }
        function clean(value) { gsub(/\./, "", value); return value + 0 }
        END { print int((free + active + inactive + speculative + throttled + wired + compressor) * page_size) }
      '
      ;;
    Linux)
      awk '/^MemTotal:/ { print $2 * 1024 }' "$MEMINFO_FILE"
      ;;
    *)
      echo "Unsupported OS for memory detection: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

memory_available_bytes() {
  case "$(uname -s)" in
    Darwin)
      vm_stat | awk '
        /page size of/ { page_size = $8 }
        /^Pages free:/ { free = clean($3) }
        /^Pages inactive:/ { inactive = clean($3) }
        /^Pages speculative:/ { speculative = clean($3) }
        /^Pages purgeable:/ { purgeable = clean($3) }
        function clean(value) { gsub(/\./, "", value); return value + 0 }
        END { print int((free + inactive + speculative + purgeable) * page_size) }
      '
      ;;
    Linux)
      awk '/^MemAvailable:/ { print $2 * 1024 }' "$MEMINFO_FILE"
      ;;
    *)
      echo "Unsupported OS for memory detection: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

percent_of_total() {
  awk -v used="$1" -v total="$2" 'BEGIN {
    if (total <= 0) print "0.0";
    else printf "%.1f", used * 100 / total;
  }'
}

utilization_percent() {
  awk -v value="$1" 'BEGIN { printf "%.0f", value * 100 }'
}

gb_to_bytes() {
  awk -v gb="$1" 'BEGIN { printf "%.0f", gb * 1073741824 }'
}

recommend_gpu_memory_utilization() {
  awk -v available="$1" -v total="$2" -v reserve="$3" 'BEGIN {
    usable = available - reserve;
    if (total <= 0 || usable <= 0) {
      print "0.50";
      exit;
    }
    # ponytail: heuristic from current reclaimable memory; replace with model-aware preflight if vLLM exposes one.
    value = usable / total * 0.90;
    if (value > 0.90) value = 0.90;
    if (value < 0.01) value = 0.01;
    printf "%.2f", value;
  }'
}

validate_gpu_memory_utilization() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]] && awk -v value="$1" 'BEGIN { exit !(value > 0 && value <= 1) }'
}

validate_non_negative_number() {
  [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]
}

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

if ! validate_gpu_memory_utilization "$GPU_MEMORY_UTILIZATION"; then
  echo "GPU_MEMORY_UTILIZATION must be a number greater than 0 and at most 1: $GPU_MEMORY_UTILIZATION" >&2
  exit 1
fi

if ! validate_non_negative_number "$VLLM_BOOTSTRAP_MEMORY_RESERVE_GB"; then
  echo "VLLM_BOOTSTRAP_MEMORY_RESERVE_GB must be a non-negative number: $VLLM_BOOTSTRAP_MEMORY_RESERVE_GB" >&2
  exit 1
fi

TOTAL_MEMORY_BYTES="$(memory_total_bytes)"
AVAILABLE_MEMORY_BYTES="$(memory_available_bytes)"
BOOTSTRAP_MEMORY_RESERVE_BYTES="$(gb_to_bytes "$VLLM_BOOTSTRAP_MEMORY_RESERVE_GB")"
AVAILABLE_MEMORY_PERCENT="$(percent_of_total "$AVAILABLE_MEMORY_BYTES" "$TOTAL_MEMORY_BYTES")"
RECOMMENDED_GPU_MEMORY_UTILIZATION="$(recommend_gpu_memory_utilization "$AVAILABLE_MEMORY_BYTES" "$TOTAL_MEMORY_BYTES" "$BOOTSTRAP_MEMORY_RESERVE_BYTES")"
EFFECTIVE_GPU_MEMORY_UTILIZATION="$GPU_MEMORY_UTILIZATION"

echo "Total memory: $(bytes_to_human "$TOTAL_MEMORY_BYTES")"
echo "Available memory: $(bytes_to_human "$AVAILABLE_MEMORY_BYTES") (${AVAILABLE_MEMORY_PERCENT}% of total)"
echo "Bootstrap memory reserve: $(bytes_to_human "$BOOTSTRAP_MEMORY_RESERVE_BYTES")"

if [[ "$USE_ENV_GPU_MEMORY_UTILIZATION" -eq 1 ]]; then
  echo "Using GPU_MEMORY_UTILIZATION=$EFFECTIVE_GPU_MEMORY_UTILIZATION ($(utilization_percent "$EFFECTIVE_GPU_MEMORY_UTILIZATION")%) from environment."
else
  echo "Recommended GPU_MEMORY_UTILIZATION=$RECOMMENDED_GPU_MEMORY_UTILIZATION ($(utilization_percent "$RECOMMENDED_GPU_MEMORY_UTILIZATION")%) for current available memory."
  read -r -p "Start vLLM with GPU_MEMORY_UTILIZATION=$RECOMMENDED_GPU_MEMORY_UTILIZATION? [y/N] " ANSWER
  case "$ANSWER" in
    y|Y|yes|YES)
      EFFECTIVE_GPU_MEMORY_UTILIZATION="$RECOMMENDED_GPU_MEMORY_UTILIZATION"
      ;;
    *)
      echo "Aborted."
      exit 1
      ;;
  esac
fi

{
  echo "Total memory: $(bytes_to_human "$TOTAL_MEMORY_BYTES")"
  echo "Available memory: $(bytes_to_human "$AVAILABLE_MEMORY_BYTES") (${AVAILABLE_MEMORY_PERCENT}% of total)"
  echo "Bootstrap memory reserve: $(bytes_to_human "$BOOTSTRAP_MEMORY_RESERVE_BYTES")"
  echo "GPU memory utilization: $EFFECTIVE_GPU_MEMORY_UTILIZATION ($(utilization_percent "$EFFECTIVE_GPU_MEMORY_UTILIZATION")%)"
} >"$LOG_FILE"

nohup "$VLLM_BIN" serve "$MODEL_ID" \
  --host "$HOST" \
  --port "$PORT" \
  --served-model-name "$SERVED_MODEL_NAME" \
  --max-model-len "$MAX_MODEL_LEN" \
  --gpu-memory-utilization "$EFFECTIVE_GPU_MEMORY_UTILIZATION" \
  --reasoning-parser "$REASONING_PARSER" \
  --default-chat-template-kwargs "$DEFAULT_CHAT_TEMPLATE_KWARGS" \
  >>"$LOG_FILE" 2>&1 &

echo "$!" > "$PID_FILE"
echo "Started vLLM PID $(cat "$PID_FILE")"
echo "Log: $LOG_FILE"
