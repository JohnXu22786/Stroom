#!/bin/bash
# Download FFmpeg for Linux
# Usage: bash scripts/download-ffmpeg.sh

OUTPUT_DIR="assets/ffmpeg"
FFMPEG_URL="https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz"

echo "Downloading FFmpeg for Linux..."

TMP_DIR=$(mktemp -d)
TAR_PATH="$TMP_DIR/ffmpeg.tar.xz"

# Download
wget -O "$TAR_PATH" "$FFMPEG_URL" || curl -L -o "$TAR_PATH" "$FFMPEG_URL"

# Extract
tar -xf "$TAR_PATH" -C "$TMP_DIR"

# Find ffmpeg binary
FFMPEG_BIN=$(find "$TMP_DIR" -name "ffmpeg" -type f | head -1)
if [ -n "$FFMPEG_BIN" ]; then
    mkdir -p "$OUTPUT_DIR"
    cp "$FFMPEG_BIN" "$OUTPUT_DIR/ffmpeg_linux"
    chmod +x "$OUTPUT_DIR/ffmpeg_linux"
    echo "FFmpeg for Linux saved to: $OUTPUT_DIR/ffmpeg_linux"
else
    echo "ERROR: ffmpeg binary not found in extracted archive"
    exit 1
fi

# Cleanup
rm -rf "$TMP_DIR"
echo "Done!"
