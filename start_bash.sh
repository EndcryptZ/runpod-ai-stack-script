#!/usr/bin/env bash
set -euo pipefail

COMFY=/workspace/runpod-slim/ComfyUI
BASE=https://huggingface.co/Comfy-Org/Krea-2/resolve/main

# Make sure aria2 is installed (falls back to wget if the install fails)
if ! command -v aria2c >/dev/null 2>&1; then
  SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
  $SUDO apt-get update -qq && $SUDO apt-get install -y -qq aria2 \
    || echo "aria2 install failed, falling back to wget"
fi

# Download helper: uses aria2c if available, otherwise wget. Resumes partial downloads.
dl() {
  local url="$1" dir="$2" file
  file=$(basename "$url")
  mkdir -p "$dir"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x 16 -s 16 -c --console-log-level=warn -d "$dir" -o "$file" "$url"
  else
    wget -c -O "$dir/$file" "$url"
  fi
}

# 1. Custom node
mkdir -p "$COMFY/custom_nodes"
cd "$COMFY/custom_nodes"
[ -d ComfyUI-Downloader ] || git clone https://github.com/romandev-codex/ComfyUI-Downloader
cd ComfyUI-Downloader
pip install -r requirements.txt

# 2. Models
dl "$BASE/diffusion_models/krea2_turbo_int8_convrot.safetensors" "$COMFY/models/diffusion_models"
dl "$BASE/text_encoders/qwen3vl_4b_fp8_scaled.safetensors"       "$COMFY/models/text_encoders"
dl "$BASE/vae/qwen_image_vae.safetensors"                        "$COMFY/models/vae"

echo "Done. Restart ComfyUI to load the new node and models."