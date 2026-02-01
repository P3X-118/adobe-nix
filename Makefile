# Makefile for LinuxPDF Docker build system
# Provides simple commands for building and managing the Docker-based build process

.PHONY: help build-32 build-64 build-both extract-32 extract-64 extract-both clean clean-all shell-32 shell-64 logs status

# Default target
help:
	@echo "LinuxPDF Docker Build System"
	@echo ""
	@echo "Build Commands:"
	@echo "  build-32       Build 32-bit LinuxPDF (default)"
	@echo "  build-64       Build 64-bit LinuxPDF"
	@echo "  build-both     Build both 32-bit and 64-bit versions"
	@echo ""
	@echo "Extract Commands:"
	@echo "  extract-32     Extract only 32-bit PDF to ./final/"
	@echo "  extract-64     Extract only 64-bit PDF to ./final/"
	@echo "  extract-both   Extract both PDFs to ./final/"
	@echo ""
	@echo "Development Commands:"
	@echo "  shell-32       Get shell in 32-bit build container"
	@echo "  shell-64       Get shell in 64-bit build container"
	@echo "  logs           Show build logs"
	@echo "  status         Show container status"
	@echo ""
	@echo "Cleanup Commands:"
	@echo "  clean          Remove build containers and images"
	@echo "  clean-all      Remove everything including caches"
	@echo ""
	@echo "Environment Variables:"
	@echo "  USE_CACHE=true     Enable download caching (default: false)"
	@echo "  BUILD_CLEAN=true   Force clean rebuild (default: false)"
	@echo "  DEBUG=true         Enable debug output (default: false)"

# Build commands
build-32:
	@echo "Building 32-bit LinuxPDF..."
	@mkdir -p out logs
	docker compose build builder-32
	docker compose up --build builder-32

build-64:
	@echo "Building 64-bit LinuxPDF..."
	@mkdir -p out logs
	docker compose -f docker-compose.yml -f docker-compose.64.yml build builder-64
	docker compose -f docker-compose.yml -f docker-compose.64.yml up --build builder-64

build-both: build-32 build-64
	@echo "Both builds completed successfully!"

# Extract commands (PDF only)
extract-32:
	@echo "Extracting 32-bit PDF..."
	@mkdir -p final
	docker compose run --rm -e BITS=32 pdf-32

extract-64:
	@echo "Extracting 64-bit PDF..."
	@mkdir -p final
	docker compose -f docker-compose.yml -f docker-compose.64.yml run --rm -e BITS=64 pdf-64

extract-both: extract-32 extract-64
	@echo "Both PDFs extracted to ./final/"

# Build and extract in one step
build-extract-32: build-32 extract-32
	@echo "32-bit LinuxPDF built and extracted to ./final/"

build-extract-64: build-64 extract-64
	@echo "64-bit LinuxPDF built and extracted to ./final/"

build-extract-both: build-both extract-both
	@echo "Both PDFs built and extracted to ./final/"

# Development commands
shell-32:
	@echo "Getting shell in 32-bit build environment..."
	docker compose run --rm --entrypoint /bin/bash builder-32

shell-64:
	@echo "Getting shell in 64-bit build environment..."
	docker compose -f docker-compose.yml -f docker-compose.64.yml run --rm --entrypoint /bin/bash builder-64

# Full development output (includes web assets)
dev-output-32:
	@echo "Building and extracting full 32-bit output..."
	@mkdir -p final
	docker compose --profile dev-output up --build output-32

dev-output-64:
	@echo "Building and extracting full 64-bit output..."
	@mkdir -p final
	docker compose -f docker-compose.yml -f docker-compose.64.yml --profile dev-output up --build output-64

# Utility commands
logs:
	@echo "Showing recent build logs..."
	@if [ -f logs/build.log ]; then \
		tail -50 logs/build.log; \
	else \
		echo "No build logs found. Run a build first."; \
	fi

status:
	@echo "Docker containers status:"
	@docker compose ps

# Cleanup commands
clean:
	@echo "Stopping and removing containers..."
	docker compose down --remove-orphans 2>/dev/null || true
	docker compose -f docker-compose.64.yml down --remove-orphans 2>/dev/null || true
	@echo "Removing build images..."
	docker compose down --rmi all 2>/dev/null || true
	docker compose -f docker-compose.64.yml down --rmi all 2>/dev/null || true

clean-all: clean
	@echo "Removing all build artifacts and caches..."
	@rm -rf out/ cache/ logs/ final/
	@docker system prune -f
	@docker volume prune -f

# Quick development commands (with caching enabled)
dev-build-32:
	@echo "Building 32-bit with caching enabled..."
	USE_CACHE=true DEBUG=true $(MAKE) build-32

dev-build-64:
	@echo "Building 64-bit with caching enabled..."
	USE_CACHE=true DEBUG=true $(MAKE) build-64

dev-rebuild-32:
	@echo "Clean rebuilding 32-bit..."
	BUILD_CLEAN=true $(MAKE) build-32

dev-rebuild-64:
	@echo "Clean rebuilding 64-bit..."
	BUILD_CLEAN=true $(MAKE) build-64

# Advanced commands
validate-pdf:
	@echo "Validating generated PDFs..."
	@if [ -f final/linux-32bit.pdf ]; then \
		echo "✓ 32-bit PDF exists and is $(stat -c%s final/linux-32bit.pdf) bytes"; \
	else \
		echo "✗ 32-bit PDF not found"; \
	fi
	@if [ -f final/linux-64bit.pdf ]; then \
		echo "✓ 64-bit PDF exists and is $(stat -c%s final/linux-64bit.pdf) bytes"; \
	else \
		echo "✗ 64-bit PDF not found"; \
	fi

info:
	@echo "LinuxPDF Docker Build Information"
	@echo "=================================="
	@echo "Docker Compose: $(shell docker-compose --version)"
	@echo "Docker: $(shell docker --version)"
	@echo "Current directory: $(shell pwd)"
	@echo "Cache directory: $(shell readlink -f cache)"
	@echo "Output directory: $(shell readlink -f out)"
	@echo "Final directory: $(shell readlink -f final)"
	@echo ""
	@echo "Environment:"
	@echo "  USE_CACHE=$(USE_CACHE)"
	@echo "  BUILD_CLEAN=$(BUILD_CLEAN)"
	@echo "  DEBUG=$(DEBUG)"

# Default target
.DEFAULT_GOAL := help