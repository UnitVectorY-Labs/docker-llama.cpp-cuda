# docker-llama.cpp-cuda
Built from upstream llama.cpp as a CUDA-enabled llama-server container for local LLM inference with a simple, reproducible Docker workflow.

The image configures `llama.cpp` with `GGML_NATIVE=OFF` so CI builds on GitHub-hosted runners do not ask `nvcc` to auto-detect a local GPU via `-arch=native`.
By default it also targets `CMAKE_CUDA_ARCHITECTURES=121`, which matches NVIDIA DGX Spark (`sm_121` / compute capability 12.1). Override the build arg if you need a different CUDA target.
