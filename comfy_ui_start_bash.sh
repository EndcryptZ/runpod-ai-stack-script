```bash
#!/usr/bin/env bash
set -euo pipefail

COMFY=/workspace/runpod-slim/ComfyUI
BASE=https://huggingface.co/Comfy-Org/Krea-2/resolve/main

# Make sure aria2 is installed (falls back to wget if the install fails)
if ! command -v aria2c >/dev/null 2>&1; then
  SUDO=""
  [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"

  $SUDO apt-get update -qq && \
  $SUDO apt-get install -y -qq aria2 \
    || echo "aria2 install failed, falling back to wget"
fi

# Download helper
dl() {
  local url="$1"
  local dir="$2"
  local file

  file=$(basename "$url")
  mkdir -p "$dir"

  echo "=============================================="
  echo "Starting: $file"
  echo "=============================================="

  if command -v aria2c >/dev/null 2>&1; then
    aria2c \
      -x 8 \
      -s 8 \
      -k 32M \
      --file-allocation=none \
      -c \
      --max-tries=10 \
      --retry-wait=3 \
      --timeout=30 \
      --connect-timeout=10 \
      --summary-interval=10 \
      --console-log-level=warn \
      -d "$dir" \
      -o "$file" \
      "$url"
  else
    wget -c -O "$dir/$file" "$url"
  fi

  echo "Finished: $file"
}

# ============================================================
# 1. Custom nodes
# ============================================================

mkdir -p "$COMFY/custom_nodes"
cd "$COMFY/custom_nodes"

[ -d ComfyUI-Downloader ] || \
  git clone https://github.com/romandev-codex/ComfyUI-Downloader

pip install -r ComfyUI-Downloader/requirements.txt

[ -d rgthree-comfy ] || \
  git clone https://github.com/rgthree/rgthree-comfy

[ -f rgthree-comfy/requirements.txt ] && \
  pip install -r rgthree-comfy/requirements.txt

# ============================================================
# 2. Models
#    Download ALL THREE simultaneously
# ============================================================

echo ""
echo "=============================================="
echo "Starting parallel model downloads..."
echo "=============================================="
echo ""

dl \
  "$BASE/diffusion_models/krea2_turbo_int8_convrot.safetensors" \
  "$COMFY/models/diffusion_models" &

PID_KREA=$!

dl \
  "$BASE/text_encoders/qwen3vl_4b_fp8_scaled.safetensors" \
  "$COMFY/models/text_encoders" &

PID_QWEN=$!

dl \
  "$BASE/vae/qwen_image_vae.safetensors" \
  "$COMFY/models/vae" &

PID_VAE=$!

# ============================================================
# 3. Wait for all downloads
# ============================================================

echo ""
echo "Waiting for all model downloads to finish..."
echo ""

wait "$PID_KREA"
wait "$PID_QWEN"
wait "$PID_VAE"

echo ""
echo "=============================================="
echo "All models downloaded successfully!"
echo "=============================================="
echo ""
echo "Restart ComfyUI to load the new nodes and models."
```
