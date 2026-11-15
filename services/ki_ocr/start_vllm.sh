#!/usr/bin/env bash
# Modified for Ki-OCR (2026-11-15); derived from the SoMark upstream project.
set -euo pipefail

# Use a complete local ki_ocr-model checkout, including Git LFS files.
model_dir="${MODEL_PATH:-${MODEL_NAME:-./ki_ocr-model}}"
if [[ ! -f "$model_dir/plugins/vllm/pyproject.toml" || ! -f "$model_dir/chat_template.jinja" ]]; then
  echo "Expected an ki_ocr-model repository root with plugins/vllm and chat_template.jinja: $model_dir" >&2
  exit 1
fi
python3 -m pip install "$model_dir/plugins/vllm"
export VLLM_PLUGINS=ki_ocr
exec vllm serve "$model_dir" \
  --trust-remote-code --served-model-name ki_ocr \
  --chat-template "$model_dir/chat_template.jinja" \
  --dtype bfloat16 --max-model-len 16384 \
  --attention-config '{"backend":"TRITON_ATTN"}' \
  --host 0.0.0.0 --port 8080 "$@"
