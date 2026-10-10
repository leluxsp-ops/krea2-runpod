# Krea 2 Turbo / RunPod (CUDA 12.8)

## Publishing

1. Create a **public** GitHub repository named `krea2-runpod` (repository name can differ).
2. Upload `Dockerfile`, `krea-entrypoint.sh` and `.github/workflows/docker.yml` preserving the directory structure. The easiest method is Git upload of the unpacked folder, including hidden `.github`.
3. In GitHub **Actions**, run **Build and publish RunPod image**; or push to the `main` branch.
4. Under GitHub **Packages**, make the published container package public if it is not public already. Private packages require registry credentials in RunPod.
5. In RunPod create a Pod template:
   - Container image: `ghcr.io/YOUR_GITHUB_USERNAME/krea2-runpod:latest` (lowercase, substitute actual owner/repo)
   - Container start command: **empty**
   - HTTP Ports: `8188` (ComfyUI), optionally `8888` (Jupyter), `8080` (FileBrowser)
   - Volume mount path: `/workspace`
   - Storage: 80–100 GB minimum recommended
6. On first boot, wait for models to download (~28 GB), then ComfyUI starts on port 8188.

## What is installed

- Krea 2 Turbo FP8, Qwen3VL FP8 and BF16, Qwen Image VAE and WAN 2.1 VAE
- CRT-Nodes, rgthree-comfy
- **No LoRA**, no Aiorbust

Place your own LoRA files in `/workspace/runpod-slim/ComfyUI/models/loras/`.

## Notes

- The base image's `/start.sh` previously ignored the user-specified Docker start command. This custom Docker image replaces its ENTRYPOINT, performs the installation **before** calling `/start.sh`, and then hands startup back to the base image.
- If you recreate a Pod with the same persistent volume, downloaded models are reused. A new ephemeral Pod without a retained `/workspace` volume will download them again.
- If the custom nodes are still not recognized, inspect `/start.sh` logs for `IMPORT FAILED` and verify compatibility with the current ComfyUI. The latest CRT-Nodes version may not have the exact `CRT Post-Process Suite` node used by the original workflow.
- Krea 2's official workflow specifies `qwen_image_vae.safetensors`. Your supplied custom workflow specified `wan_2.1_vae.safetensors`; both files are included, but the original selection may not produce correct results, so test Qwen Image VAE if decoding fails.
- Krea 2 model weights are provided under the Krea 2 community license, separately from this installer.
