#!/bin/bash
# Modified build script for Docker container environment
# Based on original build.sh but adapted for containerization

set -e

# Environment variables
export BITS="${BITS:-32}"
export USE_CACHE="${USE_CACHE:-false}"
export BUILD_CLEAN="${BUILD_CLEAN:-false}"
export DEBUG="${DEBUG:-false}"
export CACHE_DIR="/tmp/app/cache"
export LOG_DIR="/tmp/app/logs"
export BUILD_DIR="/tmp/app/build"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_DIR/build.log"
}

# Debug logging
debug() {
    [ "$DEBUG" = "true" ] && log "DEBUG" "$*"
}

# Cached wget function
wget_cached() {
    local url="$1"
    local output="$2"
    local filename=$(basename "$url")
    local cache_file="$CACHE_DIR/$filename"
    
    if [ "$USE_CACHE" = "true" ] && [ -f "$cache_file" ]; then
        log "INFO" "Using cached $filename"
        cp "$cache_file" "$output"
        return 0
    fi
    
    log "INFO" "Downloading $filename from $url"
    wget "$url" -O "$output"
    
    if [ "$USE_CACHE" = "true" ]; then
        log "INFO" "Caching $filename"
        cp "$output" "$cache_file"
    fi
}

# Main build process
main() {
    log "INFO" "Starting LinuxPDF Docker build (BITS=$BITS, USE_CACHE=$USE_CACHE)"
    
    # Clean build if requested
    if [ "$BUILD_CLEAN" = "true" ]; then
        log "INFO" "Performing clean build"
        rm -rf "$BUILD_DIR" /app/emsdk/.venv/lib/python*/site-packages/pdfrw*
    fi
    
    # Setup directories
    mkdir -p "$CACHE_DIR" "$LOG_DIR" "$BUILD_DIR" /tmp/app/out
    
# Source Emscripten environment
log "INFO" "Setting up Emscripten environment"
# Emscripten Docker image should have emsdk already in PATH
# Try to activate if available
if [ -f "/emsdk/emsdk_env.sh" ]; then
    source /emsdk/emsdk_env.sh >/dev/null 2>&1
elif command -v emcc >/dev/null 2>&1; then
    log "INFO" "Emscripten already available in PATH"
else
    log "ERROR" "Emscripten not found"
    exit 1
fi
    
    # Source Python virtual environment
    log "INFO" "Setting up Python environment"
    source /app/.venv/bin/activate >/dev/null 2>&1
    
    # Download and extract VM image if needed
    if [ ! -f "$BUILD_DIR/vm.tar.gz" ]; then
        log "INFO" "Downloading TinyEMU disk image"
        wget_cached "https://bellard.org/tinyemu/diskimage-linux-riscv-2018-09-23.tar.gz" "$BUILD_DIR/vm.tar.gz"
    fi
    
    if [ ! -d "$BUILD_DIR/vm" ]; then
        log "INFO" "Extracting TinyEMU disk image"
        tar -xf "$BUILD_DIR/vm.tar.gz" -C "$BUILD_DIR"
        mv "$BUILD_DIR"/diskimage* "$BUILD_DIR/vm"
    fi
    
    # Build TinyEMU
    if [ "$BUILD_CLEAN" = "true" ]; then
        log "INFO" "Cleaning TinyEMU build"
        emmake make -C /tmp/app/tinyemu/ -f Makefile.pdfjs clean
    fi
    
    log "INFO" "Building TinyEMU for JavaScript"
    emmake make -C /tmp/app/tinyemu/ -f Makefile.pdfjs -j$(nproc --all)
    
    # Download pako.min.js if needed
    if [ ! -f "$BUILD_DIR/pako.min.js" ]; then
        log "INFO" "Downloading pako.min.js"
        wget_cached "https://cdn.jsdelivr.net/npm/pako@2.1.0/dist/pako.min.js" "$BUILD_DIR/pako.min.js"
    fi
    
    # Build file utilities if needed
    if [ ! -f "$BUILD_DIR/build_files" ]; then
        log "INFO" "Building file utilities"
        gcc /tmp/app/tinyemu/build_filelist.c /tmp/app/tinyemu/fs_utils.c /tmp/app/tinyemu/cutils.c -o "$BUILD_DIR/build_files"
    fi
    
    # Alpine Linux setup for 64-bit
    get_alpine_rootfs() {
        log "INFO" "Setting up Alpine Linux rootfs for 64-bit"
        
        if [ ! -f "$BUILD_DIR/alpine-releases.yaml" ]; then
            log "INFO" "Downloading Alpine Linux release info"
            wget_cached "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/riscv64/latest-releases.yaml" "$BUILD_DIR/alpine-releases.yaml"
        fi
        
        download_filename="$(grep "alpine-minirootfs-" "$BUILD_DIR/alpine-releases.yaml" | head -n1 | awk '{print $NF}')"
        download_url="https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/riscv64/$download_filename"
        
        if [ ! -f "$BUILD_DIR/$download_filename" ]; then
            log "INFO" "Downloading Alpine Linux rootfs: $download_filename"
            wget_cached "$download_url" "$BUILD_DIR/$download_filename"
        fi
        
        mkdir -p "$BUILD_DIR/alpine"
        tar -xf "$BUILD_DIR/$download_filename" -C "$BUILD_DIR/alpine"
        
        # Install base packages (no sudo needed in container)
        log "INFO" "Installing Alpine packages"
        echo "nameserver 1.1.1.1" > "$BUILD_DIR/alpine/etc/resolv.conf"
        chroot "$BUILD_DIR/alpine" apk add --no-cache agetty fastfetch nano htop
        
        # Setup autologin
        log "INFO" "Configuring Alpine Linux"
        echo "tty1::respawn:/sbin/agetty --autologin root tty0 linux" > "$BUILD_DIR/alpine/etc/inittab"
        cat > "$BUILD_DIR/alpine/root/.profile" << 'EOF'
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
hostname -F /etc/hostname
echo 'VM boot complete' > /dev/hvc0
fastfetch -l small
EOF
        chmod +x "$BUILD_DIR/alpine/root/.profile"
        
        # Set hostname and motd
        echo "linuxpdf" > "$BUILD_DIR/alpine/etc/hostname"
        echo -n "" > "$BUILD_DIR/alpine/etc/motd"
        
        # Compile demos
        log "INFO" "Building demo applications"
        mkdir -p "$BUILD_DIR/alpine/root/demos/"
        git clone "https://github.com/kevinboone/fblife" "$BUILD_DIR/alpine/root/demos/fblife"
        
        cat > "$BUILD_DIR/alpine/tmp/setup.sh" << 'EOF'
#!/bin/sh
set -e
set +x
apk add --no-cache gcc make musl-dev linux-headers

cd /root/demos/fblife
echo -e "#include <stdint.h>\n$(cat src/defs.h)" > src/defs.h
make
mv fblife /root/

cd /
apk del gcc make musl-dev linux-headers
rm -rf /root/demos
EOF
        chmod +x "$BUILD_DIR/alpine/tmp/setup.sh"
        chroot "$BUILD_DIR/alpine" /bin/sh /tmp/setup.sh
    }
    
    # Get image rootfs for 32-bit
    get_img_rootfs() {
        log "INFO" "Setting up 32-bit root filesystem"
        mkdir -p "$BUILD_DIR/mountpoint"
        
        # Check if the root filesystem image exists
        if [ ! -f "$BUILD_DIR/vm/root-riscv$BITS.bin" ]; then
            log "ERROR" "Root filesystem image not found: $BUILD_DIR/vm/root-riscv$BITS.bin"
            exit 1
        fi
        
        # Try to mount with sudo (container should allow this)
        if ! sudo mount -o ro "$BUILD_DIR/vm/root-riscv$BITS.bin" "$BUILD_DIR/mountpoint"; then
            log "ERROR" "Failed to mount root filesystem image"
            exit 1
        fi
        
        cp -ar "$BUILD_DIR/mountpoint" "$BUILD_DIR/root"
        cp -ar /app/init "$BUILD_DIR/root/sbin/init"
        sudo umount "$BUILD_DIR/mountpoint"
        rm -rf "$BUILD_DIR/mountpoint"
    }
    
    # Build files using 9pfs mount
    build_files() {
        log "INFO" "Building root filesystem files"
        [ "$BITS" = "64" ] && root_dir="$BUILD_DIR/alpine" || root_dir="$BUILD_DIR/root"
        
        if [ ! -d "$root_dir" ]; then
            if [ "$BITS" = "64" ]; then
                get_alpine_rootfs
            else
                get_img_rootfs
            fi
        fi
        
        if [ ! -d "$BUILD_DIR/files" ]; then
            mkdir -p "$BUILD_DIR/files/root"
            "$BUILD_DIR/build_files" "$root_dir" "$BUILD_DIR/files/root"
        fi
    }
    
    # Build disk for block device approach
    build_disk() {
        log "INFO" "Building disk image files"
        if [ ! -d "$BUILD_DIR/files/disk" ]; then
            mkdir -p "$BUILD_DIR/files/disk"
            cp "$BUILD_DIR/vm/root-riscv$BITS.bin" "$BUILD_DIR/files/disk/root.bin"
            
            block_size="256"
            (
                cd "$BUILD_DIR/files/disk"
                split -b "${block_size}K" -d -a 9 --additional-suffix=".bin" root.bin "blk"
                rm root.bin
            )
            num_blocks="$(find "$BUILD_DIR/files/disk/" -name 'blk*.bin' | wc -l)"
            cat > "$BUILD_DIR/files/disk/info.txt" << EOF
{
  block_size: $block_size,
  n_block: $num_blocks,
}
EOF
        fi
    }
    
    # Execute build steps
    build_files
    cp "vm_$BITS.cfg" "$BUILD_DIR/vm/bbl$BITS.bin" "$BUILD_DIR/vm/kernel-riscv$BITS.bin" "$BUILD_DIR/files"
    
    # Embed files and create JavaScript bundle
    log "INFO" "Embedding files into JavaScript"
    python3 /app/embed_files.py file_template.js "$BUILD_DIR/files/" "$BUILD_DIR/files.js"
    cat "$BUILD_DIR/pako.min.js" "$BUILD_DIR/files.js" /app/pdflinux.js "/tmp/app/tinyemu/js/riscvemu$BITS.js" > /app/out/compiled.js
    
    # Generate final PDF
    log "INFO" "Generating final PDF"
    python3 /app/gen_pdf.py /app/out/compiled.js /app/out/linux.pdf
    
    # Copy web assets if needed
    if [ "$DEBUG" = "true" ]; then
        log "INFO" "Copying web assets for development"
        cp -r /app/web/* /app/out/
    fi
    
    # Clean up build directory (optional)
    if [ "$BUILD_CLEAN" = "true" ]; then
        log "INFO" "Cleaning up build artifacts"
        rm -rf "$BUILD_DIR/files" "$BUILD_DIR/files.js"
    fi
    
    log "INFO" "Build completed successfully!"
    log "INFO" "Output: /tmp/app/out/linux.pdf ($(stat -c%s /tmp/app/out/linux.pdf) bytes)"
    
    # Verify PDF exists and is readable
    if [ -f "/tmp/app/out/linux.pdf" ] && [ -s "/tmp/app/out/linux.pdf" ]; then
        log "INFO" "PDF verification passed"
        exit 0
    else
        log "ERROR" "PDF verification failed"
        exit 1
    fi
}

# Execute main function
main "$@"