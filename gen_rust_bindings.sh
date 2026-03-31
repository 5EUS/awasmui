#!/usr/bin/env bash
set -euo pipefail

# Generate FRB bindings and the local Flutter plugin package (rust_builder)
# Usage: ./gen_rust_bindings.sh

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

# Add Flutter to PATH if it's not already available
if ! command -v flutter >/dev/null 2>&1; then
  if [ -f "~/Git/flutter/bin/flutter" ]; then
    export PATH="$PATH:~/Git/flutter/bin"
    log "Added Flutter to PATH"
  fi
fi

CODEGEN_BIN="flutter_rust_bridge_codegen"
REQUIRED_VERSION="2.11.1"
CONFIG_FILE="flutter_rust_bridge.yaml"
OUTPUT_DIR="lib/rust/generated"
RUST_SRC_DIR="lib/rust/src"

log() { echo "[gen] $*"; }
err() { echo "[gen][error] $*" >&2; }

# 1) Ensure codegen is installed
if ! command -v "$CODEGEN_BIN" >/dev/null 2>&1; then
  log "Installing $CODEGEN_BIN@$REQUIRED_VERSION via cargo..."
  cargo install "$CODEGEN_BIN" --version "$REQUIRED_VERSION"
else
  log "$CODEGEN_BIN present"
fi

# 2) Verify config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  err "Config file $CONFIG_FILE not found. Please ensure it exists."
  exit 1
else
  log "Using existing $CONFIG_FILE"
fi

# 3) Check if regeneration is necessary
log "Checking if bindings need to be regenerated..."
REGENERATE=false

# Exclude generated Rust files so generation does not retrigger itself
EXCLUDE_RS_PATTERN='frb_generated.rs'
log "Ignoring generated Rust files matching: $EXCLUDE_RS_PATTERN"

# Find the most recently modified Rust or config file
if [ -d "$RUST_SRC_DIR" ]; then
  LAST_MODIFIED_RUST=$(find "$RUST_SRC_DIR" -name '*.rs' -type f ! -name "$EXCLUDE_RS_PATTERN" -exec stat -f "%m" {} + 2>/dev/null | sort -nr | head -n 1 || echo 0)
else
  log "rust/src directory not found. Skipping Rust file checks."
  LAST_MODIFIED_RUST=0
fi

# Ensure variables are integers
LAST_MODIFIED_RUST=${LAST_MODIFIED_RUST:-0}
LAST_MODIFIED_CONFIG=${LAST_MODIFIED_CONFIG:-0}

# Compare the timestamps manually
if [ "$LAST_MODIFIED_RUST" -gt "$LAST_MODIFIED_CONFIG" ]; then
  LAST_MODIFIED=$LAST_MODIFIED_RUST
else
  LAST_MODIFIED=$LAST_MODIFIED_CONFIG
fi

# Check if any generated Dart files exist
if [ -d "$OUTPUT_DIR" ]; then
  GENERATED_FILES_COUNT=$(find "$OUTPUT_DIR" -name '*.dart' -type f | wc -l)
  if [ "$GENERATED_FILES_COUNT" -gt 0 ]; then
    LAST_MODIFIED_DART=$(find "$OUTPUT_DIR" -name '*.dart' -type f -exec stat -f "%m" {} + 2>/dev/null | sort -nr | head -n 1 || echo 0)
  else
    log "No generated Dart files found in $OUTPUT_DIR."
    LAST_MODIFIED_DART=0
  fi
else
  log "Output directory $OUTPUT_DIR does not exist."
  LAST_MODIFIED_DART=0
fi

# Ensure LAST_MODIFIED_DART is an integer
LAST_MODIFIED_DART=${LAST_MODIFIED_DART:-0}

# Compare timestamps
if [ "$LAST_MODIFIED" -gt "$LAST_MODIFIED_DART" ]; then
  log "Rust files or config file have been modified since the last generation."
  REGENERATE=true
elif [ "$LAST_MODIFIED_DART" -eq 0 ]; then
  log "No generated Dart files found. Regenerating bindings."
  REGENERATE=true
else
  log "No changes detected. Skipping binding generation."
fi

# 4) Generate bindings if necessary
if [ "$REGENERATE" = true ]; then
  log "Generating FRB bindings using $CONFIG_FILE"
  log "Running command: $CODEGEN_BIN generate --config-file $CONFIG_FILE"
  $CODEGEN_BIN generate --config-file "$CONFIG_FILE" || {
    err "Binding generation failed. Check the output above for details."
    exit 1
  }
  log "Bindings generated successfully."
else
  log "Bindings are up-to-date."
fi

log "Done. Next steps:"
log "  1) flutter pub get"
log "  2) flutter run (-d <device>)"
