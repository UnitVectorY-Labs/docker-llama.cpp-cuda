# docker-llama.cpp-cuda

CUDA-enabled `llama-server` container built from upstream `llama.cpp` for NVIDIA DGX Spark class devices and equivalent GB10-based variants.

This image is intended for serving GGUF models on GB10 systems with aggressive GPU offload. The build disables native GPU auto-detection in CI with `GGML_NATIVE=OFF` and explicitly targets `CMAKE_CUDA_ARCHITECTURES=121` (`sm_121` / compute capability 12.1) for DGX Spark and matching GB10 hardware.

## Use Case

Use this container when you want a reproducible `llama.cpp` server image for:

- NVIDIA DGX Spark systems
- Other GB10-class devices with equivalent CUDA capability
- Large GGUF model serving with HTTP access from `llama-server`

The example below runs the container with full GPU access, persists the Hugging Face model cache, and starts `llama-server` with a large context window and full layer offload.

## Example Run Command

```bash
docker run -d --rm \
  --pull=always \
  --gpus all \
  --name llama-server \
  -p 8080:8080 \
  -e HOME=/root \
  -v "$HOME/.cache/llama.cpp:/root/.cache/llama.cpp" \
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
