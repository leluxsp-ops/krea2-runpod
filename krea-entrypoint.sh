#!/usr/bin/env bash
set -Eeuo pipefail

echo '========== KREA 2 BOOTSTRAP =========='
C=/workspace/runpod-slim/ComfyUI
VENV="$C/.venv-cu128"
PY="$VENV/bin/python"

# First boot of the base image normally copies baked ComfyUI here.
# Do it before installing models/nodes; the original /start.sh will
# subsequently keep managing SSH, Jupyter, FileBrowser and ComfyUI.
mkdir -p /workspace/runpod-slim
if [ ! -f "$C/main.py" ]; then
  echo '[1/4] Copying ComfyUI from base image'
  cp -a /opt/comfyui-baked "$C"
fi

if [ ! -x "$PY" ]; then
  echo '[1/4] Creating the same Python venv used by runpod/comfyui:cuda12.8'
  python3.12 -m venv --system-site-packages "$VENV"
  "$PY" -m ensurepip --upgrade
fi

if [ -f /opt/comfyui-runtime-constraints.txt ]; then
  export PIP_CONSTRAINT=/opt/comfyui-runtime-constraints.txt
fi

# CRT-Nodes currently imports comfy.ldm.minimax.controlnet. The baked
# ComfyUI v0.30.0 lacks that module; pin core to a compatible stable tag.
# This runs in the image startup automatically, not in a user's terminal.
echo '[1/4] Ensuring ComfyUI core v0.35.0 (CRT compatibility)'
if [ ! -d "$C/.git" ]; then
  echo "ERROR: No git metadata in $C; cannot safely upgrade core" >&2
  exit 1
fi
if ! "$PY" -c 'import sys;sys.path.insert(0,sys.argv[1]);import comfy.ldm.minimax.controlnet' "$C" 2>/dev/null; then
  git -C "$C" fetch --depth 1 origin tag v0.35.0
  git -C "$C" -c advice.detachedHead=false checkout --detach v0.35.0
  "$PY" -m pip install -r "$C/requirements.txt"
fi
# Validate version compatibility before spending bandwidth on large models.
(cd "$C" && "$PY" -c 'import comfy.ldm.minimax.controlnet; print("[CRT] MiniMax module available")')

mkdir -p "$C/models/diffusion_models" "$C/models/text_encoders" \
         "$C/models/vae" "$C/models/loras" "$C/custom_nodes"

install_node() {
  local name="$1" url="$2" dest="$C/custom_nodes/$1"
  if [ ! -f "$dest/__init__.py" ]; then
    echo "[2/4] Installing custom node: $name"
    if [ -e "$dest" ]; then
      echo "ERROR: $dest exists but is incomplete; please inspect it" >&2
      return 1
    fi
    git clone --depth 1 "$url" "$dest"
  fi
  if [ -f "$dest/requirements.txt" ]; then
    "$PY" -m pip install -r "$dest/requirements.txt"
  fi
}

install_node rgthree-comfy https://github.com/rgthree/rgthree-comfy.git
install_node CRT-Nodes https://github.com/PGCRT/CRT-Nodes.git
install_node comfyui-obvpm https://github.com/chanon/comfyui-obvpm.git

# Registration in comfy/samplers.py happens before custom nodes are loaded.
# Keep obvpm installed as well; this is an idempotent compatibility workaround
# for images where the KSampler API does not reflect custom-node registration.
"$PY" /usr/local/bin/enable-beta57.py "$C/comfy/samplers.py"

# Verify the downloaded file size exactly where known; download to .part,
# atomically rename only after completion. curl retries transient failures.
download_model() {
  local url="$1" path="$2" minsize="$3"
  if [ -f "$path" ] && [ "$(stat -c%s "$path")" -ge "$minsize" ]; then
    echo "[3/4] Existing: $(basename "$path")"
    return 0
  fi
  echo "[3/4] Downloading $(basename "$path")"
  mkdir -p "$(dirname "$path")"
  curl --fail --location --retry 15 --retry-all-errors --retry-delay 5 \
       --connect-timeout 30 --continue-at - \
       --output "$path.part" "$url"
  if [ ! -s "$path.part" ] || [ "$(stat -c%s "$path.part")" -lt "$minsize" ]; then
    echo "ERROR: Invalid/incomplete download: $path" >&2
    return 1
  fi
  mv -f "$path.part" "$path"
}

BASE=https://huggingface.co/Comfy-Org/Krea-2/resolve/main
# LoRA files are downloaded separately from the Google Drive folder below.
download_model "$BASE/diffusion_models/krea2_turbo_fp8_scaled.safetensors" \
  "$C/models/diffusion_models/krea2_turbo_fp8_scaled.safetensors" 12000000000
download_model "$BASE/text_encoders/qwen3vl_4b_fp8_scaled.safetensors" \
  "$C/models/text_encoders/qwen3vl_4b_fp8_scaled.safetensors" 4800000000
download_model "$BASE/text_encoders/qwen3vl_4b_bf16.safetensors" \
  "$C/models/text_encoders/qwen3vl_4b_bf16.safetensors" 8000000000
download_model "$BASE/vae/qwen_image_vae.safetensors" \
  "$C/models/vae/qwen_image_vae.safetensors" 230000000
download_model 'https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors' \
  "$C/models/vae/wan_2.1_vae.safetensors" 250000000

# WAN VAE is small enough to verify each boot; catch incorrect partial files.
echo '2fc39d31359a4b0a64f55876d8ff7fa8d780956ae2cb13463b0223e15148976b  '"$C/models/vae/wan_2.1_vae.safetensors" | sha256sum -c -

echo '[4/4] Downloading LoRA files from Google Drive'
# Use the exact model directory read by this RunPod ComfyUI image.
# Downloads are best-effort: a Google Drive quota/access error should not
# stop ComfyUI from starting; inspect logs if expected LoRAs are absent.
"$PY" -m pip install -U gdown
LORA_URL='https://drive.google.com/drive/folders/1UUGtOwtoq9L4-cijHrR974NfymK-74qk?usp=sharing'
for attempt in 1 2 3; do
  if "$PY" -m gdown "$LORA_URL" --folder -O "$C/models/loras"; then
    echo '[LoRA] Google Drive sync completed'
    break
  fi
  echo "[LoRA] Download failed, attempt $attempt/3" >&2
  if [ "$attempt" -eq 3 ]; then
    echo '[LoRA] WARNING: Google Drive download incomplete; ComfyUI will still start' >&2
  else
    sleep 15
  fi
done

echo '[4/4] Starting original RunPod services and ComfyUI' 
exec /start.sh
