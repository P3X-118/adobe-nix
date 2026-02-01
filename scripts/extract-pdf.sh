#!/bin/bash
# Script to extract only the PDF output from build results
# Used for production builds where only the PDF file is needed

set -e

# Configuration
SOURCE_DIR="/app/out"
OUTPUT_DIR="/output"
BITS="${BITS:-32}"
DEBUG="${DEBUG:-false}"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message"
}

# Function to verify PDF integrity
verify_pdf() {
    local pdf_file="$1"
    
    if [ ! -f "$pdf_file" ]; then
        log "ERROR" "PDF file not found: $pdf_file"
        return 1
    fi
    
    if [ ! -s "$pdf_file" ]; then
        log "ERROR" "PDF file is empty: $pdf_file"
        return 1
    fi
    
    # Basic PDF header check
    if ! head -c 4 "$pdf_file" | grep -q "^%PDF"; then
        log "ERROR" "PDF file has invalid header: $pdf_file"
        return 1
    fi
    
    log "INFO" "PDF verification passed: $pdf_file"
    return 0
}

# Function to extract and rename PDF
extract_pdf() {
    local source_pdf="$SOURCE_DIR/linux.pdf"
    local output_name="linux-${BITS}bit.pdf"
    local target_pdf="$OUTPUT_DIR/$output_name"
    
    log "INFO" "Extracting PDF from $source_pdf to $target_pdf"
    
    if verify_pdf "$source_pdf"; then
        mkdir -p "$OUTPUT_DIR"
        cp "$source_pdf" "$target_pdf"
        
        # Create additional files for convenience
        echo "LinuxPDF $BITS-bit build completed on $(date)" > "$OUTPUT_DIR/BUILD_INFO.txt"
        echo "Original filename: linux.pdf" >> "$OUTPUT_DIR/BUILD_INFO.txt"
        echo "Build size: $(stat -c%s "$target_pdf") bytes" >> "$OUTPUT_DIR/BUILD_INFO.txt"
        
        # Create checksum for verification
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum "$target_pdf" > "$OUTPUT_DIR/$output_name.sha256"
        elif command -v shasum >/dev/null 2>&1; then
            shasum -a 256 "$target_pdf" > "$OUTPUT_DIR/$output_name.sha256"
        fi
        
        log "INFO" "PDF extraction completed successfully"
        log "INFO" "Output: $target_pdf ($(stat -c%s "$target_pdf") bytes)"
        
        # List output directory contents if debug mode
        if [ "$DEBUG" = "true" ]; then
            log "DEBUG" "Output directory contents:"
            ls -la "$OUTPUT_DIR"
        fi
        
        return 0
    else
        log "ERROR" "Source PDF verification failed"
        return 1
    fi
}

# Function to clean up old builds
cleanup_old_builds() {
    log "INFO" "Cleaning up old builds in $OUTPUT_DIR"
    
    # Remove files older than 7 days
    if command -v find >/dev/null 2>&1; then
        find "$OUTPUT_DIR" -name "*.pdf" -type f -mtime +7 -delete 2>/dev/null || true
        find "$OUTPUT_DIR" -name "*.sha256" -type f -mtime +7 -delete 2>/dev/null || true
        find "$OUTPUT_DIR" -name "BUILD_INFO.txt" -type f -mtime +7 -delete 2>/dev/null || true
    fi
}

# Main extraction process
main() {
    log "INFO" "Starting PDF extraction process (BITS=$BITS)"
    
    # Check if source directory exists
    if [ ! -d "$SOURCE_DIR" ]; then
        log "ERROR" "Source directory not found: $SOURCE_DIR"
        log "ERROR" "Please run the build process first"
        exit 1
    fi
    
    # Clean up old builds
    cleanup_old_builds
    
    # Extract PDF
    if extract_pdf; then
        log "INFO" "PDF extraction completed successfully"
        
        # Output summary
        local pdf_size=$(stat -c%s "$OUTPUT_DIR/linux-${BITS}bit.pdf" 2>/dev/null || echo "unknown")
        log "INFO" "Summary:"
        log "INFO" "  - Extracted: linux-${BITS}bit.pdf ($pdf_size bytes)"
        log "INFO" "  - Location: $OUTPUT_DIR/"
        log "INFO" "  - Checksum: linux-${BITS}bit.pdf.sha256"
        log "INFO" "  - Build info: BUILD_INFO.txt"
        
        exit 0
    else
        log "ERROR" "PDF extraction failed"
        exit 1
    fi
}

# Execute main function
main "$@"