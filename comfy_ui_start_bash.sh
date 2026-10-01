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

# Download helper: multi-connection aria2c, no pre-allocation (fast on network disks), resumable.
dl() {
  local url="$1" dir="$2" file
  file=$(basename "$url")
  mkdir -p "$dir"
  if command -v aria2c >/dev/null 2>&1; then
    aria2c -x 8 -s 8 -k 32M --file-allocation=none -c \
      --summary-interval=10 --console-log-level=warn \
      -d "$dir" -o "$file" "$url"
  else
    wget -c -O "$dir/$file" "$url"
  fi
}

# 1. Custom nodes
mkdir -p "$COMFY/custom_nodes"
cd "$COMFY/custom_nodes"

[ -d ComfyUI-Downloader ] || git clone https://github.com/romandev-codex/ComfyUI-Downloader
pip install -r ComfyUI-Downloader/requirements.txt

[ -d rgthree-comfy ] || git clone https://github.com/rgthree/rgthree-comfy
[ -f rgthree-comfy/requirements.txt ] && pip install -r rgthree-comfy/requirements.txt

# 2. Models (one at a time, 8 connections, 32MB chunks)
dl "$BASE/diffusion_models/krea2_turbo_int8_convrot.safetensors" "$COMFY/models/diffusion_models"
dl "$BASE/text_encoders/qwen3vl_4b_fp8_scaled.safetensors"       "$COMFY/models/text_encoders"
dl "$BASE/vae/qwen_image_vae.safetensors"                        "$COMFY/models/vae"

echo "Done. Restart ComfyUI to load the new nodes and models."