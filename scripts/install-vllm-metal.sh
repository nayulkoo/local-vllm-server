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
export UV_CACHE_DIR="$ROOT_DIR/.cache/uv"
mkdir -p "$UV_CACHE_DIR"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer is for macOS on Apple Silicon." >&2
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Native arm64 is required. Rosetta/x86_64 is not supported." >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. Run: xcode-select --install" >&2
  exit 1
fi

INSTALLER="$(mktemp)"
PATCHED_INSTALLER="$(mktemp)"
trap 'rm -f "$INSTALLER" "$PATCHED_INSTALLER"' EXIT
curl -fsSL https://raw.githubusercontent.com/vllm-project/vllm-metal/main/install.sh -o "$INSTALLER"
sed "s|local venv=\"\$HOME/.venv-vllm-metal\"|local venv=\"$ROOT_DIR/.venv-vllm-metal\"|" "$INSTALLER" > "$PATCHED_INSTALLER"
bash "$PATCHED_INSTALLER"

VLLM_BIN="$ROOT_DIR/.venv-vllm-metal/bin/vllm"
if [[ ! -x "$VLLM_BIN" ]]; then
  echo "vLLM-Metal install finished but $VLLM_BIN is missing or not executable." >&2
  exit 1
fi

"$VLLM_BIN" --version
