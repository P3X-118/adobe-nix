# LinuxPDF Docker Build System

This is Linux running inside a PDF file via a RISC-V emulator, which is based on [TinyEMU](https://bellard.org/tinyemu/).

This directory contains a complete Docker-based build system for creating LinuxPDF files. The build process is fully containerized and reproducible.

## Quick Start

### Prerequisites
- Docker and Docker Compose
- Make (optional, for easy commands)
- Approximately 2-3 GB of disk space for the build

### Building the PDF

#### Using Make (Recommended)
```bash
# Build 32-bit version (faster, default)
make build-32

# Build 64-bit version (slower but more capable)
make build-64

# Build both versions
make build-both

# Build and extract only the PDF files
make build-extract-32
make build-extract-64
make build-extract-both
```

#### Using Docker Compose Directly
```bash
# Build 32-bit version
docker-compose up --build builder-32

# Build 64-bit version
docker-compose -f docker-compose.yml -f docker-compose.64.yml up --build builder-64

# Extract only the PDF (after build)
mkdir -p final
docker-compose run --rm pdf-32
```

## Output Files

After successful build, you'll find:
- `out/linux.pdf` - Full LinuxPDF with embedded emulator
- `final/linux-32bit.pdf` - Clean 32-bit PDF (if using extract commands)
- `final/linux-64bit.pdf` - Clean 64-bit PDF (if using extract commands)

## Build Options

### Environment Variables

- `USE_CACHE=true` - Enable download caching (default: false)
- `BUILD_CLEAN=true` - Force clean rebuild (default: false)
- `DEBUG=true` - Enable debug output (default: false)

### Examples
```bash
# Enable caching for faster rebuilds
USE_CACHE=true make build-32

# Force clean rebuild
BUILD_CLEAN=true make build-32

# Development build with caching and debug output
USE_CACHE=true DEBUG=true make dev-build-32
```

## Development Commands

```bash
# Get shell in build environment
make shell-32
make shell-64

# Show build logs
make logs

# Show container status
make status

# Build with full development output (includes web assets)
make dev-output-32
make dev-output-64
```

## Cleanup

```bash
# Remove containers and images
make clean

# Remove everything including caches
make clean-all
```

## Architecture

### Docker Setup

- **Dockerfile**: Multi-stage build with dependency installation, build execution, and PDF extraction
- **docker-compose.yml**: 32-bit build configuration
- **docker-compose.64.yml**: 64-bit build configuration
- **docker-compose.override.yml**: Development overrides (enabled automatically when present)

### Build Process

1. **Dependencies**: Ubuntu 22.04 with Emscripten 1.39.20-fastcomp, Python, build tools
2. **Compilation**: TinyEMU compiled to asm.js using Emscripten
3. **Linux Setup**: Download and configure RISC-V Linux (32-bit Buildroot or 64-bit Alpine)
4. **PDF Generation**: Embed JavaScript emulator into interactive PDF

### Directory Structure

```
linuxpdf/
├── Dockerfile                 # Multi-stage container build
├── docker-compose.yml         # 32-bit build services
├── docker-compose.64.yml      # 64-bit build services
├── docker-compose.override.yml # Development overrides
├── Makefile                   # Easy build commands
├── scripts/                   # Build and utility scripts
│   ├── docker-build.sh        # Modified build script for containers
│   ├── entrypoint.sh          # Container entrypoint
│   └── extract-pdf.sh         # PDF extraction utility
├── out/                       # Build output directory
├── cache/                     # Download cache (optional)
├── final/                     # Extracted PDFs
└── logs/                      # Build logs
```

## Project Details

### What is LinuxPDF?

LinuxPDF is a modified version of the TinyEMU RISC-V emulator compiled to asm.js and embedded within an interactive PDF. The PDF contains:

- Complete RISC-V emulator (32-bit or 64-bit)
- Linux kernel and root filesystem
- Interactive display using text fields
- Virtual keyboard interface
- Web browser integration (Chromium-based)

### Technical Details

- **Emulator**: TinyEMU modified for asm.js output
- **Architecture**: RISC-V (32-bit or 64-bit)
- **Display**: 320x200 pixels rendered as ASCII characters in form fields
- **Input**: Virtual keyboard with full QWERTY layout
- **Performance**: ~100x slower than native due to PDF engine restrictions

### Browser Compatibility

The generated PDF works only in Chromium-based browsers (Chrome, Edge, Opera) due to JavaScript engine limitations in PDF viewers.

## Original Project Information

This Docker build system is based on the original LinuxPDF project by [@ading2210](https://github.com/ading2210/).

### Credits

- **TinyEMU**: RISC-V emulator by [Fabrice Bellard](https://bellard.org/)
- **LinuxPDF**: Concept and implementation by [@ading2210](https://github.com/ading2210/)

### License

This repository is licensed under the GNU GPL v3.

```
ading2210/linuxpdf - Linux running inside a PDF file
Copyright (C) 2025 ading2210

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
```

## Troubleshooting

### Common Issues

1. **Out of Space**: Ensure at least 2-3 GB free disk space
2. **Network Issues**: Check internet connection for downloads
3. **Permission Issues**: Ensure Docker daemon is running
4. **Slow Builds**: Use `USE_CACHE=true` for faster rebuilds

### Debug Mode

Enable debug output for troubleshooting:
```bash
DEBUG=true make build-32
```

### Logs

Check build logs for errors:
```bash
make logs
# or directly
tail -f logs/build.log
```

## Alternative Build Methods

If you prefer not to use Docker, you can use the original build method:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip3 install -r requirements.txt
./build.sh
```

However, the Docker method is recommended for reproducibility and dependency management.