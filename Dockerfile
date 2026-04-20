# syntax=docker/dockerfile:1.7

FROM nvidia/cuda:13.2.1-devel-ubuntu24.04 AS builder

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

FROM nvidia/cuda:13.2.1-runtime-ubuntu24.04 AS runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG APP_USER=llama
ARG APP_HOME=/home/llama
ARG APP_UID=1000
ARG APP_GID=1000

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libssl3 \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    if ! getent group "${APP_GID}" >/dev/null; then \
        groupadd --gid "${APP_GID}" "${APP_USER}"; \
    fi; \
    if ! getent passwd "${APP_UID}" >/dev/null; then \
        useradd \
            --uid "${APP_UID}" \
            --gid "${APP_GID}" \
            --create-home \
            --home-dir "${APP_HOME}" \
            --shell /usr/sbin/nologin \
            "${APP_USER}"; \
    fi; \
    install -d -o "${APP_UID}" -g "${APP_GID}" \
        "${APP_HOME}" \
        "${APP_HOME}/.cache/llama.cpp" \
        "${APP_HOME}/.cache/huggingface"

WORKDIR ${APP_HOME}

COPY --from=builder /src/llama.cpp/build/bin/llama-server /usr/local/bin/llama-server

ENV HOME=${APP_HOME}
ENV XDG_CACHE_HOME=${APP_HOME}/.cache
ENV HF_HOME=${APP_HOME}/.cache/huggingface
ENV LLAMA_LOG_COLORS=1
ENV LLAMA_LOG_PREFIX=1
ENV LLAMA_LOG_TIMESTAMPS=1

USER ${APP_UID}:${APP_GID}

EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/llama-server"]
CMD ["--host", "0.0.0.0", "--port", "8080"]
