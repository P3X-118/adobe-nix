#!/bin/bash
# Manual Docker build script for LinuxPDF (alternative to docker-compose)
# Use this when Docker Compose networking issues occur

set -e

# Configuration
BITNESS="${1:-32}"
USE_CACHE="${USE_CACHE:-false}"
BUILD_CLEAN="${BUILD_CLEAN:-false}"
DEBUG="${DEBUG:-false}"
IMAGE_NAME="linuxpdf-builder-${BITNESS}"

# Build Docker image if not exists
build_image() {
    if ! docker image ls | grep -q "$IMAGE_NAME"; then
        echo "Building Docker image $IMAGE_NAME..."
        docker build --network=host -t "$IMAGE_NAME" .
    else
        echo "Docker image $IMAGE_NAME already exists"
    fi
}

# Run build process
run_build() {
    echo "Starting LinuxPDF build (${BITNESS}-bit)..."
    
    # Create output directories
    mkdir -p out logs cache final
    
    # Run build in container with host networking
    docker run --rm \
        --network=host \
        -v "$(pwd)/out:/app/out" \
        -v "$(pwd)/cache:/app/cache" \
        -v "$(pwd)/logs:/app/logs" \
        -e "BITS=${BITNESS}" \
        -e "USE_CACHE=${USE_CACHE}" \
        -e "BUILD_CLEAN=${BUILD_CLEAN}" \
        -e "DEBUG=${DEBUG}" \
        -w /app \
        "$IMAGE_NAME" \
        ./scripts/docker-build.sh
}

# Extract PDF only
extract_pdf() {
    echo "Extracting PDF to ./final/..."
    mkdir -p final
    
    docker run --rm \
        --network=host \
        -v "$(pwd)/out:/app/out" \
        -v "$(pwd)/final:/output" \
        -e "BITS=${BITNESS}" \
        -e "DEBUG=${DEBUG}" \
        "$IMAGE_NAME" \
        ./scripts/extract-pdf.sh
}

# Main execution
main() {
    case "${2:-build}" in
        "build")
            build_image
            run_build
            ;;
        "extract")
            extract_pdf
            ;;
        "all")
            build_image
            run_build
            extract_pdf
            ;;
        *)
            echo "Usage: $0 [32|64] [build|extract|all]"
            echo "  build   - Build LinuxPDF (default)"
            echo "  extract - Extract PDF only"
            echo "  all     - Build and extract"
            exit 1
            ;;
    esac
}

main "$@"