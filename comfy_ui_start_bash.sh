#!/usr/bin/env bash
set -euo pipefail

COMFY=/workspace/runpod-slim/ComfyUI
BASE=https://huggingface.co/Comfy-Org/Krea-2/resolve/main

# Optional: export HF_TOKEN=... before running if a download needs auth
HF_TOKEN="${HF_TOKEN:-}"

# Make sure aria2 is installed (falls back to wget if the install fails)
if ! command -v aria2c >/dev/null 2>&1; then
  SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
  $SUDO apt-get update -qq && $SUDO apt-get install -y -qq aria2 \
    || echo "aria2 install failed, falling back to wget"
fi

# Download helper: multi-connection aria2c, no pre-allocation (fast on network disks), resumable.
# Sends the HF token only if HF_TOKEN is set.
dl() {
  local url="$1" dir="$2" file
  file=$(basename "$url")
  mkdir -p "$dir"
  if command -v aria2c >/dev/null 2>&1; then
    local args=(-x 8 -s 8 -k 32M --file-allocation=none -c
      --summary-interval=10 --console-log-level=warn)
    [ -n "$HF_TOKEN" ] && args+=(--header="Authorization: Bearer $HF_TOKEN")
    aria2c "${args[@]}" -d "$dir" -o "$file" "$url"
  else
    local wargs=(-c)
    [ -n "$HF_TOKEN" ] && wargs+=(--header="Authorization: Bearer $HF_TOKEN")
    wget "${wargs[@]}" -O "$dir/$file" "$url"
  fi
}

# 1. Start all model downloads simultaneously in the background
pids=()

# Krea-2
dl "$BASE/diffusion_models/krea2_turbo_int8_convrot.safetensors" "$COMFY/models/diffusion_models" & pids+=($!)
dl "$BASE/text_encoders/qwen3vl_4b_fp8_scaled.safetensors"       "$COMFY/models/text_encoders"    & pids+=($!)
dl "$BASE/vae/qwen_image_vae.safetensors"                        "$COMFY/models/vae"              & pids+=($!)

# Flux.2 Klein 9B
dl "https://huggingface.co/Comfy-Org/flux2-dev/resolve/main/split_files/vae/flux2-vae.safetensors"             "$COMFY/models/vae"              & pids+=($!)
dl "https://huggingface.co/Kiro930/flux-2-klein-9b/resolve/main/flux-2-klein-9b.safetensors"                   "$COMFY/models/diffusion_models" & pids+=($!)
dl "https://huggingface.co/SassyDiffusion/FLUX.2-klein-9B-bf16/resolve/main/qwen_3_8b.safetensors"             "$COMFY/models/text_encoders"    & pids+=($!)

# 2. Custom nodes (installed while the models download)
mkdir -p "$COMFY/custom_nodes"
cd "$COMFY/custom_nodes"

[ -d ComfyUI-Downloader ] || git clone https://github.com/romandev-codex/ComfyUI-Downloader
pip install -r ComfyUI-Downloader/requirements.txt

[ -d rgthree-comfy ] || git clone https://github.com/rgthree/rgthree-comfy
[ -f rgthree-comfy/requirements.txt ] && pip install -r rgthree-comfy/requirements.txt

[ -d was-node-suite-comfyui ] || git clone https://github.com/WASasquatch/was-node-suite-comfyui
[ -f was-node-suite-comfyui/requirements.txt ] && pip install -r was-node-suite-comfyui/requirements.txt

[ -d ComfyUI_Comfyroll_CustomNodes ] || git clone https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes
[ -f ComfyUI_Comfyroll_CustomNodes/requirements.txt ] && pip install -r ComfyUI_Comfyroll_CustomNodes/requirements.txt

# 3. Wait for downloads and report failures
fail=0
for pid in "${pids[@]}"; do wait "$pid" || fail=1; done
[ "$fail" -eq 0 ] || { echo "One or more downloads failed. Re-run the script to resume."; exit 1; }

echo "Done. Restart ComfyUI to load the new nodes and models."