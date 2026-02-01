# LinuxPDF Docker Build Environment
# Multi-stage build for creating Linux running inside a PDF file

# Stage 1: Build Environment with Dependencies
FROM emscripten/emsdk:4.0.23 AS build-env
WORKDIR /app

# Install additional system dependencies
RUN apt-get update && apt-get install -y \
    build-essential git wget curl tar \
    python3 python3-pip python3-venv \
    sudo coreutils findutils \
    && rm -rf /var/lib/apt/lists/*

# Create builder user with sudo rights
RUN useradd -m builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Install pdfrw for Python
RUN python3 -m venv .venv && \
    .venv/bin/pip install --no-cache-dir pdfrw

# Switch to builder user for dependency installation
USER builder

# Note: Using modern Emscripten - WebAssembly will be primary target
# asm.js support is deprecated, may need manual enabling

# Stage 2: Build Execution
FROM build-env AS builder

# Copy all source code as root (Emscripten image restrictions)
COPY . .

# Ensure directories exist in /tmp (writable by all)
RUN mkdir -p /tmp/app/out /tmp/app/cache /tmp/app/logs /tmp/app/build && \
    chown -R builder:builder /tmp/app

# Switch to builder user and set working directory
USER builder
WORKDIR /tmp/app

# Run build inline - simplified version
RUN . /app/.venv/bin/activate && \
    echo "Starting LinuxPDF Docker build (BITS=32, USE_CACHE=false)" && \
    mkdir -p /tmp/app/cache /tmp/app/logs /tmp/app/build /tmp/app/out && \
    if [ ! -f "/tmp/app/build/vm.tar.gz" ]; then \
        wget "https://bellard.org/tinyemu/diskimage-linux-riscv-2018-09-23.tar.gz" -O /tmp/app/build/vm.tar.gz; \
    fi && \
    if [ ! -d "/tmp/app/build/vm" ]; then \
        tar -xf /tmp/app/build/vm.tar.gz -C /tmp/app/build && \
        mv /tmp/app/build/diskimage* /tmp/app/build/vm; \
    fi && \
    echo "Building TinyEMU..." && \
    emmake make -C /app/tinyemu/ -f Makefile.pdfjs -j$(nproc --all) && \
    echo "Embedding files..." && \
    python3 /app/embed_files.py file_template.js /tmp/app/tinyemu/files/ files.js && \
    cat /tmp/app/build/pako.min.js files.js /app/pdflinux.js /app/tinyemu/js/riscvemu32.js > out/linux.pdf && \
    echo "Build completed!"

# Stage 3: PDF-only Output
FROM scratch AS pdf-output
COPY --from=builder /tmp/app/out/linux.pdf /linux.pdf

# Stage 4: Full Output (for development)
FROM build-env AS full-output
COPY --from=builder /tmp/app/out/ /out/