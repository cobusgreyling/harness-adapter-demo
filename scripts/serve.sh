#!/usr/bin/env bash
# Serve Qwen3.8-27B (3-bit GGUF) with llama.cpp's llama-server on port 8080.
#
#   scripts/serve.sh base      # plain base model, alias qwen3.8-base
#   scripts/serve.sh adapter   # base + OpenCode LoRA, alias qwen3.8-opencode
#
# Stop one before starting the other (same port).
#
# Layout it expects (override the root with MODELS_DIR):
#   ~/harness-adapter-demo/models/base/*.gguf            unsloth Qwen3.8-27B-UD-IQ3_XXS.gguf
#   ~/harness-adapter-demo/models/opencode-lora/*.gguf   Qwen3.8-27B-opencode-lora-F16.gguf
set -euo pipefail

MODE="${1:-}"
MODELS_DIR="${MODELS_DIR:-$HOME/harness-adapter-demo/models}"
PORT="${PORT:-8080}"
CTX="${CTX:-16384}"
# The model card writes `llama serve`; the binary shipped by llama.cpp builds is llama-server.
LLAMA_SERVER="${LLAMA_SERVER:-llama-server}"

case "$MODE" in
  base)    ALIAS="qwen3.8-base" ;;
  adapter) ALIAS="qwen3.8-opencode" ;;
  *) echo "usage: $0 base|adapter" >&2; exit 2 ;;
esac

# Take the first .gguf in a folder (skips any mmproj file).
first_gguf() {
  local f
  for f in "$1"/*.gguf; do
    [[ -e "$f" && "$f" != *mmproj* ]] && { echo "$f"; return 0; }
  done
  echo "no .gguf found in $1" >&2
  return 1
}

BASE_GGUF="$(first_gguf "$MODELS_DIR/base")"
ARGS=(-m "$BASE_GGUF")

if [[ "$MODE" == "adapter" ]]; then
  LORA_GGUF="$(first_gguf "$MODELS_DIR/opencode-lora")"
  ARGS+=(--lora "$LORA_GGUF")
fi

echo "mode:  $MODE"
echo "alias: $ALIAS"
echo "base:  $BASE_GGUF"
[[ "$MODE" == "adapter" ]] && echo "lora:  $LORA_GGUF"
echo

# Working settings on a 16 GB M2 Pro (llama.cpp b12532):
#   -c 16384            OpenCode's own system prompt is ~9k tokens, so 8k is not enough
#   -np 1               one slot, so the whole context belongs to one session
#   -ngl 99             all layers on the GPU (Metal)
#   -fa on, -ctk/-ctv q8_0   flash attention + 8-bit KV cache, to fit the context in memory
#   --jinja             tool calling needs the model's own chat template
#   --reasoning off     thinking stays off, as in the adapter's training and evaluation
exec "$LLAMA_SERVER" "${ARGS[@]}" \
  --alias "$ALIAS" \
  --port "$PORT" \
  -c "$CTX" \
  -np 1 -ngl 99 \
  -fa on -ctk q8_0 -ctv q8_0 \
  --jinja \
  --reasoning off
