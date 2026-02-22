#!/bin/bash
# Extract the classifieds web app source code from the Docker image.
# The source lives at /usr/src/myapp inside jykoh/classifieds:latest.
# Output goes to ./classifieds_src/ by default.

set -e

IMAGE="jykoh/classifieds:latest"
SRC_PATH="/usr/src/myapp"
OUTPUT_DIR="${1:-$(dirname "$0")/classifieds_src}"

echo "Extracting classifieds source from Docker image..."
echo "  Image   : $IMAGE"
echo "  Source  : $SRC_PATH"
echo "  Output  : $OUTPUT_DIR"
echo ""

# Create a temporary container (not started) so we can use docker cp
CONTAINER=$(docker create "$IMAGE")

cleanup() {
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Copy source tree out of the container
mkdir -p "$OUTPUT_DIR"
docker cp "$CONTAINER:$SRC_PATH/." "$OUTPUT_DIR"

# Remove macOS metadata files (._*) baked into the image
find "$OUTPUT_DIR" -name '._*' -delete

echo "Done. Files extracted to: $OUTPUT_DIR"
echo ""
echo "Structure:"
find "$OUTPUT_DIR" -maxdepth 2 | sed "s|$OUTPUT_DIR/||" | sort
