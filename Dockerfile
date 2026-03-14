# syntax=docker/dockerfile:1.7

FROM nvidia/cuda:13.1.1-devel-ubuntu24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG CMAKE_CUDA_ARCHITECTURES=121

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    build-essential \
    cmake \
    ninja-build \
    pkg-config \
    libssl-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

RUN set -eux; \
    LLAMA_CPP_TAG="$(curl -fsSL https://api.github.com/repos/ggml-org/llama.cpp/releases/latest | sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p')"; \
    test -n "$LLAMA_CPP_TAG"; \
    echo "Building llama.cpp release tag: $LLAMA_CPP_TAG"; \
    git clone --depth 1 --branch "$LLAMA_CPP_TAG" https://github.com/ggml-org/llama.cpp.git llama.cpp

WORKDIR /src/llama.cpp

RUN cmake -S . -B build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DGGML_NATIVE=OFF \
    -DCMAKE_CUDA_ARCHITECTURES=${CMAKE_CUDA_ARCHITECTURES} \
    -DLLAMA_OPENSSL=ON \
    -DBUILD_SHARED_LIBS=OFF

RUN cmake --build build --config Release --target llama-server -j"$(nproc)"

FROM nvidia/cuda:13.1.1-runtime-ubuntu24.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY --from=builder /src/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server

ENV LLAMA_LOG_COLORS=1
ENV LLAMA_LOG_PREFIX=1
ENV LLAMA_LOG_TIMESTAMPS=1

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/llama-server"]
CMD ["--host", "0.0.0.0", "--port", "8080"]
