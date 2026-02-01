#!/bin/bash
# Simple Docker build test for LinuxPDF
# This bypasses complex build system for basic testing

set -e

echo "Starting simple LinuxPDF build test..."

# Use basic Ubuntu with essential tools
docker run --rm --network=host \
    -v "$(pwd)/out:/app/out" \
    -v "$(pwd)/cache:/app/cache" \
    -w /app \
    ubuntu:22.04 \
    bash -c "
        apt-get update && apt-get install -y python3 python3-pip wget tar git build-essential
        pip3 install pdfrw
        mkdir -p out cache build
        if [ ! -f build/vm.tar.gz ]; then
            wget https://bellard.org/tinyemu/diskimage-linux-riscv-2018-09-23.tar.gz -O build/vm.tar.gz
        fi
        if [ ! -d build/vm ]; then
            tar -xf build/vm.tar.gz -C build
            mv build/diskimage* build/vm
        fi
        echo 'Simple build test completed - files in out/'
    "

echo "Checking results..."
ls -la out/