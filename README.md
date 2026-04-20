# docker-llama.cpp-cuda

CUDA-enabled `llama-server` container built from upstream `llama.cpp` for NVIDIA DGX Spark class devices and equivalent GB10-based variants.

This image is intended for serving GGUF models on GB10 systems with aggressive GPU offload. The build disables native GPU auto-detection in CI with `GGML_NATIVE=OFF` and explicitly targets `CMAKE_CUDA_ARCHITECTURES=121` (`sm_121` / compute capability 12.1) for DGX Spark and matching GB10 hardware.

## Use Case

Use this container when you want a reproducible `llama.cpp` server image for:

- NVIDIA DGX Spark systems
- Other GB10-class devices with equivalent CUDA capability
- Large GGUF model serving with HTTP access from `llama-server`

The example below runs the container with full GPU access, persists the Hugging Face and `llama.cpp` caches, and starts `llama-server` with a large context window and full layer offload. The image defaults to a non-root `llama` user (`uid:gid 1000:1000`) with `HOME=/home/llama`.

## Example Run Command

```bash
docker run -d --rm \
  --pull=always \
  --gpus all \
  --name llama-server \
  -p 8080:8080 \
  -v "$HOME/.cache/llama.cpp:/home/llama/.cache/llama.cpp" \
  -v "$HOME/.cache/huggingface:/home/llama/.cache/huggingface" \
  ghcr.io/unitvectory-labs/docker-llama.cpp-cuda-snapshot:dev \
  -hf unsloth/Qwen3.5-122B-A10B-GGUF:Q4_K_M \
  --host 0.0.0.0 \
  --port 8080 \
  -ngl 999 \
  -c 262144 \
  -np 2 \
  --jinja \
  -fa on \
  -b 2048 \
  -ub 1024
```

## Non-Root Runtime Notes

If you pass `--user`, keep `HOME` and cache mounts aligned with a directory that user can write to. A mismatched combination such as `--user 1000:1000` with `-e HOME=/root` will fail when `llama-server` tries to create `/root/.cache/llama.cpp`.

For a host user with `uid:gid 1000:1000`, either let the image default to its built-in non-root user, or run explicitly with:

```bash
docker run --rm \
  --gpus all \
  --user 1000:1000 \
  -e HOME=/home/llama \
  -e XDG_CACHE_HOME=/home/llama/.cache \
  -e HF_HOME=/home/llama/.cache/huggingface \
  -v "$HOME/.cache/llama.cpp:/home/llama/.cache/llama.cpp" \
  -v "$HOME/.cache/huggingface:/home/llama/.cache/huggingface" \
  ghcr.io/unitvectory-labs/docker-llama.cpp-cuda-snapshot:dev
```
