# syntax=docker/dockerfile:1.7

ARG CUDA_DEVEL_IMAGE=nvidia/cuda:13.1.1-devel-ubuntu24.04
ARG CUDA_RUNTIME_IMAGE=nvidia/cuda:13.1.1-runtime-ubuntu24.04
ARG LLAMA_CPP_REPO=https://github.com/ggml-org/llama.cpp.git
ARG LLAMA_CPP_REF=master

FROM ${CUDA_DEVEL_IMAGE} AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG LLAMA_CPP_REPO
ARG LLAMA_CPP_REF

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

RUN git clone --depth 1 --branch "${LLAMA_CPP_REF}" "${LLAMA_CPP_REPO}" llama.cpp

WORKDIR /src/llama.cpp

RUN cmake -S . -B build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DGGML_CUDA=ON \
    -DLLAMA_OPENSSL=ON \
    -DBUILD_SHARED_LIBS=OFF

RUN cmake --build build --config Release --target llama-server -j"$(nproc)"

FROM ${CUDA_RUNTIME_IMAGE} AS runtime

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
