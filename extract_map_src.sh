#!/bin/bash

# Script to extract OpenStreetMap website source code from Docker container
# Excludes large directories like storage, tmp, node_modules, and .git

set -e

CONTAINER_NAME="openstreetmap-website-web-1"
OUTPUT_DIR="/mnt/2_1/visualwebarena_my/map_src_code_only"

echo "Extracting OpenStreetMap source code from container: $CONTAINER_NAME"
echo "Output directory: $OUTPUT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Copy source code from container, excluding large directories
docker cp "$CONTAINER_NAME:/app" "$OUTPUT_DIR/temp_app"

echo "Removing large directories and files..."

# Remove large/unnecessary directories
rm -rf "$OUTPUT_DIR/temp_app/storage" 2>/dev/null || true
rm -rf "$OUTPUT_DIR/temp_app/tmp" 2>/dev/null || true
rm -rf "$OUTPUT_DIR/temp_app/node_modules" 2>/dev/null || true
rm -rf "$OUTPUT_DIR/temp_app/.git" 2>/dev/null || true
rm -rf "$OUTPUT_DIR/temp_app/log" 2>/dev/null || true
rm -rf "$OUTPUT_DIR/temp_app/vendor/cache" 2>/dev/null || true

# Remove swap files and temporary files
find "$OUTPUT_DIR/temp_app" -name "*.swp" -delete 2>/dev/null || true
find "$OUTPUT_DIR/temp_app" -name "*.swo" -delete 2>/dev/null || true
find "$OUTPUT_DIR/temp_app" -name ".DS_Store" -delete 2>/dev/null || true

# Move contents from temp_app to output directory
mv "$OUTPUT_DIR/temp_app"/* "$OUTPUT_DIR/" 2>/dev/null || true
mv "$OUTPUT_DIR/temp_app"/.[!.]* "$OUTPUT_DIR/" 2>/dev/null || true
rmdir "$OUTPUT_DIR/temp_app"

# Get final size
FINAL_SIZE=$(du -sh "$OUTPUT_DIR" | cut -f1)

echo ""
echo "Extraction complete!"
echo "Source code location: $OUTPUT_DIR"
echo "Total size: $FINAL_SIZE"
echo ""
echo "Excluded directories:"
echo "  - storage/ (user uploaded files)"
echo "  - tmp/ (temporary files)"
echo "  - node_modules/ (npm packages)"
echo "  - .git/ (git repository data)"
echo "  - log/ (log files)"
echo ""
