#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Stop any previous instance
"$SCRIPT_DIR/stop.sh"

# Check prerequisites
command -v dart >/dev/null 2>&1 || { echo "Error: dart not found on PATH"; exit 1; }
command -v claude >/dev/null 2>&1 || { echo "Error: claude CLI not found. Install: https://claude.ai/code"; exit 1; }

# Install/update Dart dependencies
echo "Installing dependencies..."
dart pub get

# Optional: set port (default 8080)
export PORT="${PORT:-8080}"

echo "Starting server on port $PORT..."

# Start in a new process group so stop.sh can kill server + children together
set -m
dart run bin/server.dart &
SERVER_PID=$!
echo "$SERVER_PID" > "$SCRIPT_DIR/.server.pid"

# Forward signals to the process group
trap 'kill -- -$SERVER_PID 2>/dev/null; rm -f "$SCRIPT_DIR/.server.pid"; exit' INT TERM

echo "Server pid: $SERVER_PID"
wait "$SERVER_PID"
rm -f "$SCRIPT_DIR/.server.pid"
